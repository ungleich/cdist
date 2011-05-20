# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::Transport::IPv6;

# $Id: IPv6.pm,v 1.1 2009/09/09 15:08:31 dtown Rel $

# Base object for the IPv6 Transport Domains.

# Copyright (c) 2008-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Transport qw( DEBUG_INFO );

use Socket6 0.23 qw(
   PF_INET6 AF_INET6 in6addr_any in6addr_loopback getaddrinfo
   pack_sockaddr_in6_all unpack_sockaddr_in6_all inet_pton inet_ntop
);

## Version of the Net::SNMP::Transport::IPv6 module

our $VERSION = v1.0.0;

# [public methods] -----------------------------------------------------------

sub agent_addr
{
   return '0.0.0.0';
}

sub sock_flowinfo
{
   return $_[0]->_flowinfo($_[0]->sock_name());
}

sub sock_scope_id
{
   return $_[0]->_scope_id($_[0]->sock_name());
}

sub sock_tzone
{
   goto &sock_scope_id;
}

sub dest_flowinfo
{
   return $_[0]->_flowinfo($_[0]->dest_name());
}

sub dest_scope_id
{
   return $_[0]->_scope_id($_[0]->dest_name());
}

sub dest_tzone
{
   goto &dest_scope_id;
}

sub peer_flowinfo
{
   return $_[0]->_flowinfo($_[0]->peer_name());
}

sub peer_scope_id
{
   return $_[0]->_scope_id($_[0]->peer_name());
}

sub peer_tzone
{
   goto &peer_scope_id;
}

# [private methods] ----------------------------------------------------------

sub _protocol_family
{
   return PF_INET6;
}

sub _addr_any
{
   return in6addr_any;
}

sub _addr_loopback
{
   return in6addr_loopback;
}

sub _hostname_resolve
{
   my ($this, $host, $nh) = @_;

   $nh->{addr} = undef;

   # See if the service/port was included in the address.

   my $serv = ($host =~ s/^\[(.+)\]:([\w\(\)\/]+)$/$1/) ? $2 : undef;

   if (defined($serv) && (!defined $this->_service_resolve($serv, $nh))) {
      return $this->_error('Failed to resolve the %s service', $this->type());
   }

   # See if the scope zone index was included in the address.

   $nh->{scope_id} = ($host =~ s/%(\d+)$//) ? $1 : 0; # <address>%<index>

   # Resolve the address.

   my @info = getaddrinfo(($_[1] = $host), q{}, PF_INET6);

   if (@info >= 5) {
      if ($host =~ s/(.*)%.*$/$1/) { # <address>%<ifName>
         $_[1] = $1;
      }
      while (@info >= 5) {
         if ($info[0] == PF_INET6) {
            $nh->{flowinfo} = $this->_flowinfo($info[3]);
            $nh->{scope_id} ||= $this->_scope_id($info[3]);
            return $nh->{addr} = $this->_addr($info[3]);
         }
         DEBUG_INFO('family = %d, sin = %s', $info[0], unpack 'H*', $info[3]);
         splice @info, 0, 5;
      }
   } else {
      DEBUG_INFO('getaddrinfo(): %s', $info[0]);
      if ((my @host = split /:/, $host) == 2) { # <hostname>:<service>
          $_[1] = sprintf '[%s]:%s', @host;
          return $this->_hostname_resolve($_[1], $nh);
      }
   }

   # Last attempt to resolve the address.
   if (!defined $nh->{addr}) {
      $nh->{addr} = inet_pton(AF_INET6, $host);
   }

   if (!defined $nh->{addr}) {
      return $this->_error(
         q{Unable to resolve the %s address "%s"}, $this->type(), $host
      );
   }

   return $nh->{addr};
}

sub _name_pack
{
   return pack_sockaddr_in6_all(
      $_[1]->{port}, $_[1]->{flowinfo} || 0,
      $_[1]->{addr}, $_[1]->{scope_id} || 0
   );
}

sub _address
{
   return inet_ntop(AF_INET6, $_[0]->_addr($_[1]));
}

sub _addr
{
   return (unpack_sockaddr_in6_all($_[1]))[2];
}

sub _port
{
   return (unpack_sockaddr_in6_all($_[1]))[0];
}

sub _taddress
{
   my $s = $_[0]->_scope_id($_[1]);
   $s = $s ? sprintf('%%%u', $s) : q{};
   return sprintf '[%s%s]:%u', $_[0]->_address($_[1]), $s, $_[0]->_port($_[1]);
}

sub _taddr
{
   my $s = $_[0]->_scope_id($_[1]);
   $s = $s ? pack('N', $s) : q{};
   return $_[0]->_addr($_[1]) . $s . pack 'n', $_[0]->_port($_[1]);
}

sub _scope_id
{
   return (unpack_sockaddr_in6_all($_[1]))[3];
}

sub _flowinfo
{
   return (unpack_sockaddr_in6_all($_[1]))[1];
}

# ============================================================================
1; # [end Net::SNMP::Transport::IPv6]

