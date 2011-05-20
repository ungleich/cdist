package POE::Component::Server::TCP;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw(carp croak);
use Socket qw(INADDR_ANY inet_ntoa inet_aton AF_INET AF_UNIX PF_UNIX);
use Errno qw(ECONNABORTED ECONNRESET);

# Explicit use to import the parameter constants.
use POE::Session;
use POE::Driver::SysRW;
use POE::Filter::Line;
use POE::Wheel::ReadWrite;
use POE::Wheel::SocketFactory;

sub DEBUG () { 0 }

# Create the server.  This is just a handy way to encapsulate
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

  # Extract parameters.
  my $alias   = delete $param{Alias};
  my $address = delete $param{Address};
  my $hname   = delete $param{Hostname};
  my $port    = delete $param{Port};
  my $domain  = delete($param{Domain}) || AF_INET;
  my $concurrency = delete $param{Concurrency};

  $port = 0 unless defined $port;

  foreach (
    qw(
      Acceptor Error ClientInput
      ClientPreConnect ClientConnected ClientDisconnected
      ClientError ClientFlushed
      ClientLow ClientHigh
    )
  ) {
    croak "$_ must be a coderef"
      if defined($param{$_}) and ref($param{$_}) ne 'CODE';
  }

  my $high_mark_level = delete $param{HighMark};
  my $low_mark_level  = delete $param{LowMark};
  my $high_event      = delete $param{ClientHigh};
  my $low_event       = delete $param{ClientLow};

  my $mark_param_count = (
    grep { defined $_ }
    ($high_mark_level, $low_mark_level, $high_event, $low_event)
  );
  if ($mark_param_count and $mark_param_count < 4) {
    croak "If you use the Mark settings, you must define all four";
  }

  $high_event = sub { } unless defined $high_event;
  $low_event  = sub { } unless defined $low_event;

  my $accept_callback = delete $param{Acceptor};
  my $error_callback  = delete $param{Error};

  my $client_input    = delete $param{ClientInput};

  # Acceptor and ClientInput are mutually exclusive.
  croak "$mi needs either an Acceptor or a ClientInput but not both"
    unless defined($accept_callback) xor defined($client_input);

  # Make sure ClientXyz are accompanied by ClientInput.
  unless (defined($client_input)) {
    foreach (grep /^Client/, keys %param) {
      croak "$_ not permitted without ClientInput";
    }
  }

  my $client_pre_connect  = delete $param{ClientPreConnect};
  my $client_connected    = delete $param{ClientConnected};
  my $client_disconnected = delete $param{ClientDisconnected};
  my $client_error        = delete $param{ClientError};
  my $client_filter       = delete $param{ClientFilter};
  my $client_infilter     = delete $param{ClientInputFilter};
  my $client_outfilter    = delete $param{ClientOutputFilter};
  my $client_flushed      = delete $param{ClientFlushed};
  my $session_type        = delete $param{SessionType};
  my $session_params      = delete $param{SessionParams};
  my $server_started      = delete $param{Started};
  my $listener_args       = delete $param{ListenerArgs};

  $listener_args = [] unless defined $listener_args;
  croak "ListenerArgs must be an array reference"
    unless ref($listener_args) eq 'ARRAY';

  if (exists $param{Args}) {
    if (exists $param{ClientArgs}) {
      carp "Args is deprecated, and ignored since ClientArgs is present";
      delete $param{Args};
    }
    else {
      carp "Args is deprecated but allowed for now.  Please use ClientArgs";
    }
  }

  my $client_args = delete($param{ClientArgs}) || delete($param{Args});

  # Defaults.

  $concurrency = -1 unless defined $concurrency;
  my $accept_session_id;

  if (!defined $address && defined $hname) {
    $address = inet_aton($hname);
  }
  $address = INADDR_ANY unless defined $address;

  $error_callback = \&_default_server_error unless defined $error_callback;

  $session_type = 'POE::Session' unless defined $session_type;
  if (defined($session_params) && ref($session_params)) {
    if (ref($session_params) ne 'ARRAY') {
      croak "SessionParams must be an array reference";
    }
  } else {
    $session_params = [ ];
  }

  if (defined $client_input) {
    $client_error  = \&_default_client_error unless defined $client_error;
    $client_args         = []     unless defined $client_args;

    # Extra states.

    my $inline_states = delete $param{InlineStates};
    $inline_states = {} unless defined $inline_states;

    my $package_states = delete $param{PackageStates};
    $package_states = [] unless defined $package_states;

    my $object_states = delete $param{ObjectStates};
    $object_states = [] unless defined $object_states;

    my $shutdown_on_error = 1;
    if (exists $param{ClientShutdownOnError}) {
      $shutdown_on_error = delete $param{ClientShutdownOnError};
    }

    croak "InlineStates must be a hash reference"
      unless ref($inline_states) eq 'HASH';

    croak "PackageStates must be a list or array reference"
      unless ref($package_states) eq 'ARRAY';

    croak "ObjectsStates must be a list or array reference"
      unless ref($object_states) eq 'ARRAY';

    croak "ClientArgs must be an array reference"
      unless ref($client_args) eq 'ARRAY';

    # Sanity check, thanks to crab@irc for making this mistake, ha!
    # TODO we could move this to POE::Session and make it a
    # "sanity checking" sub somehow...
    if (POE::Kernel::ASSERT_USAGE) {
      my %forbidden_handlers = (
        _child => 1,
        _start => 1,
        _stop => 1,
        shutdown => 1,
        tcp_server_got_error => 1,
        tcp_server_got_flush => 1,
        tcp_server_got_high => 1,
        tcp_server_got_input => 1,
        tcp_server_got_low => 1,
      );

      if (
        my @forbidden_inline_handlers = (
          grep { exists $inline_states->{$_} }
          keys %forbidden_handlers
        )
      ) {
        croak "These InlineStates aren't allowed: @forbidden_inline_handlers";
      }

      my %handlers = (
        PackageStates => $package_states,
        ObjectStates => $object_states,
      );

      while (my ($name, $states) = each(%handlers)) {
        my %states_hash = @$states;
        my @forbidden_handlers;
        while (my ($package, $handlers) = each %states_hash) {
          croak "Undefined $name member for $package" unless (
            defined $handlers
          );

          if (ref($handlers) eq 'HASH') {
            push(
              @forbidden_handlers,
              grep { exists $handlers->{$_} }
              keys %forbidden_handlers
            );
          }
          elsif (ref($handlers) eq 'ARRAY') {
            push(
              @forbidden_handlers,
              grep { exists $forbidden_handlers{$_} }
              @$handlers
            );
          }
          else {
            croak "Unknown $name member type for $package";
          }
        }

        croak "These $name aren't allowed: @forbidden_handlers" if (
          @forbidden_handlers
        );
      }
    }

    # Revise the acceptor callback so it spawns a session.

    unless (defined $accept_callback) {
      $accept_callback = sub {
        my ($socket, $remote_addr, $remote_port) = @_[ARG0, ARG1, ARG2];

        $session_type->create(
          @$session_params,
          inline_states => {
            _start => sub {
              my ( $kernel, $session, $heap ) = @_[KERNEL, SESSION, HEAP];

              $heap->{shutdown} = 0;
              $heap->{shutdown_on_error} = $shutdown_on_error;

              # Unofficial UNIX support, suggested by Damir Dzeko.
              # Real UNIX socket support should go into a separate
              # module, but if that module only differs by four
              # lines of code it would be bad to maintain two
              # modules for the price of one.  One solution would be
              # to pull most of this into a base class and derive
              # TCP and UNIX versions from that.
              if (
                $domain == AF_UNIX or $domain == PF_UNIX
              ) {
                $heap->{remote_ip} = "LOCAL";
              }
              elsif (length($remote_addr) == 4) {
                $heap->{remote_ip} = inet_ntoa($remote_addr);
              }
              else {
                $heap->{remote_ip} =
                  Socket6::inet_ntop($domain, $remote_addr);
              }

              $heap->{remote_port} = $remote_port;

              my $socket = $_[ARG0];
              if ($client_pre_connect) {
                $socket = $client_pre_connect->(@_);
                unless (fileno($socket)) {
                  # TODO - Error callback?  Disconnected callback?
                  # TODO - Should we do this before starting the child?
                  return;
                }
              }

              $heap->{client} = POE::Wheel::ReadWrite->new(
                Handle       => $socket,
                Driver       => POE::Driver::SysRW->new(),
                _get_filters(
                  $client_filter,
                  $client_infilter,
                  $client_outfilter
                ),
                InputEvent   => 'tcp_server_got_input',
                ErrorEvent   => 'tcp_server_got_error',
                FlushedEvent => 'tcp_server_got_flush',

                (
                  $mark_param_count
                  ? (
                    HighMark  => $high_mark_level,
                    HighEvent => 'tcp_server_got_high',
                    LowMark   => $low_mark_level,
                    LowEvent  => 'tcp_server_got_low',
                  )
                  : ()
                ),
              );

              # Expand the Args constructor array, and place a copy
              # into @_[ARG0..].  There are only 2 parameters.
              splice(@_, ARG0, 2, @{$_[ARG1]});

              $client_connected and $client_connected->(@_);
            },
            tcp_server_got_high => $high_event,
            tcp_server_got_low => $low_event,

            # To quiet ASSERT_STATES.
            _child  => sub { },

            tcp_server_got_input => sub {
              return if $_[HEAP]->{shutdown};
              $client_input->(@_);
              undef;
            },
            tcp_server_got_error => sub {
              DEBUG and warn(
                "$$: $alias child Error ARG0=$_[ARG0] ARG1=$_[ARG1]"
              );
              unless ($_[ARG0] eq 'accept' and $_[ARG1] == ECONNABORTED) {
                $client_error->(@_);
                if ($_[HEAP]->{shutdown_on_error}) {
                  $_[HEAP]->{got_an_error} = 1;
                  $_[KERNEL]->yield("shutdown");
                }
              }
            },
            tcp_server_got_flush => sub {
              my $heap = $_[HEAP];
              DEBUG and warn "$$: $alias child Flush";
              $client_flushed and $client_flushed->(@_);
              if ($heap->{shutdown}) {
                DEBUG and warn "$$: $alias child Flush, callback";
                $client_disconnected and $client_disconnected->(@_);
                delete $heap->{client};
              }
            },
            shutdown => sub {
              DEBUG and warn "$$: $alias child Shutdown";
              my $heap = $_[HEAP];
              $heap->{shutdown} = 1;
              if (defined $heap->{client}) {
                if (
                  $heap->{got_an_error} or
                  not $heap->{client}->get_driver_out_octets()
                ) {
                  DEBUG and warn "$$: $alias child Shutdown, callback";
                  $client_disconnected and $client_disconnected->(@_);
                  delete $heap->{client};
                }
              }
            },
            _stop => sub {
              ## concurrency on close
              DEBUG and warn(
                "$$: $alias _stop accept_session = $accept_session_id"
              );
              if( defined $accept_session_id ) {
                $_[KERNEL]->call( $accept_session_id, 'disconnected' );
              }
              else {
                # This means that the Server::TCP was shutdown before
                # this connection closed.  So it doesn't really matter that
                # we can't decrement the connection counter.
                DEBUG and warn(
                  "$$: $_[HEAP]->{alias} Disconnected from a connection ",
                  "without POE::Component::Server::TCP parent"
                );
              }
              return;
            },

            # User supplied states.
            %$inline_states
          },

          # More user supplied states.
          package_states => $package_states,
          object_states  => $object_states,

          # XXX - If you change the number of args here, also change
          # the splice elsewhere.
          args => [ $socket, $client_args ],
        );
      };
    }
  };

  # Complain about strange things we're given.
  foreach (sort keys %param) {
    carp "$mi doesn't recognize \"$_\" as a parameter";
  }

  ## verify concurrency on accept
  my $orig_accept_callback = $accept_callback;
  $accept_callback = sub {
    $_[HEAP]->{connections}++;
    DEBUG and warn(
      "$$: $_[HEAP]->{alias} Connection opened ",
      "($_[HEAP]->{connections} open)"
    );
    if( $_[HEAP]->{concurrency} != -1 and $_[HEAP]->{listener} ) {
      if( $_[HEAP]->{connections} >= $_[HEAP]->{concurrency} ) {
        DEBUG and warn(
          "$$: $_[HEAP]->{alias} Concurrent connection limit reached, ",
          "pausing accept"
        );
        $_[HEAP]->{listener}->pause_accept()
      }
    }
    $orig_accept_callback->(@_);
  };

  # Create the session, at long last.
  # This is done inline so that closures can customize it.
  # We save the accept session's ID to avoid self reference.

  $accept_session_id = $session_type->create(
    @$session_params,
    inline_states => {
      _start => sub {
        if (defined $alias) {
          $_[HEAP]->{alias} = $alias;
          $_[KERNEL]->alias_set( $alias );
        }

        $_[HEAP]->{concurrency} = $concurrency;
        $_[HEAP]->{connections} = 0;

        $_[HEAP]->{listener} = POE::Wheel::SocketFactory->new(
          ( ($domain == AF_UNIX or $domain == PF_UNIX)
            ? ()
            : ( BindPort => $port )
          ),
          BindAddress  => $address,
          SocketDomain => $domain,
          Reuse        => 'yes',
          SuccessEvent => 'tcp_server_got_connection',
          FailureEvent => 'tcp_server_got_error',
        );
        $server_started and $server_started->(@_);
      },
      # Catch an error.
      tcp_server_got_error => $error_callback,

      # We accepted a connection.  Do something with it.
      tcp_server_got_connection => $accept_callback,

      # conncurrency on close.
      disconnected => sub {
        $_[HEAP]->{connections}--;
        DEBUG and warn(
          "$$: $_[HEAP]->{alias} Connection closed ",
          "($_[HEAP]->{connections} open)"
        );
        if ($_[HEAP]->{connections} < 0) {
          warn(
            "Excessive 'disconnected' event ",
            "from $_[CALLER_FILE] at line $_[CALLER_LINE]\n"
          );
          $_[HEAP]->{connections} = 0;
        }
        if( $_[HEAP]->{concurrency} != -1 and $_[HEAP]->{listener} ) {
          if( $_[HEAP]->{connections} == ($_[HEAP]->{concurrency}-1) ) {
            DEBUG and warn(
              "$$: $_[HEAP]->{alias} Concurrent connection limit ",
              "reestablished, resuming accept"
            );
            $_[HEAP]->{listener}->resume_accept();
          }
        }
      },

      set_concurrency => sub {
        $_[HEAP]->{concurrency} = $_[ARG0];
        DEBUG and warn(
          "$$: $_[HEAP]->{alias} Concurrent connection ",
          "limit = $_[HEAP]->{concurrency}"
        );
        if( $_[HEAP]->{concurrency} != -1 and $_[HEAP]->{listener} ) {
          if( $_[HEAP]->{connections} >= $_[HEAP]->{concurrency} ) {
            DEBUG and warn(
              "$$: $_[HEAP]->{alias} Concurrent connection limit ",
              "reached, pausing accept"
            );
            $_[HEAP]->{listener}->pause_accept()
          }
          else {
            DEBUG and warn(
              "$$: $_[HEAP]->{alias} Concurrent connection limit ",
              "reestablished, resuming accept"
            );
            $_[HEAP]->{listener}->resume_accept();
          }
        }
      },

      # Shut down.
      shutdown => sub {
        delete $_[HEAP]->{listener};
        $_[KERNEL]->alias_remove( $_[HEAP]->{alias} )
          if defined $_[HEAP]->{alias};
      },

      # Dummy states to prevent warnings.
      _stop   => sub {
        DEBUG and warn "$$: $_[HEAP]->{alias} _stop";
        undef($accept_session_id);
        return 0;
      },
      _child  => sub { },
    },

    args => $listener_args,
  )->ID;

  # Return the session ID.
  return $accept_session_id;
}

sub _get_filters {
    my ($client_filter, $client_infilter, $client_outfilter) = @_;
    if (defined $client_infilter or defined $client_outfilter) {
      return (
        "InputFilter"  => _load_filter($client_infilter),
        "OutputFilter" => _load_filter($client_outfilter)
      );
      if (defined $client_filter) {
        carp(
          "ClientFilter ignored with ClientInputFilter or ClientOutputFilter"
        );
      }
    }
    elsif (defined $client_filter) {
     return ( "Filter" => _load_filter($client_filter) );
    }
    else {
      return ( Filter => POE::Filter::Line->new(), );
    }

}

# Get something: either arrayref, ref, or string
# Return filter
sub _load_filter {
    my $filter = shift;
    if (ref ($filter) eq 'ARRAY') {
        my @args = @$filter;
        $filter = shift @args;
        if ( _test_filter($filter) ){
            return $filter->new(@args);
        } else {
            return POE::Filter::Line->new(@args);
        }
    }
    elsif (ref $filter) {
        return $filter->clone();
    }
    else {
        if ( _test_filter($filter) ) {
            return $filter->new();
        } else {
            return POE::Filter::Line->new();
        }
    }
}

# Test if a Filter can be loaded, return success or failure
sub _test_filter {
    my $filter = shift;
    my $eval = eval {
        (my $mod = $filter) =~ s!::!/!g;
        require "$mod.pm";
        1;
    };
    if (!$eval and $@) {
        carp(
          "Failed to load [$filter]\n" .
          "Reason $@\nUsing default POE::Filter::Line "
        );
        return 0;
    }
    return 1;
}

# The default server error handler logs to STDERR and shuts down the
# server.

sub _default_server_error {
  warn("$$: ".
    'Server ', $_[SESSION]->ID,
    " got $_[ARG0] error $_[ARG1] ($_[ARG2])\n"
  );
  delete $_[HEAP]->{listener};
}

# The default client error handler logs to STDERR

sub _default_client_error {
  my ($syscall, $errno, $error) = @_[ARG0..ARG2];
  unless ($syscall eq "read" and ($errno == 0 or $errno == ECONNRESET)) {
    $error = "(no error)" unless $errno;
    warn("$$: ".
      'Client session ', $_[SESSION]->ID,
      " got $syscall error $errno ($error)\n"
    );
  }
}

1;

__END__

=head1 NAME

POE::Component::Server::TCP - a simplified TCP server

=head1 SYNOPSIS

  #!perl

  use warnings;
  use strict;

  use POE qw(Component::Server::TCP);

  POE::Component::Server::TCP->new(
    Port => 12345,
    ClientConnected => sub {
      print "got a connection from $_[HEAP]{remote_ip}\n";
      $_[HEAP]{client}->put("Smile from the server!");
    },
    ClientInput => sub {
      my $client_input = $_[ARG0];
      $client_input =~ tr[a-zA-Z][n-za-mN-ZA-M];
      $_[HEAP]{client}->put($client_input);
    },
  );

  POE::Kernel->run;
  exit;

=head1 DESCRIPTION

POE::Component::Server::TCP implements a generic multi-Session server.
Simple services may be put together in a few lines of code.  For
example, a server that echoes input back to the client:

  use POE qw(Component::Server::TCP);
  POE::Component::Server::TCP->new(
    Port => 12345,
    ClientInput => sub { $_[HEAP]{client}->put($_[ARG0]) },
  );
  POE::Kernel->run();

=head2 Accepting Connections Yourself

POE::Component::Server::TCP has a default mode where it accepts new
connections and creates the sessions to handle them.  Programs can do
this themselves by providing their own C<Acceptor> callbacks.  See
L</Acceptor> for details.

=head2 Master Listener Session

At creation time, POE::Component::Server::TCP starts one POE::Session
to listen for new connections.  The component's C<Alias> refers to
this master session.

If C<Acceptor> is specified, then it's up to that callback to deal
with newly accepted sockets.  Its parameters are that of
POE::Wheel::SocketFactory's C<SuccessEvent>.

Otherwise, the default C<Acceptor> callback will start a new session
to handle each connection.  These child sessions do not have their own
aliases, but their C<ClientConnected> and C<ClientDisconnected>
callbacks may be used to register and unregister the sessions with a
shared namespace, such as a hash keyed on session IDs, or an object
that manages such a hash.

  my %client_namespace;

  sub handle_client_connected {
    my $client_session_id = $_[SESSION]->ID;
    $client_namespace{$client_session_id} = \%anything;
  }

  sub handle_client_disconnected {
    my $client_session_id = $_[SESSION]->ID;
    $client_namespace{$client_session_id} = \%anything;
  }

The component's C<Started> callback is invoked at the end of the
master session's start-up routine.  The @_[ARG0..$#_] parameters are
set to a copy of the values in the server's C<ListenerArgs>
constructor parameter.  The other parameters are standard for
POE::Session's _start handlers.

The component's C<Error> callback is invoked when the server has a
problem listening for connections.  C<Error> may also be called if the
component's default acceptor has trouble accepting a connection.
C<Error> receives the usual ones for L<POE::Wheel::SocketFactory/FailureEvent> and
L<POE::Wheel::ReadWrite/ErrorEvent>.

=head2 Default Child Connection Sessions

If C<Acceptor> isn't specified, POE::Component::Server::TCP's default
handler will start a new session for each new client connection.  As
mentioned above, these child sessions have no aliases of their own,
but they may set aliases or register themselves another way during
their C<ClientConnected> and C<ClientDisconnected> callbacks.

It can't be stressed enough that the following callbacks are executed
within the context of dynamic child sessions---one per client
connection---and not in the master listening session.  This has been a
major point of confusion.  We welcome suggestions for making this
clearer.

TODO - Document some of the implications of having each connection
handled by a separate session.

The component's C<ClientInput> callback defines how child sessions
will handle input from their clients.  Its parameters are that of
POE::Wheel::ReadWrite's C<InputEvent>.

As mentioned C<ClientConnected> is called at the end of the child
session's C<_start> routine.  The C<ClientConneted> callback receives
the same parameters as the client session's _start does.  The arrayref
passed to the constructor's C<Args> parameter is flattened and
included in C<ClientConnected>'s parameters as @_[ARG0..$#_].

  sub handle_client_connected {
    my @constructor_args = @_[ARG0..$#_];
    ...
  }

C<ClientPreConnect> is called before C<ClientConnected>, and it has
different parameters: $_[ARG0] contains a copy of the client socket
before it's given to POE::Wheel::ReadWrite for management.  Most HEAP
members are set, except of course $_[HEAP]{client}, because the
POE::Wheel::ReadWrite has not yet been created yet.
C<ClientPreConnect> may enable SSL on the socket, using
POE::Component::SSLify.  C<ClientPreConnect> must return a valid
socket to complete the connection; the client will be disconnected if
anything else is returned.

  sub handle_client_pre_connect {

    # Make sure the remote address and port are valid.
    return undef unless validate(
      $_[HEAP]{remote_ip}, $_[HEAP]{remote_port}
    );

    # SSLify the socket, which is in $_[ARG0].
    my $socket = eval { Server_SSLify($_[ARG0]) };
    return undef if $@;

    # Return the SSL-ified socket.
    return $socket;
  }

C<ClientDisconnected> is called when the client has disconnected,
either because the remote socket endpoint has closed or the local
endpoint has been closed by the server.  This doesn't mean the
client's session has ended, but the session most likely will very
shortly.  C<ClientDisconnected> is called from a couple disparate
places within the component, so its parameters are neither consistent
nor generally useful.

C<ClientError> is called when an error has occurred on the socket.
Its parameters are those of POE::Wheel::ReadWrite's C<ErrorEvent>.

C<ClientFlushed> is called when all pending output has been flushed to
the client socket.  Its parameters come from POE::Wheel::ReadWrite's
C<ErrorEvent>.

=head2 Performance Considerations

This ease of use comes at a price: POE::Component::Server::TCP often
performs significantly slower than a comparable server written with
POE::Wheel::SocketFactory and POE::Wheel::ReadWrite.

If performance is your primary goal, POE::Kernel's select_read() and
select_write() perform about the same as IO::Select, but your code
will be portable across every event loop POE supports.

=head2 Special Needs Considerations

POE::Component::Server::TCP is written to be easy for the most common
use cases.  Programs with more special needs should consider using
POE::Wheel::SocketFactory and POE::Wheel::ReadWrite instead.  These
are lower-level modules, and using them requires more effort.  They
are more flexible and customizable, however.

=head1 PUBLIC METHODS

=head2 new

new() starts a server based on POE::Component::Server::TCP and returns
a session ID for the master listening session.  All error handling is
done within the server, via the C<Error> and C<ClientError> callbacks.

The server may be shut down by posting a "shutdown" event to the
master session, either by its ID or the name given to it by the
C<Alias> parameter.

POE::Component::Server::TCP does a lot of work in its constructor.
The design goal is to push as much overhead into one-time construction
so that ongoing run-time has less overhead.  Because of this, the
server's constructor can take quite a daunting number of parameters.

POE::Component::Server::TCP always returns a POE::Session ID for the
session that will be listening for new connections.

Many of the constructor parameters have been previously described.
They are covered briefly again below.

=head3 Server Sesson Configuration

These constructor parameters affect POE::Component::Server::TCP's main
listening session.

TODO - Document the shutdown procedure somewhere.

=head4 Acceptor

C<Acceptor> defines a CODE reference that POE::Wheel::SocketFactory's
C<SuccessEvent> will trigger to handle new connections.  Therefore the
parameters passed to C<Acceptor> are identical to those given to
C<SuccessEvent>.

C<Acceptor> is optional; the default handler will create a new session
for each connection.  All the "Client" constructor parameters are used
to customize this session.  In other words, C<CleintInput> and such
B<are not used when C<Acceptor> is set>.

The default C<Acceptor> adds significant convenience and flexibility
to POE::Component::Server::TCP, but it's not always a good fit for
every application.  In some cases, a custom C<Acceptor> or even
rolling one's own server with POE::Wheel::SocketFactory and
POE::Wheel::ReadWrite may be better and/or faster.

  Acceptor => sub {
    my ($socket, $remote_address, $remote_port) = @_[ARG0..ARG2];
    # Set up something to interact with the client.
  }

=head4 Address

C<Address> defines a single interface address the server will bind to.
It defaults to INADDR_ANY or INADDR6_ANY, when using IPv4 or IPv6,
respectively.  It is often used with C<Port>.

The value in C<Address> is passed to POE::Wheel::SocketFactory's
C<BindAddress> parameter, so it may be in whatever form that module
supports.  At the time of this writing, that may be a dotted IPv4
quad, an IPv6 address, a host name, or a packed Internet address.  See
also L</Hostname>.

TODO - Example, using the lines below.

  Address => '127.0.0.1'   # Localhost IPv4
  Address => "::1"         # Localhost IPv6

=head4 Alias

C<Alias> is an optional name that will be given to the server's master
listening session.  Events sent to this name will not be delivered to
individual connections.

The server's C<Alias> may be important if it's necessary to shut a
server down.

  sub sigusr1_handler {
    $_[KERNEL]->post(chargen_server => 'shutdown');
    $_[KERNEL]->sig_handled();
  }

=head4 Concurrency

C<Concurrency> controls how many connections may be active at the same
time.  It defaults to -1, which allows POE::Component::Server::TCP to
accept concurrent connections until the process runs out of resources.

Setting C<Concurrency> to 0 prevents the server from accepting new
connections.  This may be useful if a server must perform lengthy
initialization before allowing connections.  When the initialization
finishes, it can yield(set_concurrency => -1) to enable connections.
Likewise, a running server may yield(set_concurrency => 0) or any
other number to dynamically tune its concurrency.  See L</EVENTS> for
more about the set_concurrency event.

Note: For C<Concurrency> to work with a custom C<Acceptor>, the
server's listening session must receive a C<disconnected> event
whenever clients disconnect.  Otherwise the listener cannot mediate
between its connections.

Example:

  Acceptor => sub {
    # ....
    POE::Session->create(
      # ....
      inline_states => {
        _start => sub {
          # ....
          # remember who our parent is
          $_[HEAP]->{server_tcp} = $_[SENDER]->ID;
          # ....
        },
        got_client_disconnect => sub {
          # ....
          $_[KERNEL]->post( $_[HEAP]->{server_tcp} => 'disconnected' );
          # ....
        }
      }
    );
  }


=head4 Domain

C<Domain> sets the address or protocol family within which to operate.
The C<Domain> may be any value that POE::Wheel::SocketFactory
supports.  AF_INET (Internet address space) is used by default.

Use AF_INET6 for IPv6 support.  This constant is exported by Socket6,
which must be loaded B<before> POE::Component::Server::TCP.

=head4 Error

C<Error> is the callback that will be invoked when the server socket
reports an error.  The Error callback will be used to handle
POE::Wheel::SocketFactory's FailureEvent, so it will receive the same
parameters as discussed there.

A default error handler will be provided if Error is omitted.  The
default handler will log the error to STDERR and shut down the server.
Active connections will be permitted to to complete their
transactions.

  Error => sub {
    my ($syscall_name, $err_num, $err_str) = @_[ARG0..ARG2];
    # Handle the error.
  }

=head4 Hostname

C<Hostname> is the optional non-packed name of the interface the TCP
server will bind to.  The hostname will always be resolved via
inet_aton() and so can either be a dotted quad or a name.  Name
resolution is a one-time start-up action; there are no ongoing
run-time penalties for using it.

C<Hostname> guarantees name resolution, where C<Address> does not.
It's therefore preferred to use C<Hostname> in cases where resolution
must always be done.

=head4 InlineStates

C<InlineStates> is optional.  If specified, it must hold a hashref of
named callbacks.  Its syntax is that of POE:Session->create()'s
inline_states parameter.

Remember: These InlineStates handlers will be added to the client
sessions, not to the main listening session.  A yield() in the listener
will not reach these handlers.

If POE::Kernel::ASSERT_USAGE is enabled, the constructor will croak() if it
detects a state that it uses internally. For example, please use the "Started"
callback if you want to specify your own "_start" event.

=head4 ObjectStates

If C<ObjectStates> is specified, it must holde an arrayref of objects
and the events they will handle.  The arrayref must follow the syntax
for POE::Session->create()'s object_states parameter.

Remember: These ObjectStates handlers will be added to the client 
sessions, not to the main listening session.  A yield() in the listener
will not reach these handlers.

If POE::Kernel::ASSERT_USAGE is enabled, the constructor will croak() if it
detects a state that it uses internally. For example, please use the "Started"
callback if you want to specify your own "_start" event.

=head4 PackageStates

When the optional C<PackageStates> is set, it must hold an arrayref of
package names and the events they will handle  The arrayref must
follow the syntax for POE::Session->create()'s package_states
parameter.

Remember: These PackageStates handlers will be added to the client 
sessions, not to the main listening session.  A yield() in the listener
will not reach these handlers.

If POE::Kernel::ASSERT_USAGE is enabled, the constructor will croak() if it
detects a state that it uses internally. For example, please use the "Started"
callback if you want to specify your own "_start" event.

=head4 Port

C<Port> contains the port the listening socket will be bound to.  It
defaults to 0, which usually lets the operating system pick a
port at random.

  Port => 30023

It is often used with C<Address>.

=head4 Started

C<Started> sets an optional callback that will be invoked within the
main server session's context.  It notifies the server that it has
fully started.  The callback's parameters are the usual for a
session's _start handler.

=head4 ListenerArgs

C<ListenerArgs> is passed to the listener session as the C<args> parameter.  In
other words, it must be an arrayref, and the values are are passed into the
C<Started> handler as ARG0, ARG1, etc.

=head3 Connection Session Configuration

These constructor parameters affect the individual sessions that
interact with established connections.

=head4 ClientArgs

C<ClientArgs> is optional.  When specified, it holds an ARRAYREF that
will be expanded one level and passed to the C<ClientConnected>
callback in @_[ARG0..$#_].

=head4 ClientConnected

Each new client connection is handled by a new POE::Session instance.
C<ClientConnected> is a callback that notifies the application when a
client's session is started and ready for operation.  Banners are
often sent to the remote client from this callback.

The @_[ARG0..$#_] parameters to C<ClientConnected> are a copy of the
values in the C<ClientArgs> constructor parameter's array reference.
The other @_ members are standard for a POE::Session _start handler.

C<ClientConnected> is called once per session start-up.  It will never
be called twice for the same connection.

  ClientConnected => sub {
    $_[HEAP]{client}->put("Hello, client!");
    # Other client initialization here.
  },

=head4 ClientDisconnected

C<ClientDisconnected> is a callback that will be invoked when the
client disconnects or has been disconnected by the server.  It's
useful for cleaning up global client information, such as chat room
structures.  C<ClientDisconnected> callbacks receive the usual POE
parameters, but nothing special is included.

  ClientDisconnected => sub {
    warn "Client disconnected"; # log it
  }

=head4 ClientError

The C<ClientError> callback is invoked when a client socket reports an
error.  C<ClientError> is called with POE's usual parameters, plus the
common error parameters: $_[ARG0] describes what was happening at the
time of failure.  $_[ARG1] and $_[ARG2] contain the numeric and string
versions of $!, respectively.

C<ClientError> is optional.  If omitted, POE::Component::Server::TCP
will provide a default callback that logs most errors to STDERR.

If C<ClientShutdownOnError> is set, the connection will be shut down
after C<ClientError> returns.  If C<ClientDisconnected> is specified,
it will be called as the client session is cleaned up.

C<ClientError> is triggered by POE::Wheel::ReadWrite's ErrorEvent, so
it follows that event's form.  Please see the ErrorEvent documentation
in POE::Wheel::ReadWrite for more details.

  ClientError => sub {
    my ($syscall_name, $error_num, $error_str) = @_[ARG0..ARG2];
    # Handle the client error here.
  }

=head4 ClientFilter

C<ClientFilter> specifies the POE::Filter object or class that will
parse input from each client and serialize output before it's sent to
each client.

C<ClientFilter> may be a SCALAR, in which case it should name the
POE::Filter class to use.  Each new connection will be given a freshly
instantiated filter of that class.  No constructor parameters will be
passed.

  ClientFilter => "POE::Filter::Stream",

Some filters require constructor parameters.  These may be specified
by an ARRAYREF.  The first element is the POE::Filter class name, and
subsequent elements are passed to the class' constructor.

  ClientFilter => [ "POE::Filter::Line", Literal => "\n" ],

C<ClientFilter> may also be given an archetypical POE::Filter OBJECT.
In this case, each new client session will receive a clone() of the
given object.

  ClientFilter => POE::Filter::Line->new(Literal => "\n"),

C<ClientFilter> is optional.  The component will use
"POE::Filter::Line" if it is omitted.

Filter modules are not automatically loaded.  Be sure that the program
loads the class before using it.

=head4 ClientFlushed

C<ClientFlushed> exposes POE::Wheel::ReadWrite's C<FlushedEvent> as a
callback.  It is called whenever the client's output buffer has been
fully flushed to the client socket.  At this point it's safe to shut
down the socket without losing data.

C<ClientFlushed> is useful for streaming servers, where a "flushed"
event signals the need to send more data.

  ClientFlushed => sub {
    my $data_source = $_[HEAP]{file_handle};
    my $read_count = sysread($data_source, my $buffer = "", 65536);
    if ($read_count) {
      $_[HEAP]{client}->put($buffer);
    }
    else {
      $_[KERNEL]->yield("shutdown");
    }
  },

POE::Component::Server::TCP's default C<Acceptor> ensures that data is
flushed before finishing a client shutdown.

=head4 ClientInput

C<ClientInput> defines a per-connection callback to handle client
input.  This callback receives its parameters directly from
POE::Wheel::ReadWrite's C<InputEvent>.  ARG0 contains the input
record, the format of which is defined by C<ClientFilter> or
C<ClientInputFilter>.  ARG1 has the wheel's unique ID, and so on.
Please see POE:Wheel::ReadWrite for an in-depth description of
C<InputEvent>.

C<ClientInput> and C<Acceptor> are mutually exclusive.  Enabling one
prohibits the other.

  ClientInput => sub {
    my $input = $_[ARG0];
    $_[HEAP]{wheel}->put("You said: $input");
  },

=head4 ClientInputFilter

C<ClientInputFilter> is used with C<ClientOutputFilter> to specify
different protocols for input and output.  Both must be used together.
Both follow the same usage as L</ClientFilter>.

  ClientInputFilter  => [ "POE::Filter::Line", Literal => "\n" ],
  ClientOutputFilter => 'POE::Filter::Stream',

=head4 ClientOutputFilter

C<ClientOutputFilter> is used with C<ClientInputFilter> to specify
different protocols for input and output.  Both must be used together.
Both follow the same usage as L</ClientFilter>.

  ClientInputFilter  => POE::Filter::Line->new(Literal => "\n"),
  ClientOutputFilter => 'POE::Filter::Stream',

=head4 ClientShutdownOnError

C<ClientShutdownOnError> tells the component whether client
connections should be shut down automatically if an error is detected.
It defaults to "true".  Setting it to false (0, undef, "") turns off
this feature.

The application is responsible for dealing with client errors if this
feature is disabled.  Not doing so may cause the component to emit a
constant stream of errors, eventually bogging down the application
with dead connections that spin out of control.

Yes, this is terrible.  You have been warned.

=head4 SessionParams

C<SessionParams> specifies additional parameters that will be passed
to the C<SessionType> constructor at creation time.  It must be an
array reference.

  SessionParams => [ options => { debug => 1, trace => 1 } ],

Note: POE::Component::Server::TCP supplies its own POE::Session
constructor parameters.  Conflicts between them and C<SessionParams>
may cause the component to behave erratically.  To avoid such
problems, please limit SessionParams to the C<options> hash.  See
L<POE::Session> for an known options.

We may enable other options later.  Please let us know if you need
something.

=head4 SessionType

C<SessionType> specifies the POE::Session subclass that will be
created for each new client connection.  "POE::Session" is the
default.

  SessionType => "POE::Session::MultiDispatch"

=head1 EVENTS

It's possible to manipulate a TCP server component by sending it
messages.

=head2 Main Server Commands

These events must be sent to the main server, usually by the alias set
in its L<Alias> parameter.

=head3 disconnected

The "disconnected" event informs the TCP server that a connection was
closed.  It is needed when using L</Concurrency> with an L</Acceptor>
callback.  The custom Acceptor must provide its own disconnect
notification so that the server's connection counting logic works.

Otherwise Concurrency clients will be accepted, and then no more.  The
server will never know when clients have disconnected.

=head3 set_concurrency

"set_concurrency" set the number of simultaneous connections the
server will be willing to accept.  See L</Concurrency> for more
details.  "set_concurrency" must have one parameter: the new maximum
connection count.

  $kernel->call("my_server_alias", "set_concurrency", $max_count);

=head3 shutdown

The "shutdown" event starts a graceful server shutdown.  No new
connections will be accepted.  Existing connections will be allowed to
finish.  The server will be destroyed after the last connection ends.

=head2 Per-Connection Commands

These commands affect each client connection session.

=head3 shutdown

Sending "shutdown" to an individual client session instructs the
server to gracefully shut down that connection.  No new input will be
received, and any buffered output will be sent before the session
ends.

Client sessions usually yield("shutdown") when they wish to disconnect
the client.

  ClientInput => sub {
    if ($_[ARG0] eq "quit") {
      $_[HEAP]{client}->put("B'bye!");
      $_[KERNEL]->yield("shutdown");
      return;
    }

    # Handle other input here.
  },

=head1 Reserved HEAP Members

Unlike most POE modules, POE::Component::Server::TCP stores data in
the client sessions' HEAPs.  These values are provided as conveniences
for application developers.

=head2 HEAP Members for Master Listening Sessions

The master listening session holds different data than client
connections.

=head3 alias

$_[HEAP]{alias} contains the server's Alias.

=head3 concurrency

$_[HEAP]{concurrency} remembers the server's C<Concurrency> parameter.

=head3 connections

$_[HEAP]{connections} is used to track the current number of
concurrent client connections.  It's incremented whenever a new
connection is accepted, and it's decremented whenever a client
disconnects.

=head3 listener

$_[HEAP]{listener} contains the POE::Wheel::SocketFactory object used
to listen for connections and accept them.

=head2 HEAP Members for Connection Sessions

These data members exist within the individual connections' sessions.

=head3 client

$_[HEAP]{client} contains a POE::Wheel::ReadWrite object used to
interact with the client.  All POE::Wheel::ReadWrite methods work.

=head3 got_an_error

$_[HEAP]{got_an_error} remembers whether the client connection has
already encountered an error.  It is part of the shutdown-on-error
procedure.

=head3 remote_ip

$_[HEAP]{remote_ip} contains the remote client's numeric address in
human-readable form.

=head3 remote_port

$_[HEAP]{remote_port} contains the remote client's numeric socket port
in human-readable form.

=head3 remote_addr

$_[HEAP]{remote_addr} contains the remote client's packed socket
address in computer-readable form.

=head3 shutdown

$_[HEAP]{shutdown} is true if the client is in the process of shutting
down.  The component uses it to ignore client input during shutdown,
and to close the connection after pending output has been flushed.

=head3 shutdown_on_error

$_[HEAP]{shutdown_on_error} remembers whether the client connection
should automatically shut down if an error occurs.

=head1 SEE ALSO

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

L<POE::Component::Client::TCP> is the client-side counterpart to this
module.

This component uses and exposes features from L<POE::Filter>,
L<POE::Wheel::SocketFactory>, and L<POE::Wheel::ReadWrite>.

=head1 BUGS

This looks nothing like what Ann envisioned.

This component currently does not accept many of the options that
POE::Wheel::SocketFactory does.

This component will not bind to several addresses at once.  This may
be a limitation in SocketFactory, but it's not by design.

This component needs better error handling.

Some use cases require different session classes for the listener and
the connection handlers.  This isn't currently supported.  Please send
patches. :)

TODO - Document that Reuse is set implicitly.

=head1 AUTHORS & COPYRIGHTS

POE::Component::Server::TCP is Copyright 2000-2009 by Rocco Caputo.
All rights are reserved.  POE::Component::Server::TCP is free
software, and it may be redistributed and/or modified under the same
terms as Perl itself.

POE::Component::Server::TCP is based on code, used with permission,
from Ann Barcomb E<lt>kudra@domaintje.comE<gt>.

POE::Component::Server::TCP is based on code, used with permission,
from Jos Boumans E<lt>kane@cpan.orgE<gt>.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
