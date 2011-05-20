package POE::Wheel::ReadWrite;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw( croak carp );
use POE qw(Wheel Driver::SysRW Filter::Line);
use base qw(POE::Wheel);

# Offsets into $self.
sub HANDLE_INPUT               () {  0 }
sub HANDLE_OUTPUT              () {  1 }
sub FILTER_INPUT               () {  2 }
sub FILTER_OUTPUT              () {  3 }
sub DRIVER_BOTH                () {  4 }
sub EVENT_INPUT                () {  5 }
sub EVENT_ERROR                () {  6 }
sub EVENT_FLUSHED              () {  7 }
sub WATERMARK_WRITE_MARK_HIGH  () {  8 }
sub WATERMARK_WRITE_MARK_LOW   () {  9 }
sub WATERMARK_WRITE_EVENT_HIGH () { 10 }
sub WATERMARK_WRITE_EVENT_LOW  () { 11 }
sub WATERMARK_WRITE_STATE      () { 12 }
sub DRIVER_BUFFERED_OUT_OCTETS () { 13 }
sub STATE_WRITE                () { 14 }
sub STATE_READ                 () { 15 }
sub UNIQUE_ID                  () { 16 }
sub AUTOFLUSH                  () { 17 }

sub CRIMSON_SCOPE_HACK ($) { 0 }

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  my %params = @_;

  croak "wheels no longer require a kernel reference as their first parameter"
    if (@_ && (ref($_[0]) eq 'POE::Kernel'));

  croak "$type requires a working Kernel" unless defined $poe_kernel;

  my ($in_handle, $out_handle);
  if (defined $params{Handle}) {
    carp "Ignoring InputHandle parameter (Handle parameter takes precedence)"
      if defined $params{InputHandle};
    carp "Ignoring OutputHandle parameter (Handle parameter takes precedence)"
      if defined $params{OutputHandle};
    $in_handle = $out_handle = delete $params{Handle};
  }
  else {
    croak "Handle or InputHandle required"
      unless defined $params{InputHandle};
    croak "Handle or OutputHandle required"
      unless defined $params{OutputHandle};
    $in_handle  = delete $params{InputHandle};
    $out_handle = delete $params{OutputHandle};
  }

  my ($in_filter, $out_filter);
  if (defined $params{Filter}) {
    carp "Ignoring InputFilter parameter (Filter parameter takes precedence)"
      if (defined $params{InputFilter});
    carp "Ignoring OutputFilter parameter (Filter parameter takes precedence)"
      if (defined $params{OutputFilter});
    $in_filter = $out_filter = delete $params{Filter};
  }
  else {
    $in_filter = delete $params{InputFilter};
    $out_filter = delete $params{OutputFilter};

    # If neither Filter, InputFilter or OutputFilter is defined, then
    # they default to POE::Filter::Line.
    unless (defined $in_filter and defined $out_filter) {
      my $new_filter = POE::Filter::Line->new();
      $in_filter = $new_filter unless defined $in_filter;
      $out_filter = $new_filter unless defined $out_filter;
    }
  }

  my $driver = delete $params{Driver};
  $driver = POE::Driver::SysRW->new() unless defined $driver;

  { my $mark_errors = 0;
    if (defined($params{HighMark}) xor defined($params{LowMark})) {
      carp "HighMark and LowMark parameters require each-other";
      $mark_errors++;
    }
    # Then they both exist, and they must be checked.
    elsif (defined $params{HighMark}) {
      unless (defined($params{HighMark}) and defined($params{LowMark})) {
        carp "HighMark and LowMark parameters must both be defined";
        $mark_errors++;
      }
      unless (($params{HighMark} > 0) and ($params{LowMark} > 0)) {
        carp "HighMark and LowMark parameters must be above 0";
        $mark_errors++;
      }
    }
    if (defined $params{HighEvent} and not defined $params{HighMark}) {
      carp "HighEvent requires a corresponding HighMark";
      $mark_errors++;
    }
    if (defined($params{LowMark}) xor defined($params{LowEvent})) {
      carp "LowMark and LowEvent parameters require each-other";
      $mark_errors++;
    }
    croak "Water mark errors" if $mark_errors;
  }

  my $self = bless [
    $in_handle,                       # HANDLE_INPUT
    $out_handle,                      # HANDLE_OUTPUT
    $in_filter,                       # FILTER_INPUT
    $out_filter,                      # FILTER_OUTPUT
    $driver,                          # DRIVER_BOTH
    delete $params{InputEvent},       # EVENT_INPUT
    delete $params{ErrorEvent},       # EVENT_ERROR
    delete $params{FlushedEvent},     # EVENT_FLUSHED
    # Water marks.
    delete $params{HighMark},         # WATERMARK_WRITE_MARK_HIGH
    delete $params{LowMark},          # WATERMARK_WRITE_MARK_LOW
    delete $params{HighEvent},        # WATERMARK_WRITE_EVENT_HIGH
    delete $params{LowEvent},         # WATERMARK_WRITE_EVENT_LOW
    0,                                # WATERMARK_WRITE_STATE
    # Driver statistics.
    0,                                # DRIVER_BUFFERED_OUT_OCTETS
    # Dynamic state names.
    undef,                            # STATE_WRITE
    undef,                            # STATE_READ
    # Unique ID.
    &POE::Wheel::allocate_wheel_id(), # UNIQUE_ID
    delete $params{AutoFlush},         # AUTOFLUSH
  ], $type;

  if (scalar keys %params) {
    carp(
      "unknown parameters in $type constructor call: ",
      join(', ', keys %params)
    );
  }

  $self->_define_read_state();
  $self->_define_write_state();

  return $self;
}

#------------------------------------------------------------------------------
# Redefine the select-write handler.  This uses stupid closure tricks
# to prevent keeping extra references to $self around.

sub _define_write_state {
  my $self = shift;

  # Read-only members.  If any of these change, then the write state
  # is invalidated and needs to be redefined.
  my $driver        = $self->[DRIVER_BOTH];
  my $high_mark     = $self->[WATERMARK_WRITE_MARK_HIGH];
  my $low_mark      = $self->[WATERMARK_WRITE_MARK_LOW];
  my $event_error   = \$self->[EVENT_ERROR];
  my $event_flushed = \$self->[EVENT_FLUSHED];
  my $event_high    = \$self->[WATERMARK_WRITE_EVENT_HIGH];
  my $event_low     = \$self->[WATERMARK_WRITE_EVENT_LOW];
  my $unique_id     = $self->[UNIQUE_ID];

  # Read/write members.  These are done by reference, to avoid pushing
  # $self into the anonymous sub.  Extra copies of $self are bad and
  # can prevent wheels from destructing properly.
  my $is_in_high_water_state     = \$self->[WATERMARK_WRITE_STATE];
  my $driver_buffered_out_octets = \$self->[DRIVER_BUFFERED_OUT_OCTETS];

  # Register the select-write handler.

  $poe_kernel->state(
    $self->[STATE_WRITE] = ref($self) . "($unique_id) -> select write",
    sub {                             # prevents SEGV
      0 && CRIMSON_SCOPE_HACK('<');
                                      # subroutine starts here
      my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];

      $$driver_buffered_out_octets = $driver->flush($handle);

      # When you can't write, nothing else matters.
      if ($!) {
        $$event_error && $k->call(
          $me, $$event_error, 'write', ($!+0), $!, $unique_id
        );
        $k->select_write($handle);
      }

      # Could write, or perhaps couldn't but only because the
      # filehandle's buffer is choked.
      else {

        # In high water state?  Check for low water.  High water
        # state will never be set if $event_low is undef, so don't
        # bother checking its definedness here.
        if ($$is_in_high_water_state) {
          if ( $$driver_buffered_out_octets <= $low_mark ) {
            $$is_in_high_water_state = 0;
            $k->call( $me, $$event_low, $unique_id ) if defined $$event_low;
          }
        }

        # Not in high water state.  Check for high water.  Needs to
        # also check definedness of $$driver_buffered_out_octets.
        # Although we know this ahead of time and could probably
        # optimize it away with a second state definition, it would
        # be best to wait until ReadWrite stabilizes.  That way
        # there will be only half as much code to maintain.
        elsif (
          $high_mark and
          ( $$driver_buffered_out_octets >= $high_mark )
        ) {
          $$is_in_high_water_state = 1;
          $k->call( $me, $$event_high, $unique_id ) if defined $$event_high;
        }
      }

      # All chunks written; fire off a "flushed" event.  This
      # occurs independently, so it's possible to get a low-water
      # call and a flushed call at the same time (if the low mark
      # is 1).
      unless ($$driver_buffered_out_octets) {
        $k->select_pause_write($handle);
        $$event_flushed && $k->call($me, $$event_flushed, $unique_id);
      }
    }
  );

  $poe_kernel->select_write($self->[HANDLE_OUTPUT], $self->[STATE_WRITE]);

  # Pause the write select immediately, unless output is pending.
  $poe_kernel->select_pause_write($self->[HANDLE_OUTPUT])
    unless ($self->[DRIVER_BUFFERED_OUT_OCTETS]);
}

#------------------------------------------------------------------------------
# Redefine the select-read handler.  This uses stupid closure tricks
# to prevent keeping extra references to $self around.

sub _define_read_state {
  my $self = shift;

  # Register the select-read handler.

  if (defined $self->[EVENT_INPUT]) {

    # If any of these change, then the read state is invalidated and
    # needs to be redefined.

    my $driver       = $self->[DRIVER_BOTH];
    my $input_filter = \$self->[FILTER_INPUT];
    my $event_input  = \$self->[EVENT_INPUT];
    my $event_error  = \$self->[EVENT_ERROR];
    my $unique_id    = $self->[UNIQUE_ID];

    # If the filter can get_one, then define the input state in terms
    # of get_one_start() and get_one().

    if (
      $$input_filter->can('get_one') and
      $$input_filter->can('get_one_start')
    ) {
      $poe_kernel->state(
        $self->[STATE_READ] = ref($self) . "($unique_id) -> select read",
        sub {

          # Protects against coredump on older perls.
          0 && CRIMSON_SCOPE_HACK('<');

          # The actual code starts here.
          my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];
          if (defined(my $raw_input = $driver->get($handle))) {
            $$input_filter->get_one_start($raw_input);
            while (1) {
              my $next_rec = $$input_filter->get_one();
              last unless @$next_rec;
              foreach my $cooked_input (@$next_rec) {
                $k->call($me, $$event_input, $cooked_input, $unique_id);
              }
            }
          }
          else {
            $$event_error and $k->call(
              $me, $$event_error, 'read', ($!+0), $!, $unique_id
            );
            $k->select_read($handle);
          }
        }
      );
    }

    # Otherwise define the input state in terms of the older, less
    # robust, yet faster get().

    else {
      $poe_kernel->state(
        $self->[STATE_READ] = ref($self) . "($unique_id) -> select read",
        sub {

          # Protects against coredump on older perls.
          0 && CRIMSON_SCOPE_HACK('<');

          # The actual code starts here.
          my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];
          if (defined(my $raw_input = $driver->get($handle))) {
            foreach my $cooked_input (@{$$input_filter->get($raw_input)}) {
              $k->call($me, $$event_input, $cooked_input, $unique_id);
            }
          }
          else {
            $$event_error and $k->call(
              $me, $$event_error, 'read', ($!+0), $!, $unique_id
            );
            $k->select_read($handle);
          }
        }
      );
    }
                                        # register the state's select
    $poe_kernel->select_read($self->[HANDLE_INPUT], $self->[STATE_READ]);
  }
                                        # undefine the select, just in case
  else {
    $poe_kernel->select_read($self->[HANDLE_INPUT])
  }
}

#------------------------------------------------------------------------------
# Redefine events.

sub event {
  my $self = shift;
  push(@_, undef) if (scalar(@_) & 1);

  my ($redefine_read, $redefine_write) = (0, 0);

  while (@_) {
    my ($name, $event) = splice(@_, 0, 2);

    if ($name eq 'InputEvent') {
      $self->[EVENT_INPUT] = $event;
      $redefine_read = 1;
    }
    elsif ($name eq 'ErrorEvent') {
      $self->[EVENT_ERROR] = $event;
      $redefine_read = $redefine_write = 1;
    }
    elsif ($name eq 'FlushedEvent') {
      $self->[EVENT_FLUSHED] = $event;
      $redefine_write = 1;
    }
    elsif ($name eq 'HighEvent') {
      if (defined $self->[WATERMARK_WRITE_MARK_HIGH]) {
        $self->[WATERMARK_WRITE_EVENT_HIGH] = $event;
        $redefine_write = 1;
      }
      else {
        carp "Ignoring HighEvent (there is no high watermark set)";
      }
    }
    elsif ($name eq 'LowEvent') {
      if (defined $self->[WATERMARK_WRITE_MARK_LOW]) {
        $self->[WATERMARK_WRITE_EVENT_LOW] = $event;
        $redefine_write = 1;
      }
      else {
        carp "Ignoring LowEvent (there is no high watermark set)";
      }
    }
    else {
      carp "ignoring unknown ReadWrite parameter '$name'";
    }
  }

  $self->_define_read_state()  if $redefine_read;
  $self->_define_write_state() if $redefine_write;
}

#------------------------------------------------------------------------------

sub DESTROY {
  my $self = shift;

  # Turn off the select.  This is a problem if a wheel is being
  # swapped, since it will turn off selects for the other wheel.
  if ($self->[HANDLE_INPUT]) {
    $poe_kernel->select_read($self->[HANDLE_INPUT]);
    $self->[HANDLE_INPUT] = undef;
  }

  if ($self->[HANDLE_OUTPUT]) {
    $poe_kernel->select_write($self->[HANDLE_OUTPUT]);
    $self->[HANDLE_OUTPUT] = undef;
  }

  if ($self->[STATE_READ]) {
    $poe_kernel->state($self->[STATE_READ]);
    $self->[STATE_READ] = undef;
  }

  if ($self->[STATE_WRITE]) {
    $poe_kernel->state($self->[STATE_WRITE]);
    $self->[STATE_WRITE] = undef;
  }

  &POE::Wheel::free_wheel_id($self->[UNIQUE_ID]);
}

#------------------------------------------------------------------------------
# TODO - We set the high/low watermark state here, but we don't fire
# events for it.  My assumption is that the return value tells us
# all we want to know.

sub put {
  my ($self, @chunks) = @_;

  my $old_buffered_out_octets = $self->[DRIVER_BUFFERED_OUT_OCTETS];
  my $new_buffered_out_octets =
    $self->[DRIVER_BUFFERED_OUT_OCTETS] =
    $self->[DRIVER_BOTH]->put($self->[FILTER_OUTPUT]->put(\@chunks));

  if (
    $self->[AUTOFLUSH] &&
    $new_buffered_out_octets and !$old_buffered_out_octets
  ) {
    $old_buffered_out_octets = $new_buffered_out_octets;
    $self->flush();
    $new_buffered_out_octets = $self->[DRIVER_BUFFERED_OUT_OCTETS];
  }

  # Resume write-ok if the output buffer gets data.  This avoids
  # redundant calls to select_resume_write(), which is probably a good
  # thing.
  if ($new_buffered_out_octets and !$old_buffered_out_octets) {
    $poe_kernel->select_resume_write($self->[HANDLE_OUTPUT]);
  }

  # If the high watermark has been reached, return true.
  if (
    $self->[WATERMARK_WRITE_MARK_HIGH] and
    $new_buffered_out_octets >= $self->[WATERMARK_WRITE_MARK_HIGH]
  ) {
    return $self->[WATERMARK_WRITE_STATE] = 1;
  }

  return $self->[WATERMARK_WRITE_STATE] = 0;
}

#------------------------------------------------------------------------------
# Redefine filter. -PG / Now that there are two filters internally,
# one input and one output, make this set both of them at the same
# time. -RCC

sub _transfer_input_buffer {
  my ($self, $buf) = @_;

  my $old_input_filter = $self->[FILTER_INPUT];

  # If the new filter implements "get_one", use that.
  if (
    $old_input_filter->can('get_one') and
    $old_input_filter->can('get_one_start')
  ) {
    if (defined $buf) {
      $self->[FILTER_INPUT]->get_one_start($buf);
      while ($self->[FILTER_INPUT] == $old_input_filter) {
        my $next_rec = $self->[FILTER_INPUT]->get_one();
        last unless @$next_rec;
        foreach my $cooked_input (@$next_rec) {
          $poe_kernel->call(
            $poe_kernel->get_active_session(),
            $self->[EVENT_INPUT],
            $cooked_input, $self->[UNIQUE_ID]
          );
        }
      }
    }
  }

  # Otherwise use the old behavior.
  else {
    if (defined $buf) {
      foreach my $cooked_input (@{$self->[FILTER_INPUT]->get($buf)}) {
        $poe_kernel->call(
          $poe_kernel->get_active_session(),
          $self->[EVENT_INPUT],
          $cooked_input, $self->[UNIQUE_ID]
        );
      }
    }
  }
}

# Set input and output filters.

sub set_filter {
  my ($self, $new_filter) = @_;
  my $buf = $self->[FILTER_INPUT]->get_pending();
  $self->[FILTER_INPUT] = $self->[FILTER_OUTPUT] = $new_filter;

  $self->_transfer_input_buffer($buf);
}

# Redefine input and/or output filters separately.
sub set_input_filter {
  my ($self, $new_filter) = @_;
  my $buf = $self->[FILTER_INPUT]->get_pending();
  $self->[FILTER_INPUT] = $new_filter;

  $self->_transfer_input_buffer($buf);
}

# No closures need to be redefined or anything.  All the previously
# put stuff has been serialized already.
sub set_output_filter {
  my ($self, $new_filter) = @_;
  $self->[FILTER_OUTPUT] = $new_filter;
}

# Get the current input filter; used for accessing the filter's custom
# methods, as in: $wheel->get_input_filter()->filter_method();
sub get_input_filter {
  my $self = shift;
  return $self->[FILTER_INPUT];
}

# Get the current input filter; used for accessing the filter's custom
# methods, as in: $wheel->get_input_filter()->filter_method();
sub get_output_filter {
  my $self = shift;
  return $self->[FILTER_OUTPUT];
}

# Set the high water mark.

sub set_high_mark {
  my ($self, $new_high_mark) = @_;

  unless (defined $self->[WATERMARK_WRITE_MARK_HIGH]) {
    carp "Ignoring high mark (must be initialized in constructor first)";
    return;
  }

  unless (defined $new_high_mark) {
    carp "New high mark is undefined.  Ignored";
    return;
  }

  unless ($new_high_mark > $self->[WATERMARK_WRITE_MARK_LOW]) {
    carp "New high mark would not be greater than low mark.  Ignored";
    return;
  }

  $self->[WATERMARK_WRITE_MARK_HIGH] = $new_high_mark;
  $self->_define_write_state();
}

sub set_low_mark {
  my ($self, $new_low_mark) = @_;

  unless (defined $self->[WATERMARK_WRITE_MARK_LOW]) {
    carp "Ignoring low mark (must be initialized in constructor first)";
    return;
  }

  unless (defined $new_low_mark) {
    carp "New low mark is undefined.  Ignored";
    return;
  }

  unless ($new_low_mark > 0) {
    carp "New low mark would be less than one.  Ignored";
    return;
  }

  unless ($new_low_mark < $self->[WATERMARK_WRITE_MARK_HIGH]) {
    carp "New low mark would not be less than high high mark.  Ignored";
    return;
  }

  $self->[WATERMARK_WRITE_MARK_LOW] = $new_low_mark;
  $self->_define_write_state();
}

# Return driver statistics.
sub get_driver_out_octets {
  $_[0]->[DRIVER_BUFFERED_OUT_OCTETS];
}

sub get_driver_out_messages {
  $_[0]->[DRIVER_BOTH]->get_out_messages_buffered();
}

# Get the wheel's ID.
sub ID {
  return $_[0]->[UNIQUE_ID];
}

# Pause the wheel's input watcher.
sub pause_input {
  my $self = shift;
  return unless defined $self->[HANDLE_INPUT];
  $poe_kernel->select_pause_read( $self->[HANDLE_INPUT] );
}

# Resume the wheel's input watcher.
sub resume_input {
  my $self = shift;
  return unless  defined $self->[HANDLE_INPUT];
  $poe_kernel->select_resume_read( $self->[HANDLE_INPUT] );
}

# Return the wheel's input handle
sub get_input_handle {
  my $self = shift;
  return $self->[HANDLE_INPUT];
}

# Return the wheel's output handle
sub get_output_handle {
  my $self = shift;
  return $self->[HANDLE_OUTPUT];
}

# Shutdown the socket for reading.
sub shutdown_input {
  my $self = shift;
  return unless defined $self->[HANDLE_INPUT];
  eval { local $^W = 0; shutdown($self->[HANDLE_INPUT], 0) };
  $poe_kernel->select_read($self->[HANDLE_INPUT], undef);
}

# Shutdown the socket for writing.
sub shutdown_output {
  my $self = shift;
  return unless defined $self->[HANDLE_OUTPUT];
  eval { local $^W=0; shutdown($self->[HANDLE_OUTPUT], 1) };
  $poe_kernel->select_write($self->[HANDLE_OUTPUT], undef);
}

# Flush the output handle
sub flush {
  my $self = shift;
  return unless defined $self->[HANDLE_OUTPUT];
  $poe_kernel->call($poe_kernel->get_active_session(),
        $self->[STATE_WRITE], $self->[HANDLE_OUTPUT]);
}

1;

__END__

=head1 NAME

POE::Wheel::ReadWrite - non-blocking buffered I/O mix-in for POE::Session

=head1 SYNOPSIS

  #!perl

  use warnings;
  use strict;

  use IO::Socket::INET;
  use POE qw(Wheel::ReadWrite);

  POE::Session->create(
    inline_states => {
      _start => sub {
        # Note: IO::Socket::INET will block.  We recommend
        # POE::Wheel::SocketFactory or POE::Component::Client::TCP if
        # blocking is contraindicated.
        $_[HEAP]{client} = POE::Wheel::ReadWrite->new(
          Handle => IO::Socket::INET->new(
            PeerHost => 'www.yahoo.com',
            PeerPort => 80,
          ),
          InputEvent => 'on_remote_data',
          ErrorEvent => 'on_remote_fail',
        );

        print "Connected.  Sending request...\n";
        $_[HEAP]{client}->put(
          "GET / HTTP/0.9",
          "Host: www.yahoo.com",
          "",
        );
      },
      on_remote_data => sub {
        print "Received: $_[ARG0]\n";
      },
      on_remote_fail => sub {
        print "Connection failed or ended.  Shutting down...\n";
        delete $_[HEAP]{client};
      },
    },
  );

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE::Wheel::ReadWrite encapsulates a common design pattern: dealing
with buffered I/O in a non-blocking, event driven fashion.

The pattern goes something like this:

Given a filehandle, watch it for incoming data.  When notified of
incoming data, read it, buffer it, and parse it according to some
low-level protocol (such as line-by-line).  Generate higher-level
"here be lines" events, one per parsed line.

In the other direction, accept whole chunks of data (such as lines)
for output.  Reformat them according to some low-level protocol (such
as by adding newlines), and buffer them for output.  Flush the
buffered data when the filehandle is ready to transmit it.

=head1 PUBLIC METHODS

=head2 Constructor

POE::Wheel subclasses tend to perform a lot of setup so that they run
lighter and faster.  POE::Wheel::ReadWrite's constructor is no
exception.

=head3 new

new() creates and returns a new POE:Wheel::ReadWrite instance.  Under
most circumstances, the wheel will continue to read/write to one or
more filehandles until it's destroyed.

=head4 Handle

Handle defines the filehandle that a POE::Wheel::ReadWrite object will
read from and write to.  The L</SYNOPSIS> includes an example using
Handle.

A single POE::Wheel::ReadWrite object can read from and write to different
filehandles.  See L</InputHandle> for more information and an example.

=head4 InputHandle

InputHandle and OutputHandle may be used to specify different handles
for input and output.  For example, input may be from STDIN and output
may go to STDOUT:

  $_[HEAP]{console} = POE::Wheel::ReadWrite->new(
    InputHandle => \*STDIN,
    OutputHandle => \*STDOUT,
    InputEvent => "console_input",
  );

InputHandle and OutputHandle may not be used with Handle.

=head4 OutputHandle

InputHandle and OutputHandle may be used to specify different handles
for input and output.  Please see L</InputHandle> for more information
and an example.

=head4 Driver

Driver specifies how POE::Wheel::ReadWrite will actually read from and
write to its filehandle or filehandles.  Driver must be an object that
inherits from L<POE::Driver>.

L<POE::Driver::SysRW>, which implements sysread() and syswrite(), is the
default.  It's used in nearly all cases, so there's no point in
specifying it.

TODO - Example.

=head4 Filter

Filter is the parser that POE::Wheel::ReadWrite will used to recognize
input data and the serializer it uses to prepare data for writing.  It
defaults to a new L<POE::Filter::Line> instance since many network
protocols are line based.

TODO - Example.

=head4 InputFilter

InputFilter and OutputFilter may be used to specify different filters
for input and output.

TODO - Example.

=head4 OutputFilter

InputFilter and OutputFilter may be used to specify different filters
for input and output. Please see L</InputFilter> for more information
and an example.

=head4 InputEvent

InputEvent specifies the name of the event that will be sent for every
complete input unit (as parsed by InputFilter or Filter).

Every input event includes two parameters:

C<ARG0> contains the parsed input unit, and C<ARG1> contains the
unique ID for the POE::Wheel::ReadWrite object that generated the
event.

InputEvent is optional.  If omitted, the POE::Wheel::ReadWrite object
will not watch its Handle or InputHandle for input, and no input
events will be generated.

A sample InputEvent handler:

  sub handle_input {
    my ($heap, $input, $wheel_id) = @_[HEAP, ARG0, ARG1];
    print "Echoing input from wheel $wheel_id: $input\n";
    $heap->{wheel}->put($input); # Put... the input... beck!
  }

=head4 FlushedEvent

FlushedEvent specifies the event that a POE::Wheel::ReadWrite object
will emit whenever its output buffer transitions from containing data
to becoming empty.

FlushedEvent comes with a single parameter: C<ARG0> contains the
unique ID for the POE::Wheel::ReadWrite object that generated the
event.  This may be used to match the event to a particular wheel.

"Flushed" events are often used to shut down I/O after a "goodbye"
message has been sent.  For example, the following input_handler()
responds to "quit" by instructing the wheel to say "Goodbye." and then
to send a "shutdown" event when that has been flushed to the socket.

  sub handle_input {
    my ($input, $wheel_id) = @_[ARG0, ARG1];
    my $wheel = $_[HEAP]{wheel}{$wheel_id};

    if ($input eq "quit") {
      $wheel->event( FlushedEvent => "shutdown" );
      $wheel->put("Goodbye.");
    }
    else {
      $wheel->put("Echo: $input");
    }
  }

Here's the shutdown handler.  It just destroys the wheel to end the
connection:

  sub handle_flushed {
    my $wheel_id = $_[ARG0];
    delete $_[HEAP]{wheel}{$wheel_id};
  }

=head4 ErrorEvent

ErrorEvent names the event that a POE::Wheel::ReadWrite object will
emit whenever an error occurs.  Every ErrorEvent includes four
parameters:

C<ARG0> describes what failed, either "read" or "write".  It doesn't
name a particular function since POE::Wheel::ReadWrite delegates
actual reading and writing to a L<POE::Driver> object.

C<ARG1> and C<ARG2> hold numeric and string values for C<$!> at the
time of failure.  Applicatin code cannot test C<$!> directly since its
value may have changed between the time of the error and the time the
error event is dispatched.

C<ARG3> contains the wheel's unique ID.  The wheel's ID is used to
differentiate between many wheels managed by a single session.

ErrorEvent may also indicate EOF on a FileHandle by returning
operation "read" error 0.  For sockets, this means the remote end has
closed the connection.

A sample ErrorEvent handler:

  sub error_state {
    my ($operation, $errnum, $errstr, $id) = @_[ARG0..ARG3];
    if ($operation eq "read" and $errnum == 0) {
      print "EOF from wheel $id\n";
    }
    else {
      warn "Wheel $id encountered $operation error $errnum: $errstr\n";
    }
    delete $_[HEAP]{wheels}{$id}; # shut down that wheel
  }

=head4 HighEvent

HighEvent and LowEvent are used along with HighMark and LowMark to
control the flow of streamed output.

A HighEvent is sent when the output buffer of a POE::Wheel::ReadWrite
object exceeds a certain size (the "high water" mark, or HighMark).
This advises an application to stop streaming output.  POE and Perl
really don't care if the application continues, but it's possible that
the process may run out of memory if a buffer grows without bounds.

A POE::Wheel::ReadWrite object will continue to flush its buffer even
after an application stops streaming data, until the buffer is empty.
Some streaming applications may require the buffer to always be primed
with data, however.  For example, a media server would encounter
stutters if it waited for a FlushedEvent before sending more data.

LowEvent solves the stutter problem.  A POE::Wheel::ReadWrite object
will send a LowEvent when its output buffer drains below a certain
level (the "low water" mark, or LowMark).  This notifies an
application that the buffer is small enough that it may resume
streaming.

The stutter problem is solved because the output buffer never quite
reaches empty.

HighEvent and LowEvent are edge-triggered, not level-triggered.  This
means they are emitted once whenever a POE::Wheel::ReadWrite object's
output buffer crosses the HighMark or LowMark.  If an application
continues to put() data after the HighMark is reached, it will not
cause another HighEvent to be sent.

HighEvent is generally not needed.  The put() method will return the
high watermark state: true if the buffer is at or above the high
watermark, or false if the buffer has room for more data.  Here's a
quick way to prime a POE::Wheel::ReadWrite object's output buffer:

  1 while not $_[HEAP]{readwrite}->put(get_next_data());

POE::Wheel::ReadWrite objects always start in a low-water state.

HighEvent and LowEvent are optional.  Omit them if flow control is not
needed.

=head4 LowEvent

HighEvent and LowEvent are used along with HighMark and LowMark to
control the flow of streamed output.  Please see L</HighEvent> for
more information and examples.

TODO - Example here.

=head2 put RECORDS

put() accepts a list of RECORDS, which will be serialized by the
wheel's Filter and buffered and written by its Driver.

put() returns true if a HighMark has been set and the Driver's output
buffer has reached or exceeded the limit.  False is returned if
HighMark has not been set, or if the Driver's buffer is smaller than
that limit.

put()'s return value is purely advisory; an application may continue
buffering data beyond the HighMark---at the risk of exceeding the
process' memory limits.  Do not use C<<1 while not $wheel->put()>>
syntax if HighMark isn't set: the application will fail spectacularly!

=head2 event EVENT_TYPE => EVENT_NAME, ...

event() allows an application to modify the events emitted by a
POE::Wheel::ReadWrite object.  All constructor parameters ending in
"Event" may be changed at run time: L</InputEvent>, L</FlushedEvent>,
L</ErrorEvent>, L</HighEvent>, and L</LowEvent>.

Setting an event to undef will disable the code within the wheel that
generates the event.  So for example, stopping InputEvent will also
stop reading from the filehandle.  L</pause_input> and
L</resume_input> may be a better way to manage input events, however.

TODO - Example.

=head2 set_filter POE_FILTER

set_filter() changes the way a POE::Wheel::ReadWrite object parses
input and serializes output.  Any pending data that has not been
dispatched to the application will be parsed with the new POE_FILTER.
Information that has been put() but not flushed will not be
reserialized.

set_filter() performs the same act as calling set_input_filter()
and set_output_filter() with the same POE::Filter object.

Switching filters can be tricky.  Please see the discussion of
get_pending() in L<POE::Filter>.  Some filters may not support being
dynamically loaded or unloaded.

TODO - Example.

=head2 set_input_filter POE_FILTER

set_input_filter() changes a POE::Wheel::ReadWrite object's input
filter while leaving the output filter unchanged.  This alters the way
data is parsed without affecting how it's serialized for output.

TODO - Example.

=head2 set_output_filter POE_FILTER

set_output_filter() changes how a POE::Wheel::ReadWrite object
serializes its output but does not affect the way data is parsed.

TODO - Example.

=head2 get_input_filter

get_input_filter() returns the POE::Filter object currently used by a
POE::Wheel::ReadWrite object to parse incoming data.  The returned
object may be introspected or altered via its own methods.

There is no get_filter() method because there is no sane return value
when input and output filters differ.

TODO - Example.

=head2 get_output_filter

get_output_filter() returns the L<POE::Filter> object currently used by a
POE::Wheel::ReadWrite object to serialize outgoing data.  The returned
object may be introspected or altered via its own methods.

There is no get_filter() method because there is no sane return value
when input and output filters differ.

TODO - Example.

=head2 set_high_mark HIGH_MARK_OCTETS

Sets the high water mark---the number of octets that designates a
"full enough" output buffer.  A POE::Wheel::ReadWrite object will emit
a HighEvent when its output buffer expands to reach this point.  All
put() calls will return true when the output buffer is equal or
greater than HIGH_MARK_OCTETS.

Both HighEvent and put() indicate that it's unsafe to continue writing
when the output buffer expands to at least HIGH_MARK_OCTETS.

TODO - Example.

=head2 set_low_mark LOW_MARK_OCTETS

Sets the low water mark---the number of octets that designates an
"empty enough" output buffer.  This event lets an application know
that it's safe to resume writing again.

POE::Wheel::ReadWrite objects will emit a LowEvent when their output
buffers shrink to LOW_MARK_OCTETS after having reached
HIGH_MARK_OCTETS.

TODO - Example.

=head2 ID

ID() returns a POE::Wheel::ReadWrite object's unique ID.  ID() is
usually called after the object is created so that the object may be
stashed by its ID.  Events generated by the POE::Wheel::ReadWrite
object will include the ID of the object, so that they may be matched
back to their sources.

TODO - Example.

=head2 pause_input

pause_input() instructs a POE::Wheel::ReadWrite object to stop
watching for input, and thus stop emitting InputEvent events.  It's
much more efficient than destroying the object outright, especially if
an application intends to resume_input() later.

TODO - Example.

=head2 resume_input

resume_input() turns a POE::Wheel::ReadWrite object's input watcher
back on.  It's used to resume watching for input, and thus resume
sending InputEvent events.  pause_input() and resume_input() implement
a form of input flow control, driven by the application itself.

TODO - Example.

=head2 get_input_handle

get_input_handle() returns the filehandle being watched for input.

Manipulating filehandles that are managed by POE may cause nasty side
effects, which may change from one POE release to the next.  Please
use caution.

TODO - Example.

=head2 get_output_handle

get_output_handle() returns the filehandle being watched for output.

Manipulating filehandles that are managed by POE may cause nasty side
effects, which may change from one POE release to the next.  Please
use caution.

TODO - Example.

=head2 shutdown_input

Call shutdown($fh,0) on a POE::Wheel::ReadWrite object's input
filehandle.  This only works for sockets; nothing will happen for
other types of filehandle.

Occasionally, the POE::Wheel::ReadWrite object will stop monitoring
its input filehandle for new data.  This occurs regardless of the
filehandle type.

TODO - Example.

=head2 shutdown_output

Call shutdown($fh,1) on a POE::Wheel::ReadWrite object's output
filehandle.  This only works for sockets; nothing will happen for
other types of filehandle.

Occasionally, the POE::Wheel::ReadWrite object will stop monitoring its
output filehandle for new data. This occurs regardless of the
filehandle type.

TODO - Example.

=head2 get_driver_out_octets

L<POE::Driver> objects contain output buffers that are flushed
asynchronously.  get_driver_out_octets() returns the number of octets
remaining in the wheel's driver's output buffer.

TODO - Example.

=head2 get_driver_out_messages

L<POE::Driver> objects' output buffers may be message based.  Every put()
call may be buffered individually.  get_driver_out_messages() will
return the number of pending put() messages that remain to be sent.

Stream-based drivers will simply return 1 if any data remains to be
flushed.  This is because they operate with one potentially large
message.

TODO - Example.

=head2 flush

flush() manually attempts to flush a wheel's output in a synchronous
fashion.  This can be used to flush small messages.  Note, however,
that complete flushing is not guaranteed---to do so would mean
potentially blocking indefinitely, which is undesirable in most POE
applications.

If an application must guarantee a full buffer flush, it may loop
flush() calls:

  $wheel->flush() while $wheel->get_driver_out_octets();

However it would be prudent to check for errors as well.  A flush()
failure may be permanent, and an infinite loop is probably not what
most developers have in mind here.

It should be obvious by now that B<this method is experimental>.  Its
behavior may change or it may disappear outright.  Please let us know
whether it's useful.

# TODO - Example?

=head1 SEE ALSO

L<POE::Wheel> describes wheels in general.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

None known.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
