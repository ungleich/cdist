# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::Transport::IPv4;

# $Id: IPv4.pm,v 1.1 2009/09/09 15:08:31 dtown Rel $

# Base object for the IPv4 Transport Domains.

# Copyright (c) 2008-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Transport;

use IO::Socket qw(
   INADDR_ANY INADDR_LOOPBACK inet_aton PF_INET sockaddr_in inet_ntoa
);

## Version of the Net::SNMP::Transport::IPv4 module

our $VERSION = v1.0.0;

# [private methods] ----------------------------------------------------------

sub _socket_create
{
   my ($this) = @_;

   return IO::Socket->new()->socket($this->_protocol_family(),
                                    $this->_protocol_type(),
                                    $this->_protocol());
}

sub _protocol_family
{
   return PF_INET;
}

sub _addr_any
{
   return INADDR_ANY;
}

sub _addr_loopback
{
   return INADDR_LOOPBACK;
}

sub _hostname_resolve
{
   my ($this, $host, $nh) = @_;

   $nh->{addr} = undef;

   # See if the the service/port was included in the address.

   my $serv = ($host =~ s/:([\w\(\)\/]+)$//) ? $1 : undef;

   if (defined($serv) && (!defined $this->_service_resolve($serv, $nh))) {
      return $this->_error('Failed to resolve the %s service', $this->type());
   }

   # Resolve the address.

   if (!defined ($nh->{addr} = inet_aton($_[1] = $host))) {
      return $this->_error(
         q{Unable to resolve the %s address "%s"}, $this->type(), $host
      );
   }

   return $nh->{addr};
}

sub _name_pack
{
   return sockaddr_in($_[1]->{port}, $_[1]->{addr});
}

sub _address
{
   return inet_ntoa($_[0]->_addr($_[1]));
}

sub _addr
{
   return (sockaddr_in($_[1]))[1];
}

sub _port
{
   return (sockaddr_in($_[1]))[0];
}

sub _taddress
{
   return sprintf '%s:%d', $_[0]->_address($_[1]), $_[0]->_port($_[1]);
}

sub _taddr
{
   return $_[0]->_addr($_[1]) . pack 'n', $_[0]->_port($_[1]);
}

# ============================================================================
1; # [end Net::SNMP::Transport::IPv4]

