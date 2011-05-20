# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::Transport::IPv4::TCP;

# $Id: TCP.pm,v 3.0 2009/09/09 15:05:33 dtown Rel $

# Object that handles the TCP/IPv4 Transport Domain for the SNMP Engine.

# Copyright (c) 2004-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Transport qw( 
   MSG_SIZE_MAXIMUM DOMAIN_TCPIPV4 TRUE FALSE DEBUG_INFO
);

use Net::SNMP::Message qw( SEQUENCE );

use IO::Socket qw( SOCK_STREAM );

## Version of the Net::SNMP::Transport::IPv4::TCP module

our $VERSION = v3.0.0;

## Handle importing/exporting of symbols

use base qw( Net::SNMP::Transport::IPv4 Net::SNMP::Transport );

sub import
{
   return Net::SNMP::Transport->export_to_level(1, @_);
}

## RFC 3411 - snmpEngineMaxMessageSize::=INTEGER (484..2147483647)

sub MSG_SIZE_DEFAULT_TCP4  { 1460 }  # Ethernet(1500) - IPv4(20) - TCP(20)

# [public methods] -----------------------------------------------------------

sub new
{
   my ($this, $error) = shift->SUPER::_new(@_);

   if (defined $this) {
      if (!defined $this->_reasm_init()) {
         return wantarray ? (undef, $this->error()) : undef;
      }
   }

   return wantarray ? ($this, $error) : $this;
}

sub accept
{
   my ($this) = @_;

   $this->_error_clear();

   my $socket = $this->{_socket}->accept();

   if (!defined $socket) {
      return $this->_perror('Failed to accept the connection');
   }

   DEBUG_INFO('opened %s socket [%d]', $this->type(), $socket->fileno());

   # Create a new object by copying the current object.

   my $new = bless { %{$this} }, ref $this;

   # Now update the appropriate fields.

   $new->{_socket}        = $socket;
   $new->{_dest_name}     = $socket->peername();
   $new->{_dest_hostname} = $new->sock_address();

   if (!defined $new->_reasm_init()) {
      return $this->_error($new->error());
   }

   # Return the new object.
   return $new;
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

   if (!defined $this->{_socket}->connected()) {
      return $this->_error(
         q{Not connected to the remote host '%s'}, $this->dest_hostname()
      );
   }

   my $bytes = $this->{_socket}->send($_[0], 0);

   return defined($bytes) ? $bytes : $this->_perror('Send failure');
}

sub recv
{
   my $this = shift;

   $this->_error_clear();

   if (!defined $this->{_socket}->connected()) {
      $this->_reasm_reset();
      return $this->_error(
         q{Not connected to the remote host '%s'}, $this->dest_hostname()
      );
   }

   # RCF 3430 Section 2.1 - "It is possible that the underlying TCP 
   # implementation delivers byte sequences that do not align with 
   # SNMP message boundaries.  A receiving SNMP engine MUST therefore 
   # use the length field in the BER-encoded SNMP message to separate 
   # multiple requests sent over a single TCP connection (framing).  
   # An SNMP engine which looses framing (for example due to ASN.1 
   # parse errors) SHOULD close the TCP connection."

   # If the reassembly bufer is empty then there is no partial message
   # waiting for completion.  We must then process the message length
   # to properly determine how much data to receive.

   my $name;

   if ($this->{_reasm_buffer} eq q{}) {

      if (!defined $this->{_reasm_object}) {
         return $this->_error('The reassembly object is not defined');
      }

      # Read enough data to parse the ASN.1 type and length.

      $name = $this->{_socket}->recv($this->{_reasm_buffer}, 6, 0);

      if ((!defined $name) || ($!)) {
         $this->_reasm_reset();
         return $this->_perror('Receive failure');
      } elsif (!length $this->{_reasm_buffer}) {
         $this->_reasm_reset();
         return $this->_error(
            q{The connection was closed by the remote host '%s'},
            $this->dest_hostname()
         );
      }

      $this->{_reasm_object}->append($this->{_reasm_buffer});

      $this->{_reasm_length} = $this->{_reasm_object}->process(SEQUENCE) || 0;

      if ((!$this->{_reasm_length}) ||
           ($this->{_reasm_length} > MSG_SIZE_MAXIMUM))
      {
         $this->_reasm_reset();
         return $this->_error(
            q{Message framing was lost with the remote host '%s'},
            $this->dest_hostname()
         );
      }

      # Add in the bytes parsed to define the expected message length.
      $this->{_reasm_length} += $this->{_reasm_object}->index();

   }

   # Setup a temporary buffer for the message and set the length
   # based upon the contents of the reassembly buffer. 

   my $buf = q{};
   my $buf_len = length $this->{_reasm_buffer};

   # Read the rest of the message.

   $name = $this->{_socket}->recv($buf, ($this->{_reasm_length} - $buf_len), 0);

   if ((!defined $name) || ($!)) {
      $this->_reasm_reset();
      return $this->_perror('Receive failure');
   } elsif (!length $buf) {
      $this->_reasm_reset();
      return $this->_error(
         q{The connection was closed by the remote host '%s'},
         $this->dest_hostname()
      );
   }

   # Now see if we have the complete message.  If it is not complete,
   # success is returned with an empty buffer.  The application must
   # continue to call recv() until the message is reassembled.

   $buf_len += length $buf;
   $this->{_reasm_buffer} .= $buf;

   if ($buf_len < $this->{_reasm_length}) {
      DEBUG_INFO(
         'message is incomplete (expect %u bytes, have %u bytes)',
         $this->{_reasm_length}, $buf_len
      );
      $_[0] = q{};
      return $name || $this->{_socket}->connected();
   }

   # Validate the maxMsgSize.
   if ($buf_len > $this->{_max_msg_size}) {
      $this->_reasm_reset();
      return $this->_error(
         'Incoming message size %d exceeded the maxMsgSize %d',
         $buf_len, $this->{_max_msg_size}
      );
   }

   # The message is complete, copy the buffer to the caller.
   $_[0] = $this->{_reasm_buffer};

   # Clear the reassembly buffer and length.
   $this->_reasm_reset();

   return $name || $this->{_socket}->connected();
}

sub connectionless
{
   return FALSE;
}

sub domain
{
   return DOMAIN_TCPIPV4; # transportDomainTcpIpv4
}

sub type
{
   return 'TCP/IPv4'; # tcpIpv4(5)
}

sub agent_addr
{
   return shift->sock_address();
}

# [private methods] ----------------------------------------------------------

sub _protocol_name
{
   return 'tcp';
}

sub _protocol_type
{
   return SOCK_STREAM;
}

sub _msg_size_default
{
   return MSG_SIZE_DEFAULT_TCP4;
}

sub _reasm_init
{
   my ($this) = @_;

   my $error;

   ($this->{_reasm_object}, $error) = Net::SNMP::Message->new();

   if (!defined $this->{_reasm_object}) {
      return $this->_error(
         'Failed to create the reassembly object: %s', $error
      );
   }

   $this->_reasm_reset();

   return TRUE;
}

sub _reasm_reset
{
   my ($this) = @_;

   if (defined $this->{_reasm_object}) {
      $this->{_reasm_object}->error(undef);
      $this->{_reasm_object}->clear();
   }

   $this->{_reasm_buffer} = q{};
   $this->{_reasm_length} = 0;

   return TRUE;
}

sub _tdomain
{
   return DOMAIN_TCPIPV4; # transportDomainTcpIpv4
}

# ============================================================================
1; # [end Net::SNMP::Transport::IPv4::TCP]

