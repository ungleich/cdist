# License and documentation are after __END__.
# vim: set ts=2 sw=2 expandtab

package POE::Component::Client::Ping;

use warnings;
use strict;

use Exporter;
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);
@EXPORT_OK = qw(
  REQ_ADDRESS REQ_TIMEOUT REQ_TIME REQ_USER_ARGS RES_ADDRESS
  RES_ROUNDTRIP RES_TIME RES_TTL
);
%EXPORT_TAGS = (
  const => [
    qw(
      REQ_ADDRESS REQ_TIMEOUT REQ_TIME REQ_USER_ARGS RES_ADDRESS
      RES_ROUNDTRIP RES_TIME RES_TTL
    )
  ]
);

use vars qw($VERSION $PKTSIZE);
$VERSION = '1.163';
$PKTSIZE = $^O eq 'linux' ? 3_000 : 100;

use Carp qw(croak);
use Symbol qw(gensym);
use Socket;
use Time::HiRes qw(time);

use POE::Session;

sub DEBUG        () { 0 } # Enable more information.
sub DEBUG_SOCKET () { 0 } # Watch the socket open and close.
sub DEBUG_PBS    () { 0 } # Watch ping_by_seq management.

# Spawn a new PoCo::Client::Ping session.  This basically is a
# constructor, but it isn't named "new" because it doesn't create a
# usable object.  Instead, it spawns the object off as a session.

sub spawn {
  my $type = shift;

  croak "$type requires an even number of parameters" if @_ % 2;
  my %params = @_;

  croak "$type requires root privilege" if (
    $> and ($^O ne "VMS") and
    ($^O ne "cygwin") and
    not defined $params{Socket}
  );

  my $alias = delete $params{Alias};
  $alias = "pinger" unless defined $alias and length $alias;

  my $timeout = delete $params{Timeout};
  $timeout = 1 unless defined $timeout and $timeout >= 0;

  my $onereply = delete $params{OneReply};
  my $socket = delete $params{Socket};
  my $parallelism = delete $params{Parallelism} || -1;
  my $rcvbuf = delete $params{BufferSize};
  my $always_decode = delete $params{AlwaysDecodeAddress};
  my $retry = delete $params{Retry};
  my $payload = delete $params{Payload};

  # 56 data bytes :)
  $payload = 'Use POE!' x 7 unless defined $payload;

  croak(
    "$type doesn't know these parameters: ", join(', ', sort keys %params)
  ) if scalar keys %params;

  POE::Session->create(
    inline_states => {
      _start   => \&poco_ping_start,
      ping     => \&poco_ping_ping,
      clear    => \&poco_ping_clear,
      got_pong => \&poco_ping_pong,
      _default => \&poco_ping_default,
    },
    args => [
      $alias, $timeout, $retry, $socket, $onereply, $parallelism,
      $rcvbuf, $always_decode, $payload
    ],
  );

  undef;
}

# ping_by_seq structure offsets.

sub PBS_POSTBACK     () { 0 };
sub PBS_SESSION      () { 1 };
sub PBS_ADDRESS      () { 2 };
sub PBS_REQUEST_TIME () { 3 };

# request_packet offsets
sub REQ_ADDRESS       () { 0 };
sub REQ_TIMEOUT       () { 1 };
sub REQ_TIME          () { 2 };
sub REQ_USER_ARGS     () { 3 };

# response_packet offsets
sub RES_ADDRESS       () { 0 };
sub RES_ROUNDTRIP     () { 1 };
sub RES_TIME          () { 2 };
sub RES_TTL           () { 3 };

# "Static" variables which will be shared across multiple instances.

my $pid = $$ & 0xFFFF;
my $master_seq = 0;

# Start the pinger session.  Record running stats, and create the
# socket which will be used to ping.

sub poco_ping_start {
  my (
    $kernel, $heap,
    $alias, $timeout, $retry, $socket, $onereply, $parallelism,
    $rcvbuf, $always_decode, $payload
  ) = @_[KERNEL, HEAP, ARG0..ARG8];

  $heap->{data}          = $payload;
  $heap->{data_size}     = length($heap->{data});
  $heap->{timeout}       = $timeout;
  $heap->{onereply}      = $onereply;
  $heap->{always_decode} = $always_decode;
  $heap->{ping_by_seq}   = { };  # keyed on sequence number
  $heap->{addr_to_seq}   = { };  # keyed on request address, then sender
  $heap->{rcvbuf}        = $rcvbuf;
  $heap->{retry}         = $retry;

  # Queue to manage throttling
  $heap->{parallelism}   = $parallelism; # how many pings can we send at once
  $heap->{queue}         = [ ]; # ordered list of throttled pings
  $heap->{pending}       = { }; # data for the sequence ids of queued pings
  $heap->{outstanding}   = 0;   # How many pings are we awaiting replies for

  if (defined $socket) {
    # Root is needed for this step too.
    $heap->{socket_handle} = $socket;
    $heap->{keep_socket}   = 1;
  }
  else {
    $heap->{keep_socket}   = 0;
  }

  $kernel->alias_set($alias);
}

# ICMP echo constants. Types, structures, and fields.  Cribbed
# mercilessly from Net::Ping.

sub ICMP_ECHOREPLY () { 0 }
sub ICMP_ECHO      () { 8 }
sub ICMP_STRUCT    () { 'C2 S3 A' }
sub ICMP_SUBCODE   () { 0 }
sub ICMP_FLAGS     () { 0 }
sub ICMP_PORT      () { 0 }

# (NOT A POE EVENT HANDLER)
# Create a raw socket to send ICMP packets down.
# (optionally) mess with the size of the buffers on the socket.
sub create_handle {
  my ($kernel, $heap) = @_;
  DEBUG_SOCKET and warn "opening a raw socket for icmp";

  my $protocol = (getprotobyname('icmp'))[2]
    or die "can't get icmp protocol by name: $!";

  my $socket = gensym();
  socket($socket, PF_INET, SOCK_RAW, $protocol)
    or die "can't create icmp socket: $!";

  $heap->{socket_handle} = $socket;

  _setup_handle($kernel, $heap);
}

### NOT A POE EVENT HANDLER
sub _setup_handle {
  my ($kernel, $heap) = @_;

  if ($heap->{rcvbuf}) {
    unless (
      setsockopt(
        $heap->{socket_handle}, SOL_SOCKET,
        SO_RCVBUF, pack("I", $heap->{rcvbuf})
      )
    ) {
        warn("setsockopt rcvbuf size ($heap->{rcvbuf}) failed: $!");
    }
  }

  if ($heap->{parallelism} && $heap->{parallelism} == -1) {
    my $rcvbuf = getsockopt($heap->{socket_handle}, SOL_SOCKET, SO_RCVBUF);
    if ($rcvbuf) {
      my $size = unpack("I", $rcvbuf);
      my $max_parallel = int($size / $PKTSIZE);
      if ($max_parallel > 8) {
        $max_parallel -= 8;
      }
      elsif ($max_parallel < 1) {
        $max_parallel = 1;
      }
      $heap->{parallelism} = $max_parallel;
    }
  }

  $kernel->select_read($heap->{socket_handle}, 'got_pong');
}

# Request a ping.  This code borrows heavily from Net::Ping.

sub poco_ping_ping {
  my (
    $kernel, $heap, $sender,
    $event, $address, $timeout, $retry, $optpostback
  ) = @_[
    KERNEL, HEAP, SENDER,
    ARG0, ARG1, ARG2, ARG3, ARG4
  ];

  # When doing retries, the pinger session will request the ping and
  # therefore the sender info is bogus. So, for retries we stash all the
  # original information away and pass it back in via the optpostback param.
  if ($optpostback) {
    $sender = $optpostback->[PBS_SESSION];
  }

  DEBUG and warn "ping requested for $address\n";

  # No current pings.  Open a socket, or setup the existing one.
  unless (scalar(keys %{$heap->{ping_by_seq}})) {
    unless (exists $heap->{socket_handle}) {
      create_handle($kernel, $heap);
    }
    else {
      _setup_handle($kernel, $heap);
    }
  }

  # Get the timeout, or default to the one set for the component.
  $timeout = $heap->{timeout} unless defined $timeout and $timeout > 0;
  $retry = $heap->{retry} unless defined $retry;

  # Find an unused sequence number.
  while (1) {
    $master_seq = ($master_seq + 1) & 0xFFFF;
    last unless exists $heap->{ping_by_seq}->{$master_seq};
  }

  my $checksum = 0;

  # Build the message without a checksum.
  my $msg = pack(
    ICMP_STRUCT . $heap->{data_size},
    ICMP_ECHO, ICMP_SUBCODE, $checksum, $pid, $master_seq, $heap->{data}
  );

  ### Begin checksum calculation section.

  # Sum up short integers in the packet.
  my $shorts = int(length($msg) / 2);
  foreach my $short (unpack "S$shorts", $msg) {
    $checksum += $short;
  }

  # If there's an odd byte, add that in as well.
  $checksum += ord(substr($msg, -1)) if length($msg) % 2;

  # Fold the high short into the low one twice, and then complement.
  $checksum = ($checksum >> 16) + ($checksum & 0xFFFF);
  $checksum = ~( ($checksum >> 16) + $checksum) & 0xFFFF;

  ### Cease checksum calculation section.

  # Rebuild the message with the checksum this time.
  $msg = pack(
    ICMP_STRUCT . $heap->{data_size},
    ICMP_ECHO, ICMP_SUBCODE, $checksum, $pid, $master_seq, $heap->{data}
  );

  # Record information about the ping request.

  my ($event_name, @user_args);
  if (ref($event) eq "ARRAY") {
    ($event_name, @user_args) = @$event;
  }
  else {
    $event_name = $event;
  }

  # Build an address to send the ping at.
  my $usable_address = $address;
  if ($heap->{always_decode} || length($address) != 4) {
    $usable_address = inet_aton($address);
  }

  # Return failure if an address was not resolvable.  This simulates
  # the postback behavior.
  unless (defined $usable_address) {
    $kernel->post(
      $sender, $event_name,
      [ $address,    # REQ_ADDRESS
        $timeout,    # REQ_TIMEOUT
        time(),      # REQ_TIME
        @user_args,  # REQ_USER_ARGS
      ],
      [ undef,   # RES_ADDRESS
        undef,   # RES_ROUNDTRIP
        time(),  # RES_TIME
        undef,   # RES_TTL
      ],
    );
    _check_for_close($kernel, $heap);
    return;
  }

  my $socket_address = pack_sockaddr_in(ICMP_PORT, $usable_address);

  push(@{$heap->{queue}}, $master_seq);
  $heap->{pending}->{$master_seq} = [
    $msg,               # PEND_MSG
    $socket_address,    # PEND_ADDR
    $sender,            # PEND_SENDER
    $event,             # PEND_EVENT
    $address,           # PEND_ADDR ???
    $timeout,           # PEND_TIMEOUT
    $optpostback,       # PEND_OPTPOSTBACK
  ];

  if ($retry && $retry > 1) {
    $heap->{retrydata}->{$master_seq} = [
      $sender,    # RD_SENDER
      $event,     # RD_EVENT
      $address,   # RD_ADDRESS
      $timeout,   # RD_TIMEOUT
      $retry,     # RD_RETRY
    ];
  }

  _send_packet($kernel, $heap);
}

sub _send_packet {
  my ($kernel, $heap) = @_;
  return unless (scalar @{$heap->{queue}});

  if ($heap->{parallelism} && $heap->{outstanding} >= $heap->{parallelism}) {
    # We want to throttle back since we're still waiting for pings
    # so, let's just leave this till later
    DEBUG and warn(
      "throttled since there are $heap->{outstanding} pings outstanding. " .
      "queue size=" . (scalar @{$heap->{queue}}) . "\n"
    );
    return;
  }

  my $seq = shift(@{$heap->{queue}});

  # May have been cleared by caller
  return unless (exists $heap->{pending}->{$seq});

  my $ping_info = delete $heap->{pending}->{$seq};
  my (
    $msg,               # PEND_MSG
    $socket_address,    # PEND_ADDR
    $sender,            # PEND_SENDER
    $event,             # PEND_EVENT
    $address,           # PEND_ADDR ???
    $timeout,           # PEND_TIMEOUT
    $optpostback,       # PEND_OPTPOSTBACK
  ) = @$ping_info;

  # Send the packet.  If send() fails, then we bail with an error.
  my @user_args = ();
  ($event, @user_args) = @$event if ref($event) eq "ARRAY";

  DEBUG and warn "sending packet sequence number $seq\n";
  unless (send($heap->{socket_handle}, $msg, ICMP_FLAGS, $socket_address)) {
    $kernel->post(
      $sender, $event,
      [ $address,    # REQ_ADDRESS
        $timeout,    # REQ_TIMEOUT
        time(),      # REQ_TIME
        @user_args,  # REQ_USER_ARGS
      ],
      [ undef,   # RES_ADDRESS
        undef,   # RES_ROUNDTRIP
        time(),  # RES_TIME
        undef,   # RES_TTL
      ],
    );
    _check_for_close($kernel, $heap);
    return;
  }

  # Record the message's length.  This is constant, but we do it here
  # anyway.  It's also used to flag when we start requesting replies.
  $heap->{message_length} = length($msg);
  $heap->{outstanding}++;

  # Set a timeout based on the sequence number.
  $kernel->delay( $seq => $timeout );

  DEBUG_PBS and warn "recording ping_by_seq($seq)";
  if ($optpostback) {
    $heap->{ping_by_seq}->{$seq} = $optpostback;

    # If retries, set the request time to the new/actual request time.
    # Inserted by Ralph Schmitt 2009-09-12.
    $optpostback->[PBS_REQUEST_TIME] = time();
  }
  else {
    $heap->{ping_by_seq}->{$seq} = [
      # PBS_POSTBACK
      $sender->postback(
        $event,
        $address,    # REQ_ADDRESS
        $timeout,    # REQ_TIMEOUT
        time(),      # REQ_TIME
        @user_args,  # REQ_USER_ARGS
      ),
      "$sender",   # PBS_SESSION (stringified to weaken reference)
      $address,    # PBS_ADDRESS
      time()       # PBS_REQUEST_TIME
    ];
  }

  # Duplicate pings?  Forcibly time out the previous one.
  if (exists $heap->{addr_to_seq}->{$sender}->{$address}) {
    my $now = time();
    my $old_seq = delete $heap->{addr_to_seq}->{$sender}->{$address};
    my $old_info = delete $heap->{ping_by_seq}->{$old_seq};
    $old_info->[PBS_POSTBACK]->( undef, undef, $now, undef );
  }

  $heap->{addr_to_seq}->{$sender}->{$address} = $seq;
}

# Clear a ping postback by address.  The sender+address pair are a
# unique ID into the pinger's data.

sub poco_ping_clear {
  my ($kernel, $heap, $sender, $address) = @_[KERNEL, HEAP, SENDER, ARG0];

  # Is the sender still waiting for anything?
  return unless exists $heap->{addr_to_seq}->{$sender};

  # Try to clear a single ping if an address was specified.
  if (defined $address) {

    # Don't bother if we don't have it.
    if (!exists $heap->{addr_to_seq}->{$sender}->{$address}) {
      delete $heap->{pending}->{$sender}->{$address};
      return;
    }

    # Stop mapping the sender+address pair to that sequence number.
    my $seq = delete $heap->{addr_to_seq}->{$sender}->{$address};

    # Stop tracking the sender if that was the last address.
    delete $heap->{addr_to_seq}->{$sender} unless (
      scalar(keys %{$heap->{addr_to_seq}->{$sender}})
    );

    # Discard the postback for the discarded sequence number.
    DEBUG_PBS and warn "removing ping_by_seq($seq)";
    delete $heap->{ping_by_seq}->{$seq};
    $kernel->delay($seq);
  }

  # No address was specified.  Clear all the pings for this session.
  else {
    # First discard all the ping records.
    foreach my $seq (values %{$heap->{addr_to_seq}->{$sender}}) {
      DEBUG_PBS and warn "removing ping_by_seq($seq)";
      delete $heap->{ping_by_seq}->{$seq};
      $kernel->delay($seq);
    }

    # Now clear all the postbacks for the sender.
    delete $heap->{addr_to_seq}->{$sender};
  }

  _check_for_close($kernel, $heap);
}

# (NOT A POE EVENT HANDLER)
# Check to see if no more pings are waiting.  Close the socket if so.
sub _check_for_close {
  my ($kernel, $heap) = @_;
  unless (scalar(keys %{$heap->{ping_by_seq}})) {
    DEBUG_SOCKET and warn "stopping raw socket watcher";
    $kernel->select_read( $heap->{socket_handle} );
    unless ($heap->{keep_socket}) {
      DEBUG_SOCKET and warn "closing raw socket";
      delete $heap->{socket_handle};
    }
  }
}

# (NOT A POE EVENT HANDLER)
# Clean up after we're done with a ping.
# remove it from all tracking hashes. After it's removed
# check to see if we should unthrottle or shutdown the socket.

sub _end_ping {
  my ($kernel, $heap, $from_seq) = @_;

  # Delete the ping information.  Cache a copy for other cleanup.
  DEBUG_PBS and warn "removing ping_by_seq($from_seq)";
  my $ping_info = delete $heap->{ping_by_seq}->{$from_seq};
  $kernel->delay($from_seq);

  # Stop mapping the session+address to this sequence number.
  delete(
   $heap->{addr_to_seq}->{
     $ping_info->[PBS_SESSION]
   }->{$ping_info->[PBS_ADDRESS]}
  );

  # Stop tracking the session if that was the last address.
  delete $heap->{addr_to_seq}->{$ping_info->[PBS_SESSION]} unless (
    scalar(keys %{$heap->{addr_to_seq}->{$ping_info->[PBS_SESSION]}})
  );

  $heap->{outstanding}--;

  return $ping_info;
}


# Something has arrived.  Try to match it against something being
# waited for.

sub poco_ping_pong {
  my ($kernel, $heap, $socket) = @_[KERNEL, HEAP, ARG0];

  # Record the receive time for possible use later.
  my $now = time();

  # Receive a message on the ICMP port.
  my $recv_message = '';
  my $from_saddr = recv($socket, $recv_message, 1500, ICMP_FLAGS);
  return unless $from_saddr;

  # We haven't yet sent a message, so don't bother with whatever we've
  # received.
  return unless defined $heap->{message_length};

  # Unpack the packet's sender address.
  my ($from_port, $from_ip) = unpack_sockaddr_in($from_saddr);

  # Get the response packet's time to live.
  my ($ihl, $from_ttl) = unpack('C1@7C1', $recv_message);
  $ihl &= 0x0F;

  # Unpack the packet itself.
  my (
    $from_type, $from_subcode,
    $from_checksum, $from_pid, $from_seq, $from_message
  )  = unpack( '@'.$ihl*4 . ICMP_STRUCT.$heap->{data_size},
               $recv_message );

  DEBUG and do {
    warn ",----- packet from ", inet_ntoa($from_ip), ", port $from_port\n";
    warn "| type = $from_type / subtype = $from_subcode\n";
    warn "| checksum = $from_checksum, pid = $from_pid, seq = $from_seq\n";
    warn "| message: $from_message\n";
    warn "`------------------------------------------------------------\n";
  };

  # Not an ICMP echo reply.  Move along.
  return unless $from_type == ICMP_ECHOREPLY;

  DEBUG and warn "it's an ICMP echo reply";

  # Not from this process.  Move along.
  return unless $from_pid == $pid;

  DEBUG and warn "it's from this process ($pid)";

  # Not waiting for a response with that sequence number.  Move along.
  return unless exists $heap->{ping_by_seq}->{$from_seq};

  DEBUG and warn "it's one we're waiting for ($from_seq)";

  # This is the response we're looking for.  Calculate the round trip
  # time, and map it to a postback.
  my $trip_time = $now - $heap->{ping_by_seq}->{$from_seq}->[PBS_REQUEST_TIME];
  $heap->{ping_by_seq}->{$from_seq}->[PBS_POSTBACK]->(
    inet_ntoa($from_ip), $trip_time, $now, $from_ttl
  );

  # It's a single-reply ping.  Clean up after it.
  if ($heap->{onereply}) {
    _end_ping($kernel, $heap, $from_seq);
    _send_packet($kernel, $heap);
    _check_for_close($kernel, $heap);
  }
}

# Default's used to catch ping timeouts, which are named after the
# packed socket addresses being pinged.  We always send the timeout so
# the other session knows that a ping period has ended.

sub poco_ping_default {
  my ($kernel, $heap, $seq) = @_[KERNEL, HEAP, ARG0];

  # Record the receive time for possible use later.
  my $now = time();

  # Are we waiting for this sequence number?  We should be!
  if (exists $heap->{ping_by_seq}->{$seq}) {
    my $retryinfo = delete $heap->{retrydata}->{$seq};
    if ($retryinfo) {
      my ($sender, $event, $address, $timeout, $remaining) = @{$retryinfo};
      DEBUG and warn("retrying ping for $address\n");
      my $pinginfo = _end_ping($kernel, $heap, $seq);
      $kernel->yield(
        "ping", $event, $address, $timeout, $remaining-1, $pinginfo
      );
      return 1;
    }

    # Post a timer tick back to the session.  This marks the end of
    # the request/response transaction.
    my $ping_info = _end_ping($kernel, $heap, $seq);
    $ping_info->[PBS_POSTBACK]->( undef, undef, $now, undef );
    _send_packet($kernel, $heap);
    _check_for_close($kernel, $heap);

    return 1;
  }

  warn "this shouldn't technically be displayed ($seq)" if (
    DEBUG and $seq =~ /^\d+$/
  );

  # Let unhandled signals pass through so we do not block SIGINT, etc.
  return 0;
}

1;

__END__

=head1 NAME

POE::Component::Client::Ping - a non-blocking ICMP ping client

=head1 SYNOPSIS

  use POE qw(Component::Client::Ping);

  POE::Component::Client::Ping->spawn(
    Alias               => "pingthing",  # defaults to "pinger"
    Timeout             => 10,           # defaults to 1 second
    Retry               => 3,            # defaults to 1 attempt
    OneReply            => 1,            # defaults to disabled
    Parallelism         => 64,           # defaults to autodetect
    BufferSize          => 65536,        # defaults to undef
    AlwaysDecodeAddress => 1,            # defaults to 0
  );

  sub some_event_handler {
    $kernel->post(
      "pingthing", # Post the request to the "pingthing" component.
      "ping",      # Ask it to "ping" an address.
      "pong",      # Have it post an answer as a "pong" event.
      $address,    # This is the address we want to ping.
      $timeout,    # Optional timeout.  It overrides the default.
      $retry,      # Optional retries. It overrides the default.
    );
  }

  # This is the sub which is called when the session receives a "pong"
  # event.  It handles responses from the Ping component.
  sub got_pong {
    my ($request, $response) = @_[ARG0, ARG1];

    my ($req_address, $req_timeout, $req_time)      = @$request;
    my ($resp_address, $roundtrip_time, $resp_time, $resp_ttl) = @$response;

    # The response address is defined if this is a response.
    if (defined $resp_address) {
      printf(
        "ping to %-15.15s at %10d. pong from %-15.15s in %6.3f s\n",
        $req_address, $req_time,
        $resp_address, $roundtrip_time,
      );
      return;
    }

    # Otherwise the timeout period has ended.
    printf(
      "ping to %-15.15s is done.\n", $req_address,
    );
  }

  or

  use POE::Component::Client::Ping ":const";

  # Post an array ref as the callback to get data back to you
  $kernel->post("pinger", "ping", [ "pong", $user_data ]);

  # use the REQ_USER_ARGS constant to get to your data
  sub got_pong {
      my ($request, $response) = @_[ARG0, ARG1];
      my $user_data = $request->[REQ_USER_ARGS];
      ...;
  }

=head1 DESCRIPTION

POE::Component::Client::Ping is non-blocking ICMP ping client.  It
lets several other sessions ping through it in parallel, and it lets
them continue doing other things while they wait for responses.

Ping client components are not proper objects.  Instead of being
created, as most objects are, they are "spawned" as separate sessions.
To avoid confusion (and hopefully not cause other confusion), they
must be spawned with a C<spawn> method, not created anew with a C<new>
one.

PoCo::Client::Ping's C<spawn> method takes a few named parameters:

=over 2

=item Alias => $session_alias

C<Alias> sets the component's alias.  It is the target of post()
calls.  See the synopsis.  The alias defaults to "pinger".

=item Socket => $raw_socket

C<Socket> allows developers to open an existing raw socket rather
than letting the component attempt opening one itself.  If omitted,
the component will create its own raw socket.

This is useful for people who would rather not perform a security
audit on POE, since it allows them to create a raw socket in their own
code and then run POE at reduced privileges.

=item Timeout => $ping_timeout

C<Timeout> sets the default amount of time (in seconds) a Ping
component will wait for a single ICMP echo reply before retrying.  It
is 1 by default.  It is possible and meaningful to set the timeout to
a fractional number of seconds.

This default timeout is only used for ping requests that don't include
their own timeouts.

=item Retry => $ping_attempts

C<Retry> sets the default number of attempts a ping will be sent
before it should be considered failed. It is 1 by default.

=item OneReply => 0|1

Set C<OneReply> to prevent the Ping component from waiting the full
timeout period for replies.  Normally the ICMP protocol allows for
multiple replies to a single request, so it's proper to wait for late
responses.  This option disables the wait, ending the ping transaction
at the first response.  Any subsequent responses will be silently
ignored.

C<OneReply> is disabled by default, and a single successful request
will generate at least two responses.  The first response is a
successful ICMP ECHO REPLY event.  The second is an undefined response
event, signifying that the timeout period has ended.

A ping request will generate exactly one reply when C<OneReply> is
enabled.  This reply will represent either the first ICMP ECHO REPLY
to arrive or that the timeout period has ended.

=item Parallelism => $limit

Parallelism sets POE::Component::Client::Ping's maximum number of
simultaneous ICMP requests.  Higher numbers speed up the processing of
large host lists, up to the point where the operating system or
network becomes oversaturated and begin to drop packets.

The difference can be dramatic.  A tuned Parallelism can enable
responses down to 1ms, depending on the network, although it will take
longer to get through the hosts list.

  Pinging 762 hosts at Parallelism=64
  Starting to ping hosts.
  Pinged 10.0.0.25       - Response from 10.0.0.25       in  0.002s
  Pinged 10.0.0.200      - Response from 10.0.0.200      in  0.003s
  Pinged 10.0.0.201      - Response from 10.0.0.201      in  0.001s

  real  1m1.923s
  user  0m2.584s
  sys   0m0.207s

Responses will take significantly longer with an untuned Parallelism,
but the total run time will be quicker.

  Pinging 762 hosts at Parallelism=500
  Starting to ping hosts.
  Pinged 10.0.0.25       - Response from 10.0.0.25       in  3.375s
  Pinged 10.0.0.200      - Response from 10.0.0.200      in  1.258s
  Pinged 10.0.0.201      - Response from 10.0.0.201      in  2.040s

  real  0m13.410s
  user  0m6.390s
  sys   0m0.290s

Excessively high parallelism values may saturate the OS or network,
resulting in few or no responses.

  Pinging 762 hosts at Parallelism=1000
  Starting to ping hosts.

  real  0m20.520s
  user  0m7.896s
  sys   0m0.297s

By default, POE::Component::Client::Ping will guess at an optimal
Parallelism value based on the raw socket receive buffer size and the
operating system's nominal ICMP packet size.  The latter figure is
3000 octets for Linux and 100 octets for other systems.  ICMP packets
are generally under 90 bytes, but operating systems may use
alternative numbers when calculating buffer capacities.  The component
tries to mimic calculations observed in the wild.

When in doubt, experiment with different Parallelism values and use
the one that works best.

=item BufferSize => $bytes

If set, then the size of the receive buffer of the raw socket will be
modified to the given value. The default size of the receive buffer is
operating system dependent. If the buffer cannot be set to the given
value, a warning will be generated but the system will continue
working. Note that if the buffer is set too small and too many ping
replies arrive at the same time, then the operating system may discard
the ping replies and mistakenly cause this component to believe the
ping to have timed out. In this case, you will typically see discards
being noted in the counters displayed by 'netstat -s'.

Increased BufferSize values can expand the practical limit for
Parallelism.

=item AlwaysDecodeAddress => 0|1

If set, then any input addresses will always be looked up,
even if the hostname happens to be only 4 characters in size.
Ideally, you should be passing addresses in to the system to
avoid slow hostname lookups, but if you must use hostnames
and there is a possibility that you might have short
hostnames, then you should set this.

=item Payload => $bytes

Sets the ICMP payload (data bytes).  Otherwise the component generates
56 data bytes internally.  Note that some firewalls will discard ICMP
packets with nonstandard payload sizes.

=back

Sessions communicate asynchronously with the Client::Ping component.
They post ping requests to it, and they receive pong events back.

Requests are posted to the component's "ping" handler.  They include
the name of an event to post back, an address to ping, and an optional
amount of time to wait for responses.  The address may be a numeric
dotted quad, a packed inet_aton address, or a host name.  Host names
are not recommended: they must be looked up for every ping request,
and DNS lookups can be very slow.  The optional timeout overrides the
one set when C<spawn> is called.

Ping responses come with two array references:

  my ($request, $response) = @_[ARG0, ARG1];

C<$request> contains information about the original request:

  my (
    $req_address, $req_timeout, $req_time, $req_user_args,
  ) = @$request;

=over 2

=item C<$req_address>

This is the original request address.  It matches the address posted
along with the original "ping" request.

It is useful along with C<$req_user_args> for pairing requests with
their corresponding responses.

=item C<$req_timeout>

This is the original request timeout.  It's either the one passed with
the "ping" request or the default timeout set with C<spawn>.

=item C<$req_time>

This is the time that the "ping" event was received by the Ping
component.  It is a real number based on the current system's time()
epoch.

=item C<$req_user_args>

This is a scalar containing arbitrary data that can be sent along with
a request.  It's often used to provide continuity between requests and
their responses.  C<$req_user_args> may contain a reference to some
larger data structure.

To use it, replace the response event with an array reference in the
original request.  The array reference should contain two items: the
actual response event and a scalar with the context data the program
needs back.  See the SYNOPSIS for an example.

=back

C<$response> contains information about the ICMP ping response.  There
may be multiple responses for a single request.

  my ($response_address, $roundtrip_time, $reply_time, $reply_ttl) =
  @$response;

=over 2

=item C<$response_address>

This is the address that responded to the ICMP echo request.  It may
be different than C<$request_address>, especially if the request was
sent to a broadcast address.

C<$response_address> will be undefined if C<$request_timeout> seconds
have elapsed.  This marks the end of responses for a given request.
Programs can assume that no more responses will be sent for the
request address.  They may use this marker to initiate another ping
request.

=item C<$roundtrip_time>

This is the number of seconds that elapsed between the ICMP echo
request's transmission and its corresponding response's receipt.  It's
a real number. This is purely the trip time and does *not* include any
time spent queueing if the system's parallelism limit caused the ping
transmission to be delayed.

=item C<$reply_time>

This is the time when the ICMP echo response was received.  It is a
real number based on the current system's time() epoch.

=item C<$reply_ttl>

This is the ttl for the echo response packet we received.

=back

If the ":const" tagset is imported the following constants will be
exported:

REQ_ADDRESS, REQ_TIMEOUT, REQ_TIME
REQ_USER_ARGS, RES_ADDRESS, RES_ROUNDTRIP, RES_TIME, RES_TTL

=head1 SEE ALSO

This component's ICMP ping code was lifted from Net::Ping, which is an
excellent module when you only need to ping one host at a time.

See POE, of course, which includes a lot of documentation about how
POE works.

Also see the test program, t/01_ping.t, in the component's
distribution.

=head1 BUG TRACKER

https://rt.cpan.org/Dist/Display.html?Queue=POE-Component-Client-Ping

=head1 REPOSITORY

http://github.com/rcaputo/poe-component-client-ping/

=head1 OTHER RESOURCES

http://search.cpan.org/dist/POE-Component-Client-Ping/

=head1 AUTHOR & COPYRIGHTS

POE::Component::Client::Ping is Copyright 1999-2009 by Rocco Caputo.
All rights are reserved.  POE::Component::Client::Ping is free
software; you may redistribute it and/or modify it under the same
terms as Perl itself.

You can learn more about POE at http://poe.perl.org/

=cut
