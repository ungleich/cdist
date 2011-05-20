# -*- mode: perl -*- 
# ============================================================================

package Net::SNMP::Security::Community;

# $Id: Community.pm,v 2.0 2009/09/09 15:05:33 dtown Rel $

# Object that implements the SNMPv1/v2c Community-based Security Model.

# Copyright (c) 2001-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Security qw( 
   SECURITY_MODEL_SNMPV1 SECURITY_MODEL_SNMPV2C DEBUG_INFO
);

use Net::SNMP::Message qw(
   OCTET_STRING SEQUENCE INTEGER SNMP_VERSION_1 SNMP_VERSION_2C TRUE
);

## Version of the Net::SNMP::Security::Community module

our $VERSION = v2.0.0;

## Handle importing/exporting of symbols

use base qw( Net::SNMP::Security );

sub import
{
   return Net::SNMP::Security->export_to_level(1, @_);
}

## RFC 3584 - snmpCommunityName::=OCTET STRING 

sub COMMUNITY_DEFAULT  { 'public' }

# [public methods] -----------------------------------------------------------

sub new
{
   my ($class, %argv) = @_;

   # Create a new data structure for the object
   my $this = bless {
      '_error'     => undef,              # Error message
      '_version'   => SNMP_VERSION_1,     # SNMP version
      '_community' => COMMUNITY_DEFAULT,  # Community name
   }, $class;

   # Now validate the passed arguments

   for (keys %argv) {
      if (/^-?community$/i) {
         $this->_community($argv{$_});
      } elsif (/^-?debug$/i) {
         $this->debug($argv{$_});
      } elsif (/^-?version$/i) {
         $this->_version($argv{$_});
      } else {
         $this->_error('The argument "%s" is unknown', $_);
      }

      if (defined $this->{_error}) {
         return wantarray ? (undef, $this->{_error}) : undef;
      }
   }

   # Return the object and an empty error message (in list context)
   return wantarray ? ($this, q{}) : $this;
}

sub generate_request_msg
{
   my ($this, $pdu, $msg) = @_;

   # Clear any previous errors
   $this->_error_clear();

   if (@_ < 3) {
      return $this->_error('The required PDU and/or Message object is missing');
   }

   if ($pdu->version() != $this->{_version}) {
      return $this->_error(
         'The SNMP version %d was expected, but %d was found',
         $this->{_version}, $pdu->version()
      );
   }

   # Append the PDU
   if (!defined $msg->append($pdu->copy())) {
      return $this->_error($msg->error());
   }

   # community::=OCTET STRING
   if (!defined $msg->prepare(OCTET_STRING, $this->{_community})) {
      return $this->_error($msg->error());
   }

   # version::=INTEGER
   if (!defined $msg->prepare(INTEGER, $this->{_version})) {
      return $this->_error($msg->error());
   }

   # message::=SEQUENCE
   if (!defined $msg->prepare(SEQUENCE)) {
      return $this->_error($msg->error());
   }

   # Return the message
   return $msg;
}

sub process_incoming_msg
{
   my ($this, $msg) = @_;

   # Clear any previous errors
   $this->_error_clear();

   return $this->_error('The required Message object is missing') if (@_ < 2);

   if ($msg->security_name() ne $this->{_community}) {
      return $this->_error(
         'The community name "%s" was expected, but "%s" was found',
         $this->{_community}, $msg->security_name()
      );
   }

   return TRUE;
}

sub community
{
   return $_[0]->{_community};
}

sub security_model
{
   my ($this) = @_;

   # RFC 3411 - SnmpSecurityModel::=TEXTUAL-CONVENTION 

   if ($this->{_version} == SNMP_VERSION_2C) {
      return SECURITY_MODEL_SNMPV2C;
   }

   return SECURITY_MODEL_SNMPV1;
}

sub security_name
{
   return $_[0]->{_community};
}

# [private methods] ----------------------------------------------------------

sub _community
{
   my ($this, $community) = @_;

   return $this->_error('The community is not defined') if !defined $community;

   $this->{_community} = $community;

   return TRUE;
}

sub _version
{
   my ($this, $version) = @_;

   if (($version != SNMP_VERSION_1) && ($version != SNMP_VERSION_2C)) {
      return $this->_error('The SNMP version %s is not supported', $version);
   }

   $this->{_version} = $version;

   return TRUE;
}

# ============================================================================
1; # [end Net::SNMP::Security::Community]

