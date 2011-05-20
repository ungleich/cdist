package POE::Component::Client::HTTP::RequestFactory;
use strict;
use warnings;

use Carp;
use POE::Component::Client::HTTP::Request;
use POE::Component::Client::HTTP;

use constant FCT_AGENT           => 0;
use constant FCT_STREAMING       => 1;
use constant FCT_MAXSIZE         => 2;
use constant FCT_PROTOCOL        => 3;
use constant FCT_COOKIEJAR       => 4;
use constant FCT_FROM            => 5;
use constant FCT_NOPROXY         => 6;
use constant FCT_HTTP_PROXY      => 7;
use constant FCT_FOLLOWREDIRECTS => 8;
use constant FCT_TIMEOUT         => 9;
use constant DEBUG               => 0;
use constant DEFAULT_BLOCK_SIZE  => 4096;

our $VERSION = "0.895";

=head1 CONSTRUCTOR

=head2 new

Create a new request factory object. It expects its parameters in a
hashref.

The following parameters are accepted.  They are explained in detail
in L<POE::Component::Client::HTTP>.

=over 4

=item 

Agent

=item

MaxSize

=item

Streaming

=item

Protocol

=item

From

=item

CookieJar

=item

NoProxy

=item

Proxy

=item

FollowRedirects

=item

Timeout

=back

=cut

sub new {
  my ($class, $params) = @_;

  croak __PACKAGE__ . "expects its arguments in a hashref"
    unless (!defined ($params) or ref($params) eq 'HASH');

  # Accept an agent, or a reference to a list of agents.
  my $agent = delete $params->{Agent};
  $agent = [] unless defined $agent;
  $agent = [ $agent ] unless ref($agent);
  unless (ref($agent) eq "ARRAY") {
    croak "Agent must be a scalar or a reference to a list of agent strings";
  }

  my $v = $POE::Component::Client::HTTP::VERSION;
  push(
    @$agent,
    sprintf(
      'POE-Component-Client-HTTP/%s (perl; N; POE; en; rv:%f)',
      $v, $v
    )
  ) unless @$agent;

  my $max_size = delete $params->{MaxSize};

  my $streaming = delete $params->{Streaming};

  my $protocol = delete $params->{Protocol};
  $protocol = 'HTTP/1.1' unless defined $protocol and length $protocol;

  my $cookie_jar       = delete $params->{CookieJar};
  my $from             = delete $params->{From};
  my $no_proxy         = delete $params->{NoProxy};
  my $proxy            = delete $params->{Proxy};
  my $follow_redirects = delete $params->{FollowRedirects} || 0;
  my $timeout          = delete $params->{Timeout};

  # Process HTTP_PROXY and NO_PROXY environment variables.

  $proxy    = $ENV{HTTP_PROXY} || $ENV{http_proxy} unless defined $proxy;
  $no_proxy = $ENV{NO_PROXY}   || $ENV{no_proxy}   unless defined $no_proxy;

  # Translate environment variable formats into internal versions.

  $class->parse_proxy($proxy) if defined $proxy;

  if (defined $no_proxy) {
    unless (ref($no_proxy) eq 'ARRAY') {
      $no_proxy = [ split(/\s*\,\s*/, $no_proxy) ];
    }
  }

  $timeout = 180 unless (defined $timeout and $timeout > 0);

  my $self = [
    $agent,            # FCT_AGENT
    $streaming,        # FCT_STREAMING
    $max_size,         # FCT_MAXSIZE
    $protocol,         # FCT_PROTOCOL
    $cookie_jar,       # FCT_COOKIEJAR
    $from,             # FCT_FROM
    $no_proxy,         # FCT_NOPROXY
    $proxy,            # FCT_HTTP_PROXY
    $follow_redirects, # FCT_FOLLOWREDIRECTS
    $timeout,          # FCT_TIMEOUT
  ];

  return bless $self, $class;
}

=head1 METHODS

=head2 timeout [$timeout]

Method that lets you query and/or change the timeout value for requests
created by this factory.

=cut

sub timeout {
  my ($self, $timeout) = @_;

  if (defined $timeout) {
    $self->[FCT_TIMEOUT] = $timeout;
  }
  return $self->[FCT_TIMEOUT];
}

=head2 is_streaming

Accessor for the Streaming parameter

=cut

sub is_streaming {
  my ($self) = @_;

  DEBUG and warn(
    "FCT: this is "
    . ($self->[FCT_STREAMING] ? "" : "not ")
    . "streaming"
  );
  return $self->[FCT_STREAMING];
}

=head2 agent

Accessor to the Agent parameter

=cut

sub agent {
  my ($self) = @_;

  return $self->[FCT_AGENT]->[rand @{$self->[FCT_AGENT]}];
}

=head2 from

getter/setter for the From parameter

=cut

sub from {
  my ($self) = @_;

  if (defined $self->[FCT_FROM] and length $self->[FCT_FROM]) {
    return $self->[FCT_FROM];
  }
  return undef;
}

=head2 create_request

Creates a new L<POE::Component::Client::HTTP::Request>

=cut

sub create_request {
  my ($self, $http_request, $response_event, $tag,
      $progress_event, $proxy_override, $sender) =  @_;

  # Add a protocol if one isn't included.
  $http_request->protocol( $self->[FCT_PROTOCOL] ) unless (
    defined $http_request->protocol()
    and length $http_request->protocol()
  );


  # Add the User-Agent: header if one isn't included.
  unless (defined $http_request->user_agent()) {
    $http_request->user_agent($self->agent);
  }

  # Add a From: header if one isn't included.
  if (defined $self->from) {
    my $req_from = $http_request->from();
    unless (defined $req_from and length $req_from) {
      $http_request->from( $self->from );
    }
  }

  # Add a Content-Length header if this request has content but
  # doesn't have a Content-Length header already.  Also, don't do it
  # if the content is a reference, as this means we're streaming via
  # callback.
  if (
    length($http_request->content()) and
    !ref($http_request->content()) and
    !$http_request->content_length()
  ) {
    use bytes;
    $http_request->content_length(length($http_request->content()));
  }

  my ($last_request, $postback);
  if (ref($response_event)) {
    $last_request = $response_event;
    $postback = $last_request->postback;
  }
  else {
    $postback = $sender->postback( $response_event, $http_request, $tag );
  }
  # Create a progress postback if requested.
  my $progress_postback;
  if (defined $progress_event) {
    if (ref $progress_event) {
      # The given progress event appears to already
      # be a postback, so use it.  This is needed to
      # propagate the postback through redirects.
      $progress_postback = $progress_event;
    }
    else {
      $progress_postback = $sender->postback(
        $progress_event,
        $http_request,
        $tag
      );
    }
  }

  # If we have a cookie jar, have it add the appropriate headers.
  # LWP rocks!

  if (defined $self->[FCT_COOKIEJAR]) {
    $self->[FCT_COOKIEJAR]->add_cookie_header($http_request);
  }

  # MEXNIX 2002-06-01: If we have a proxy set, and the request URI is
  # not in our no_proxy, then use the proxy.  Otherwise use the
  # request URI.
  #
  # RCAPUTO 2006-03-23: We only support http proxying right now.
  # Avoid proxying if this isn't an http request.
  my $proxy = $proxy_override;
  if ($http_request->uri->scheme() eq "http") {
    $proxy ||= $self->[FCT_HTTP_PROXY];
  }

  if (defined $proxy) {
  # This request qualifies for proxying.  Replace the host and port
  # with the proxy's host and port.  This comes after the Host:
  # header is set, so it doesn't break the request object.
    my $host = $http_request->uri->host;

    undef $proxy if (
      !defined($host) or
      _in_no_proxy ($host, $self->[FCT_NOPROXY])
    );
  }

  my $request = POE::Component::Client::HTTP::Request->new (
    Request => $http_request,
    Proxy => $proxy,
    Postback => $postback,
    #Tag => $tag, # TODO - Is this needed for anything?
    Progress => $progress_postback,
    Factory => $self,
  );

  if (defined $last_request) {
    $request->does_redirect($last_request);
  }
  return $request;
}

# Determine whether a host is in a no-proxy list.
# {{{ _in_no_proxy

sub _in_no_proxy {
  my ($host, $no_proxy) = @_;

  foreach my $no_proxy_domain (@$no_proxy) {
    return 1 if $host =~ /\Q$no_proxy_domain\E$/i;
  }
  return 0;
}

# }}} _in_no_proxy

=head2 max_response_size

Method to retrieve the maximum size of a response, as set by the
C<MaxSize> parameter to L<Client::HTTP>'s C<spawn()> method.

=cut

sub max_response_size {
  my ($self) = @_;

  return $self->[FCT_MAXSIZE];
}

=head2 block_size

Accessor for the Streaming parameter

=cut

sub block_size {
  my ($self) = @_;

  my $block_size = $self->[FCT_STREAMING] || DEFAULT_BLOCK_SIZE;
  $block_size = DEFAULT_BLOCK_SIZE if $block_size < 1;

  return $block_size;
}

=head2 frob_cookies $response

Store the cookies from the L<HTTP::Response> parameter passed into
our cookie jar

=cut

sub frob_cookies {
  my ($self, $response) = @_;

  if (defined $self->[FCT_COOKIEJAR]) {
    $self->[FCT_COOKIEJAR] ->extract_cookies($response);
  }
}

=head2 max_redirect_count [$count]

Function to get/set the maximum number of redirects to follow
automatically. This allows you to retrieve or modify the value
you passed with the FollowRedirects parameter to L<Client::HTTP>'s
C<spawn> method.

=cut

sub max_redirect_count {
  my ($self, $count) = @_;

  if (defined $count) {
    $self->[FCT_FOLLOWREDIRECTS] = $count;
  }
  return $self->[FCT_FOLLOWREDIRECTS];
}

=head2 parse_proxy $proxy

This static method is used for parsing proxies. The $proxy can be
array reference like [host, port] or comma separated string like
"http://1.2.3.4:80/,http://2.3.4.5:80/".

parse_proxy() returns an array reference of two-element tuples (also
array ferences), each containing a host and a port:

  [ [ host1, port1 ],
    [ host2, port2 ],
    ...
  ]

=cut

sub parse_proxy {
  my $proxy = $_[1];

  if (ref($proxy) eq 'ARRAY') {
    croak "Proxy must contain [HOST,PORT]" unless @$proxy == 2;
    $proxy = [ $proxy ];
  } else {
    my @proxies = split /\s*\,\s*/, $proxy;
    foreach (@proxies) {
      s/^http:\/+//;
      s/\/+$//;
      croak "Proxy must contain host:port" unless /^(.+):(\d+)$/;
      $_ = [ $1, $2 ];
    }
    if (@proxies) {
      $proxy = \@proxies;
    } else {
      undef $proxy; # Empty proxy list means not to use proxy
    }
  }

  $_[1] = $proxy;
}

1;
