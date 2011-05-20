package POE::Kernel;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use POSIX qw(uname);
use Errno qw(ESRCH EINTR ECHILD EPERM EINVAL EEXIST EAGAIN EWOULDBLOCK);
use Carp qw(carp croak confess cluck);
use Sys::Hostname qw(hostname);
use IO::Handle ();
use File::Spec ();

# People expect these to be lexical.

use vars qw($poe_kernel $poe_main_window);

#------------------------------------------------------------------------------
# A cheezy exporter to avoid using Exporter.

my $queue_class;

BEGIN {
  eval {
    require POE::XS::Queue::Array;
    POE::XS::Queue::Array->import();
    $queue_class = "POE::XS::Queue::Array";
  };
  unless ($queue_class) {
    require POE::Queue::Array;
    POE::Queue::Array->import();
    $queue_class = "POE::Queue::Array";
  }
}

sub import {
  my ($class, $args) = @_;
  my $package = caller();

  croak "POE::Kernel expects its arguments in a hash ref"
    if ($args && ref($args) ne 'HASH');

  {
    no strict 'refs';
    *{ $package . '::poe_kernel'      } = \$poe_kernel;
    *{ $package . '::poe_main_window' } = \$poe_main_window;
  }

  # Extract the import arguments we're interested in here.

  my $loop = delete $args->{loop} || $ENV{POE_EVENT_LOOP};

  # Don't accept unknown/mistyped arguments.

  my @unknown = sort keys %$args;
  croak "Unknown POE::Kernel import arguments: @unknown" if @unknown;

  # Now do things with them.

  unless (UNIVERSAL::can('POE::Kernel', 'poe_kernel_loop')) {
    if (defined $loop) {
      $loop =~ s/^(POE::)?(XS::)?(Loop::)?//;
      if (defined $2) {
        $loop = "POE::XS::Loop::$loop";
      }
      else {
        $loop = "POE::Loop::$loop";
      }
    }
    _test_loop($loop);
    # Bootstrap the kernel.  This is inherited from a time when multiple
    # kernels could be present in the same Perl process.
    POE::Kernel->new() if UNIVERSAL::can('POE::Kernel', 'poe_kernel_loop');
  }
}

#------------------------------------------------------------------------------
# Perform some optional setup.

BEGIN {
  local $SIG{'__DIE__'} = 'DEFAULT';

  {
    no strict 'refs';
    if ($^O eq 'MSWin32') {
        *{ __PACKAGE__ . '::RUNNING_IN_HELL' } = sub { 1 };
    } else {
        *{ __PACKAGE__ . '::RUNNING_IN_HELL' } = sub { 0 };
    }
  }

  # POE runs better with Time::HiRes, but it also runs without it.
  { no strict 'refs';

    # Allow users to turn off Time::HiRes usage for whatever reason.
    my $time_hires_default = 1;
    $time_hires_default = $ENV{USE_TIME_HIRES} if defined $ENV{USE_TIME_HIRES};
    if (defined &USE_TIME_HIRES) {
      $time_hires_default = USE_TIME_HIRES();
    }
    else {
      *USE_TIME_HIRES = sub () { $time_hires_default };
    }
  }
}

# Second BEGIN block so that USE_TIME_HIRES is treated as a constant.
BEGIN {
  eval {
    require Time::HiRes;
    Time::HiRes->import(qw(time sleep));
  } if USE_TIME_HIRES();

  # Set up a "constant" sub that lets the user deactivate
  # automatic exception handling
  { no strict 'refs';
    unless (defined &CATCH_EXCEPTIONS) {
      my $catch_exceptions = (
        (exists $ENV{POE_CATCH_EXCEPTIONS})
        ? $ENV{POE_CATCH_EXCEPTIONS}
        : 1
      );

      if ($catch_exceptions) {
        *CATCH_EXCEPTIONS = sub () { 1 };
      }
      else {
        *CATCH_EXCEPTIONS = sub () { 0 };
      }
    }
  }

  { no strict 'refs';
    unless (defined &CHILD_POLLING_INTERVAL) {
      # That's one second, not a true value.
      *CHILD_POLLING_INTERVAL = sub () { 1 };
    }
  }

  { no strict 'refs';
    unless (defined &USE_SIGCHLD) {
      #if ( exists($INC{'Apache.pm'}) ) { # or unsafe signals
      *USE_SIGCHLD = sub () { 0 };
      #} else {
      #  *USE_SIGCHLD = sub () { 1 };
      #}
    }
  }
  { no strict 'refs';
    unless (defined &USE_SIGNAL_PIPE) {
      my $use_signal_pipe;
      if ( exists $ENV{POE_USE_SIGNAL_PIPE} ) {
        $use_signal_pipe = $ENV{POE_USE_SIGNAL_PIPE};
      }

      if (RUNNING_IN_HELL) {
        if ($use_signal_pipe) {
          _warn(
            "Sorry, disabling USE_SIGNAL_PIPE on $^O.\n",
            "Programs are reported to hang when it's enabled.\n",
          );
        }

        # Must be defined to supersede the default.
        $use_signal_pipe = 0;
      }

      if ($use_signal_pipe or not defined $use_signal_pipe) {
        *USE_SIGNAL_PIPE = sub () { 1 };
      }
      else {
        *USE_SIGNAL_PIPE = sub () { 0 };
      }
    }
  }
}

#==============================================================================
# Globals, or at least package-scoped things.  Data structures were
# moved into lexicals in 0.1201.

# A reference to the currently active session.  Used throughout the
# functions that act on the current session.
my $kr_active_session;
my $kr_active_event;
my $kr_active_event_type;

# Needs to be lexical so that POE::Resource::Events can see it
# change.  TODO - Something better?  Maybe we call a method in
# POE::Resource::Events to trigger the exception there?
use vars qw($kr_exception);

# The Kernel's master queue.
my $kr_queue;

# The current PID, to detect when it changes
my $kr_pid;

# Filehandle activity modes.  They are often used as list indexes.
sub MODE_RD () { 0 }  # read
sub MODE_WR () { 1 }  # write
sub MODE_EX () { 2 }  # exception/expedite

#------------------------------------------------------------------------------
# Kernel structure.  This is the root of a large data tree.  Dumping
# $poe_kernel with Data::Dumper or something will show most of the
# data that POE keeps track of.  The exceptions to this are private
# storage in some of the leaf objects, such as POE::Wheel.  All its
# members are described in detail further on.

sub KR_SESSIONS          () {  0 } # [ \%kr_sessions,
sub KR_FILENOS           () {  1 } #   \%kr_filenos,
sub KR_SIGNALS           () {  2 } #   \%kr_signals,
sub KR_ALIASES           () {  3 } #   \%kr_aliases,
sub KR_ACTIVE_SESSION    () {  4 } #   \$kr_active_session,
sub KR_QUEUE             () {  5 } #   \$kr_queue,
sub KR_ID                () {  6 } #   $unique_kernel_id,
sub KR_SESSION_IDS       () {  7 } #   \%kr_session_ids,
sub KR_SID_SEQ           () {  8 } #   \$kr_sid_seq,
sub KR_EXTRA_REFS        () {  9 } #   \$kr_extra_refs,
sub KR_SIZE              () { 10 } #   XXX UNUSED ???
sub KR_RUN               () { 11 } #   \$kr_run_warning
sub KR_ACTIVE_EVENT      () { 12 } #   \$kr_active_event
sub KR_PIDS              () { 13 } #   \%kr_pids_to_events
sub KR_ACTIVE_EVENT_TYPE () { 14 } #   \$kr_active_event_type
                                   # ]

# This flag indicates that POE::Kernel's run() method was called.
# It's used to warn about forgetting $poe_kernel->run().

sub KR_RUN_CALLED  () { 0x01 }  # $kernel->run() called
sub KR_RUN_SESSION () { 0x02 }  # sessions created
sub KR_RUN_DONE    () { 0x04 }  # run returned
my $kr_run_warning = 0;

#------------------------------------------------------------------------------
# Events themselves.

sub EV_SESSION    () { 0 }  # [ $destination_session,
sub EV_SOURCE     () { 1 }  #   $sender_session,
sub EV_NAME       () { 2 }  #   $event_name,
sub EV_TYPE       () { 3 }  #   $event_type,
sub EV_ARGS       () { 4 }  #   \@event_parameters_arg0_etc,
                            #
                            #   (These fields go towards the end
                            #   because they are optional in some
                            #   cases.  TODO: Is this still true?)
                            #
sub EV_OWNER_FILE () { 5 }  #   $caller_filename_where_enqueued,
sub EV_OWNER_LINE () { 6 }  #   $caller_line_where_enqueued,
sub EV_TIME       () { 7 }  #   Maintained by POE::Queue (create time)
sub EV_SEQ        () { 8 }  #   Maintained by POE::Queue (unique event ID)
                            # ]

# These are the names of POE's internal events.  They're in constants
# so we don't mistype them again.

sub EN_CHILD  () { '_child'           }
sub EN_GC     () { '_garbage_collect' }
sub EN_PARENT () { '_parent'          }
sub EN_SCPOLL () { '_sigchld_poll'    }
sub EN_SIGNAL () { '_signal'          }
sub EN_START  () { '_start'           }
sub EN_STAT   () { '_stat_tick'       }
sub EN_STOP   () { '_stop'            }

# These are POE's event classes (types).  They often shadow the event
# names themselves, but they can encompass a large group of events.
# For example, ET_ALARM describes anything enqueued as by an alarm
# call.  Types are preferred over names because bitmask tests are
# faster than string equality tests.

sub ET_POST   () { 0x0001 }  # User events (posted, yielded).
sub ET_CALL   () { 0x0002 }  # User events that weren't enqueued.
sub ET_START  () { 0x0004 }  # _start
sub ET_STOP   () { 0x0008 }  # _stop
sub ET_SIGNAL () { 0x0010 }  # _signal
sub ET_GC     () { 0x0020 }  # _garbage_collect
sub ET_PARENT () { 0x0040 }  # _parent
sub ET_CHILD  () { 0x0080 }  # _child
sub ET_SCPOLL () { 0x0100 }  # _sigchild_poll
sub ET_ALARM  () { 0x0200 }  # Alarm events.
sub ET_SELECT () { 0x0400 }  # File activity events.
sub ET_STAT   () { 0x0800 }  # Statistics gathering
sub ET_SIGCLD () { 0x1000 }  # sig_child() events.

# A mask for all events generated by/for users.
sub ET_MASK_USER () { ~(ET_GC | ET_SCPOLL | ET_STAT) }

# A mask for all events that are delayed by a dispatch time.
sub ET_MASK_DELAYED () { ET_ALARM | ET_SCPOLL }

# Temporary signal subtypes, used during signal dispatch semantics
# deprecation and reformation.

sub ET_SIGNAL_RECURSIVE () { 0x2000 }  # Explicitly requested signal.

# A hash of reserved names.  It's used to test whether someone is
# trying to use an internal event directly.

my %poes_own_events = (
  +EN_CHILD  => 1,
  +EN_GC     => 1,
  +EN_PARENT => 1,
  +EN_SCPOLL => 1,
  +EN_SIGNAL => 1,
  +EN_START  => 1,
  +EN_STOP   => 1,
  +EN_STAT   => 1,
);

# These are ways a child may come or go.
# TODO - It would be useful to split 'lose' into two types.  One to
# indicate that the child has stopped, and one to indicate that it was
# given away.

sub CHILD_GAIN   () { 'gain'   }  # The session was inherited from another.
sub CHILD_LOSE   () { 'lose'   }  # The session is no longer this one's child.
sub CHILD_CREATE () { 'create' }  # The session was created as a child of this.

# Argument offsets for different types of internally generated events.
# TODO Exporting (EXPORT_OK) these would let people stop depending on
# positions for them.

sub EA_SEL_HANDLE () { 0 }
sub EA_SEL_MODE   () { 1 }
sub EA_SEL_ARGS   () { 2 }

#------------------------------------------------------------------------------
# Debugging and configuration constants.

# Shorthand for defining a trace constant.
sub _define_trace {
  no strict 'refs';
  foreach my $name (@_) {
    next if defined *{"TRACE_$name"}{CODE};
    my $trace_value = &TRACE_DEFAULT;
    my $trace_name  = "TRACE_$name";
    *$trace_name = sub () { $trace_value };
  }
}

# Debugging flags for subsystems.  They're done as double evals here
# so that someone may define them before using POE::Kernel (or POE),
# and the pre-defined value will take precedence over the defaults
# here.

my $trace_file_handle;

BEGIN {
  # Shorthand for defining an assert constant.
  sub _define_assert {
    no strict 'refs';
    foreach my $name (@_) {
      next if defined *{"ASSERT_$name"}{CODE};
      my $assert_value = &ASSERT_DEFAULT;
      my $assert_name  = "ASSERT_$name";
      *$assert_name = sub () { $assert_value };
    }
  }

  # Assimilate POE_TRACE_* and POE_ASSERT_* environment variables.
  # Environment variables override everything else.
  while (my ($var, $val) = each %ENV) {
    next unless $var =~ /^POE_([A-Z_]+)$/;

    my $const = $1;

    next unless $const =~ /^(?:TRACE|ASSERT)_/ or do { no strict 'refs'; defined &$const };

    # Copy so we don't hurt our environment.
    my $value = $val;
    $value =~ tr['"][]d;
    $value = 0 + $value if $value =~ /^\s*-?\d+(?:\.\d+)?\s*$/;

    no strict 'refs';
    local $^W = 0;
    local $SIG{__WARN__} = sub { }; # redefine
    *$const = sub () { $value };
  }

  # TRACE_FILENAME is special.
  {
    no strict 'refs';
    my $trace_filename = TRACE_FILENAME() if defined &TRACE_FILENAME;
    if (defined $trace_filename) {
      open $trace_file_handle, ">$trace_filename"
        or die "can't open trace file `$trace_filename': $!";
      CORE::select((CORE::select($trace_file_handle), $| = 1)[0]);
    }
  }
  # TRACE_DEFAULT changes the default value for other TRACE_*
  # constants.  Since define_trace() uses TRACE_DEFAULT internally, it
  # can't be used to define TRACE_DEFAULT itself.

  defined &TRACE_DEFAULT or *TRACE_DEFAULT = sub () { 0 };

  _define_trace qw(
    EVENTS FILES PROFILE REFCNT RETVALS SESSIONS SIGNALS STATISTICS
  );

  # See the notes for TRACE_DEFAULT, except read ASSERT and assert
  # where you see TRACE and trace.

  defined &ASSERT_DEFAULT or *ASSERT_DEFAULT = sub () { 0 };

  _define_assert qw(DATA EVENTS FILES RETVALS USAGE);
}

# An "idle" POE::Kernel may still have events enqueued.  These events
# regulate polling for signals, profiling, and perhaps other aspects of
# POE::Kernel's internal workings.
#
# XXX - There must be a better mechanism.
#
my $idle_queue_size;

sub _idle_queue_grow   { $idle_queue_size++; }
sub _idle_queue_shrink { $idle_queue_size--; }
sub _idle_queue_size   { $idle_queue_size;   }
sub _idle_queue_reset  { $idle_queue_size = TRACE_STATISTICS ? 1 : 0; }

#------------------------------------------------------------------------------
# Helpers to carp, croak, confess, cluck, warn and die with whatever
# trace file we're using today.  _trap is reserved for internal
# errors.

{
  # This block abstracts away a particular piece of voodoo, since we're about
  # to call it many times. This is all a big closure around the following two
  # variables, allowing us to swap out and replace handlers without the need
  # for mucking up the namespace or the kernel itself.
  my ($orig_warn_handler, $orig_die_handler);

  # _trap_death replaces the current __WARN__ and __DIE__ handlers
  # with our own.  We keep the defaults around so we can put them back
  # when we're done.  Specifically this is necessary, it seems, for
  # older perls that don't respect the C<local *STDERR = *TRACE_FILE>.
  #
  # TODO - The __DIE__ handler generates a double message if
  # TRACE_FILE is STDERR and the die isn't caught by eval.  That's
  # messy and needs to go.
  sub _trap_death {
    if ($trace_file_handle) {
      $orig_warn_handler = $SIG{__WARN__};
      $orig_die_handler = $SIG{__DIE__};

      $SIG{__WARN__} = sub { print $trace_file_handle $_[0] };
      $SIG{__DIE__} = sub { print $trace_file_handle $_[0]; die $_[0]; };
    }
  }

  # _release_death puts the original __WARN__ and __DIE__ handlers back in
  # place. Hopefully this is zero-impact camping. The hope is that we can
  # do our trace magic without impacting anyone else.
  sub _release_death {
    if ($trace_file_handle) {
      $SIG{__WARN__} = $orig_warn_handler;
      $SIG{__DIE__} = $orig_die_handler;
    }
  }
}


sub _trap {
  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  local *STDERR = $trace_file_handle || *STDERR;

  _trap_death();
  confess(
    "-----\n",
    "Please address any warnings or errors above this message, and try\n",
    "again.  If there are none, or those messages are from within POE,\n",
    "then please mail them along with the following information\n",
    "to bug-POE\@rt.cpan.org:\n---\n@_\n-----\n"
  );
  _release_death();
}

sub _croak {
  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  local *STDERR = $trace_file_handle || *STDERR;

  _trap_death();
  croak @_;
  _release_death();
}

sub _confess {
  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  local *STDERR = $trace_file_handle || *STDERR;

  _trap_death();
  confess @_;
  _release_death();
}

sub _cluck {
  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  local *STDERR = $trace_file_handle || *STDERR;

  _trap_death();
  cluck @_;
  _release_death();
}

sub _carp {
  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  local *STDERR = $trace_file_handle || *STDERR;

  _trap_death();
  carp @_;
  _release_death();
}

sub _warn {
  my ($package, $file, $line) = caller();
  my $message = join("", @_);
  $message .= " at $file line $line\n" unless $message =~ /\n$/;

  _trap_death();
  $message =~ s/^/$$: /mg;
  warn $message;
  _release_death();
}

sub _die {
  my ($package, $file, $line) = caller();
  my $message = join("", @_);
  $message .= " at $file line $line\n" unless $message =~ /\n$/;
  local *STDERR = $trace_file_handle || *STDERR;

  _trap_death();
  $message =~ s/^/$$: /mg;
  die $message;
  _release_death();
}

#------------------------------------------------------------------------------
# Adapt POE::Kernel's personality to whichever event loop is present.

sub _find_loop {
  my ($mod) = @_;

  foreach my $dir (@INC) {
    return 1 if (-r "$dir/$mod");
  }
  return 0;
}

sub _load_loop {
  my $loop = shift;

  *poe_kernel_loop = sub { return "$loop" };

  # Modules can die with "not really dying" if they've loaded
  # something else.  This exception prevents the rest of the
  # originally used module from being parsed, so the module it's
  # handed off to takes over.
  eval "require $loop";
  if ($@ and $@ !~ /not really dying/) {
    die(
      "*\n",
      "* POE can't use $loop:\n",
      "* $@\n",
      "*\n",
    );
  }
}

sub _test_loop {
  my $used_first = shift;
  local $SIG{__DIE__} = "DEFAULT";

  # First see if someone wants to load a POE::Loop or XS version
  # explicitly.
  if (defined $used_first) {
    _load_loop($used_first);
    return;
  }

  foreach my $file (keys %INC) {
    next if (substr ($file, -3) ne '.pm');
    my @split_dirs = File::Spec->splitdir($file);

    # Create a module name by replacing the path separators with
    # underscores and removing ".pm"
    my $module = join("_", @split_dirs);
    substr($module, -3) = "";

    # Skip the module name if it isn't legal.
    next if $module =~ /[^\w\.]/;

    # Try for the XS version first.  If it fails, try the plain
    # version.  If that fails, we're up a creek.
    $module = "POE/XS/Loop/$module.pm";
    unless (_find_loop($module)) {
      $module =~ s|XS/||;
      next unless (_find_loop($module));
    }

    if (defined $used_first and $used_first ne $module) {
      die(
        "*\n",
        "* POE can't use multiple event loops at once.\n",
        "* You used $used_first and $module.\n",
        "* Specify the loop you want as an argument to POE\n",
        "*  use POE qw(Loop::Select);\n",
        "* or;\n",
        "*  use POE::Kernel { loop => 'Select' };\n",
        "*\n",
      );
    }

    $used_first = $module;
  }

  # No loop found.  Default to our internal select() loop.
  unless (defined $used_first) {
    $used_first = "POE/XS/Loop/Select.pm";
    unless (_find_loop($used_first)) {
      $used_first =~ s/XS\///;
    }
  }

  substr($used_first, -3) = "";
  $used_first =~ s|/|::|g;
  _load_loop($used_first);
}

#------------------------------------------------------------------------------
# Include resource modules here.  Later, when we have the option of XS
# versions, we'll adapt this to include them if they're available.

use POE::Resources;

###############################################################################
# Helpers.

### Resolve $whatever into a session reference, trying every method we
### can until something succeeds.

sub _resolve_session {
  my ($self, $whatever) = @_;
  my $session;

  # Resolve against sessions.
  $session = $self->_data_ses_resolve($whatever);
  return $session if defined $session;

  # Resolve against IDs.
  $session = $self->_data_sid_resolve($whatever);
  return $session if defined $session;

  # Resolve against aliases.
  $session = $self->_data_alias_resolve($whatever);
  return $session if defined $session;

  # Resolve against the Kernel itself.  Use "eq" instead of "==" here
  # because $whatever is often a string.
  return $whatever if $whatever eq $self;

  # We don't know what it is.
  return undef;
}

### Test whether POE has become idle.

sub _test_if_kernel_is_idle {
  my $self = shift;

  if (TRACE_REFCNT) {
    _warn(
      "<rc> ,----- Kernel Activity -----\n",
      "<rc> | Events : ", $kr_queue->get_item_count(),
      " (vs. idle size = ", $idle_queue_size, ")\n",
      "<rc> | Files  : ", $self->_data_handle_count(), "\n",
      "<rc> | Extra  : ", $self->_data_extref_count(), "\n",
      "<rc> | Procs  : ", $self->_data_sig_child_procs(), "\n",
      "<rc> `---------------------------\n",
      "<rc> ..."
     );
  }

  if( ASSERT_DATA ) {
    if( $kr_pid != $$ ) {
      _trap(
        "New process detected. " .
        "You must call ->has_forked() in the child process."
      );
    }
  }

  # Not yet idle, or SO idle that there's nothing to receive the
  # event.  Try to order these from most to least likely to be true so
  # that the tests short-circuit quickly.

  return if (
    $kr_queue->get_item_count() > $idle_queue_size or
    $self->_data_handle_count() or
    $self->_data_extref_count() or
    $self->_data_sig_child_procs() or
    !$self->_data_ses_count()
  );

  $self->_data_ev_enqueue(
    $self, $self, EN_SIGNAL, ET_SIGNAL, [ 'IDLE' ],
    __FILE__, __LINE__, undef, time(),
  );
}

### Explain why a session could not be resolved.

sub _explain_resolve_failure {
  my ($self, $whatever, $nonfatal) = @_;
  local $Carp::CarpLevel = 2;

  if (ASSERT_DATA and !$nonfatal) {
    _trap "<dt> Cannot resolve ``$whatever'' into a session reference";
  }

  $! = ESRCH;
  TRACE_RETVALS  and _carp "<rv> session not resolved: $!";
  ASSERT_RETVALS and _carp "<rv> session not resolved: $!";
}

### Explain why a function is returning unsuccessfully.

sub _explain_return {
  my ($self, $message) = @_;
  local $Carp::CarpLevel = 2;

  ASSERT_RETVALS and _confess "<rv> $message";
  TRACE_RETVALS  and _carp    "<rv> $message";
}

### Explain how the user made a mistake calling a function.

sub _explain_usage {
  my ($self, $message) = @_;
  local $Carp::CarpLevel = 2;

  ASSERT_USAGE   and _confess "<us> $message";
  ASSERT_RETVALS and _confess "<rv> $message";
  TRACE_RETVALS  and _carp    "<rv> $message";
}

#==============================================================================
# SIGNALS
#==============================================================================

#------------------------------------------------------------------------------
# Register or remove signals.

# Public interface for adding or removing signal handlers.

sub sig {
  my ($self, $signal, $event_name, @args) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call sig() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined signal in sig()" unless defined $signal;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved assigning it to a signal"
    ) if defined($event_name) and exists($poes_own_events{$event_name});
  };

  if (defined $event_name) {
    $self->_data_sig_add($kr_active_session, $signal, $event_name, \@args);
  }
  else {
    $self->_data_sig_remove($kr_active_session, $signal);
  }
}

# Public interface for posting signal events.
# TODO - Like post(), signal() should return

sub signal {
  my ($self, $dest_session, $signal, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined destination in signal()"
      unless defined $dest_session;
    _confess "<us> undefined signal in signal()" unless defined $signal;
  };

  my $session = $self->_resolve_session($dest_session);
  unless (defined $session) {
    $self->_explain_resolve_failure($dest_session);
    return;
  }

  $self->_data_ev_enqueue(
    $session, $kr_active_session,
    EN_SIGNAL, ET_SIGNAL, [ $signal, @etc ],
    (caller)[1,2], $kr_active_event, time(),
  );
  return 1;
}

# Public interface for flagging signals as handled.  This will replace
# the handlers' return values as an implicit flag.  Returns undef so
# it may be used as the last function in an event handler.

sub sig_handled {
  my $self = shift;
  $self->_data_sig_handled();

  if ($kr_active_event eq EN_SIGNAL) {
    _die(
      ",----- DEPRECATION ERROR -----\n",
      "| Session ", $self->_data_alias_loggable($kr_active_session), ":\n",
      "| handled a _signal event.  You must register a handler with sig().\n",
      "`-----------------------------\n",
    );
  }
}

# Attach a window or widget's destroy/closure to the UIDESTROY signal.

sub signal_ui_destroy {
  my ($self, $window) = @_;
  $self->loop_attach_uidestroy($window);
}

# Handle child PIDs being reaped.  Added 2006-09-15.

sub sig_child {
  my ($self, $pid, $event_name, @args) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call sig_chld() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined process ID in sig_chld()" unless defined $pid;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved assigning it to a signal"
    ) if defined($event_name) and exists($poes_own_events{$event_name});
  };

  if (defined $event_name) {
    $self->_data_sig_pid_watch($kr_active_session, $pid, $event_name, \@args);
  }
  elsif ($self->_data_sig_pids_is_ses_watching($kr_active_session, $pid)) {
    $self->_data_sig_pid_ignore($kr_active_session, $pid);
  }
}

#==============================================================================
# KERNEL
#==============================================================================

sub new {
  my $type = shift;

  # Prevent multiple instances, no matter how many times it's called.
  # This is a backward-compatibility enhancement for programs that
  # have used versions prior to 0.06.  It also provides a convenient
  # single entry point into the entirety of POE's state: point a
  # Dumper module at it, and you'll see a hideous tree of knowledge.
  # Be careful, though.  Its apples bite back.
  unless (defined $poe_kernel) {

    # Create our master queue.
    $kr_queue = $queue_class->new();

    # Remember the PID
    $kr_pid = $$;

    # TODO - Should KR_ACTIVE_SESSIONS and KR_ACTIVE_EVENT be handled
    # by POE::Resource::Sessions?
    # TODO - Should the subsystems be split off into separate real
    # objects, such as KR_QUEUE is?

    my $self = $poe_kernel = bless [
      undef,                  # KR_SESSIONS - from POE::Resource::Sessions
      undef,                  # KR_FILENOS - from POE::Resource::FileHandles
      undef,                  # KR_SIGNALS - from POE::Resource::Signals
      undef,                  # KR_ALIASES - from POE::Resource::Aliases
      \$kr_active_session,    # KR_ACTIVE_SESSION
      $kr_queue,              # KR_QUEUE - reference to an object
      undef,                  # KR_ID
      undef,                  # KR_SESSION_IDS - from POE::Resource::SIDS
      undef,                  # KR_SID_SEQ - from POE::Resource::SIDS
      undef,                  # KR_EXTRA_REFS
      undef,                  # KR_SIZE
      \$kr_run_warning,       # KR_RUN
      \$kr_active_event,      # KR_ACTIVE_EVENT
      undef,                  # KR_PIDS
      \$kr_active_event_type, # KR_ACTIVE_EVENT_TYPE
    ], $type;

    POE::Resources->load();

    $self->_data_sid_set($self->ID(), $self);

    # Initialize subsystems.  The order is important.

    # We need events before sessions, and the kernel's session before
    # it can start polling for signals.  Statistics gathering requires
    # a polling event as well, so it goes late.
    $self->_data_ev_initialize($kr_queue);
    $self->_initialize_kernel_session();
    $self->_data_stat_initialize() if TRACE_STATISTICS;
    $self->_data_sig_initialize();
    $self->_data_alias_initialize();

    # These other subsystems don't have strange interactions.
    $self->_data_handle_initialize($kr_queue);

    _idle_queue_reset();
  }

  # Return the global instance.
  $poe_kernel;
}

#------------------------------------------------------------------------------
# Send an event to a session right now.  Used by _disp_select to
# expedite select() events, and used by run() to deliver posted events
# from the queue.

# Dispatch an event to its session.  A lot of work goes on here.

sub _dispatch_event {
  my (
    $self,
    $session, $source_session, $event, $type, $etc,
    $file, $line, $fromstate, $time, $seq
  ) = @_;

  if (ASSERT_EVENTS) {
    _confess "<ev> undefined dest session" unless defined $session;
    _confess "<ev> undefined source session" unless defined $source_session;
  };

  if (TRACE_EVENTS) {
    my $log_session = $session;
    $log_session =  $self->_data_alias_loggable($session) unless (
      $type & ET_START
    );
    my $string_etc = join(" ", map { defined() ? $_ : "(undef)" } @$etc);
    _warn(
      "<ev> Dispatching event $seq ``$event'' ($string_etc) from ",
      $self->_data_alias_loggable($source_session), " to $log_session"
    );
  }

  $self->_stat_profile($event, $session) if TRACE_PROFILE;

  ### Pre-dispatch processing.

  # Some sessions don't do anything in _start and expect their
  # creators to provide a start-up event.  This means we can't
  # &_collect_garbage at _start time.  Instead, an ET_GC event is
  # posted as part of session allocation.  Simply dispatching it
  # will trigger a GC sweep.

  return 0 if $type & ET_GC;

  # Preprocess signals.  This is where _signal is translated into
  # its registered handler's event name, if there is one.

  if ($type & ET_SIGNAL) {
    my $signal = $etc->[0];

    if (TRACE_SIGNALS) {
      _warn(
        "<sg> dispatching ET_SIGNAL ($signal) to ",
        $self->_data_alias_loggable($session)
      );
    }

    # Step 1a: Reset the handled-signal flags.

    local @POE::Kernel::kr_signaled_sessions;
    local $POE::Kernel::kr_signal_total_handled;
    local $POE::Kernel::kr_signal_type;

    $self->_data_sig_reset_handled($signal);

    # Step 1b: Collect a list of sessions to receive the signal.

    my @touched_sessions = ($session);
    my $touched_index = 0;
    while ($touched_index < @touched_sessions) {
      my $next_target = $touched_sessions[$touched_index];
      push @touched_sessions, $self->_data_ses_get_children($next_target);
      $touched_index++;
    }

    # Step 1c: The DIE signal propagates up through parents, too.

    if ($signal eq "DIE") {
      my $next_target = $self->_data_ses_get_parent($session);
      while (defined($next_target) and $next_target != $self) {
        unshift @touched_sessions, $next_target;
        $next_target = $self->_data_ses_get_parent($next_target);
      }
    }

    # Step 2: Propagate the signal to the explicit watchers in the
    # child tree.  Ensure the full tree is touched regardless
    # whether there are explicit watchers.

    if ($self->_data_sig_explicitly_watched($signal)) {
      my %signal_watchers = $self->_data_sig_watchers($signal);

      $touched_index = @touched_sessions;
      while ($touched_index--) {
        my $target_session = $touched_sessions[$touched_index];
        $self->_data_sig_touched_session($target_session);

        next unless exists $signal_watchers{$target_session};
        my ($target_event, $target_etc) = @{$signal_watchers{$target_session}};

        if (TRACE_SIGNALS) {
          _warn(
            "<sg> propagating explicit signal $target_event ($signal) ",
            "(@$target_etc) to ", $self->_data_alias_loggable($target_session)
          );
        }

        # ET_SIGNAL_RECURSIVE is used here to avoid repropagating
        # the signal ad nauseam.
        $self->_dispatch_event(
          $target_session, $self,
          $target_event, ET_SIGNAL_RECURSIVE, [ @$etc, @$target_etc ],
          $file, $line, $fromstate, time(), -__LINE__
        );
      }
    }
    else {
      $touched_index = @touched_sessions;
      while ($touched_index--) {
        $self->_data_sig_touched_session($touched_sessions[$touched_index]);
      }
    }

    # Step 3: Check to see if the signal was handled.

    $self->_data_sig_free_terminated_sessions();

    # If the signal was SIGDIE, then propagate the exception.

    my $handled_session_count = (_data_sig_handled_status())[0];
    if ($signal eq "DIE" and !$handled_session_count) {
      $kr_exception = $etc->[1]{error_str};
    }

    # Signal completely dispatched.  Thanks for flying!
    return;
  }

  if (TRACE_EVENTS) {
    _warn(
    "<ev> dispatching event $seq ``$event'' to ",
      $self->_data_alias_loggable($session)
    );
    if ($event eq EN_SIGNAL) {
      _warn("<ev>     signal($etc->[0])");
    }
  }

  # Prepare to call the appropriate handler.  Push the current active
  # session on Perl's call stack.

  my ($hold_active_session, $hold_active_event, $hold_active_event_type) = (
    $kr_active_session, $kr_active_event, $kr_active_event_type
  );
  (
    $kr_active_session, $kr_active_event, $kr_active_event_type
  ) = ($session, $event, $type);

  # Dispatch the event, at long last.
  my $before;
  if (TRACE_STATISTICS) {
    $before = time();
  }

  # We only care about the return value and calling context if it's
  # ET_CALL.

  my $return;
  my $wantarray = wantarray();

  if ($type & (ET_CALL | ET_START | ET_STOP)) {
    eval {
      if ($wantarray) {
        $return = [
          $session->_invoke_state(
            $source_session, $event, $etc, $file, $line, $fromstate
          )
        ];
      }
      elsif (defined $wantarray) {
        $return = $session->_invoke_state(
          $source_session, $event, $etc, $file, $line, $fromstate
        );
      }
      else {
        $session->_invoke_state(
          $source_session, $event, $etc, $file, $line, $fromstate
        );
      }
    };
  }
  else {
    eval {
      $session->_invoke_state(
        $source_session, $event, $etc, $file, $line, $fromstate
      );
    };
  }

  # local $@ doesn't work quite the way I expect, but there is a
  # bit of a problem if an eval{} occurs here because a signal is
  # dispatched or something.

  if (CATCH_EXCEPTIONS) {
    if (ref($@) or $@ ne '') {
      my $exception = $@;
      if(TRACE_EVENTS) {
        _warn(
          "<ev> exception occurred in $event when invoked on ",
          $self->_data_alias_loggable($session)
        );
      }

      # Exceptions in _stop are rethrown unconditionally.
      # We can't enqueue them--the session is about to go away.
      if ($type & ET_STOP) {
        $kr_exception = $exception;
      }
      else {
        $self->_data_ev_enqueue(
          $session, $self, EN_SIGNAL, ET_SIGNAL, [
            'DIE' => {
              source_session => $source_session,
              dest_session => $session,
              event => $event,
              file => $file,
              line => $line,
              from_state => $fromstate,
              error_str => $exception,
            },
          ], __FILE__, __LINE__, undef, time()
        );
      }
    }
  }
  else {
    die "$@\n" if ref($@) or $@ ne '';
  }

  # Call with exception catching.

  # Clear out the event arguments list, in case there are POE-ish
  # things in it. This allows them to destruct happily before we set
  # the current session back.

  @$etc = ( );

  if (TRACE_STATISTICS) {
      my $after = time();
      my $elapsed = $after - $before;
      if ($type & ET_MASK_USER) {
        $self->_data_stat_add('user_seconds', $elapsed);
        $self->_data_stat_add('user_events', 1);
      }
  }

  # Stringify the handler's return value if it belongs in the POE
  # namespace.  $return's scope exists beyond the post-dispatch
  # processing, which includes POE's garbage collection.  The scope
  # bleed was known to break determinism in surprising ways.

  if (defined $return and substr(ref($return), 0, 5) eq 'POE::') {
    $return = "$return";
  }

  # Pop the active session and event, now that they're no longer
  # active.

  ($kr_active_session, $kr_active_event, $kr_active_event_type) = (
    $hold_active_session, $hold_active_event, $hold_active_event_type
  );

  if (TRACE_EVENTS) {
    my $string_ret = $return;
    $string_ret = "undef" unless defined $string_ret;
    _warn("<ev> event $seq ``$event'' returns ($string_ret)\n");
  }

  # Return doesn't matter unless ET_CALL, ET_START or ET_STOP.
  return unless $type & (ET_CALL | ET_START | ET_STOP);

  # Return what the handler did.  This is used for call().
  return( $wantarray ? @$return : $return );
}

#------------------------------------------------------------------------------
# POE's main loop!  Now with Tk and Event support!

# Do pre-run start-up.  Initialize the event loop, and allocate a
# session structure to represent the Kernel.

sub _initialize_kernel_session {
  my $self = shift;

  $self->loop_initialize();

  $kr_exception = undef;
  $kr_active_session = $self;
  $self->_data_ses_allocate($self, $self->ID(), undef);
}

# Do post-run cleanup.

sub _finalize_kernel {
  my $self = shift;

  # Disable signal watching since there's now no place for them to go.
  foreach ($self->_data_sig_get_safe_signals()) {
    $self->loop_ignore_signal($_);
  }

  # Remove the kernel session's signal watcher.
  $self->_data_sig_remove($self, "IDLE");

  # The main loop is done, no matter which event library ran it.
  # sig before loop so that it clears the signal_pipe file handler
  $self->_data_sig_finalize();
  $self->loop_finalize();
  $self->_data_extref_finalize();
  $self->_data_sid_finalize();
  $self->_data_alias_finalize();
  $self->_data_handle_finalize();
  $self->_data_ev_finalize();
  $self->_data_ses_finalize();
  $self->_data_stat_finalize() if TRACE_PROFILE or TRACE_STATISTICS;
}

sub run_while {
  my ($self, $scalar_ref) = @_;
  1 while $$scalar_ref and $self->run_one_timeslice();
}

sub run_one_timeslice {
  my $self = shift;

  unless ($self->_data_ses_count()) {
    $self->_finalize_kernel();
    $kr_run_warning |= KR_RUN_DONE;
    $kr_exception and $self->_rethrow_kr_exception();
    return;
  }

  $self->loop_do_timeslice();
  $kr_exception and $self->_rethrow_kr_exception();

  return 1;
}

sub run {
  # So run() can be called as a class method.
  POE::Kernel->new unless defined $poe_kernel;
  my $self = $poe_kernel;

  # Flag that run() was called.
  $kr_run_warning |= KR_RUN_CALLED;

  # Don't run the loop if we have no sessions
  # Loop::Event will blow up, so we're doing this sanity check
  if ( $self->_data_ses_count() == 0 ) {
    # Emit noise only if we are under debug mode
    if ( ASSERT_DATA ) {
      _warn("Not running the event loop because we have no sessions!\n");
    }
  } else {
    # All signals must be explicitly watched now.  We do it here because
    # it's too early in initialize_kernel_session.
    $self->_data_sig_add($self, "IDLE", EN_SIGNAL);

    # Run the loop!
    $self->loop_run();

    # Cleanup
    $self->_finalize_kernel();
  }

  # Clean up afterwards.
  $kr_run_warning |= KR_RUN_DONE;

  $kr_exception and $self->_rethrow_kr_exception();
}

sub _rethrow_kr_exception {
  my $self = shift;

  # Save the exception lexically.
  # Clear it so it doesn't linger if run() is called again.
  my $exception = $kr_exception;
  $kr_exception = undef;

  # Rethrow it.
  die $exception if $exception;
}

# Stops the kernel cold.  XXX Experimental!
# No events happen as a result of this, all structures are cleaned up
# except the kernel's.  Even the current session and POE::Kernel are
# cleaned up, which may introduce inconsistencies in the current
# session... as _dispatch_event() attempts to clean up for a defunct
# session.

sub stop {
  # So stop() can be called as a class method.
  my $self = $poe_kernel;

  # May be called when the kernel's already stopped.  Avoid problems
  # trying to find child sessions when the kernel isn't registered.
  if ($self->_data_ses_exists($self)) {
    my @children = ($self);
    foreach my $session (@children) {
      push @children, $self->_data_ses_get_children($session);
    }

    # Don't stop believin'.  Nor the POE::Kernel singleton.
    shift @children;

    # Walk backwards to avoid inconsistency errors.
    foreach my $session (reverse @children) {
      $self->_data_ses_free($session);
    }
  }

  # Roll back whether sessions were started.
  $kr_run_warning &= ~KR_RUN_SESSION;

  # So new sessions will not be child of the current defunct session.
  $kr_active_session = $self;

  # Undefined the kernel ID so it will be recalculated on the next
  # ID() call.
  $self->[KR_ID] = undef;

  # The GC mark list may prevent sessions from DESTROYing.
  # Clean it up.
  $self->_data_ses_gc_sweep();

  # Running stop() is recommended in a POE::Wheel::Run coderef
  # Program, before setting up for the next POE::Kernel->run().  When
  # the PID has changed, imply _data_sig_has_forked() during stop().

  $poe_kernel->has_forked unless $kr_pid == $$;

  # TODO - If we're polling for signals, then the reset gets it wrong.
  # The reset only counts statistics tracing, not sigchld polling.  If
  # we must put this back, it MUST account for all internal events
  # currently in play, or the child process will stall if it reruns
  # POE::Kernel's loop.
  #_idle_queue_reset();

  return;
}

# Less invasive form of ->stop() + ->run()
sub has_forked {
  if( $kr_pid == $$ ) {
    _croak "You should only call ->has_forked() from the child process.";
  }

  # So has_forked() can be called as a class method.
  my $self = $poe_kernel;

  # Undefine the kernel ID so it will be recalculated on the next
  # ID() call.
  $self->[KR_ID] = undef;
  $kr_pid = $$;

  # reset some stuff for the signals
  $poe_kernel->_data_sig_has_forked;
}

#------------------------------------------------------------------------------

sub DESTROY {
  my $self = shift;

  # Warn that a session never had the opportunity to run if one was
  # created but run() was never called.

  unless ($kr_run_warning & KR_RUN_CALLED) {
    if ($kr_run_warning & KR_RUN_SESSION) {
      _warn(
        "Sessions were started, but POE::Kernel's run() method was never\n",
        "called to execute them.  This usually happens because an error\n",
        "occurred before POE::Kernel->run() could be called.  Please fix\n",
        "any errors above this notice, and be sure that POE::Kernel->run()\n",
        "is called.  See documentation for POE::Kernel's run() method for\n",
        "another way to disable this warning.\n",
      );
    }
  }
}

#------------------------------------------------------------------------------
# _invoke_state is what _dispatch_event calls to dispatch a transition
# event.  This is the kernel's _invoke_state so it can receive events.
# These are mostly signals, which are propagated down in
# _dispatch_event.

sub _invoke_state {
  my ($self, $source_session, $event, $etc) = @_;

  # This is an event loop to poll for child processes without needing
  # to catch SIGCHLD.

  if ($event eq EN_SCPOLL) {
    $self->_data_sig_handle_poll_event($etc->[0]);
  }

  # A signal was posted.  Because signals propagate depth-first, this
  # _invoke_state is called last in the dispatch.  If the signal was
  # SIGIDLE, then post a SIGZOMBIE if the main queue is still idle.

  elsif ($event eq EN_SIGNAL) {
    if ($etc->[0] eq 'IDLE') {
      unless (
        $kr_queue->get_item_count() > $idle_queue_size or
        $self->_data_handle_count()
      ) {
        $self->_data_ev_enqueue(
          $self, $self, EN_SIGNAL, ET_SIGNAL, [ 'ZOMBIE' ],
          __FILE__, __LINE__, undef, time(),
        );
      }
    }
  }

  elsif ($event eq EN_STAT) {
    $self->_data_stat_tick();
  }

  return 0;
}

#==============================================================================
# SESSIONS
#==============================================================================

# Dispatch _start to a session, allocating it in the kernel's data
# structures as a side effect.

sub session_alloc {
  my ($self, $session, @args) = @_;

  # If we already returned, then we must reinitialize.  This is so
  # $poe_kernel->run() will work correctly more than once.
  if ($kr_run_warning & KR_RUN_DONE) {
    $kr_run_warning &= ~KR_RUN_DONE;
    $self->_initialize_kernel_session();
    $self->_data_stat_initialize() if TRACE_STATISTICS;
    $self->_data_sig_initialize();
  }

  if (ASSERT_DATA) {
    if ($self->_data_ses_exists($session)) {
      _trap(
        "<ss> ", $self->_data_alias_loggable($session), " already exists\a"
      );
    }
  }

  # Register that a session was created.
  $kr_run_warning |= KR_RUN_SESSION;

  # Allocate the session's data structure.  This must be done before
  # we dispatch anything regarding the new session.
  my $new_sid = $self->_data_sid_allocate();
  $self->_data_ses_allocate($session, $new_sid, $kr_active_session);

  my $loggable = $self->_data_alias_loggable($session);

  # Tell the new session that it has been created.  Catch the _start
  # state's return value so we can pass it to the parent with the
  # _child create.
  #
  # TODO - Void the context if the parent has no _child handler?

  my $return = $self->_dispatch_event(
    $session, $kr_active_session,
    EN_START, ET_START, \@args,
    __FILE__, __LINE__, undef, time(), -__LINE__
  );

  unless($self->_data_ses_exists($session)) {
    if(TRACE_SESSIONS) {
      _warn("<ss> ", $loggable, " disappeared during ", EN_START);
    }
    return $return;
  }

  # If the child has not detached itself---that is, if its parent is
  # the currently active session---then notify the parent with a
  # _child create event.  Otherwise skip it, since we'd otherwise
  # throw a create without a lose.
  $self->_dispatch_event(
    $self->_data_ses_get_parent($session), $self,
    EN_CHILD, ET_CHILD, [ CHILD_CREATE, $session, $return ],
    __FILE__, __LINE__, undef, time(), -__LINE__
  );

  unless($self->_data_ses_exists($session)) {
    if(TRACE_SESSIONS) {
      _warn("<ss> ", $loggable, " disappeared during ", EN_CHILD, " dispatch");
    }
    return $return;
  }

  # Enqueue a delayed garbage-collection event so the session has time
  # to do its thing before it goes.
  $self->_data_ev_enqueue(
    $session, $session, EN_GC, ET_GC, [],
    __FILE__, __LINE__, undef, time(),
  );
}

# Detach a session from its parent.  This breaks the parent/child
# relationship between the current session and its parent.  Basically,
# the current session is given to the Kernel session.  Unlike with
# _stop, the current session's children follow their parent.

sub detach_myself {
  my $self = shift;

  if (ASSERT_USAGE) {
    _confess "<us> must call detach_myself() from a running session"
      if $kr_active_session == $self;
  }

  # Can't detach from the kernel.
  if ($self->_data_ses_get_parent($kr_active_session) == $self) {
    $! = EPERM;
    return;
  }

  my $old_parent = $self->_data_ses_get_parent($kr_active_session);

  # Tell the old parent session that the child is departing.
  # But not if the active event is ET_START, since that would generate
  # a CHILD_LOSE without a CHILD_CREATE.
  $self->_dispatch_event(
    $old_parent, $self,
    EN_CHILD, ET_CHILD, [ CHILD_LOSE, $kr_active_session, undef ],
    (caller)[1,2], undef, time(), -__LINE__
  )
  unless $kr_active_event_type & ET_START;

  # Tell the new parent (kernel) that it's gaining a child.
  # (Actually it doesn't care, so we don't do that here, but this is
  # where the code would go if it ever does in the future.)

  # Tell the current session that its parentage is changing.
  $self->_dispatch_event(
    $kr_active_session, $self,
    EN_PARENT, ET_PARENT, [ $old_parent, $self ],
    (caller)[1,2], undef, time(), -__LINE__
  );

  $self->_data_ses_move_child($kr_active_session, $self);

  # Success!
  return 1;
}

# Detach a child from this, the parent.  The session being detached
# must be a child of the current session.

sub detach_child {
  my ($self, $child) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call detach_child() from a running session"
      if $kr_active_session == $self;
  }

  my $child_session = $self->_resolve_session($child);
  unless (defined $child_session) {
    $self->_explain_resolve_failure($child);
    return;
  }

  # Can't detach if it belongs to the kernel.  TODO We shouldn't need
  # to check for this.
  if ($kr_active_session == $self) {
    $! = EPERM;
    return;
  }

  # Can't detach if it's not a child of the current session.
  unless ($self->_data_ses_is_child($kr_active_session, $child_session)) {
    $! = EPERM;
    return;
  }

  # Tell the current session that the child is departing.
  $self->_dispatch_event(
    $kr_active_session, $self,
    EN_CHILD, ET_CHILD, [ CHILD_LOSE, $child_session, undef ],
    (caller)[1,2], undef, time(), -__LINE__
  );

  # Tell the new parent (kernel) that it's gaining a child.
  # (Actually it doesn't care, so we don't do that here, but this is
  # where the code would go if it ever does in the future.)

  # Tell the child session that its parentage is changing.
  $self->_dispatch_event(
    $child_session, $self,
    EN_PARENT, ET_PARENT, [ $kr_active_session, $self ],
    (caller)[1,2], undef, time(), -__LINE__
  );

  $self->_data_ses_move_child($child_session, $self);

  # Success!
  return 1;
}

### Helpful accessors.

sub get_active_session {
  return $kr_active_session;
}

sub get_active_event {
  return $kr_active_event;
}

# FIXME - Should this exist?
sub get_event_count {
  return $kr_queue->get_item_count();
}

# FIXME - Should this exist?
sub get_next_event_time {
  return $kr_queue->get_next_priority();
}

#==============================================================================
# EVENTS
#==============================================================================

#------------------------------------------------------------------------------
# Post an event to the queue.

sub post {
  my ($self, $dest_session, $event_name, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> destination is undefined in post()"
      unless defined $dest_session;
    _confess "<us> event is undefined in post()" unless defined $event_name;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by posting it"
    ) if exists $poes_own_events{$event_name};
  };

  # Attempt to resolve the destination session reference against
  # various things.

  my $session = $self->_resolve_session($dest_session);
  unless (defined $session) {
    $self->_explain_resolve_failure($dest_session);
    return;
  }

  # Enqueue the event for "now", which simulates FIFO in our
  # time-ordered queue.

  $self->_data_ev_enqueue(
    $session, $kr_active_session, $event_name, ET_POST, \@etc,
    (caller)[1,2], $kr_active_event, time(),
  );
  return 1;
}

#------------------------------------------------------------------------------
# Post an event to the queue for the current session.

sub yield {
  my ($self, $event_name, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call yield() from a running session"
      if $kr_active_session == $self;
    _confess "<us> event name is undefined in yield()"
      unless defined $event_name;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by yielding it"
    ) if exists $poes_own_events{$event_name};
  };

  $self->_data_ev_enqueue(
    $kr_active_session, $kr_active_session, $event_name, ET_POST, \@etc,
    (caller)[1,2], $kr_active_event, time(),
  );

  undef;
}

#------------------------------------------------------------------------------
# Call an event handler directly.

sub call {
  my ($self, $dest_session, $event_name, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> destination is undefined in call()"
      unless defined $dest_session;
    _confess "<us> event is undefined in call()" unless defined $event_name;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by calling it"
    ) if exists $poes_own_events{$event_name};
  };

  # Attempt to resolve the destination session reference against
  # various things.

  my $session = $self->_resolve_session($dest_session);
  unless (defined $session) {
    $self->_explain_resolve_failure($dest_session);
    return;
  }

  # Dispatch the event right now, bypassing the queue altogether.
  # This tends to be a Bad Thing to Do.

  # TODO The difference between synchronous and asynchronous events
  # should be made more clear in the documentation, so that people
  # have a tendency not to abuse them.  I discovered in xws that that
  # mixing the two types makes it harder than necessary to write
  # deterministic programs, but the difficulty can be ameliorated if
  # programmers set some base rules and stick to them.

  $self->_stat_profile($event_name, $session) if TRACE_PROFILE;

  if (wantarray) {
    my @return_value = (
      ($session == $kr_active_session)
      ? $session->_invoke_state(
        $session, $event_name, \@etc, (caller)[1,2],
        $kr_active_event
      )
      : $self->_dispatch_event(
        $session, $kr_active_session,
        $event_name, ET_CALL, \@etc,
        (caller)[1,2], $kr_active_event, time(), -__LINE__
      )
    );

    $self->_data_ses_gc_sweep();

    $! = 0;
    return @return_value;
  }

  if (defined wantarray) {
    my $return_value = (
      $session == $kr_active_session
      ? $session->_invoke_state(
        $session, $event_name, \@etc, (caller)[1,2],
        $kr_active_event
      )
      : $self->_dispatch_event(
        $session, $kr_active_session,
        $event_name, ET_CALL, \@etc,
        (caller)[1,2], $kr_active_event, time(), -__LINE__
      )
    );

    $self->_data_ses_gc_sweep();

    $! = 0;
    return $return_value;
  }

  if ($session == $kr_active_session) {
    $session->_invoke_state(
      $session, $event_name, \@etc, (caller)[1,2],
      $kr_active_event
    );
  }
  else {
    $self->_dispatch_event(
      $session, $kr_active_session,
      $event_name, ET_CALL, \@etc,
      (caller)[1,2], $kr_active_event, time(), -__LINE__
    );
  }

  $! = 0;
  return;
}

#==============================================================================
# DELAYED EVENTS
#==============================================================================

sub alarm {
  my ($self, $event_name, $time, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call alarm() from a running session"
      if $kr_active_session == $self;
    _confess "<us> event name is undefined in alarm()"
      unless defined $event_name;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by setting an alarm for it"
    ) if exists $poes_own_events{$event_name};
  };

  unless (defined $event_name) {
    $self->_explain_return("invalid parameter to alarm() call");
    return EINVAL;
  }

  $self->_data_ev_clear_alarm_by_name($kr_active_session, $event_name);

  # Add the new alarm if it includes a time.  Calling _data_ev_enqueue
  # directly is faster than calling alarm_set to enqueue it.
  if (defined $time) {
    $self->_data_ev_enqueue
      ( $kr_active_session, $kr_active_session,
        $event_name, ET_ALARM, [ @etc ],
        (caller)[1,2], $kr_active_event, $time,
      );
  }
  else {
    # The event queue has become empty?  Stop the time watcher.
    $self->loop_pause_time_watcher() unless $kr_queue->get_item_count();
  }

  return 0;
}

# Add an alarm without clobbering previous alarms of the same name.
sub alarm_add {
  my ($self, $event_name, $time, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call alarm_add() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined event name in alarm_add()"
      unless defined $event_name;
    _confess "<us> undefined time in alarm_add()" unless defined $time;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by adding an alarm for it"
    ) if exists $poes_own_events{$event_name};
  };

  unless (defined $event_name and defined $time) {
    $self->_explain_return("invalid parameter to alarm_add() call");
    return EINVAL;
  }

  $self->_data_ev_enqueue
    ( $kr_active_session, $kr_active_session,
      $event_name, ET_ALARM, [ @etc ],
      (caller)[1,2], $kr_active_event, $time,
    );

  return 0;
}

# Add a delay, which is just an alarm relative to the current time.
sub delay {
  my ($self, $event_name, $delay, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call delay() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined event name in delay()" unless defined $event_name;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by setting a delay for it"
    ) if exists $poes_own_events{$event_name};
  };

  unless (defined $event_name) {
    $self->_explain_return("invalid parameter to delay() call");
    return EINVAL;
  }

  if (defined $delay) {
    $self->alarm($event_name, time() + $delay, @etc);
  }
  else {
    $self->alarm($event_name);
  }

  return 0;
}

# Add a delay without clobbering previous delays of the same name.
sub delay_add {
  my ($self, $event_name, $delay, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call delay_add() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined event name in delay_add()"
      unless defined $event_name;
    _confess "<us> undefined time in delay_add()" unless defined $delay;
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by adding a delay for it"
    ) if exists $poes_own_events{$event_name};
  };

  unless (defined $event_name and defined $delay) {
    $self->_explain_return("invalid parameter to delay_add() call");
    return EINVAL;
  }

  $self->alarm_add($event_name, time() + $delay, @etc);

  return 0;
}

#------------------------------------------------------------------------------
# New style alarms.

# Set an alarm.  This does more *and* less than plain alarm().  It
# only sets alarms (that's the less part), but it also returns an
# alarm ID (that's the more part).

sub alarm_set {
  my ($self, $event_name, $time, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call alarm_set() from a running session"
      if $kr_active_session == $self;
  }

  unless (defined $event_name) {
    $self->_explain_usage("undefined event name in alarm_set()");
    $! = EINVAL;
    return;
  }

  unless (defined $time) {
    $self->_explain_usage("undefined time in alarm_set()");
    $! = EINVAL;
    return;
  }

  if (ASSERT_USAGE) {
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by setting an alarm for it"
    ) if exists $poes_own_events{$event_name};
  }

  return $self->_data_ev_enqueue
    ( $kr_active_session, $kr_active_session, $event_name, ET_ALARM, [ @etc ],
      (caller)[1,2], $kr_active_event, $time,
    );
}

# Remove an alarm by its ID.  TODO Now that alarms and events have
# been recombined, this will remove an event by its ID.  However,
# nothing returns an event ID, so nobody knows what to remove.

sub alarm_remove {
  my ($self, $alarm_id) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call alarm_remove() from a running session"
      if $kr_active_session == $self;
  }

  unless (defined $alarm_id) {
    $self->_explain_usage("undefined alarm id in alarm_remove()");
    $! = EINVAL;
    return;
  }

  my ($time, $event) =
    $self->_data_ev_clear_alarm_by_id($kr_active_session, $alarm_id);
  return unless defined $time;

  # In a list context, return the alarm that was removed.  In a scalar
  # context, return a reference to the alarm that was removed.  In a
  # void context, return nothing.  Either way this returns a defined
  # value when someone needs something useful from it.

  return unless defined wantarray;
  return ( $event->[EV_NAME], $time, @{$event->[EV_ARGS]} ) if wantarray;
  return [ $event->[EV_NAME], $time, @{$event->[EV_ARGS]} ];
}

# Move an alarm to a new time.  This virtually removes the alarm and
# re-adds it somewhere else.  In reality, adjust_priority() is
# optimized for this sort of thing.

sub alarm_adjust {
  my ($self, $alarm_id, $delta) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call alarm_adjust() from a running session"
      if $kr_active_session == $self;
  }

  unless (defined $alarm_id) {
    $self->_explain_usage("undefined alarm id in alarm_adjust()");
    $! = EINVAL;
    return;
  }

  unless (defined $delta) {
    $self->_explain_usage("undefined alarm delta in alarm_adjust()");
    $! = EINVAL;
    return;
  }

  my $my_alarm = sub {
    $_[0]->[EV_SESSION] == $kr_active_session;
  };
  return $kr_queue->adjust_priority($alarm_id, $my_alarm, $delta);
}

# A convenient function for setting alarms relative to now.  It also
# uses whichever time() POE::Kernel can find, which may be
# Time::HiRes'.

sub delay_set {
  # Always always always grab time() ASAP, so that the eventual
  # time we set the alarm for is as close as possible to the time
  # at which they ASKED for the delay, not when we actually set it.
  my $t = time();

  # And now continue as normal
  my ($self, $event_name, $seconds, @etc) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call delay_set() from a running session"
      if $kr_active_session == $self;
  }

  unless (defined $event_name) {
    $self->_explain_usage("undefined event name in delay_set()");
    $! = EINVAL;
    return;
  }

  if (ASSERT_USAGE) {
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by setting a delay for it"
    ) if exists $poes_own_events{$event_name};
  }

  unless (defined $seconds) {
    $self->_explain_usage("undefined seconds in delay_set()");
    $! = EINVAL;
    return;
  }

  return $self->_data_ev_enqueue
    ( $kr_active_session, $kr_active_session, $event_name, ET_ALARM, [ @etc ],
      (caller)[1,2], $kr_active_event, $t + $seconds,
    );
}

# Move a delay to a new offset from time().  As with alarm_adjust(),
# this is optimized internally for this sort of activity.

sub delay_adjust {
  my ($self, $alarm_id, $seconds) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call delay_adjust() from a running session"
      if $kr_active_session == $self;
  }

  unless (defined $alarm_id) {
    $self->_explain_usage("undefined delay id in delay_adjust()");
    $! = EINVAL;
    return;
  }

  unless (defined $seconds) {
    $self->_explain_usage("undefined delay seconds in delay_adjust()");
    $! = EINVAL;
    return;
  }

  my $my_delay = sub {
    $_[0]->[EV_SESSION] == $kr_active_session;
  };

  if (TRACE_EVENTS) {
    _warn("<ev> adjusted event $alarm_id by $seconds seconds");
  }

  return $kr_queue->set_priority($alarm_id, $my_delay, time() + $seconds);
}

# Remove all alarms for the current session.

sub alarm_remove_all {
  my $self = shift;

  if (ASSERT_USAGE) {
    _confess "<us> must call alarm_remove_all() from a running session"
      if $kr_active_session == $self;
  }

  # This should never happen, actually.
  _trap "unknown session in alarm_remove_all call"
    unless $self->_data_ses_exists($kr_active_session);

  # Free every alarm owned by the session.  This code is ripped off
  # from the _stop code to flush everything.

  my @removed = $self->_data_ev_clear_alarm_by_session($kr_active_session);

  return unless defined wantarray;
  return @removed if wantarray;
  return \@removed;
}

#==============================================================================
# SELECTS
#==============================================================================

sub _internal_select {
  my ($self, $session, $handle, $event_name, $mode, $args) = @_;

  # If an event is included, then we're defining a filehandle watcher.

  if ($event_name) {
    $self->_data_handle_add($handle, $mode, $session, $event_name, $args);
  }
  else {
    $self->_data_handle_remove($handle, $mode, $session);
  }
}

# A higher-level select() that manipulates read, write and expedite
# selects together.

sub select {
  my ($self, $handle, $event_r, $event_w, $event_e, @args) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select()" unless defined $handle;
    _confess "<us> invalid filehandle in select()"
      unless defined fileno($handle);
    foreach ($event_r, $event_w, $event_e) {
      next unless defined $_;
      _carp(
        "<us> The '$_' event is one of POE's own.  Its " .
        "effect cannot be achieved by setting a file watcher to it"
      ) if exists($poes_own_events{$_});
    }
  }

  $self->_internal_select(
    $kr_active_session, $handle, $event_r, MODE_RD, \@args
  );
  $self->_internal_select(
    $kr_active_session, $handle, $event_w, MODE_WR, \@args
  );
  $self->_internal_select(
    $kr_active_session, $handle, $event_e, MODE_EX, \@args
  );
  return 0;
}

# Only manipulate the read select.
sub select_read {
  my ($self, $handle, $event_name, @args) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select_read() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select_read()"
      unless defined $handle;
    _confess "<us> invalid filehandle in select_read()"
      unless defined fileno($handle);
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by setting a file watcher to it"
    ) if defined($event_name) and exists($poes_own_events{$event_name});
  };

  $self->_internal_select(
    $kr_active_session, $handle, $event_name, MODE_RD, \@args
  );
  return 0;
}

# Only manipulate the write select.
sub select_write {
  my ($self, $handle, $event_name, @args) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select_write() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select_write()"
      unless defined $handle;
    _confess "<us> invalid filehandle in select_write()"
      unless defined fileno($handle);
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by setting a file watcher to it"
    ) if defined($event_name) and exists($poes_own_events{$event_name});
  };

  $self->_internal_select(
    $kr_active_session, $handle, $event_name, MODE_WR, \@args
  );
  return 0;
}

# Only manipulate the expedite select.
sub select_expedite {
  my ($self, $handle, $event_name, @args) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select_expedite() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select_expedite()"
      unless defined $handle;
    _confess "<us> invalid filehandle in select_expedite()"
      unless defined fileno($handle);
    _carp(
      "<us> The '$event_name' event is one of POE's own.  Its " .
      "effect cannot be achieved by setting a file watcher to it"
    ) if defined($event_name) and exists($poes_own_events{$event_name});
  };

  $self->_internal_select(
    $kr_active_session, $handle, $event_name, MODE_EX, \@args
  );
  return 0;
}

# Turn off a handle's write mode bit without doing
# garbage-collection things.
sub select_pause_write {
  my ($self, $handle) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select_pause_write() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select_pause_write()"
      unless defined $handle;
    _confess "<us> invalid filehandle in select_pause_write()"
      unless defined fileno($handle);
  };

  return 0 unless $self->_data_handle_is_good($handle, MODE_WR);

  $self->_data_handle_pause($handle, MODE_WR);

  return 1;
}

# Turn on a handle's write mode bit without doing garbage-collection
# things.
sub select_resume_write {
  my ($self, $handle) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select_resume_write() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select_resume_write()"
      unless defined $handle;
    _confess "<us> invalid filehandle in select_resume_write()"
      unless defined fileno($handle);
  };

  return 0 unless $self->_data_handle_is_good($handle, MODE_WR);

  $self->_data_handle_resume($handle, MODE_WR);

  return 1;
}

# Turn off a handle's read mode bit without doing garbage-collection
# things.
sub select_pause_read {
  my ($self, $handle) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select_pause_read() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select_pause_read()"
      unless defined $handle;
    _confess "<us> invalid filehandle in select_pause_read()"
      unless defined fileno($handle);
  };

  return 0 unless $self->_data_handle_is_good($handle, MODE_RD);

  $self->_data_handle_pause($handle, MODE_RD);

  return 1;
}

# Turn on a handle's read mode bit without doing garbage-collection
# things.
sub select_resume_read {
  my ($self, $handle) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> must call select_resume_read() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined filehandle in select_resume_read()"
      unless defined $handle;
    _confess "<us> invalid filehandle in select_resume_read()"
      unless defined fileno($handle);
  };

  return 0 unless $self->_data_handle_is_good($handle, MODE_RD);

  $self->_data_handle_resume($handle, MODE_RD);

  return 1;
}

#==============================================================================
# Aliases: These functions expose the internal alias accessors with
# extra fun parameter/return value checking.
#==============================================================================

### Set an alias in the current session.

sub alias_set {
  my ($self, $name) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined alias in alias_set()" unless defined $name;
  };

  # Don't overwrite another session's alias.
  my $existing_session = $self->_data_alias_resolve($name);
  if (defined $existing_session) {
    if ($existing_session != $kr_active_session) {
      $self->_explain_usage("alias '$name' is in use by another session");
      return EEXIST;
    }
    return 0;
  }

  $self->_data_alias_add($kr_active_session, $name);
  return 0;
}

### Remove an alias from the current session.

sub alias_remove {
  my ($self, $name) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined alias in alias_remove()" unless defined $name;
  };

  my $existing_session = $self->_data_alias_resolve($name);

  unless (defined $existing_session) {
    $self->_explain_usage("alias does not exist");
    return ESRCH;
  }

  if ($existing_session != $kr_active_session) {
    $self->_explain_usage("alias does not belong to current session");
    return EPERM;
  }

  $self->_data_alias_remove($kr_active_session, $name);
  return 0;
}

### Resolve an alias into a session.

sub alias_resolve {
  my ($self, $name) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined alias in alias_resolve()" unless defined $name;
  };

  my $session = $self->_resolve_session($name);
  unless (defined $session) {
    $self->_explain_resolve_failure($name, "nonfatal");
    return;
  }

  $session;
}

### List the aliases for a given session.

sub alias_list {
  my ($self, $search_session) = @_;
  my $session =
    $self->_resolve_session($search_session || $kr_active_session);

  unless (defined $session) {
    $self->_explain_resolve_failure($search_session, "nonfatal");
    return;
  }

  # Return whatever can be found.
  my @alias_list = $self->_data_alias_list($session);
  return wantarray() ? @alias_list : $alias_list[0];
}

#==============================================================================
# Kernel and Session IDs
#==============================================================================

# Return the Kernel's "unique" ID.  There's only so much uniqueness
# available; machines on separate private 10/8 networks may have
# identical kernel IDs.  The chances of a collision are vanishingly
# small.

# The Kernel and Session IDs are based on Philip Gwyn's code.  I hope
# he still can recognize it.

sub ID {
  my $self = shift;

  # Recalculate the kernel ID if necessary.  stop() undefines it.
  unless (defined $self->[KR_ID]) {
    my $hostname = eval { (uname)[1] };
    $hostname = hostname() unless defined $hostname;
    $self->[KR_ID] = $hostname . '-' .  unpack('H*', pack('N*', time(), $$));
  }

  return $self->[KR_ID];
}

# Resolve an ID to a session reference.  This function is virtually
# moot now that _resolve_session does it too.  This explicit call will
# be faster, though, so it's kept for things that can benefit from it.

sub ID_id_to_session {
  my ($self, $id) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined ID in ID_id_to_session()" unless defined $id;
  };

  my $session = $self->_data_sid_resolve($id);
  return $session if defined $session;

  $self->_explain_return("ID does not exist");
  $! = ESRCH;
  return;
}

# Resolve a session reference to its corresponding ID.

sub ID_session_to_id {
  my ($self, $session) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined session in ID_session_to_id()"
      unless defined $session;
  };

  my $id = $self->_data_ses_resolve_to_id($session);
  if (defined $id) {
    $! = 0;
    return $id;
  }

  $self->_explain_return("session ($session) does not exist");
  $! = ESRCH;
  return;
}

#==============================================================================
# Extra reference counts, to keep sessions alive when things occur.
# They take session IDs because they may be called from resources at
# times where the session reference is otherwise unknown.
#==============================================================================

sub refcount_increment {
  my ($self, $session_id, $tag) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined session ID in refcount_increment()"
      unless defined $session_id;
    _confess "<us> undefined reference count tag in refcount_increment()"
      unless defined $tag;
  };

  my $session = $self->_data_sid_resolve($session_id);
  unless (defined $session) {
    $self->_explain_return("session id $session_id does not exist");
    $! = ESRCH;
    return;
  }

  my $refcount = $self->_data_extref_inc($session, $tag);
  # TODO trace it here
  return $refcount;
}

sub refcount_decrement {
  my ($self, $session_id, $tag) = @_;

  if (ASSERT_USAGE) {
    _confess "<us> undefined session ID in refcount_decrement()"
      unless defined $session_id;
    _confess "<us> undefined reference count tag in refcount_decrement()"
      unless defined $tag;
  };

  my $session = $self->_data_sid_resolve($session_id);
  unless (defined $session) {
    $self->_explain_return("session id $session_id does not exist");
    $! = ESRCH;
    return;
  }

  my $refcount = $self->_data_extref_dec($session, $tag);

  # TODO trace it here
  return $refcount;
}

#==============================================================================
# HANDLERS
#==============================================================================

# Add or remove event handlers from sessions.
sub state {
  my ($self, $event, $state_code, $state_alias) = @_;
  $state_alias = $event unless defined $state_alias;

  if (ASSERT_USAGE) {
    _confess "<us> must call state() from a running session"
      if $kr_active_session == $self;
    _confess "<us> undefined event name in state()" unless defined $event;
    _confess "<us> can't call state() outside a session" if (
      $kr_active_session == $self
    );
  };

  if (
    (ref($kr_active_session) ne '') &&
    (ref($kr_active_session) ne 'POE::Kernel')
  ) {
    $kr_active_session->_register_state($event, $state_code, $state_alias);
    return 0;
  }

  # TODO A terminal signal (such as UIDESTROY) kills a session.  The
  # Kernel deallocates the session, which cascades destruction to its
  # HEAP.  That triggers a Wheel's destruction, which calls
  # $kernel->state() to remove a state from the session.  The session,
  # though, is already gone.  If TRACE_RETVALS and/or ASSERT_RETVALS
  # is set, this causes a warning or fatal error.

  $self->_explain_return("session ($kr_active_session) does not exist");
  return ESRCH;
}

1;

__END__

=head1 NAME

POE::Kernel - an event-based application kernel in Perl

=head1 SYNOPSIS

  use POE; # auto-includes POE::Kernel and POE::Session

  POE::Session->create(
    inline_states => {
      _start => sub { $_[KERNEL]->yield("next") },
      next   => sub {
        print "tick...\n";
        $_[KERNEL]->delay(next => 1);
      },
    },
  );

  POE::Kernel->run();
  exit;

In the spirit of Perl, there are a lot of other ways to use POE.

=head1 DESCRIPTION

POE::Kernel is the heart of POE.  It provides the lowest-level
features: non-blocking multiplexed I/O, timers, and signal watchers
are the most significant.  Everything else is built upon this
foundation.

POE::Kernel is not an event loop in itself.  For that it uses one of
several available POE::Loop interface modules.  See CPAN for modules
in the POE::Loop namespace.

POE's documentation assumes the reader understands the @_ offset
constants (KERNEL, HEAP, ARG0, etc.).  The curious or confused reader
will find more detailed explanation in L<POE::Session>.

=head1 USING POE

=head2 Literally Using POE

POE.pm is little more than a class loader.  It implements some magic
to cut down on the setup work.

Parameters to C<use POE> are not treated as normal imports.  Rather,
they're abbreviated modules to be included along with POE.

  use POE qw(Component::Client::TCP).

As you can see, the leading "POE::" can be omitted this way.

POE.pm also includes POE::Kernel and POE::Session by default.  These
two modules are used by nearly all POE-based programs.  So the above
example is actually the equivalent of:

  use POE;
  use POE::Kernel;
  use POE::Session;
  use POE::Component::Client::TCP;

=head2 Using POE::Kernel

POE::Kernel needs to know which event loop you want to use.  This is
supported in three different ways:

The first way is to use an event loop module before using POE::Kernel
(or POE, which loads POE::Kernel for you):

  use Tk; # or one of several others
  use POE::Kernel.

POE::Kernel scans the list of modules already loaded, and it loads an
appropriate POE::Loop adapter if it finds a known event loop.

The next way is to explicitly load the POE::Loop class you want:

  use POE qw(Loop::Gtk);

Finally POE::Kernel's C<import()> supports more programmer-friendly
configuration:

  use POE::Kernel { loop => "Gtk" };
  use POE::Session;

=head2 Anatomy of a POE-Based Application

Programs using POE work like any other.  They load required modules,
perform some setup, run some code, and eventually exit.  Halting
Problem notwithstanding.

A POE-based application loads some modules, sets up one or more
sessions, runs the code in those sessions, and eventually exits.

  use POE;
  POE::Session->create( ... map events to code here ... );
  POE::Kernel->run();
  exit;

=head2 POE::Kernel singleton

The POE::Kernel is a singleton object; there can be only one POE::Kernel
instance within a process.  This allows many object methods to also be
package methods.

=head2 Sessions

POE implements isolated compartments called I<sessions>.  Sessions play
the role of tasks or threads within POE.  POE::Kernel acts as POE's
task scheduler, doling out timeslices to each session by invoking
callbacks within them.

Callbacks are not preemptive.  As long as one is running, no others
will be dispatched.  This is known as I<cooperative> multitasking.
Each session must cooperate by returning to the central dispatching
kernel.

Cooperative multitasking vastly simplifies data sharing, since no two
pieces of code may alter data at once.

A session may also take exclusive control of a program's time, if
necessary, by simply not returning in a timely fashion.  It's even
possible to write completely blocking programs that use POE as a state
machine rather than a cooperative dispatcher.

Every POE-based application needs at least one session.  Code cannot
run I<within POE> without being a part of some session.  Likewise, a
threaded program always has a "thread zero".

Sessions in POE::Kernel should not be confused with
L<POE::Session|POE::Session> even though the two are inextricably
associated.  POE::Session adapts POE::Kernel's dispatcher to a
particular calling convention.  Other POE::Session classes exist on
the CPAN.  Some radically alter the way event handlers are called.
L<http://search.cpan.org/search?query=poe+session>.

=head2 Resources

Resources are events and things which may create new events, such as
timers, I/O watchers, and even other sessions.

POE::Kernel tracks resources on behalf of its active sessions.  It
generates events corresponding to these resources' activity, notifying
sessions when it's time to do things.

The conversation goes something like this:

  Session: Be a dear, Kernel, and let me know when someone clicks on
           this widget.  Thanks so much!

  [TIME PASSES]  [SFX: MOUSE CLICK]

  Kernel: Right, then.  Someone's clicked on your widget.
          Here you go.

Furthermore, since the Kernel keeps track of everything sessions do,
it knows when a session has run out of tasks to perform.  When this
happens, the Kernel emits a C<_stop> event at the dead session so it
can clean up and shutdown.

  Kernel: Please switch off the lights and lock up; it's time to go.

Likewise, if a session stops on its own and there still are opened
resource watchers, the Kernel knows about them and cleans them up on
the session's behalf.  POE excels at long-running services because it
so meticulously tracks and cleans up resources.

POE::Resources and the POE::Resource classes implement each kind of
resource, which are summarized here and covered in greater detail
later.

=over 2

=item Events.

An event is a message to a sessions.  Posting an event keeps both the
sender and the receiver alive until after the event has been
dispatched.  This is only guaranteed if both the sender and receiver
are in the same process.  Inter-Kernel message passing add-ons may
have other guarantees.  Please see their documentation for details.

The rationale is that the event is in play, so the receiver must
remain active for it to be dispatched.  The sender remains alive in
case the receiver would like to send back a response.

Posted events cannot be preemptively canceled.  They tend to be
short-lived in practice, so this generally isn't an issue.

=item Timers.

Timers allow an application to send a message to the future. Once set,
a timer will keep the destination session active until it goes off and
the resulting event is dispatched.

=item Aliases.

Session aliases are an application-controlled way of addressing a
session.  Aliases act as passive event watchers.  As long as a session
has an alias, some other session may send events to that session by
that name.  Aliases keep sessions alive as long as a process has
active sessions.

If the only sessions remaining are being kept alive solely by their
aliases, POE::Kernel will send them a terminal L</IDLE> signal.  In
most cases this will terminate the remaining sessions and allow the
program to exit.  If the sessions remain in memory without waking up
on the C<IDLE> signal, POE::Kernel sends them a non-maskable L</ZOMBIE>
signal.  They are then forcibly removed, and the program will finally
exit.

=item I/O watchers.

A session will remain active as long as a session is paying attention
to some external data source or sink. See
L<select_read|"select_read FILE_HANDLE [, EVENT_NAME [, ADDITIONAL_PARAMETERS] ]">
and
L<select_write|"select_write FILE_HANDLE [, EVENT_NAME [, ADDITIONAL_PARAMETERS] ]">.

=item Child sessions.

A session acting as a parent of one or more other sessions will remain
active until all the child sessions stop.  This may be bypassed by
detaching the children from the parent.

=item Child processes.

Child process are watched by sig_child().  The sig_child() watcher
will keep the watching session active until the child process has been
reaped by POE::Kernel and the resulting event has been dispatched.

All other signal watchers, including using L</sig> to watch for
C<CHLD>, do not keep their sessions active.  If you need a session to
remain active when it's only watching for signals, have it set an
alias or one of its own public reference counters.

=item Public reference counters.

A session will remain active as long as it has one or more nonzero
public (or external) reference counter.

=back

=head2 Session Lifespans

"Session" as a term is somewhat overloaded.  There are two related
concepts that share the name.  First there is the class POE::Session,
and objects created with it or related classes.  Second there is a
data structure within POE::Kernel that tracks the POE::Session objects
in play and the various resources owned by each.

The way POE's garbage collector works is that a session object gives
itself to POE::Kernel at creation time.  The Kernel then holds onto
that object as long as resources exist that require the session to
remain alive.  When all of these resources are destroyed or released,
the session object has nothing left to trigger activity.  POE::Kernel
notifies the object it's through, and cleans up its internal session
context.  The session object is released, and self-destructs in the
normal Perlish fashion.

Sessions may be stopped even if they have active resources.  For
example, a session may fail to handle a terminal signal.  In this
case, POE::Kernel forces the session to stop, and all resources
associated with the session are preemptively released.

=head2 Events

An event is a message that is sent from one part of the POE
application to another.  An event consists of the event's name,
optional event-specific parameters and OOB information.  An event may
be sent from the kernel, from a wheel or from a session.

An application creates an event with L</post>, L</yield>, L</call> or
even L</signal>.  POE::Kernel creates events in response external
stimulus (signals, select, etc).

=head3 Event Handlers

An event is handled by a function called an I<event handler>, which is
some code that is designated to be called when a particular event is
dispatched.  See L</Event Handler Management> and L<POE::Session>.

The term I<state> is often used in place of I<event handler>,
especially when treating sessions as event driven state machines.

Handlers are always called in scalar context for asynchronous events
(i.e. via post()).  Synchronous events, invoked with call(), are
handled in the same context that call() was called.

Event handlers may not directly return references to objects in the
"POE" namespace.  POE::Kernel will stringify these references to
prevent timing issues with certain objects' destruction.  For example,
this error handler would cause errors because a deleted wheel would
not be destructed when one might think:

  sub handle_error {
    warn "Got an error";
    delete $_[HEAP]{wheel};
  }

The delete() call returns the deleted wheel member, which is then
returned implicitly by handle_error().

=head2 Using POE with Other Event Loops

POE::Kernel supports any number of event loops.  Two are included in
the base distribution.  Historically, POE included other loops but they
were moved into a separate distribution.  You can find them and other
loops on the CPAN.

POE's public interfaces remain the same regardless of the event loop
being used.  Since most graphical toolkits include some form of event
loop, back-end code should be portable to all of them.

POE's cooperation with other event loops lets POE be embedded into
other software.  The common underlying event loop drives both the
application and POE.  For example, by using POE::Loop::Glib, one can
embed POE into Vim, irssi, and so on.  Application scripts can then
take advantage of POE::Component::Client::HTTP (and everything else)
to do large-scale work without blocking the rest of the program.

Because this is Perl, there are multiple ways to load an alternate
event loop.  The simplest way is to load the event loop before loading
POE::Kernel.

  use Gtk;
  use POE;

Remember that POE loads POE::Kernel internally.

POE::Kernel examines the modules loaded before it and detects that
L<Gtk> has been loaded.  If L<POE::Loop::Gtk|POE::Loop::Gtk> is
available, POE loads and hooks it into POE::Kernel automatically.

It's less mysterious to load the appropriate L<POE::Loop|POE::Loop>
class directly. Their names follow the format
C<POE::Loop::$loop_module_name>, where C<$loop_module_name> is the
name of the event loop module after each C<::> has been substituted
with an underscore. It can be abbreviated using POE's loader magic.

  use POE qw( Loop::Event_Lib );

POE also recognizes XS loops, they reside in the
C<POE::XS::Loop::$loop_module_name> namespace.  Using them may give
you a performance improvement on your platform, as the eventloop
are some of the hottest code in the system.  As always, benchmark
your application against various loops to see which one is best for
your workload and platform.

  use POE qw( XS::Loop::EPoll );

Please don't load the loop modules directly, because POE will not have
a chance to initialize it's internal structures yet. Code written like
this will throw errors on startup. It might look like a bug in POE, but
it's just the way POE is designed.

  use POE::Loop::IO_Poll;
  use POE;

POE::Kernel also supports configuration directives on its own C<use>
line.  A loop explicitly specified this way will override the search
logic.

  use POE::Kernel { loop => "Glib" };

Finally, one may specify the loop class by setting the POE::Loop or
POE::XS:Loop class name in the POE_EVENT_LOOP environment variable.
This mechanism was added for tests that need to specify the loop from
a distance.

  BEGIN { $ENV{POE_EVENT_LOOP} = "POE::XS::Loop::Poll" }
  use POE;

Of course this may also be set from your shell:

  % export POE_EVENT_LOOP='POE::XS::Loop::Poll'
  % make test

Many external event loops support their own callback mechanisms.
L<POE::Session|POE::Session>'s L<"postback()"|POE::Session/postback>
and L<"callback()"|POE::Session/callback> methods return plain Perl
code references that will generate POE events when called.
Applications can pass these code references to event loops for use as
callbacks.

POE's distribution includes two event loop interfaces.  CPAN holds
several more:

=head3 POE::Loop::Select (bundled)

By default POE uses its select() based loop to drive its event system.
This is perhaps the least efficient loop, but it is also the most
portable.  POE optimizes for correctness above all.

=head3 POE::Loop::IO_Poll (bundled)

The L<IO::Poll|IO::Poll> event loop provides an alternative that
theoretically scales better than select().

=head3 POE::Loop::Event (separate distribution)

This event loop provides interoperability with other modules that use
L<Event>.  It may also provide a performance boost because L<Event> is
written in a compiled language.  Unfortunately, this makes L<Event>
less portable than Perl's built-in select().

=head3 POE::Loop::Gtk (separate distribution)

This event loop allows programs to work under the L<Gtk> graphical
toolkit.

=head3 POE::Loop::Tk (separate distribution)

This event loop allows programs to work under the L<Tk> graphical
toolkit.  Tk has some restrictions that require POE to behave oddly.

Tk's event loop will not run unless one or more widgets are created.
POE must therefore create such a widget before it can run. POE::Kernel
exports $poe_main_window so that the application developer may use the
widget (which is a L<MainWindow|Tk::MainWindow>), since POE doesn't
need it other than for dispatching events.

Creating and using a different MainWindow often has an undesired
outcome.

=head3 POE::Loop::EV (separate distribution)

L<POE::Loop::EV> allows POE-based programs to use the EV event library
with little or no change.

=head3 POE::Loop::Glib (separate distribution)

L<POE::Loop::Glib> allows POE-based programs to use Glib with little
or no change.  It also supports embedding POE-based programs into
applications that already use Glib.  For example, we have heard that
POE has successfully embedded into vim, irssi and xchat via this loop.

=head3 POE::Loop::Kqueue (separate distribution)

L<POE::Loop::Kqueue> allows POE-based programs to transparently use
the BSD kqueue event library on operating systems that support it.

=head3 POE::Loop::Prima (separate distribution)

L<POE::Loop::Prima> allows POE-based programs to use Prima's event
loop with little or no change.  It allows POE libraries to be used
within Prima applications.

=head3 POE::Loop::Wx (separate distribution)

L<POE::Loop::Wx> allows POE-based programs to use Wx's event loop with
little or no change.  It allows POE libraries to be used within Wx
applications, such as Padre.

=head3 POE::XS::Loop::EPoll (separate distribution)

L<POE::XS::Loop::EPoll> allows POE components to transparently use the
EPoll event library on operating systems that support it.

=head3 POE::XS::Loop::Poll (separate distribution)

L<POE::XS::Loop::Poll> is a higher-performance C-based libpoll event
loop.  It replaces some of POE's hot Perl code with C for better
performance.

=head3 Other Event Loops (separate distributions)

POE may be extended to handle other event loops.  Developers are
invited to work with us to support their favorite loops.

=head1 PUBLIC METHODS

POE::Kernel encapsulates a lot of features.  The documentation for
each set of features is grouped by purpose.

=head2 Kernel Management and Accessors

=head3 ID

ID() returns the kernel's unique identifier.  Every POE::Kernel
instance is assigned a (hopefully) globally unique ID at birth.

  % perl -wl -MPOE -e 'print $poe_kernel->ID'
  poerbook.local-46c89ad800000e21

While the IDs are made globally unique by including hostname, time and
PID, they should be considered an opaque but printable string.  That
is, your code should not depend on the current format.

=head3 run

run() runs POE::Kernel's event dispatcher.  It will not return until
all sessions have ended.  run() is a class method so a POE::Kernel
reference is not needed to start a program's execution.

  use POE;
  POE::Session->create( ... ); # one or more
  POE::Kernel->run();          # set them all running
  exit;

POE implements the Reactor pattern at its core.  Events are dispatched
to functions and methods through callbacks.  The code behind run()
waits for and dispatches events.

run() will not return until every session has ended.  This includes
sessions that were created while run() was running.

POE::Kernel will print a strong message if a program creates sessions
but fails to call run().  Prior to this warning, we received tons of
bug reports along the lines of "my POE program isn't doing anything".
It turned out that people forgot to start an event dispatcher, so
events were never dispatched.

If the lack of a run() call is deliberate, perhaps because some other
event loop already has control, you can avoid the message by calling
it before creating a session.  run() at that point will initialize POE
and return immediately.  POE::Kernel will be satisfied that run() was
called, although POE will not have actually taken control of the event
loop.

  use POE;
  POE::Kernel->run(); # silence the warning
  POE::Session->create( ... );
  exit;

Note, however, that this varies from one event loop to another.  If a
particular POE::Loop implementation doesn't support it, that's
probably a bug.  Please file a bug report with the owner of the
relevant POE::Loop module.

=head3 run_one_timeslice

run_one_timeslice() dispatches any events that are due to be
delivered.  These events include timers that are due, asynchronous
messages that need to be delivered, signals that require handling, and
notifications for files with pending I/O.  Do not rely too much on
event ordering.  run_one_timeslice() is defined by the underlying
event loop, and its timing may vary.

run() is implemented similar to

  run_one_timeslice() while $session_count > 0;

run_one_timeslice() can be used to keep running POE::Kernel's
dispatcher while emulating blocking behavior.  The pattern is
implemented with a flag that is set when some asynchronous event
occurs.  A loop calls run_one_timeslice() until that flag is set.  For
example:

  my $done = 0;

  sub handle_some_event {
    $done = 1;
  }

  $kernel->run_one_timeslice() while not $done;

Do be careful.  The above example will spin if POE::Kernel is done but
$done is never set.  The loop will never be done, even though there's
nothing left that will set $done.

=head3 run_while SCALAR_REF

run_while() is an B<experimental> version of run_one_timeslice() that
will only return when there are no more active sessions, or the value
of the referenced scalar becomes false.

Here's a version of the run_one_timeslice() example using run_while()
instead:

  my $job_count = 3;

  sub handle_some_event {
    $job_count--;
  }

  $kernel->run_while(\$job_count);

=head3 has_forked

    my $pid = fork();
    die "Unable to fork" unless defined $pid;
    unless( $pid ) { 
        $poe_kernel->has_forked;
    }
 
Inform the kernel that it is now running in a new process.  This allows the
kernel to reset some internal data to adjust to the new situation.

has_forked() must be called in the child process if you wish to run the same
kernel.  However, if you want the child process to have new kernel, you must
call L</stop> instead.


=head3 stop

stop() causes POE::Kernel->run() to return early.  It does this by
emptying the event queue, freeing all used resources, and stopping
every active session.  stop() is not meant to be used lightly.
Proceed with caution.

Caveats:

The session that calls stop() will not be fully DESTROYed until it
returns.  Invoking an event handler in the session requires a
reference to that session, and weak references are prohibited in POE
for backward compatibility reasons, so it makes sense that the last
session won't be garbage collected right away.

Sessions are not notified about their destruction.  If anything relies
on _stop being delivered, it will break and/or leak memory.

stop() is still considered experimental.  It was added to improve fork()
support for L<POE::Wheel::Run|POE::Wheel::Run>.  If it proves unfixably
problematic, it will be removed without much notice.

stop() is advanced magic.  Programmers who think they need it are
invited to become familiar with its source.

See L<POE::Wheel::Run/Running POE::Kernel in the Child> for an example
of how to use this facility.

=head2 Asynchronous Messages (FIFO Events)

Asynchronous messages are events that are dispatched in the order in
which they were enqueued (the first one in is the first one out,
otherwise known as first-in/first-out, or FIFO order).  These methods
enqueue new messages for delivery.  The act of enqueuing a message
keeps the sender alive at least until the message is delivered.

=head3 post DESTINATION, EVENT_NAME [, PARAMETER_LIST]

post() enqueues a message to be dispatched to a particular DESTINATION
session.  The message will be handled by the code associated with
EVENT_NAME.  If a PARAMETER_LIST is included, its values will also be
passed along.

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->post( $_[SESSION], "event_name", 0 );
      },
      event_name => sub {
        print "$_[ARG0]\n";
        $_[KERNEL]->post( $_[SESSION], "event_name", $_[ARG0] + 1 );
      },
    }
  );

post() returns a Boolean value indicating whether the message was
successfully enqueued.  If post() returns false, $! is set to explain
the failure:

ESRCH ("No such process") - The DESTINATION session did not exist at
the time post() was called.

=head3 yield EVENT_NAME [, PARAMETER_LIST]

yield() is a shortcut for post() where the destination session is the
same as the sender.  This example is equivalent to the one for post():

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->yield( "event_name", 0 );
      },
      event_name => sub {
        print "$_[ARG0]\n";
        $_[KERNEL]->yield( "event_name", $_[ARG0] + 1 );
      },
    }
  );

As with post(), yield() returns right away, and the enqueued
EVENT_NAME is dispatched later.  This may be confusing if you're
already familiar with threading.

yield() should always succeed, so it does not return a meaningful
value.

=head2 Synchronous Messages

It is sometimes necessary for code to be invoked right away.  For
example, some resources must be serviced right away, or they'll
faithfully continue reporting their readiness.  These reports would
appear as a stream of duplicate events.  Synchronous events can also
prevent data from going stale between the time an event is enqueued
and the time it's delivered.

Synchronous event handlers preempt POE's event queue, so they should
perform simple tasks of limited duration.  Synchronous events that
need to do more than just service a resource should pass the
resource's information to an asynchronous handler.  Otherwise
synchronous operations will occur out of order in relation to
asynchronous events.  It's very easy to have race conditions or break
causality this way, so try to avoid it unless you're okay with the
consequences.

POE provides these ways to call message handlers right away.

=head3 call DESTINATION, EVENT_NAME [, PARAMETER_LIST]

call()'s semantics are nearly identical to post()'s.  call() invokes a
DESTINATION's handler associated with an EVENT_NAME.  An optional
PARAMETER_LIST will be passed along to the message's handler.  The
difference, however, is that the handler will be invoked immediately,
even before call() returns.

call() returns the value returned by the EVENT_NAME handler.  It can
do this because the handler is invoked before call() returns.  call()
can therefore be used as an accessor, although there are better ways
to accomplish simple accessor behavior.

  POE::Session->create(
    inline_states => {
      _start => sub {
        print "Got: ", $_[KERNEL]->call($_[SESSION], "do_now"), "\n";
      },
      do_now => sub {
        return "some value";
      }
    }
  );

The L<POE::Wheel|POE::Wheel> classes uses call() to synchronously deliver I/O
notifications.  This avoids a host of race conditions.

call() may fail in the same way and for the same reasons as post().
On failure, $! is set to some nonzero value indicating why.  Since
call() may return undef as a matter of course, it's recommended that
$! be checked for the error condition as well as the explanation.

ESRCH ("No such process") - The DESTINATION session did not exist at
the time post() was called.

=head2 Timer Events (Delayed Messages)

It's often useful to wait for a certain time or until a certain amount
of time has passed.  POE supports this with events that are deferred
until either an absolute time ("alarms") or until a certain duration
of time has elapsed ("delays").

Timer interfaces are further divided into two groups.  One group identifies
timers by the names of their associated events.  Another group identifies
timers by a unique identifier returned by the timer constructors.
Technically, the two are both name-based, but the "identifier-based" timers
provide a second, more specific handle to identify individual timers.

Timers may only be set up for the current session.  This design was
modeled after alarm() and SIGALRM, which only affect the current UNIX
process.  Each session has a separate namespace for timer names.
Timer methods called in one session cannot affect the timers in
another.  As you may have noticed, quite a lot of POE's API is
designed to prevent sessions from interfering with each other.

The best way to simulate deferred inter-session messages is to send an
immediate message that causes the destination to set a timer.  The
destination's timer then defers the action requested of it.  This way
is preferred because the time spent communicating the request between
sessions may not be trivial, especially if the sessions are separated
by a network.  The destination can determine how much time remains on
the requested timer and adjust its wait time accordingly.

=head3 Using Time::HiRes

POE::Kernel timers support sub-second accuracy, but don't expect too
much here.  Perl is not the right language for realtime programming.

Subsecond accuracy is supported through the use of select() timeouts
and other event-loop features.  For increased accuracy, POE::Kernel
uses L<Time::HiRes|Time::HiRes>'s time() internally, if it's available.

You can disable POE's use of Time::HiRes by defining a constant in the
POE::Kernel namespace.  This must be done before POE::Kernel is
loaded, so that the compiler can use it.

  BEGIN {
    package POE::Kernel;
    use constant USE_TIME_HIRES => 0;
  }
  use POE;

Or the old-fashioned (and more concise) "constant subroutine" method.
This doesn't need the C<BEGIN{}> block since subroutine definitions are
done at compile time.

  sub POE::Kernel::USE_TIME_HIRES () { 0 }
  use POE;

=head3 Name-Based Timers

Name-based timers are identified by the event names used to set them.
It is possible for different sessions to use the same timer event names,
since each session is a separate compartment with its own timer namespace.
It is possible for a session to have multiple timers for a given event,
but results may be surprising.  Be careful to use the right timer methods.

The name-based timer methods are alarm(), alarm_add(), delay(), and
delay_add().

=head4 alarm EVENT_NAME [, EPOCH_TIME [, PARAMETER_LIST] ]

alarm() clears all existing timers in the current session with the
same EVENT_NAME.  It then sets a new timer, named EVENT_NAME, that
will fire EVENT_NAME at the current session when EPOCH_TIME has been
reached.  An optional PARAMETER_LIST may be passed along to the
timer's handler.

Omitting the EPOCH_TIME and subsequent parameters causes alarm() to
clear the EVENT_NAME timers in the current session without setting a
new one.

EPOCH_TIME is the UNIX epoch time.  You know, seconds since midnight,
1970-01-01.  "Now" is whatever time() returns, either the built-in or
L<Time::HiRes|Time::HiRes> version.  POE will use Time::HiRes if it's
available.

POE supports fractional seconds, but accuracy falls off steeply after
1/100 second.  Mileage will vary depending on your CPU speed and your
OS time resolution.

Be sure to use Time::HiRes::time() rather than Perl's built-in time()
if sub-second accuracy matters at all.  The built-in time() returns
floor(Time::HiRes::time()), which is nearly always some fraction of a
second in the past.  For example the high-resolution time might be
1200941422.89996.  At that same instant, time() would be 1200941422.
An alarm for time() + 0.5 would be 0.39996 seconds in the past, so it
would be dispatched immediately (if not sooner).

POE's event queue is time-ordered, so a timer due before time() will
be delivered ahead of other events but not before timers with even
earlier due times.  Therefore an alarm() with an EPOCH_TIME before
time() jumps ahead of the queue.

All timers are implemented identically internally, regardless of how
they are set.  alarm() will therefore blithely clear timers set by
other means.

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->alarm( tick => time() + 1, 0 );
      },
      tick => sub {
        print "tick $_[ARG0]\n";
        $_[KERNEL]->alarm( tock => time() + 1, $_[ARG0] + 1 );
      },
      tock => sub {
        print "tock $_[ARG0]\n";
        $_[KERNEL]->alarm( tick => time() + 1, $_[ARG0] + 1 );
      },
    }
  );

alarm() returns 0 on success or a true value on failure.  Usually
EINVAL to signal an invalid parameter, such as an undefined
EVENT_NAME.

=head4 alarm_add EVENT_NAME, EPOCH_TIME [, PARAMETER_LIST]

alarm_add() is used to add a new alarm timer named EVENT_NAME without
clearing existing timers.  EPOCH_TIME is a required parameter.
Otherwise the semantics are identical to alarm().

A program may use alarm_add() without first using alarm().

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->alarm_add( tick => time() + 1.0, 1_000_000 );
        $_[KERNEL]->alarm_add( tick => time() + 1.5, 2_000_000 );
      },
      tick => sub {
        print "tick $_[ARG0]\n";
        $_[KERNEL]->alarm_add( tock => time() + 1, $_[ARG0] + 1 );
      },
      tock => sub {
        print "tock $_[ARG0]\n";
        $_[KERNEL]->alarm_add( tick => time() + 1, $_[ARG0] + 1 );
      },
    }
  );

alarm_add() returns 0 on success or EINVAL if EVENT_NAME or EPOCH_TIME
is undefined.

=head4 delay EVENT_NAME [, DURATION_SECONDS [, PARAMETER_LIST] ]

delay() clears all existing timers in the current session with the
same EVENT_NAME.  It then sets a new timer, named EVENT_NAME, that
will fire EVENT_NAME at the current session when DURATION_SECONDS have
elapsed from "now".  An optional PARAMETER_LIST may be passed along to
the timer's handler.

Omitting the DURATION_SECONDS and subsequent parameters causes delay()
to clear the EVENT_NAME timers in the current session without setting
a new one.

DURATION_SECONDS may be or include fractional seconds.  As with all of
POE's timers, accuracy falls off steeply after 1/100 second.  Mileage
will vary depending on your CPU speed and your OS time resolution.

POE's event queue is time-ordered, so a timer due before time() will
be delivered ahead of other events but not before timers with even
earlier due times.  Therefore a delay () with a zero or negative
DURATION_SECONDS jumps ahead of the queue.

delay() may be considered a shorthand form of alarm(), but there are
subtle differences in timing issues.  This code is roughly equivalent
to the alarm() example.

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->delay( tick => 1, 0 );
      },
      tick => sub {
        print "tick $_[ARG0]\n";
        $_[KERNEL]->delay( tock => 1, $_[ARG0] + 1 );
      },
      tock => sub {
        print "tock $_[ARG0]\n";
        $_[KERNEL]->delay( tick => 1, $_[ARG0] + 1 );
      },
    }
  );

delay() returns 0 on success or a reason for failure: EINVAL if
EVENT_NAME is undefined.

=head4 delay_add EVENT_NAME, DURATION_SECONDS [, PARAMETER_LIST]

delay_add() is used to add a new delay timer named EVENT_NAME without
clearing existing timers.  DURATION_SECONDS is a required parameter.
Otherwise the semantics are identical to delay().

A program may use delay_add() without first using delay().

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->delay_add( tick => 1.0, 1_000_000 );
        $_[KERNEL]->delay_add( tick => 1.5, 2_000_000 );
      },
      tick => sub {
        print "tick $_[ARG0]\n";
        $_[KERNEL]->delay_add( tock => 1, $_[ARG0] + 1 );
      },
      tock => sub {
        print "tock $_[ARG0]\n";
        $_[KERNEL]->delay_add( tick => 1, $_[ARG0] + 1 );
      },
    }
  );

delay_add() returns 0 on success or EINVAL if EVENT_NAME or EPOCH_TIME
is undefined.

=head3 Identifier-Based Timers

A second way to manage timers is through identifiers.  Setting an
alarm or delay with the "identifier" methods allows a program to
manipulate several timers with the same name in the same session.  As
covered in alarm() and delay() however, it's possible to mix named and
identified timer calls, but the consequences may not always be
expected.

=head4 alarm_set EVENT_NAME, EPOCH_TIME [, PARAMETER_LIST]

alarm_set() sets an alarm, returning a unique identifier that can be
used to adjust or remove the alarm later.  Unlike alarm(), it does not
first clear existing timers with the same EVENT_NAME.  Otherwise the
semantics are identical to alarm().

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]{alarm_id} = $_[KERNEL]->alarm_set(
          party => time() + 1999
        );
        $_[KERNEL]->delay(raid => 1);
      },
      raid => sub {
        $_[KERNEL]->alarm_remove( delete $_[HEAP]{alarm_id} );
      },
    }
  );

alarm_set() returns false if it fails and sets $! with the
explanation.  $! will be EINVAL if EVENT_NAME or TIME is undefined.

=head4 alarm_adjust ALARM_ID, DELTA_SECONDS

alarm_adjust() adjusts an existing timer's due time by DELTA_SECONDS,
which may be positive or negative.  It may even be zero, but that's
not as useful.  On success, it returns the timer's new due time since
the start of the UNIX epoch.

It's possible to alarm_adjust() timers created by delay_set() as well
as alarm_set().

This example moves an alarm's due time ten seconds earlier.

  use POSIX qw(strftime);

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]{alarm_id} = $_[KERNEL]->alarm_set(
          party => time() + 1999
        );
        $_[KERNEL]->delay(postpone => 1);
      },
      postpone => sub {
        my $new_time = $_[KERNEL]->alarm_adjust(
          $_[HEAP]{alarm_id}, -10
        );
        print(
          "Now we're gonna party like it's ",
          strftime("%F %T", gmtime($new_time)), "\n"
        );
      },
    }
  );

alarm_adjust() returns Boolean false if it fails, setting $! to the
reason why.  $! may be EINVAL if ALARM_ID or DELTA_SECONDS are
undefined.  It may be ESRCH if ALARM_ID no longer refers to a pending
timer.  $! may also contain EPERM if ALARM_ID is valid but belongs to
a different session.

=head4 alarm_remove ALARM_ID

alarm_remove() removes the alarm identified by ALARM_ID.  ALARM_ID
comes from a previous alarm_set() or delay_set() call.

Upon success, alarm_remove() returns something true based on its
context.  In a list context, it returns three things: The removed
alarm's event name, the UNIX time it was due to go off, and a
reference to the PARAMETER_LIST (if any) assigned to the timer when it
was created.  If necessary, the timer can be re-set with this
information.

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]{alarm_id} = $_[KERNEL]->alarm_set(
          party => time() + 1999
        );
        $_[KERNEL]->delay(raid => 1);
      },
      raid => sub {
        my ($name, $time, $param) = $_[KERNEL]->alarm_remove(
          $_[HEAP]{alarm_id}
        );
        print(
          "Removed alarm for event $name due at $time with @$param\n"
        );

        # Or reset it, if you'd like.  Possibly after modification.
        $_[KERNEL]->alarm_set($name, $time, @$param);
      },
    }
  );

In a scalar context, it returns a reference to a list of the three
things above.

  # Remove and reset an alarm.
  my $alarm_info = $_[KERNEL]->alarm_remove( $alarm_id );
  my $new_id = $_[KERNEL]->alarm_set(
    $alarm_info[0], $alarm_info[1], @{$alarm_info[2]}
  );

Upon failure, however, alarm_remove() returns a Boolean false value
and sets $! with the reason why the call failed:

EINVAL ("Invalid argument") indicates a problem with one or more
parameters, usually an undefined ALARM_ID.

ESRCH ("No such process") indicates that ALARM_ID did not refer to a
pending alarm.

EPERM ("Operation not permitted").  A session cannot remove an alarm
it does not own.

=head4 alarm_remove_all

alarm_remove_all() removes all the pending timers for the current
session, regardless of creation method or type.  This method takes no
arguments.  It returns information about the alarms that were removed,
either as a list of alarms or a list reference depending whether
alarm_remove_all() is called in scalar or list context.

Each removed alarm's information is identical to the format explained
in alarm_remove().

  sub some_event_handler {
    my @removed_alarms = $_[KERNEL]->alarm_remove_all();
    foreach my $alarm (@removed_alarms) {
      my ($name, $time, $param) = @$alarm;
      ...;
    }
  }

=head4 delay_set EVENT_NAME, DURATION_SECONDS [, PARAMETER_LIST]

delay_set() sets a timer for DURATION_SECONDS in the future.  The
timer will be dispatched to the code associated with EVENT_NAME in the
current session.  An optional PARAMETER_LIST will be passed through to
the handler.  It returns the same sort of things that alarm_set()
does.

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->delay_set("later", 5, "hello", "world");
      },
      later => sub {
        print "@_[ARG0..#$_]\n";
      }
    }
  );

=head4 delay_adjust ALARM_ID, SECONDS_FROM_NOW

delay_adjust() changes a timer's due time to be SECONDS_FROM_NOW.
It's useful for refreshing watchdog- or timeout-style timers.  On
success it returns the new absolute UNIX time the timer will be due.

It's possible for delay_adjust() to adjust timers created by
alarm_set() as well as delay_set().

  use POSIX qw(strftime);

  POE::Session->create(
    inline_states => {
      # Setup.
      # ... omitted.

      got_input => sub {
        my $new_time = $_[KERNEL]->delay_adjust(
          $_[HEAP]{input_timeout}, 60
        );
        print(
          "Refreshed the input timeout.  Next may occur at ",
          strftime("%F %T", gmtime($new_time)), "\n"
        );
      },
    }
  );

On failure it returns Boolean false and sets $! to a reason for the
failure.  See the explanation of $! for alarm_adjust().

=head4 delay_remove is not needed

There is no delay_remove().  Timers are all identical internally, so
alarm_remove() will work with timer IDs returned by delay_set().

=head4 delay_remove_all is not needed

There is no delay_remove_all().  Timers are all identical internally,
so alarm_remove_all() clears them all regardless how they were
created.

=head2 Session Identifiers (IDs and Aliases)

A session may be referred to by its object references (either blessed
or stringified), a session ID, or one or more symbolic names we call
aliases.

Every session is represented by an object, so session references are
fairly straightforward.  POE::Kernel may reference these objects.  For
instance, post() may use $_[SENDER] as a destination:

  POE::Session->create(
    inline_states => {
      _start => sub { $_[KERNEL]->alias_set("echoer") },
      ping => sub {
        $_[KERNEL]->post( $_[SENDER], "pong", @_[ARG0..$#_] );
      }
    }
  );

POE also recognized stringified Session objects for convenience and as
a form of weak reference.  Here $_[SENDER] is wrapped in quotes to
stringify it:

  POE::Session->create(
    inline_states => {
      _start => sub { $_[KERNEL]->alias_set("echoer") },
      ping => sub {
        $_[KERNEL]->post( "$_[SENDER]", "pong", @_[ARG0..$#_] );
      }
    }
  );

Every session is assigned a unique ID at creation time.  No two active
sessions will have the same ID, but IDs may be reused over time.  The
combination of a kernel ID and a session ID should be sufficient as a
global unique identifier.

  POE::Session->create(
    inline_states => {
      _start => sub { $_[KERNEL]->alias_set("echoer") },
      ping => sub {
        $_[KERNEL]->delay(
          pong_later => rand(5), $_[SENDER]->ID, @_[ARG0..$#_]
        );
      },
      pong_later => sub {
        $_[KERNEL]->post( $_[ARG0], "pong", @_[ARG1..$#_] );
      }
    }
  );

Kernels also maintain a global session namespace or dictionary from which
may be used to map a symbolic aliases to a session. Once an alias is mapping
has been created, that alias may be used to refer to the session wherever a
session may be specified.

In the previous examples, each echoer service has set an "echoer"
alias.  Another session can post a ping request to the echoer session
by using that alias rather than a session object or ID.  For example:

  POE::Session->create(
    inline_states => {
      _start => sub { $_[KERNEL]->post(echoer => ping => "whee!" ) },
      pong => sub { print "@_[ARG0..$#_]\n" }
    }
  );

A session with an alias will not stop until all other activity has stopped.
Aliases are treated as a kind of event watcher.  Events come from active
sessions.  Aliases therefore become useless when there are no active
sessions left.  Rather than leaving the program running in a "zombie" state,
POE detects this deadlock condition and triggers a cleanup.  See
L</Signal Classes> for more information.

=head3 alias_set ALIAS

alias_set() maps an ALIAS in POE::Kernel's dictionary to the
current session. The ALIAS may then be used nearly everywhere a session
reference, stringified reference, or ID is expected.

Sessions may have more than one alias.  Each alias must be defined in
a separate alias_set() call.  A single alias may not refer to more
than one session.

Multiple alias examples are above.

alias_set() returns 0 on success, or a nonzero failure indicator:
EEXIST ("File exists") indicates that the alias is already assigned to
to a different session.

=head3 alias_remove ALIAS

alias_remove() removes an ALIAS for the current session from
POE::Kernel's dictionary.  The ALIAS will no longer refer to the
current session.  This does not negatively affect events already
posted to POE's queue.  Alias resolution occurs at post() time, not at
delivery time.

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->alias_set("short_window");
        $_[KERNEL]->delay(close_window => 1);
      },
      close_window => {
        $_[KERNEL]->alias_remove("short_window");
      }
    }
  );

alias_remove() returns 0 on success or a nonzero failure code:  ESRCH
("No such process") indicates that the ALIAS is not currently in
POE::Kernel's dictionary.  EPERM ("Operation not permitted") means
that the current session may not remove the ALIAS because it is in use
by some other session.

=head3 alias_resolve ALIAS

alias_resolve() returns a session reference corresponding to a given
ALIAS.  Actually, the ALIAS may be a stringified session reference, a
session ID, or an alias previously registered by alias_set().

One use for alias_resolve() is to detect whether another session has
gone away:

  unless (defined $_[KERNEL]->alias_resolve("Elvis")) {
    print "Elvis has left the building.\n";
  }

As previously mentioned, alias_resolve() returns a session reference
or undef on failure.  Failure also sets $! to ESRCH ("No such
process") when the ALIAS is not currently in POE::Kernel's.

=head3 alias_list [SESSION_REFERENCE]

alias_list() returns a list of aliases associated with a specific
SESSION, or with the current session if SESSION is omitted.
alias_list() returns an empty list if the requested SESSION has no
aliases.

SESSION may be a session reference (blessed or stringified), a session
ID, or a session alias.

  POE::Session->create(
    inline_states => {
      $_[KERNEL]->alias_set("mi");
      print(
        "The names I call myself: ",
        join(", ", $_[KERNEL]->alias_list()),
        "\n"
      );
    }
  );

=head3 ID_id_to_session SESSION_ID

ID_id_to_session() translates a session ID into a session reference.
It's a special-purpose subset of alias_resolve(), so it's a little
faster and somewhat less flexible.

  unless (defined $_[KERNEL]->ID_id_to_session($session_id)) {
    print "Session $session_id doesn't exist.\n";
  }

ID_id_to_session() returns undef if a lookup failed.  $! will be set
to ESRCH ("No such process").

=head3 ID_session_to_id SESSION_REFERENCE

ID_session_to_id() converts a blessed or stringified SESSION_REFERENCE
into a session ID.  It's more practical for stringified references, as
programs can call the POE::Session ID() method on the blessed ones.
These statements are equivalent:

  $id = $_[SENDER]->ID();
  $id = $_[KERNEL]->ID_session_to_id($_[SENDER]);
  $id = $_[KERNEL]->ID_session_to_id("$_[SENDER]");

As with other POE::Kernel lookup methods, ID_session_to_id() returns
undef on failure, setting $! to ESRCH ("No such process").

=head2 I/O Watchers (Selects)

No event system would be complete without the ability to
asynchronously watch for I/O events.  POE::Kernel implements the
lowest level watchers, which are called "selects" because they were
historically implemented using Perl's built-in select(2) function.

Applications handle I/O readiness events by performing some activity
on the underlying filehandle.  Read-readiness might be handled by
reading from the handle.  Write-readiness by writing to it.

All I/O watcher events include two parameters.  C<ARG0> contains the
handle that is ready for work.  C<ARG1> contains an integer describing
what's ready.

  sub handle_io {
    my ($handle, $mode) = @_[ARG0, ARG1];
    print "File $handle is ready for ";
    if ($mode == 0) {
      print "reading";
    }
    elsif ($mode == 1) {
      print "writing";
    }
    elsif ($mode == 2) {
      print "out-of-band reading";
    }
    else {
      die "unknown mode $mode";
    }
    print "\n";
    # ... do something here
  }

The remaining parameters, C<@_[ARG2..$%_]>, contain additional
parameters that were passed to the POE::Kernel method that created the
watcher.

POE::Kernel conditions filehandles to be 8-bit clean and non-blocking.
Programs that need them conditioned differently should set them up
after starting POE I/O watchers.

I/O watchers will prevent sessions from stopping.

=head3 select_read FILE_HANDLE [, EVENT_NAME [, ADDITIONAL_PARAMETERS] ]

select_read() starts or stops the current session from watching for
incoming data on a given FILE_HANDLE.  The watcher is started if
EVENT_NAME is specified, or stopped if it's not.
ADDITIONAL_PARAMETERS, if specified, will be passed to the EVENT_NAME
handler as C<@_[ARG2..$#_]>.

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]{socket} = IO::Socket::INET->new(
          PeerAddr => "localhost",
          PeerPort => 25,
        );
        $_[KERNEL]->select_read( $_[HEAP]{socket}, "got_input" );
        $_[KERNEL]->delay(timed_out => 1);
      },
      got_input => sub {
        my $socket = $_[ARG0];
        while (sysread($socket, my $buf = "", 8192)) {
          print $buf;
        }
      },
      timed_out => sub {
        $_[KERNEL]->select_read( delete $_[HEAP]{socket} );
      },
    }
  );

select_read() does not return anything significant.

=head3 select_write FILE_HANDLE [, EVENT_NAME [, ADDITIONAL_PARAMETERS] ]

select_write() follows the same semantics as select_read(), but it
starts or stops a watcher that looks for write-readiness.  That is,
when EVENT_NAME is delivered, it means that FILE_HANDLE is ready to be
written to.

select_write() does not return anything significant.

=head3 select_expedite FILE_HANDLE [, EVENT_NAME [, ADDITIONAL_PARAMETERS] ]

select_expedite() does the same sort of thing as select_read() and
select_write(), but it watches a FILE_HANDLE for out-of-band data
ready to be input from a FILE_HANDLE.  Hardly anybody uses this, but
it exists for completeness' sake.

An EVENT_NAME event will be delivered whenever the FILE_HANDLE can be
read from out-of-band.  Out-of-band data is considered "expedited"
because it is often ahead of a socket's normal data.

select_expedite() does not return anything significant.

=head3 select_pause_read FILE_HANDLE

select_pause_read() is a lightweight way to pause a FILE_HANDLE input
watcher without performing all the bookkeeping of a select_read().
It's used with select_resume_read() to implement input flow control.

Input that occurs on FILE_HANDLE will backlog in the operating system
buffers until select_resume_read() is called.

A side effect of bypassing the select_read() bookkeeping is that a
paused FILE_HANDLE will not prematurely stop the current session.

select_pause_read() does not return anything significant.

=head3 select_resume_read FILE_HANDLE

select_resume_read() resumes a FILE_HANDLE input watcher that was
previously paused by select_pause_read().  See select_pause_read() for
more discussion on lightweight input flow control.

Data backlogged in the operating system due to a select_pause_read()
call will become available after select_resume_read() is called.

select_resume_read() does not return anything significant.

=head3 select_pause_write FILE_HANDLE

select_pause_write() pauses a FILE_HANDLE output watcher the same way
select_pause_read() does for input.  Please see select_pause_read()
for further discussion.

=head3 select_resume_write FILE_HANDLE

select_resume_write() resumes a FILE_HANDLE output watcher the same
way that select_resume_read() does for input.  See
select_resume_read() for further discussion.

=head3 select FILE_HANDLE [, EV_READ [, EV_WRITE [, EV_EXPEDITE [, ARGS] ] ] ]

POE::Kernel's select() method sets or clears a FILE_HANDLE's read,
write and expedite watchers at once.  It's a little more expensive
than calling select_read(), select_write() and select_expedite()
manually, but it's significantly more convenient.

Defined event names enable their corresponding watchers, and undefined
event names disable them.  This turns off all the watchers for a
FILE_HANDLE:

  sub stop_io {
    $_[KERNEL]->select( $_[HEAP]{file_handle} );
  }

This statement:

  $_[KERNEL]->select( $file_handle, undef, "write_event", undef, @stuff );

is equivalent to:

  $_[KERNEL]->select_read( $file_handle );
  $_[KERNEL]->select_write( $file_handle, "write_event", @stuff );
  $_[KERNEL]->select_expedite( $file_handle );

POE::Kernel's select() should not be confused with Perl's built-in
select() function.

As with the other I/O watcher methods, select() does not return a
meaningful value.

=head2 Session Management

Sessions are dynamic.  They may be created and destroyed during a
program's lifespan.  When a session is created, it becomes the "child"
of the current session.  The creator -- the current session -- becomes
its "parent" session.  This is loosely modeled after UNIX processes.

The most common session management is done by creating new sessions
and allowing them to eventually stop.

Every session has a parent, even the very first session created.
Sessions without obvious parents are children of the program's
POE::Kernel instance.

Child sessions will keep their parents active.  See L</Session
Lifespans> for more about why sessions stay alive.

The parent/child relationship tree also governs the way many signals
are dispatched.  See L</Common Signal Dispatching> for more
information on that.

=head3 Session Management Events (_start, _stop, _parent, _child)

POE::Kernel provides four session management events: _start, _stop,
_parent and _child.  They are invoked synchronously whenever a session
is newly created or just about to be destroyed.

=over 2

=item _start

_start should be familiar by now.  POE dispatches the _start event to
initialize a session after it has been registered under POE::Kernel.
What is not readily apparent, however, is that it is invoked before
the L<POE::Session|POE::Session> constructor returns.

Within the _start handler, the event's sender is the session that
created the new session.  Otherwise known as the new session's
I<parent>.  Sessions created before POE::Kernel->run() is called will
be descendents of the program's POE::Kernel singleton.

The _start handler's return value is passed to the parent session in a
_child event, along with the notification that the parent's new child
was created successfully.  See the discussion of _child for more
details.

  POE::Session->create(
    inline_states => { _start=> \&_start },
    args => [ $some, $args ]
  );

  sub _start {
    my ( $some, $args ) = @_[ ARG0, ARG1 ];
    # ....
  }

=item _stop

_stop is a little more mysterious.  POE calls a _stop handler when a
session is irrevocably about to be destroyed.  Part of session
destruction is the forcible reclamation of its resources (events,
timers, message events, etc.) so it's not possible to post() a message
from _stop's handler.  A program is free to try, but the event will be
destroyed before it has a chance to be dispatched.

the _stop handler's return value is passed to the parent's _child
event.  See _child for more details.

_stop is usually invoked when a session has no further reason to live,
although signals may cause them to stop sooner.

The corresponding _child handler is invoked synchronously just after
_stop returns.

=item _parent

_parent is used to notify a child session when its parent has changed.
This usually happens when a session is first created.  It can also
happen when a child session is detached from its parent. See
L<detach_child|/"detach_child CHILD_SESSION"> and L</detach_myself>.

_parent's ARG0 contains the session's previous parent, and ARG1
contains its new parent.

  sub _parent {
    my ( $old_parent, $new_parent ) = @_[ ARG0, ARG1 ];
    print(
      "Session ", $_[SESSION]->ID,
      " parent changed from session ", $old_parent->ID,
      " to session ", $new_parent->ID,
      "\n"
    );
  }

=item _child

_child notifies one session when a child session has been created,
destroyed, or reassigned to or from another parent.  It's usually
dispatched when sessions are created or destroyed.  It can also happen
when a session is detached from its parent.

_child includes some information in the "arguments" portion of @_.
Typically ARG0, ARG1 and ARG2, but these may be overridden by a
different POE::Session class:

ARG0 contains a string describing what has happened to the child.  The
string may be 'create' (the child session has been created), 'gain'
(the child has been given by another session), or 'lose' (the child
session has stopped or been given away).

In all cases, ARG1 contains a reference to the child session.

In the 'create' case, ARG2 holds the value returned by the child
session's _start handler.  Likewise, ARG2 holds the _stop handler's
return value for the 'lose' case.

  sub _child {
    my( $reason, $child ) = @_[ ARG0, ARG1 ];
    if( $reason eq 'create' ) {
      my $retval = $_[ ARG2 ];
    }
    # ...
  }

=back

The events are delivered in specific orders.

=head4 When a new session is created:

=over 4

=item 1

The session's constructor is called.

=item 2

The session is put into play.  That is, POE::Kernel
enters the session into its bookkeeping.

=item 3

The new session receives _start.

=item 4

The parent session receives _child ('create'), the new
session reference, and the new session's _start's return value.

=item 5

The session's constructor returns.

=back

=head4 When an old session stops:

=over 4

=item 1

If the session has children of its
own, they are given to the session's parent.  This triggers one or
more _child ('gain') events in the parent, and a _parent in each
child.

=item 2

Once divested of its children, the stopping session
receives a _stop event.

=item 3

The stopped session's parent receives a
_child ('lose') event with the departing child's reference and _stop
handler's return value.

=item 4

The stopped session is removed from play,
as are all its remaining resources.

=item 5

The parent session is checked
for idleness.  If so, garbage collection will commence on it, and it
too will be stopped

=back

=head4 When a session is detached from its parent:

=over 4

=item 1

The parent session of
the session being detached is notified with a _child ('lose') event.
The _stop handler's return value is undef since the child is not
actually stopping.

=item 2

The detached session is notified with a _parent event that its new parent is
POE::Kernel itself.

=item 3

POE::Kernel's bookkeeping data is adjusted to reflect the change of
parentage.

=item 4

The old parent session is checked for idleness.  If so, garbage collection
will commence on it, and it too will be stopped

=back

=head3 Session Management Methods

These methods allow sessions to be detached from their parents in the
rare cases where the parent/child relationship gets in the way.

=head4 detach_child CHILD_SESSION

detach_child() detaches a particular CHILD_SESSION from the current
session.  On success, the CHILD_SESSION will become a child of the
POE::Kernel instance, and detach_child() will return true.  On failure
however, detach_child() returns false and sets $! to explain the
nature of the failure:

=over 4

=item ESRCH ("No such process").

The CHILD_SESSION is not a valid session.

=item EPERM ("Operation not permitted").

The CHILD_SESSION exists, but it is not a child of the current session.

=back

detach_child() will generate L</_parent> and/or L</_child> events to the
appropriate sessions.  See L<Session Management Events|/Session Management> for a detailed
explanation of these events.  See
L<above|/"When a session is detached from its parent:">
for the order the events are generated.

=head4 detach_myself

detach_myself() detaches the current session from its current parent.
The new parent will be the running POE::Kernel instance.  It returns
true on success.  On failure it returns false and sets C<$!> to
explain the nature of the failure:

=over 4

=item EPERM ("Operation not permitted").

The current session is already a
child of POE::Kernel, so it may not be detached.

=back

detach_child() will generate L</_parent> and/or L</_child> events to the
appropriate sessions.  See L<Session Management Events|/Session Management> for a detailed
explanation of these events.  See
L<above|/"When a session is detached from its parent:">
for the order the events are generated.

=head2 Signals

POE::Kernel provides methods through which a program can register
interest in signals that come along, can deliver its own signals
without resorting to system calls, and can indicate that signals have
been handled so that default behaviors are not necessary.

Signals are I<action at a distance> by nature, and their implementation
requires widespread synchronization between sessions (and reentrancy
in the dispatcher, but that's an implementation detail).  Perfecting
the semantics has proven difficult, but POE tries to do the Right
Thing whenever possible.

POE does not register %SIG handlers for signals until sig() is called
to watch for them.  Therefore a signal's default behavior occurs for
unhandled signals.  That is, SIGINT will gracelessly stop a program,
SIGWINCH will do nothing, SIGTSTP will pause a program, and so on.

=head3 Signal Classes

There are three signal classes.  Each class defines a default behavior
for the signal and whether the default can be overridden.  They are:

=head4 Benign, advisory, or informative signals

These are three names for the same signal class.  Signals in this class
notify a session of an event but do not terminate the session if they are
not handled.

It is possible for an application to create its own benign signals.  See
L</signal> below.

=head4 Terminal signals

Terminal signals will kill sessions if they are not handled by a
L</sig_handled>() call.  The OS signals that usually kill or dump a process
are considered terminal in POE, but they never trigger a coredump.  These
are: HUP, INT, QUIT and TERM.

There are two terminal signals created by and used within POE:

=over

=item DIE

C<DIE> notifies sessions that a Perl exception has occurred.  See
L</"Exception Handling"> for details.

=item IDLE

The C<IDLE> signal is used to notify leftover sessions that a
program has run out of things to do.

=back

=head4 Nonmaskable signals

Nonmaskable signals are terminal regardless whether sig_handled() is
called.  The term comes from "NMI", the non-maskable CPU interrupt
usually generated by an unrecoverable hardware exception.

Sessions that receive a non-maskable signal will unavoidably stop.  POE
implements two non-maskable signals:

=over

=item ZOMBIE

This non-maskable signal is fired if a program has received an C<IDLE> signal
but neither restarted nor exited.  The program has become a zombie (that is,
it's neither dead nor alive, and only exists to consume braaaains ...er...
memory).  The C<ZOMBIE> signal acts like a cricket bat to the head,
bringing the zombie down, for good.

=item UIDESTROY

This non-maskable signal indicates that a program's user
interface has been closed, and the program should take the user's hint
and buzz off as well.  It's usually generated when a particular GUI
widget is closed.

=back

=head3 Common Signal Dispatching

Most signals are not dispatched to a single session.  POE's session
lineage (parents and children) form a sort of family tree.  When a
signal is sent to a session, it first passes through any children (and
grandchildren, and so on) that are also interested in the signal.

In the case of terminal signals, if any of the sessions a signal passes
through calls L</sig_handled>(), then the signal is considered taken care
of.  However if none of them do, then the entire session tree rooted at the
destination session is terminated.  For example, consider this tree of
sessions:

  POE::Kernel
    Session 2
      Session 4
      Session 5
    Session 3
      Session 6
      Session 7

POE::Kernel is the parent of sessions 2 and 3.  Session 2 is the
parent of sessions 4 and 5.  And session 3 is the parent of 6 and 7.

A signal sent to Session 2 may also be dispatched to session 4 and 5
because they are 2's children.  Sessions 4 and 5 will only receive the
signal if they have registered the appropriate watcher.  If the signal is
terminal, and none of the signal watchers in sessions 2, 4 and 5 called
C<sig_handled()>, all 3 sessions will be terminated.

The program's POE::Kernel instance is considered to be a session for
the purpose of signal dispatch.  So any signal sent to POE::Kernel
will propagate through every interested session in the entire program.
This is in fact how OS signals are handled: A global signal handler is
registered to forward the signal to POE::Kernel.

=head3 Signal Semantics

All signals come with the signal name in ARG0.  The signal name is as
it appears in %SIG, with one exception: Child process signals are
always "CHLD" even if the current operating system recognizes them as
"CLD".

Certain signals have special semantics:

=head4 SIGCHLD

=head4 SIGCLD

Both C<SIGCHLD> and C<SIGCLD> indicate that a child process has exited
or been terminated by some signal.  The actual signal name varies
between operating systems, but POE uses C<CHLD> regardless.

Interest in C<SIGCHLD> is registered using the L</sig_child> method.
The L</sig>() method also works, but it's not as nice.

The C<SIGCHLD> event includes three parameters:

=over

=item ARG0

C<ARG0> contains the string 'CHLD' (even if the OS calls it SIGCLD,
SIGMONKEY, or something else).

=item ARG1

C<ARG1> contains the process ID of the finished child process.

=item ARG2

And C<ARG2> holds the value of C<$?> for the finished process.

=back

Example:

  sub sig_CHLD {
    my( $name, $PID, $exit_val ) = @_[ ARG0, ARG1, ARG2 ];
    # ...
  }

By default, SIGCHLD is not handled by registering a C<%SIG> handler.
Rather, waitpid() is called periodically to test for child process
exits.  See the experimental L</USE_SIGCHLD> option if you would prefer
child processes to be reaped in a more timely fashion.

=head4 SIGPIPE

SIGPIPE is rarely used since POE provides events that do the same
thing.  Nevertheless SIGPIPE is supported if you need it.  Unlike most
events, however, SIGPIPE is dispatched directly to the active session
when it's caught.  Barring race conditions, the active session should
be the one that caused the OS to send the signal in the first place.

The SIGPIPE signal will still propagate to child sessions.

ARG0 is "PIPE".  There is no other information associated with this
signal.

=head4 SIGWINCH

Window resizes can generate a large number of signals very quickly.
This may not be a problem when using perl 5.8.0 or later, but earlier
versions may not take kindly to such abuse.  You have been warned.

ARG0 is "WINCH".  There is no other information associated with this
signal.

=head3 Exception Handling

POE::Kernel provides only one form of exception handling: the
C<DIE> signal.

When exception handling is enabled (the default), POE::Kernel wraps state
invocation in C<eval{}>.  If the event handler raises an exception, generally
with C<die>, POE::Kernel will dispatch a C<DIE> signal to the event's
destination session.

C<ARG0> is the signal name, C<DIE>.

C<ARG1> is a hashref describing the exception:

=over

=item error_str

The text of the exception.  In other words, C<$@>.

=item dest_session

Session object of the state that the raised the exception.  In other words,
C<$_[SESSION]> in the function that died.

=item event

Name of the event that died.

=item source_session

Session object that sent the original event.
That is, C<$_[SENDER]> in the function that died.

=item from_state

State from which the original event was sent.
That is, C<$_[CALLER_STATE]> in the function that died.

=item file

Name of the file the event was sent from.
That is, C<$_[CALLER_FILE]> in the function that died.

=item line

Line number the event was sent from.
That is, C<$_[CALLER_LINE]> in the function that died.

=back

I<Note that the preceding discussion assumes you are using
L<POE::Session|POE::Session>'s call semantics.>

Note that the C<DIE> signal is sent to the session that raised the
exception, not the session that sent the event that caused the exception to
be raised.

  sub _start {
    $poe_kernel->sig( DIE => 'sig_DIE' );
    $poe_kernel->yield( 'some_event' );
  }

  sub some_event {
    die "I didn't like that!";
  }

  sub sig_DIE {
    my( $sig, $ex ) = @_[ ARG0, ARG1 ];
    # $sig is 'DIE'
    # $ex is the exception hash
    warn "$$: error in $ex->{event}: $ex->{error_str}";
    $poe_kernel->sig_handled();

    # Send the signal to session that sent the original event.
    if( $ex->{source_session} ne $_[SESSION] ) {
      $poe_kernel->signal( $ex->{source_session}, 'DIE', $sig, $ex );
    }
  }

POE::Kernel's built-in exception handling can be disabled by setting
the C<POE::Kernel::CATCH_EXCEPTIONS> constant to zero.  As with other
compile-time configuration constants, it must be set before
POE::Kernel is compiled:

  BEGIN {
    package POE::Kernel;
    use constant CATCH_EXCEPTIONS => 0;
  }
  use POE;

or

  sub POE::Kernel::CATCH_EXCEPTIONS () { 0 }
  use POE;

=head2 Signal Watcher Methods

And finally the methods themselves.

=head3 sig SIGNAL_NAME [, EVENT_NAME [, LIST] ]

sig() registers or unregisters an EVENT_NAME event for a particular
SIGNAL_NAME, with an optional LIST of parameters that will be passed
to the signal's handler---after any data that comes wit the signal.

If EVENT_NAME is defined, the signal handler is registered.  Otherwise
it's unregistered.  

Each session can register only one handler per SIGNAL_NAME.
Subsequent registrations will replace previous ones.  Multiple
sessions may however watch the same signal.

SIGNAL_NAMEs are generally the same as members of C<%SIG>, with two
exceptions.  First, C<CLD> is an alias for C<CHLD> (although see
L</sig_child>).  And second, it's possible to send and handle signals
created by the application and have no basis in the operating system.

  sub handle_start {
    $_[KERNEL]->sig( INT => "event_ui_shutdown" );
    $_[KERNEL]->sig( bat => "holy_searchlight_batman" );
    $_[KERNEL]->sig( signal => "main_screen_turn_on" );
  }

The operating system may never be able to generate the last two
signals, but a POE session can by using POE::Kernel's
L</signal>() method.

Later on the session may decide not to handle the signals:

  sub handle_ui_shutdown {
    $_[KERNEL]->sig( "INT" );
    $_[KERNEL]->sig( "bat" );
    $_[KERNEL]->sig( "signal" );
  }

More than one session may register interest in the same signal, and a
session may clear its own signal watchers without affecting those in
other sessions.

sig() does not return a meaningful value.

=head3 sig_child PROCESS_ID [, EVENT_NAME [, LIST] ]

sig_child() is a convenient way to deliver an EVENT_NAME event when a
particular PROCESS_ID has exited.  An optional LIST of parameters will
be passed to the signal handler after the waitpid() information.

The watcher can be cleared at any time by calling sig_child() with
just the PROCESS_ID.

A session may register as many sig_child() handlers as necessary, but
a session may only have one per PROCESS_ID.

sig_child() watchers are one-shot.  They automatically unregister
themselves once the EVENT_NAME has been delivered.  There's no point
in continuing to watch for a signal that will never come again.  Other
signal handlers persist until they are cleared.

sig_child() watchers keep a session alive for as long as they are
active.  This is unique among signal watchers.

Programs that wish to reliably reap child processes should be sure to
call sig_child() before returning from the event handler that forked
the process.  Otherwise POE::Kernel may have an opportunity to call
waitpid() before an appropriate event watcher has been registered.

sig_child() does not return a meaningful value.

  sub forked_parent {
    my( $heap, $pid, $details ) = @_[ HEAP, ARG0, ARG1 ];
    $poe_kernel->sig_child( $pid, 'sig_child', $details );
  }

  sub sig_child {
    my( $heap, $sig, $pid, $exit_val, $details ) = @_[ HEAP, ARG0..ARG3 ];
    my $details = delete $heap->{ $pid };
    warn "$$: Child $pid exited"
    # .... also, $details has been passed from forked_parent()
    # through sig_child()
  }

=head3 sig_handled

sig_handled() informs POE::Kernel that the currently dispatched signal has
been handled by the currently active session. If the signal is terminal, the
sig_handled() call prevents POE::Kernel from stopping the sessions that
received the signal.

A single signal may be dispatched to several sessions.  Only one needs
to call sig_handled() to prevent the entire group from being stopped.
If none of them call it, however, then they are all stopped together.

sig_handled() does not return a meaningful value.

  sub _start {
    $_[KERNEL]->sig( INT => 'sig_INT' );
  }

  sub sig_INT {
    warn "$$ SIGINT";
    $_[KERNEL]->sig_handled();
  }

=head3 signal SESSION, SIGNAL_NAME [, ARGS_LIST]

signal() posts a SIGNAL_NAME signal to a specific SESSION with an
optional ARGS_LIST that will be passed to every interested handler.  As
mentioned elsewhere, the signal may be delivered to SESSION's
children, grandchildren, and so on.  And if SESSION is the POE::Kernel
itself, then all interested sessions will receive the signal.

It is possible to send a signal in POE that doesn't exist in the
operating system.  signal() places the signal directly into POE's
event queue as if they came from the operating system, but they are
not limited to signals recognized by kill().  POE uses a few of these
fictitious signals for its own global notifications.

For example:

  sub some_event_handler {
    # Turn on all main screens.
    $_[KERNEL]->signal( $_[KERNEL], "signal" );
  }

signal() returns true on success.  On failure, it returns false after
setting $! to explain the nature of the failure:

=over

=item ESRCH ("No such process")

The SESSION does not exist.

=back

Because all sessions are a child of POE::Kernel, sending a signal to
the kernel will propagate the signal to all sessions.  This is a cheap
form of I<multicast>.

  $_[KERNEL]->signal( $_[KERNEL], 'shutdown' );

=head3 signal_ui_destroy WIDGET_OBJECT

signal_ui_destroy() associates the destruction of a particular
WIDGET_OBJECT with the complete destruction of the program's user
interface.  When the WIDGET_OBJECT destructs, POE::Kernel issues the
non-maskable UIDESTROY signal, which quickly triggers mass destruction
of all active sessions.  POE::Kernel->run() returns shortly
thereafter.

  sub setup_ui {
    $_[HEAP]{main_widget} = Gtk->new("toplevel");
    # ... populate the main widget here ...
    $_[KERNEL]->signal_ui_destroy( $_[HEAP]{main_widget} );
  }

Detecting widget destruction is specific to each toolkit.

=head2 Event Handler Management

Event handler management methods let sessions hot swap their event
handlers at run time. For example, the L<POE::Wheel|POE::Wheel>
objects use state() to dynamically mix their own event handlers into
the sessions that create them.

These methods only affect the current session; it would be rude to
change another session's handlers.

There is only one method in this group.  Since it may be called in
several different ways, it may be easier to understand if each is
documented separately.

=head3 state EVENT_NAME [, CODE_REFERNCE]

state() sets or removes a handler for EVENT_NAME in the current
session.  The function referred to by CODE_REFERENCE will be called
whenever EVENT_NAME events are dispatched to the current session.  If
CODE_REFERENCE is omitted, the handler for EVENT_NAME will be removed.

A session may only have one handler for a given EVENT_NAME.
Subsequent attempts to set an EVENT_NAME handler will replace earlier
handlers with the same name.

  # Stop paying attention to input.  Say goodbye, and
  # trigger a socket close when the message is sent.
  sub send_final_response {
    $_[HEAP]{wheel}->put("KTHXBYE");
    $_[KERNEL]->state( 'on_client_input' );
    $_[KERNEL]->state( on_flush => \&close_connection );
  }

=head3 state EVENT_NAME [, OBJECT_REFERENCE [, OBJECT_METHOD_NAME] ]

Set or remove a handler for EVENT_NAME in the current session.  If an
OBJECT_REFERENCE is given, that object will handle the event.  An
optional OBJECT_METHOD_NAME may be provided.  If the method name is
not given, POE will look for a method matching the EVENT_NAME instead.
If the OBJECT_REFERENCE is omitted, the handler for EVENT_NAME will be
removed.

A session may only have one handler for a given EVENT_NAME.
Subsequent attempts to set an EVENT_NAME handler will replace earlier
handlers with the same name.

  $_[KERNEL]->state( 'some_event', $self );
  $_[KERNEL]->state( 'other_event', $self, 'other_method' );

=head3 state EVENT_NAME [, CLASS_NAME [, CLASS_METHOD_NAME] ]

This form of state() call is virtually identical to that of the object
form.

Set or remove a handler for EVENT_NAME in the current session.  If an
CLASS_NAME is given, that class will handle the event.  An optional
CLASS_METHOD_NAME may be provided.  If the method name is not given,
POE will look for a method matching the EVENT_NAME instead.  If the
CLASS_NAME is omitted, the handler for EVENT_NAME will be removed.

A session may only have one handler for a given EVENT_NAME.
Subsequent attempts to set an EVENT_NAME handler will replace earlier
handlers with the same name.

  $_[KERNEL]->state( 'some_event', __PACKAGE__ );
  $_[KERNEL]->state( 'other_event', __PACKAGE__, 'other_method' );

=head2 Public Reference Counters

The methods in this section manipulate reference counters on the
current session or another session.

Each session has a namespace for user-manipulated reference counters.
These namespaces are associated with the target SESSION_ID for the
reference counter methods, not the caller.  Nothing currently prevents
one session from decrementing a reference counter that was incremented
by another, but this behavior is not guaranteed to remain.  For now,
it's up to the users of these methods to choose obscure counter names
to avoid conflicts.

Reference counting is a big part of POE's magic.  Various objects
(mainly event watchers and components) hold references to the sessions
that own them.  L</Session Lifespans> explains the concept in more
detail.

The ability to keep a session alive is sometimes useful in an application or
library.  For example, a component may hold a public reference to another
session while it processes a request from that session.  In doing so, the
component guarantees that the requester is still around when a response is
eventually ready.  Keeping a reference to the session's object is not
enough.  POE::Kernel has its own internal reference counting mechanism.

=head3 refcount_increment SESSION_ID, COUNTER_NAME

refcount_increment() increases the value of the COUNTER_NAME reference
counter for the session identified by a SESSION_ID.  To discourage the
use of session references, the refcount_increment() target session
must be specified by its session ID.

The target session will not stop until the value of any and all of its
COUNTER_NAME reference counters are zero.  (Actually, it may stop in
some cases, such as failing to handle a terminal signal.)

Negative reference counters are legal.  They still must be incremented
back to zero before a session is eligible for stopping.

  sub handle_request {
    # Among other things, hold a reference count on the sender.
    $_[KERNEL]->refcount_increment( $_[SENDER]->ID, "pending request");
    $_[HEAP]{requesters}{$request_id} = $_[SENDER]->ID;
  }

For this to work, the session needs a way to remember the
$_[SENDER]->ID for a given request.  Customarily the session generates
a request ID and uses that to track the request until it is fulfilled.

refcount_increment() returns the resulting reference count (which may
be zero) on success.  On failure, it returns undef and sets $! to be
the reason for the error.

ESRCH: The SESSION_ID does not refer to a currently active session.

=head3 refcount_decrement SESSION_ID, COUNTER_NAME

refcount_decrement() reduces the value of the COUNTER_NAME reference
counter for the session identified by a SESSION_ID.  It is the
counterpoint for refcount_increment().  Please see
refcount_increment() for more context.

  sub finally_send_response {
    # Among other things, release the reference count for the
    # requester.
    my $requester_id = delete $_[HEAP]{requesters}{$request_id};
    $_[KERNEL]->refcount_decrement( $requester_id, "pending request");
  }

The requester's $_[SENDER]->ID is remembered and removed from the heap
(lest there be memory leaks).  It's used to decrement the reference
counter that was incremented at the start of the request.

refcount_decrement() returns the resulting reference count (which may
be zero) on success.  On failure, it returns undef, and $! will be set
to the reason for the failure:

ESRCH: The SESSION_ID does not refer to a currently active session.

It is not possible to discover currently active public references.  See
L<POE::API::Peek>.

=head2 Kernel State Accessors

POE::Kernel provides a few accessors into its massive brain so that
library developers may have convenient access to necessary data
without relying on their callers to provide it.

These accessors expose ways to break session encapsulation.  Please
use them sparingly and carefully.

=head3 get_active_session

get_active_session() returns a reference to the session that is
currently running, or a reference to the program's POE::Kernel
instance if no session is running at that moment.  The value is
equivalent to L<POE::Session|POE::Session>'s C<$_[SESSION]>.

This method was added for libraries that need C<$_[SESSION]> but don't
want to include it as a parameter in their APIs.

  sub some_housekeeping {
    my( $self ) = @_;
    my $session = $poe_kernel->get_active_session;
    # do some housekeeping on $session
  }

=head3 get_active_event

get_active_event() returns the name of the event currently being
dispatched.  It returns an empty string when called outside event
dispatch.  The value is equivalent to L<POE::Session|POE::Session>'s
C<$_[STATE]>.

  sub waypoint {
    my( $message ) = @_;
    my $event = $poe_kernel->get_active_event;
    print STDERR "$$:$event:$mesage\n";
  }

=head3 get_event_count

get_event_count() returns the number of events pending in POE's event
queue.  It is exposed for L<POE::Loop|POE::Loop> class authors.  It
may be deprecated in the future.

=head3 get_next_event_time

get_next_event_time() returns the time the next event is due, in a
form compatible with the UNIX time() function.  It is exposed for
L<POE::Loop|POE::Loop> class authors.  It may be deprecated in the future.

=head3 poe_kernel_loop

poe_kernel_loop() returns the name of the POE::Loop class that is used
to detect and dispatch events.

=head2 Session Helper Methods

The methods in this group expose features for L<POE::Session|POE::Session>
class authors.

=head3 session_alloc SESSION_OBJECT [, START_ARGS]

session_alloc() allocates a session context within POE::Kernel for a
newly created SESSION_OBJECT.  A list of optional START_ARGS will be
passed to the session as part of the L</_start> event.

The SESSION_OBJECT is expected to follow a subset of POE::Session's
interface.

There is no session_free().  POE::Kernel determines when the session
should stop and performs the necessary cleanup after dispatching _stop
to the session.

=head2 Miscellaneous Methods

We don't know where to classify the methods in this section.

=head3 new

It is not necessary to call POE::Kernel's new() method.  Doing so will
return the program's singleton POE::Kernel object, however.

=head1 PUBLIC EXPORTED VARIABLES

POE::Kernel exports two variables for your coding enjoyment:
C<$poe_kernel> and C<$poe_main_window>.  POE::Kernel is implicitly
used by POE itself, so using POE gets you POE::Kernel (and its
exports) for free.

In more detail:

=head2 $poe_kernel

C<$poe_kernel> contains a reference to the process' POE::Kernel singleton
instance. It's mainly used for accessing POE::Kernel methods from places
where C<$_[KERNEL]> is not available.  It's most commonly used in helper
libraries.

=head2 $poe_main_window

$poe_main_window is used by graphical toolkits that require at least
one widget to be created before their event loops are usable.  This is
currently only Tk.

L<POE::Loop::Tk|POE::Loop::Tk> creates a main window to satisfy Tk's
event loop.  The window is given to the application since POE has no
other use for it.

C<$poe_main_window> is undefined in toolkits that don't require a
widget to dispatch events.

On a related note, POE will shut down if the widget in
C<$poe_main_window> is destroyed.  This can be changed with
POE::Kernel's L</signal_ui_destroy> method.

=head1 DEBUGGING POE AND PROGRAMS USING IT

POE includes quite a lot of debugging code, in the form of both fatal
assertions and run-time traces.  They may be enabled at compile time,
but there is no way to toggle them at run-time.  This was done to
avoid run-time penalties in programs where debugging is not necessary.
That is, in most production cases.

Traces are verbose reminders of what's going on within POE.  Each is
prefixed with a four-character field describing the POE subsystem that
generated it.

Assertions (asserts) are quiet but deadly, both in performance (they
cause a significant run-time performance hit) and because they cause
fatal errors when triggered.

The assertions and traces are useful for developing programs with POE,
but they were originally added to debug POE itself.

Each assertion and tracing group is enabled by setting a constant in
the POE::Kernel namespace to a true value.  This is the same mechanism
documented under L</"Using Time::HiRes">, namely:

  BEGIN {
    package POE::Kernel;
    use constant ASSERT_DEFAULT => 1;
  }
  use POE;

or

  sub POE::Kernel::ASSERT_DEFAULT () { 1 }
  use POE;

As mentioned in L</"Using Time::HiRes">, the switches must be defined as
constants before POE::Kernel is first loaded.  Otherwise Perl's
compiler will not see the constants when first compiling POE::Kernel,
and the features will not be properly enabled.

Assertions and traces may also be enabled by setting shell environment
variables.  The environment variables are named after the POE::Kernel
constants with a "POE_" prefix.

  POE_ASSERT_DEFAULT=1 POE_TRACE_DEFAULT=1 ./my_poe_program

In alphabetical order:

=head2 ASSERT_DATA

ASSERT_DATA enables run-time data integrity checks within POE::Kernel
and the classes that mix into it.  POE::Kernel tracks a lot of
cross-referenced data, and this group of assertions ensures that it's
consistent.

Prefix: <dt>

Environment variable: POE_ASSERT_DATA

=head2 ASSERT_DEFAULT

ASSERT_DEFAULT specifies the default value for assertions that are not
explicitly enabled or disabled.  This is a quick and reliable way to
make sure all assertions are on.

No assertion uses ASSERT_DEFAULT directly, and this assertion flag has
no corresponding output prefix.

Turn on all assertions except ASSERT_EVENTS:

  sub POE::Kernel::ASSERT_DEFAULT () { 1 }
  sub POE::Kernel::ASSERT_EVENTS  () { 0 }
  use POE::Kernel;

Prefix: (none)

Environment variable: POE_ASSERT_DEFAULT

=head2 ASSERT_EVENTS

ASSERT_EVENTS mainly checks for attempts to dispatch events to
sessions that don't exist.  This assertion can assist in the debugging
of strange, silent cases where event handlers are not called.

Prefix: <ev>

Environment variable: POE_ASSERT_EVENTS

=head2 ASSERT_FILES

ASSERT_FILES enables some run-time checks in POE's filehandle watchers
and the code that manages them.

Prefix: <fh>

Environment variable: POE_ASSERT_FILES

=head2 ASSERT_RETVALS

ASSERT_RETVALS upgrades failure codes from POE::Kernel's methods from
advisory return values to fatal errors.  Most programmers don't check
the values these methods return, so ASSERT_RETVALS is a quick way to
validate one's assumption that all is correct.

Prefix: <rv>

Environment variable: POE_ASSERT_RETVALS

=head2 ASSERT_USAGE

ASSERT_USAGE is the counterpoint to ASSERT_RETVALS.  It enables
run-time checks that the parameters to POE::Kernel's methods are
correct.  It's a quick (but not foolproof) way to verify a program's
use of POE.

Prefix: <us>

Environment variable: POE_ASSERT_USAGE

=head2 TRACE_DEFAULT

TRACE_DEFAULT specifies the default value for traces that are not
explicitly enabled or disabled.  This is a quick and reliable way to
ensure your program generates copious output on the file named in
TRACE_FILENAME or STDERR by default.

To enable all traces except a few noisier ones:

  sub POE::Kernel::TRACE_DEFAULT () { 1 }
  sub POE::Kernel::TRACE_EVENTS  () { 0 }
  use POE::Kernel;

Prefix: (none)

Environment variable: POE_TRACE_DEFAULT

=head2 TRACE_DESTROY

TRACE_DESTROY causes every POE::Session object to dump the contents of
its C<$_[HEAP]> when Perl destroys it.  This trace was added to help
developers find memory leaks in their programs.

Prefix: A line that reads "----- Session $self Leak Check -----".

Environment variable: POE_TRACE_DESTROY

=head2 TRACE_EVENTS

TRACE_EVENTS enables messages pertaining to POE's event queue's
activities: when events are enqueued, dispatched or discarded, and
more.  It's great for determining where events go and when.
Understandably this is one of POE's more verbose traces.

Prefix: <ev>

Environment variable: POE_TRACE_EVENTS

=head2 TRACE_FILENAME

TRACE_FILENAME specifies the name of a file where POE's tracing and
assertion messages should go.  It's useful if you want the messages
but have other plans for STDERR, which is where the messages go by
default.

POE's tests use this so the trace and assertion code can be
instrumented during testing without spewing all over the terminal.

Prefix: (none)

Environment variable: POE_TRACE_FILENAME

=head2 TRACE_FILES

TRACE_FILES enables or disables traces in POE's filehandle watchers and
the L<POE::Loop|POE::Loop> class that implements the lowest-level filehandle
multiplexing.  This may be useful when tracking down strange behavior
related to filehandles.

Prefix: <fh>

Environment variable: POE_TRACE_FILES

=head2 TRACE_PROFILE

TRACE_PROFILE enables basic profiling within POE's event dispatcher.
When enabled, POE counts the number of times each event is dispatched.
At the end of a run, POE will display a table for each event name and
its dispatch count.

See TRACE_STATISTICS for more profiling.

Prefix: <pr>

Environment variable: POE_TRACE_PROFILE

=head3 stat_show_profile

When TRACE_PROFILE is enabled, a program may call
C<< $_[KERNEL]->stat_show_profile() >> to display a current dispatch
profile snapshot.

=head3 stat_getprofile [ SESSION ]

stat_getprofile() returns a hash of events and the number of times
they were dispatched.  It only returns meaningful data if
TRACE_PROFILE is enabled.

Without the optional SESSION parameter, stat_getprofile() returns
cumulative statistics for the entire program.

When given a valid SESSION, stat_getprofile() will return profile
statistics for that session.

stat_getprofile() returns nothing if TRACE_PROFILE isn't enabled, or
if the given SESSION doesn't exist.

=head2 TRACE_REFCNT

TRACE_REFCNT governs whether POE::Kernel will trace sessions'
reference counts.  As discussed in L</"Session Lifespans">, POE does a
lot of reference counting, and the current state of a session's
reference counts determines whether the session lives or dies.  It's
common for developers to wonder why a session stops too early or
remains active too long.  TRACE_REFCNT can help explain why.

Prefix: <rc>

Environment variable: POE_TRACE_REFCNT

=head2 TRACE_RETVALS

TRACE_RETVALS can enable carping whenever a POE::Kernel method is
about to fail.  It's a non-fatal but noisier form of
ASSERT_RETVALS.

Prefix: <rv>

Environment variable: POE_TRACE_RETVALS

=head2 TRACE_SESSIONS

TRACE_SESSIONS enables trace messages that pertain to session
management.  Notice will be given when sessions are created or
destroyed, and when the parent or child status of a session changes.

Prefix: <ss>

Environment variable: POE_TRACE_SESSIONS

=head2 TRACE_SIGNALS

TRACE_SIGNALS turns on (or off) traces in POE's signal handling
subsystem.  Signal dispatch is one of POE's more complex parts, and
the trace messages may help application developers understand signal
propagation and timing.

Prefix: <sg>

Environment variable: POE_TRACE_SIGNALS

=head2 TRACE_STATISTICS

B<This feature is experimental, and its interface will likely change.>

TRACE_STATISTICS enables run-time gathering and reporting of various
performance metrics within a POE program.  Some statistics include how
much time is spent processing event handlers, time spent in POE's
dispatcher, and the time spent waiting for an event.  A report is
displayed just before run() returns, and the data can be retrieved at
any time using stat_getdata().

See L<POE::Resource::Statistics> for more details about POE's
statistics.

=head3 stat_getdata

stat_getdata() returns a hash of various statistics and their values
The statistics are calculated using a sliding window and vary over
time as a program runs.  It only returns meaningful data if
TRACE_STATISTICS is enabled.

See L<POE::Resource::Statistics/Gathered Statistics> for details about
what is gathered.

=head1 ADDITIONAL CONSTANTS

These additional constants govern POE's operation.

=head2 USE_TIME_HIRES

Whether or not to use L<Time::HiRes> for timing purposes.

See L</"Using Time::HiRes">.

=head2 USE_SIGCHLD

Whether to use C<$SIG{CHLD}> or to poll at an interval.

This flag is disabled by default, and enabling it may cause breakage
under older perls with no safe signals, and under L<Apache> which uses
C<$SIG{CHLD}>.

Enabling this flag will cause child reaping to happen almost
immediately, as opposed to once per L</CHILD_POLLING_INTERVAL>.

=head2 CHILD_POLLING_INTERVAL

The interval at which C<wait> is called to determine if child
processes need to be reaped and the C<CHLD> signal emulated.

Defaults to 1 second.

=head2 USE_SIGNAL_PIPE

The only safe way to handle signals is to implement a shared-nothing
model.  POE builds a I<signal pipe> that communicates between the
signal handlers and the POE kernel loop in a safe and atomic manner.
The signal pipe is implemented with L<POE::Pipe::OneWay>, using a
C<pipe> conduit on Unix.  Unfortunately, the signal pipe is not compatible
with Windows and is not used on that platform.

If you wish to revert to the previous unsafe signal behaviour, you
must set C<USE_SIGNAL_PIPE> to 0, or the environment variable
C<POE_USE_SIGNAL_PIPE>.

=head2 CATCH_EXCEPTIONS

Whether or not POE should run event handler code in an eval { } and
deliver the C<DIE> signal on errors.

See L</"Exception Handling">.

=head1 ENVIRONMENT VARIABLES FOR TESTING

POE's tests are lovely, dark and deep.  These environment variables
allow testers to take roads less traveled.

=head2 POE_DANTIC

Windows and Perls built for it tend to be poor at doing UNIXy things,
although they do try.  POE being very UNIXy itself must skip a lot of
Windows tests.  The POE_DANTIC environment variable will, when true,
enable all these tests.  It's intended to be used from time to time to
see whether Windows has improved in some area.

=head1 SEE ALSO

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

=over

=item *

There is no mechanism in place to prevent external reference count
names from clashing.

=item *

There is no mechanism to catch exceptions generated in another session.

=back

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - More practical examples.
# TODO - Test the examples.
# TODO - Edit.
