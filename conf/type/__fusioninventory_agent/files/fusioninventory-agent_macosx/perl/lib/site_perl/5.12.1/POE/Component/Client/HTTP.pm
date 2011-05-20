package POE::Component::Client::HTTP;

# {{{ INIT

use strict;
#use bytes; # for utf8 compatibility

use constant DEBUG      => 0;
use constant DEBUG_DATA => 0;

use vars qw($VERSION);
$VERSION = '0.895';

use Carp qw(croak);
use HTTP::Response;
use Net::HTTP::Methods;
use Socket qw(sockaddr_in inet_ntoa);

use POE::Component::Client::HTTP::RequestFactory;
use POE::Component::Client::HTTP::Request qw(:states :fields);

BEGIN {
  local $SIG{'__DIE__'} = 'DEFAULT';
  #TODO: move this to Client::Keepalive?
  # Allow more finely grained timeouts if Time::HiRes is available.
  eval {
    require Time::HiRes;
    Time::HiRes->import("time");
  };
}

use POE qw(
  Driver::SysRW Filter::Stream
  Filter::HTTPHead Filter::HTTPChunk
  Component::Client::Keepalive
);

# The Internet Assigned Numbers Authority (IANA) acts as a registry
# for transfer-coding value tokens. Initially, the registry contains
# the following tokens: "chunked" (section 3.6.1), "identity" (section
# 3.6.2), "gzip" (section 3.5), "compress" (section 3.5), and
# "deflate" (section 3.5).

# FIXME - Haven't been able to test the compression options.
# Comments for each filter are what HTTP::Message use.  Methods
# without packages are from Compress::Zlib.

# FIXME - Is it okay to be mixing content and transfer encodings in
# this one table?

my %te_possible_filters = (
  'chunked'  => 'POE::Filter::HTTPChunk',
  'identity' => 'POE::Filter::Stream',
#  'gzip'     => 'POE::Filter::Zlib::Stream',  # Zlib: memGunzip
#  'x-gzip'   => 'POE::Filter::Zlib::Stream',  # Zlib: memGunzip
#  'x-bzip2'  => 'POE::Filter::Bzip2',         # Compress::BZip2::decompress
#  'deflate'  => 'POE::Filter::Zlib::Stream',  # Zlib: uncompress / inflate
#  'compress' => 'POE::Filter::LZW',           # unsupported
  # FIXME - base64 = MIME::Base64::decode
  # FIXME - quoted-printable = Mime::QuotedPrint::decode
);

my %te_filters;

while (my ($encoding, $filter) = each %te_possible_filters) {
  eval "use $filter";
  next if $@;
  $te_filters{$encoding} = $filter;
}

# The following defaults to 'chunked,identity' which is technically
# correct but arguably useless.  It also stomps on gzip'd transport
# because in the World Wild Web, Accept-Encoding is used to indicate
# gzip readiness, but the server responds with 'Content-Encoding:
# gzip', completely outside of TE encoding.
#
# Done this way so they appear in order of preference.
# FIXME - Is the order important here?

#my $accept_encoding = join(
#  ",",
#  grep { exists $te_filters{$_} }
#  qw(x-bzip2 gzip x-gzip deflate compress chunked identity)
#);

my %supported_schemes = (
  http  => 1,
  https => 1,
);

# }}} INIT

#------------------------------------------------------------------------------
# Spawn a new PoCo::Client::HTTP session.  This basically is a
# constructor, but it isn't named "new" because it doesn't create a
# usable object.  Instead, it spawns the object off as a separate
# session.
# {{{ spawn

sub spawn {
  my $type = shift;

  croak "$type requires an even number of parameters" if @_ % 2;

  my %params = @_;

  my $alias = delete $params{Alias};
  $alias = 'weeble' unless defined $alias and length $alias;

  my $bind_addr = delete $params{BindAddr};
  my $cm = delete $params{ConnectionManager};

  my $request_factory = POE::Component::Client::HTTP::RequestFactory->new(
    \%params
  );

  croak(
    "$type doesn't know these parameters: ",
    join(', ', sort keys %params)
  ) if scalar keys %params;

  POE::Session->create(
    inline_states => {
      _start  => \&_poco_weeble_start,
      _stop   => \&_poco_weeble_stop,
      _child  => sub { },

      # Public interface.
      request                => \&_poco_weeble_request,
      pending_requests_count => \&_poco_weeble_pending_requests_count,
      'shutdown'             => \&_poco_weeble_shutdown,
      cancel                 => \&_poco_weeble_cancel,

      # Client::Keepalive interface.
      got_connect_done  => \&_poco_weeble_connect_done,

      # ReadWrite interface.
      got_socket_input  => \&_poco_weeble_io_read,
      got_socket_flush  => \&_poco_weeble_io_flushed,
      got_socket_error  => \&_poco_weeble_io_error,

      # I/O timeout.
      got_timeout       => \&_poco_weeble_timeout,
      remove_request    => \&_poco_weeble_remove_request,
    },
    heap => {
      alias        => $alias,
      factory      => $request_factory,
      cm           => $cm,
      is_shut_down => 0,
      bind_addr    => $bind_addr,
    },
  );

  undef;
}

# }}} spawn
# ------------------------------------------------------------------------------
# {{{ _poco_weeble_start

sub _poco_weeble_start {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  $kernel->alias_set($heap->{alias});

  # have to do this here because it wants a current_session
  $heap->{cm} = POE::Component::Client::Keepalive->new(
    timeout => $heap->{factory}->timeout,
    $heap->{bind_addr} ? (bind_address => $heap->{bind_addr}) : (),
  ) unless ($heap->{cm});
}

# }}} _poco_weeble_start
#------------------------------------------------------------------------------
# {{{ _poco_weeble_stop

sub _poco_weeble_stop {
  my $heap = $_[HEAP];
  my $request = delete $heap->{request};

  foreach my $request_rec (values %$request) {
    $request_rec->remove_timeout();
    delete $heap->{ext_request_to_int_id}->{$request_rec->[REQ_HTTP_REQUEST]};
  }

  DEBUG and warn "Client::HTTP (alias=$heap->{alias}) stopped.";
}

# }}} _poco_weeble_stop
# {{{ _poco_weeble_pending_requests_count

sub _poco_weeble_pending_requests_count {
  my ($heap) = $_[HEAP];
  my $r = $heap->{request} || {};
  return scalar keys %$r;
}

# }}} _poco_weeble_pending_requests_count
#------------------------------------------------------------------------------
# {{{ _poco_weeble_request

sub _poco_weeble_request {
  my (
    $kernel, $heap, $sender,
    $response_event, $http_request, $tag, $progress_event,
    $proxy_override
  ) = @_[KERNEL, HEAP, SENDER, ARG0, ARG1, ARG2, ARG3, ARG4];

  unless (
    defined($http_request->uri->scheme) and
    length($http_request->uri->scheme) and
    $supported_schemes{$http_request->uri->scheme} and
    defined($http_request->uri->host) and
    length($http_request->uri->host)
  ) {
    my $rsp = HTTP::Response->new(
       400 => 'Bad Request', [],
       "<html>\n"
       . "<HEAD><TITLE>Error: Bad Request</TITLE></HEAD>\n"
       . "<BODY>\n"
       . "<H1>Error: Bad Request</H1>\n"
       . "Unsupported URI scheme\n"
       . "</BODY>\n"
       . "</HTML>\n"
    );
    $rsp->request($http_request);
    if (ref $response_event) {
      $response_event->postback->($rsp);
    } else {
      $kernel->post($sender, $response_event, [$http_request, $tag], [$rsp]);
    }
    return;
  }

  if ($heap->{is_shut_down}) {
    my $rsp = HTTP::Response->new(
       408 => 'Request timed out (component shut down)', [],
       "<html>\n"
       . "<HEAD><TITLE>Error: Request timed out (component shut down)"
       . "</TITLE></HEAD>\n"
       . "<BODY>\n"
       . "<H1>Error: Request Timeout</H1>\n"
       . "Request timed out (component shut down)\n"
       . "</BODY>\n"
       . "</HTML>\n"
      );
    $rsp->request($http_request);
    if (ref $response_event) {
      $response_event->postback->($rsp);
    } else {
      $kernel->post($sender, $response_event, [$http_request, $tag], [$rsp]);
    }
    return;
  }

  if (defined $proxy_override) {
    POE::Component::Client::HTTP::RequestFactory->parse_proxy($proxy_override);
  }

  my $request = $heap->{factory}->create_request(
    $http_request, $response_event, $tag, $progress_event,
    $proxy_override, $sender
  );
  $heap->{request}->{$request->ID} = $request;
  $heap->{ext_request_to_int_id}->{$http_request} = $request->ID;

  my @timeout;
  if ($heap->{factory}->timeout()) {
    @timeout = (
      timeout => $heap->{factory}->timeout()
    );
  }

  eval {
    # get a connection from Client::Keepalive
    $request->[REQ_CONN_ID] = $heap->{cm}->allocate(
      scheme  => $request->scheme,
      addr    => $request->host,
      port    => $request->port,
      context => $request->ID,
      event   => 'got_connect_done',
      @timeout,
    );
  };
  if ($@) {
    delete $heap->{request}->{$request->ID};
    delete $heap->{ext_request_to_int_id}->{$http_request};

    # we can reach here for things like host being invalid.
    $request->error(400, $@);
  }
}

# }}} _poco_weeble_request

#------------------------------------------------------------------------------
# {{{ _poco_weeble_connect_done

sub _poco_weeble_connect_done {
  my ($heap, $response) = @_[HEAP, ARG0];

  my $connection = $response->{'connection'};
  my $request_id = $response->{'context'};

  # Can't handle connections if we're shut down.
  # TODO - How do we still get these?  Were they previously queued or
  # something?
  if ($heap->{is_shut_down}) {
    _internal_cancel(
      $heap, $request_id, 408, "Request timed out (request canceled)"
    );
    return;
  }

  if (defined $connection) {
    DEBUG and warn "CON: request $request_id connected ok...";

    my $request = $heap->{request}->{$request_id};
    unless (defined $request) {
      DEBUG and warn "CON: ignoring connection for canceled request";
      return;
    }

    my $block_size = $heap->{factory}->block_size;

    # get wheel from the connection
    my $new_wheel = $connection->start(
      Driver       => POE::Driver::SysRW->new(BlockSize => $block_size),
      InputFilter  => POE::Filter::HTTPHead->new(),
      OutputFilter => POE::Filter::Stream->new(),
      InputEvent   => 'got_socket_input',
      FlushedEvent => 'got_socket_flush',
      ErrorEvent   => 'got_socket_error',
    );

    DEBUG and warn "CON: request $request_id uses wheel ", $new_wheel->ID;

    # Add the new wheel ID to the lookup table.
    $heap->{wheel_to_request}->{ $new_wheel->ID() } = $request_id;

    $request->[REQ_CONNECTION] = $connection;

    my $peer_addr = getpeername($new_wheel->get_input_handle());
    if (defined $peer_addr) {
      my ($port, $iaddr) = sockaddr_in($peer_addr);
      $request->[REQ_PEERNAME] = inet_ntoa($iaddr) . "." . $port;
    }
    else {
      $request->[REQ_PEERNAME] = "error:$!";
    }

    $request->create_timer($heap->{factory}->timeout);
    $request->send_to_wheel;
  }
  else {
    DEBUG and warn(
      "CON: Error connecting for request $request_id --- ", $_[SENDER]->ID
    );

    my ($operation, $errnum, $errstr) = (
      $response->{function},
      $response->{error_num} || '??',
      $response->{error_str}
    );

    DEBUG and warn(
      "CON: request $request_id encountered $operation error " .
      "$errnum: $errstr"
    );

    DEBUG and warn "I/O: removing request $request_id";
    my $request = delete $heap->{request}->{$request_id};
    $request->remove_timeout();
    delete $heap->{ext_request_to_int_id}->{$request->[REQ_HTTP_REQUEST]};

    # Post an error response back to the requesting session.
    $request->connect_error("$operation error $errnum: $errstr");
  }
}

# }}} _poco_weeble_connect_done

# {{{ _poco_weeble_timeout

sub _poco_weeble_timeout {
  my ($kernel, $heap, $request_id) = @_[KERNEL, HEAP, ARG0];

  DEBUG and warn "T/O: request $request_id timed out";

  # Discard the request.  Keep a copy for a few bits of cleanup.
  DEBUG and warn "I/O: removing request $request_id";
  my $request = delete $heap->{request}->{$request_id};

  unless (defined $request) {
    die(
      "T/O: unexpectedly undefined request for id $request_id\n",
      "T/O: known request IDs: ", join(", ", keys %{$heap->{request}}), "\n",
      "...",
    );
  }

  DEBUG and warn "T/O: request $request_id has timer ", $request->timer;
  $request->remove_timeout();
  delete $heap->{ext_request_to_int_id}->{$request->[REQ_HTTP_REQUEST]};

  # There's a wheel attached to the request.  Shut it down.
  if (defined(my $wheel = $request->wheel())) {
    my $wheel_id = $wheel->ID();
    DEBUG and warn "T/O: request $request_id is wheel $wheel_id";

    # Shut down the connection so it's not reused.
    $wheel->shutdown_input();
    delete $heap->{wheel_to_request}->{$wheel_id};
  }


  DEBUG and do {
    die( "T/O: request $request_id is unexpectedly zero" )
      unless $request->[REQ_STATE];
    warn "T/O: request_state = " . sprintf("%#04x\n", $request->[REQ_STATE]);
  };

  # Hey, we haven't sent back a response yet!
  unless ($request->[REQ_STATE] & (RS_REDIRECTED | RS_POSTED)) {

    # Well, we have a response.  Isn't that nice?  Let's send it.
    if ($request->[REQ_STATE] & (RS_IN_CONTENT | RS_DONE)) {
      _finish_request($heap, $request, 0);
      return;
    }

    # Post an error response back to the requesting session.
    DEBUG and warn "I/O: Disconnect, keepalive timeout or HTTP/1.0.";
    $request->error(408, "Request timed out") if $request->[REQ_STATE];
    return;
  }
}

# }}} _poco_weeble_timeout
#------------------------------------------------------------------------------
# {{{ _poco_weeble_io_flushed

sub _poco_weeble_io_flushed {
  my ($heap, $wheel_id) = @_[HEAP, ARG0];

  # We sent the request.  Now we're looking for a response.  It may be
  # bad to assume we won't get a response until a request has flushed.
  my $request_id = $heap->{wheel_to_request}->{$wheel_id};
  if (not defined $request_id) {
    DEBUG and warn "!!!: unexpectedly undefined request ID";
    return;
  }

  DEBUG and warn(
    "I/O: wheel $wheel_id (request $request_id) flushed its request..."
  );

  my $request = $heap->{request}->{$request_id};

  # Read content to send from a callback
  if ( ref $request->[REQ_HTTP_REQUEST]->content() eq 'CODE' ) {
    my $callback = $request->[REQ_HTTP_REQUEST]->content();

    my $buf = eval { $callback->() };

    if ( $buf ) {
      $request->[REQ_CONNECTION]->wheel->put($buf);

      # reset the timeout
      # Have to also reset REQ_START_TIME or timer ends early
      $request->remove_timeout;
      $request->[REQ_START_TIME] = time();
      $request->create_timer($heap->{factory}->timeout);

      return;
    }
  }

  $request->[REQ_STATE] ^= RS_SENDING;
  $request->[REQ_STATE] = RS_IN_HEAD;

  # XXX - Removed a second time.  The first time was in version 0.53,
  # because the EOF generated by shutdown_output() causes some servers
  # to disconnect rather than send their responses.
  # $request->wheel->shutdown_output();
}

# }}} _poco_weeble_io_flushed
#------------------------------------------------------------------------------
# {{{ _poco_weeble_io_error

sub _poco_weeble_io_error {
  my ($kernel, $heap, $operation, $errnum, $errstr, $wheel_id) =
    @_[KERNEL, HEAP, ARG0..ARG3];

  DEBUG and warn(
    "I/O: wheel $wheel_id encountered $operation error $errnum: $errstr"
  );

  # Drop the wheel.
  my $request_id = delete $heap->{wheel_to_request}->{$wheel_id};
  #K or die "!!!: unexpectedly undefined request ID" unless defined $request_id;

  # There was no corresponding request?  Nothing left to do here.
  return unless $request_id;

  DEBUG and warn "I/O: removing request $request_id";
  my $request = delete $heap->{request}->{$request_id};
  $request->remove_timeout;
  delete $heap->{ext_request_to_int_id}{$request->[REQ_HTTP_REQUEST]};

  # Otherwise the remote end simply closed.  If we've got a pending
  # response, then post it back to the client.
  DEBUG and warn "STATE is ", $request->[REQ_STATE];

  # Except when we're redirected.  In this case, the connection was but
  # one step towards our destination.
  return if ($request->[REQ_STATE] & RS_REDIRECTED);

  # If there was a non-zero error, then something bad happened.  Post
  # an error response back, if we haven't posted anything before.
  if ($errnum) {
    unless ($request->[REQ_STATE] & RS_POSTED) {
      $request->error(400, "$operation error $errnum: $errstr");
    }
    return;
  }

  # We seem to have finished with the request.  Send back a response.
  if (
    $request->[REQ_STATE] & (RS_IN_CONTENT | RS_DONE) and
    not $request->[REQ_STATE] & RS_POSTED
  ) {
    _finish_request($heap, $request, 0);
    return;
  }

  # We have already posted a response, so this is a remote keepalive
  # timeout or other delayed socket shutdown.  Nothing left to do.
  if ($request->[REQ_STATE] & RS_POSTED) {
    DEBUG and warn "I/O: Disconnect, remote keepalive timeout or HTTP/1.0.";
    return;
  }

  # We never received a response.
  if (not defined $request->[REQ_RESPONSE]) {
    # Check for pending data indicating a LF-free HTTP 0.9 response.
    my $lines = $request->wheel->get_input_filter()->get_pending();
    my $text = join '' => @$lines;
    DEBUG and warn "Got ", length($text), " bytes of data without LF.";

    # If we have data, build and return a response from it.
    if ($text =~ /\S/) {
      DEBUG and warn(
        "Generating HTTP response for HTTP/0.9 response without LF."
      );
      $request->[REQ_RESPONSE] = HTTP::Response->new(
        200, 'OK', [
          'Content-Type'  => 'text/html',
          'X-PCCH-Peer'   => $request->[REQ_PEERNAME],
        ], $text
      );
      $request->[REQ_RESPONSE]->protocol('HTTP/0.9');
      $request->[REQ_RESPONSE]->request($request->[REQ_HTTP_REQUEST]);
      $request->[REQ_STATE] = RS_DONE;
      $request->return_response;
      return;
    }

    # No data received.  This is an incomplete response.
    $request->error(400, "Incomplete response - $request_id");
    return;
  }

  # We haven't built a proper response, and nothing returned by the
  # server can be turned into a proper response.  Send back an error.
  # Changed to 406 after considering rt.cpan.org 20975.
  #
  # 10.4.7 406 Not Acceptable
  #
  # The resource identified by the request is only capable of
  # generating response entities which have content characteristics
  # not acceptable according to the accept headers sent in the
  # request.

  $request->error(406, "Server response is Not Acceptable - $request_id");
}

# }}} _poco_weeble_io_error
#------------------------------------------------------------------------------
# Read a chunk of response.  This code is directly adapted from Artur
# Bergman's nifty POE::Filter::HTTPD, which does pretty much the same
# in the other direction.
# {{{ _poco_weeble_io_read

sub _poco_weeble_io_read {
  my ($kernel, $heap, $input, $wheel_id) = @_[KERNEL, HEAP, ARG0, ARG1];
  my $request_id = $heap->{wheel_to_request}->{$wheel_id};

  DEBUG and warn "I/O: wheel $wheel_id got input...";
  DEBUG_DATA and warn (ref($input) ? $input->as_string : _hexdump($input));

  # TODO - So, which is it?  Return, or die?
  return unless defined $request_id;
  die unless defined $request_id;

  my $request = $heap->{request}->{$request_id};
  return unless defined $request;
  DEBUG and warn(
    "REQUEST $request_id is $request <" . $request->[REQ_HTTP_REQUEST]->uri . ">"
  );

  # Reset the timeout if we get data.
  $kernel->delay_adjust($request->timer, $heap->{factory}->timeout);

  if ($request->[REQ_STATE] & RS_REDIRECTED) {
    DEBUG and warn "input for request that was redirected";
    return;
  }

# {{{ HEAD

  # The very first line ought to be status.  If it's not, then it's
  # part of the content.
  if ($request->[REQ_STATE] & RS_IN_HEAD) {
    if (defined $input) {
      $input->request ($request->[REQ_HTTP_REQUEST]);
      #warn(
      #  "INPUT for ", $request->[REQ_HTTP_REQUEST]->uri,
      #  " is \n",$input->as_string
      #)
    }
    else {
      #warn "NO INPUT";
    }

    # FIXME: LordVorp gets here without $input being a HTTP::Response.
    # FIXME: This happens when the response is HTTP/0.9 and doesn't
    # include a status line.  See t/53_response_parser.t.
    $request->[REQ_RESPONSE] = $input;
    $input->header("X-PCCH-Peer", $request->[REQ_PEERNAME]);

    # Some responses are without content by definition
    # FIXME: #12363
    # Make sure we finish even when it isn't one of these, but there
    # is no content.
    if (
      $request->[REQ_HTTP_REQUEST]->method eq 'HEAD'
      or $input->code =~ /^(?:1|[23]04)/
      or (
        defined($input->content_length())
        and $input->content_length() == 0
      )
    ) {
      if (_try_redirect($request_id, $input, $request)) {
        my $old_request = delete $heap->{request}->{$request_id};
        delete $heap->{wheel_to_request}->{$wheel_id};
        if (defined $old_request) {
          DEBUG and warn "I/O: removed request $request_id";
          $old_request->remove_timeout();
          delete $heap->{ext_request_to_int_id}{$old_request->[REQ_HTTP_REQUEST]};
          $old_request->[REQ_CONNECTION] = undef;
        }
        return;
      }
      $request->[REQ_STATE] |= RS_DONE;
      $request->remove_timeout();
      _finish_request($heap, $request, 1);
      return;
    }
    else {
      # If we have content length, and it's more than the maximum we
      # requested, then fail without bothering with the content.
      if (
        defined($heap->{factory}->max_response_size())
        and defined($input->content_length())
        and $input->content_length() > $heap->{factory}->max_response_size()
      ) {
        _internal_cancel(
          $heap, $request_id, 406,
          "Response content length " . $input->content_length() .
          " is greater than specified MaxSize of " .
          $heap->{factory}->max_response_size() .
          ".  Use range requests to retrieve specific amounts of content."
        );
        return;
      }

      $request->[REQ_STATE] |= RS_IN_CONTENT;
      $request->[REQ_STATE] &= ~RS_IN_HEAD;
      #FIXME: probably want to find out when the content from this
      #       request is in, and only then do the new request, so we
      #       can reuse the connection.
      if (_try_redirect($request_id, $input, $request)) {
        my $old_request = delete $heap->{request}->{$request_id};
        delete $heap->{wheel_to_request}->{$wheel_id};
        if (defined $old_request) {
          DEBUG and warn "I/O: removed request $request_id";
          delete $heap->{ext_request_to_int_id}{$old_request->[REQ_HTTP_REQUEST]};
          $old_request->remove_timeout();
          $old_request->[REQ_CONNECTION]->close();
          $old_request->[REQ_CONNECTION] = undef;
        }
        return;
      }

      # RFC 2616 14.41:  If multiple encodings have been applied to an
      # entity, the transfer-codings MUST be listed in the order in
      # which they were applied.

      my ($filter, @filters);

      # Transfer encoding.

      my $te = $input->header('Transfer-Encoding');
      if (defined $te) {
        my @te = split(/\s*,\s*/, lc($te));

        while (@te and exists $te_filters{$te[-1]}) {
          my $encoding = pop @te;
          my $fclass = $te_filters{$encoding};
          push @filters, $fclass->new();
        }

        if (@te) {
          $input->header('Transfer-Encoding', join(', ', @te));
        }
        else {
          $input->header('Transfer-Encoding', undef);
        }
      }

      # Content encoding.

      my $ce = $input->header('Content-Encoding');
      if (defined $ce) {
        my @ce = split(/\s*,\s*/, lc($ce));

        while (@ce and exists $te_filters{$ce[-1]}) {
          my $encoding = pop @ce;
          my $fclass = $te_filters{$encoding};
          push @filters, $fclass->new();
        }

        if (@ce) {
          $input->header('Content-Encoding', join(', ', @ce));
        }
        else {
          $input->header('Content-Encoding', undef);
        }
      }

      if (@filters > 1) {
        $filter = POE::Filter::Stackable->new( Filters => \@filters );
      }
      elsif (@filters) {
        $filter = $filters[0];
      }
      else {
        # Punt if we have no specified filters.
        $filter = POE::Filter::Stream->new;
      }

      # do this last, because it triggers a read
      $request->wheel->set_input_filter($filter);
    }
    return;
  }

# }}} HEAD

# {{{ content

  # We're in a content state.
  if ($request->[REQ_STATE] & RS_IN_CONTENT) {
    if (ref($input) and UNIVERSAL::isa($input, 'HTTP::Response')) {
      # there was a problem in the input filter
      # $request->close_connection;
    }
    else {
      my $is_done = $request->add_content ($input);
    }
  }

# }}} content

# {{{ deliver reponse if complete

# POST response without disconnecting
  if (
    $request->[REQ_STATE] & RS_DONE and
    not $request->[REQ_STATE] & RS_POSTED
  ) {
    $request->remove_timeout;
    _finish_request($heap, $request, 1);
  }

# }}} deliver reponse if complete

}

# }}} _poco_weeble_io_read


#------------------------------------------------------------------------------
# Generate a hex dump of some input. This is not a POE function.
# {{{ _hexdump

sub _hexdump {
  my $data = shift;

  my $dump;
  my $offset = 0;
  while (length $data) {
    my $line = substr($data, 0, 16);
    substr($data, 0, 16) = '';

    my $hexdump  = unpack 'H*', $line;
    $hexdump =~ s/(..)/$1 /g;

    $line =~ tr[ -~][.]c;
    $dump .= sprintf( "%04x %-47.47s - %s\n", $offset, $hexdump, $line );
    $offset += 16;
  }

  return $dump;
}

# }}} _hexdump

# Check for and handle redirect.  Returns true if redirect should
# occur, or false if there's no redirect.

sub _try_redirect {
  my ($request_id, $input, $request) = @_;

  if (my $newrequest = $request->check_redirect) {
    DEBUG and warn(
      "Redirected $request_id ", $input->code, " to <",
      $newrequest->uri, ">"
    );
    my @proxy;
    if ($request->[REQ_USING_PROXY]) {
      push @proxy, (
        'http://' .  $request->host .  ':' .  $request->port .  '/'
      );
    }

    $poe_kernel->yield(
      request =>
      $request,
      $newrequest,
      "_redir_".$request->ID,
      $request->[REQ_PROG_POSTBACK],
      @proxy
    );

    return 1;
  }

  return;
}

# Complete a request. This was moved out of _poco_weeble_io_error(). This is
# not a POE function.
# {{{ _finish_request

sub _finish_request {
  my ($heap, $request, $wait) = @_;

  my $request_id = $request->ID;
  if (DEBUG) {
    my ($pkg, $file, $line) = caller();
    warn(
      "XXX: calling _finish_request(request id = $request_id)" .
      "at $file line $line"
    );
  }

  # XXX What does this do?
  $request->add_eof;

  # KeepAlive: added the RS_POSTED flag
  $request->[REQ_STATE] |= RS_POSTED;

  my $wheel_id = defined $request->wheel ? $request->wheel->ID : "(undef)";
  DEBUG and warn "Wheel from request is ", $wheel_id;
  # clean up the request
  my $address = "$request->[REQ_HOST]:$request->[REQ_PORT]";

  DEBUG and warn "address is $address";

  if ($wait) {
    # Wait a bit with removing the request, so there's time to receive
    # the EOF event in case the connection gets closed.
    # TODO - Inflates the pending request count.  Why do we do this?
    my $alarm_id = $poe_kernel->delay_set('remove_request', 0.5, $request_id);

    # remove the old timeout first
    DEBUG and warn "delay_set; now remove_timeout()";
    $request->remove_timeout();
    DEBUG and warn "removed timeout; now timer()";
    $request->timer($alarm_id);
  }
  else {
    # Virtually identical to _remove_request.
    # TODO - Make a common sub to handle both cases?
    my $request = delete $heap->{request}->{$request_id};
    if (defined $request) {
      DEBUG and warn "I/O: removing request $request_id";
      $request->remove_timeout();
      delete $heap->{ext_request_to_int_id}{$request->[REQ_HTTP_REQUEST]};
      if (my $wheel = $request->wheel) {
        delete $heap->{wheel_to_request}->{$wheel->ID};
      }
    }
  }
}

# }}} _finish_request

#{{{ _remove_request
sub _poco_weeble_remove_request {
  my ($kernel, $heap, $request_id) = @_[KERNEL, HEAP, ARG0];

  my $request = delete $heap->{request}->{$request_id};
  if (defined $request) {
    DEBUG and warn "I/O: removed request $request_id";
    $request->remove_timeout();
    delete $heap->{ext_request_to_int_id}{$request->[REQ_HTTP_REQUEST]};
    if (my $wheel = $request->wheel) {
      delete $heap->{wheel_to_request}->{$wheel->ID};
    }
  }
}
#}}} _remove_request

# Cancel a single request by HTTP::Request object.

sub _poco_weeble_cancel {
  my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];
  my $request_id = $heap->{ext_request_to_int_id}{$request};
  return unless defined $request_id;
  _internal_cancel(
    $heap, $request_id, 408, "Request timed out (request canceled)"
  );
}

sub _internal_cancel {
  my ($heap, $request_id, $code, $message) = @_;

  my $request = delete $heap->{request}{$request_id};
  return unless defined $request;

  DEBUG and warn "CXL: canceling request $request_id";
  $request->remove_timeout();
  delete $heap->{ext_request_to_int_id}{$request->[REQ_HTTP_REQUEST]};

  if (my $wheel = $request->wheel) {
    my $wheel_id = $wheel->ID;
    DEBUG and warn "CXL: Request $request_id canceling wheel $wheel_id";
    delete $heap->{wheel_to_request}{$wheel_id};
    $wheel = undef;
  }

  if ($request->[REQ_CONNECTION]) {
    $request->[REQ_CONNECTION]->close();
    $request->[REQ_CONNECTION] = undef;
  }
  else {
    # Didn't connect yet; inform connection manager to cancel
    # connection request.
    $heap->{cm}->deallocate($request_id);
  }

  unless ($request->[REQ_STATE] & RS_POSTED) {
    $request->error($code, $message);
  }
}

# Shut down the entire component.
sub _poco_weeble_shutdown {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  $heap->{is_shut_down} = 1;

  my @request_ids = keys %{$heap->{request}};
  foreach my $request_id (@request_ids) {
    _internal_cancel(
      $heap, $request_id, 408, "Request timed out (component shut down)"
    );
  }

  # Shut down the connection manager subcomponent.
  if (defined $heap->{cm}) {
    DEBUG and warn "CXL: Client::HTTP shutting down Client::Keepalive";
    $heap->{cm}->shutdown();
    delete $heap->{cm};
  }

  # Final cleanup of this component.
  $kernel->alias_remove($heap->{alias});
}

1;

__END__

# {{{ POD

=head1 NAME

POE::Component::Client::HTTP - a HTTP user-agent component

=head1 SYNOPSIS

  use POE qw(Component::Client::HTTP);

  POE::Component::Client::HTTP->spawn(
    Agent     => 'SpiffCrawler/0.90',   # defaults to something long
    Alias     => 'ua',                  # defaults to 'weeble'
    From      => 'spiffster@perl.org',  # defaults to undef (no header)
    Protocol  => 'HTTP/0.9',            # defaults to 'HTTP/1.1'
    Timeout   => 60,                    # defaults to 180 seconds
    MaxSize   => 16384,                 # defaults to entire response
    Streaming => 4096,                  # defaults to 0 (off)
    FollowRedirects => 2,               # defaults to 0 (off)
    Proxy     => "http://localhost:80", # defaults to HTTP_PROXY env. variable
    NoProxy   => [ "localhost", "127.0.0.1" ], # defs to NO_PROXY env. variable
    BindAddr  => "12.34.56.78",         # defaults to INADDR_ANY
  );

  $kernel->post(
    'ua',        # posts to the 'ua' alias
    'request',   # posts to ua's 'request' state
    'response',  # which of our states will receive the response
    $request,    # an HTTP::Request object
  );

  # This is the sub which is called when the session receives a
  # 'response' event.
  sub response_handler {
    my ($request_packet, $response_packet) = @_[ARG0, ARG1];

    # HTTP::Request
    my $request_object  = $request_packet->[0];

    # HTTP::Response
    my $response_object = $response_packet->[0];

    my $stream_chunk;
    if (! defined($response_object->content)) {
      $stream_chunk = $response_packet->[1];
    }

    print(
      "*" x 78, "\n",
      "*** my request:\n",
      "-" x 78, "\n",
      $request_object->as_string(),
      "*" x 78, "\n",
      "*** their response:\n",
      "-" x 78, "\n",
      $response_object->as_string(),
    );

    if (defined $stream_chunk) {
      print "-" x 40, "\n", $stream_chunk, "\n";
    }

    print "*" x 78, "\n";
  }

=head1 DESCRIPTION

POE::Component::Client::HTTP is an HTTP user-agent for POE.  It lets
other sessions run while HTTP transactions are being processed, and it
lets several HTTP transactions be processed in parallel.

It supports keep-alive through POE::Component::Client::Keepalive,
which in turn uses POE::Component::Client::DNS for asynchronous name
resolution.

HTTP client components are not proper objects.  Instead of being
created, as most objects are, they are "spawned" as separate sessions.
To avoid confusion (and hopefully not cause other confusion), they
must be spawned with a C<spawn> method, not created anew with a C<new>
one.

=head1 CONSTRUCTOR

=head2 spawn

PoCo::Client::HTTP's C<spawn> method takes a few named parameters:

=over 2

=item Agent => $user_agent_string

=item Agent => \@list_of_agents

If a UserAgent header is not present in the HTTP::Request, a random
one will be used from those specified by the C<Agent> parameter.  If
none are supplied, POE::Component::Client::HTTP will advertise itself
to the server.

C<Agent> may contain a reference to a list of user agents.  If this is
the case, PoCo::Client::HTTP will choose one of them at random for
each request.

=item Alias => $session_alias

C<Alias> sets the name by which the session will be known.  If no
alias is given, the component defaults to "weeble".  The alias lets
several sessions interact with HTTP components without keeping (or
even knowing) hard references to them.  It's possible to spawn several
HTTP components with different names.

=item ConnectionManager => $poco_client_keepalive

C<ConnectionManager> sets this component's connection pool manager.
It expects the connection manager to be a reference to a
POE::Component::Client::Keepalive object.  The HTTP client component
will call C<allocate()> on the connection manager itself so you should
not have done this already.

  my $pool = POE::Component::Client::Keepalive->new(
    keep_alive    => 10, # seconds to keep connections alive
    max_open      => 100, # max concurrent connections - total
    max_per_host  => 20, # max concurrent connections - per host
    timeout       => 30, # max time (seconds) to establish a new connection
  );

  POE::Component::Client::HTTP->spawn(
    # ...
    ConnectionManager => $pool,
    # ...
  );

See L<POE::Component::Client::Keepalive> for more information.

=item CookieJar => $cookie_jar

C<CookieJar> sets the component's cookie jar.  It expects the cookie
jar to be a reference to a HTTP::Cookies object.

=item From => $admin_address

C<From> holds an e-mail address where the client's administrator
and/or maintainer may be reached.  It defaults to undef, which means
no From header will be included in requests.

=item MaxSize => OCTETS

C<MaxSize> specifies the largest response to accept from a server.
The content of larger responses will be truncated to OCTET octets.
This has been used to return the <head></head> section of web pages
without the need to wade through <body></body>.

=item NoProxy => [ $host_1, $host_2, ..., $host_N ]

=item NoProxy => "host1,host2,hostN"

C<NoProxy> specifies a list of server hosts that will not be proxied.
It is useful for local hosts and hosts that do not properly support
proxying.  If NoProxy is not specified, a list will be taken from the
NO_PROXY environment variable.

  NoProxy => [ "localhost", "127.0.0.1" ],
  NoProxy => "localhost,127.0.0.1",

=item BindAddr => $local_ip

Specify C<BindAddr> to bind all client sockets to a particular local
address.  The value of BindAddr will be passed through
POE::Component::Client::Keepalive to POE::Wheel::SocketFactory (as
C<bind_address>).  See that module's documentation for implementation
details.

  BindAddr => "12.34.56.78"

=item Protocol => $http_protocol_string

C<Protocol> advertises the protocol that the client wishes to see.
Under normal circumstances, it should be left to its default value:
"HTTP/1.1".

=item Proxy => [ $proxy_host, $proxy_port ]

=item Proxy => $proxy_url

=item Proxy => $proxy_url,$proxy_url,...

C<Proxy> specifies one or more proxy hosts that requests will be
passed through.  If not specified, proxy servers will be taken from
the HTTP_PROXY (or http_proxy) environment variable.  No proxying will
occur unless Proxy is set or one of the environment variables exists.

The proxy can be specified either as a host and port, or as one or
more URLs.  Proxy URLs must specify the proxy port, even if it is 80.

  Proxy => [ "127.0.0.1", 80 ],
  Proxy => "http://127.0.0.1:80/",

C<Proxy> may specify multiple proxies separated by commas.
PoCo::Client::HTTP will choose proxies from this list at random.  This
is useful for load balancing requests through multiple gateways.

  Proxy => "http://127.0.0.1:80/,http://127.0.0.1:81/",

=item Streaming => OCTETS

C<Streaming> changes allows Client::HTTP to return large content in
chunks (of OCTETS octets each) rather than combine the entire content
into a single HTTP::Response object.

By default, Client::HTTP reads the entire content for a response into
memory before returning an HTTP::Response object.  This is obviously
bad for applications like streaming MP3 clients, because they often
fetch songs that never end.  Yes, they go on and on, my friend.

When C<Streaming> is set to nonzero, however, the response handler
receives chunks of up to OCTETS octets apiece.  The response handler
accepts slightly different parameters in this case.  ARG0 is also an
HTTP::Response object but it does not contain response content,
and ARG1 contains a a chunk of raw response
content, or undef if the stream has ended.

  sub streaming_response_handler {
    my $response_packet = $_[ARG1];
    my ($response, $data) = @$response_packet;
    print SAVED_STREAM $data if defined $data;
  }

=item FollowRedirects => $number_of_hops_to_follow

C<FollowRedirects> specifies how many redirects (e.g. 302 Moved) to
follow.  If not specified defaults to 0, and thus no redirection is
followed.  This maintains compatibility with the previous behavior,
which was not to follow redirects at all.

If redirects are followed, a response chain should be built, and can
be accessed through $response_object->previous(). See HTTP::Response
for details here.

=item Timeout => $query_timeout

C<Timeout> sets how long POE::Component::Client::HTTP has to process
an application's request, in seconds.  C<Timeout> defaults to 180
(three minutes) if not specified.

It's important to note that the timeout begins when the component
receives an application's request, not when it attempts to connect to
the web server.

Timeouts may result from sending the component too many requests at
once.  Each request would need to be received and tracked in order.
Consider this:

  $_[KERNEL]->post(component => request => ...) for (1..15_000);

15,000 requests are queued together in one enormous bolus.  The
component would receive and initialize them in order.  The first
socket activity wouldn't arrive until the 15,000th request was set up.
If that took longer than C<Timeout>, then the requests that have
waited too long would fail.

C<ConnectionManager>'s own timeout and concurrency limits also affect
how many requests may be processed at once.  For example, most of the
15,000 requests would wait in the connection manager's pool until
sockets become available.  Meanwhile, the C<Timeout> would be counting
down.

Applications may elect to control concurrency outside the component's
C<Timeout>.  They may do so in a few ways.

The easiest way is to limit the initial number of requests to
something more manageable.  As responses arrive, the application
should handle them and start new requests.  This limits concurrency to
the initial request count.

An application may also outsource job throttling to another module,
such as POE::Component::JobQueue.

In any case, C<Timeout> and C<ConnectionManager> may be tuned to
maximize timeouts and concurrency limits.  This may help in some
cases.  Developers should be aware that doing so will increase memory
usage.  POE::Component::Client::HTTP and KeepAlive track requests in
memory, while applications are free to keep pending requests on disk.

=back

=head1 ACCEPTED EVENTS

Sessions communicate asynchronously with PoCo::Client::HTTP.  They
post requests to it, and it posts responses back.

=head2 request

Requests are posted to the component's "request" state.  They include
an HTTP::Request object which defines the request.  For example:

  $kernel->post(
    'ua', 'request',           # http session alias & state
    'response',                # my state to receive responses
    GET 'http://poe.perl.org', # a simple HTTP request
    'unique id',               # a tag to identify the request
    'progress',                # an event to indicate progress
    'http://1.2.3.4:80/'       # proxy to use for this request
  );

Requests include the state to which responses will be posted.  In the
previous example, the handler for a 'response' state will be called
with each HTTP response.  The "progress" handler is optional and if
installed, the component will provide progress metrics (see sample
handler below).  The "proxy" parameter is optional and if not defined,
a default proxy will be used if configured.  No proxy will be used if
neither a default one nor a "proxy" parameter is defined.

=head2 pending_requests_count

There's also a pending_requests_count state that returns the number of
requests currently being processed.  To receive the return value, it
must be invoked with $kernel->call().

  my $count = $kernel->call('ua' => 'pending_requests_count');

=head2 cancel

Cancel a specific HTTP request.  Requires a reference to the original
request (blessed or stringified) so it knows which one to cancel.  See
L<progress handler> below for notes on canceling streaming requests.

To cancel a request based on its blessed HTTP::Request object:

  $kernel->post( component => cancel => $http_request );

To cancel a request based on its stringified HTTP::Request object:

  $kernel->post( component => cancel => "$http_request" );

=head2 shutdown

Responds to all pending requests with 408 (request timeout), and then
shuts down the component and all subcomponents.

=head1 SENT EVENTS

=head2 response handler

In addition to all the usual POE parameters, HTTP responses come with
two list references:

  my ($request_packet, $response_packet) = @_[ARG0, ARG1];

C<$request_packet> contains a reference to the original HTTP::Request
object.  This is useful for matching responses back to the requests
that generated them.

  my $http_request_object = $request_packet->[0];
  my $http_request_tag    = $request_packet->[1]; # from the 'request' post

C<$response_packet> contains a reference to the resulting
HTTP::Response object.

  my $http_response_object = $response_packet->[0];

Please see the HTTP::Request and HTTP::Response manpages for more
information.

=head2 progress handler

The example progress handler shows how to calculate a percentage of
download completion.

  sub progress_handler {
    my $gen_args  = $_[ARG0];    # args passed to all calls
    my $call_args = $_[ARG1];    # args specific to the call

    my $req = $gen_args->[0];    # HTTP::Request object being serviced
    my $tag = $gen_args->[1];    # Request ID tag from.
    my $got = $call_args->[0];   # Number of bytes retrieved so far.
    my $tot = $call_args->[1];   # Total bytes to be retrieved.
    my $oct = $call_args->[2];   # Chunk of raw octets received this time.

    my $percent = $got / $tot * 100;

    printf(
      "-- %.0f%% [%d/%d]: %s\n", $percent, $got, $tot, $req->uri()
    );

    # To cancel the request:
    # $_[KERNEL]->post( component => cancel => $req );
  }

=head3 DEPRECATION WARNING

The third return argument (the raw octets received) has been deprecated.
Instead of it, use the Streaming parameter to get chunks of content
in the response handler.

=head1 REQUEST CALLBACKS

The HTTP::Request object passed to the request event can contain a
CODE reference as C<content>.  This allows for sending large files
without wasting memory.  Your callback should return a chunk of data
each time it is called, and an empty string when done.  Don't forget
to set the Content-Length header correctly.  Example:

  my $request = HTTP::Request->new( PUT => 'http://...' );

  my $file = '/path/to/large_file';

  open my $fh, '<', $file;

  my $upload_cb = sub {
    if ( sysread $fh, my $buf, 4096 ) {
      return $buf;
    }
    else {
      close $fh;
      return '';
    }
  };

  $request->content_length( -s $file );

  $request->content( $upload_cb );

  $kernel->post( ua => request, 'response', $request );

=head1 CONTENT ENCODING AND COMPRESSION

Transparent content decoding has been disabled as of version 0.84.
This also removes support for transparent gzip requesting and
decompression.

To re-enable gzip compression, specify the gzip Content-Encoding and
use HTTP::Response's decoded_content() method rather than content():

  my $request = HTTP::Request->new(
    GET => "http://www.yahoo.com/", [
      'Accept-Encoding' => 'gzip'
    ]
  );

  # ... time passes ...

  my $content = $response->decoded_content();

The change in POE::Component::Client::HTTP behavior was prompted by
changes in HTTP::Response that surfaced a bug in the component's
transparent gzip handling.

Allowing the application to specify and handle content encodings seems
to be the most reliable and flexible resolution.

For more information about the problem and discussions regarding the
solution, see:
L<http://www.perlmonks.org/?node_id=683833> and
L<http://rt.cpan.org/Ticket/Display.html?id=35538>

=head1 CLIENT HEADERS

POE::Component::Client::HTTP sets its own response headers with
additional information.  All of its headers begin with "X-PCCH".

=head2 X-PCCH-Peer

X-PCCH-Peer contains the remote IPv4 address and port, separated by a
period.  For example, "127.0.0.1.8675" represents port 8675 on
localhost.

Proxying will render X-PCCH-Peer nearly useless, since the socket will
be connected to a proxy rather than the server itself.

This feature was added at Doreen Grey's request.  Doreen wanted a
means to find the remote server's address without having to make an
additional request.

Patches for IPv6 support are welcome.

=head1 ENVIRONMENT

POE::Component::Client::HTTP uses two standard environment variables:
HTTP_PROXY and NO_PROXY.

HTTP_PROXY sets the proxy server that Client::HTTP will forward
requests through.  NO_PROXY sets a list of hosts that will not be
forwarded through a proxy.

See the Proxy and NoProxy constructor parameters for more information
about these variables.

=head1 SEE ALSO

This component is built upon HTTP::Request, HTTP::Response, and POE.
Please see its source code and the documentation for its foundation
modules to learn more.  If you want to use cookies, you'll need to
read about HTTP::Cookies as well.

Also see the test program, t/01_request.t, in the PoCo::Client::HTTP
distribution.

=head1 BUGS

There is no support for CGI_PROXY or CgiProxy.

Secure HTTP (https) proxying is not supported at this time.

There is no object oriented interface.  See
L<POE::Component::Client::Keepalive> and
L<POE::Component::Client::DNS> for examples of a decent OO interface.

=head1 AUTHOR, COPYRIGHT, & LICENSE

POE::Component::Client::HTTP is

=over 2

=item

Copyright 1999-2009 Rocco Caputo

=item

Copyright 2004 Rob Bloodgood

=item

Copyright 2004-2005 Martijn van Beers

=back

All rights are reserved.  POE::Component::Client::HTTP is free
software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=head1 CONTRIBUTORS

Joel Bernstein solved some nasty race conditions.  Portugal Telecom
L<http://www.sapo.pt/> was kind enough to support his contributions.

Jeff Bisbee added POD tests and documentation to pass several of them
to version 0.79.  He's a kwalitee-increasing machine!

=head1 BUG TRACKER

https://rt.cpan.org/Dist/Display.html?Queue=POE-Component-Client-HTTP

=head1 REPOSITORY

http://github.com/rcaputo/poe-component-client-http
http://gitorious.org/poe-component-client-http

=head1 OTHER RESOURCES

http://search.cpan.org/dist/POE-Component-Client-HTTP/

=cut

# }}} POD
# rocco // vim: ts=2 sw=2 expandtab
