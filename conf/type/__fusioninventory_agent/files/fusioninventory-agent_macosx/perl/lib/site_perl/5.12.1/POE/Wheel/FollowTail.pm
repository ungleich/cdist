package POE::Wheel::FollowTail;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw( croak carp );
use Symbol qw( gensym );
use POSIX qw(SEEK_SET SEEK_CUR SEEK_END S_ISCHR S_ISBLK);
use POE qw(Wheel Driver::SysRW Filter::Line);
use base qw(POE::Wheel);
use IO::Handle ();
use Errno qw(ENOENT);

sub CRIMSON_SCOPE_HACK ($) { 0 }

sub SELF_HANDLE      () {  0 }
sub SELF_FILENAME    () {  1 }
sub SELF_DRIVER      () {  2 }
sub SELF_FILTER      () {  3 }
sub SELF_INTERVAL    () {  4 }
sub SELF_EVENT_INPUT () {  5 }
sub SELF_EVENT_ERROR () {  6 }
sub SELF_EVENT_RESET () {  7 }
sub SELF_UNIQUE_ID   () {  8 }
sub SELF_STATE_READ  () {  9 }
sub SELF_LAST_STAT   () { 10 }
sub SELF_FOLLOW_MODE () { 11 }

sub MODE_TIMER  () { 0x01 } # Follow on a timer loop.
sub MODE_SELECT () { 0x02 } # Follow via select().

# Turn on tracing.  A lot of debugging occurred just after 0.11.
sub TRACE_POLL         () { 0 }
sub TRACE_RESET        () { 0 }
sub TRACE_STAT         () { 0 }
sub TRACE_STAT_VERBOSE () { 0 }

# Tk doesn't provide a SEEK method, as of 800.022
BEGIN {
  if (exists $INC{'Tk.pm'}) {
    eval <<'    EOE';
      sub Tk::Event::IO::SEEK {
        my $o = shift;
        $o->wait(Tk::Event::IO::READABLE);
        my $h = $o->handle;
        sysseek($h, shift, shift);
      }
    EOE
  }
}

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  my %params = @_;

  croak "wheels no longer require a kernel reference as their first parameter"
    if @_ and (ref($_[0]) eq 'POE::Kernel');

  croak "$type requires a working Kernel" unless (defined $poe_kernel);

  croak "FollowTail requires a Handle or Filename parameter, but not both"
    unless $params{Handle} xor defined $params{Filename};

  my $driver = delete $params{Driver};
  $driver = POE::Driver::SysRW->new() unless defined $driver;

  my $filter = delete $params{Filter};
  $filter = POE::Filter::Line->new() unless defined $filter;

  croak "InputEvent required" unless defined $params{InputEvent};

  my $handle   = $params{Handle};
  my $filename = $params{Filename};

  my $poll_interval = (
    defined($params{PollInterval})
    ?  $params{PollInterval}
    : 1
  );

  my $seek;
  if (exists $params{SeekBack}) {
    $seek = $params{SeekBack} * -1;
    if (exists $params{Seek}) {
      croak "can't have Seek and SeekBack at the same time";
    }
  }
  elsif (exists $params{Seek}) {
    $seek = $params{Seek};
  }
  else {
    $seek = -4096;
  }

  my $self = bless [
    $handle,                          # SELF_HANDLE
    $filename,                        # SELF_FILENAME
    $driver,                          # SELF_DRIVER
    $filter,                          # SELF_FILTER
    $poll_interval,                   # SELF_INTERVAL
    delete $params{InputEvent},       # SELF_EVENT_INPUT
    delete $params{ErrorEvent},       # SELF_EVENT_ERROR
    delete $params{ResetEvent},       # SELF_EVENT_RESET
    &POE::Wheel::allocate_wheel_id(), # SELF_UNIQUE_ID
    undef,                            # SELF_STATE_READ
    [ (-1) x 8 ],                     # SELF_LAST_STAT
    undef,                            # SELF_FOLLOW_MODE
  ], $type;

  if (defined $filename) {
    $handle = $self->[SELF_HANDLE] = _open_file($filename);
    $self->[SELF_LAST_STAT] = [ (stat $filename)[0..7] ] if $handle;
  }
  elsif (defined $handle) {
    $self->[SELF_LAST_STAT] = [ (stat $handle)[0..7] ];
  }

  # Honor SeekBack and discard partial input if we have a plain file
  # that is successfully open at this point.
  #
  # SeekBack attempts to position the file pointer somewhere before
  # the end of the file.  If it's specified, we assume the user knows
  # where a record begins.  Otherwise we just seek back and discard
  # everything to EOF so we can frame the input record.

  if (defined $handle) {

    # Handle is a plain file.  Honor SeekBack and PollInterval.

    if (-f $handle) {
      my $end = sysseek($self->[SELF_HANDLE], 0, SEEK_END);

      # Seeking back from EOF.
      if ($seek < 0) {
        if (defined($end) and ($end < -$seek)) {
          sysseek($self->[SELF_HANDLE], 0, SEEK_SET);
        }
        else {
          sysseek($self->[SELF_HANDLE], $seek, SEEK_END);
        }
      }

      # Seeking forward from the beginning of the file.
      elsif ($seek > 0) {
        if ($seek > $end) {
          sysseek($self->[SELF_HANDLE], 0, SEEK_END);
        }
        else {
          sysseek($self->[SELF_HANDLE], $seek, SEEK_SET);
        }
      }

      # If they set Seek to 0, we start at the beginning of the file.
      # If it was SeekBack, we start at the end.
      elsif (exists $params{Seek}) {
        sysseek($self->[SELF_HANDLE], 0, SEEK_SET);
      }
      elsif (exists $params{SeekBack}) {
        sysseek($self->[SELF_HANDLE], 0, SEEK_END);
      }
      else {
        die;  # Should never happen.
      }

      # Discard partial input chunks unless a SeekBack was specified.
      unless (defined $params{SeekBack} or defined $params{Seek}) {
        while (defined(my $raw_input = $driver->get($self->[SELF_HANDLE]))) {
          # Skip out if there's no more input.
          last unless @$raw_input;
          $filter->get($raw_input);
        }
      }

      # Start the timer loop.
      $self->[SELF_FOLLOW_MODE] = MODE_TIMER;
      $self->_define_timer_states();

      return $self;
    }

    # Strange things that ought not be tailed?  Directories...

    if (-d $self->[SELF_HANDLE]) {
      croak "FollowTail does not tail directories";
    }

    # Handle is not a plain file.  Can't honor SeekBack.

    carp "POE::Wheel::FollowTail can't SeekBack special files"
      if defined $params{SeekBack};

    # The handle isn't legal to multiplex on this platform.
    if (POE::Kernel::RUNNING_IN_HELL and not -S $handle) {
      $self->[SELF_FOLLOW_MODE] = MODE_TIMER;
      $self->_define_timer_states();
      return $self;
    }

    # Multiplexing should be more efficient where it's supported.

    carp "FollowTail does not need PollInterval for special files"
      if defined $params{PollInterval};

    $self->[SELF_FOLLOW_MODE] = MODE_SELECT;
    $self->_define_select_states();
    return $self;
  }

  # We don't have an open filehandle yet.  We can't tell whether
  # multiplexing is legal, and we can't seek back yet.  Don't honor
  # either.

  $self->[SELF_FOLLOW_MODE] = MODE_TIMER;
  $self->_define_timer_states();
  return $self;
}

### Define the select based polling loop.  This relies on stupid
### closure tricks to keep references to $self out of anonymous
### coderefs.  Otherwise a circular reference would occur, and the
### wheel would never self-destruct.

sub _define_select_states {
  my $self = shift;

  my $filter      = $self->[SELF_FILTER];
  my $driver      = $self->[SELF_DRIVER];
  my $handle      = \$self->[SELF_HANDLE];
  my $unique_id   = $self->[SELF_UNIQUE_ID];
  my $event_input = \$self->[SELF_EVENT_INPUT];
  my $event_error = \$self->[SELF_EVENT_ERROR];
  my $event_reset = \$self->[SELF_EVENT_RESET];

  TRACE_POLL and warn "<poll> defining select state";

  $poe_kernel->state(
    $self->[SELF_STATE_READ] = ref($self) . "($unique_id) -> select read",
    sub {

      # Protects against coredump on older perls.
      0 && CRIMSON_SCOPE_HACK('<');

      # The actual code starts here.
      my ($k, $ses) = @_[KERNEL, SESSION];

      # Reset position.
      eval { sysseek($$handle, 0, SEEK_CUR) };
      $! = 0;

      TRACE_POLL and warn "<poll> " . time . " read ok";

      # Read the next chunk, and return its data.  Go around again.
      if (defined(my $raw_input = $driver->get($$handle))) {
        if (@$raw_input) {
          TRACE_POLL and warn "<poll> " . time . " raw input";
          $filter->get_one_start($raw_input);
          foreach my $cooked_input (@{$filter->get_one()}) {
            TRACE_POLL and warn "<poll> " . time . " cooked input";
            $k->call($ses, $$event_input, $cooked_input, $unique_id);
          }
        }

        # Clear the filehandle's EOF status, if any.
        IO::Handle::clearerr($$handle);

        return;
      }

      # Error reading.  Report the error if it's not EOF, or if it's
      # EOF on a socket or TTY.  Shut down the select, too.
      else {
        if ($! or (-S $$handle) or (-t $$handle)) {
          TRACE_POLL and warn "<poll> " . time . " error: $!";
          $$event_error and
            $k->call($ses, $$event_error, 'read', ($!+0), $!, $unique_id);
        }

        $k->select_read($$handle => undef);
        eval { IO::Handle::clearerr($$handle) }; # could be a globref
      }
    }
  );

  $poe_kernel->select_read($$handle, $self->[SELF_STATE_READ]);
}

### Define the timer based polling loop.  This also relies on stupid
### closure tricks.

sub _define_timer_states {
  my $self = shift;

  # Tail by filename.
  if (defined $self->[SELF_FILENAME]) {
    TRACE_POLL and warn "<poll> defining timer state for filename tail";
    $self->_generate_filename_timer();
  }
  else {
    TRACE_POLL and warn "<poll> defining timer state for handle tail";
    $self->_generate_filehandle_timer();
  }

  # Fire up the loop.  The delay() aspect of the loop will prevent
  # duplicate events from being significant for long.
  $poe_kernel->delay($self->[SELF_STATE_READ], 0);
}

sub _generate_filehandle_timer {
  my $self = shift;

  my $filter        = $self->[SELF_FILTER];
  my $driver        = $self->[SELF_DRIVER];
  my $unique_id     = $self->[SELF_UNIQUE_ID];
  my $poll_interval = $self->[SELF_INTERVAL];
  my $last_stat     = $self->[SELF_LAST_STAT];

  my $handle        = \$self->[SELF_HANDLE];
  my $event_input   = \$self->[SELF_EVENT_INPUT];
  my $event_error   = \$self->[SELF_EVENT_ERROR];
  my $event_reset   = \$self->[SELF_EVENT_RESET];

  $self->[SELF_STATE_READ] = ref($self) . "($unique_id) -> handle timer read";
  my $state_read    = \$self->[SELF_STATE_READ];

  $poe_kernel->state(
    $$state_read,
    sub {

      # Protects against coredump on older perls.
      0 && CRIMSON_SCOPE_HACK('<');

      # The actual code starts here.
      my ($k, $ses) = @_[KERNEL, SESSION];

      # File isn't open?  We're done.
      unless (defined $$handle and fileno $$handle) {
        TRACE_POLL and warn "<poll> ", time, " $$handle closed";
        $$event_error and
          $k->call($ses, $$event_error, 'read', 0, "", $unique_id);
        return;
      }

      # Reset position.
      eval { sysseek($$handle, 0, SEEK_CUR) };
      $! = 0;

      # Read the next chunk, and return its data.  Go around again.
      if (defined(my $raw_input = $driver->get($$handle))) {
        TRACE_POLL and warn "<poll> " . time . " raw input";
        $filter->get_one_start($raw_input);
        foreach my $cooked_input (@{$filter->get_one()}) {
          TRACE_POLL and warn "<poll> " . time . " cooked input";
          $k->call($ses, $$event_input, $cooked_input, $unique_id);
        }

        # Clear the filehandle's EOF status, if any.
        IO::Handle::clearerr($$handle);

        # Must use a timer so that it can be cleared in DESTROY.
        $k->delay($$state_read, 0) if defined $$state_read;
        return;
      }

      # Some kind of important error?
      if ($!) {
        TRACE_POLL and warn "<poll> ", time, " $$handle error: $!";
        $$event_error and
          $k->call($ses, $$event_error, 'read', ($!+0), "$!", $unique_id);
        return;
      }

      # Merely EOF.  Check for file rotation.

      my @new_stat = (stat $$handle)[0..7];
      unless (@new_stat) {
        TRACE_POLL and warn "<poll> ", time, " $$handle stat error";
        $$event_error and
          $k->call($ses, $$event_error, 'stat', ($!+0), "$!", $unique_id);
        return;
      }

      TRACE_STAT_VERBOSE and do {
        my @test_new = @new_stat;
        my @test_old = @$last_stat;
        warn "<stat> from: @test_old\n<stat> to  : @test_new" if (
          "@test_new" ne "@test_old"
        );
      };

      # Ignore rdev changes for non-device files
      eval {
        if (!S_ISBLK($new_stat[2]) and !S_ISCHR($new_stat[2])) {
          $last_stat->[6] = $new_stat[6];
        }
      };

      # Something fundamental about the file changed.
      # Consider it a reset, and try to rewind to the top of the file.
      if (
        $new_stat[1] != $last_stat->[1] or # inode's number
        $new_stat[0] != $last_stat->[0] or # inode's device
        $new_stat[6] != $last_stat->[6] or # device type
        $new_stat[3] != $last_stat->[3] or # number of links
        $new_stat[7] <  $last_stat->[7]    # size reduced
      ) {
        TRACE_STAT and do {
          warn "<stat> inode $new_stat[1] != old $last_stat->[1]"
            if $new_stat[1] != $last_stat->[1];
          warn "<stat> inode device $new_stat[0] != old $last_stat->[0]"
            if $new_stat[0] != $last_stat->[0];
          warn "<stat> device type $new_stat[6] != old $last_stat->[6]"
            if $new_stat[6] != $last_stat->[6];
          warn "<stat> link count $new_stat[3] != old $last_stat->[3]"
            if $new_stat[3] != $last_stat->[3];
          warn "<stat> file size $new_stat[7] < old $last_stat->[7]"
            if $new_stat[7] < $last_stat->[7];
        };

        # File has reset.
        TRACE_RESET and warn "<reset> filehandle has reset";
        $$event_reset and $k->call($ses, $$event_reset, $unique_id);

        sysseek($$handle, 0, SEEK_SET);
      }

      # The file didn't roll.  Try again shortly.
      @$last_stat = @new_stat;
      IO::Handle::clearerr($$handle);
      $k->delay($$state_read, $poll_interval) if defined $$state_read;
      return;
    }
  );
}

sub _generate_filename_timer {
  my $self = shift;

  my $filter        = $self->[SELF_FILTER];
  my $driver        = $self->[SELF_DRIVER];
  my $unique_id     = $self->[SELF_UNIQUE_ID];
  my $poll_interval = $self->[SELF_INTERVAL];
  my $filename      = $self->[SELF_FILENAME];
  my $last_stat     = $self->[SELF_LAST_STAT];

  my $handle        = \$self->[SELF_HANDLE];
  my $event_input   = \$self->[SELF_EVENT_INPUT];
  my $event_error   = \$self->[SELF_EVENT_ERROR];
  my $event_reset   = \$self->[SELF_EVENT_RESET];

  $self->[SELF_STATE_READ] = ref($self) . "($unique_id) -> name timer read";
  my $state_read    = \$self->[SELF_STATE_READ];

  $poe_kernel->state(
    $$state_read,
    sub {

      # Protects against coredump on older perls.
      0 && CRIMSON_SCOPE_HACK('<');

      # The actual code starts here.
      my ($k, $ses) = @_[KERNEL, SESSION];

      # File isn't open?  Try to open it.
      unless ($$handle) {
        $$handle = _open_file($filename);

        # Couldn't open yet.
        unless ($$handle) {
          $k->delay($$state_read, $poll_interval) if defined $$state_read;
          return;
        }

        # File has reset.
        TRACE_RESET and warn "<reset> file name has reset";
        $$event_reset and $k->call($ses, $$event_reset, $unique_id);

        @$last_stat = (stat $$handle)[0..7];
      }
      else {
        # Reset position.
        eval { sysseek($$handle, 0, SEEK_CUR) };
        $! = 0;
      }

      # Read the next chunk, and return its data.  Go around again.
      if (defined(my $raw_input = $driver->get($$handle))) {
        TRACE_POLL and warn "<poll> " . time . " raw input";
        $filter->get_one_start($raw_input);
        my $cooked_array;
        while (@{$cooked_array = $filter->get_one()}) {
          foreach my $cooked_input (@$cooked_array) {
            TRACE_POLL and warn "<poll> " . time . " cooked input";
            $k->call($ses, $$event_input, $cooked_input, $unique_id);
          }
        }

        # Clear the filehandle's EOF status, if any.
        IO::Handle::clearerr($$handle);

        # Must use a timer so that it can be cleared in DESTROY.
        $k->delay($$state_read, 0) if defined $$state_read;
        return;
      }

      # Some kind of important error?
      if ($!) {
        TRACE_POLL and warn "<poll> ", time, " $$handle error: $!";
        $$event_error and
          $k->call($ses, $$event_error, 'read', ($!+0), "$!", $unique_id);
        return;
      }

      # Merely EOF.  Check for file rotation.
      my @new_stat = (stat $filename)[0..7];
      unless (@new_stat) {
        TRACE_POLL and warn "<poll> ", time, " $filename stat error: $!";
        if ($! != ENOENT) {
          $$event_error and
            $k->call($ses, $$event_error, 'stat', ($!+0), "$!", $unique_id);
          return;
        }
        @new_stat = (-1) x 8;
      }

      TRACE_STAT_VERBOSE and do {
        my @test_new = @new_stat;
        my @test_old = @$last_stat;
        warn "<stat> from: @test_old\n<stat> to  : @test_new" if (
          "@test_new" ne "@test_old"
        );
      };

      # Ignore rdev changes for non-device files
      eval {
        if (!S_ISBLK($new_stat[2]) and !S_ISCHR($new_stat[2])) {
          $last_stat->[6] = $new_stat[6];
        }
      };

      # Something fundamental about the file changed.
      # Consider it a reset, and close the file.
      if (
        $new_stat[1] != $last_stat->[1] or # inode's number
        $new_stat[0] != $last_stat->[0] or # inode's device
        $new_stat[6] != $last_stat->[6] or # device type
        $new_stat[3] != $last_stat->[3] or # number of links
        $new_stat[7] <  $last_stat->[7]    # size reduced
      ) {
        TRACE_STAT and do {
          warn "<stat> inode $new_stat[1] != old $last_stat->[1]"
            if $new_stat[1] != $last_stat->[1];
          warn "<stat> inode device $new_stat[0] != old $last_stat->[0]"
            if $new_stat[0] != $last_stat->[0];
          warn "<stat> device type $new_stat[6] != old $last_stat->[6]"
            if $new_stat[6] != $last_stat->[6];
          warn "<stat> link count $new_stat[3] != old $last_stat->[3]"
            if $new_stat[3] != $last_stat->[3];
          warn "<stat> file size $new_stat[7] < old $last_stat->[7]"
            if $new_stat[7] < $last_stat->[7];
        };

        $$handle = undef;
        @$last_stat = @new_stat;

        # Must use a timer so that it can be cleared in DESTROY.
        $k->delay($$state_read, 0) if defined $$state_read;
        return;
      }

      # The file didn't roll.  Try again shortly.
      @$last_stat = @new_stat;
      IO::Handle::clearerr($$handle);
      $k->delay($$state_read, $poll_interval) if defined $$state_read;
      return;
    }
  );
}

#------------------------------------------------------------------------------

sub event {
  my $self = shift;
  push(@_, undef) if (scalar(@_) & 1);

  while (@_) {
    my ($name, $event) = splice(@_, 0, 2);

    if ($name eq 'InputEvent') {
      if (defined $event) {
        $self->[SELF_EVENT_INPUT] = $event;
      }
      else {
        carp "InputEvent requires an event name.  ignoring undef";
      }
    }
    elsif ($name eq 'ErrorEvent') {
      $self->[SELF_EVENT_ERROR] = $event;
    }
    elsif ($name eq 'ResetEvent') {
      $self->[SELF_EVENT_RESET] = $event;
    }
    else {
      carp "ignoring unknown FollowTail parameter '$name'";
    }
  }
}

#------------------------------------------------------------------------------

sub DESTROY {
  my $self = shift;

  # Remove our tentacles from our owner.
  $poe_kernel->select_read($self->[SELF_HANDLE] => undef) if (
    defined $self->[SELF_HANDLE]
  );

  if ($self->[SELF_STATE_READ]) {
    $poe_kernel->delay($self->[SELF_STATE_READ]);
    $poe_kernel->state($self->[SELF_STATE_READ]);
    undef $self->[SELF_STATE_READ];
  }

  &POE::Wheel::free_wheel_id($self->[SELF_UNIQUE_ID]);
}

#------------------------------------------------------------------------------

sub ID {
  return $_[0]->[SELF_UNIQUE_ID];
}

sub tell {
  my $self = shift;
  return sysseek($self->[SELF_HANDLE], 0, SEEK_CUR);
}

sub _open_file {
  my $filename = shift;

  my $handle = gensym();

  # FIFOs (named pipes) are opened R/W so they don't report EOF.
  # Everything else is opened read-only.
  if (-p $filename) {
    return $handle if open $handle, "+<", $filename;
    return;
  }

  return $handle if open $handle, "<", $filename;
  return;
}

1;

__END__

=head1 NAME

POE::Wheel::FollowTail - follow the tail of an ever-growing file

=head1 SYNOPSIS

  #!perl

  use POE qw(Wheel::FollowTail);

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
          Filename => "/var/log/system.log",
          InputEvent => "got_log_line",
          ResetEvent => "got_log_rollover",
        );
      },
      got_log_line => sub {
        print "Log: $_[ARG0]\n";
      },
      got_log_rollover => sub {
        print "Log rolled over.\n";
      },
    }
  );

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE::Wheel::FollowTail objects watch for new data at the end of a file
and generate new events when things happen to the file. Its C<Filter>
parameter defines how to parse data from the file. Each new item is sent
to the creator's session as an C<InputEvent> event. Log rotation will
trigger a C<ResetEvent>.

POE::Wheel::FollowTail only reads from a file, so it doesn't implement
a put() method.

=head1 PUBLIC METHODS

=head2 new

new() returns a new POE::Wheel::FollowTail object.  As long as this
object exists, it will generate events when the corresponding file's
status changes.

new() accepts a small set of named parameters:

=head3 Driver

The optional C<Driver> parameter specifies which driver to use when
reading from the tailed file.  If omitted, POE::Wheel::FollowTail will
use POE::Driver::SysRW.  This is almost always the right thing to do.

=head3 Filter

C<Filter> is an optional constructor parameter that specifies how to
parse data from the followed file.  By default, POE::Wheel::FollowTail
will use POE::Filter::Line to parse files as plain, newline-separated
text.

  $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
    Filename => "/var/log/snort/alert",
    Filter => POE::Filter::Snort->new(),
    InputEvent => "got_snort_alert",
  );

=head3 PollInterval

POE::Wheel::FollowTail needs to periodically check for new data on the
followed file.  C<PollInterval> specifies the number of seconds to
wait between checks.  Applications that need to poll once per second
may omit C<PollInterval>, as it defaults to 1.

Longer poll intervals may be used to reduce the polling overhead for
infrequently updated files.

  $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
    ...,
    PollInterval => 10,
  );

=head3 Seek

If specified, C<Seek> instructs POE::Wheel::FollowTail to seek to a
specific spot in the tailed file before beginning to read from it.  A
positive C<Seek> value is interpreted as the number of octets to seek
from the start of the file.  Negative C<Seek> will, like negative
array indices, seek backwards from the end of the file.  Zero C<Seek>
starts reading from the beginning of the file.

Be careful when using C<Seek>, as it's quite easy to seek into the
middle of a record.  When in doubt, and when beginning at the end of
the file, omit C<Seek> entirely.  POE::Wheel::FollowTail will seek
4 kilobytes back from the end of the file, then parse and discard all
records unto EOF.  As long as the file's records are smaller than 4
kilobytes, this will guarantee that the first record returned will be
complete.

C<Seek> may also be used with the wheel's tell() method to restore the
file position after a program restart.  Save the tell() value prior to
exiting, and load and C<Seek> back to it on subsequent start-up.

TODO - Example.

=head3 SeekBack

C<SeekBack> behaves like the inverse of C<Seek>.  A positive value
acts like a negative C<Seek>.  A negative value acts like a positive
C<Seek>.  A zero C<SeekBack> instructs POE::Wheel::FollowTail to begin
at the very end of the file.

C<Seek> and C<SeekBack> are mutually exclusive.

See L</Seek> for caveats, techniques, and an explanation of the magic
that happens when neither C<Seek> nor C<SeekBack> is specified.

TODO - Example.

=head3 Handle

POE::Wheel::FollowTail may follow a previously opened file C<Handle>.
Unfortunately it cannot follow log resets this way, as it won't be
able to reopen the file once it has been reset.  Applications that
must follow resets should use C<Filename> instead.

C<Handle> is still useful for files that will never be reset, or for
devices that require setup outside of POE::Wheel::FollowTail's
purview.

C<Handle> and C<Filename> are mutually exclusive.  One of them is
required, however.

TODO - Example.

=head3 Filename

Specify the C<Filename> to watch.  POE::Wheel::FollowTail will wait
for the file to appear if it doesn't exist.  The wheel will also
reopen the file if it disappears, such as when it has been reset or
rolled over.  In the case of a reset, POE::Wheel::FollowTail will also
emit a C<ResetEvent>, if one has been requested.

C<Handle> and C<Filename> are mutually exclusive.  One of them is
required, however.

See the L</SYNOPSIS> for an example.

=head3 InputEvent

The C<InputEvent> parameter is required, and it specifies the event to
emit when new data arrives in the watched file.  C<InputEvent> is
described in detail in L</PUBLIC EVENTS>.

=head3 ResetEvent

C<ResetEvent> is an optional.  It specifies the name of the event that
indicates file rollover or reset.  Please see L</PUBLIC EVENTS> for
more details.

=head3 ErrorEvent

POE::Wheel::FollowTail may emit optional C<ErrorEvent>s whenever it
runs into trouble.  The data that comes with this event is explained
in L</PUBLIC EVENTS>.

=head2 event

event() allows a session to change the events emitted by a wheel
without destroying and re-creating the object.  It accepts one or more
of the events listed in L</PUBLIC EVENTS>.  Undefined event names
disable those events.

Stop handling log resets:

  sub some_event_handler {
    $_[HEAP]{tailor}->event( ResetEvent => undef );
  }

The events are described in more detail in L</PUBLIC EVENTS>.

=head2 ID

The ID() method returns the wheel's unique ID.  It's useful for
storing the wheel in a hash.  All POE::Wheel events should be
accompanied by a wheel ID, which allows the wheel to be referenced in
their event handlers.

  sub setup_tailor {
    my $wheel = POE::Wheel::FollowTail->new(... incomplete ...);
    $_[HEAP]{tailors}{$wheel->ID} = $wheel;
  }

See the example in L</ErrorEvent> for a handler that will find this
wheel again.

=head2 tell

tell() returns the current position for the file being watched by
POE::Wheel::FollowTail.  It may be useful for saving the position
program termination.  new()'s C<Seek> parameter may be used to
resume watching the file where tell() left off.

  sub handle_shutdown {
    # Not robust.  Do better in production.
    open my $save, ">", "position.save" or die $!;
    print $save $_[HEAP]{tailor}->tell(), "\n";
    close $save;
  }

  sub handle_startup {
    open my $save, "<", "position.save" or die $!;
    chomp(my $seek = <$save>);
    $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
      ...,
      Seek => $seek,
    );
  }

=head1 PUBLIC EVENTS

POE::Wheel::FollowTail emits a small number of events.

=head2 InputEvent

C<InputEvent> sets the name of the event to emit when new data arrives
into the tailed file.  The event will be accompanied by two
parameters:

C<$_[ARG0]> contains the data that was read from the file, after being
parsed by the current C<Filter>.

C<$_[ARG1]> contains the wheel's ID, which may be used as a key into a
data structure tracking multiple wheels.  No assumption should be made
about the nature or format of this ID, as it may change at any time.
Therefore, track your wheels in a hash.

See the L</SYNOPSIS> for an example.

=head2 ResetEvent

C<ResetEvent> names the event to be emitted whenever the wheel detects
that the followed file has been reset.  It's only available when
watching files by name, as POE::Wheel::FollowTail must reopen the file
after it has been reset.

C<ResetEvent> comes with only one parameter, C<$_[ARG0]>, which
contains the wheel's ID.  See L</InputEvent> for some notes about what
may be done with wheel IDs.

See the L</SYNOPSIS> for an example.

=head2 ErrorEvent

C<ErrorEvent> names the event emitted when POE::Wheel::FollowTail
encounters a problem.  Every C<ErrorEvent> comes with four parameters
that describe the error and its situation:

C<$_[ARG0]> describes the operation that failed.  This is usually
"read", since POE::Wheel::FollowTail spends most of its time reading
from a file.

C<$_[ARG1]> and C<$_[ARG2]> contain the numeric and stringified values
of C<$!>, respectively.  They will never contain EAGAIN (or its local
equivalent) since POE::Wheel::FollowTail handles that error itself.

C<$_[ARG3]> contains the wheel's ID, which has been discussed in
L</InputEvent>.

This error handler logs a message to STDERR and then shuts down the
wheel.  It assumes that the session is watching multiple files.

  sub handle_tail_error {
    my ($operation, $errnum, $errstr, $wheel_id) = @_[ARG0..ARG3];
    warn "Wheel $wheel_id: $operation error $errnum: $errstr\n";
    delete $_[HEAP]{tailors}{$wheel_id};
  }

=head1 SEE ALSO

L<POE::Wheel> describes the basic operations of all wheels in more
depth.  You need to know this.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

This wheel can't tail pipes and consoles on some operating systems.

POE::Wheel::FollowTail generally reads ahead of the data it returns,
so the tell() position may be later in the file than the data an
application has already received.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
