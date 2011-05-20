# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::Transport::IPv6::TCP;

# $Id: TCP.pm,v 3.0 2009/09/09 15:05:33 dtown Rel $

# Object that handles the TCP/IPv6 Transport Domain for the SNMP Engine.

# Copyright (c) 2004-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Transport::IPv4::TCP qw( DOMAIN_TCPIPV6 DOMAIN_TCPIPV6Z );

## Version of the Net::SNMP::Transport::IPv6::TCP module

our $VERSION = v3.0.0;

## Handle importing/exporting of symbols

use base qw( Net::SNMP::Transport::IPv6 Net::SNMP::Transport::IPv4::TCP );

## RFC 3411 - snmpEngineMaxMessageSize::=INTEGER (484..2147483647)

sub MSG_SIZE_DEFAULT_TCP6  { 1440 }  # Ethernet(1500) - IPv6(40) - TCP(20)

# [public methods] -----------------------------------------------------------

sub domain
{
   return DOMAIN_TCPIPV6; # transportDomainTcpIpv6
}

sub type
{
   return 'TCP/IPv6'; # tcpIpv6(6)
}

# [private methods] ----------------------------------------------------------

sub _msg_size_default
{
   return MSG_SIZE_DEFAULT_TCP6;
}

sub _tdomain
{
   return $_[0]->_scope_id($_[1]) ? DOMAIN_TCPIPV6Z : DOMAIN_TCPIPV6;
}

# ============================================================================
1; # [end Net::SNMP::Transport::TCP6]

