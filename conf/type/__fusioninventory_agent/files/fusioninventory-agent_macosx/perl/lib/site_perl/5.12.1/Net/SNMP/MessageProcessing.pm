# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::MessageProcessing;

# $Id: MessageProcessing.pm,v 3.1 2010/09/10 00:01:22 dtown Rel $

# Object that implements the Message Processing module.

# Copyright (c) 2001-2010 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::PDU qw( 
   :types :msgFlags :securityLevels asn1_itoa SNMP_VERSION_3 TRUE FALSE 
);

srand( time() ^ ($$ + ($$ <<15)) );

## Version of the Net::SNMP::MessageProcessing module

our $VERSION = v3.0.1;

## Package variables

our $INSTANCE;          # Reference to the Singleton object

our $DEBUG = FALSE;     # Debug flag

## Object array indexes

sub _ERROR    { 0 }     # Error message
sub _HANDLES  { 1 }     # Cached request messages

BEGIN
{
   # See if there is a better pseudorandom number generator (PRNG) available.
   if (eval 'require Math::Random::MT::Auto') {
      Math::Random::MT::Auto->import('rand');
   }
}

# [public methods] -----------------------------------------------------------

sub instance
{
   return $INSTANCE ||= Net::SNMP::MessageProcessing->_new();
}

sub prepare_outgoing_msg
{
   my ($this, $pdu) = @_;

   # Clear any previous errors
   $this->_error_clear();

   if ((@_ != 2) || (!ref $pdu)) {
      return $this->_error('The PDU object is missing or invalid');
   }

   # We must have a Security Model in order to prepare the message. 
   if (!defined $pdu->security()) {
      return $this->_error('The Security Model object is not defined');
   }

   # Create a new Message
   my ($msg, $error) = Net::SNMP::Message->new(
      -callback   => $pdu->callback(),
      -leadingdot => $pdu->leading_dot(),
      -requestid  => $pdu->request_id(),
      -security   => $pdu->security(),
      -translate  => $pdu->translate(),
      -transport  => $pdu->transport(),
      -version    => $pdu->version()
   );
   return $this->_error($error) if !defined $msg;

   if ($pdu->version() == SNMP_VERSION_3) {

      # ScopedPDU::=SEQUENCE

      if (!defined $pdu->prepare_pdu_scope()) {
         return $this->_error($pdu->error());
      }

      # We need to copy the contextEngineID and contextName to the 
      # request message so that they are available for comparison 
      # with the response message.

      $msg->context_engine_id($pdu->context_engine_id());
      $msg->context_name($pdu->context_name());

      # Set a new msgID for each message unless the PDU type is a
      # GetResponse-PDU or a Report-PDU.

      if (($pdu->pdu_type() != GET_RESPONSE) && ($pdu->pdu_type() != REPORT)) {
         $pdu->msg_id($this->msg_handle_alloc());
      }

      # msgGlobalData::=SEQUENCE

      if (!defined $this->_prepare_global_data($pdu, $msg)) {
         return $this->_error();
      }

   }

   # Pass off to the Security Model
   if (!defined $pdu->security()->generate_request_msg($pdu, $msg)) {
      return $this->_error($pdu->security()->error());
   }

   # If a response to the message is expected, add the message to the
   # cache using the msgId (request-id) has the lookup "handle".

   if ($pdu->expect_response()) {
      $this->[_HANDLES]->{$msg->msg_id()} = $msg;
   }

   # Return the new message.
   return $msg;
}

sub prepare_data_elements
{
   my ($this, $msg) = @_;

   # Clear any previous errors
   $this->_error_clear();

   if ((@_ != 2) || (!ref $msg)) {
      return $this->_error('The Message object is missing or invalid');
   }

   # message::=SEQUENCE
   return $this->_error($msg->error()) if !defined $msg->process(SEQUENCE);

   # version::=INTEGER
   if (!defined $msg->version($msg->process(INTEGER))) {
      return $this->_error($msg->error());
   }

   # Find the request message in the cache.  We are assuming this 
   # message is a response to an outstanding request.

   my $request;

   if ($msg->version() == SNMP_VERSION_3) {

      # msgGlobalData::=SEQUENCE
      if (!defined $this->_process_global_data($msg)) {
         return $this->_error();
      }

      $request = $this->msg_handle_delete($msg->msg_id());

   } else {

      # community::=OCTET STRING
      if (!defined $msg->security_name($msg->process(OCTET_STRING))) {
         return $this->_error($msg->error());
      }

      # Cast the Message to a PDU
      if (!defined($msg = Net::SNMP::PDU->new($msg))) {
         return $this->_error('Failed to allocate a new PDU object');
      }

      # PDU::=SEQUENCE
      if (!defined $msg->process_pdu_sequence()) {
         return $this->_error($msg->error());
      }

      if ($msg->pdu_type() != GET_RESPONSE) {
          return $this->_error(
             'A %s was expected, but %s was found',
             asn1_itoa(GET_RESPONSE), asn1_itoa($msg->pdu_type())
          );
      }

      $request = $this->msg_handle_delete($msg->request_id());

   }

   # Was a matching request found?
   if (!defined $request) {
      return $this->_error('No matching request message was found');
   }

   # Update the received message with the relevant request data. 
   $msg->callback($request->callback());
   $msg->timeout_id($request->timeout_id());
   $msg->transport($request->transport());

   # Now that we have found the matching request for this response
   # we return a FALSE error instead of undefined so that the error
   # gets propagated back to the user.

   # Compare the Security Models
   if ($msg->msg_security_model() != $request->msg_security_model()) {
      $this->_error(
         'The msgSecurityModel %d was expected, but %d was found',
         $request->msg_security_model(), $msg->msg_security_model()
      );
      return FALSE;
   }
  
   $msg->security($request->security());

   # Pass off to the Security Model
   if (!defined $request->security()->process_incoming_msg($msg)) {
      $this->_error($request->security()->error());
      return FALSE;
   }

   if ($msg->version() == SNMP_VERSION_3) {

      # Adjust our maxMsgSize if necessary
      if ($msg->msg_max_size() < $request->max_msg_size()) {
         DEBUG_INFO('new maxMsgSize = %d', $msg->msg_max_size());
         if (!defined $request->max_msg_size($msg->msg_max_size())) {
            $this->_error($request->error());
            return FALSE;
         }
      }

      # Cast the Message to a PDU
      if (!defined($msg = Net::SNMP::PDU->new($msg))) {
         $this->_error('Failed to allocate new PDU object');
         return FALSE;
      }

      # ScopedPDU::=SEQUENCE
      if (!defined $msg->process_pdu_scope()) {
         $this->_error($msg->error());
         return FALSE;
      }

      # PDU::=SEQUENCE
      if (!defined $msg->process_pdu_sequence()) {
         $this->_error($msg->error());
         return FALSE;
      }

      if ($msg->pdu_type() != REPORT) {

         if ($msg->pdu_type() != GET_RESPONSE) {
            $this->_error(
               'A %s was expected, but %s was found',
               asn1_itoa(GET_RESPONSE), asn1_itoa($msg->pdu_type())
            );
            return FALSE;
         }

         # Compare the contextEngineID
         if ($msg->context_engine_id() ne $request->context_engine_id()) {
            $this->_error(
               'The contextEngineID "%s" was expected, but "%s" was found',
               unpack('H*', $request->context_engine_id()),
               unpack('H*', $msg->context_engine_id()),
            );
            return FALSE;
         }

         # Compare the contextName
         if ($msg->context_name() ne $request->context_name()) {
            $this->_error(
               'The contextName "%s" was expected, but "%s" was found',
               $request->context_name(), $msg->context_name()
            );
            return FALSE;
         }

         # Check the request-id
         if ($msg->request_id() != $request->request_id()) {
            $this->_error(
               'The request-id %d was expected, but %d was found',
               $request->request_id(), $msg->request_id()
            );
            return FALSE;
         }
      }

   }

   # Now update the message with format parameters.
   $msg->leading_dot($request->leading_dot());
   $msg->translate($request->translate());

   # VarBindList::=SEQUENCE OF VarBind

   if (!defined $msg->process_var_bind_list()) {
      $this->_error($msg->error());
      return FALSE;
   }

   # Return the PDU
   return $msg;
}

sub msg_handle_alloc
{
   my ($this) = @_;

   # Limit message handles by RFC 3412 - msgID::=INTEGER (0..2147483647)

   my $handle = int rand(2147483648);

   while (exists $this->[_HANDLES]->{$handle} &&
          keys %{$this->[_HANDLES]->{$handle}} < 2147483648)
   {
      $handle = int rand(2147483648);
   }

   return $handle;
}

sub msg_handle_delete
{
   my ($this, $handle) = @_;

   # Clear any previous errors
   $this->_error_clear();

   return $this->_error('No msgHandle was specified') if (@_ < 2);

   if (!exists $this->[_HANDLES]->{$handle}) {
      return $this->_error('The msgHandle %d was not found', $handle);
   }

   return delete $this->[_HANDLES]->{$handle};
}

sub error
{
   return $_[0]->[_ERROR] || q{};
}

sub debug
{
   return (@_ == 2) ? $DEBUG = ($_[1]) ? TRUE : FALSE : $DEBUG;
}

# [private methods] ----------------------------------------------------------

sub _new
{
   my ($class) = @_;

   # The constructor is private since we only want one MessageProcessing
   # object.  We also reserve message handle (request-id/msgID) 0 so that 
   # it is not used for valid messages.

   return bless [ undef, { 0, undef } ], $class;
}

sub _prepare_global_data
{
   my ($this, $pdu, $msg) = @_;

   # msgSecurityModel::=INTEGER

   if (!defined
         $msg->prepare(
            INTEGER, $msg->msg_security_model($pdu->msg_security_model())
         )
      )
   {
      return $this->_error($msg->error());
   }

   # msgFlags::=OCTET STRING

   my $security_level = $pdu->security_level();
   my $msg_flags      = MSG_FLAGS_NOAUTHNOPRIV | MSG_FLAGS_REPORTABLE;

   if ($security_level > SECURITY_LEVEL_NOAUTHNOPRIV) {
      $msg_flags |= MSG_FLAGS_AUTH;
      if ($security_level > SECURITY_LEVEL_AUTHNOPRIV) {
         $msg_flags |= MSG_FLAGS_PRIV;
      }
   }

   if (!$pdu->expect_response()) {
      $msg_flags &= ~MSG_FLAGS_REPORTABLE;
   }

   if (!defined $msg->prepare(OCTET_STRING, pack 'C', $msg_flags)) {
      $this->_error($msg->error());
   }

   $msg->msg_flags($msg_flags);

   # msgMaxSize::=INTEGER

   if (!defined
         $msg->prepare(INTEGER, $msg->msg_max_size($pdu->max_msg_size()))
      )
   {
      return $this->_error($msg->error());
   }

   # msgID::=INTEGER
   if (!defined $msg->prepare(INTEGER, $msg->msg_id($pdu->msg_id()))) {
      return $this->_error($msg->error());
   }

   # msgGlobalData::=SEQUENCE
   if (!defined $msg->prepare(SEQUENCE)) {
      return $this->_error($msg->error());
   }

   return TRUE;
}

sub _process_global_data
{
   my ($this, $msg) = @_;

   # msgGlobalData::=SEQUENCE
   return $this->_error($msg->error()) if !defined $msg->process(SEQUENCE);

   # msgID::=INTEGER
   if (!defined $msg->msg_id($msg->process(INTEGER))) {
      return $this->_error($msg->error());
   }

   # msgMaxSize::=INTEGER
   if (!defined $msg->msg_max_size($msg->process(INTEGER))) {
      return $this->_error($msg->error());
   }

   # msgFlags::=OCTET STRING

   my $msg_flags = $msg->process(OCTET_STRING);

   if (!defined $msg_flags) {
      return $this->_error($msg->error());
   }

   if (CORE::length($msg_flags) != 1) {
      return $this->_error(
         'The msgFlags length of %d is invalid', CORE::length($msg_flags)
      );
   }

   $msg->msg_flags($msg_flags = unpack 'C', $msg_flags);

   # Validate the msgFlags and derive the securityLevel. 

   my $security_level = SECURITY_LEVEL_NOAUTHNOPRIV;

   if ($msg_flags & MSG_FLAGS_AUTH) {
      $security_level = SECURITY_LEVEL_AUTHNOPRIV;
      if ($msg_flags & MSG_FLAGS_PRIV) {
         $security_level = SECURITY_LEVEL_AUTHPRIV;
      }
   } elsif ($msg_flags & MSG_FLAGS_PRIV) {

      # RFC 3412 - Section 7.2 1d: "If the authFlag is not set
      # and privFlag is set... ...the message is discarded..."

      return $this->_error('The msgFlags value 0x%02x is invalid', $msg_flags);
   }

   # RFC 3412 - Section 7.2 1e: "Any other bits... ...are ignored."
   if ($msg_flags & ~MSG_FLAGS_MASK) {
      DEBUG_INFO('questionable msgFlags value 0x%02x', $msg_flags);
   }

   $msg->security_level($security_level);

   # msgSecurityModel::=INTEGER
   if (!defined $msg->msg_security_model($msg->process(INTEGER))) {
      return $this->_error($msg->error());
   }

   return TRUE;
}

sub _error
{
   my $this = shift;

   if (!defined $this->[_ERROR]) {
      $this->[_ERROR] = (@_ > 1) ? sprintf(shift(@_), @_) : $_[0];
      if ($this->debug()) {
         printf "error: [%d] %s(): %s\n",
                (caller 0)[2], (caller 1)[3], $this->[_ERROR];
      }
   }

   return;
}

sub _error_clear
{
   return $_[0]->[_ERROR] = undef;
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
1; # [end Net::SNMP::MessageProcessing]
