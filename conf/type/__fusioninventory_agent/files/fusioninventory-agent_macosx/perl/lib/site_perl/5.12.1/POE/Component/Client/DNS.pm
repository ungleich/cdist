# License and documentation are after __END__.
# vim: ts=2 sw=2 expandtab

package POE::Component::Client::DNS;

use strict;

use vars qw($VERSION);
$VERSION = '1.051';

use Carp qw(croak);

use Socket qw(unpack_sockaddr_in inet_ntoa);
use Net::DNS;
use POE;

use constant DEBUG => 0;

# A hosts file we found somewhere.

my $global_hosts_file;

# Object fields.  "SF" stands for "self".

sub SF_ALIAS       () { 0 }
sub SF_TIMEOUT     () { 1 }
sub SF_NAMESERVERS () { 2 }
sub SF_RESOLVER    () { 3 }
sub SF_HOSTS_FILE  () { 4 }
sub SF_HOSTS_MTIME () { 5 }
sub SF_HOSTS_CTIME () { 6 }
sub SF_HOSTS_INODE () { 7 }
sub SF_HOSTS_CACHE () { 8 }
sub SF_HOSTS_BYTES () { 9 }
sub SF_SHUTDOWN    () { 10 }
sub SF_REQ_BY_SOCK () { 11 }

# Spawn a new PoCo::Client::DNS session.  This basically is a
# constructor, but it isn't named "new" because it doesn't create a
# usable object.  Instead, it spawns the object off as a session.

sub spawn {
  my $type = shift;
  croak "$type requires an even number of parameters" if @_ % 2;
  my %params = @_;

  my $alias = delete $params{Alias};
  $alias = "resolver" unless $alias;

  my $timeout = delete $params{Timeout};
  $timeout = 90 unless $timeout;

  my $nameservers = delete $params{Nameservers};
  my $resolver = Net::DNS::Resolver->new();
  $nameservers ||= [ $resolver->nameservers() ];

  my $hosts = delete $params{HostsFile};

  croak(
    "$type doesn't know these parameters: ", join(', ', sort keys %params)
  ) if scalar keys %params;

  my $self = bless [
    $alias,                     # SF_ALIAS
    $timeout,                   # SF_TIMEOUT
    $nameservers,               # SF_NAMESERVERS
    $resolver,                  # SF_RESOLVER
    $hosts,                     # SF_HOSTS_FILE
    0,                          # SF_HOSTS_MTIME
    0,                          # SF_HOSTS_CTIME
    0,                          # SF_HOSTS_INODE
    { },                        # SF_HOSTS_CACHE
    0,                          # SF_HOSTS_BYTES
    0,                          # SF_SHUTDOWN
  ], $type;

  # Set the list of nameservers, if one was supplied.
  # May redundantly reset itself.
  $self->[SF_RESOLVER]->nameservers(@$nameservers);

  POE::Session->create(
    object_states => [
      $self => {
        _default         => "_dns_default",
        _start           => "_dns_start",
        _stop            => "_dns_stop",
        got_dns_response => "_dns_response",
        resolve          => "_dns_resolve",
        send_request     => "_dns_do_request",
        shutdown         => "_dns_shutdown",
      },
    ],
  );

  return $self;
}

# Public method interface.

sub resolve {
  my $self = shift;
  croak "resolve() needs an even number of parameters" if @_ % 2;
  my %args = @_;

  croak "resolve() must include an 'event'"  unless exists $args{event};
  croak "resolve() must include a 'context'" unless exists $args{context};
  croak "resolve() must include a 'host'"    unless exists $args{host};

  $poe_kernel->call( $self->[SF_ALIAS], "resolve", \%args );

  return undef;
}

sub shutdown {
  my $self = shift;
  $poe_kernel->call( $self->[SF_ALIAS], "shutdown" );
}

# Start the resolver session.  Record the parameters which were
# validated in spawn(), create the internal resolver object, and set
# an alias which we'll be known by.

sub _dns_start {
  my ($object, $kernel) = @_[OBJECT, KERNEL];
  $kernel->alias_set($object->[SF_ALIAS]);
}

# Dummy handler to avoid ASSERT_DEFAULT problems.

sub _dns_stop {
  # do nothing
}

# Receive a request.  Version 4 API.  This uses extra reference counts
# to keep the client sessions alive until responses are ready.

sub _dns_resolve {
  my ($self, $kernel, $sender, $event, $host, $type, $class) =
    @_[OBJECT, KERNEL, SENDER, ARG0, ARG1, ARG2, ARG3];

  my $debug_info =
    "in Client::DNS request at $_[CALLER_FILE] line $_[CALLER_LINE]\n";

  my ($api_version, $context, $timeout);

  # Version 3 API.  Pass the entire request as a hash.
  if (ref($event) eq 'HASH') {
    my %args = %$event;

    $type = delete $args{type};
    $type = "A" unless $type;

    $class = delete $args{class};
    $class = "IN" unless $class;

    $event = delete $args{event};
    die "Must include an 'event' $debug_info" unless $event;

    $context = delete $args{context};
    die "Must include a 'context' $debug_info" unless $context;

    $timeout = delete $args{timeout};

    $host = delete $args{host};
    die "Must include a 'host' $debug_info" unless $host;

    $api_version = 3;
  }

  # Parse user args from the magical $response format.  Version 2 API.

  elsif (ref($event) eq "ARRAY") {
    $context     = $event;
    $event       = shift @$context;
    $api_version = 2;
  }

  # Whee.  Version 1 API.

  else {
    $context     = [ ];
    $api_version = 1;
  }

  # Default the request's timeout.
  $timeout = $self->[SF_TIMEOUT] unless $timeout;

  # Set an extra reference on the sender so it doesn't go away.
  $kernel->refcount_increment($sender->ID, __PACKAGE__);

  # If it's an IN type A request, check /etc/hosts or the equivalent.
  # -><- This is not always the right thing to do, but it's more right
  # more often than never checking at all.

  if (($type eq "A" or $type eq "AAAA") and $class eq "IN") {
    my $address = $self->check_hosts_file($host, $type);

    if (defined $address) {
      # Pretend the request went through a name server.

      my $packet = Net::DNS::Packet->new($address, $type, "IN");
      $packet->push(
        "answer",
        Net::DNS::RR->new(
          Name    => $host,
          TTL     => 1,
          Class   => $class,
          Type    => $type,
          Address => $address,
        )
      );

      # Send the response immediately, and return.

      _send_response(
        api_ver  => $api_version,
        sender   => $sender,
        event    => $event,
        host     => $host,
        type     => $type,
        class    => $class,
        context  => $context,
        response => $packet,
        error    => "",
      );

      return;
    }
  }

  # We are here.  Yield off to the state where the request will be
  # sent.  This is done so that the do-it state can yield or delay
  # back to itself for retrying.

  my $now = time();
  $kernel->call(
    $self->[SF_ALIAS],
    send_request => {
      sender    => $sender,
      event     => $event,
      host      => $host,
      type      => $type,
      class     => $class,
      context   => $context,
      started   => $now,
      ends      => $now + $timeout,
      api_ver   => $api_version,
      nameservers => [ $self->[SF_RESOLVER]->nameservers() ],
    }
  );
}

# Perform the real request.  May recurse to perform retries.

sub _dns_do_request {
  my ($self, $kernel, $req) = @_[OBJECT, KERNEL, ARG0];

  # Did the request time out?
  my $remaining = $req->{ends} - time();
  if ($remaining <= 0) {
    _send_response(
      %$req,
      response => undef,
      error    => "timeout",
    );
    return;
  }

  # Send the request.
  my $resolver_socket = $self->[SF_RESOLVER]->bgsend(
    $req->{host},
    $req->{type},
    $req->{class}
  );

  # The request failed?  Attempt to retry.

  unless ($resolver_socket) {
    $remaining = 1 if $remaining > 1;
    $kernel->delay_add(send_request => $remaining, $req);
    return;
  }

  # Set a timeout for the request, and watch the response socket for
  # activity.

  $self->[SF_REQ_BY_SOCK]->{$resolver_socket} = $req;

  $kernel->delay($resolver_socket, $remaining / 2, $resolver_socket);
  $kernel->select_read($resolver_socket, 'got_dns_response');

  # Save the socket for pre-emptive shutdown.
  $req->{resolver_socket} = $resolver_socket;
}

# A resolver query timed out.  Keep trying until we run out of time.
# Also, if the top nameserver is the one we tried, then cycle the
# nameservers.

sub _dns_default {
  my ($self, $kernel, $event, $args) = @_[OBJECT, KERNEL, ARG0, ARG1];
  my $socket = $args->[0];

  return unless defined($socket) and $event eq $socket;

  my $req = delete $self->[SF_REQ_BY_SOCK]->{$socket};
  return unless $req;

  # Stop watching the socket.
  $kernel->select_read($socket);

  # No more time remaining?  We must time out.
  my $remaining = $req->{ends} - time();
  if ($remaining <= 0) {
    _send_response(
      %$req,
      response => undef,
      error    => "timeout",
    );
    return;
  }

  # There remains time.  Let's try again.

  # The nameserver we tried has failed us.  If it's the top
  # nameserver in Net::DNS's list, then send it to the back and retry.

  my @nameservers = $self->[SF_RESOLVER]->nameservers();
  if ($nameservers[0] eq $req->{nameservers}[0]) {
    push @nameservers, shift(@nameservers);
    $self->[SF_RESOLVER]->nameservers(@nameservers);
    $req->{nameservers} = \@nameservers;
  }

  # Retry.
  $kernel->yield(send_request => $req);

  # Don't accidentally handle signals.
  return;
}

# A resolver query generated a response.  Post the reply back.

sub _dns_response {
  my ($self, $kernel, $socket) = @_[OBJECT, KERNEL, ARG0];

  my $req = delete $self->[SF_REQ_BY_SOCK]->{$socket};
  return unless $req;

  # Turn off the timeout for this request, and stop watching the
  # resolver connection.
  $kernel->delay($socket);
  $kernel->select_read($socket);

  # Read the DNS response.
  my $packet = $self->[SF_RESOLVER]->bgread($socket);

  # Set the packet's answerfrom field, if the packet was received ok
  # and an answerfrom isn't already included.  This uses the
  # documented peerhost() method

  if (defined $packet and !defined $packet->answerfrom) {
    my $answerfrom = getpeername($socket);
    if (defined $answerfrom) {
      $answerfrom = (unpack_sockaddr_in($answerfrom))[1];
      $answerfrom = inet_ntoa($answerfrom);
      $packet->answerfrom($answerfrom);
    }
  }

  # Send the response.
  _send_response(
    %$req,
    response => $packet,
    error    => $self->[SF_RESOLVER]->errorstring(),
  );
}

sub _dns_shutdown {
  my ($self, $kernel) = @_[OBJECT, KERNEL];

  # Clean up all pending socket timeouts and selects.
  foreach my $socket (keys %{$self->[SF_REQ_BY_SOCK]}) {
    DEBUG and warn "SHT: Shutting down resolver socket $socket";
    my $req = delete $self->[SF_REQ_BY_SOCK]->{$socket};

    $kernel->delay($socket);
    $kernel->select($req->{resolver_socket});

    # Let the client session go.
    DEBUG and warn "SHT: Releasing sender ", $req->{sender}->ID;
    $poe_kernel->refcount_decrement($req->{sender}->ID, __PACKAGE__);
  }

  # Clean out our global timeout.
  $kernel->delay(send_request => undef);

  # Clean up our global alias.
  DEBUG and warn "SHT: Resolver removing alias $self->[SF_ALIAS]";
  $kernel->alias_remove($self->[SF_ALIAS]);

  $self->[SF_SHUTDOWN] = 1;
}

# Send a response.  Fake a postback for older API versions.  Send a
# nice, tidy hash for new ones.  Also decrement the reference count
# that's keeping the requester session alive.

sub _send_response {
  my %args = @_;

  # Simulate a postback for older API versions.

  my $api_version = delete $args{api_ver};
  if ($api_version < 3) {
    $poe_kernel->post(
      $args{sender}, $args{event},
      [ $args{host}, $args{type}, $args{class}, @{$args{context}} ],
      [ $args{response}, $args{error} ],
    );
  }

  # New, fancy, shiny hash-based response.

  else {
    $poe_kernel->post(
      $args{sender}, $args{event},
      {
        host     => $args{host},
        type     => $args{type},
        class    => $args{class},
        context  => $args{context},
        response => $args{response},
        error    => $args{error},
      }
    );
  }

  # Let the client session go.
  $poe_kernel->refcount_decrement($args{sender}->ID, __PACKAGE__);
}

### NOT A POE EVENT HANDLER

sub check_hosts_file {
  my ($self, $host, $type) = @_;

  # Use the hosts file that was specified, or find one.
  my $use_hosts_file;
  if (defined $self->[SF_HOSTS_FILE]) {
    $use_hosts_file = $self->[SF_HOSTS_FILE];
  }
  else {
    # Discard the hosts file name if it has disappeared.
    $global_hosts_file = undef if (
      $global_hosts_file and !-f $global_hosts_file
    );

    # Try to find a hosts file if one doesn't exist.
    unless ($global_hosts_file) {
      my @candidates = (
        "/etc/hosts",
      );

      if ($^O eq "MSWin32" or $^O eq "Cygwin") {
        my $sys_dir;
        $sys_dir = $ENV{SystemRoot} || "c:\\Windows";
        push(
          @candidates,
          "$sys_dir\\System32\\Drivers\\Etc\\hosts",
          "$sys_dir\\System\\Drivers\\Etc\\hosts",
          "$sys_dir\\hosts",
        );
      }

      foreach my $candidate (@candidates) {
        next unless -f $candidate;
        $global_hosts_file = $candidate;
        $global_hosts_file =~ s/\\+/\//g;
        $self->[SF_HOSTS_MTIME] = 0;
        $self->[SF_HOSTS_CTIME] = 0;
        $self->[SF_HOSTS_INODE] = 0;
        last;
      }
    }

    # We use the global hosts file.
    $use_hosts_file = $global_hosts_file;
  }

  # Still no hosts file?  Don't bother reading it, then.
  return unless $use_hosts_file;

  # Blow away our cache if the file doesn't exist.
  $self->[SF_HOSTS_CACHE] = { } unless -f $use_hosts_file;

  # Reload the hosts file if times have changed.
  my ($inode, $bytes, $mtime, $ctime) = (stat $use_hosts_file)[1, 7, 9,10];
  unless (
    $self->[SF_HOSTS_MTIME] == ($mtime || -1) and
    $self->[SF_HOSTS_CTIME] == ($ctime || -1) and
    $self->[SF_HOSTS_INODE] == ($inode || -1) and
    $self->[SF_HOSTS_BYTES] == ($bytes || -1)
  ) {
    return unless open(HOST, "<", $use_hosts_file);

    my %cached_hosts;
    while (<HOST>) {
      next if /^\s*\#/; # skip all-comment lines
      next if /^\s*$/;  # skip empty lines
      chomp;

      # Bare split discards leading and trailing whitespace.
      my ($address, @aliases) = split;
      next unless defined $address;

      my $type = ($address =~ /:/) ? "AAAA" : "A";
      foreach my $alias (@aliases) {
        $cached_hosts{$alias}{$type}{$address} = 1;
      }
    }
    close HOST;

    # Normalize our cached hosts.
    while (my ($alias, $type_rec) = each %cached_hosts) {
      while (my ($type, $address_rec) = each %$type_rec) {
        $cached_hosts{$alias}{$type} = (keys %$address_rec)[0];
      }
    }

    $self->[SF_HOSTS_CACHE] = \%cached_hosts;
    $self->[SF_HOSTS_MTIME] = $mtime;
    $self->[SF_HOSTS_CTIME] = $ctime;
    $self->[SF_HOSTS_INODE] = $inode;
    $self->[SF_HOSTS_BYTES] = $bytes;
  }

  # Return whatever match we have.
  return unless (
    (exists $self->[SF_HOSTS_CACHE]{$host}) and
    (exists $self->[SF_HOSTS_CACHE]{$host}{$type})
  );
  return $self->[SF_HOSTS_CACHE]{$host}{$type};
}

### NOT A POE EVENT HANDLER

sub get_resolver {
  my $self = shift;
  return $self->[SF_RESOLVER];
}

1;

__END__

=head1 NAME

POE::Component::Client::DNS - non-blocking, concurrent DNS requests

=head1 SYNOPSIS

  use POE qw(Component::Client::DNS);

  my $named = POE::Component::Client::DNS->spawn(
    Alias => "named"
  );

  POE::Session->create(
    inline_states  => {
      _start   => \&start_tests,
      response => \&got_response,
    }
  );

  POE::Kernel->run();
  exit;

  sub start_tests {
    my $response = $named->resolve(
      event   => "response",
      host    => "localhost",
      context => { },
    );
    if ($response) {
      $_[KERNEL]->yield(response => $response);
    }
  }

  sub got_response {
    my $response = $_[ARG0];
    my @answers = $response->{response}->answer();

    foreach my $answer (@answers) {
      print(
        "$response->{host} = ",
        $answer->type(), " ",
        $answer->rdatastr(), "\n"
      );
    }
  }

=head1 DESCRIPTION

POE::Component::Client::DNS provides a facility for non-blocking,
concurrent DNS requests.  Using POE, it allows other tasks to run
while waiting for name servers to respond.

=head1 PUBLIC METHODS

=over 2

=item spawn

A program must spawn at least one POE::Component::Client::DNS instance
before it can perform background DNS lookups.  Each instance
represents a connection to a name server, or a pool of them.  If a
program only needs to request DNS lookups from one server, then you
only need one POE::Component::Client::DNS instance.

As of version 0.98 you can override the default timeout per request.
From this point forward there is no need to spawn multiple instances o
affect different timeouts for each request.

PoCo::Client::DNS's C<spawn> method takes a few named parameters:

Alias sets the component's alias.  Requests will be posted to this
alias.  The component's alias defaults to "resolver" if one is not
provided.  Programs spawning more than one DNS client component must
specify aliases for N-1 of them, otherwise alias collisions will
occur.

  Alias => $session_alias,  # defaults to "resolver"

Timeout sets the component's default timeout.  The timeout may be
overridden per request.  See the "request" event, later on.  If no
Timeout is set, the component will wait 90 seconds per request by
default.

Timeouts may be set to real numbers.  Timeouts are more accurate if
you have Time::HiRes installed.  POE (and thus this component) will
use Time::HiRes automatically if it's available.

  Timeout => $seconds_to_wait,  # defaults to 90

Nameservers holds a reference to a list of name servers to try.  The
list is passed directly to Net::DNS::Resolver's nameservers() method.
By default, POE::Component::Client::DNS will query the name servers
that appear in /etc/resolv.conf or its equivalent.

  Nameservers => \@name_servers,  # defaults to /etc/resolv.conf's

HostsFile (optional) holds the name of a specific hosts file to use
for resolving hardcoded addresses.  By default, it looks for a file
named /etc/hosts.

On Windows systems, it may look in the following other places:

  $ENV{SystemRoot}\System32\Drivers\Etc\hosts
  $ENV{SystemRoot}\System\Drivers\Etc\hosts
  $ENV{SystemRoot}\hosts

=item resolve

resolve() requests the component to resolve a host name.  It will
return a hash reference (described in RESPONSE MESSAGES, below) if it
can honor the request immediately (perhaps from a cache).  Otherwise
it returns undef if a resolver must be consulted asynchronously.

Requests are passed as a list of named fields.

  $resolver->resolve(
    class   => $dns_record_class,  # defaults to "IN"
    type    => $dns_record_type,   # defaults to "A"
    host    => $request_host,      # required
    context => $request_context,   # required
    event   => $response_event,    # required
    timeout => $request_timeout,   # defaults to spawn()'s Timeout
  );

The "class" and "type" fields specify what kind of information to
return about a host.  Most of the time internet addresses are
requested for host names, so the class and type default to "IN"
(internet) and "A" (address), respectively.

The "host" field designates the host to look up.  It is required.

The "event" field tells the component which event to send back when a
response is available.  It is required, but it will not be used if
resolve() can immediately return a cached response.

"timeout" tells the component how long to wait for a response to this
request.  It defaults to the "Timeout" given at spawn() time.

"context" includes some external data that links responses back to
their requests.  The context data is provided by the program that uses
POE::Component::Client::DNS.  The component will pass the context back
to the program without modification.  The "context" parameter is
required, and may contain anything that fits in a scalar.

=item shutdown

shutdown() causes the component to terminate gracefully. It will finish
serving pending requests then close down.

=item get_resolver

POE::Component::Client::DNS uses a Net::DNS::Resolver object
internally.  get_resolver() returns that object so it may be
interrogated or modified.  See L<Net::DNS::Resolver> for options.

Set the resolver to check on nonstandard port 1153:

  $poco_client_dns->resolver()->port(1153);

=head1 RESPONSE MESSAGES

POE::Component::Client::DNS responds in one of two ways.  Its
resolve() method will return a response immediately if it can be found
in the component's cache.  Otherwise the component posts the response
back in $_[ARG0].  In either case, the response is a hash reference
containing the same fields:

  host     => $request_host,
  type     => $request_type,
  class    => $request_class,
  context  => $request_context,
  response => $net_dns_packet,
  error    => $net_dns_error,

The "host", "type", "class", and "context" response fields are
identical to those given in the request message.

"response" contains a Net::DNS::Packet object on success or undef if
the lookup failed.  The Net::DNS::Packet object describes the response
to the program's request.  It may contain several DNS records.  Please
consult L<Net::DNS> and L<Net::DNS::Packet> for more information.

"error" contains a description of any error that has occurred.  It is
only valid if "response" is undefined.

=head1 SEE ALSO

L<POE> - POE::Component::Client::DNS builds heavily on POE.

L<Net::DNS> - This module uses Net::DNS internally.

L<Net::DNS::Packet> - Responses are returned as Net::DNS::Packet
objects.

=head1 DEPRECATIONS

The older, list-based interfaces are no longer documented as of
version 0.98.  They are being phased out.  The method-based interface,
first implementedin version 0.98, will replace the deprecated
interfaces after a six-month phase-out period.

Version 0.98 was released in October of 2004.  The deprecated
interfaces will continue to work without warnings until January 2005.

As of January 2005, programs that use the deprecated interfaces will
continue to work, but they will generate mandatory warnings.  Those
warnings will persist until April 2005.

As of April 2005 the mandatory warnings will be upgraded to mandatory
errors.  Support for the deprecated interfaces will be removed
entirely.

=head1 BUG TRACKER

https://rt.cpan.org/Dist/Display.html?Queue=POE-Component-Client-DNS

=head1 REPOSITORY

http://github.com/rcaputo/poe-component-client-dns

=head1 OTHER RESOURCES

http://search.cpan.org/dist/POE-Component-Client-DNS/

=head1 AUTHOR & COPYRIGHTS

POE::Component::Client::DNS is Copyright 1999-2009 by Rocco Caputo.
All rights are reserved.  POE::Component::Client::DNS is free
software; you may redistribute it and/or modify it under the same
terms as Perl itself.

Postback arguments were contributed by tag.

=cut
