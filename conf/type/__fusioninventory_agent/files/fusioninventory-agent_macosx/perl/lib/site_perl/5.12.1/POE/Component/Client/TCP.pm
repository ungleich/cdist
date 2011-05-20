package POE::Component::Client::TCP;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw(carp croak);
use Errno qw(ETIMEDOUT ECONNRESET);

# Explicit use to import the parameter constants;
use POE::Session;
use POE::Driver::SysRW;
use POE::Filter::Line;
use POE::Wheel::ReadWrite;
use POE::Wheel::SocketFactory;

# Create the client.  This is just a handy way to encapsulate
# POE::Session->create().  Because the states are so small, it uses
# real inline coderefs.

sub new {
  my $type = shift;

  # Helper so we don't have to type it all day.  $mi is a name I call
  # myself.
  my $mi = $type . '->new()';

  # If they give us lemons, tell them to make their own damn
  # lemonade.
  croak "$mi requires an even number of parameters" if (@_ & 1);
  my %param = @_;

  # Validate what we're given.
  croak "$mi needs a RemoteAddress parameter"
    unless exists $param{RemoteAddress};
  croak "$mi needs a RemotePort parameter"
    unless exists $param{RemotePort};

  # Extract parameters.
  my $alias           = delete $param{Alias};
  my $address         = delete $param{RemoteAddress};
  my $port            = delete $param{RemotePort};
  my $domain          = delete $param{Domain};
  my $bind_address    = delete $param{BindAddress};
  my $bind_port       = delete $param{BindPort};
  my $ctimeout        = delete $param{ConnectTimeout};
  my $args            = delete $param{Args};
  my $session_type    = delete $param{SessionType};
  my $session_params  = delete $param{SessionParams};

  $args = [] unless defined $args;
  croak "Args must be an array reference" unless ref($args) eq "ARRAY";

  foreach (
    qw(
      PreConnect Connected ConnectError Disconnected ServerInput
      ServerError ServerFlushed Started
      ServerHigh ServerLow
    )
  ) {
    croak "$_ must be a coderef" if(
      defined($param{$_}) and ref($param{$_}) ne 'CODE'
    );
  }

  my $high_mark_level = delete $param{HighMark};
  my $low_mark_level  = delete $param{LowMark};
  my $high_event      = delete $param{ServerHigh};
  my $low_event       = delete $param{ServerLow};

  # this is ugly, but now its elegant :)  grep++
  my $using_watermarks = grep { defined $_ }
    ($high_mark_level, $low_mark_level, $high_event, $low_event);
  if ($using_watermarks > 0 and $using_watermarks != 4) {
    croak "If you use the Mark settings, you must define all four";
  }

  $high_event = sub { } unless defined $high_event;
  $low_event  = sub { } unless defined $low_event;

  my $pre_conn_callback   = delete $param{PreConnect};
  my $conn_callback       = delete $param{Connected};
  my $conn_error_callback = delete $param{ConnectError};
  my $disc_callback       = delete $param{Disconnected};
  my $input_callback      = delete $param{ServerInput};
  my $error_callback      = delete $param{ServerError};
  my $flush_callback      = delete $param{ServerFlushed};
  my $start_callback      = delete $param{Started};
  my $filter              = delete $param{Filter};

  # Extra states.

  my $inline_states = delete $param{InlineStates};
  $inline_states = {} unless defined $inline_states;

  my $package_states = delete $param{PackageStates};
  $package_states = [] unless defined $package_states;

  my $object_states = delete $param{ObjectStates};
  $object_states = [] unless defined $object_states;

  croak "InlineStates must be a hash reference"
    unless ref($inline_states) eq 'HASH';

  croak "PackageStates must be a list or array reference"
    unless ref($package_states) eq 'ARRAY';

  croak "ObjectStates must be a list or array reference"
    unless ref($object_states) eq 'ARRAY';

  # Errors.

  croak "$mi requires a ServerInput parameter" unless defined $input_callback;

  foreach (sort keys %param) {
    carp "$mi doesn't recognize \"$_\" as a parameter";
  }

  # Defaults.

  $session_type = 'POE::Session' unless defined $session_type;
  if (defined($session_params) && ref($session_params)) {
    if (ref($session_params) ne 'ARRAY') {
      croak "SessionParams must be an array reference";
    }
  } else {
    $session_params = [ ];
  }

  $address = '127.0.0.1' unless defined $address;

  $conn_error_callback = \&_default_error unless defined $conn_error_callback;
  $error_callback      = \&_default_io_error unless defined $error_callback;

  # Spawn the session that makes the connection and then interacts
  # with what was connected to.

  return $session_type->create
    ( @$session_params,
      inline_states =>
      { _start => sub {
          my ($kernel, $heap) = @_[KERNEL, HEAP];
          $heap->{shutdown_on_error} = 1;
          $kernel->alias_set( $alias ) if defined $alias;
          $kernel->yield( 'reconnect' );
          $start_callback and $start_callback->(@_);
        },

        # To quiet ASSERT_STATES.
        _stop   => sub { },
        _child  => sub { },

        reconnect => sub {
          my ($kernel, $heap) = @_[KERNEL, HEAP];

          $heap->{shutdown} = 0;
          $heap->{connected} = 0;

          # Tentative patch to re-establish the alias upon reconnect.
          # Necessary because otherwise the alias goes away for good.
          # Unfortunately, there is a gap where the alias may not be
          # set, and any events dispatched then will be dropped.
          $kernel->alias_set( $alias ) if defined $alias;

          $heap->{server} = POE::Wheel::SocketFactory->new
            ( RemoteAddress => $address,
              RemotePort    => $port,
              SocketDomain  => $domain,
              BindAddress   => $bind_address,
              BindPort      => $bind_port,
              SuccessEvent  => 'got_connect_success',
              FailureEvent  => 'got_connect_error',
            );
          $_[KERNEL]->alarm_remove( delete $heap->{ctimeout_id} )
            if exists $heap->{ctimeout_id};
          $heap->{ctimeout_id} = $_[KERNEL]->alarm_set
            ( got_connect_timeout => time + $ctimeout
            ) if defined $ctimeout;
        },

        connect => sub {
          my ($new_address, $new_port) = @_[ARG0, ARG1];
          $address = $new_address if defined $new_address;
          $port    = $new_port    if defined $new_port;
          $_[KERNEL]->yield("reconnect");
        },

        got_connect_success => sub {
          my ($kernel, $heap, $socket) = @_[KERNEL, HEAP, ARG0];

          $kernel->alarm_remove( delete $heap->{ctimeout_id} )
            if exists $heap->{ctimeout_id};

          # Pre-connected callback.
          if ($pre_conn_callback) {
            unless ($socket = $pre_conn_callback->(@_)) {
              $heap->{connected} = 0;
              # TODO - Error callback?  Disconnected callback?
              return;
            }
          }

          # Ok to overwrite like this as of 0.13.
          $_[HEAP]->{server} = POE::Wheel::ReadWrite->new
            ( Handle       => $socket,
              Driver       => POE::Driver::SysRW->new(),
              Filter       => _get_filter($filter),
              InputEvent   => 'got_server_input',
              ErrorEvent   => 'got_server_error',
              FlushedEvent => 'got_server_flush',
              do {
                  $using_watermarks ? return (
                    HighMark => $high_mark_level,
                    HighEvent => 'got_high',
                    LowMark => $low_mark_level,
                    LowEvent => 'got_low',
                  ) : ();
                },
            );

          $heap->{connected} = 1;
          $conn_callback and $conn_callback->(@_);
        },
        got_high => $high_event,
        got_low => $low_event,

        got_connect_error => sub {
          my $heap = $_[HEAP];
          $_[KERNEL]->alarm_remove( delete $heap->{ctimeout_id} )
            if exists $heap->{ctimeout_id};
          $heap->{connected} = 0;
          $conn_error_callback->(@_);
          delete $heap->{server};
        },

        got_connect_timeout => sub {
          my $heap = $_[HEAP];
          $heap->{connected} = 0;
          $_[KERNEL]->alarm_remove( delete $heap->{ctimeout_id} )
            if exists $heap->{ctimeout_id};
          $! = ETIMEDOUT;
          @_[ARG0,ARG1,ARG2] = ('connect', $!+0, $!);
          $conn_error_callback->(@_);
          delete $heap->{server};
        },

        got_server_error => sub {
          $error_callback->(@_);
          if ($_[HEAP]->{shutdown_on_error}) {
            $_[KERNEL]->yield("shutdown");
            $_[HEAP]->{got_an_error} = 1;
          }
        },

        got_server_input => sub {
          my $heap = $_[HEAP];
          return if $heap->{shutdown};
          $input_callback->(@_);
        },

        got_server_flush => sub {
          my $heap = $_[HEAP];
          $flush_callback and $flush_callback->(@_);
          if ($heap->{shutdown}) {
            delete $heap->{server};
            $disc_callback and $disc_callback->(@_);
          }
        },

        shutdown => sub {
          my ($kernel, $heap) = @_[KERNEL, HEAP];
          $heap->{shutdown} = 1;

          $kernel->alarm_remove( delete $heap->{ctimeout_id} )
            if exists $heap->{ctimeout_id};

          if ($heap->{connected}) {
            $heap->{connected} = 0;
            if (defined $heap->{server}) {
              if (
                $heap->{got_an_error} or
                not $heap->{server}->get_driver_out_octets()
              ) {
                delete $heap->{server};
                $disc_callback and $disc_callback->(@_);
              }
            }
          }
          else {
            delete $heap->{server};
          }

          $kernel->alias_remove($alias) if defined $alias;
        },

        # User supplied states.
        %$inline_states,
      },

      # User arguments.
      args => $args,

      # User supplied states.
      package_states => $package_states,
      object_states  => $object_states,
    )->ID;
}

sub _get_filter {
  my $filter = shift;
  if (ref $filter eq 'ARRAY') {
    my @filter_args = @$filter;
    $filter = shift @filter_args;
    return $filter->new(@filter_args);
  } elsif (ref $filter) {
    return $filter->clone();
  } elsif (!defined($filter)) {
    return POE::Filter::Line->new();
  } else {
    return $filter->new();
  }
}

# The default error handler logs to STDERR and shuts down the socket.

sub _default_error {
  unless ($_[ARG0] eq "read" and ($_[ARG1] == 0 or $_[ARG1] == ECONNRESET)) {
    warn(
      'Client ', $_[SESSION]->ID, " got $_[ARG0] error $_[ARG1] ($_[ARG2])\n"
    );
  }
  delete $_[HEAP]->{server};
}

sub _default_io_error {
  my ($syscall, $errno, $error) = @_[ARG0..ARG2];
  $error = "Normal disconnection" unless $errno;
  warn('Client ', $_[SESSION]->ID, " got $syscall error $errno ($error)\n");
  $_[KERNEL]->yield("shutdown");
}

1;

__END__

=head1 NAME

POE::Component::Client::TCP - a simplified TCP client

=head1 SYNOPSIS

  #!perl

  use warnings;
  use strict;

  use POE qw(Component::Client::TCP);

  POE::Component::Client::TCP->new(
    RemoteAddress => "yahoo.com",
    RemotePort    => 80,
    Connected     => sub {
      $_[HEAP]{server}->put("HEAD /");
    },
    ServerInput   => sub {
      my $input = $_[ARG0];
      print "from server: $input\n";
    },
  );

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE::Component::Client::TCP implements a generic single-Session
client.  Internally it uses POE::Wheel::SocketFactory to establish the
connection and POE::Wheel::ReadWrite to interact with the server.

POE::Component::Cilent::TCP is customized by providing callbacks for
common operations.  Most operations have sensible default callbacks,
so clients may be created with as little work as possible.

=head2 Performance Considerations

POE::Component::Client::TCP's ease of use comes at a price.  The
component is generic, so it's not tuned to perform well for any
particular application.

If performance is your primary goal, POE::Kernel's select_read() and
select_write() perform about the same as IO::Select, but your code
will be portable across every event loop POE supports.

=head1 PUBLIC METHODS

=head2 new

new() starts a client based on POE::Component::Client::TCP and returns
the ID of the session that will handle server interaction.

new() returns immediately, which may be before the client has
established its connection.  It is always reliable to wait for the
C<Connected> callback to fire before transmitting data to the server.

The client's constructor may seem to take a daunting number of
parameters.  As with most POE modules, POE::Component::Client::TCP
tries to do as much work in its constructor so that the run-time code
path is relatively light.

=head3 Constructor Parameters Affecting the Session

The parameters in this section affect how the client's POE::Session
object will be created.

=head4 Alias

C<Alias> is an optional symbolic name for the client's Session.  It
allows other sessions to post events to the client, such as "shutdown"
and "reconnect".  The client itself may yield() these events, so an
alias isn't usually needed.

  Alias => "client",

=head4 Args

C<Args> is optional.  When specified, it holds an ARRAYREF that will
be passed to the C<Started> callback via @_[ARG0..$#_].  This allows a
program to pass extra information into the client session.

=head4 InlineStates

C<InlineStates> is optional.  If specified, it must hold a hashref of
named callbacks.  Its syntax is that of POE:Session->create()'s
inline_states parameter.

=head4 ObjectStates

If C<ObjectStates> is specified, it must holde an arrayref of objects
and the events they will handle.  The arrayref must follow the syntax
for POE::Session->create()'s object_states parameter.

=head4 PackageStates

When the optional C<PackageStates> is set, it must hold an arrayref of
package names and the events they will handle  The arrayref must
follow the syntax for POE::Session->create()'s package_states
parameter.

=head4 PreConnect

C<PreConnect> is called before C<Connected>, and it has different
parameters: $_[ARG0] contains a copy of the socket before it's given
to POE::Wheel::ReadWrite for management.  Most HEAP members are set,
except of course $_[HEAP]{server}, because the POE::Wheel::ReadWrite
object has not been created yet.  C<PreConnect> may enable SSL on the
socket using POE::Component::SSLify.  C<PreConnect> must return a
valid socket to complete the connection; the client will disconnect if
anything else is returned.

  PreConnect => {
    # Convert the socket into an SSL socket.
    my $socket = eval { Client_SSLify($_[ARG0]) };

    # Disconnect if SSL failed.
    return if $@;

    # Return the SSL-ified socket.
    return $socket;
  }

=head4 SessionType

Each client is created within its own Session.  C<SessionType> names
the class that will be used to create the session.

  SessionType => "POE::Session::MultiDispatch",

C<SessionType> is optional.  The component will use "POE::Session" by
default.

=head4 SessionParams

C<SessionParams> specifies additional parameters that will be passed
to the C<SessionType> constructor at creation time.  It must be an
array reference.

  SessionParams => [ options => { debug => 1, trace => 1 } ],

Note: POE::Component::Client::TCP supplies its own POE::Session
constructor parameters.  Conflicts between them and C<SessionParams>
may cause the component to behave erratically.  To avoid such
problems, please limit SessionParams to the C<options> hash.  See
L<POE::Session> for an known options.

We may enable other options later.  Please let us know if you need
something.

=head4 Started

C<Started> sets an optional callback that will be invoked within the
client session has been started.  The callback's parameters are the
usual for the session's _start handler.

C<Args> may be used to pass additional parameters to C<Started>.  This
can be used to bypass issues introduced by closures.  The values from
C<Args> will be included in the @_[ARG0..$#_] parameters.

  sub handle_started {
    my @args = @_[ARG0..$#_];
    # ...
  }

=head3 POE::Wheel::SocketFactory Constructor Parameters

The constructor parameters in this section affect how the client's
POE::Wheel::SocketFactory object will be created.

=head4 BindAddress

C<BindAddress> specifies the local interface address to bind to before
starting to connect.  This allows the client to connect from a
specific address when multiple interfaces are available.

C<BindAddress> is optional.  If specified, its value will be passed
directly to POE::Wheel::SocketFactory's BindAddress constructor
parameter.

=head4 BindPort

C<BindPort> sets the local socket port that the client will be bound
to before starting to connect.  This allows the client to connect from
a specific port.

It's not usually necessary to bind to a particular port, so
C<BindPort> is optional and disabled by default.

If specified, the value in C<BindPort> is passed directly to
POE::Wheel::SocketFactory's own BindPort constructor parameter.

=head4 ConnectError

C<ConnectError> is an optional callback to handle errors from
POE::Wheel::SocketFactory.  These errors happen when a socket can't be
created or has trouble connecting to the remote host.

The following parameters will be passed to the callback along with the
usual POE event parameters:  $_[ARG0] will describe what was happening
at the time of failure.  $_[ARG1] and $_[ARG2] will contain the
numeric and string versions of $!, respectively.

Depending on the nature of the error and the type of client, it may be
useful to reconnect from the ConnectError callback.

  ConnectError => sub {
    my ($operation, $error_number, $error_string) = @_[ARG0..ARG2];
    warn "$operation error $error_number occurred: $error_string";
    if (error_is_recoverable($error_number)) {
      $_[KERNEL]->delay( reconnect => 60 );
    }
    else {
      $_[KERNEL]->yield("shutdown");
    }
  },

POE::Component::Client::TCP will shut down after ConnectError if a
reconnect isn't requested.

=head4 Connected

Connections are asynchronously set up and may take some time to
complete.  C<Connected> is an optional callback that notifies a
program when the connection has finally been made.

This is an advisory callback that occurs after a POE::Wheel::ReadWrite
object has already been created.  Programs should not need to create
their own.

C<Connected> is called in response to POE::Wheel::SocketFactory's
SuccessEvent.  In addition to the usual POE event parameters, it
includes a copy of the established socket handle in  $_[ARG0].
POE::Component::Client::TCP will manage the socket, so an application
should rarely need to save a copy of it.  $_[ARG1] and $_[ARG2]
contain the remote address and port as returned from getpeername().

  Connected => {
    my ($socket, $peer_addr, $peer_port) = @_[ARG0, ARG1, ARG2];
    # ...
  }

See L</PreConnect> to modify the socket before it's given to
POE::Wheel::ReadWrite.

=head4 ConnectTimeout

C<ConnectTimeout> is the maximum number of seconds to wait for a
connection to be established.  If it is omitted, Client::TCP relies on
the operating system to abort stalled connect() calls.

The application will be notified of a timeout via the ConnectError
callback.  In the case of a timeout, $_[ARG0] will contain "connect",
and $_[ARG1] and $_[ARG2] will contain the numeric and string
representations of the ETIMEDOUT error.

=head4 Domain

C<Domain> sets the address or protocol family within which to operate.
The C<Domain> may be any value that POE::Wheel::SocketFactory
supports.  AF_INET (Internet address space) is used by default.

Use AF_INET6 for IPv6 support.  This constant is exported by Socket6,
which must be loaded B<before> POE::Component::Client::TCP.

=head4 RemoteAddress

C<RemoteAddress> contains the address of the server to connect to.  It
is required and may contain a host name ("poe.perl.org"), a dot- or
colon-separated numeric address (depending on the Domain), or a packed
socket address.  Pretty much anything POE::Wheel::SocketFactory's
RemoteAddress parameter does.

=head4 RemotePort

C<RemotePort> contains the port of the server to connect to.  It is
required and may be a service name ("echo") or number (7).


=head3 POE::Wheel::ReadWrite Constructor Parameters

Parameters in this section control configuration of the client's
POE::Wheel::ReadWrite object.

=head4 Disconnected

C<Disconnected> is an optional callback to notify a program that an
established socket has been disconnected.  It includes no special
parameters.

It may be useful to reconnect from the Disconnected callback, in the
case of MUD bots or long-running services.  For example:

  Disconnected => sub {
    $_[KERNEL]->delay( reconnect => 60 );
  },

The component will shut down if the connection ceases without being
reconnected.

=head4 Filter

C<Filter> specifies the type of POE::Filter object that will parse
input from and serialize output to a server.  It may either be a
scalar, an array reference, or a POE::Filter object.

If C<Filter> is a scalar, it will be expected to contain a POE::Filter
class name:

  Filter => "POE::Filter::Line",

C<Filter> is optional.  In most cases, the default "POE::Filter::Line"
is fine.

If C<Filter> is an array reference, the first item in the array will
be treated as a POE::Filter class name.  The remaining items will be
passed to the filter's constructor.  In this example, the vertical bar
will be used as POE::Filter::Line's record terminator:

  Filter => [ "POE::Filter::Line", Literal => "|" ],

If it is an object, it will be cloned every time the client connects:

  Filter => POE::Filter::Line->new(Literal => "|"),

Be sure to C<use> the appropriate POE::Filter subclass when specifying
a C<Filter> other than the default.

=head4 ServerError

C<ServerError> is an optional callback that will be invoked when an
established server connection has encountered some kind of error.  It
is triggered by POE::Wheel::ReadWrite's ErrorEvent.  By default, the
component will log any errors to STDERR.  This may be suppressed by
defining a quieter ServerError callback.

As with C<ConnectError>, it is invoked with the customary error
parameters:  $_[ARG0] will contain the name of the operation that
failed.  $_[ARG1] and $_[ARG2] will hold the numeric and string forms
of $!, respectively.

Components usually disconnect on error.  POE::Component::Client::TCP
will shut down if the socket disconnects without being reconnected.

=head4 ServerFlushed

C<ServerFlushed> is an optional callback to notify a program that
ReadWrite's output buffers have completely flushed.  It has no special
parameters.

The component will shut down after a server flush if $heap->{shutdown}
is set.

=head4 ServerInput

C<ServerInput> is a required callback.  It is called for each fully
parsed input record received by POE::Wheel::ReadWrite.  $_[ARG0]
contains the input record, the format of which is determined by the
C<Filter> constructor parameter.

C<SeverInput> will stop being called when $_[HEAP]{shutdown} is true.
The most reliable way to set the "shutdown" member is to call
$_[KERNEL]->yield("shutdown").

=head1 Public Events

POE::Component::Client::TCP handles a small number of public "command"
messages.  These may be posted into the client from an external
session, or yielded from within the client.

=head2 connect

The C<connect> event causes POE::Component::Client::TCP to begin
connecting to a server.  It optionally includes a new RemoteHost and
RemotePort, both of which will be used for subsequent reconnections.

  $_[KERNEL]->post(alias => connect => "127.0.0.1", 80);

If the client is already connected to a server, it will disconnect
immediately before beginning the new connection procedure.  Buffered
input and output will be lost.

=head2 reconnect

The C<reconnect> command causes POE::Component::Client::TCP to
immediately disconnect its current connection and begin reconnecting
to its most recently set RemoteHost and RemotePort.  Any buffered
input and output will be lost.

=head2 shutdown

The C<shutdown> command tells POE::Component::Client::TCP to flush its
buffers, disconnect, and begin DESTROY procedures.

All input will be discarded after receipt of "shutdown".  All pending
output will be written to the server socket before disconnecting and
destructing.

=head1 Reserved Heap Members

POE::Component::Client::TCP requires some heap space for its own
bookkeeping.  The following members are used and should be used as
directed, or with care.

This sample input handler is an example of most reserved heap members:

  sub handle_input {
    # Pending input from when we were connected.
    return unless $_[HEAP]{connected};

    # We've been shut down.
    return if $_[HEAP]{shutdown};

    my $input = $_[ARG0];
    $_[HEAP]{server}->put("you sent: $input");
  }

=head2 server

The read-only C<server> heap member contains the POE::Wheel object
used to connect to or talk with the server.  While the component is
connecting, C<server> will be a L<POE::Wheel::SocketFactory> object.  After
the connection has been made, C<server> is replaced with a
L<POE::Wheel::ReadWrite> object.

The most reliable way to avoid prematurely using C<server> is to first
check the C<connected> reserved heap member.  See the example above.

=head2 shutdown

C<shutdown> is a read-only flag that tells the component it's shutting
down.  It should only be by the C<shutdown> event, which does other
cleanup.

C<shutdown> may be checked to avoid starting new work during a
client's shutting-down procedure.  See the example above.

=head2 connected

C<connected> is a read-only flag that indicates whether the component
is currently connected.

=head2 shutdown_on_error

C<shutdown_on_error> is a read-only flag that governs the component's
shutdown-on-error behavior.  When true, POE::Component::Client::TCP
will automatically shutdown when it encounters an error.

=head1 SEE ALSO

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

L<POE::Component::Server::TCP> is the server-side counterpart to this
module.

This component uses and exposes features from L<POE::Filter>,
L<POE::Wheel::SocketFactory>, and L<POE::Wheel::ReadWrite>.

See L<POE::Wheel::SocketFactory/SYNOPSIS> for a more efficient but
lower-level way to create clients and servers.

=head1 CAVEATS

This looks nothing like what Ann envisioned.

POE::Component::Client::TCP is a generic client.  As such, it's not
tuned for any particular task.  While it handles the common cases well
and with a minimum of code, it may not be suitable for everything.

=head1 AUTHORS & COPYRIGHTS

POE::Component::Client::TCP is Copyright 2001-2009 by Rocco Caputo.
All rights are reserved.  POE::Component::Client::TCP is free
software, and it may be redistributed and/or modified under the same
terms as Perl itself.

POE::Component::Client::TCP is based on code, used with permission,
from Ann Barcomb E<lt>kudra@domaintje.comE<gt>.

POE::Component::Client::TCP is based on code, used with permission,
from Jos Boumans E<lt>kane@cpan.orgE<gt>.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
