# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::Transport;

# $Id: Transport.pm,v 3.0 2009/09/09 15:05:33 dtown Rel $

# Base object for the Net::SNMP Transport Domain objects.

# Copyright (c) 2004-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

## Version of the Net::SNMP::Transport module

our $VERSION = v3.0.0;

## Handle importing/exporting of symbols

use base qw( Exporter );

our @EXPORT_OK = qw( TRUE FALSE DEBUG_INFO );

our %EXPORT_TAGS = (
   domains => [
      qw( DOMAIN_UDP DOMAIN_UDPIPV4 DOMAIN_UDPIPV6 DOMAIN_UDPIPV6Z
          DOMAIN_TCPIPV4 DOMAIN_TCPIPV6 DOMAIN_TCPIPV6Z )
   ],
   msgsize => [ qw( MSG_SIZE_DEFAULT MSG_SIZE_MINIMUM MSG_SIZE_MAXIMUM ) ],
   ports   => [ qw( SNMP_PORT SNMP_TRAP_PORT )                           ],
   retries => [ qw( RETRIES_DEFAULT RETRIES_MINIMUM RETRIES_MAXIMUM )    ],
   timeout => [ qw( TIMEOUT_DEFAULT TIMEOUT_MINIMUM TIMEOUT_MAXIMUM )    ],
);

Exporter::export_ok_tags( qw( domains msgsize ports retries timeout ) );

$EXPORT_TAGS{ALL} = [ @EXPORT_OK ];

## Transport Layer Domain definitions

# RFC 3417 Transport Mappings for SNMP
# Presuhn, Case, McCloghrie, Rose, and Waldbusser; December 2002

sub DOMAIN_UDP             { '1.3.6.1.6.1.1' }  # snmpUDPDomain

# RFC 3419 Textual Conventions for Transport Addresses
# Consultant, Schoenwaelder, and Braunschweig; December 2002

sub DOMAIN_UDPIPV4   { '1.3.6.1.2.1.100.1.1' }  # transportDomainUdpIpv4
sub DOMAIN_UDPIPV6   { '1.3.6.1.2.1.100.1.2' }  # transportDomainUdpIpv6
sub DOMAIN_UDPIPV6Z  { '1.3.6.1.2.1.100.1.4' }  # transportDomainUdpIpv6z
sub DOMAIN_TCPIPV4   { '1.3.6.1.2.1.100.1.5' }  # transportDomainTcpIpv4
sub DOMAIN_TCPIPV6   { '1.3.6.1.2.1.100.1.6' }  # transportDomainTcpIpv6
sub DOMAIN_TCPIPV6Z  { '1.3.6.1.2.1.100.1.8' }  # transportDomainTcpIpv6z

## SNMP well-known ports

sub SNMP_PORT             { 161 }
sub SNMP_TRAP_PORT        { 162 }

## RFC 3411 - snmpEngineMaxMessageSize::=INTEGER (484..2147483647)

sub MSG_SIZE_DEFAULT     {  484 }
sub MSG_SIZE_MINIMUM     {  484 }
sub MSG_SIZE_MAXIMUM    { 65535 }   # 2147483647 is not reasonable

sub RETRIES_DEFAULT        {  1 }
sub RETRIES_MINIMUM        {  0 }
sub RETRIES_MAXIMUM        { 20 }

sub TIMEOUT_DEFAULT      {  5.0 }
sub TIMEOUT_MINIMUM      {  1.0 }
sub TIMEOUT_MAXIMUM      { 60.0 }

## Truth values

sub TRUE                 { 0x01 }
sub FALSE                { 0x00 }

## Shared socket array indexes

sub _SHARED_SOCKET          { 0 }   # Shared Socket object
sub _SHARED_REFC            { 1 }   # Reference count
sub _SHARED_MAXSIZE         { 2 }   # Shared maxMsgSize

## Package variables

our $DEBUG = FALSE;                 # Debug flag

our $AUTOLOAD;                      # Used by the AUTOLOAD method

our $SOCKETS = {};                  # List of shared sockets

# [public methods] -----------------------------------------------------------

{
   my $domains = {
      'udp/?(?:ip)?v?4?',          DOMAIN_UDPIPV4,
      quotemeta DOMAIN_UDP,        DOMAIN_UDPIPV4,
      quotemeta DOMAIN_UDPIPV4,    DOMAIN_UDPIPV4,
      'udp/?(?:ip)?v?6',           DOMAIN_UDPIPV6,
      quotemeta DOMAIN_UDPIPV6,    DOMAIN_UDPIPV6,
      quotemeta DOMAIN_UDPIPV6Z,   DOMAIN_UDPIPV6,
      'tcp/?(?:ip)?v?4?',          DOMAIN_TCPIPV4,
      quotemeta DOMAIN_TCPIPV4,    DOMAIN_TCPIPV4,
      'tcp/?(?:ip)?v?6',           DOMAIN_TCPIPV6,
      quotemeta DOMAIN_TCPIPV6,    DOMAIN_TCPIPV6,
      quotemeta DOMAIN_TCPIPV6Z,   DOMAIN_TCPIPV6,
   };

   sub new
   {
      my ($class, %argv) = @_;

      my $domain = DOMAIN_UDPIPV4;
      my $error  = q{};

      # See if a Transport Layer Domain argument has been passed.

      for (keys %argv) {

         if (/^-?domain$/i) {

            my $key = $argv{$_};
            $domain = undef;

            for (keys %{$domains}) {
               if ($key =~ /^$_$/i) {
                  $domain = $domains->{$_};
                  last;
               }
            }

            if (!defined $domain) {
               $error = err_msg(
                  'The transport domain "%s" is unknown', $argv{$_}
               );
               return wantarray ? (undef, $error) : undef;
            }

            $argv{$_} = $domain;
         }

      }

      # Return the appropriate object based on the Transport Domain.  To
      # avoid consuming unnecessary resources, only load the appropriate
      # module when requested.   Some modules require non-core modules and
      # if these modules are not present, we gracefully return an error. 

      if ($domain eq DOMAIN_UDPIPV6) {

         if (defined ($error = load_module('Net::SNMP::Transport::IPv6::UDP')))
         {
            $error = 'UDP/IPv6 support is unavailable ' . $error;
            return wantarray ? (undef, $error) : undef;
         }
         return Net::SNMP::Transport::IPv6::UDP->new(%argv);

      } elsif ($domain eq DOMAIN_TCPIPV6) {

         if (defined ($error = load_module('Net::SNMP::Transport::IPv6::TCP')))
         {
            $error = 'TCP/IPv6 support is unavailable ' . $error;
            return wantarray ? (undef, $error) : undef;
         }
         return Net::SNMP::Transport::IPv6::TCP->new(%argv);

      } elsif ($domain eq DOMAIN_TCPIPV4) {

         if (defined ($error = load_module('Net::SNMP::Transport::IPv4::TCP')))
         {
            $error = 'TCP/IPv4 support is unavailable ' . $error;
            return wantarray ? (undef, $error) : undef;
         }
         return Net::SNMP::Transport::IPv4::TCP->new(%argv);

      }

      # Load the default Transport Domain module without eval protection.

      require Net::SNMP::Transport::IPv4::UDP;
      return  Net::SNMP::Transport::IPv4::UDP->new(%argv);
   }

}

sub max_msg_size
{
   my ($this, $size) = @_;

   if (@_ < 2) {
      return $this->{_max_msg_size};
   }

   $this->_error_clear();

   if ($size !~ m/^\d+$/) {
      return $this->_error(
         'The maxMsgSize value "%s" is expected in positive numeric format',
         $size
      );
   }

   if ($size < MSG_SIZE_MINIMUM || $size > MSG_SIZE_MAXIMUM) {
      return $this->_error(
         'The maxMsgSize value %s is out of range (%d..%d)',
         $size, MSG_SIZE_MINIMUM, MSG_SIZE_MAXIMUM
      );
   }

   # Adjust the share maximum size if necessary.
   $this->_shared_max_size($size);

   return $this->{_max_msg_size} = $size;
}

sub timeout
{
   my ($this, $timeout) = @_;

   if (@_ < 2) {
      return $this->{_timeout};
   }

   $this->_error_clear();

   if ($timeout !~ m/^\d+(?:\.\d+)?$/) {
      return $this->_error(
         'The timeout value "%s" is expected in positive numeric format',
         $timeout
      );
   }

   if ($timeout < TIMEOUT_MINIMUM || $timeout > TIMEOUT_MAXIMUM) {
      return $this->_error(
         'The timeout value %s is out of range (%d..%d)',
         $timeout, TIMEOUT_MINIMUM, TIMEOUT_MAXIMUM
      );
   }

   return $this->{_timeout} = $timeout;
}

sub retries
{
   my ($this, $retries) = @_;

   if (@_ < 2) {
      return $this->{_retries};
   }

   $this->_error_clear();

   if ($retries !~ m/^\d+$/) {
      return $this->_error(
         'The retries value "%s" is expected in positive numeric format',
         $retries
      );
   }

   if ($retries < RETRIES_MINIMUM || $retries > RETRIES_MAXIMUM) {
      return $this->_error(
         'The retries value %s is out of range (%d..%d)',
         $retries, RETRIES_MINIMUM, RETRIES_MAXIMUM
      );
   }

   return $this->{_retries} = $retries;
}

sub agent_addr
{
   return '0.0.0.0';
}

sub connectionless
{
   return TRUE;
}

sub debug
{
   return (@_ == 2) ? $DEBUG = ($_[1]) ? TRUE : FALSE : $DEBUG;
}

sub domain
{
   return '0.0';
}

sub error
{
   return $_[0]->{_error} || q{};
}

sub fileno
{
   return defined($_[0]->{_socket}) ? $_[0]->{_socket}->fileno() : undef;
}

sub socket
{
   return $_[0]->{_socket};
}

sub type
{
   return '<unknown>'; # unknown(0)
}

sub sock_name
{
   if (defined $_[0]->{_socket}) {
      return $_[0]->{_socket}->sockname() || $_[0]->{_sock_name};
   } else {
      return $_[0]->{_sock_name};
   }
}

sub sock_hostname
{
   return $_[0]->{_sock_hostname} || $_[0]->sock_address();
}

sub sock_address
{
   return $_[0]->_address($_[0]->sock_name());
}

sub sock_addr
{
   return $_[0]->_addr($_[0]->sock_name());
}

sub sock_port
{
   return $_[0]->_port($_[0]->sock_name());
}

sub sock_taddress
{
   return $_[0]->_taddress($_[0]->sock_name());
}

sub sock_taddr
{
   return $_[0]->_taddr($_[0]->sock_name());
}

sub sock_tdomain
{
   return $_[0]->_tdomain($_[0]->sock_name());
}

sub dest_name
{
   return $_[0]->{_dest_name};
}

sub dest_hostname
{
   return $_[0]->{_dest_hostname} || $_[0]->dest_address();
}

sub dest_address
{
   return $_[0]->_address($_[0]->dest_name());
}

sub dest_addr
{
   return $_[0]->_addr($_[0]->dest_name());
}

sub dest_port
{
   return $_[0]->_port($_[0]->dest_name());
}

sub dest_taddress
{
   return $_[0]->_taddress($_[0]->dest_name());
}

sub dest_taddr
{
   return $_[0]->_taddr($_[0]->dest_name());
}

sub dest_tdomain
{
   return $_[0]->_tdomain($_[0]->dest_name());
}

sub peer_name
{
   if (defined $_[0]->{_socket}) {
      return $_[0]->{_socket}->peername() || $_[0]->dest_name();
   } else {
      return $_[0]->dest_name();
   }
}

sub peer_hostname
{
   return $_[0]->peer_address();
}

sub peer_address
{
   return $_[0]->_address($_[0]->peer_name());
}

sub peer_addr
{
   return $_[0]->_addr($_[0]->peer_name());
}

sub peer_port
{
   return $_[0]->_port($_[0]->peer_name());
}

sub peer_taddress
{
   return $_[0]->_taddress($_[0]->peer_name());
}

sub peer_taddr
{
   return $_[0]->_taddr($_[0]->peer_name());
}

sub peer_tdomain
{
   return $_[0]->_tdomain($_[0]->peer_name());
}

sub AUTOLOAD
{
   my $this = shift;

   return if $AUTOLOAD =~ /::DESTROY$/;

   $AUTOLOAD =~ s/.*://;

   if (ref $this) {
      if (defined($this->{_socket}) && ($this->{_socket}->can($AUTOLOAD))) {
         return $this->{_socket}->$AUTOLOAD(@_);
      } else {
         $this->_error_clear();
         return $this->_error(
            'The method "%s" is not supported by this Transport Domain',
            $AUTOLOAD
         );
      }
   } else {
      require Carp;
      Carp::croak(sprintf 'The function "%s" is not supported', $AUTOLOAD);
   }

   # Never get here.
   return;
}

sub DESTROY
{
   my ($this) = @_;

   # Connection-oriented transports do not share sockets.
   return if !$this->connectionless();

   # If the shared socket structure exists, decrement the reference count
   # and clear the shared socket structure if it is no longer being used. 

   if (defined($this->{_sock_name}) && exists $SOCKETS->{$this->{_sock_name}}) {
      if (--$SOCKETS->{$this->{_sock_name}}->[_SHARED_REFC] < 1) {
         delete $SOCKETS->{$this->{_sock_name}};
      }
   }

   return;
}

## Obsolete methods - previous deprecated 

sub OBSOLETE
{
   my ($this, $method) = splice @_, 0, 2;

   require Carp;
   Carp::croak(
      sprintf '%s() is obsolete, use %s() instead', (caller 1)[3], $method
   );

   # Never get here.
   return $this->${\$method}(@_);
}

sub name     { return $_[0]->OBSOLETE('type');          }

sub srcaddr  { return $_[0]->OBSOLETE('sock_addr');     }

sub srcport  { return $_[0]->OBSOLETE('sock_port');     }

sub srchost  { return $_[0]->OBSOLETE('sock_address');  }

sub srcname  { return $_[0]->OBSOLETE('sock_address');  }

sub dstaddr  { return $_[0]->OBSOLETE('dest_addr');     }

sub dstport  { return $_[0]->OBSOLETE('dest_port');     }

sub dsthost  { return $_[0]->OBSOLETE('dest_address');  }

sub dstname  { return $_[0]->OBSOLETE('dest_hostname'); }

sub recvaddr { return $_[0]->OBSOLETE('peer_addr');     }

sub recvport { return $_[0]->OBSOLETE('peer_port');     }

sub recvhost { return $_[0]->OBSOLETE('peer_address');  }


# [private methods] ----------------------------------------------------------

sub _new
{
   my ($class, %argv) = @_;

   my $this = bless {
      '_dest_hostname' => 'localhost',                 # Destination hostname
      '_dest_name'     => undef,                       # Destination sockaddr
      '_error'         => undef,                       # Error message
      '_max_msg_size'  => $class->_msg_size_default(), # maxMsgSize
      '_retries'       => RETRIES_DEFAULT,             # Number of retries      
      '_socket'        => undef,                       # Socket object
      '_sock_hostname' => q{},                         # Socket hostname
      '_sock_name'     => undef,                       # Socket sockaddr
      '_timeout'       => TIMEOUT_DEFAULT,             # Timeout period (secs)
   }, $class;

   # Default the values for the "name (sockaddr) hashes".

   my $sock_nh = { port => 0,         addr => $this->_addr_any()      };
   my $dest_nh = { port => SNMP_PORT, addr => $this->_addr_loopback() };

   # Validate the "port" arguments first to allow for a consistency
   # check with any values passed with the "address" arguments.

   my ($dest_port, $sock_port, $listen) = (undef, undef, 0);

   for (keys %argv) {

      if (/^-?debug$/i) {
         $this->debug(delete $argv{$_});
      } elsif (/^-?(?:de?st|peer)?port$/i) {
         $this->_service_resolve(delete($argv{$_}), $dest_nh);
         $dest_port = $dest_nh->{port};
      } elsif (/^-?(?:src|sock|local)port$/i) {
         $this->_service_resolve(delete($argv{$_}), $sock_nh);
         $sock_port = $sock_nh->{port};
      }

      if (defined $this->{_error}) {
         return wantarray ? (undef, $this->{_error}) : undef;
      }
   }

   # Validate the rest of the arguments.

   for (keys %argv) {

      if (/^-?domain$/i) {
         if ($argv{$_} ne $this->domain()) {
            $this->_error(
               'The domain value "%s" was expected, but "%s" was found',
               $this->domain(), $argv{$_}
            );
         }
      } elsif ((/^-?hostname$/i) || (/^-?(?:de?st|peer)?addr$/i)) {
         $this->_hostname_resolve(
            $this->{_dest_hostname} = $argv{$_}, $dest_nh
         );
         if (defined($dest_port) && ($dest_port != $dest_nh->{port})) {
            $this->_error(
               'Inconsistent %s port information was specified (%d != %d)',
               $this->type(), $dest_port, $dest_nh->{port}
            );
         }
      } elsif (/^-?(?:src|sock|local)addr$/i) {
         $this->_hostname_resolve(
            $this->{_sock_hostname} = $argv{$_}, $sock_nh
         );
         if (defined($sock_port) && ($sock_port != $sock_nh->{port})) {
            $this->_error(
               'Inconsistent %s port information was specified (%d != %d)',
               $this->type(), $sock_port, $sock_nh->{port}
            );
         }
      } elsif (/^-?listen$/i) {
         if (($argv{$_} !~ /^\d+$/) || ($argv{$_} < 1)) {
            $this->_error(
               'The listen queue size value "%s" was expected in positive ' .
               'non-zero numeric format', $argv{$_}
            );
         } elsif (!$this->connectionless()) {
            $listen = $argv{$_};
         }
      } elsif ((/^-?maxmsgsize$/i) || (/^-?mtu$/i)) {
         $this->max_msg_size($argv{$_});
      } elsif (/^-?retries$/i) {
         $this->retries($argv{$_});
      } elsif (/^-?timeout$/i) {
         $this->timeout($argv{$_});
      } else {
         $this->_error('The argument "%s" is unknown', $_);
      }

      if (defined $this->{_error}) {
         return wantarray ? (undef, $this->{_error}) : undef;
      }

   }

   # Pack the socket name (sockaddr) information.
   $this->{_sock_name} = $this->_name_pack($sock_nh);

   # Pack the destination name (sockaddr) information.
   $this->{_dest_name} = $this->_name_pack($dest_nh);

   # For all connection-oriented transports and for each unique source 
   # address for connectionless transports, create a new socket. 

   if (!$this->connectionless() || !exists $SOCKETS->{$this->{_sock_name}}) {

      # Create a new IO::Socket object.

      if (!defined ($this->{_socket} = $this->_socket_create())) {
         $this->_perror('Failed to open %s socket', $this->type());
         return wantarray ? (undef, $this->{_error}) : undef
      }

      DEBUG_INFO('opened %s socket [%d]', $this->type(), $this->fileno());

      # Bind the socket.

      if (!defined $this->{_socket}->bind($this->{_sock_name})) {
         $this->_perror('Failed to bind %s socket', $this->type());
         return wantarray ? (undef, $this->{_error}) : undef
      }

      # For connection-oriented transports, we either listen or connect.

      if (!$this->connectionless()) {

         if ($listen) {
            if (!defined $this->{_socket}->listen($listen)) {
               $this->_perror('Failed to listen on %s socket', $this->type());
               return wantarray ? (undef, $this->{_error}) : undef
            }
         } else {
            if (!defined $this->{_socket}->connect($this->{_dest_name})) {
               $this->_perror(
                  q{Failed to connect to remote host '%s'},
                  $this->dest_hostname()
               );
               return wantarray ? (undef, $this->{_error}) : undef
            }
         }
      }

      # Flag the socket as non-blocking outside of socket creation or 
      # the object instantiation fails on some systems (e.g. MSWin32). 

      $this->{_socket}->blocking(FALSE);

      # Add the socket to the global socket list with a reference
      # count to track when to close the socket and the maxMsgSize
      # associated with this new object for connectionless transports.

      if ($this->connectionless()) {
         $SOCKETS->{$this->{_sock_name}} = [
            $this->{_socket},       # Shared Socket object
            1,                      # Reference count
            $this->{_max_msg_size}, # Shared maximum message size
         ];
      }

   } else {

      # Bump up the reference count.
      $SOCKETS->{$this->{_sock_name}}->[_SHARED_REFC]++;

      # Assign the socket to the object.
      $this->{_socket} = $SOCKETS->{$this->{_sock_name}}->[_SHARED_SOCKET];

      # Adjust the shared maxMsgSize if necessary.
      $this->_shared_max_size($this->{_max_msg_size});

      DEBUG_INFO('reused %s socket [%d]', $this->type(), $this->fileno());

   }

   # Return the object and empty error message (in list context)
   return wantarray ? ($this, q{}) : $this;
}

sub _service_resolve
{
   my ($this, $serv, $nh) = @_;

   $nh->{port} = undef;

   if ($serv !~ /^\d+$/) {
      my $port = ($serv =~ s/\((\d+)\)$//) ? ($1 > 65535) ? undef : $1 : undef;
      $nh->{port} = getservbyname($serv, $this->_protocol_name()) || $port;
      if (!defined $nh->{port}) {
         return $this->_error(
            'Unable to resolve the %s service name "%s"', $this->type(), $_[1]
         );
      }
   } elsif ($serv > 65535) {
      return $this->_error(
         'The %s port number %s is out of range (0..65535)',
         $this->type(), $serv
      );
   } else {
      $nh->{port} = $serv;
   }

   return $nh->{port};
}

sub _protocol
{
   return (getprotobyname $_[0]->_protocol_name())[2];
}

sub _shared_max_size
{
   my ($this, $size) = @_;

   # Connection-oriented transports do not share sockets.
   if (!$this->connectionless()) {
      return $this->{_max_msg_size};
   }

   if (@_ == 2) {

      # Handle calls during object creation.
      if (!defined $this->{_sock_name}) {
         return $this->{_max_msg_size};
      }

      # Update the shared maxMsgSize if the passed
      # value is greater than the current size.

      if ($size > $SOCKETS->{$this->{_sock_name}}->[_SHARED_MAXSIZE]) {
         $SOCKETS->{$this->{_sock_name}}->[_SHARED_MAXSIZE] = $size;
      }

   }

   return $SOCKETS->{$this->{_sock_name}}->[_SHARED_MAXSIZE];
}

sub _msg_size_default
{
   return MSG_SIZE_DEFAULT;
}

sub _error
{
   my $this = shift;

   if (!defined $this->{_error}) {
      $this->{_error} = (@_ > 1) ? sprintf(shift(@_), @_) : $_[0];
      if ($this->debug()) {
         printf "error: [%d] %s(): %s\n",
                (caller 0)[2], (caller 1)[3], $this->{_error};
      }
   }

   return;
}

sub strerror
{
   if ($! =~ /^Unknown error/) {
      return sprintf '%s', $^E if ($^E);
      require Errno;
      for (keys (%!)) {
         if ($!{$_}) {
            return sprintf 'Error %s', $_;
         }
      }
      return sprintf '%s (%d)', $!, $!;
   }

   return $! ? sprintf('%s', $!) : 'No error';
}

sub _perror
{
   my $this = shift;

   if (!defined $this->{_error}) {
      $this->{_error}  = ((@_ > 1) ? sprintf(shift(@_), @_) : $_[0]) || q{};
      $this->{_error} .= (($this->{_error}) ? ': ' : q{}) . strerror();
      if ($this->debug()) {
         printf "error: [%d] %s(): %s\n",
                (caller 0)[2], (caller 1)[3], $this->{_error};
      }
   }

   return;
}

sub _error_clear
{
   $! = 0;
   return $_[0]->{_error} = undef;
}

{
   my %modules;

   sub load_module
   {
      my ($module) = @_;

      # We attempt to load the required module under the protection of an 
      # eval statement.  If there is a failure, typically it is due to a 
      # missing module required by the requested module and we attempt to 
      # simplify the error message by just listing that module.  We also 
      # need to track failures since require() only produces an error on 
      # the first attempt to load the module.

      # NOTE: Contrary to our typical convention, a return value of "undef"
      # actually means success and a defined value means error.

      return $modules{$module} if exists $modules{$module};

      if (!eval "require $module") {
         if ($@ =~ /locate (\S+\.pm)/) {
            $modules{$module} = err_msg('(Required module %s not found)', $1);
         } elsif ($@ =~ /(.*)\n/) {
            $modules{$module} = err_msg('(%s)', $1);
         } else {
            $modules{$module} = err_msg('(%s)', $@);
         }
      } else {
         $modules{$module} = undef;
      }

      return $modules{$module};
   }
}

sub err_msg
{
   my $msg = (@_ > 1) ? sprintf(shift(@_), @_) : $_[0];

   if ($DEBUG) {
      printf "error: [%d] %s(): %s\n", (caller 0)[2], (caller 1)[3], $msg;
   }

   return $msg;
}

sub DEBUG_INFO
{
   return $DEBUG if (!$DEBUG);

   return printf
      sprintf('debug: [%d] %s(): ', (caller 0)[2], (caller 1)[3]) .
      ((@_ > 1) ? shift(@_) : '%s') .
      "\n",
      @_;
}

# ============================================================================
1; # [end Net::SNMP::Transport]
