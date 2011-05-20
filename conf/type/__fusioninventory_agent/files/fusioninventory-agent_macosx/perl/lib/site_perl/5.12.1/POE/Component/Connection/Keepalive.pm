# This is a proxy object for a socket.  Its most important feature is
# that it passes the socket back to POE::Component::Client::Keepalive
# when it's destroyed.

package POE::Component::Connection::Keepalive;

use warnings;
use strict;

use vars qw($VERSION);
$VERSION = "0.262";

use Carp qw(croak);
use POE::Wheel::ReadWrite;

use constant DEBUG => 0;

sub CK_SOCKET  () { 0 }  # The socket we're hiding.
sub CK_MANAGER () { 1 }  # The connection manager that owns the socket.
sub CK_WHEEL   () { 2 }  # The wheel we're hiding.

# Assimilate a socket on construction, and the keep-alive connection
# so that free() may be called at destruction time.

sub new {
  my ($class, %args) = @_;

  my $self = bless [
    $args{socket},      # CK_SOCKET
    $args{manager},     # CK_MANAGER
    undef,              # CK_WHEEL
  ], $class;

  return $self;
}

# Free the socket on destruction.

sub DESTROY {
  my $self = shift;
  $self->[CK_WHEEL] = undef;
  $self->[CK_MANAGER]->free($self->[CK_SOCKET]);
}

# Start a Read/Write wheel on the hidden socket.

sub start {
  my $self = shift;
  croak "Must call start() with an even number of parameters" if @_ % 2;
  my %args = @_;

  # Override the read/write handle with our own.
  $args{Handle} = $self->[CK_SOCKET];

  $self->[CK_WHEEL] = POE::Wheel::ReadWrite->new(%args);
}

# Wheel accessor, for modifying the wheel directly.

sub wheel {
  my $self = shift;
  return $self->[CK_WHEEL];
}


# For getting rid of the connection prematurely

sub close {
  my $self = shift;

  DEBUG and warn "closing $self";
  if (defined $self->wheel) {
    $self->wheel->shutdown_input();
    $self->wheel->shutdown_output();
    $self->[CK_WHEEL] = undef;
  }

  DEBUG and warn "about to close potentially tied socket/ tied = ", tied(*{$self->[CK_SOCKET]}) ;
  close $self->[CK_SOCKET];

  my $is_tied = defined tied(*{$self->[CK_SOCKET]});
  # this is necessary so defined fileno() does the right thing
  # on SSLified sockets
  if ($is_tied) {
    DEBUG and warn "about to untie";
    untie(*{$self->[CK_SOCKET]});
  }

  if (DEBUG) {
    if (defined(fileno($self->[CK_SOCKET]))) {
      warn "*** BUG: fileno still defined! Is " . fileno($self->[CK_SOCKET]);
    }
  }
}

1;

__END__

=head1 NAME

POE::Component::Connection::Keepalive - a wheel wrapper around a
kept-alive socket

=head1 SYNOPSIS

  See the SYNOPSIS for POE::Component::Client::Keepalive for a
  complete working example.

  my $connection = $response->{connection};
  $heap->{connection} = $connection;

  $connection->start( InputEvent => "got_input" );

  delete $heap->{connection};  # When done with it.

=head1 DESCRIPTION

POE::Component::Connection::Keepalive is a helper class for
POE::Component::Client::Keepalive.  It wraps managed sockets,
providing a few extra features.

Connection objects free their underlying sockets when they are
DESTROYed.  This eliminates the need to explicitly free sockets when
you are done with them.

Connection objects manage POE::Wheel::ReadWrite objects internally,
saving a bit of effort.

=over 2

=item new

Creates a new POE::Component::Connection::Keepalive instance.  It
accepts two parameters: A socket handle (socket) and a reference to a
POE::Component::Client::Keepalive object to manage the socket when the
connection is destroyed.

  my $conn = POE::Component::Connection::Keepalive->new(
    socket  => $socket_handle,
    manager => $poe_component_client_keepalive,
  );

new() is usually called by a POE::Component::Client::Keepalive object.

=item start

Starts a POE::Wheel::ReadWrite object.  All parameters except Handle
for start() are passed directly to POE::Wheel::ReadWrite's
constructor.  Handle is provided by the connection object.  start()
returns a reference to the new POE::Wheel::ReadWrite object, but it is
not necessary to save a copy of that wheel.  The connection object
keeps a copy of the reference internally, so the wheel will persist as
long as the connection does.  The POE::Wheel::ReadWrite object will be
DESTROYed when the connection object is.

  # Asynchronous connection from Client::Keepalive.
  sub handle_connection {
    my $connection_info = $_[ARG0];
    $_[HEAP]->{connection} = $connection_info->{connection};

    $heap->{connection}->start(
      InputEvent => "got_input",
      ErrorEvent => "got_error",
    );
  }

  # Stop the connection (and the wheel) when an error occurs.
  sub handle_error {
    delete $_[HEAP]->{connection};
  }

=item wheel

Returns a reference to the internal POE::Wheel::ReadWrite object, so
that methods may be called upon it.

  $heap->{connection}->wheel()->pause_input();

=item close

Closes the connection immediately. Calls shutdown_input() and
shutdown_output() on the wheel also.

=back

=item SEE ALSO

L<POE>
L<POE::Component::Client::Keepalive>
L<POE::Wheel::ReadWrite>

=head1 BUGS

None known.

=head1 LICENSE

This distribution is copyright 2004-2009 by Rocco Caputo.  All rights
are reserved.  This distribution is free software; you may
redistribute it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Rocco Caputo <rcaputo@cpan.org>

Special thanks to Rob Bloodgood.

=cut
