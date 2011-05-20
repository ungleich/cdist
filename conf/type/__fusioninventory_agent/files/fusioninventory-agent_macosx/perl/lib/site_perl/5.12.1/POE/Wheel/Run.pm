package POE::Wheel::Run;

use strict;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = 'POE::Wheel';

use Carp qw(carp croak);
use POSIX qw(
  sysconf setsid _SC_OPEN_MAX ECHO ICANON IEXTEN ISIG BRKINT ICRNL
  INPCK ISTRIP IXON CSIZE PARENB OPOST TCSANOW
);

use POE qw( Wheel Pipe::TwoWay Pipe::OneWay Driver::SysRW Filter::Line );
use base qw(POE::Wheel);

# http://rt.cpan.org/Ticket/Display.html?id=50068
# Avoid using these constants in Windows' subprocesses (actually
# interpreter threads).  Reported in the above ticket to avoid a
# memory leak.
my ($STD_INPUT_HANDLE, $STD_OUTPUT_HANDLE, $STD_ERROR_HANDLE);

BEGIN {
  die "$^O does not support fork()\n" if $^O eq 'MacOS';

  local $SIG{'__DIE__'} = 'DEFAULT';
  eval    { require IO::Pty; };
  if ($@) { eval 'sub PTY_AVAILABLE () { 0 }';  }
  else {
    IO::Pty->import();
    eval 'sub PTY_AVAILABLE () { 1 }';
  }

  if (POE::Kernel::RUNNING_IN_HELL) {
    eval    { require Win32::Console; Win32::Console->import() };
    if ($@) { die "Win32::Console needed for POE::Wheel::Run on $^O:\n$@" }

    eval    {
      require Win32API::File;
      Win32API::File->import("FdGetOsFHandle");
    };
    if ($@) { die "Win32API::File needed for POE::Wheel::Run on $^O:\n$@" }

    eval    { require Win32::Process; Win32::Process->import() };
    if ($@) { die "Win32::Process needed for POE::Wheel::Run on $^O:\n$@" }

    eval    { require Win32::Job; Win32::Job->import() };
    if ($@) { die "Win32::Job needed for POE::Wheel::Run on $^O:\n$@" }

    eval    { require Win32; Win32->import() };
    if ($@) { die "Win32.pm needed for POE::Wheel::Run on $^O:\n$@" }

    $STD_INPUT_HANDLE  = STD_INPUT_HANDLE();
    $STD_OUTPUT_HANDLE = STD_OUTPUT_HANDLE();
    $STD_ERROR_HANDLE  = STD_ERROR_HANDLE();
  }

  # Determine the most file descriptors we can use.
  my $max_open_fds;
  eval {
    $max_open_fds = sysconf(_SC_OPEN_MAX);
  };
  $max_open_fds = 1024 unless $max_open_fds;
  eval "sub MAX_OPEN_FDS () { $max_open_fds }";
  die if $@;
};

# Offsets into $self.
sub UNIQUE_ID     () {  0 }
sub ERROR_EVENT   () {  1 }
sub CLOSE_EVENT   () {  2 }
sub PROGRAM       () {  3 }
sub CHILD_PID     () {  4 }
sub CONDUIT_TYPE  () {  5 }
sub IS_ACTIVE     () {  6 }
sub CLOSE_ON_CALL () {  7 }
sub STDIO_TYPE    () {  8 }

sub HANDLE_STDIN  () {  9 }
sub FILTER_STDIN  () { 10 }
sub DRIVER_STDIN  () { 11 }
sub EVENT_STDIN   () { 12 }
sub STATE_STDIN   () { 13 }
sub OCTETS_STDIN  () { 14 }

sub HANDLE_STDOUT () { 15 }
sub FILTER_STDOUT () { 16 }
sub DRIVER_STDOUT () { 17 }
sub EVENT_STDOUT  () { 18 }
sub STATE_STDOUT  () { 19 }

sub HANDLE_STDERR () { 20 }
sub FILTER_STDERR () { 21 }
sub DRIVER_STDERR () { 22 }
sub EVENT_STDERR  () { 23 }
sub STATE_STDERR  () { 24 }

sub MSWIN32_GROUP_PID () { 25 }

# Used to work around a bug in older perl versions.
sub CRIMSON_SCOPE_HACK ($) { 0 }

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  croak "$type needs an even number of parameters" if @_ & 1;
  my %params = @_;

  croak "wheels no longer require a kernel reference as their first parameter"
    if @_ and ref($_[0]) eq 'POE::Kernel';

  croak "$type requires a working Kernel" unless defined $poe_kernel;

  my $program = delete $params{Program};
  croak "$type needs a Program parameter" unless defined $program;

  my $prog_args = delete $params{ProgramArgs};
  $prog_args = [] unless defined $prog_args;
  croak "ProgramArgs must be an ARRAY reference"
    unless ref($prog_args) eq "ARRAY";

  my $priority_delta = delete $params{Priority};
  $priority_delta = 0 unless defined $priority_delta;

  my $close_on_call = delete $params{CloseOnCall};
  $close_on_call = 0 unless defined $close_on_call;

  my $user_id  = delete $params{User};
  my $group_id = delete $params{Group};

  # The following $stdio_type is new.  $conduit is kept around for now
  # to preserve the logic of the rest of the module.  This change
  # allows a Session using POE::Wheel::Run to define the type of pipe
  # to be created for stdin and stdout.  Read the POD on Conduit.
  # However, the documentation lies, because if Conduit is undefined,
  # $stdio_type is set to undefined (so the default pipe type provided
  # by POE::Pipe::TwoWay will be used). Otherwise, $stdio_type
  # determines what type of pipe Pipe:TwoWay creates unless it's
  # 'pty'.

  my $conduit = delete $params{Conduit};
  my $stdio_type;
  if (defined $conduit) {
    croak "$type\'s Conduit type ($conduit) is unknown" if (
      $conduit ne 'pipe' and
      $conduit ne 'pty'  and
      $conduit ne 'pty-pipe' and
      $conduit ne 'socketpair' and
      $conduit ne 'inet'
    );
    unless ($conduit =~ /^pty(-pipe)?$/) {
      $stdio_type = $conduit;
      $conduit = "pipe";
    }
  }
  else {
    $conduit = "pipe";
  }

  # TODO remove deprecation warning after some time
  carp "Winsize is deprecated." if exists $params{Winsize};
  delete $params{Winsize};  # so the unknown arg check doesn't complain

  my $stdin_event  = delete $params{StdinEvent};
  my $stdout_event = delete $params{StdoutEvent};
  my $stderr_event = delete $params{StderrEvent};

  if ($conduit eq 'pty' and defined $stderr_event) {
    carp "ignoring StderrEvent with pty conduit";
    undef $stderr_event;
  }

  croak "$type needs at least one of StdinEvent, StdoutEvent or StderrEvent"
    unless(
      defined($stdin_event) or defined($stdout_event) or
      defined($stderr_event)
    );

  my $stdio_driver  = delete $params{StdioDriver}  || POE::Driver::SysRW->new();
  my $stdin_driver  = delete $params{StdinDriver}  || $stdio_driver;
  my $stdout_driver = delete $params{StdoutDriver} || $stdio_driver;
  my $stderr_driver = delete $params{StderrDriver} || POE::Driver::SysRW->new();

  my $stdio_filter  = delete $params{Filter};
  my $stdin_filter  = delete $params{StdinFilter};
  my $stdout_filter = delete $params{StdoutFilter};
  my $stderr_filter = delete $params{StderrFilter};

  if (defined $stdio_filter) {
    croak "Filter and StdioFilter cannot be used together"
      if defined $params{StdioFilter};
    croak "Replace deprecated Filter with StdioFilter and StderrFilter"
      if defined $stderr_event and not defined $stderr_filter;
    carp "Filter is deprecated.  Please try StdioFilter and/or StderrFilter";
  }
  else {
    $stdio_filter = delete $params{StdioFilter};
  }
  $stdio_filter = POE::Filter::Line->new(Literal => "\n")
    unless defined $stdio_filter;

  $stdin_filter  = $stdio_filter unless defined $stdin_filter;
  $stdout_filter = $stdio_filter unless defined $stdout_filter;

  if ($conduit eq 'pty' and defined $stderr_filter) {
    carp "ignoring StderrFilter with pty conduit";
    undef $stderr_filter;
  }
  else {
    $stderr_filter = POE::Filter::Line->new(Literal => "\n")
      unless defined $stderr_filter;
  }

  croak "$type needs either StdioFilter or StdinFilter when using StdinEvent"
    if defined($stdin_event) and not defined($stdin_filter);
  croak "$type needs either StdioFilter or StdoutFilter when using StdoutEvent"
    if defined($stdout_event) and not defined($stdout_filter);
  croak "$type needs a StderrFilter when using StderrEvent"
    if defined($stderr_event) and not defined($stderr_filter);

  my $error_event = delete $params{ErrorEvent};
  my $close_event = delete $params{CloseEvent};

  my $no_setsid = delete $params{NoSetSid};
  my $no_setpgrp = delete $params{NoSetPgrp};

  # Make sure the user didn't pass in parameters we're not aware of.
  if (scalar keys %params) {
    carp(
      "unknown parameters in $type constructor call: ",
      join(', ', sort keys %params)
    );
  }

  my (
    $stdin_read, $stdout_write, $stdout_read, $stdin_write,
    $stderr_read, $stderr_write,
  );

  # Create a semaphore pipe.  This is used so that the parent doesn't
  # begin listening until the child's stdio has been set up.
  my ($sem_pipe_read, $sem_pipe_write) = POE::Pipe::OneWay->new();
  croak "could not create semaphore pipe: $!" unless defined $sem_pipe_read;

  # Use IO::Pty if requested.  IO::Pty turns on autoflush for us.
  if ($conduit =~ /^pty(-pipe)?$/) {
    croak "IO::Pty is not available" unless PTY_AVAILABLE;

    $stdin_write = $stdout_read = IO::Pty->new();
    croak "could not create master pty: $!" unless defined $stdout_read;

    if ($conduit eq "pty-pipe") {
      ($stderr_read, $stderr_write) = POE::Pipe::OneWay->new();
      croak "could not make stderr pipes: $!"
        unless defined $stderr_read and defined $stderr_write;
    }
  }

  # Use pipes otherwise.
  elsif ($conduit eq 'pipe') {
    # We make more pipes than strictly necessary in case someone wants
    # to turn some on later.  Uses a TwoWay pipe for STDIN/STDOUT and
    # a OneWay pipe for STDERR.  This may save 2 filehandles if
    # socketpair() is available and no other $stdio_type is selected.
    ($stdin_read, $stdout_write, $stdout_read, $stdin_write) =
      POE::Pipe::TwoWay->new($stdio_type);
    croak "could not make stdin pipe: $!"
      unless defined $stdin_read and defined $stdin_write;
    croak "could not make stdout pipe: $!"
      unless defined $stdout_read and defined $stdout_write;

    ($stderr_read, $stderr_write) = POE::Pipe::OneWay->new();
    croak "could not make stderr pipes: $!"
      unless defined $stderr_read and defined $stderr_write;
  }

  # Sanity check.
  else {
    croak "unknown conduit type $conduit";
  }

  # Block signals until safe
  my $must_unmask;
  if( $poe_kernel->can( '_data_sig_mask_all' ) ) {
    $poe_kernel->_data_sig_mask_all;
    $must_unmask = 1;
  }

  # Fork!  Woo-hoo!
  my $pid = fork;

  # Child.  Parent side continues after this block.
  unless ($pid) {
    # removed the croak because it wasn't "safe" RT#56417
    #croak "couldn't fork: $!" unless defined $pid;
    # ANY OTHER DIE/CROAK/EXIT/WHATEVER in the child MUST use the helper!
    __PACKAGE__->_warn_and_exit_child( "couldn't fork: $!", int( $! ) )
      unless defined $pid;

    # Stdio should not be tied.  Resolves rt.cpan.org ticket 1648.
    if (tied *STDOUT) {
      carp "Cannot redirect into tied STDOUT.  Untying it";
      untie *STDOUT;
    }

    if (tied *STDERR) {
      carp "Cannot redirect into tied STDERR.  Untying it";
      untie *STDERR;
    }

    # If running pty, we delay the slave side creation 'til after
    # doing the necessary bits to become our own [unix] session.
    if ($conduit =~ /^pty(-pipe)?$/) {

      # Become a new unix session.
      # Program 19.3, APITUE.  W. Richard Stevens built my hot rod.
      eval 'setsid()' unless $no_setsid;

      # Acquire a controlling terminal.  Program 19.3, APITUE.
      $stdin_write->make_slave_controlling_terminal();

      # Open the slave side of the pty.
      $stdin_read = $stdout_write = $stdin_write->slave();
      __PACKAGE__->_warn_and_exit_child( "could not create slave pty: $!", int( $! ) )
        unless defined $stdin_read;

      # For a simple pty conduit, stderr is wedged into stdout.
      $stderr_write = $stdout_write if $conduit eq 'pty';

      # Put the pty conduit (slave side) into "raw" or "cbreak" mode,
      # per APITUE 19.4 and 11.10.
      $stdin_read->set_raw();

      # Set the pty conduit (slave side) window size to our window
      # size.  APITUE 19.4 and 19.5.
      eval { $stdin_read->clone_winsize_from(\*STDIN) };
    }
    else {
      # TODO - Can this be block eval?  Or a do{} block?
      eval 'setpgrp(0,0)' unless $no_setpgrp;
    }

    # Reset all signals in the child process.  POE's own handlers are
    # silly to keep around in the child process since POE won't be
    # using them.
    my @safe_signals = $poe_kernel->_data_sig_get_safe_signals();
    @SIG{@safe_signals} = ("DEFAULT") x @safe_signals;
    $poe_kernel->_data_sig_unmask_all if $must_unmask;

    # TODO How to pass events to the parent process?  Maybe over a
    # expedited (OOB) filehandle.

    # Fix the child process' priority.  Don't bother doing this if it
    # wasn't requested.  Can't emit events on failure because we're in
    # a separate process, so just fail quietly.

    if ($priority_delta) {
      eval {
        if (defined(my $priority = getpriority(0, $$))) {
          unless (setpriority(0, $$, $priority + $priority_delta)) {
            # TODO can't set child priority
          }
        }
        else {
          # TODO can't get child priority
        }
      };
      if ($@) {
        # TODO can't get child priority
      }
    }

    # Fix the group ID.  TODO Add getgrnam so group IDs can be
    # specified by name.  TODO Warn if not superuser to begin with.
    if (defined $group_id) {
      $( = $) = $group_id;
    }

    # Fix the user ID.  TODO Add getpwnam so user IDs can be specified
    # by name.  TODO Warn if not superuser to begin with.
    if (defined $user_id) {
      $< = $> = $user_id;
    }

    # Close what the child won't need.
    close $stdin_write;
    close $stdout_read;
    close $stderr_read if defined $stderr_read;

    if (POE::Kernel::RUNNING_IN_HELL) {
      __PACKAGE__->_redirect_child_stdio_in_hell(
        $stdin_read, $stdout_write, $stderr_write
      );
    }
    else {
      __PACKAGE__->_redirect_child_stdio_sanely(
        $stdin_read, $stdout_write, $stderr_write
      );
    }

    # Make STDOUT and/or STDERR auto-flush.
    select STDERR;  $| = 1;
    select STDOUT;  $| = 1;

    # The child doesn't need to read from the semaphore pipe.
    $sem_pipe_read = undef;

    # Run Perl code.  This is farily consistent across most systems.
    if (ref($program) eq 'CODE') {

      # Tell the parent that the stdio has been set up.
      print $sem_pipe_write "go\n";
      close $sem_pipe_write;

      # Close any close-on-exec file descriptors.  Except STDIN,
      # STDOUT, and STDERR, of course.
      if ($close_on_call) {
        for (0..MAX_OPEN_FDS-1) {
          next if fileno(STDIN)  == $_;
          next if fileno(STDOUT) == $_;
          next if fileno(STDERR) == $_;
          POSIX::close($_);
        }
      }

      # TODO what if the program tries to exit? It needs to use
      # our _exit_child_any_way_we_can handler...
      # Should we replace CORE::exit? CORE::die too? blahhhhhh
      # We've documented that users should not do it, but who knows!
      eval { $program->(@$prog_args) };

      my $exitval;
      if ($@) {
        chomp $@;
        warn "$@\n";
        $exitval = -1;
      }

      __PACKAGE__->_exit_child_any_way_we_can( $exitval || 0 );
    }

    # Execute an external program.  This gets weird.

    # Windows! What I do for you!
    __PACKAGE__->_exec_in_hell(
      $close_on_call, $sem_pipe_write, $program, $prog_args
    ) if POE::Kernel::RUNNING_IN_HELL;

    # Everybody else seems sane.
    # Tell the parent that the stdio has been set up.
    print $sem_pipe_write "go\n";
    close $sem_pipe_write;

    # exec(ARRAY)
    if (ref($program) eq 'ARRAY') {
      exec(@$program, @$prog_args)
         or __PACKAGE__->_warn_and_exit_child(
           "can't exec (@$program) in child pid $$: $!", int( $! ) );
    }

    # exec(SCALAR)
    exec(join(" ", $program, @$prog_args))
      or __PACKAGE__->_warn_and_exit_child(
        "can't exec ($program) in child pid $$: $!", int( $! ) );
  }

  # Parent here.  Close what the parent won't need.
  defined($stdin_read)   and close $stdin_read;
  defined($stdout_write) and close $stdout_write;
  defined($stderr_write) and close $stderr_write;

  # Also close any slave ptys
  $stdout_read->close_slave() if (
    defined $stdout_read and ref($stdout_read) eq 'IO::Pty'
  );

  $stderr_read->close_slave() if (
    defined $stderr_read and ref($stderr_read) eq 'IO::Pty'
  );

  my $active_count = 0;
  $active_count++ if $stdout_event and $stdout_read;
  $active_count++ if $stderr_event and $stderr_read;

  my $self = bless [
    &POE::Wheel::allocate_wheel_id(),  # UNIQUE_ID
    $error_event,   # ERROR_EVENT
    $close_event,   # CLOSE_EVENT
    $program,       # PROGRAM
    $pid,           # CHILD_PID
    $conduit,       # CONDUIT_TYPE
    $active_count,  # IS_ACTIVE
    $close_on_call, # CLOSE_ON_CALL
    $stdio_type,    # STDIO_TYPE
    # STDIN
    $stdin_write,   # HANDLE_STDIN
    $stdin_filter,  # FILTER_STDIN
    $stdin_driver,  # DRIVER_STDIN
    $stdin_event,   # EVENT_STDIN
    undef,          # STATE_STDIN
    0,              # OCTETS_STDIN
    # STDOUT
    $stdout_read,   # HANDLE_STDOUT
    $stdout_filter, # FILTER_STDOUT
    $stdout_driver, # DRIVER_STDOUT
    $stdout_event,  # EVENT_STDOUT
    undef,          # STATE_STDOUT
    # STDERR
    $stderr_read,   # HANDLE_STDERR
    $stderr_filter, # FILTER_STDERR
    $stderr_driver, # DRIVER_STDERR
    $stderr_event,  # EVENT_STDERR
    undef,          # STATE_STDERR
    undef,          # MSWIN32_GROUP_PID
  ], $type;

  # PG- I suspect <> might need PIPE
  $poe_kernel->_data_sig_unmask_all if $must_unmask;

  # Wait here while the child sets itself up.
  $sem_pipe_write = undef;
  {
    local $/ = "\n";  # TODO - Needed?
    my $chldout = <$sem_pipe_read>;
    chomp $chldout;
    $self->[MSWIN32_GROUP_PID] = $chldout if $chldout ne 'go';
  }
  close $sem_pipe_read;

  $self->_define_stdin_flusher();
  $self->_define_stdout_reader() if defined $stdout_read;
  $self->_define_stderr_reader() if defined $stderr_read;

  return $self;
}

#------------------------------------------------------------------------------
# Define the internal state that will flush output to the child
# process' STDIN pipe.

sub _define_stdin_flusher {
  my $self = shift;

  # Read-only members.  If any of these change, then the write state
  # is invalidated and needs to be redefined.
  my $unique_id    = $self->[UNIQUE_ID];
  my $driver       = $self->[DRIVER_STDIN];
  my $error_event  = \$self->[ERROR_EVENT];
  my $close_event  = \$self->[CLOSE_EVENT];
  my $stdin_filter = $self->[FILTER_STDIN];
  my $stdin_event  = \$self->[EVENT_STDIN];
  my $is_active    = \$self->[IS_ACTIVE];

  # Read/write members.  These are done by reference, to avoid pushing
  # $self into the anonymous sub.  Extra copies of $self are bad and
  # can prevent wheels from destructing properly.
  my $stdin_octets = \$self->[OCTETS_STDIN];

  # Register the select-write handler.
  $poe_kernel->state(
    $self->[STATE_STDIN] = ref($self) . "($unique_id) -> select stdin",
    sub {                             # prevents SEGV
      0 && CRIMSON_SCOPE_HACK('<');
                                      # subroutine starts here
      my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];

      $$stdin_octets = $driver->flush($handle);

      # When you can't write, nothing else matters.
      if ($!) {
        $$error_event && $k->call(
          $me, $$error_event,
          'write', ($!+0), $!, $unique_id, "STDIN"
        );
        $k->select_write($handle);
      }

      # Could write, or perhaps couldn't but only because the
      # filehandle's buffer is choked.
      else {

        # All chunks written; fire off a "flushed" event.
        unless ($$stdin_octets) {
          $k->select_pause_write($handle);
          $$stdin_event && $k->call($me, $$stdin_event, $unique_id);
        }
      }
    }
  );

  $poe_kernel->select_write($self->[HANDLE_STDIN], $self->[STATE_STDIN]);

  # Pause the write select immediately, unless output is pending.
  $poe_kernel->select_pause_write($self->[HANDLE_STDIN])
    unless ($self->[OCTETS_STDIN]);
}

#------------------------------------------------------------------------------
# Define the internal state that will read input from the child
# process' STDOUT pipe.  This is virtually identical to
# _define_stderr_reader, but they aren't implemented as a common
# function for speed reasons.

sub _define_stdout_reader {
  my $self = shift;

  # Can't do anything if we don't have a handle.
  return unless defined $self->[HANDLE_STDOUT];

  # No event?  Unregister the handler and leave.
  my $stdout_event  = \$self->[EVENT_STDOUT];
  unless ($$stdout_event) {
    $poe_kernel->select_read($self->[HANDLE_STDOUT]);
    return;
  }

  # If any of these change, then the read state is invalidated and
  # needs to be redefined.
  my $unique_id     = $self->[UNIQUE_ID];
  my $driver        = $self->[DRIVER_STDOUT];
  my $stdout_filter = $self->[FILTER_STDOUT];

  # These can change without redefining the callback since they're
  # enclosed by reference.
  my $is_active     = \$self->[IS_ACTIVE];
  my $close_event   = \$self->[CLOSE_EVENT];
  my $error_event   = \$self->[ERROR_EVENT];

  # Register the select-read handler for STDOUT.
  if (
    $stdout_filter->can("get_one") and
    $stdout_filter->can("get_one_start")
  ) {
    $poe_kernel->state(
      $self->[STATE_STDOUT] = ref($self) . "($unique_id) -> select stdout",
      sub {
        # prevents SEGV
        0 && CRIMSON_SCOPE_HACK('<');

        # subroutine starts here
        my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];
        if (defined(my $raw_input = $driver->get($handle))) {
          $stdout_filter->get_one_start($raw_input);
          while (1) {
            my $next_rec = $stdout_filter->get_one();
            last unless @$next_rec;
            foreach my $cooked_input (@$next_rec) {
              $k->call($me, $$stdout_event, $cooked_input, $unique_id);
            }
          }
        }
        else {
          $$error_event and $k->call(
            $me, $$error_event,
            'read', ($!+0), $!, $unique_id, 'STDOUT'
          );
          unless (--$$is_active) {
            $k->call( $me, $$close_event, $unique_id )
              if defined $$close_event;
          }
          $k->select_read($handle);
        }
      }
    );
  }

  # Otherwise we can't get one.
  else {
    $poe_kernel->state(
      $self->[STATE_STDOUT] = ref($self) . "($unique_id) -> select stdout",
      sub {
        # prevents SEGV
        0 && CRIMSON_SCOPE_HACK('<');

        # subroutine starts here
        my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];
        if (defined(my $raw_input = $driver->get($handle))) {
          foreach my $cooked_input (@{$stdout_filter->get($raw_input)}) {
            $k->call($me, $$stdout_event, $cooked_input, $unique_id);
          }
        }
        else {
          $$error_event and
            $k->call(
              $me, $$error_event,
              'read', ($!+0), $!, $unique_id, 'STDOUT'
            );
          unless (--$$is_active) {
            $k->call( $me, $$close_event, $unique_id )
              if defined $$close_event;
          }
          $k->select_read($handle);
        }
      }
    );
  }

  # register the state's select
  $poe_kernel->select_read($self->[HANDLE_STDOUT], $self->[STATE_STDOUT]);
}

#------------------------------------------------------------------------------
# Define the internal state that will read input from the child
# process' STDERR pipe.

sub _define_stderr_reader {
  my $self = shift;

  # Can't do anything if we don't have a handle.
  return unless defined $self->[HANDLE_STDERR];

  # No event?  Unregister the handler and leave.
  my $stderr_event  = \$self->[EVENT_STDERR];
  unless ($$stderr_event) {
    $poe_kernel->select_read($self->[HANDLE_STDERR]);
    return;
  }

  my $unique_id     = $self->[UNIQUE_ID];
  my $driver        = $self->[DRIVER_STDERR];
  my $stderr_filter = $self->[FILTER_STDERR];

  # These can change without redefining the callback since they're
  # enclosed by reference.
  my $error_event   = \$self->[ERROR_EVENT];
  my $close_event   = \$self->[CLOSE_EVENT];
  my $is_active     = \$self->[IS_ACTIVE];

  # Register the select-read handler for STDERR.
  if (
    $stderr_filter->can("get_one") and
    $stderr_filter->can("get_one_start")
  ) {
    $poe_kernel->state(
      $self->[STATE_STDERR] = ref($self) . "($unique_id) -> select stderr",
      sub {
        # prevents SEGV
        0 && CRIMSON_SCOPE_HACK('<');

        # subroutine starts here
        my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];
        if (defined(my $raw_input = $driver->get($handle))) {
          $stderr_filter->get_one_start($raw_input);
          while (1) {
            my $next_rec = $stderr_filter->get_one();
            last unless @$next_rec;
            foreach my $cooked_input (@$next_rec) {
              $k->call($me, $$stderr_event, $cooked_input, $unique_id);
            }
          }
        }
        else {
          $$error_event and $k->call(
            $me, $$error_event,
            'read', ($!+0), $!, $unique_id, 'STDERR'
          );
          unless (--$$is_active) {
            $k->call( $me, $$close_event, $unique_id )
              if defined $$close_event;
          }
          $k->select_read($handle);
        }
      }
    );
  }

  # Otherwise we can't get_one().
  else {
    $poe_kernel->state(
      $self->[STATE_STDERR] = ref($self) . "($unique_id) -> select stderr",
      sub {
        # prevents SEGV
        0 && CRIMSON_SCOPE_HACK('<');

        # subroutine starts here
        my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];
        if (defined(my $raw_input = $driver->get($handle))) {
          foreach my $cooked_input (@{$stderr_filter->get($raw_input)}) {
            $k->call($me, $$stderr_event, $cooked_input, $unique_id);
          }
        }
        else {
          $$error_event and $k->call(
            $me, $$error_event,
            'read', ($!+0), $!, $unique_id, 'STDERR'
          );
          unless (--$$is_active) {
            $k->call( $me, $$close_event, $unique_id )
              if defined $$close_event;
          }
          $k->select_read($handle);
        }
      }
    );
  }

  # Register the state's select.
  $poe_kernel->select_read($self->[HANDLE_STDERR], $self->[STATE_STDERR]);
}

#------------------------------------------------------------------------------
# Redefine events.

sub event {
  my $self = shift;
  push(@_, undef) if (scalar(@_) & 1);

  my ($redefine_stdin, $redefine_stdout, $redefine_stderr) = (0, 0, 0);

  while (@_) {
    my ($name, $event) = splice(@_, 0, 2);

    if ($name eq 'StdinEvent') {
      $self->[EVENT_STDIN] = $event;
      $redefine_stdin = 1;
    }
    elsif ($name eq 'StdoutEvent') {
      $self->[EVENT_STDOUT] = $event;
      $redefine_stdout = 1;
    }
    elsif ($name eq 'StderrEvent') {
      if ($self->[CONDUIT_TYPE] ne 'pty') {
        $self->[EVENT_STDERR] = $event;
        $redefine_stderr = 1;
      }
      else {
        carp "ignoring StderrEvent on a pty conduit";
      }
    }
    elsif ($name eq 'ErrorEvent') {
      $self->[ERROR_EVENT] = $event;
    }
    elsif ($name eq 'CloseEvent') {
      $self->[CLOSE_EVENT] = $event;
    }
    else {
      carp "ignoring unknown Run parameter '$name'";
    }
  }

  # Recalculate the active handles count.
  my $active_count = 0;
  $active_count++ if $self->[EVENT_STDOUT] and $self->[HANDLE_STDOUT];
  $active_count++ if $self->[EVENT_STDERR] and $self->[HANDLE_STDERR];
  $self->[IS_ACTIVE] = $active_count;
}

#------------------------------------------------------------------------------
# Destroy the wheel.

sub DESTROY {
  my $self = shift;

  # Turn off the STDIN thing.
  if ($self->[HANDLE_STDIN]) {
    $poe_kernel->select_write($self->[HANDLE_STDIN]);
    $self->[HANDLE_STDIN] = undef;
  }
  if ($self->[STATE_STDIN]) {
    $poe_kernel->state($self->[STATE_STDIN]);
    $self->[STATE_STDIN] = undef;
  }

  if ($self->[HANDLE_STDOUT]) {
    $poe_kernel->select_read($self->[HANDLE_STDOUT]);
    $self->[HANDLE_STDOUT] = undef;
  }
  if ($self->[STATE_STDOUT]) {
    $poe_kernel->state($self->[STATE_STDOUT]);
    $self->[STATE_STDOUT] = undef;
  }

  if ($self->[HANDLE_STDERR]) {
    $poe_kernel->select_read($self->[HANDLE_STDERR]);
    $self->[HANDLE_STDERR] = undef;
  }
  if ($self->[STATE_STDERR]) {
    $poe_kernel->state($self->[STATE_STDERR]);
    $self->[STATE_STDERR] = undef;
  }

  &POE::Wheel::free_wheel_id($self->[UNIQUE_ID]);
}

#------------------------------------------------------------------------------
# Queue input for the child process.

sub put {
  my ($self, @chunks) = @_;

  # Avoid big bada boom if someone put()s on a dead wheel.
  croak "Called put() on a wheel without an open STDIN handle" unless (
    $self->[HANDLE_STDIN]
  );

  if (
    $self->[OCTETS_STDIN] =  # assignment on purpose
    $self->[DRIVER_STDIN]->put($self->[FILTER_STDIN]->put(\@chunks))
  ) {
    $poe_kernel->select_resume_write($self->[HANDLE_STDIN]);
  }

  # No watermark.
  return 0;
}

#------------------------------------------------------------------------------
# Pause and resume various input events.

sub pause_stdout {
  my $self = shift;
  return unless defined $self->[HANDLE_STDOUT];
  $poe_kernel->select_pause_read($self->[HANDLE_STDOUT]);
}

sub pause_stderr {
  my $self = shift;
  return unless defined $self->[HANDLE_STDERR];
  $poe_kernel->select_pause_read($self->[HANDLE_STDERR]);
}

sub resume_stdout {
  my $self = shift;
  return unless defined $self->[HANDLE_STDOUT];
  $poe_kernel->select_resume_read($self->[HANDLE_STDOUT]);
}

sub resume_stderr {
  my $self = shift;
  return unless defined $self->[HANDLE_STDERR];
  $poe_kernel->select_resume_read($self->[HANDLE_STDERR]);
}

# Shutdown the pipe that leads to the child's STDIN.
sub shutdown_stdin {
  my $self = shift;
  return unless defined $self->[HANDLE_STDIN];

  $poe_kernel->select_write($self->[HANDLE_STDIN], undef);

  eval { local $^W = 0; shutdown($self->[HANDLE_STDIN], 1) };
  if ($@ or $self->[HANDLE_STDIN] != $self->[HANDLE_STDOUT]) {
    close $self->[HANDLE_STDIN];
  }

  $self->[HANDLE_STDIN] = undef;
}

#------------------------------------------------------------------------------
# Redefine filters, one at a time or at once.  This is based on PG's
# code in Wheel::ReadWrite.

sub _transfer_stdout_buffer {
  my ($self, $buf) = @_;

  my $old_output_filter = $self->[FILTER_STDOUT];

  # Assign old buffer contents to the new filter, and send out any
  # pending packets.

  # Use "get_one" if the new filter implements it.
  if (defined $buf) {
    if (
      $old_output_filter->can("get_one") and
      $old_output_filter->can("get_one_start")
    ) {
      $old_output_filter->get_one_start($buf);

      # Don't bother to continue if the filter has switched out from
      # under our feet again.  The new switcher will finish the job.

      while ($self->[FILTER_STDOUT] == $old_output_filter) {
        my $next_rec = $old_output_filter->get_one();
        last unless @$next_rec;
        foreach my $cooked_input (@$next_rec) {
          $poe_kernel->call(
            $poe_kernel->get_active_session(), $self->[EVENT_STDOUT],
            $cooked_input, $self->[UNIQUE_ID]
          );
        }
      }
    }

    # Otherwise use the old get() behavior.
    else {
      foreach my $cooked_input (@{$self->[FILTER_STDOUT]->get($buf)}) {
        $poe_kernel->call(
          $poe_kernel->get_active_session(), $self->[EVENT_STDOUT],
          $cooked_input, $self->[UNIQUE_ID]
        );
      }
    }
  }
}

sub _transfer_stderr_buffer {
  my ($self, $buf) = @_;

  my $old_output_filter = $self->[FILTER_STDERR];

  # Assign old buffer contents to the new filter, and send out any
  # pending packets.

  # Use "get_one" if the new filter implements it.
  if (defined $buf) {
    if (
      $old_output_filter->can("get_one") and
      $old_output_filter->can("get_one_start")
    ) {
      $old_output_filter->get_one_start($buf);

      # Don't bother to continue if the filter has switched out from
      # under our feet again.  The new switcher will finish the job.

      while ($self->[FILTER_STDERR] == $old_output_filter) {
        my $next_rec = $old_output_filter->get_one();
        last unless @$next_rec;
        foreach my $cooked_input (@$next_rec) {
          $poe_kernel->call(
            $poe_kernel->get_active_session(), $self->[EVENT_STDERR],
            $cooked_input, $self->[UNIQUE_ID]
          );
        }
      }
    }

    # Otherwise use the old get() behavior.
    else {
      foreach my $cooked_input (@{$self->[FILTER_STDERR]->get($buf)}) {
        $poe_kernel->call(
          $poe_kernel->get_active_session(), $self->[EVENT_STDERR],
          $cooked_input, $self->[UNIQUE_ID]
        );
      }
    }
  }
}

sub set_stdio_filter {
  my ($self, $new_filter) = @_;
  $self->set_stdout_filter($new_filter);
  $self->set_stdin_filter($new_filter);
}

sub set_stdin_filter {
  my ($self, $new_filter) = @_;
  $self->[FILTER_STDIN] = $new_filter;
}

sub set_stdout_filter {
  my ($self, $new_filter) = @_;

  my $buf = $self->[FILTER_STDOUT]->get_pending();
  $self->[FILTER_STDOUT] = $new_filter;

  $self->_transfer_stdout_buffer($buf);
}

sub set_stderr_filter {
  my ($self, $new_filter) = @_;

  my $buf = $self->[FILTER_STDERR]->get_pending();
  $self->[FILTER_STDERR] = $new_filter;

  $self->_transfer_stderr_buffer($buf);
}

sub get_stdin_filter {
  my $self = shift;
  return $self->[FILTER_STDIN];
}

sub get_stdout_filter {
  my $self = shift;
  return $self->[FILTER_STDOUT];
}

sub get_stderr_filter {
  my $self = shift;
  return $self->[FILTER_STDERR];
}

#------------------------------------------------------------------------------
# Data accessors.

sub get_driver_out_octets {
  $_[0]->[OCTETS_STDIN];
}

sub get_driver_out_messages {
  $_[0]->[DRIVER_STDIN]->get_out_messages_buffered();
}

sub ID {
  $_[0]->[UNIQUE_ID];
}

sub PID {
  $_[0]->[CHILD_PID];
}

sub kill {
  my ($self, $signal) = @_;
  $signal = 'TERM' unless defined $signal;
  if ( $self->[MSWIN32_GROUP_PID] ) {
    Win32::Process::KillProcess( $self->[MSWIN32_GROUP_PID], 293 ) ? 1 : 0;
  }
  else {
    eval { kill $signal, $self->[CHILD_PID] };
  }
}

### Internal helpers.

sub _redirect_child_stdio_in_hell {
  my ($class, $stdin_read, $stdout_write, $stderr_write) = @_;

  # Win32 needs the stdio handles closed before they're reopened
  # because the standard handles aren't dup()'d.

  close STDIN;
  close STDOUT;
  close STDERR;

  $class->_redirect_child_stdio_sanely(
    $stdin_read, $stdout_write, $stderr_write
  );

  # The Win32 pseudo fork sets up the std handles in the child
  # based on the true win32 handles.  The reopening of stdio
  # handles isn't enough.  We must also set the underlying
  # Win32 notion of these handles for completeness.
  #
  # Only necessary for the exec, as Perl CODE subroutine goes
  # through 0/1/2 which are correct.  But of course that coderef
  # might invoke exec, so better do it regardless.
  #
  # HACK: Using Win32::Console as nothing else exposes
  # SetStdHandle
  #
  # TODO - https://rt.cpan.org/Ticket/Display.html?id=50068 claims
  # that these _SetStdHandle() calls may leak memory.  Do we have
  # alternatives?

  Win32::Console::_SetStdHandle(
    $STD_INPUT_HANDLE,
    FdGetOsFHandle(fileno($stdin_read))
  );

  Win32::Console::_SetStdHandle(
    $STD_OUTPUT_HANDLE,
    FdGetOsFHandle(fileno($stdout_write))
  );

  Win32::Console::_SetStdHandle(
    $STD_ERROR_HANDLE,
    FdGetOsFHandle(fileno($stderr_write))
  );
}

sub _redirect_child_stdio_sanely {
  my ($class, $stdin_read, $stdout_write, $stderr_write) = @_;

  # Redirect STDIN from the read end of the stdin pipe.
  open( STDIN, "<&" . fileno($stdin_read) )
    or $class->_warn_and_exit_child(
      "can't redirect STDIN in child pid $$: $!", int( $! ) );

  # Redirect STDOUT to the write end of the stdout pipe.
  open( STDOUT, ">&" . fileno($stdout_write) )
    or $class->_warn_and_exit_child(
      "can't redirect stdout in child pid $$: $!", int( $! ) );

  # Redirect STDERR to the write end of the stderr pipe.
  open( STDERR, ">&" . fileno($stderr_write) )
    or $class->_warn_and_exit_child(
      "can't redirect stderr in child pid $$: $!", int( $! ) );
}

sub _exit_child_any_way_we_can {
  my $class = shift;
  my $exitval = shift || 0;

  # First make sure stdio are flushed.
  close STDIN  if defined fileno(STDIN); # Voodoo?
  close STDOUT if defined fileno(STDOUT);
  close STDERR if defined fileno(STDERR);

  # On Windows, subprocesses run in separate threads.  All the "fancy"
  # methods act on entire processes, so they also exit the parent.

  unless (POE::Kernel::RUNNING_IN_HELL) {
    # Try to avoid triggering END blocks and object destructors.
    eval { POSIX::_exit( $exitval ); };

    # TODO those methods will not exit with $exitval... what to do?
    eval { CORE::kill KILL => $$; };
    eval { exec("$^X -e 0"); };
  } else {
    eval { CORE::kill( KILL => $$ ); };

    # TODO Interestingly enough, the KILL is not enough to terminate this process...
    # However, it *is* enough to stop execution of END blocks/etc
    # So we will end up falling through to the exit( $exitval ) below
  }

  # Do what we must.
  exit( $exitval );
}

# RUNNING_IN_HELL use Win32::Process to create a pucker new shiny
# process. It'll inherit our processes handles which is neat.

sub _exec_in_hell {
  my (
    $class, $close_on_call, $sem_pipe_write,
    $program, $prog_args
  ) = @_;

  # Close any close-on-exec file descriptors.
  # Except STDIN, STDOUT, and STDERR, of course.

  if ($close_on_call) {
    for (0..MAX_OPEN_FDS-1) {
      next if fileno(STDIN) == $_;
      next if fileno(STDOUT) == $_;
      next if fileno(STDERR) == $_;
      POSIX::close($_);
    }
  }

  my ($appname, $cmdline);

  if (ref $program eq 'ARRAY') {
    $appname = $program->[0];
    $cmdline = join(
      ' ',
      map { /\s/ && ! /"/ ? qq{"$_"} : $_ }
      (@$program, @$prog_args)
    );
  }
  else {
    $appname = undef;
    $cmdline = join(
      ' ', $program,
      map { /\s/ && ! /"/ ? qq{"$_"} : $_ }
      @$prog_args
    );
  }

  my $w32job;

  unless ( $w32job = Win32::Job->new() ) {
    print $sem_pipe_write "go\n\n"; # TODO why the double newline?
    close $sem_pipe_write;
    $class->_warn_and_exit_child(
      Win32::FormatMessage( Win32::GetLastError() ), Win32::GetLastError() );
  }

  my $w32pid;

  unless ( $w32pid = $w32job->spawn( $appname, $cmdline ) ) {
    print $sem_pipe_write "go\n";
    close $sem_pipe_write;
    $class->_warn_and_exit_child(
      Win32::FormatMessage( Win32::GetLastError() ), Win32::GetLastError() );
  }

  print $sem_pipe_write "$w32pid\n";
  close $sem_pipe_write;

  # TODO why 60? Why not MAX_INT so we don't do unnecessary work?
  my $ok = $w32job->watch( sub { 0 }, 60 );
  my $hashref = $w32job->status();

  # In case flushing them wasn't good enough.
  close STDOUT if defined fileno(STDOUT);
  close STDERR if defined fileno(STDERR);

  $class->_exit_child_any_way_we_can( $hashref->{$w32pid}->{exitcode} );
}

# Simple helper to ease the pain of warn+exit
sub _warn_and_exit_child {
  my( $class, $warning, $exitval ) = @_;

  warn "$warning\n";

  $class->_exit_child_any_way_we_can( $exitval );
}

1;

__END__

=head1 NAME

POE::Wheel::Run - portably run blocking code and programs in subprocesses

=head1 SYNOPSIS

  #!/usr/bin/perl

  use warnings;
  use strict;

  use POE qw( Wheel::Run );

  POE::Session->create(
    inline_states => {
      _start           => \&on_start,
      got_child_stdout => \&on_child_stdout,
      got_child_stderr => \&on_child_stderr,
      got_child_close  => \&on_child_close,
      got_child_signal => \&on_child_signal,
    }
  );

  POE::Kernel->run();
  exit 0;

  sub on_start {
    my $child = POE::Wheel::Run->new(
      Program => [ "/bin/ls", "-1", "/" ],
      StdoutEvent  => "got_child_stdout",
      StderrEvent  => "got_child_stderr",
      CloseEvent   => "got_child_close",
    );

    $_[KERNEL]->sig_child($child->PID, "got_child_signal");

    # Wheel events include the wheel's ID.
    $_[HEAP]{children_by_wid}{$child->ID} = $child;

    # Signal events include the process ID.
    $_[HEAP]{children_by_pid}{$child->PID} = $child;

    print(
      "Child pid ", $child->PID,
      " started as wheel ", $child->ID, ".\n"
    );
  }

  # Wheel event, including the wheel's ID.
  sub on_child_stdout {
    my ($stdout_line, $wheel_id) = @_[ARG0, ARG1];
    my $child = $_[HEAP]{children_by_wid}{$wheel_id};
    print "pid ", $child->PID, " STDOUT: $stdout_line\n";
  }

  # Wheel event, including the wheel's ID.
  sub on_child_stderr {
    my ($stderr_line, $wheel_id) = @_[ARG0, ARG1];
    my $child = $_[HEAP]{children_by_wid}{$wheel_id};
    print "pid ", $child->PID, " STDERR: $stderr_line\n";
  }

  # Wheel event, including the wheel's ID.
  sub on_child_close {
    my $wheel_id = $_[ARG0];
    my $child = delete $_[HEAP]{children_by_wid}{$wheel_id};

    # May have been reaped by on_child_signal().
    unless (defined $child) {
      print "wid $wheel_id closed all pipes.\n";
      return;
    }

    print "pid ", $child->PID, " closed all pipes.\n";
    delete $_[HEAP]{children_by_pid}{$child->PID};
  }

  sub on_child_signal {
    print "pid $_[ARG1] exited with status $_[ARG2].\n";
    my $child = delete $_[HEAP]{children_by_pid}{$_[ARG1]};

    # May have been reaped by on_child_close().
    return unless defined $child;

    delete $_[HEAP]{children_by_wid}{$child->ID};
  }

=head1 DESCRIPTION

POE::Wheel::Run executes a program or block of code in a subprocess,
created the usual way: using fork().  The parent process may exchange
information with the child over the child's STDIN, STDOUT and STDERR
filehandles.

In the parent process, the POE::Wheel::Run object represents the child
process.  It has methods such as PID() and kill() to query and manage
the child process.

POE::Wheel::Run's put() method sends data to the child's STDIN.  Child
output on STDOUT and STDERR may be dispatched as events within the
parent, if requested.

POE::Wheel::Run can also notify the parent when the child has closed
its output filehandles.  Some programs remain active, but they close
their output filehandles to indicate they are done writing.

A more reliable way to detect child exit is to use POE::Kernel's
sig_child() method to wait for the wheel's process to be reaped.  It
is in fact vital to use sig_child() in all circumstances since without
it, POE will not try to reap child processes.

Failing to use sig_child() has in the past led to wedged machines.
Long-running programs have leaked processes, eventually consuming all
available slots in the process table and requiring reboots.

Because process leaks are so severe, POE::Kernel will check for this
condition on exit and display a notice if it finds that processes are
leaking.  Developers should heed these warnings.

POE::Wheel::Run communicates with the child process in a line-based
fashion by default.  Programs may override this by specifying some
other POE::Filter object in L</StdinFilter>, L</StdoutFilter>,
L</StdioFilter> and/or L</StderrFilter>.

=head1 PUBLIC METHODS

=head2 Constructor

POE::Wheel subclasses tend to perform a lot of setup so that they run
lighter and faster.  POE::Wheel::Run's constructor is no exception.

=head3 new

new() creates and returns a new POE::Wheel::Run object.  If it's
successful, the object will represent a child process with certain
specified qualities.  It also provides an OO- and event-based
interface for asynchronously interacting with the process.

=head4 Conduit

Conduit specifies the inter-process communications mechanism that will
be used to pass data between the parent and child process.  Conduit
may be one of "pipe", "socketpair", "inet", "pty", or "pty-pipe".
POE::Wheel::Run will use the most appropriate Conduit for the run-time
(not the compile-time) operating system, but this varies from one OS
to the next.

Internally, POE::Wheel::Run passes the Conduit type to
L<POE::Pipe::OneWay> and L<POE::Pipe::TwoWay>.  These helper classes
were created to make IPC portable and reusable.  They do not require
the rest of POE.

Three Conduit types use pipes or pipelike inter-process communication:
"pipe", "socketpair" and "inet".  They determine whether the internal
IPC uses pipe(), socketpair() or Internet sockets.  These Conduit
values are passed through to L<POE::Pipe::OneWay> or
L<POE::Pipe::TwoWay> internally.

The "pty" conduit type runs the child process under a pseudo-tty,
which is created by L<IO::Pty>.  Pseudo-ttys (ptys) convince child
processes that they are interacting with terminals rather than pipes.
This may be used to trick programs like ssh into believing it's secure
to prompt for a password, although passphraseless identities might be
better for that.

The "pty" conduit cannot separate STDERR from STDOUT, but the
"pty-pipe" mode can.

The "pty-pipe" conduit uses a pty for STDIN and STDOUT and a one-way
pipe for STDERR.  The additional pipe keeps STDERR output separate
from STDOUT.

The L<IO::Pty> module is only loaded if "pty" or "pty-pipe" is used.
It's not a dependency until it's actually needed.

TODO - Example.

=head4 Winsize

WARNING! This has been deprecated. WARNING!

The reason for the deprecation is that the original code was crufty
and unmaintained. It caused more problems than it helped. In the
mists of time, the old code was silently removed. Actually, it was
replaced with IO::Pty::clone_winsize_from(\*FH) which was more saner.
Alas, the docs weren't updated and users were led to believe that
this would do something. Now, POE::Wheel::Run will issue a warning
if it sees this param. If you want the old behavior back, please help
us fix it! Patches welcome :)

WARNING! This has been deprecated. WARNING!

Winsize sets the child process' terminal size.  Its value should be an
arrayref with two or four elements.  The first two elements must be
the number of lines and columns for the child's terminal window,
respectively.  The optional pair of elements describe the terminal's X
and Y dimensions in pixels:

  $_[HEAP]{child} = POE::Wheel::Run->new(
    # ... among other things ...
    Winsize => [ 25, 80, 1024, 768 ],
  );

Winsize is only valid for conduits that use pseudo-ttys: "pty" and
"pty-pipe".  Other conduits don't simulate terminals, so they don't
have window sizes.

Winsize defaults to the parent process' window size, assuming the
parent process has a terminal to query.

=head4 CloseOnCall

CloseOnCall, when true, turns on close-on-exec emulation for
subprocesses that don't actually call exec().  These would be
instances when the child is running a block of code rather than
executing an external program.  For example:

  $_[HEAP]{child} = POE::Wheel::Run->new(
    # ... among other things ...
    CloseOnCall => 1,
    Program => \&some_function,
  );

CloseOnCall is off (0) by default.

CloseOnCall works by closing all file descriptors greater than $^F in
the child process before calling the application's code.  For more
details, please the discussion of $^F in L<perlvar>.

=head4 StdioDriver

StdioDriver specifies a single L<POE::Driver> object to be used for
both STDIN and STDOUT.  It's equivalent to setting L</StdinDriver> and
L</StdoutDriver> to the same L<POE::Driver> object.

POE::Wheel::Run will create and use a L<POE::Driver::SysRW> driver of
one isn't specified.  This is by far the most common use case, so it's
the default.

=head4 StdinDriver

C<StdinDriver> sets the L<POE::Driver> used to write to the child
process' STDIN IPC conduit.  It is almost never needed.  Omitting it
will allow POE::Wheel::Run to use an internally created
L<POE::Driver::SysRW> object.

=head4 StdoutDriver

C<StdoutDriver> sets the L<POE::Driver> object that will be used to
read from the child process' STDOUT conduit.  It's almost never
needed.  If omitted, POE::Wheel::Run will internally create and use
a L<POE::Driver::SysRW> object.

=head4 StderrDriver

C<StderrDriver> sets the driver that will be used to read from the
child process' STDERR conduit.  As with L</StdoutDriver>, it's almost
always preferable to let POE::Wheel::Run instantiate its own driver.

=head4 CloseEvent

CloseEvent contains the name of an event that the wheel will emit when
the child process closes its last open output handle.  This is a
consistent notification that the child is done sending output.  Please
note that it does not signal when the child process has exited.
Programs should use sig_child() to detect that.

While it is impossible for ErrorEvent or StdoutEvent to happen after
CloseEvent, there is no such guarantee for CHLD, which may happen before
or after CloseEvent.

In addition to the usual POE parameters, each CloseEvent comes with
one of its own:

C<ARG0> contains the wheel's unique ID.  This can be used to keep
several child processes separate when they're managed by the same
session.

A sample close event handler:

  sub close_state {
    my ($heap, $wheel_id) = @_[HEAP, ARG0];

    my $child = delete $heap->{child}->{$wheel_id};
    print "Child ", $child->PID, " has finished.\n";
  }

=head4 ErrorEvent

ErrorEvent contains the name of an event to emit if something fails.
It is optional; if omitted, the wheel will not notify its session if
any errors occur.  However, POE::Wheel::Run->new() will still throw an
exception if it fails.

C<ARG0> contains the name of the operation that failed.  It may be
'read', 'write', 'fork', 'exec' or the name of some other function or
task.  The actual values aren't yet defined.  They will probably not
correspond so neatly to Perl builtin function names.

C<ARG1> and C<ARG2> hold numeric and string values for C<$!>,
respectively.  C<"$!"> will eq C<""> for read error 0 (child process
closed the file handle).

C<ARG3> contains the wheel's unique ID.

C<ARG4> contains the name of the child filehandle that has the error.
It may be "STDIN", "STDOUT", or "STDERR".  The sense of C<ARG0> will
be the opposite of what you might normally expect for these handles.
For example, POE::Wheel::Run will report a "read" error on "STDOUT"
because it tried to read data from the child's STDOUT handle.

A sample error event handler:

  sub error_state {
    my ($operation, $errnum, $errstr, $wheel_id) = @_[ARG0..ARG3];
    $errstr = "remote end closed" if $operation eq "read" and !$errnum;
    warn "Wheel $wheel_id generated $operation error $errnum: $errstr\n";
  }

Note that unless you deactivate the signal pipe, you might also see C<EIO>
(5) error during read operations.

=head4 StdinEvent

StdinEvent contains the name of an event that Wheel::Run emits
whenever everything queued by its put() method has been flushed to the
child's STDIN handle.  It is the equivalent to POE::Wheel::ReadWrite's
FlushedEvent.

StdinEvent comes with only one additional parameter: C<ARG0> contains
the unique ID for the wheel that sent the event.

=head4 StdoutEvent

StdoutEvent contains the name of an event  that Wheel::Run emits
whenever the child process writes something to its STDOUT filehandle.
In other words, whatever the child prints to STDOUT, the parent
receives a StdoutEvent---provided that the child prints something
compatible with the parent's StdoutFilter.

StdoutEvent comes with two parameters.  C<ARG0> contains the
information that the child wrote to STDOUT.  C<ARG1> holds the unique
ID of the wheel that read the output.

  sub stdout_state {
    my ($heap, $input, $wheel_id) = @_[HEAP, ARG0, ARG1];
    print "Child process in wheel $wheel_id wrote to STDOUT: $input\n";
  }

=head4 StderrEvent

StderrEvent behaves exactly as StdoutEvent, except for data the child
process writes to its STDERR filehandle.

StderrEvent comes with two parameters.  C<ARG0> contains the
information that the child wrote to STDERR.  C<ARG1> holds the unique
ID of the wheel that read the output.

  sub stderr_state {
    my ($heap, $input, $wheel_id) = @_[HEAP, ARG0, ARG1];
    print "Child process in wheel $wheel_id wrote to STDERR: $input\n";
  }

=head4 StdioFilter

StdioFilter, if used, must contain an instance of a POE::Filter
subclass.  This filter describes how the parent will format put() data
for the child's STDIN, and how the parent will parse the child's
STDOUT.

If STDERR will also be parsed, then a separate StderrFilter will also
be needed.

StdioFilter defaults to a POE::Filter::Line instance, but only if both
StdinFilter and StdoutFilter are not specified.  If either StdinFilter
or StdoutFilter is used, then StdioFilter is illegal.

=head4 StdinFilter

StdinFilter may be used to specify a particular STDIN serializer that
is different from the STDOUT parser.  If specified, it conflicts with
StdioFilter.  StdinFilter's value, if specified, must be an instance
of a POE::Filter subclass.

Without a StdinEvent, StdinFilter is illegal.

=head4 StdoutFilter

StdoutFilter may be used to specify a particular STDOUT parser that is
different from the STDIN serializer.  If specified, it conflicts with
StdioFilter.  StdoutFilter's value, if specified, must be an instance
of a POE::Filter subclass.

Without a StdoutEvent, StdoutFilter is illegal.

=head4 StderrFilter

StderrFilter may be used to specify a filter for a child process'
STDERR output.  If omitted, POE::Wheel::Run will create and use its
own POE::Filter::Line instance, but only if a StderrEvent is
specified.

Without a StderrEvent, StderrFilter is illegal.

=head4 Group

Group contains a numeric group ID that the child process should run
within.  By default, the child process will run in the same group as
the parent.

Group is not fully portable.  It may not work on systems that have no
concept of user groups.  Also, the parent process may need to run with
elevated privileges for the child to be able to change groups.

=head4 User

User contains a numeric user ID that should own the child process.  By
default, the child process will run as the same user as the parent.

User is not fully portable.  It may not work on systems that have no
concept of users.  Also, the parent process may need to run with
elevated privileges for the child to be able to change users.

=head4 NoSetSid

When true, NoSetSid disables setsid() in the child process.  By
default, the child process calls setsid() is called so that it may
execute in a separate UNIX session.

=head4 NoSetPgrp

When true, NoSetPgrp disables setprgp() in the child process. By
default, the child process calls setpgrp() to change its process
group, if the OS supports that.

setsid() is used instead of setpgrp() if Conduit is pty or pty-pipe.
See L</NoSetSid>.

=head4 Priority

Priority adjusts the child process' niceness or priority level,
depending on which (if any) the underlying OS supports.  Priority
contains a numeric offset which will be added to the parent's priority
to determine the child's.

The priority offset may be negative, which in UNIX represents a higher
priority.  However UNIX requires elevated privileges to increase a
process' priority.

=head4 Program

Program specifies the program to exec() or the block of code to run in
the child process.  Program's type is significant.

If Program holds a scalar, its value will be executed as
exec($program).  Shell metacharacters are significant, per
exec(SCALAR) semantics.

If Program holds an array reference, it will executed as
exec(@$program).  As per exec(ARRAY), shell metacharacters will not be
significant.

If Program holds a code reference, that code will be called in the
child process.  This mode allows POE::Wheel::Run to execute
long-running internal code asynchronously, while the usual modes
execute external programs.  The child process will exit after that
code is finished, in such a way as to avoid DESTROY and END block
execution.  See L</Coderef Execution Side Effects> for more details.

L<perlfunc> has more information about exec() and the different ways
to call it.

Please avoid calling exit() explicitly when executing a subroutine.
The child process inherits all objects from the parent, including ones
that may perform side effects.  POE::Wheel::Run takes special care to
avoid object destructors and END blocks in the child process, but
calling exit() will trigger them.

=head4 ProgramArgs

If specified, ProgramArgs should refer to a list of parameters for the
program being run.

  my @parameters = qw(foo bar baz);  # will be passed to Program
  ProgramArgs => \@parameters;

=head2 event EVENT_TYPE => EVENT_NAME, ...

event() allows programs to change the events that Wheel::Run emits
when certain activities occurs.  EVENT_TYPE may be one of the event
parameters described in POE::Wheel::Run's constructor.

This example changes the events that $wheel emits for STDIN flushing
and STDOUT activity:

  $wheel->event(
    StdinEvent  => 'new-stdin-event',
    StdoutEvent => 'new-stdout-event',
  );

Undefined EVENT_NAMEs disable events.

=head2 put RECORDS

put() queues up a list of RECORDS that will be sent to the child
process' STDIN filehandle.  These records will first be serialized
according to the wheel's StdinFilter.  The serialized RECORDS will be
flushed asynchronously once the current event handler returns.

=head2 get_stdin_filter

get_stind_filter() returns the POE::Filter object currently being used
to serialize put() records for the child's STDIN filehandle.  The
return object may be used according to its own interface.

=head2 get_stdout_filter

get_stdout_filter() returns the POE::Filter object currently being
used to parse what the child process writes to STDOUT.

=head2 get_stderr_filter

get_stderr_filter() returns the POE::Filter object currently being
used to parse what the child process writes to STDERR.

=head2 set_stdio_filter FILTER_OBJECT

Set StdinFilter and StdoutFilter to the same new FILTER_OBJECT.
Unparsed STDOUT data will be parsed later by the new FILTER_OBJECT.
However, data already put() will remain serialized by the old filter.

=head2 set_stdin_filter FILTER_OBJECT

Set StdinFilter to a new FILTER_OBJECT.  Data already put() will
remain serialized by the old filter.

=head2 set_stdout_filter FILTER_OBJECT

Set StdoutFilter to a new FILTER_OBJECT.  Unparsed STDOUT data will be
parsed later by the new FILTER_OBJECT.

=head2 set_stderr_filter FILTER_OBJECT

Set StderrFilter to a new FILTER_OBJECT.  Unparsed STDERR data will be
parsed later by the new FILTER_OBJECT.

=head2 pause_stdout

Pause reading of STDOUT from the child.  The child process may block
if the STDOUT IPC conduit fills up.  Reading may be resumed with
resume_stdout().

=head2 pause_stderr

Pause reading of STDERR from the child.  The child process may block
if the STDERR IPC conduit fills up.  Reading may be resumed with
resume_stderr().

=head2 resume_stdout

Resume reading from the child's STDOUT filehandle.  This is only
meaningful if pause_stdout() has been called and remains in effect.

=head2 resume_stderr

Resume reading from the child's STDERR filehandle.  This is only
meaningful if pause_stderr() has been called and remains in effect.

=head2 shutdown_stdin

shutdown_stdin() closes the child process' STDIN and stops the wheel
from reporting StdinEvent.  It is extremely useful for running
utilities that expect to receive EOF on STDIN before they respond.

=head2 ID

ID() returns the wheel's unique ID.  Every event generated by a
POE::Wheel::Run object includes a wheel ID so that it can be matched
to the wheel that emitted it.  This lets a single session manage
several wheels without becoming confused about which one generated
what event.

ID() is not the same as PID().

=head2 PID

PID() returns the process ID for the child represented by the
POE::Wheel::Run object.  It's often used as a parameter to
sig_child().

PID() is not the same as ID().

=head2 kill SIGNAL

POE::Wheel::Run's kill() method sends a SIGNAL to the child process
the object represents.  kill() is often used to force a reluctant
program to terminate.  SIGNAL is one of the operating signal names
present in %SIG.

kill() returns the number of processes successfully signaled: 1 on
success, or 0 on failure, since the POE::Wheel::Run object only
affects at most a single process.

kill() sends SIGTERM if SIGNAL is undef or omitted.

=head2 get_driver_out_messages

get_driver_out_messages() returns the number of put() records
remaining in whole or in part in POE::Wheel::Run's POE::Driver output
queue.  It is often used to tell whether the wheel has more input for
the child process.

In most cases, StdinEvent may be used to trigger activity when all
data has been sent to the child process.

=head2 get_driver_out_octets

get_driver_out_octets() returns the number of serialized octets
remaining in POE::Wheel::Run's POE::Driver output queue.  It is often
used to tell whether the wheel has more input for the child process.

=head1 TIPS AND TRICKS

=head2 MSWin32 Support

In the past POE::Wheel::Run did not support MSWin32 and users had to
use custom work-arounds. Then Chris Williams ( BINGOS ) arrived and
saved the day with his L<POE::Wheel::Run::Win32> module. After some
testing, it was decided to merge the win32 code into POE::Wheel::Run.
Everyone was happy!

However, after some investigation Apocalypse ( APOCAL ) found out that
in some situations it still didn't behave properly. The root cause was
that the win32 code path in POE::Wheel::Run didn't exit cleanly. This
means DESTROY and END blocks got executed! After talking with more
people, the solution was not pretty.

The problem is that there is no equivalent of POSIX::_exit() for MSWin32.
Hopefully, in a future version of Perl this can be fixed! In the meantime,
POE::Wheel::Run will use CORE::kill() to terminate the child. However,
this comes with a caveat: you will leak around 1KB per exec. The code
has been improved so the chance of this happening has been reduced.

As of now the most reliable way to trigger this is to exec an invalid
binary. The definition of "invalid binary" depends on different things,
but what it means is that Win32::Job->spawn() failed to run. This will
force POE::Wheel::Run to use the workaround to exit the child. If this
happens, a very big warning will be printed to the STDERR of the child
and the parent process will receive it.

If you are a Perl MSWin32 hacker, PLEASE help us with this situation! Go
read rt.cpan.org bug #56417 and talk with us/p5p to see where you can
contribute.

Thanks again for your patience as we continue to improve POE::Wheel::Run
on MSWin32!

=head2 Execution Environment

It's common to scrub a child process' environment, so that only
required, secure values exist.  This amounts to clearing the contents
of %ENV and repopulating it.

Environment scrubbing is easy when the child process is running a
subroutine, but it's not so easy---or at least not as intuitive---when
executing external programs.

The way we do it is to run a small subroutine in the child process
that performs the exec() call for us.

  Program => \&exec_with_scrubbed_env,

  sub exec_with_scrubbed_env {
    delete @ENV{keys @ENV};
    $ENV{PATH} = "/bin";
    exec(@program_and_args);
  }

That deletes everything from the environment and sets a simple, secure
PATH before executing a program.

=head2 Coderef Execution Side Effects

The child process is created by fork(), which duplicates the parent
process including a copy of POE::Kernel, all running Session
instances, events in the queue, watchers, open filehandles, and so on.

When executing an external program, the UNIX exec() call immediately
replaces the copy of the parent with a completely new program.

When executing internal coderefs, however, we must preserve the code
and any memory it might reference.  This leads to some potential side
effects.

=head3 DESTROY and END Blocks Run Twice

Objects that were created in the parent process are copied into the
child.  When the child exits normally, any DESTROY and END blocks are
executed there.  Later, when the parent exits, they may run again.

POE::Wheel::Run takes steps to avoid running DESTROY and END blocks in
the child process.  It uses POSIX::_exit() to bypass them.  If that
fails, it may even kill() itself.

If an application needs to exit explicitly, for example to return an
error code to the parent process, then please use POSIX::_exit()
rather than Perl's core exit().

=head3 POE::Kernel's run() method was never called

This warning is displayed from POE::Kernel's DESTROY method.  It's a
side effect of calling exit() in a child process that was started
before C<< POE::Kernel->run() >> could be called.  The child process
receives a copy of POE::Kernel where run() wasn't called, even if it
was called later in the parent process.

The most direct solution is to call POSIX::_exit() rather than exit().
This will bypass POE::Kernel's DESTROY, and the message it emits.

=head3 Running POE::Kernel in the Child

Calling C<< POE::Kernel->run() >> in the child process effectively
resumes the copy of the parent process.  This is rarely (if ever)
desired.

More commonly, an application wants to run an entirely new POE::Kernel
instance in the child process.  This is supported by first stop()ping
the copied instance, starting one or more new sessions, and calling
run() again.  For example:

  Program => sub {
    # Wipe the existing POE::Kernel clean.
    $poe_kernel->stop();

    # Start a new session, or more.
    POE::Session->create(
      ...
    );

    # Run the new sessions.
    POE::Kernel->run();
  }

Strange things are bound to happen if the program does not call
L<POE::Kernel/stop> before L<POE::Kernel/run>.  However this is
vaguely supported in case it's the right thing to do at the time.

=head1 SEE ALSO

L<POE::Wheel> describes wheels in general.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 CAVEATS & TODOS

POE::Wheel::Run's constructor should emit proper events when it fails.
Instead, it just dies, carps or croaks.  This isn't necessarily bad; a
program can trap the death in new() and move on.

Priority is a delta, not an absolute niceness value.

It might be nice to specify User by name rather than just UID.

It might be nice to specify Group by name rather than just GID.

POE::Pipe::OneWay and Two::Way don't require the rest of POE.  They
should be spun off into a separate distribution for everyone to enjoy.

If StdinFilter and StdoutFilter seem backwards, remember that it's the
filters for the child process.  StdinFilter is the one that dictates
what the child receives on STDIN.  StdoutFilter tells the parent how
to parse the child's STDOUT.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
