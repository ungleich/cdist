# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::Transport::IPv4::UDP;

# $Id: UDP.pm,v 4.0 2009/09/09 15:05:33 dtown Rel $

# Object that handles the UDP/IPv4 Transport Domain for the SNMP Engine.

# Copyright (c) 2001-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Transport qw( DOMAIN_UDPIPV4 );

use IO::Socket qw( SOCK_DGRAM );

## Version of the Net::SNMP::Transport::IPv4::UDP module

our $VERSION = v4.0.0;

## Handle importing/exporting of symbols

use base qw( Net::SNMP::Transport::IPv4 Net::SNMP::Transport );

sub import
{
   return Net::SNMP::Transport->export_to_level(1, @_);
}

## RFC 3411 - snmpEngineMaxMessageSize::=INTEGER (484..2147483647)

sub MSG_SIZE_DEFAULT_UDP4  { 1472 }  # Ethernet(1500) - IPv4(20) - UDP(8)

# [public methods] -----------------------------------------------------------

sub new
{
   return shift->SUPER::_new(@_);
}

sub send
{
   my $this = shift;

   $this->_error_clear();

   if (length($_[0]) > $this->{_max_msg_size}) {
      return $this->_error(
         'The message size %d exceeds the maxMsgSize %d',
         length($_[0]), $this->{_max_msg_size}
      );
   }

   my $bytes = $this->{_socket}->send($_[0], 0, $this->{_dest_name});

   return defined($bytes) ? $bytes : $this->_perror('Send failure');
}

sub recv
{
   my $this = shift;

   $this->_error_clear();

   my $name = $this->{_socket}->recv($_[0], $this->_shared_max_size(), 0);

   return defined($name) ? $name : $this->_perror('Receive failure');
}

sub domain
{
   return DOMAIN_UDPIPV4; # transportDomainUdpIpv4
}

sub type
{
   return 'UDP/IPv4'; # udpIpv4(1)
}

sub agent_addr
{
   my ($this) = @_;

   $this->_error_clear();

   my $name = $this->{_socket}->sockname() || $this->{_sock_name};

   if ($this->{_socket}->connect($this->{_dest_name})) {
      $name = $this->{_socket}->sockname() || $this->{_sock_name};
      if (!$this->{_socket}->connect((pack('x') x length $name))) {
         $this->_perror('Failed to disconnect');
      }
   }

   return $this->_address($name);
}

# [private methods] ----------------------------------------------------------

sub _protocol_name
{
   return 'udp';
}

sub _protocol_type
{
   return SOCK_DGRAM;
}

sub _msg_size_default
{
   return MSG_SIZE_DEFAULT_UDP4;
}

sub _tdomain
{
   return DOMAIN_UDPIPV4;
}

# ============================================================================
1; # [end Net::SNMP::Transport::IPv4::UDP]

