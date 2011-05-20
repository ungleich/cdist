package POE::Component::Client::Keepalive;

use warnings;
use strict;

use vars qw($VERSION);
$VERSION = "0.263";

use Carp qw(croak);
use Errno qw(ETIMEDOUT EBADF);
use Socket qw(SOL_SOCKET SO_LINGER);

use POE;
use POE::Wheel::SocketFactory;
use POE::Component::Connection::Keepalive;
use POE::Component::Client::DNS;
use Net::IP qw(ip_is_ipv4);

my $ssl_available;
eval {
  require POE::Component::SSLify;
  $ssl_available = 1;
};

use constant DEBUG => 0;
use constant DEBUG_DNS => DEBUG || 0;
use constant DEBUG_DEALLOCATE => DEBUG || 0;

# Manage connection request IDs.

my $current_id = 0;
my %active_req_ids;

sub _allocate_req_id {
  while (1) {
    last unless exists $active_req_ids{++$current_id};
  }
  return $active_req_ids{$current_id} = $current_id;
}

sub _free_req_id {
  my $id = shift;
  delete $active_req_ids{$id};
}

# The connection manager uses a number of data structures, most of
# them arrays.  These constants define offsets into those arrays, and
# the comments document them.

                             # @$self = (
sub SF_POOL      () {  0 }   #   \%socket_pool,
sub SF_QUEUE     () {  1 }   #   \@request_queue,
sub SF_USED      () {  2 }   #   \%sockets_in_use,
sub SF_WHEELS    () {  3 }   #   \%wheels_by_id,
sub SF_USED_EACH () {  4 }   #   \%count_by_triple,
sub SF_MAX_OPEN  () {  5 }   #   $max_open_count,
sub SF_MAX_HOST  () {  6 }   #   $max_per_host,
sub SF_SOCKETS   () {  7 }   #   \%socket_xref,
sub SF_KEEPALIVE () {  8 }   #   $keep_alive_secs,
sub SF_TIMEOUT   () {  9 }   #   $default_request_timeout,
sub SF_RESOLVER  () { 10 }   #   $poco_client_dns_object,
sub SF_SHUTDOWN  () { 11 }   #   $shutdown_flag,
sub SF_REQ_INDEX () { 12 }   #   \%request_id_to_wheel_id,
sub SF_BIND_ADDR () { 13 }   #   $bind_address,
                             # );

                            # $socket_xref{$socket} = [
sub SK_KEY       () { 0 }   #   $conn_key,
sub SK_TIMER     () { 1 }   #   $idle_timer,
                            # ];

                            # $count_by_triple{$conn_key} = # $conn_count;

                            # $wheels_by_id{$wheel_id} = [
sub WHEEL_WHEEL   () { 0 }  #   $wheel_object,
sub WHEEL_REQUEST () { 1 }  #   $request,
                            # ];

                            # $socket_pool{$conn_key}{$socket} = $socket;

                            # $sockets_in_use{$socket} = (
sub USED_SOCKET () { 0 }    #   $socket_handle,
sub USED_TIME   () { 1 }    #   $allocation_time,
sub USED_KEY    () { 2 }    #   $conn_key,
                            # );

                            # @request_queue = (
                            #   $request,
                            #   $request,
                            #   ....
                            # );

                            # $request = [
sub RQ_SESSION  () {  0 }   #   $request_session,
sub RQ_EVENT    () {  1 }   #   $request_event,
sub RQ_SCHEME   () {  2 }   #   $request_scheme,
sub RQ_ADDRESS  () {  3 }   #   $request_address,
sub RQ_IP       () {  4 }   #   $request_ip,
sub RQ_PORT     () {  5 }   #   $request_port,
sub RQ_CONN_KEY () {  6 }   #   $request_connection_key,
sub RQ_CONTEXT  () {  7 }   #   $request_context,
sub RQ_TIMEOUT  () {  8 }   #   $request_timeout,
sub RQ_START    () {  9 }   #   $request_start_time,
sub RQ_TIMER_ID () { 10 }   #   $request_timer_id,
sub RQ_WHEEL_ID () { 11 }   #   $request_wheel_id,
sub RQ_ACTIVE   () { 12 }   #   $request_is_active,
sub RQ_ID       () { 13 }   #   $request_id,
                            # ];

# Create a connection manager.

sub new {
  my $class = shift;
  croak "new() needs an even number of parameters" if @_ % 2;
  my %args = @_;

  my $max_per_host = delete($args{max_per_host}) || 4;
  my $max_open     = delete($args{max_open})     || 128;
  my $keep_alive   = delete($args{keep_alive})   || 15;
  my $timeout      = delete($args{timeout})      || 120;
  my $resolver     = delete($args{resolver});
  my $bind_address = delete($args{bind_address}) || "0.0.0.0";

  my @unknown = sort keys %args;
  if (@unknown) {
    croak "new() doesn't accept: @unknown";
  }

  my $self = bless [
    { },                # SF_POOL
    [ ],                # SF_QUEUE
    { },                # SF_USED
    { },                # SF_WHEELS
    { },                # SF_USED_EACH
    $max_open,          # SF_MAX_OPEN
    $max_per_host,      # SF_MAX_HOST
    { },                # SF_SOCKETS
    $keep_alive,        # SF_KEEPALIVE
    $timeout,           # SF_TIMEOUT
    undef,              # SF_RESOLVER
    undef,              # SF_SHUTDOWN
    undef,              # SF_REQ_INDEX
    $bind_address,      # SF_BIND_ADDR
  ], $class;

  unless (defined $resolver) {
    $resolver = POE::Component::Client::DNS->spawn (
      Alias => "$self\_resolver",
    );
  }
  $self->[SF_RESOLVER] = $resolver;

  POE::Session->create(
    object_states => [
      $self => {
        _start               => "_ka_initialize",
        _stop                => "_ka_stopped",
        ka_add_to_queue      => "_ka_add_to_queue",
        ka_cancel_dns_response => "_ka_cancel_dns_response",
        ka_conn_failure      => "_ka_conn_failure",
        ka_conn_success      => "_ka_conn_success",
        ka_deallocate        => "_ka_deallocate",
        ka_dns_response      => "_ka_dns_response",
        ka_keepalive_timeout => "_ka_keepalive_timeout",
        ka_reclaim_socket    => "_ka_reclaim_socket",
        ka_relinquish_socket => "_ka_relinquish_socket",
        ka_request_timeout   => "_ka_request_timeout",
        ka_resolve_request   => "_ka_resolve_request",
        ka_set_timeout       => "_ka_set_timeout",
        ka_shutdown          => "_ka_shutdown",
        ka_socket_activity   => "_ka_socket_activity",
        ka_wake_up           => "_ka_wake_up",
      },
    ],
  );

  return $self;
}

# Initialize the hidden session behind this component.
# Set an alias so the public methods can send it messages easily.

sub _ka_initialize {
  my ($object, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  $heap->{resolve} = { };
  $kernel->alias_set("$object");
}

# When programs crash, the session may stop in a non-shutdown state.
# _ka_stopped and DESTROY catch this either way the death occurs.

sub _ka_stopped {
  $_[OBJECT][SF_SHUTDOWN] = 1;
}

sub DESTROY {
  my $self = shift;
  $self->shutdown();
}

# Request to wake up.  This should only happen during the edge
# condition where the component's request queue goes from empty to
# having one item.
#
# It also happens during free(), to see if there are more sockets to
# deal with.
#
# TODO - Make the _ka_wake_up stuff smart enough not to post duplicate
# messages to the queue.

sub _ka_wake_up {
  my ($self, $kernel) = @_[OBJECT, KERNEL];

  # Scan the list of requests, until we find one that can be met.
  # Fire off POE::Wheel::SocketFactory to begin the connection
  # process.

  my $request_index  = 0;
  my $currently_open = keys(%{$self->[SF_USED]}) + keys(%{$self->[SF_SOCKETS]});
  my @splice_list;

  QUEUED:
  foreach my $request (@{$self->[SF_QUEUE]}) {
    DEBUG and warn "WAKEUP: checking for $request->[RQ_CONN_KEY]";

    # Sweep away inactive requests.

    unless ($request->[RQ_ACTIVE]) {
      push @splice_list, $request_index;
      next;
    }

    # Skip this request if its scheme/address/port triple is maxed
    # out.

    my $req_key = $request->[RQ_CONN_KEY];
    next if (
      ($self->[SF_USED_EACH]{$req_key} || 0) >= $self->[SF_MAX_HOST]
    );

    # Honor the request from the free pool, if possible.  The
    # currently open socket count does not increase.

    my $existing_connection = $self->_check_free_pool($req_key);
    if ($existing_connection) {
      push @splice_list, $request_index;

      _respond(
        $request, {
          connection => $existing_connection,
          from_cache => "deferred",
        }
      );

      # Remove the wheel-to-request index.
      delete $self->[SF_REQ_INDEX]{$request->[RQ_ID]};
      _free_req_id($request->[RQ_ID]);

      next;
    }

    # we can't easily take this out of the outer loop since _check_free_pool
    # can change it from under us
    my @free_sockets   = keys(%{$self->[SF_SOCKETS]});

    # Try to free over-committed (but unused) sockets until we're back
    # under SF_MAX_OPEN sockets.  Bail out if we can't free enough.
    # TODO - Consider removing @free_sockets in least- to
    # most-recently used order.
    while ($currently_open >= $self->[SF_MAX_OPEN]) {
      last QUEUED unless @free_sockets;
      my $next_to_go = $free_sockets[rand(@free_sockets)];
      $self->_remove_socket_from_pool($next_to_go);
      $currently_open--;
    }

    # Start the request.  Create a wheel to begin the connection.
    # Move the wheel and its request into SF_WHEELS.
    DEBUG and warn "WAKEUP: creating wheel for $req_key";

    # TODO - Set the SocketDomain to AF_INET6 if $addr =~ /:/?
    my $addr = ($request->[RQ_IP] or $request->[RQ_ADDRESS]);
    my $wheel = POE::Wheel::SocketFactory->new(
      BindAddress   => $self->[SF_BIND_ADDR],
      RemoteAddress => $addr,
      RemotePort    => $request->[RQ_PORT],
      SuccessEvent  => "ka_conn_success",
      FailureEvent  => "ka_conn_failure",
    );

    $self->[SF_WHEELS]{$wheel->ID} = [
      $wheel,     # WHEEL_WHEEL
      $request,   # WHEEL_REQUEST
    ];

    # store the wheel's ID in the request object
    $request->[RQ_WHEEL_ID] = $wheel->ID;

    # Count it as used, so we don't over commit file handles.
    $currently_open++;
    $self->[SF_USED_EACH]{$req_key}++;

    # Temporarily store the SF_USED record under the wheel ID.  It
    # will be moved to the socket when the wheel responds.
    $self->[SF_USED]{$wheel->ID} = [
      undef,     # USED_SOCKET
      time(),    # USED_TIME
      $req_key,  # USED_KEY
    ];

    # Mark the request index as one to splice out.

    push @splice_list, $request_index;
  }
  continue {
    $request_index++;
  }

  # The @splice_list is a list of element indices that need to be
  # spliced out of the request queue.  We scan in backwards, from
  # highest index to lowest, so that each splice does not affect the
  # indices of the other.
  #
  # This removes the request from the queue.  It's vastly important
  # that the request be entered into SF_WHEELS before now.

  my $splice_index = @splice_list;
  while ($splice_index--) {
    splice @{$self->[SF_QUEUE]}, $splice_list[$splice_index], 1;
  }
}

sub allocate {
  my $self = shift;
  croak "allocate() needs an even number of parameters" if @_ % 2;
  my %args = @_;

  # TODO - Validate arguments.

  my $scheme  = delete $args{scheme};
  croak "allocate() needs a 'scheme'"  unless $scheme;
  my $address = delete $args{addr};
  croak "allocate() needs an 'addr'"   unless $address;
  my $port    = delete $args{port};
  croak "allocate() needs a 'port'"    unless $port;
  my $event   = delete $args{event};
  croak "allocate() needs an 'event'"  unless $event;
  my $context = delete $args{context};
  croak "allocate() needs a 'context'" unless $context;
  my $timeout = delete $args{timeout};
  $timeout    = $self->[SF_TIMEOUT]    unless $timeout;

  croak "allocate() on shut-down connection manager" if $self->[SF_SHUTDOWN];

  my @unknown = sort keys %args;
  if (@unknown) {
    croak "allocate() doesn't accept: @unknown";
  }

  my $conn_key = "$scheme:$address:$port";

  # If we have a connection pool for the scheme/address/port triple,
  # then we can maybe post an available connection right away.

  my $existing_connection = $self->_check_free_pool($conn_key);
  if (defined $existing_connection) {
    $poe_kernel->post(
      $poe_kernel->get_active_session,
      $event => {
        addr       => $address,
        context    => $context,
        port       => $port,
        scheme     => $scheme,
        connection => $existing_connection,
        from_cache => "immediate",
      }
    );
    return;
  }

  # We can't honor the request immediately, so it's put into a queue.
  DEBUG and warn "ALLOCATE: enqueuing request for $conn_key";

  my $request = [
    $poe_kernel->get_active_session(),  # RQ_SESSION
    $event,     # RQ_EVENT
    $scheme,    # RQ_SCHEME
    $address,   # RQ_ADDRESS
    undef,      # RQ_IP
    $port,      # RQ_PORT
    $conn_key,  # RQ_CONN_KEY
    $context,   # RQ_CONTEXT
    $timeout,   # RQ_TIMEOUT
    time(),     # RQ_START
    undef,      # RQ_TIMER_ID
    undef,      # RQ_WHEEL_ID
    1,          # RQ_ACTIVE
    _allocate_req_id(), # RQ_ID
  ];

  $self->[SF_REQ_INDEX]{$request->[RQ_ID]} = $request;

  $poe_kernel->refcount_increment(
    $request->[RQ_SESSION]->ID(),
    "poco-client-keepalive"
  );

  $poe_kernel->call("$self", ka_set_timeout     => $request);
  $poe_kernel->call("$self", ka_resolve_request => $request);

  return $request->[RQ_ID];
}

sub deallocate {
  my ($self, $req_id) = @_;

  croak "deallocate() requires a request ID" unless(
    defined($req_id) and exists($active_req_ids{$req_id})
  );

  my $request = delete $self->[SF_REQ_INDEX]{$req_id};
  unless (defined $request) {
    DEBUG_DEALLOCATE and warn "deallocate could not find request $req_id";
    return;
  }
  _free_req_id($request->[RQ_ID]);

  # Now pass the vetted request & its ID into our manager session.
  $poe_kernel->call("$self", "ka_deallocate", $request, $req_id);
}

sub _ka_deallocate {
  my ($self, $heap, $request, $req_id) = @_[OBJECT, HEAP, ARG0, ARG1];

  my $conn_key = $request->[RQ_CONN_KEY];
  my $existing_connection = $self->_check_free_pool($conn_key);

  # Existing connection.  Remove it from the pool, and delete the socket.
  if (defined $existing_connection) {
    $self->_remove_socket_from_pool($existing_connection->{socket});
    DEBUG_DEALLOCATE and warn(
      "deallocate called, deleted already-connected socket"
    );
    return;
  }

  # No connection yet.  Cancel the request.
  DEBUG_DEALLOCATE and warn(
    "deallocate called without an existing connection.  ",
    "cancelling connection request"
  );

  unless (exists $heap->{resolve}->{$request->[RQ_ADDRESS]}) {
    DEBUG_DEALLOCATE and warn(
      "deallocate cannot cancel dns -- no pending request"
    );
    return;
  }

  if ($heap->{resolve}->{$request->[RQ_ADDRESS]} eq 'cancelled') {
    DEBUG_DEALLOCATE and warn(
      "deallocate cannot cancel dns -- request already cancelled"
    );
    return;
  }

  $poe_kernel->call( "$self", ka_cancel_dns_response => $request );
  return;
}

sub _ka_cancel_dns_response {
  my ($self, $kernel, $heap, $request) = @_[OBJECT, KERNEL, HEAP, ARG0];

  my $address = $request->[RQ_ADDRESS];
  DEBUG_DNS and warn "DNS: canceling request for $address\n";
  my $requests = $heap->{resolve}{$address};

  # Remove the resolver request for the address of this connection
  # request

  my $req_index = @$requests;
  while ($req_index--) {
    next unless $requests->[$req_index] == $request;
    splice(@$requests, $req_index, 1);
    last;
  }

  # Clean up the structure for the address if there are no more
  # requests to resolve that address.

  unless (@$requests) {
    DEBUG_DNS and warn "DNS: canceled all requests for $address";
    $heap->{resolve}{$address} = 'cancelled';
  }

  # cancel our attempt to connect
  $poe_kernel->alarm_remove( $request->[RQ_TIMER_ID] );
  $poe_kernel->refcount_decrement(
    $request->[RQ_SESSION]->ID(), "poco-client-keepalive"
  );
}

# Set the request's timeout, in the component's context.

sub _ka_set_timeout {
  my ($kernel, $request) = @_[KERNEL, ARG0];
  $request->[RQ_TIMER_ID] = $kernel->delay_set(
    ka_request_timeout => $request->[RQ_TIMEOUT], $request
  );
}

# The request has timed out.  Mark it as defunct, and respond with an
# ETIMEDOUT error.

sub _ka_request_timeout {
  my ($self, $kernel, $request) = @_[OBJECT, KERNEL, ARG0];

  DEBUG and warn(
    "CON: request from session ", $request->[RQ_SESSION]->ID,
    " for address ", $request->[RQ_ADDRESS], " timed out"
  );
  $! = ETIMEDOUT;

  # The easiest way to do this?  Simulate an error from the wheel
  # itself.

  if (defined $request->[RQ_WHEEL_ID]) {
    @_[ARG0..ARG3] = ("connect", $!+0, "$!", $request->[RQ_WHEEL_ID]);
    goto &_ka_conn_failure;
  }

  # But what if there is no wheel?
  _respond_with_error($request, "connect", $!+0, "$!"),
}

# Connection failed.  Remove the SF_WHEELS record corresponding to the
# request.  Remove the SF_USED placeholder record so it won't count
# anymore.  Send a failure notice to the requester.

sub _ka_conn_failure {
  my ($self, $func, $errnum, $errstr, $wheel_id) = @_[OBJECT, ARG0..ARG3];

  DEBUG and warn "CON: sending $errstr for function $func";
  # Remove the SF_WHEELS record.
  my $wheel_rec = delete $self->[SF_WHEELS]{$wheel_id};
  my $request   = $wheel_rec->[WHEEL_REQUEST];

  # Remove the SF_USED placeholder.
  delete $self->[SF_USED]{$wheel_id};

  # remove the wheel-to-request index
  delete $self->[SF_REQ_INDEX]{$request->[RQ_ID]};
  _free_req_id($request->[RQ_ID]);

  # Discount the use by request key, removing the SF_USED record
  # entirely if it's now moot.
  my $request_key = $request->[RQ_CONN_KEY];
  $self->_decrement_used_each($request_key);

  # Tell the requester about the failure.
  _respond_with_error($request, $func, $errnum, $errstr),
}

# Connection succeeded.  Remove the SF_WHEELS record corresponding to
# the request.  Flesh out the placeholder SF_USED record so it counts.

sub _ka_conn_success {
  my ($self, $socket, $wheel_id) = @_[OBJECT, ARG0, ARG3];

  # Remove the SF_WHEELS record.
  my $wheel_rec = delete $self->[SF_WHEELS]{$wheel_id};
  my $request   = $wheel_rec->[WHEEL_REQUEST];

  # remove the wheel-to-request index
  delete $self->[SF_REQ_INDEX]{$request->[RQ_ID]};
  _free_req_id($request->[RQ_ID]);

  # Remove the SF_USED placeholder, add in the socket, and store it
  # properly.
  my $used = delete $self->[SF_USED]{$wheel_id};

  if ($request->[RQ_SCHEME] eq 'https') {
    unless ($ssl_available) {
      die "There is no SSL support, please install POE::Component::SSLify";
    }
    $socket = POE::Component::SSLify::Client_SSLify ($socket);
  }

  $used->[USED_SOCKET] = $socket;

  $self->[SF_USED]{$socket} = $used;
  DEBUG and warn(
    "CON: posting... to $request->[RQ_SESSION] . $request->[RQ_EVENT]"
  );

  # Build a connection object around the socket.
  my $connection = POE::Component::Connection::Keepalive->new(
    socket  => $socket,
    manager => $self,
  );

  # Give the socket to the requester.
  _respond(
    $request, {
      connection => $connection,
    }
  );
}

# The user is done with a socket.  Make it available for reuse.

sub free {
  my ($self, $socket) = @_;

  return if $self->[SF_SHUTDOWN];
  DEBUG and warn "FREE: freeing socket";

  # Remove the accompanying SF_USED record.
  croak "can't free() undefined socket" unless defined $socket;
  my $used = delete $self->[SF_USED]{$socket};
  croak "can't free() unallocated socket" unless defined $used;

  # Reclaim the socket.
  $poe_kernel->call("$self", "ka_reclaim_socket", $used);

  # Avoid returning things by mistake.
  return;
}

# A sink for deliberately unhandled events.

sub _ka_ignore_this_event {
  # Do nothing.
}

# An internal method to fetch a socket from the free pool, if one
# exists.

sub _check_free_pool {
  my ($self, $conn_key) = @_;

  return unless exists $self->[SF_POOL]{$conn_key};

  my $free = $self->[SF_POOL]{$conn_key};

  DEBUG and warn "CHECK: reusing $conn_key";

  my $next_socket = (values %$free)[0];
  delete $free->{$next_socket};
  unless (keys %$free) {
    delete $self->[SF_POOL]{$conn_key};
  }

  # _check_free_pool() may be operating in another session, so we call
  # the correct one here.
  $poe_kernel->call("$self", "ka_relinquish_socket", $next_socket);

  $self->[SF_USED]{$next_socket} = [
    $next_socket,  # USED_SOCKET
    time(),        # USED_TIME
    $conn_key,     # USED_KEY
  ];

  delete $self->[SF_SOCKETS]{$next_socket};

  $self->[SF_USED_EACH]{$conn_key}++;

    # Build a connection object around the socket.
    my $connection = POE::Component::Connection::Keepalive->new(
      socket  => $next_socket,
      manager => $self,
    );

  return $connection;
}

sub _decrement_used_each {
  my ($self, $request_key) = @_;
  unless (--$self->[SF_USED_EACH]{$request_key}) {
    delete $self->[SF_USED_EACH]{$request_key};
  }
}

# Reclaim a socket.  Put it in the free socket pool, and wrap it with
# select_read() to discard any data and detect when it's closed.

sub _ka_reclaim_socket {
  my ($self, $kernel, $used) = @_[OBJECT, KERNEL, ARG0];

  my $socket = $used->[USED_SOCKET];

  # Decrement the usage counter for the given connection key.
  my $request_key = $used->[USED_KEY];
  $self->_decrement_used_each($request_key);

  # Socket is closed.  We can't reuse it.
  unless (defined fileno $socket) {
    DEBUG and warn "RECLAIM: freed socket has previously been closed";
    goto &_ka_wake_up;
  }

  # Socket is still open.  Check for lingering data.
  DEBUG and warn "RECLAIM: checking if socket still works";

  # Check for data on the socket, which implies that the server
  # doesn't know we're done.  That leads to desynchroniziation on the
  # protocol level, which strongly implies that we can't reuse the
  # socket.  In this case, we'll make a quick attempt at fetching all
  # the data, then close the socket.

  my $rin = '';
  vec($rin, fileno($socket), 1) = 1;
  my ($rout, $eout);
  my $socket_is_active = select ($rout=$rin, undef, $eout=$rin, 0);

  if ($socket_is_active) {
    DEBUG and warn "RECLAIM: socket is still active; trying to drain";
    use bytes;

    my $socket_had_data = sysread($socket, my $buf = "", 65536) || 0;
    DEBUG and warn "RECLAIM: socket had $socket_had_data bytes. 0 means EOF";
    DEBUG and warn "RECLAIM: Giving up on socket.";

    # Avoid common FIN_WAIT_2 issues, but only for valid sockets.
    #if ($socket_had_data and fileno($socket)) {
    if ($socket_had_data) {
      my $opt_result = setsockopt(
        $socket, SOL_SOCKET, SO_LINGER, pack("sll",1,0,0)
      );
      die "setsockopt: " . ($!+0) . " $!" if (not $opt_result and $!  != EBADF);
    }

    goto &_ka_wake_up;
  }

  # Socket is alive and has no data, so it's in a quiet, theoretically
  # reclaimable state.

  DEBUG and warn "RECLAIM: reclaiming socket";

  # Watch the socket, and set a keep-alive timeout.
  $kernel->select_read($socket, "ka_socket_activity");
  my $timer_id = $kernel->delay_set(
    ka_keepalive_timeout => $self->[SF_KEEPALIVE], $socket
  );

  # Record the socket as free to be used.
  $self->[SF_POOL]{$request_key}{$socket} = $socket;
  $self->[SF_SOCKETS]{$socket} = [
    $request_key,       # SK_KEY
    $timer_id,          # SK_TIMER
  ];

  goto &_ka_wake_up;
}

# Socket timed out.  Discard it.

sub _ka_keepalive_timeout {
  my ($self, $socket) = @_[OBJECT, ARG0];
  $self->_remove_socket_from_pool($socket);
}

# Relinquish a socket.  Stop selecting on it.

sub _ka_relinquish_socket {
  my ($kernel, $socket) = @_[KERNEL, ARG0];
  $kernel->alarm_remove($_[OBJECT]->[SF_SOCKETS]{$socket}[SK_TIMER]);
  $kernel->select_read($socket, undef);
}

# Shut down the component.  Release any sockets we're currently
# holding onto.  Clean up any timers.  Remove the alias it's known by.

sub shutdown {
  my $self = shift;
  return if $self->[SF_SHUTDOWN];
  $poe_kernel->call("$self", "ka_shutdown");
}

sub _ka_shutdown {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];

  return if $self->[SF_SHUTDOWN];

  # Clean out the request queue.
  foreach my $request (@{$self->[SF_QUEUE]}) {
    $self->_shutdown_request($kernel, $request);
  }
  $self->[SF_QUEUE] = [ ];

  # Clean out the socket pool.
  foreach my $sockets (values %{$self->[SF_POOL]}) {
    foreach my $socket (values %$sockets) {
      $kernel->alarm_remove($self->[SF_SOCKETS]{$socket}[SK_TIMER]);
      $kernel->select_read($socket, undef);
    }
  }

  # Stop any pending resolver requests.
  foreach my $host (keys %{$heap->{resolve}}) {
    if ($heap->{resolve}{$host} eq 'cancelled') {
      DEBUG and warn "SHT: Skipping shutdown for $host (already cancelled)";
      next;
    }
    DEBUG and warn "SHT: Shutting down resolver requests for $host";
    foreach my $request (@{$heap->{resolve}{$host}}) {
      $self->_shutdown_request($kernel, $request);
    }
  }
  $heap->{resolve} = { };

  # Shut down the resolver.
  DEBUG and warn "SHT: Shutting down resolver";
  $self->[SF_RESOLVER]->shutdown();
  delete $self->[SF_RESOLVER];

  # Finish keepalive's shutdown.
  $kernel->alias_remove("$self");
  $self->[SF_SHUTDOWN] = 1;

  return;
}

sub _shutdown_request {
  my ($self, $kernel, $request) = @_;

  if (defined $request->[RQ_TIMER_ID]) {
    DEBUG and warn "SHT: Shutting down resolver timer $request->[RQ_TIMER_ID]";
    $kernel->alarm_remove($request->[RQ_TIMER_ID]);
  }

  if (defined $request->[RQ_WHEEL_ID]) {
    DEBUG and warn "SHT: Shutting down resolver wheel $request->[RQ_TIMER_ID]";
    delete $self->[SF_WHEELS]{$request->[RQ_WHEEL_ID]};

    # remove the wheel-to-request index
    delete $self->[SF_REQ_INDEX]{$request->[RQ_ID]};
    _free_req_id($request->[RQ_ID]);
  }

  if (defined $request->[RQ_SESSION]) {
    my $session_id = $request->[RQ_SESSION]->ID;
    DEBUG and warn "SHT: Releasing session $session_id";
    $kernel->refcount_decrement($session_id, "poco-client-keepalive");
  }
}

# A socket in the free pool has activity.  Read from it and discard
# the output.  Discard the socket on error or remote closure.

sub _ka_socket_activity {
  my ($self, $kernel, $socket) = @_[OBJECT, KERNEL, ARG0];

  if (DEBUG) {
    my $socket_rec = $self->[SF_SOCKETS]{$socket};
    my $key = $socket_rec->[SK_KEY];
    warn "CON: Got activity on socket for $key";
  }

  # Any socket activity on a kept-alive socket implies that the socket
  # is no longer reusable.

  use bytes;
  my $socket_had_data = sysread($socket, my $buf = "", 65536) || 0;
  DEBUG and warn "CON: socket had $socket_had_data bytes. 0 means EOF";
  DEBUG and warn "CON: Removing socket from the pool";

  $self->_remove_socket_from_pool($socket);
}

sub _ka_resolve_request {
  my ($self, $kernel, $heap, $request) = @_[OBJECT, KERNEL, HEAP, ARG0];

  my $host = $request->[RQ_ADDRESS];

  # Skip DNS resolution if it's already a dotted quad.
  # ip_is_ipv4() doesn't require quads, so we count the dots.
  #
  # TODO - Do the same for IPv6 addresses containing colons?
  # TODO - Would require AF_INET6 support around the SocketFactory.
  if ((($host =~ tr[.][.]) == 3) and ip_is_ipv4($host)) {
    DEBUG_DNS and warn "DNS: $host is a dotted quad; skipping lookup";
    $kernel->call("$self", ka_add_to_queue => $request);
    return;
  }

  # It's already pending DNS resolution.  Combine this with previous.
  if (exists $heap->{resolve}->{$host}) {
    DEBUG_DNS and warn "DNS: $host is piggybacking on a pending lookup.\n";
    push @{$heap->{resolve}->{$host}}, $request;
    return;
  }

  # New request.  Start lookup.
  $heap->{resolve}->{$host} = [ $request ];

  my $response = $self->[SF_RESOLVER]->resolve(
    event   => 'ka_dns_response',
    host    => $host,
    context => 1, # required but unused
  );

  if ($response) {
    DEBUG_DNS and warn "DNS: immediate resolution for $host";
    $kernel->yield(ka_dns_response => $response);
    return;
  }

  DEBUG_DNS and warn "DNS: looking up $host in the background.\n";
}

sub _ka_dns_response {
  my ($self, $kernel, $heap, $response) = @_[OBJECT, KERNEL, HEAP, ARG0];

  # We've shut down.  Nothing to do here.
  return if $self->[SF_SHUTDOWN];

  my $request_address = $response->{'host'};
  my $response_object = $response->{'response'};
  my $response_error  = $response->{'error'};

  my $requests = delete $heap->{resolve}->{$request_address};

  DEBUG_DNS and warn "DNS: got response for request address $request_address";

  # Requests on record.
  if (defined $requests) {
    # We can receive responses for canceled requests.  Ignore them: we
    # cannot cancel PoCo::Client::DNS requests, so this is how we reap
    # them when they're canceled.
    if ($requests eq 'cancelled') {
      DEBUG_DNS and warn "DNS: reaping cancelled request for $request_address";
      return;
    }
    unless (ref $requests eq 'ARRAY') {
      die "DNS: got an unknown requests for $request_address: $requests";
    }
  }
  else {
    die "DNS: Unexpectedly undefined requests for $request_address";
  }

  # No response.  This is an error.  Cancel all requests for the
  # address.  Tell everybody that their requests timed out.
  unless (defined $response_object) {
    DEBUG_DNS and warn "DNS: undefined response = error";
    foreach my $request (@$requests) {
      _respond_with_error($request, "resolve", undef, $response_error),
    }
    return;
  }

  DEBUG_DNS and warn "DNS: got a response";

  # A response!
  foreach my $answer ($response_object->answer()) {
    # don't need this because we ask for only A answers anyway
    #next unless $answer->type eq "A";

    DEBUG_DNS and warn "DNS: $request_address resolves to ", $answer->rdatastr;

    foreach my $request (@$requests) {
      # Don't bother continuing inactive requests.
      next unless $request->[RQ_ACTIVE];
      $request->[RQ_IP] = $answer->rdatastr;
      $kernel->yield(ka_add_to_queue => $request);
    }

    # Return after the first good answer.
    return;
  }

  # Didn't return here.  No address record for the host?
  foreach my $request (@$requests) {
    DEBUG_DNS and warn "DNS: $request_address does not resolve";
    _respond_with_error($request, "resolve", undef, "Host has no address."),
  }
}


sub _ka_add_to_queue {
  my ($self, $kernel, $request) = @_[OBJECT, KERNEL, ARG0];

  push @{ $self->[SF_QUEUE] }, $request;

  # If the queue has more than one request in it, then it already has
  # a wakeup event pending.  We don't need to send another one.

  return if @{$self->[SF_QUEUE]} > 1;

  # If the component's allocated socket count is maxed out, then it
  # will check the queue when an existing socket is released.  We
  # don't need to wake it up here.

  return if keys(%{$self->[SF_USED]}) >= $self->[SF_MAX_OPEN];

  # Likewise, we shouldn't awaken the session if there are no
  # available slots for the given scheme/address/port triple.  "|| 0"
  # to avoid an undef error.

  my $conn_key = $request->[RQ_CONN_KEY];
  return if (
    ($self->[SF_USED_EACH]{$conn_key} || 0) >= $self->[SF_MAX_HOST]
  );

  # Wake the session up, and return nothing, signifying sound and fury
  # yet to come.
  DEBUG and warn "posting wakeup for $conn_key";
  $poe_kernel->post("$self", "ka_wake_up");
  return;
}

# Remove a socket from the free pool, by the socket handle itself.

sub _remove_socket_from_pool {
  my ($self, $socket) = @_;

  my $socket_rec = delete $self->[SF_SOCKETS]{$socket};
  my $key = $socket_rec->[SK_KEY];

  # Get the blessed version.
  DEBUG and warn "removing socket for $key";
  $socket = delete $self->[SF_POOL]{$key}{$socket};

  unless (keys %{$self->[SF_POOL]{$key}}) {
    delete $self->[SF_POOL]{$key};
  }

  $poe_kernel->alarm_remove($socket_rec->[SK_TIMER]);
  $poe_kernel->select_read($socket, undef);

  # Avoid common FIN_WAIT_2 issues.
  # Commented out because fileno() will return true for closed
  # sockets, which makes setsockopt() highly unhappy.  Also, SO_LINGER
  # will cause te socket closure to block, which is less than ideal.
  # We need to revisit this another way, or just let sockets enter
  # FIN_WAIT_2.

#  if (fileno $socket) {
#    setsockopt($socket, SOL_SOCKET, SO_LINGER, pack("sll",1,0,0)) or die(
#      "setsockopt: $!"
#    );
#  }
}

# Internal function.  NOT AN EVENT HANDLER.

sub _respond_with_error {
  my ($request, $func, $num, $string) = @_;
  _respond(
    $request,
    {
      connection => undef,
      function   => $func,
      error_num  => $num,
      error_str  => $string,
    }
  );
}

sub _respond {
  my ($request, $fields) = @_;

  # Bail out early if the request isn't active.
  return unless $request->[RQ_ACTIVE] and $request->[RQ_SESSION];

  $poe_kernel->post(
    $request->[RQ_SESSION],
    $request->[RQ_EVENT],
    {
      addr       => $request->[RQ_ADDRESS],
      context    => $request->[RQ_CONTEXT],
      port       => $request->[RQ_PORT],
      scheme     => $request->[RQ_SCHEME],
      %$fields,
    }
  );

  # Drop the extra refcount.
  $poe_kernel->refcount_decrement(
    $request->[RQ_SESSION]->ID(),
    "poco-client-keepalive"
  );

  # Remove associated timer.
  if ($request->[RQ_TIMER_ID]) {
    $poe_kernel->alarm_remove($request->[RQ_TIMER_ID]);
    $request->[RQ_TIMER_ID] = undef;
  }

  # Deactivate the request.
  $request->[RQ_ACTIVE] = undef;
}

1;

__END__

=head1 NAME

POE::Component::Client::Keepalive - manage connections, with keep-alive

=head1 SYNOPSIS

  use warnings;
  use strict;

  use POE;
  use POE::Component::Client::Keepalive;

  POE::Session->create(
    inline_states => {
      _start    => \&start,
      got_conn  => \&got_conn,
      got_error => \&handle_error,
      got_input => \&handle_input,
    }
  );

  POE::Kernel->run();
  exit;

  sub start {
    $_[HEAP]->{ka} = POE::Component::Client::Keepalive->new();

    $_[HEAP]->{ka}->allocate(
      scheme  => "http",
      addr    => "127.0.0.1",
      port    => 9999,
      event   => "got_conn",
      context => "arbitrary data (even a reference) here",
      timeout => 60,
    );

    print "Connection is in progress.\n";
  }

  sub got_conn {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    my $conn    = $response->{connection};
    my $context = $response->{context};

    if (defined $conn) {
      if ($response->{from_cache}) {
        print "Connection was established immediately.\n";
      }
      else {
        print "Connection was established asynchronously.\n";
      }

      $conn->start(
        InputEvent => "got_input",
        ErrorEvent => "got_error",
      );
      return;
    }

    print(
      "Connection could not be established: ",
      "$response->{function} error $response->{error_num}: ",
      "$response->{error_str}\n"
    );
  }

  sub handle_input {
    my $input = $_[ARG0];
    print "$input\n";
  }

  sub handle_error {
    my $heap = $_[HEAP];
    delete $heap->{connection};
    $heap->{ka}->shutdown();
  }

=head1 DESCRIPTION

POE::Component::Client::Keepalive creates and manages connections for
other components.  It maintains a cache of kept-alive connections for
quick reuse.  It is written specifically for clients that can benefit
from kept-alive connections, such as HTTP clients.  Using it for
one-shot connections would probably be silly.

=over 2

=item new

Creates a new keepalive connection manager.  A program may contain
several connection managers.  Each will operate independently of the
others.  None will know about the limits set in the others, so it's
possible to overrun your file descriptors for a process if you're not
careful.

new() takes up to five parameters.  All of them are optional.

To limit the number of simultaneous connections to a particular host
(defined by a combination of scheme, address and port):

  max_per_host => $max_simultaneous_host_connections, # defaults to 4

To limit the overall number of connections that may be open at once,
use

  max_open     => $maximum_open_connections, # defaults to 128

Programs are required to give connections back to the manager when
they are done.  See the free() method for how that works.  The
connection manager will keep connections alive for a period of time
before recycling them.  The maximum keep-alive time may be set with

  keep_alive   => $seconds_to_keep_free_conns_alive, # defaults to 15

Programs may not want to wait a long time for a connection to be
established.  They can set the request timeout to alter how long the
component holds a request before generating an error.

  timeout      => $seconds_to_process_a_request, # defaults to 120

Specify a bind_address to bind all client sockets to a particular
local address.  The value of bind_address will be passed directly to
POE::Wheel::SocketFactory.  See that module's documentation for
implementation details.

=item allocate

Allocate a new connection.  Allocate() will return immediately.  The
allocated connection, however, will be posted back to the requesting
session.  This happens even if the connection was found in the
component's keep-alive cache.

Allocate() requires five parameters and has an optional sixth.

Specify the scheme that will be used to communicate on the connection
(typically http or https).  The scheme is required, but you're free to
make something up here.  It's used internally to differentiate
different types of socket (e.g., ssl vs. cleartext) on the same
address and port.

  scheme  => $connection_scheme,

Request a connection to a particular address and port.  The address
and port must be numeric.  Both the address and port are required.

  address => $remote_address,
  port    => $remote_port,

Specify an name of the event to post when an asynchronous response is
ready.  This is of course required.

  event   => $return_event,

Set the connection timeout, in seconds.  The connection manager will
post back an error message if it can't establish a connection within
the requested time.  This parameter is optional.  It will default to
the master timeout provided to the connection manager's constructor.

  timeout => $connect_timeout,

Specify additional contextual data.  The context defines the
connection's purpose.  It is used to maintain continuity between a
call to allocate() and an asynchronous response.  A context is
extremely handy, but it's optional.

  context => $context_data,

In summary:

  $mgr->allocate(
    scheme   => "http",
    address  => "127.0.0.1",
    port     => 80,
    event    => "got_a_connection",
    context  => \%connection_context,
  );

The response event ("got_a_connection" in this example) contains
several fields, passed as a list of key/value pairs.  The list may be
assigned to a hash for convenience:

  sub got_a_connection {
    my %response = @_[ARG0..$#_];
    ...;
  }

Four of the fields exist to echo back your data:

  $response{address}    = $your_request_address;
  $response{context}    = $your_request_context;
  $response{port}       = $your_request_port;
  $response{scheme}     = $your_request_scheme;

One field returns the connection object if the connection was
successful, or undef if there was a failure:

  $response{connection} = $new_socket_handle;

On success, another field tells you whether the connection contains
all new materials.  That is, whether the connection has been recycled
from the component's cache or created anew.

  $response{from_cache} = $status;

The from_cache status may be "immediate" if the connection was
immediately available from the cache.  It will be "deferred" if the
connection was reused, but another user had to release it first.
Finally, from_cache will be false if the connection had to be created
to satisfy allocate().

Three other fields return error information if the connection failed.
They are not present if the connection was successful.

  $response{function}   = $name_of_failing_function;
  $response{error_num}  = $! as a number;
  $response{error_str}  = $! as a string;

=item free

Free() notifies the connection manager when connections are free to be
reused.  Freed connections are entered into the keep-alive pool and
may be returned by subsequent allocate() calls.

  $mgr->free($socket);

For now free() is called with a socket, not a connection object.  This
is usually not a problem since POE::Component::Connection::Keepalive
objects call free() for you when they are destroyed.

Not calling free() will cause a program to leak connections.  This is
also not generally a problem, since free() is called automatically
whenever connection objects are destroyed.

=item shutdown

The keep-alive pool requires connections to be active internally.
This may keep a program active even when all connections are idle.
The shutdown() method forces the connection manager to clear its
keep-alive pool, allowing a program to terminate gracefully.

  $mgr->shutdown();

=back

=head1 SEE ALSO

L<POE>
L<POE::Component::Connection::Keepalive>

=head1 LICENSE

This distribution is copyright 2004-2009 by Rocco Caputo.  All rights
are reserved.  This distribution is free software; you may
redistribute it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Rocco Caputo <rcaputo@cpan.org>

=head1 CONTRIBUTORS

Rob Bloodgood helped out a lot.  Thank you.

Joel Bernstein solved some nasty race conditions.  Portugal Telecom
L<http://www.sapo.pt/> was kind enough to support his contributions.

=head1 BUG TRACKER

https://rt.cpan.org/Dist/Display.html?Queue=POE-Component-Client-Keepalive

=head1 REPOSITORY

http://gitorious.org/poe-component-client-keepalive
http://github.com/rcaputo/poe-component-client-keepalive

=head1 OTHER RESOURCES

http://search.cpan.org/dist/POE-Component-Client-Keepalive/

=cut
