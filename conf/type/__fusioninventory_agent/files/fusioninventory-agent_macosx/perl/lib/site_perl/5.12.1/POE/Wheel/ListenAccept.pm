package POE::Wheel::ListenAccept;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw( croak carp );
use Symbol qw( gensym );

use POSIX qw(:fcntl_h);
use Errno qw(EWOULDBLOCK);
use POE qw( Wheel );
use base qw(POE::Wheel);

sub SELF_HANDLE       () { 0 }
sub SELF_EVENT_ACCEPT () { 1 }
sub SELF_EVENT_ERROR  () { 2 }
sub SELF_UNIQUE_ID    () { 3 }
sub SELF_STATE_ACCEPT () { 4 }

sub CRIMSON_SCOPE_HACK ($) { 0 }

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  my %params = @_;

  croak "wheels no longer require a kernel reference as their first parameter"
    if (@_ && (ref($_[0]) eq 'POE::Kernel'));

  croak "$type requires a working Kernel" unless defined $poe_kernel;

  croak "Handle required"      unless defined $params{Handle};
  croak "AcceptEvent required" unless defined $params{AcceptEvent};

  my $self = bless [ $params{Handle},                  # SELF_HANDLE
                     delete $params{AcceptEvent},      # SELF_EVENT_ACCEPT
                     delete $params{ErrorEvent},       # SELF_EVENT_ERROR
                     &POE::Wheel::allocate_wheel_id(), # SELF_UNIQUE_ID
                     undef,                            # SELF_STATE_ACCEPT
                   ], $type;
                                        # register private event handlers
  $self->_define_accept_state();
  $poe_kernel->select($self->[SELF_HANDLE], $self->[SELF_STATE_ACCEPT]);

  $self;
}

#------------------------------------------------------------------------------

sub event {
  my $self = shift;
  push(@_, undef) if (scalar(@_) & 1);

  while (@_) {
    my ($name, $event) = splice(@_, 0, 2);

    if ($name eq 'AcceptEvent') {
      if (defined $event) {
        $self->[SELF_EVENT_ACCEPT] = $event;
      }
      else {
        carp "AcceptEvent requires an event name.  ignoring undef";
      }
    }
    elsif ($name eq 'ErrorEvent') {
      $self->[SELF_EVENT_ERROR] = $event;
    }
    else {
      carp "ignoring unknown ListenAccept parameter '$name'";
    }
  }
}

#------------------------------------------------------------------------------

sub _define_accept_state {
  my $self = shift;
                                        # stupid closure trick
  my $event_accept = \$self->[SELF_EVENT_ACCEPT];
  my $event_error  = \$self->[SELF_EVENT_ERROR];
  my $handle       = $self->[SELF_HANDLE];
  my $unique_id    = $self->[SELF_UNIQUE_ID];
                                        # register the select-read handler
  $poe_kernel->state
    ( $self->[SELF_STATE_ACCEPT] =  ref($self) . "($unique_id) -> select read",
      sub {
        # prevents SEGV
        0 && CRIMSON_SCOPE_HACK('<');

        # subroutine starts here
        my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];

        my $new_socket = gensym;
        my $peer = accept($new_socket, $handle);

        if ($peer) {
          $k->call($me, $$event_accept, $new_socket, $peer, $unique_id);
        }
        elsif ($! != EWOULDBLOCK) {
          $$event_error &&
            $k->call($me, $$event_error, 'accept', ($!+0), $!, $unique_id);
        }
      }
    );
}

#------------------------------------------------------------------------------

sub DESTROY {
  my $self = shift;
                                        # remove tentacles from our owner
  $poe_kernel->select($self->[SELF_HANDLE]);

  if ($self->[SELF_STATE_ACCEPT]) {
    $poe_kernel->state($self->[SELF_STATE_ACCEPT]);
    undef $self->[SELF_STATE_ACCEPT];
  }

  &POE::Wheel::free_wheel_id($self->[SELF_UNIQUE_ID]);
}

#------------------------------------------------------------------------------

sub ID {
  return $_[0]->[SELF_UNIQUE_ID];
}

1;

__END__

=head1 NAME

POE::Wheel::ListenAccept - accept connections from regular listening sockets

=head1 SYNOPSIS

See L<POE::Wheel::SocketFactory/SYNOPSIS> for a simpler version of
this program.

  #!perl

  use warnings;
  use strict;

  use IO::Socket;
  use POE qw(Wheel::ListenAccept Wheel::ReadWrite);

  POE::Session->create(
    inline_states => {
      _start => sub {
        # Start the server.
        $_[HEAP]{server} = POE::Wheel::ListenAccept->new(
          Handle => IO::Socket::INET->new(
            LocalPort => 12345,
            Listen => 5,
          ),
          AcceptEvent => "on_client_accept",
          ErrorEvent => "on_server_error",
        );
      },
      on_client_accept => sub {
        # Begin interacting with the client.
        my $client_socket = $_[ARG0];
        my $io_wheel = POE::Wheel::ReadWrite->new(
          Handle => $client_socket,
          InputEvent => "on_client_input",
          ErrorEvent => "on_client_error",
        );
        $_[HEAP]{client}{ $io_wheel->ID() } = $io_wheel;
      },
      on_server_error => sub {
        # Shut down server.
        my ($operation, $errnum, $errstr) = @_[ARG0, ARG1, ARG2];
        warn "Server $operation error $errnum: $errstr\n";
        delete $_[HEAP]{server};
      },
      on_client_input => sub {
        # Handle client input.
        my ($input, $wheel_id) = @_[ARG0, ARG1];
        $input =~ tr[a-zA-Z][n-za-mN-ZA-M]; # ASCII rot13
        $_[HEAP]{client}{$wheel_id}->put($input);
      },
      on_client_error => sub {
        # Handle client error, including disconnect.
        my $wheel_id = $_[ARG3];
        delete $_[HEAP]{client}{$wheel_id};
      },
    }
  );

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE::Wheel::ListenAccept implements non-blocking accept() calls for
plain old listening server sockets.  The application provides the
socket, using some normal means such as socket(), IO::Socket::INET, or
IO::Socket::UNIX.  POE::Wheel::ListenAccept monitors the listening
socket and emits events whenever a new client has been accepted.

Please see L<POE::Wheel::SocketFactory> if you need non-blocking
connect() or a more featureful listen/accept solution.

POE::Wheel::ListenAccept only accepts client connections.  It does not
read or write data, so it neither needs nor includes a put() method.
L<POE::Wheel::ReadWrite> generally handles the accepted client socket.

=head1 PUBLIC METHODS

=head2 new

new() creates a new POE::Wheel::ListenAccept object for a given
listening socket.  The object will generate events relating to the
socket for as long as it exists.

new() accepts two required named parameters:

=head3 Handle

The C<Handle> constructor parameter must contain a listening socket
handle.  POE::Wheel::FollowTail will monitor this socket and accept()
new connections as they arrive.

=head3 AcceptEvent

C<AcceptEvent> is a required event name that POE::Wheel::ListenAccept
will emit for each accepted client socket.  L</PUBLIC EVENTS>
describes it in detail

=head3 ErrorEvent

C<ErrorEvent> is an optional event name that will be emitted whenever
a serious problem occurs.  Please see L</PUBLIC EVENTS> for more
details.

=head2 event

event() allows a session to change the events emitted by a wheel
without destroying and re-creating the object.  It accepts one or more
of the events listed in L</PUBLIC EVENTS>.  Undefined event names
disable those events.

Ignore connections:

  sub ignore_new_connections {
    $_[HEAP]{tailor}->event( AcceptEvent => "on_ignored_accept" );
  }

  sub handle_ignored_accept {
    # does nothing
  }

=head2 ID

The ID() method returns the wheel's unique ID.  It's useful for
storing the wheel in a hash.  All POE::Wheel events should be
accompanied by a wheel ID, which allows the wheel to be referenced in
their event handlers.

  sub setup_listener {
    my $wheel = POE::Wheel::ListenAccept->new(... etc  ...);
    $_[HEAP]{listeners}{$wheel->ID} = $wheel;
  }

=head1 PUBLIC EVENTS

POE::Wheel::ListenAccept emits a couple events.

=head2 AcceptEvent

C<AcceptEvent> names the event that will be emitted for each newly
accepted client socket.  It is accompanied by three parameters:

C<$_[ARG0]> contains the newly accepted client socket handle.  It's up
to the application to do something with this socket.  Most use cases
involve passing the socket to a L<POE::Wheel::ReadWrite> constructor.

C<$_[ARG1]> contains the accept() call's return value, which is often
the encoded remote end of the remote end of the socket.

C<$_[ARG2]> contains the POE::Wheel::ListenAccept object's unique ID.
This is the same value as returned by the wheel's ID() method.

A sample C<AcceptEvent> handler:

  sub accept_state {
    my ($client_socket, $remote_addr, $wheel_id) = @_[ARG0..ARG2];

    # Make the remote address human readable.
    my ($port, $packed_ip) = sockaddr_in($remote_addr);
    my $dotted_quad = inet_ntoa($packed_ip);

    print(
      "Wheel $wheel_id accepted a connection from ",
      "$dotted_quad port $port.\n"
    );

    # Spawn off a session to interact with the socket.
    create_server_session($handle);
  }

=head2 ErrorEvent

C<ErrorEvent> names the event that will be generated whenever a new
connection could not be successfully accepted.  This event is
accompanied by four parameters:

C<$_[ARG0]> contains the name of the operation that failed.  This
usually is 'accept', but be aware that it's not necessarily a function
name.

C<$_[ARG1]> and C<$_[ARG2]> hold the numeric and stringified values
of C<$!>, respectively.  POE::Wheel::ListenAccept knows how to handle
EAGAIN (and system-dependent equivalents), so this error will never be
returned.

C<$_[ARG3]> contains the wheel's unique ID, which may be useful for
shutting down one particular wheel out of a group of them.

A sample C<ErrorEvent> event handler.  This assumes the wheels are
saved as in the L</ID> example.

  sub error_state {
    my ($operation, $errnum, $errstr, $wheel_id) = @_[ARG0..ARG3];
    warn "Wheel $wheel_id generated $operation error $errnum: $errstr\n";
    delete $_[HEAP]{listeners}{$wheel_id};
  }

=head1 SEE ALSO

L<POE::Wheel> describes the basic operations of all wheels in more
depth.  You need to know this.

L<POE::Wheel::ReadWrite> for one possible way to handle clients once
you have their sockets.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

None known.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
