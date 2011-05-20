package POE::Wheel::SocketFactory;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw( carp croak );
use Symbol qw( gensym );

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Errno qw(
  EWOULDBLOCK EADDRNOTAVAIL EINPROGRESS EADDRINUSE ECONNABORTED
  ESPIPE
);
use Socket qw(
  AF_INET SOCK_STREAM SOL_SOCKET AF_UNIX PF_UNIX 
  PF_INET SOCK_DGRAM SO_ERROR unpack_sockaddr_in 
  unpack_sockaddr_un PF_UNSPEC SO_REUSEADDR INADDR_ANY 
  pack_sockaddr_in pack_sockaddr_un inet_aton SOMAXCONN
);
use IO::Handle ();
use FileHandle ();
use POE qw( Wheel );
use base qw(POE::Wheel);

sub CRIMSON_SCOPE_HACK ($) { 0 }
sub DEBUG () { 0 }

sub MY_SOCKET_HANDLE   () {  0 }
sub MY_UNIQUE_ID       () {  1 }
sub MY_EVENT_SUCCESS   () {  2 }
sub MY_EVENT_FAILURE   () {  3 }
sub MY_SOCKET_DOMAIN   () {  4 }
sub MY_STATE_ACCEPT    () {  5 }
sub MY_STATE_CONNECT   () {  6 }
sub MY_MINE_SUCCESS    () {  7 }
sub MY_MINE_FAILURE    () {  8 }
sub MY_SOCKET_PROTOCOL () {  9 }
sub MY_SOCKET_TYPE     () { 10 }
sub MY_STATE_ERROR     () { 11 }
sub MY_SOCKET_SELECTED () { 12 }

# Fletch has subclassed SSLSocketFactory from SocketFactory.  He's
# added new members after MY_SOCKET_SELECTED.  Be sure, if you extend
# this, to extend add stuff BEFORE MY_SOCKET_SELECTED or let Fletch
# know you've broken his module.

# Provide dummy constants for systems that don't have them.
# Test and provide for each constant separately, per suggestion in
# rt.cpan.org 27250.
BEGIN {
  eval { require Socket6 };
  if ($@) {
    *Socket6::AF_INET6 = sub () { ~0 };
    *Socket6::PF_INET6 = sub () { ~0 };
  }
  else {
    eval { my $x = &Socket6::AF_INET6 };
    *Socket6::AF_INET6 = sub () { ~0 } if $@;
    eval { my $x = &Socket6::PF_INET6 };
    *Socket6::PF_INET6 = sub () { ~0 } if $@;
  }
}

#------------------------------------------------------------------------------
# These tables customize the socketfactory.  Many protocols share the
# same operations, it seems, and this is a way to add new ones with a
# minimum of additional code.

sub DOM_UNIX  () { 'unix'  }  # UNIX domain socket
sub DOM_INET  () { 'inet'  }  # INET domain socket
sub DOM_INET6 () { 'inet6' }  # INET v6 domain socket

# AF_XYZ and PF_XYZ may be different.
my %map_family_to_domain = (
  AF_UNIX,  DOM_UNIX,  PF_UNIX,  DOM_UNIX,
  AF_INET,  DOM_INET,  PF_INET,  DOM_INET,
  &Socket6::AF_INET6, DOM_INET6,
  &Socket6::PF_INET6, DOM_INET6,
);

sub SVROP_LISTENS () { 'listens' }  # connect/listen sockets
sub SVROP_NOTHING () { 'nothing' }  # connectionless sockets

# Map family/protocol pairs to connection or connectionless
# operations.
my %supported_protocol = (
  DOM_UNIX, {
    none => SVROP_LISTENS
  },
  DOM_INET, {
    tcp  => SVROP_LISTENS,
    udp  => SVROP_NOTHING,
  },
  DOM_INET6, {
    tcp  => SVROP_LISTENS,
    udp  => SVROP_NOTHING,
  },
);

# Sane default socket types for each supported protocol.  TODO Maybe
# this structure can be combined with %supported_protocol?
my %default_socket_type = (
  DOM_UNIX, {
    none => SOCK_STREAM
  },
  DOM_INET, {
    tcp  => SOCK_STREAM,
    udp  => SOCK_DGRAM,
  },
  DOM_INET6, {
    tcp  => SOCK_STREAM,
    udp  => SOCK_DGRAM,
  },
);

#------------------------------------------------------------------------------
# Perform system-dependent translations on Unix addresses, if
# necessary.

sub _condition_unix_address {
  my ($address) = @_;

  # OS/2 would like sockets to use backwhacks, and please place them
  # in the virtual \socket\ directory.  Thank you.
  if ($^O eq 'os2') {
    $address =~ tr[\\][/];
    if ($address !~ m{^/socket/}) {
      $address =~ s{^/?}{/socket/};
    }
    $address =~ tr[/][\\];
  }

  $address;
}

#------------------------------------------------------------------------------
# Define the select handler that will accept connections.

sub _define_accept_state {
  my $self = shift;

  # We do these stupid closure tricks to avoid putting $self in it
  # directly.  If you include $self in one of the state() closures,
  # the component will fail to shut down properly: there will be a
  # circular definition in the closure holding $self alive.

  my $domain = $map_family_to_domain{ $self->[MY_SOCKET_DOMAIN] };
  $domain = '(undef)' unless defined $domain;
  my $event_success = \$self->[MY_EVENT_SUCCESS];
  my $event_failure = \$self->[MY_EVENT_FAILURE];
  my $unique_id     =  $self->[MY_UNIQUE_ID];

  $poe_kernel->state(
    $self->[MY_STATE_ACCEPT] = ref($self) . "($unique_id) -> select accept",
    sub {
      # prevents SEGV
      0 && CRIMSON_SCOPE_HACK('<');

      # subroutine starts here
      my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];

      my $new_socket = gensym;
      my $peer = accept($new_socket, $handle);

      if ($peer) {
        my ($peer_addr, $peer_port);
        if ( $domain eq DOM_UNIX ) {
          $peer_addr = $peer_port = undef;
        }
        elsif ( $domain eq DOM_INET ) {
          ($peer_port, $peer_addr) = unpack_sockaddr_in($peer);
        }
        elsif ( $domain eq DOM_INET6 ) {
          $peer = getpeername($new_socket);
          ($peer_port, $peer_addr) = Socket6::unpack_sockaddr_in6($peer);
        }
        else {
          die "sanity failure: socket domain == $domain";
        }
        $k->call(
          $me, $$event_success,
          $new_socket, $peer_addr, $peer_port,
          $unique_id
        );
      }
      elsif ($! != EWOULDBLOCK and $! != ECONNABORTED and $! != ESPIPE) {
        # OSX reports ESPIPE, which isn't documented anywhere.
        $$event_failure && $k->call(
          $me, $$event_failure,
          'accept', ($!+0), $!, $unique_id
        );
      }
    }
  );

  $self->[MY_SOCKET_SELECTED] = 'yes';
  $poe_kernel->select_read(
    $self->[MY_SOCKET_HANDLE],
    $self->[MY_STATE_ACCEPT]
  );
}

#------------------------------------------------------------------------------
# Define the select handler that will finalize an established
# connection.

sub _define_connect_state {
  my $self = shift;

  # We do these stupid closure tricks to avoid putting $self in it
  # directly.  If you include $self in one of the state() closures,
  # the component will fail to shut down properly: there will be a
  # circular definition in the closure holding $self alive.

  my $domain = $map_family_to_domain{ $self->[MY_SOCKET_DOMAIN] };
  $domain = '(undef)' unless defined $domain;
  my $event_success   = \$self->[MY_EVENT_SUCCESS];
  my $event_failure   = \$self->[MY_EVENT_FAILURE];
  my $unique_id       =  $self->[MY_UNIQUE_ID];
  my $socket_selected = \$self->[MY_SOCKET_SELECTED];

  my $socket_handle   = \$self->[MY_SOCKET_HANDLE];
  my $state_accept    = \$self->[MY_STATE_ACCEPT];
  my $state_connect   = \$self->[MY_STATE_CONNECT];
  my $mine_success    = \$self->[MY_MINE_SUCCESS];
  my $mine_failure    = \$self->[MY_MINE_FAILURE];

  $poe_kernel->state(
    $self->[MY_STATE_CONNECT] = (
      ref($self) .  "($unique_id) -> select connect"
    ),
    sub {
      # This prevents SEGV in older versions of Perl.
      0 && CRIMSON_SCOPE_HACK('<');

      # Grab some values and stop watching the socket.
      my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];

      _shutdown(
        $socket_selected, $socket_handle,
        $state_accept, $state_connect,
        $mine_success, $event_success,
        $mine_failure, $event_failure,
      );

      # Throw a failure if the connection failed.
      $! = unpack('i', getsockopt($handle, SOL_SOCKET, SO_ERROR));
      if ($!) {
        (defined $$event_failure) and $k->call(
          $me, $$event_failure,
          'connect', ($!+0), $!, $unique_id
        );
        return;
      }

      # Get the remote address, or throw an error if that fails.
      my $peer = getpeername($handle);
      if ($!) {
        (defined $$event_failure) and $k->call(
          $me, $$event_failure,
          'getpeername', ($!+0), $!, $unique_id
        );
        return;
      }

      # Parse the remote address according to the socket's domain.
      my ($peer_addr, $peer_port);

      # UNIX sockets have some trouble with peer addresses.
      if ($domain eq DOM_UNIX) {
        if (defined $peer) {
          eval {
            $peer_addr = unpack_sockaddr_un($peer);
          };
          undef $peer_addr if length $@;
        }
      }

      # INET socket stacks tend not to.
      elsif ($domain eq DOM_INET) {
        if (defined $peer) {
          eval {
            ($peer_port, $peer_addr) = unpack_sockaddr_in($peer);
          };
          if (length $@) {
            $peer_port = $peer_addr = undef;
          }
        }
      }

      # INET6 socket stacks tend not to.
      elsif ($domain eq DOM_INET6) {
        if (defined $peer) {
          eval {
            ($peer_port, $peer_addr) = Socket6::unpack_sockaddr_in6($peer);
          };
          if (length $@) {
            $peer_port = $peer_addr = undef;
          }
        }
      }

      # What are we doing here?
      else {
        die "sanity failure: socket domain == $domain";
      }

      # Tell the session it went okay.  Also let go of the socket.
      $k->call(
        $me, $$event_success,
        $handle, $peer_addr, $peer_port, $unique_id
      );
    }
  );

  # Cygwin expects an error state registered to expedite.  This code
  # is nearly identical the stuff above.
  if ($^O eq "cygwin") {
    $poe_kernel->state(
      $self->[MY_STATE_ERROR] = (
        ref($self) .  "($unique_id) -> connect error"
      ),
      sub {
        # This prevents SEGV in older versions of Perl.
        0 && CRIMSON_SCOPE_HACK('<');

        # Grab some values and stop watching the socket.
        my ($k, $me, $handle) = @_[KERNEL, SESSION, ARG0];

        _shutdown(
          $socket_selected, $socket_handle,
          $state_accept, $state_connect,
          $mine_success, $event_success,
          $mine_failure, $event_failure,
        );

        # Throw a failure if the connection failed.
        $! = unpack('i', getsockopt($handle, SOL_SOCKET, SO_ERROR));
        if ($!) {
          (defined $$event_failure) and $k->call(
            $me, $$event_failure, 'connect', ($!+0), $!, $unique_id
          );
          return;
        }
      }
    );
    $poe_kernel->select_expedite(
      $self->[MY_SOCKET_HANDLE],
      $self->[MY_STATE_ERROR]
    );
  }

  $self->[MY_SOCKET_SELECTED] = 'yes';
  $poe_kernel->select_write(
    $self->[MY_SOCKET_HANDLE],
    $self->[MY_STATE_CONNECT]
  );
}

#------------------------------------------------------------------------------

sub event {
  my $self = shift;
  push(@_, undef) if (scalar(@_) & 1);

  while (@_) {
    my ($name, $event) = splice(@_, 0, 2);

    if ($name eq 'SuccessEvent') {
      if (defined $event) {
        if (ref($event)) {
          carp "reference for SuccessEvent will be treated as an event name"
        }
        $self->[MY_EVENT_SUCCESS] = $event;
        undef $self->[MY_MINE_SUCCESS];
      }
      else {
        carp "SuccessEvent requires an event name.  ignoring undef";
      }
    }
    elsif ($name eq 'FailureEvent') {
      if (defined $event) {
        if (ref($event)) {
          carp "reference for FailureEvent will be treated as an event name";
        }
        $self->[MY_EVENT_FAILURE] = $event;
        undef $self->[MY_MINE_FAILURE];
      }
      else {
        carp "FailureEvent requires an event name.  ignoring undef";
      }
    }
    else {
      carp "ignoring unknown SocketFactory parameter '$name'";
    }
  }

  $self->[MY_SOCKET_SELECTED] = 'yes';
  if (defined $self->[MY_STATE_ACCEPT]) {
    $poe_kernel->select_read(
      $self->[MY_SOCKET_HANDLE],
      $self->[MY_STATE_ACCEPT]
     );
  }
  elsif (defined $self->[MY_STATE_CONNECT]) {
    $poe_kernel->select_write(
      $self->[MY_SOCKET_HANDLE],
      $self->[MY_STATE_CONNECT]
    );
    if ($^O eq "cygwin") {
      $poe_kernel->select_expedite(
        $self->[MY_SOCKET_HANDLE],
        $self->[MY_STATE_ERROR]
      );
    }
  }
  else {
    die "POE developer error - no state defined";
  }
}

#------------------------------------------------------------------------------

sub getsockname {
  my $self = shift;
  return undef unless defined $self->[MY_SOCKET_HANDLE];
  return getsockname($self->[MY_SOCKET_HANDLE]);
}

sub ID {
  return $_[0]->[MY_UNIQUE_ID];
}

#------------------------------------------------------------------------------

sub new {
  my $type = shift;

  # Don't take responsibility for a bad parameter count.
  croak "$type requires an even number of parameters" if @_ & 1;

  my %params = @_;

  # The calling convention experienced a hard deprecation.
  croak "wheels no longer require a kernel reference as their first parameter"
    if (@_ && (ref($_[0]) eq 'POE::Kernel'));

  # Ensure some of the basic things are present.
  croak "$type requires a working Kernel" unless (defined $poe_kernel);
  croak 'SuccessEvent required' unless (defined $params{SuccessEvent});
  croak 'FailureEvent required' unless (defined $params{FailureEvent});
  my $event_success = $params{SuccessEvent};
  my $event_failure = $params{FailureEvent};

  # Create the SocketServer.  Cache a copy of the socket handle.
  my $socket_handle = gensym();
  my $self = bless(
    [
      $socket_handle,                   # MY_SOCKET_HANDLE
      &POE::Wheel::allocate_wheel_id(), # MY_UNIQUE_ID
      $event_success,                   # MY_EVENT_SUCCESS
      $event_failure,                   # MY_EVENT_FAILURE
      undef,                            # MY_SOCKET_DOMAIN
      undef,                            # MY_STATE_ACCEPT
      undef,                            # MY_STATE_CONNECT
      undef,                            # MY_MINE_SUCCESS
      undef,                            # MY_MINE_FAILURE
      undef,                            # MY_SOCKET_PROTOCOL
      undef,                            # MY_SOCKET_TYPE
      undef,                            # MY_STATE_ERROR
      undef,                            # MY_SOCKET_SELECTED
    ],
    $type
  );

  # Default to Internet sockets.
  my $domain = delete $params{SocketDomain};
  $domain = AF_INET unless defined $domain;
  $self->[MY_SOCKET_DOMAIN] = $domain;

  # Abstract the socket domain into something we don't have to keep
  # testing duplicates of.
  my $abstract_domain = $map_family_to_domain{$self->[MY_SOCKET_DOMAIN]};
  unless (defined $abstract_domain) {
    $poe_kernel->yield(
      $event_failure, 'domain', 0, '', $self->[MY_UNIQUE_ID]
    );
    return $self;
  }

  #---------------#
  # Create Socket #
  #---------------#

  # Declare the protocol name out here; it'll be needed by
  # getservbyname later.
  my $protocol_name;

  # Unix sockets don't use protocols; warn the programmer, and force
  # PF_UNSPEC.
  if ($abstract_domain eq DOM_UNIX) {
    carp 'SocketProtocol ignored for Unix socket'
      if defined $params{SocketProtocol};
    $self->[MY_SOCKET_PROTOCOL] = PF_UNSPEC;
    $protocol_name = 'none';
  }

  # Internet sockets use protocols.  Default the INET protocol to tcp,
  # and try to resolve it.
  elsif (
    $abstract_domain eq DOM_INET or
    $abstract_domain eq DOM_INET6
  ) {
    my $socket_protocol = (
      (defined $params{SocketProtocol})
      ? $params{SocketProtocol}
      : 'tcp'
    );

    if ($socket_protocol !~ /^\d+$/) {
      unless ($socket_protocol = getprotobyname($socket_protocol)) {
        $poe_kernel->yield(
          $event_failure, 'getprotobyname', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }
    }

    # Get the protocol's name regardless of what was provided.  If the
    # protocol isn't supported, croak now instead of making the
    # programmer wonder why things fail later.
    $protocol_name = lc(getprotobynumber($socket_protocol));
    unless ($protocol_name) {
      $poe_kernel->yield(
        $event_failure, 'getprotobynumber', $!+0, $!, $self->[MY_UNIQUE_ID]
      );
      return $self;
    }

    unless (defined $supported_protocol{$abstract_domain}->{$protocol_name}) {
      croak "SocketFactory does not support Internet $protocol_name sockets";
    }

    $self->[MY_SOCKET_PROTOCOL] = $socket_protocol;
  }
  else {
    die "Mail this error to the author of POE: Internal consistency error";
  }

  # If no SocketType, default it to something appropriate.
  if (defined $params{SocketType}) {
    $self->[MY_SOCKET_TYPE] = $params{SocketType};
  }
  else {
    unless (defined $default_socket_type{$abstract_domain}->{$protocol_name}) {
      croak "SocketFactory does not support $abstract_domain $protocol_name";
    }
    $self->[MY_SOCKET_TYPE] =
      $default_socket_type{$abstract_domain}->{$protocol_name};
  }

  # o  create a dummy socket
  # o  cache the value of SO_OPENTYPE in $win32_socket_opt
  # o  set the overlapped io attribute
  # o  close dummy socket
  my $win32_socket_opt;
  if ( POE::Kernel::RUNNING_IN_HELL) {

    # Constants are evaluated first so they exist when the code uses
    # them.
    eval {
      *SO_OPENTYPE     = sub () { 0x7008 };
      *SO_SYNCHRONOUS_ALERT    = sub () { 0x10 };
      *SO_SYNCHRONOUS_NONALERT = sub () { 0x20 };
    };
    die "Could not install SO constants [$@]" if $@;

    # Turn on socket overlapped IO attribute per MSKB: Q181611. 

    eval {
      socket(POE, AF_INET, SOCK_STREAM, getprotobyname("tcp"))
        or die "socket failed: $!";
      my $opt = unpack("I", getsockopt(POE, SOL_SOCKET, SO_OPENTYPE()));
      $win32_socket_opt = $opt;
      $opt &= ~(SO_SYNCHRONOUS_ALERT()|SO_SYNCHRONOUS_NONALERT());
      setsockopt(POE, SOL_SOCKET, SO_OPENTYPE(), $opt);
      close POE;
    };

    die if $@;
  }

  # Create the socket.
  unless (
    socket( $socket_handle, $self->[MY_SOCKET_DOMAIN],
      $self->[MY_SOCKET_TYPE], $self->[MY_SOCKET_PROTOCOL]
    )
  ) {
    $poe_kernel->yield(
      $event_failure, 'socket', $!+0, $!, $self->[MY_UNIQUE_ID]
    );
    return $self;
  }

  # o  create a dummy socket
  # o  restore previous value of SO_OPENTYPE
  # o  close dummy socket
  #
  # This way we'd only be turning on the overlap attribute for
  # the socket we created... and not all subsequent sockets.
  if ( POE::Kernel::RUNNING_IN_HELL) {
    eval {
      socket(POE, AF_INET, SOCK_STREAM, getprotobyname("tcp"))
        or die "socket failed: $!";
      setsockopt(POE, SOL_SOCKET, SO_OPENTYPE(), $win32_socket_opt);
      close POE;
    };

    die if $@;
  }
  DEBUG && warn "socket";

  #------------------#
  # Configure Socket #
  #------------------#

  # Make the socket binary.  It's wrapped in eval{} because tied
  # filehandle classes may actually die in their binmode methods.
  eval { binmode($socket_handle) };

  # Don't block on socket operations, because the socket will be
  # driven by a select loop.

  # RCC 2002-12-19: Replace the complex blocking checks and methods
  # with IO::Handle's blocking(0) method.  This is theoretically more
  # portable and less maintenance than rolling our own.  If things
  # work out, we'll remove the commented out code.

  # RCC 2003-01-20: Unfortunately, blocking() isn't available in perl
  # 5.005_03, and people still use that.  We'll use blocking() for
  # Perl 5.8.0 and beyond, since that's the first version of
  # ActivePerl that has a problem.

  if ($] >= 5.008) {
    $socket_handle->blocking(0);
  }
  else {
    # Do it the Win32 way.  XXX This is incomplete.
    if ($^O eq 'MSWin32') {
      my $set_it = "1";

      # 126 is FIONBIO (some docs say 0x7F << 16)
      ioctl(
        $socket_handle,
        0x80000000 | (4 << 16) | (ord('f') << 8) | 126,
        \$set_it
      ) or do {
        $poe_kernel->yield(
          $event_failure,
          'ioctl', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      };
    }

    # Do it the way everyone else does.
    else {
      my $flags = fcntl($socket_handle, F_GETFL, 0) or do {
        $poe_kernel->yield(
          $event_failure,
          'fcntl', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      };

      $flags = fcntl($socket_handle, F_SETFL, $flags | O_NONBLOCK) or do {
        $poe_kernel->yield(
          $event_failure,
          'fcntl', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      };
    }
  }

  # Make the socket reusable, if requested.
  if (
    (defined $params{Reuse})
       and ( (lc($params{Reuse}) eq 'yes')
             or (lc($params{Reuse}) eq 'on')
             or ( ($params{Reuse} =~ /\d+/)
                  and $params{Reuse}
                )
           )
     )
  {
    setsockopt($socket_handle, SOL_SOCKET, SO_REUSEADDR, 1) or do {
      $poe_kernel->yield(
        $event_failure,
        'setsockopt', $!+0, $!, $self->[MY_UNIQUE_ID]
      );
      return $self;
    };
  }

  #-------------#
  # Bind Socket #
  #-------------#

  my $bind_address;

  # Check SocketFactory /Bind.*/ parameters in an Internet socket
  # context, and translate them into parameters that bind()
  # understands.
  if ($abstract_domain eq DOM_INET) {
    # Don't bind if the creator doesn't specify a related parameter.
    if ((defined $params{BindAddress}) or (defined $params{BindPort})) {

      # Set the bind address, or default to INADDR_ANY.
      $bind_address = (
        (defined $params{BindAddress})
        ? $params{BindAddress}
        : INADDR_ANY
      );

      # Need to check lengths in octets, not characters.
      BEGIN { eval { require bytes } and bytes->import; }

      # Resolve the bind address if it's not already packed.
      unless (length($bind_address) == 4) {
        $bind_address = inet_aton($bind_address);
      }

      unless (defined $bind_address) {
        $! = EADDRNOTAVAIL;
        $poe_kernel->yield(
          $event_failure,
          "inet_aton", $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }

      # Set the bind port, or default to 0 (any) if none specified.
      # Resolve it to a number, if at all possible.
      my $bind_port = (defined $params{BindPort}) ? $params{BindPort} : 0;
      if ($bind_port =~ /[^0-9]/) {
        $bind_port = getservbyname($bind_port, $protocol_name);
        unless (defined $bind_port) {
          $! = EADDRNOTAVAIL;
          $poe_kernel->yield(
            $event_failure,
            'getservbyname', $!+0, $!, $self->[MY_UNIQUE_ID]
          );
          return $self;
        }
      }

      $bind_address = pack_sockaddr_in($bind_port, $bind_address);
      unless (defined $bind_address) {
        $poe_kernel->yield(
          $event_failure,
          "pack_sockaddr_in", $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }
    }
  }

  # Check SocketFactory /Bind.*/ parameters in an Internet socket
  # context, and translate them into parameters that bind()
  # understands.
  elsif ($abstract_domain eq DOM_INET6) {

    # Don't bind if the creator doesn't specify a related parameter.
    if ((defined $params{BindAddress}) or (defined $params{BindPort})) {

      # Set the bind address, or default to INADDR_ANY.
      $bind_address = (
        (defined $params{BindAddress})
        ? $params{BindAddress}
        : Socket6::in6addr_any()
      );

      # Set the bind port, or default to 0 (any) if none specified.
      # Resolve it to a number, if at all possible.
      my $bind_port = (defined $params{BindPort}) ? $params{BindPort} : 0;
      if ($bind_port =~ /[^0-9]/) {
        $bind_port = getservbyname($bind_port, $protocol_name);
        unless (defined $bind_port) {
          $! = EADDRNOTAVAIL;
          $poe_kernel->yield(
            $event_failure,
            'getservbyname', $!+0, $!, $self->[MY_UNIQUE_ID]
          );
          return $self;
        }
      }

      # Need to check lengths in octets, not characters.
      BEGIN { eval { require bytes } and bytes->import; }

      # Resolve the bind address.
      my @info = Socket6::getaddrinfo(
        $bind_address, $bind_port,
        $self->[MY_SOCKET_DOMAIN], $self->[MY_SOCKET_TYPE],
      );

      if (@info < 5) {  # unless defined $bind_address
        $! = EADDRNOTAVAIL;
        $poe_kernel->yield(
          $event_failure,
          "getaddrinfo", $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }

      $bind_address = $info[3];
    }
  }

  # Check SocketFactory /Bind.*/ parameters in a Unix context, and
  # translate them into parameters bind() understands.
  elsif ($abstract_domain eq DOM_UNIX) {
    carp 'BindPort ignored for Unix socket' if defined $params{BindPort};

    if (defined $params{BindAddress}) {
      # Is this necessary, or will bind() return EADDRINUSE?
      if (defined $params{RemotePort}) {
        $! = EADDRINUSE;
        $poe_kernel->yield(
          $event_failure,
          'bind', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }

      $bind_address = &_condition_unix_address($params{BindAddress});
      $bind_address = pack_sockaddr_un($bind_address);
      unless ($bind_address) {
        $poe_kernel->yield(
          $event_failure,
          'pack_sockaddr_un', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }
    }
  }

  # This is an internal consistency error, and it should be hard
  # trapped right away.
  else {
    die "Mail this error to the author of POE: Internal consistency error";
  }

  # Perform the actual bind, if there's a bind address to bind to.
  if (defined $bind_address) {
    unless (bind($socket_handle, $bind_address)) {
      $poe_kernel->yield(
        $event_failure,
        'bind', $!+0, $!, $self->[MY_UNIQUE_ID]
      );
      return $self;
    }

    DEBUG && warn "bind";
  }

  #---------#
  # Connect #
  #---------#

  my $connect_address;

  if (defined $params{RemoteAddress}) {

    # Check SocketFactory /Remote.*/ parameters in an Internet socket
    # context, and translate them into parameters that connect()
    # understands.
    if (
      $abstract_domain eq DOM_INET or
      $abstract_domain eq DOM_INET6
    ) {
      # connecting if RemoteAddress
      croak 'RemotePort required' unless (defined $params{RemotePort});
      carp 'ListenQueue ignored' if (defined $params{ListenQueue});

      my $remote_port = $params{RemotePort};
      if ($remote_port =~ /[^0-9]/) {
        unless ($remote_port = getservbyname($remote_port, $protocol_name)) {
          $! = EADDRNOTAVAIL;
          $poe_kernel->yield(
            $event_failure,
            'getservbyname', $!+0, $!, $self->[MY_UNIQUE_ID]
          );
          return $self;
        }
      }

      my $error_tag;
      if ($abstract_domain eq DOM_INET) {
        $connect_address = inet_aton($params{RemoteAddress});
        $error_tag = "inet_aton";
      }
      elsif ($abstract_domain eq DOM_INET6) {
        my @info = Socket6::getaddrinfo(
          $params{RemoteAddress}, $remote_port,
          $self->[MY_SOCKET_DOMAIN], $self->[MY_SOCKET_TYPE],
        );

        if (@info < 5) {
          $connect_address = undef;
        }
        else {
          $connect_address = $info[3];
        }

        $error_tag = "getaddrinfo";
      }
      else {
        die "unknown domain $abstract_domain";
      }

      # TODO - If the gethostbyname2() code is removed, then we can
      # combine the previous code with the following code, and perhaps
      # remove one of these redundant $connect_address checks.  The
      # 0.29 release should tell us pretty quickly whether it's
      # needed.  If we reach 0.30 without incident, it's probably safe
      # to remove the old gethostbyname2() code and clean this up.
      unless (defined $connect_address) {
        $! = EADDRNOTAVAIL;
        $poe_kernel->yield(
          $event_failure,
          $error_tag, $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }

      if ($abstract_domain eq DOM_INET) {
        $connect_address = pack_sockaddr_in($remote_port, $connect_address);
        $error_tag = "pack_sockaddr_in";
      }
      elsif ($abstract_domain eq DOM_INET6) {
        $error_tag = "pack_sockaddr_in6";
      }
      else {
        die "unknown domain $abstract_domain";
      }

      unless ($connect_address) {
        $! = EADDRNOTAVAIL;
        $poe_kernel->yield(
          $event_failure,
          $error_tag, $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }
    }

    # Check SocketFactory /Remote.*/ parameters in a Unix socket
    # context, and translate them into parameters connect()
    # understands.
    elsif ($abstract_domain eq DOM_UNIX) {

      $connect_address = _condition_unix_address($params{RemoteAddress});
      $connect_address = pack_sockaddr_un($connect_address);
      unless (defined $connect_address) {
        $poe_kernel->yield(
          $event_failure,
          'pack_sockaddr_un', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }
    }

    # This is an internal consistency error, and it should be trapped
    # right away.
    else {
      die "Mail this error to the author of POE: Internal consistency error";
    }
  }

  else {
    carp "RemotePort ignored without RemoteAddress"
      if defined $params{RemotePort};
  }

  # Perform the actual connection, if a connection was requested.  If
  # the connection can be established, then return the SocketFactory
  # handle.
  if (defined $connect_address) {
    unless (connect($socket_handle, $connect_address)) {
      if ($! and ($! != EINPROGRESS) and ($! != EWOULDBLOCK)) {
        $poe_kernel->yield(
          $event_failure,
          'connect', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }
    }

    DEBUG && warn "connect";

    $self->[MY_SOCKET_HANDLE] = $socket_handle;
    $self->_define_connect_state();
    $self->event(
      SuccessEvent => $params{SuccessEvent},
      FailureEvent => $params{FailureEvent},
    );
    return $self;
  }

  #---------------------#
  # Listen, or Whatever #
  #---------------------#

  # A connection wasn't requested, so this must be a server socket.
  # Do whatever it is that needs to be done for whatever type of
  # server socket this is.
  if (exists $supported_protocol{$abstract_domain}->{$protocol_name}) {
    my $protocol_op = $supported_protocol{$abstract_domain}->{$protocol_name};

    DEBUG && warn "$abstract_domain + $protocol_name = $protocol_op";

    if ($protocol_op eq SVROP_LISTENS) {
      my $listen_queue = $params{ListenQueue} || SOMAXCONN;
      # <rmah> In SocketFactory, you limit the ListenQueue parameter
      #        to SOMAXCON (or is it SOCONNMAX?)...why?
      # <rmah> ah, here's czth, he'll have more to say on this issue
      # <czth> not really.  just that SOMAXCONN can lie, notably on
      #        Solaris and reportedly on BSDs too
      # 
      # ($listen_queue > SOMAXCONN) && ($listen_queue = SOMAXCONN);
      unless (listen($socket_handle, $listen_queue)) {
        $poe_kernel->yield(
          $event_failure,
          'listen', $!+0, $!, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }

      DEBUG && warn "listen";

      $self->[MY_SOCKET_HANDLE] = $socket_handle;
      $self->_define_accept_state();
      $self->event(
        SuccessEvent => $params{SuccessEvent},
        FailureEvent => $params{FailureEvent},
      );
      return $self;
    }
    else {
      carp "Ignoring ListenQueue parameter for non-listening socket"
        if defined $params{ListenQueue};
      if ($protocol_op eq SVROP_NOTHING) {
        # Do nothing.  Duh.  Fire off a success event immediately, and
        # return.
        $poe_kernel->yield(
          $event_success,
          $socket_handle, undef, undef, $self->[MY_UNIQUE_ID]
        );
        return $self;
      }
      else {
        die "Mail this error to the author of POE: Internal consistency error";
      }
    }
  }
  else {
    die "SocketFactory doesn't support $abstract_domain $protocol_name socket";
  }

  die "Mail this error to the author of POE: Internal consistency error";
}

# Pause and resume accept.
sub pause_accept {
  my $self = shift;
  if (
    defined $self->[MY_SOCKET_HANDLE] and
    defined $self->[MY_STATE_ACCEPT] and
    defined $self->[MY_SOCKET_SELECTED]
  ) {
    $poe_kernel->select_pause_read($self->[MY_SOCKET_HANDLE]);
  }
}

sub resume_accept {
  my $self = shift;
  if (
    defined $self->[MY_SOCKET_HANDLE] and
    defined $self->[MY_STATE_ACCEPT] and
    defined $self->[MY_SOCKET_SELECTED]
  ) {
    $poe_kernel->select_resume_read($self->[MY_SOCKET_HANDLE]);
  }
}

#------------------------------------------------------------------------------
# DESTROY and _shutdown pass things by reference because _shutdown is
# called from the state() closures above.  As a result, we can't
# mention $self explicitly, or the wheel won't shut itself down
# properly.  Rather, it will form a circular reference on $self.

sub DESTROY {
  my $self = shift;
  _shutdown(
    \$self->[MY_SOCKET_SELECTED],
    \$self->[MY_SOCKET_HANDLE],
    \$self->[MY_STATE_ACCEPT],
    \$self->[MY_STATE_CONNECT],
    \$self->[MY_MINE_SUCCESS],
    \$self->[MY_EVENT_SUCCESS],
    \$self->[MY_MINE_FAILURE],
    \$self->[MY_EVENT_FAILURE],
  );
  &POE::Wheel::free_wheel_id($self->[MY_UNIQUE_ID]);
}

sub _shutdown {
  my (
    $socket_selected, $socket_handle,
    $state_accept, $state_connect,
    $mine_success, $event_success,
    $mine_failure, $event_failure,
  ) = @_;

  if (defined $$socket_selected) {
    $poe_kernel->select($$socket_handle);
    $$socket_selected = undef;
  }

  if (defined $$state_accept) {
    $poe_kernel->state($$state_accept);
    $$state_accept = undef;
  }

  if (defined $$state_connect) {
    $poe_kernel->state($$state_connect);
    $$state_connect = undef;
  }

  if (defined $$mine_success) {
    $poe_kernel->state($$event_success);
    $$mine_success = $$event_success = undef;
  }

  if (defined $$mine_failure) {
    $poe_kernel->state($$event_failure);
    $$mine_failure = $$event_failure = undef;
  }
}

1;

__END__

=head1 NAME

POE::Wheel::SocketFactory - non-blocking socket creation

=head1 SYNOPSIS

See L<POE::Component::Server::TCP/SYNOPSIS> for a much simpler version
of this program.

  #!perl

  use warnings;
  use strict;

  use IO::Socket;
  use POE qw(Wheel::SocketFactory Wheel::ReadWrite);

  POE::Session->create(
    inline_states => {
      _start => sub {
        # Start the server.
        $_[HEAP]{server} = POE::Wheel::SocketFactory->new(
          BindPort => 12345,
          SuccessEvent => "on_client_accept",
          FailureEvent => "on_server_error",
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

POE::Wheel::SocketFactory creates sockets upon demand.  It can create
connectionless UDP sockets, but it really shines for client/server
work where establishing connections normally would block.

=head1 PUBLIC METHODS

=head2 new

new() creates a new POE::Wheel::SocketFactory object.  For sockets
which listen() for and accept() connections, the wheel will generate
new sockets for each accepted client.  Socket factories for one-shot
sockets, such as UDP peers or clients established by connect() only
emit a single socket and can be destroyed afterwards without ill
effects.

new() always returns a POE::Wheel::SocketFactory object even if it
fails to establish the socket.  This allows the object to be queried
after it has sent its session a C<FailureEvent>.

new() accepts a healthy number of named parameters, each governing
some aspect of socket creation.

=head3 Creating the Socket

Socket creation is done with Perl's built-in socket() function.  The
new() parameters beginning with C<Socket> determine how socket() will
be called.

=head4 SocketDomain

C<SocketDomain> instructs the wheel to create a socket within a
particular domain.  Supported domains are C<AF_UNIX>, C<AF_INET>,
C<AF_INET6>, C<PF_UNIX>, C<PF_INET>, and C<PF_INET6>.  If omitted, the
socket will be created in the C<AF_INET> domain.

POE::Wheel::SocketFactory contains a table of supported domains and
the instructions needed to create them.  Please send patches to
support additional domains, as needed.

Note: C<AF_INET6> and C<PF_INET6> are supplied by the L<Socket6>
module, which is available on the CPAN.  You must have Socket6 loaded
before SocketFactory can create IPv6 sockets.

TODO - Example.

=head4 SocketType

C<SocketType> supplies the socket() call with a particular socket
type, which may be C<SOCK_STREAM> or C<SOCK_DGRAM>.  C<SOCK_STREAM> is
the default if C<SocketType> is not supplied.

TODO - Example.

=head4 SocketProtocol

C<SocketProtocol> sets the socket() call's protocol.  Protocols may be
specified by number or name.  C<SocketProtocol> is ignored for UNIX
domain sockets.

The protocol defaults to "tcp" for INET domain sockets.  There is no
default for other socket domains.

TODO - Example.

=head3 Setting Socket Options

POE::Wheel::SocketFactory uses ioctl(), fcntl() and setsockopt() to
set socket options after the socket is created.  All sockets are set
non-blocking, and bound sockets may be made reusable.

=head4 Reuse

When set, the C<Reuse> parameter allows a bound port to be reused
immediately.  C<Reuse> is considered enabled if it contains "yes",
"on", or a true numeric value.  All other values disable port reuse,
as does omitting C<Reuse> entirely.

For security purposes, a port cannot be reused for a minute or more
after a server has released it.  This gives clients time to realize
the port has been abandoned.  Otherwise a malicious service may snatch
up the port and spoof the legitimate service.

It's also terribly annoying to wait a minute or more between server
invocations, especially during development.

=head3 Bind the Socket to an Address and Port

A socket may optionally be bound to a specific interface and port.
The C<INADDR_ANY> address may be used to bind to a specific port
across all interfaces.

Sockets are bound using bind().  POE::Wheel::SocketFactory parameters
beginning with C<Bind> control how bind() is called.

=head4 BindAddress

C<BindAddress> sets an address to bind the socket's local endpoint to.
C<INADDR_ANY> will be used if C<BindAddress> is not specified.

C<BindAddress> may contain either a string or a packed Internet
address (for "INET" domain sockets).  The string parameter should be a
dotted numeric address or a resolvable host name.  Note that the host
name will be resolved with a blocking call.  If this is not desired,
use POE::Component::Client::DNS to perform a non-blocking name
resolution.

When used to bind a "UNIX" domain socket, C<BindAddress> should
contain a path describing the socket's filename.  This is required for
server sockets and datagram client sockets.  C<BindAddress> has no
default value for UNIX sockets.

TODO - Example.

=head4 BindPort

C<BindPort> is only meaningful for "INET" domain sockets.  It contains
a port on the C<BindAddress> interface where the socket will be bound.
It defaults to 0 if omitted, which will cause the bind() call to
choose an indeterminate unallocated port.

C<BindPort> may be a port number or a name that can be looked up in
the system's services (or equivalent) database.

TODO - Example.

=head3 Connectionless Sockets

Connectionless sockets may interact with remote endpoints without
needing to listen() for connections or connect() to remote addresses.

This class of sockets is complete after the bind() call.

TODO - Example.

=head3 Connecting the Socket to a Remote Endpoint

A socket may either listen for connections to arrive, initiate
connections to a remote endpoint, or be connectionless (such as in the
case of UDP sockets).

POE::Wheel::SocketFactory will initiate a client connection when new()
is capped with parameters that describe a remote endpoint.  In all
other cases, the socket will either listen for connections or be
connectionless depending on the socket type.

The following parameters describe a socket's remote endpoint.  They
determine how POE::Wheel::SocketFactory will call Perl's built-in
connect() function.

=head4 RemoteAddress

C<RemoteAddress> specifies the remote address to which a socket should
connect.  If present, POE::Wheel::SocketFactory will create a client
socket that attempts to collect to the C<RemoteAddress>.  Otherwise,
if the protocol warrants it, the wheel will create a listening socket
and attempt to accept connections.

As with the bind address, C<RemoteAddress> may be a string containing
a dotted quad or a resolvable host name.  It may also be a packed
Internet address, or a UNIX socket path.  It will be packed, with or
without an accompanying C<RemotePort>, as necessary for the socket
domain.

TODO - Example.

=head4 RemotePort

C<RemotePort> is the port to which the socket should connect.  It is
required for "INET" client sockets, since the remote endpoint must
contain both an address and a port.

The remote port may be numeric, or it may be a symbolic name found in
/etc/services or the equivalent for your operating system.

TODO - Example.

=head3 Listening for Connections

Streaming sockets that have no remote endpoint are considered to be
server sockets.  POE::Wheel::SocketFactory will listen() for
connections to these sockets, accept() the new clients, and send the
application events with the new client sockets.

POE::Wheel::SocketFactory constructor parameters beginning with
C<Listen> control how the listen() function is called.

=head4 ListenQueue

C<ListenQueue> specifies the length of the socket's listen() queue.
It defaults to C<SOMAXCONN> if omitted.  C<ListenQueue> values greater
than C<SOMAXCONN> will be clipped to C<SOMAXCONN>.  Excessively large
C<ListenQueue> values are not necessarily portable, and may cause
errors in some rare cases.

TODO - Example.

=head3 Emitting Events

POE::Wheel::SocketFactory emits a small number of events depending on
what happens during socket setup or while listening for new
connections.

See L</PUBLIC EVENTS> for more details.

=head4 SuccessEvent

C<SuccessEvent> names the event that will be emitted whenever
POE::Wheel::SocketFactory succeeds in creating a new socket.

For connectionless sockets, C<SuccessEvent> happens just after the
socket is created.

For client connections, C<SuccessEvent> is fired when the connection
has successfully been established with the remote endpoint.

Server sockets emit a C<SuccessEvent> for every successfully accepted
client.

=head4 FailureEvent

C<FailureEvent> names the event POE::Wheel::SocketFactory will emit
whenever something goes wrong.  It usually represents some kind of
built-in function call error.  See L</PUBLIC EVENTS> for details, as
some errors are handled internally by this wheel.

=head2 event

event() allows a session to change the events emitted by a wheel
without destroying and re-creating the wheel.  It accepts one or more
of the events listed in L</PUBLIC EVENTS>.  Undefined event names
disable those events.

event() is described in more depth in L<POE::Wheel>.

TODO - Example.

=head2 getsockname

getsockname() behaves like the built-in function of the same name.  It
returns the local endpoint information for POE::Wheel::SocketFactory's
encapsulated listening socket.

getsockname() allows applications to determine the address and port
to which POE::Wheel::SocketFactory has bound its listening socket.

Test applications may use getsockname() to find the server socket
after POE::Wheel::SocketFactory has bound to INADDR_ANY port 0.

TODO - Example.

=head2 ID

ID() returns the wheel's unique ID.  The ID will also be included in
every event the wheel generates.  Applications can match events back
to the objects that generated them.

TODO - Example.

=head2 pause_accept

Applications may occasionally need to block incoming connections.
pause_accept() pauses the event watcher that triggers accept().  New
inbound connections will stack up in the socket's listen() queue until
the queue overflows or the application calls resume_accept().

Pausing accept() can limit the amount of load a server generates.
It's also useful in pre-forking servers when the master process
shouldn't accept connections at all.

pause_accept() and resume_accept() is quicker and more reliable than
dynamically destroying and re-creating a POE::Wheel::SocketFactory
object.

TODO - Example.

=head2 resume_accept

resume_accept() resumes the watcher that triggers accept().  See
L</pause_accept> for a more detailed discussion.

=head1 PUBLIC EVENTS

POE::Wheel::SocketFactory emits two public events.

=head2 SuccessEvent

C<SuccessEvent> names an event that will be sent to the creating
session whenever a POE::Wheel::SocketFactory has created a new socket.
For connectionless sockets, it's when the socket is created.  For
connecting clients, it's after the connection has been established.
And for listening servers, C<SuccessEvent> is fired after each new
client is accepted.

=head3 Common SuccessEvent Parameters

In all cases, C<$_[ARG0]> holds the new socket's filehandle, and
C<$_[ARG3]> contains the POE::Wheel::SocketFactory's ID.  Other
parameters vary depending on the socket's domain and whether it's
listening or connecting.  See below for the differences.

=head3 INET SuccessEvent Parameters

For INET sockets, C<$_[ARG1]> and C<$_[ARG2]> hold the socket's remote
address and port, respectively.  The address is packed; see
L<Socket/inet_ntoa> if a human-readable version is needed.

  sub handle_new_client {
    my $accepted_socket = $_[ARG0];

    my $peer_host = inet_ntoa($_[ARG1]);
    print(
      "Wheel $_[ARG3] accepted a connection from ",
      "$peer_host port $peer_port\n"
    );

    spawn_connection_session($accepted_handle);
  }

=head3 UNIX Client SuccessEvent Parameters

For UNIX client sockets, C<$_[ARG1]> often (but not always) holds the
server address.  Some systems cannot retrieve a UNIX socket's remote
address.  C<$_[ARG2]> is always undef for UNIX client sockets.

=head3 UNIX Server SuccessEvent Parameters

According to I<Perl Cookbook>, the remote address returned by accept()
on UNIX sockets is undefined, so C<$_[ARG1]> and C<$_[ARG2]> are also
undefined in this case.

=head2 FailureEvent

C<FailureEvent> names the event that will be emitted when a socket
error occurs.  POE::Wheel::SocketFactory handles C<EAGAIN> internally,
so it doesn't count as an error.

C<FailureEvent> events include the standard error event parameters:

C<$_[ARG0]> describes which part of socket creation failed.  It often
holds a Perl built-in function name.

C<$_[ARG1]> and C<$_[ARG2]> describe how the operation failed.  They
contain the numeric and stringified versions of C<$!>, respectively.
An application cannot merely check the global C<$!> variable since it
may change during event dispatch.

Finally, C<$_[ARG3]> contains the ID for the POE::Wheel::SocketFactory
instance that generated the event.  See L</ID> and L<POE::Wheel/ID>
for uses for wheel IDs.

A sample FailureEvent handler:

  sub handle_failure {
    my ($operation, $errnum, $errstr, $wheel_id) = @_[ARG0..ARG3];
    warn "Wheel $wheel_id generated $operation error $errnum: $errstr\n";
    delete $_[HEAP]{wheels}{$wheel_id}; # shut down that wheel
  }

=head1 SEE ALSO

L<POE::Wheel> describes the basic operations of all wheels in more
depth.  You need to know this.

L<Socket6> is required for IPv6 work.  POE::Wheel::SocketFactory will
load it automatically if it's installed, but applications will need to
use it themselves to get access to AF_INET6.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

Many (if not all) of the croak/carp/warn/die statements should fire
back C<FailureEvent> instead.

SocketFactory is only tested with UNIX streams and INET sockets using
the UDP and TCP protocols.  Others should work after the module's
internal configuration tables are updated.  Please send patches.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
