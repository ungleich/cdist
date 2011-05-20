# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::PDU;

# $Id: PDU.pm,v 3.1 2010/09/10 00:01:22 dtown Rel $

# Object used to represent a SNMP PDU. 

# Copyright (c) 2001-2010 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Message qw( 
   :types :versions asn1_itoa ENTERPRISE_SPECIFIC TRUE FALSE DEBUG_INFO 
);

use Net::SNMP::Transport qw( DOMAIN_UDPIPV4 DOMAIN_TCPIPV4 );

## Version of the Net::SNMP::PDU module

our $VERSION = v3.0.1;

## Handle importing/exporting of symbols

use base qw( Net::SNMP::Message );

sub import
{
   return Net::SNMP::Message->export_to_level(1, @_);
}

# [public methods] -----------------------------------------------------------

sub new
{
   my $class = shift;

   # We play some games here to allow us to "convert" a Message into a PDU. 

   my $this = ref($_[0]) ? bless shift(@_), $class : $class->SUPER::new();

   # Override or initialize fields inherited from the base class

   $this->{_error_status}   = 0;
   $this->{_error_index}    = 0;
   $this->{_scoped}         = FALSE;
   $this->{_var_bind_list}  = undef;
   $this->{_var_bind_names} = [];
   $this->{_var_bind_types} = undef;

   my (%argv) = @_;

   # Validate the passed arguments

   for (keys %argv) {

      if (/^-?callback$/i) {
         $this->callback($argv{$_});
      } elsif (/^-?contextengineid/i) {
         $this->context_engine_id($argv{$_});
      } elsif (/^-?contextname/i) {
         $this->context_name($argv{$_});
      } elsif (/^-?debug$/i) {
         $this->debug($argv{$_});
      } elsif (/^-?leadingdot$/i) {
         $this->leading_dot($argv{$_});
      } elsif (/^-?maxmsgsize$/i) {
         $this->max_msg_size($argv{$_});
      } elsif (/^-?requestid$/i) {
         $this->request_id($argv{$_});
      } elsif (/^-?security$/i) {
         $this->security($argv{$_});
      } elsif (/^-?translate$/i) {
         $this->{_translate} = $argv{$_};
      } elsif (/^-?transport$/i) {
         $this->transport($argv{$_});
      } elsif (/^-?version$/i) {
         $this->version($argv{$_});
      } else {
         $this->_error('The argument "%s" is unknown', $_);
      }

      if (defined $this->{_error}) {
         return wantarray ? (undef, $this->{_error}) : undef;
      }

   }

   if (!defined $this->{_transport}) {
      $this->_error('The Transport Domain object is not defined');
      return wantarray ? (undef, $this->{_error}) : undef;
   }

   return wantarray ? ($this, q{}) : $this;
}

sub prepare_get_request
{
   my ($this, $oids) = @_;

   $this->_error_clear();

   return $this->prepare_pdu(GET_REQUEST,
                             $this->_create_oid_null_pairs($oids));
}

sub prepare_get_next_request
{
   my ($this, $oids) = @_;

   $this->_error_clear();

   return $this->prepare_pdu(GET_NEXT_REQUEST,
                             $this->_create_oid_null_pairs($oids));
}

sub prepare_get_response
{
   my ($this, $trios) = @_;

   $this->_error_clear();

   return $this->prepare_pdu(GET_RESPONSE,
                             $this->_create_oid_value_pairs($trios));
}

sub prepare_set_request
{
   my ($this, $trios) = @_;

   $this->_error_clear();

   return $this->prepare_pdu(SET_REQUEST,
                             $this->_create_oid_value_pairs($trios));
}

sub prepare_trap
{
   my ($this, $enterprise, $addr, $generic, $specific, $time, $trios) = @_;

   $this->_error_clear();

   return $this->_error('Insufficient arguments for a Trap-PDU') if (@_ < 6);

   # enterprise

   if (!defined $enterprise) {

      # Use iso(1).org(3).dod(6).internet(1).private(4).enterprises(1) 
      # for the default enterprise.

      $this->{_enterprise} = '1.3.6.1.4.1';

   } elsif ($enterprise !~ m/^\.?\d+(?:\.\d+)* *$/) {
      return $this->_error(
         'The enterprise OBJECT IDENTIFIER "%s" is expected in dotted ' .
         'decimal notation', $enterprise
      );
   } else {
      $this->{_enterprise} = $enterprise;
   }

   # agent-addr

   if (!defined $addr) {

      # See if we can get the agent-addr from the Transport
      # Layer.  If not, we return an error.

      if (defined $this->{_transport}) {
         if (($this->{_transport}->domain() ne DOMAIN_UDPIPV4) &&
             ($this->{_transport}->domain() ne DOMAIN_TCPIPV4))
         {
            $this->{_agent_addr} = '0.0.0.0';
         } else {
            $this->{_agent_addr} = $this->{_transport}->agent_addr();
            if ($this->{_agent_addr} eq '0.0.0.0') {
               delete $this->{_agent_addr};
            }
         }
      }
      if (!exists $this->{_agent_addr}) {
         return $this->_error('Unable to resolve the local agent-addr');
      }

   } elsif ($addr !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
      return $this->_error(
         'The agent-addr "%s" is expected in dotted decimal notation', $addr
      );
   } else {
      $this->{_agent_addr} = $addr;
   }

   # generic-trap

   if (!defined $generic) {

      # Use enterpriseSpecific(6) for the generic-trap type.
      $this->{_generic_trap} = ENTERPRISE_SPECIFIC;

   } elsif ($generic !~ /^\d+$/) {
      return $this->_error(
         'The generic-trap value "%s" is expected in positive numeric format',
         $generic
      );
   } else {
      $this->{_generic_trap} = $generic;
   }

   # specific-trap

   if (!defined $specific) {
      $this->{_specific_trap} = 0;
   } elsif ($specific !~ /^\d+$/) {
      return $this->_error(
         'The specific-trap value "%s" is expected in positive numeric format',
         $specific
      );
   } else {
      $this->{_specific_trap} = $specific;
   }

   # time-stamp

   if (!defined $time) {

      # Use the "uptime" of the script for the time-stamp.
      $this->{_time_stamp} = ((time() - $^T) * 100);

   } elsif ($time !~ /^\d+$/) {
      return $this->_error(
         'The time-stamp value "%s" is expected in positive numeric format',
         $time
      );
   } else {
      $this->{_time_stamp} = $time;
   }

   return $this->prepare_pdu(TRAP, $this->_create_oid_value_pairs($trios));
}

sub prepare_get_bulk_request
{
   my ($this, $repeaters, $repetitions, $oids) = @_;

   $this->_error_clear();

   if (@_ < 3) {
      return $this->_error('Insufficient arguments for a GetBulkRequest-PDU');
   }

   # non-repeaters

   if (!defined $repeaters) {
      $this->{_error_status} = 0;
   } elsif ($repeaters !~ /^\d+$/) {
      return $this->_error(
         'The non-repeaters value "%s" is expected in positive numeric format',
         $repeaters
      );
   } elsif ($repeaters > 2147483647) {
      return $this->_error(
         'The non-repeaters value %s is out of range (0..2147483647)',
         $repeaters
      );
   } else {
      $this->{_error_status} = $repeaters;
   }

   # max-repetitions

   if (!defined $repetitions) {
      $this->{_error_index} = 0;
   } elsif ($repetitions !~ /^\d+$/) {
      return $this->_error(
         'The max-repetitions value "%s" is expected in positive numeric ' .
         'format', $repetitions
      );
   } elsif ($repetitions > 2147483647) {
      return $this->_error(
         'The max-repetitions value %s is out of range (0..2147483647)',
         $repetitions
      );
   } else {
      $this->{_error_index} = $repetitions;
   }

   # Some sanity checks

   if (defined($oids) && (ref($oids) eq 'ARRAY')) {

      if ($this->{_error_status} > @{$oids}) {
         return $this->_error(
            'The non-repeaters value %d is greater than the number of ' .
            'variable-bindings %d', $this->{_error_status}, scalar @{$oids}
         );
      }

      if (($this->{_error_status} == @{$oids}) && ($this->{_error_index})) {
         return $this->_error(
            'The non-repeaters value %d equals the number of variable-' .
            'bindings and max-repetitions is not equal to zero',
             $this->{_error_status}
         );
      }
   }

   return $this->prepare_pdu(GET_BULK_REQUEST,
                             $this->_create_oid_null_pairs($oids));
}

sub prepare_inform_request
{
   my ($this, $trios) = @_;

   $this->_error_clear();

   return $this->prepare_pdu(INFORM_REQUEST,
                             $this->_create_oid_value_pairs($trios));
}

sub prepare_snmpv2_trap
{
   my ($this, $trios) = @_;

   $this->_error_clear();

   return $this->prepare_pdu(SNMPV2_TRAP,
                             $this->_create_oid_value_pairs($trios));
}

sub prepare_report
{
   my ($this, $trios) = @_;

   $this->_error_clear();

   return $this->prepare_pdu(REPORT, $this->_create_oid_value_pairs($trios));
}

sub prepare_pdu
{
   my ($this, $type, $var_bind) = @_;

   # Clear the buffer
   $this->clear();

   # Clear the "scoped" indication
   $this->{_scoped} = FALSE;

   # VarBindList::=SEQUENCE OF VarBind
   if (!defined $this->_prepare_var_bind_list($var_bind || [])) {
      return $this->_error();
   }

   # PDU::=SEQUENCE 
   if (!defined $this->_prepare_pdu_sequence($type)) {
      return $this->_error();
   }

   return TRUE;
}

sub prepare_var_bind_list
{
   my ($this, $var_bind) = @_;

   return $this->_prepare_var_bind_list($var_bind || []);
}

sub prepare_pdu_sequence
{
   goto &_prepare_pdu_sequence;
}

sub prepare_pdu_scope
{
   goto &_prepare_pdu_scope;
}

sub process_pdu
{
   my ($this) = @_;

   # Clear any errors 
   $this->_error_clear();

   # PDU::=SEQUENCE
   return $this->_error() if !defined $this->_process_pdu_sequence();

   # VarBindList::=SEQUENCE OF VarBind
   return $this->_process_var_bind_list();
}

sub process_pdu_scope
{
   goto &_process_pdu_scope;
}

sub process_pdu_sequence
{
   goto &_process_pdu_sequence;
}

sub process_var_bind_list
{
   goto &_process_var_bind_list;
}

sub expect_response
{
   my ($this) = @_;

   if (($this->{_pdu_type} == GET_RESPONSE) ||
       ($this->{_pdu_type} == TRAP)         ||
       ($this->{_pdu_type} == SNMPV2_TRAP)  ||
       ($this->{_pdu_type} == REPORT))
   {
      return FALSE;
   }

   return TRUE;
}

sub pdu_type
{
   return $_[0]->{_pdu_type};
}

sub error_status
{
   my ($this, $status) = @_;

   # error-status::=INTEGER { noError(0) .. inconsistentName(18) } 

   if (@_ == 2) {
      if (!defined $status) {
         return $this->_error('The error-status value is not defined');
      }
      if (($status < 0) ||
          ($status > (($this->version > SNMP_VERSION_1) ? 18 : 5)))
      {
         return $this->_error(
            'The error-status %s is out of range (0..%d)',
            $status, ($this->version > SNMP_VERSION_1) ? 18 : 5
         );
      }
      $this->{_error_status} = $status;
   }

   return $this->{_error_status} || 0; # noError(0)
}

sub error_index
{
   my ($this, $index) = @_;

   # error-index::=INTEGER (0..max-bindings) 

   if (@_ == 2) {
      if (!defined $index) {
         return $this->_error('The error-index value is not defined');
      }
      if (($index < 0) || ($index > 2147483647)) {
         return $this->_error(
            'The error-index value %s is out of range (0.. 2147483647)',
            $index
         );
      }
      $this->{_error_index} = $index;
   }

   return $this->{_error_index} || 0;
}

sub non_repeaters
{
   # non-repeaters::=INTEGER (0..max-bindings)

   return $_[0]->{_error_status} || 0;
}

sub max_repetitions
{
   # max-repetitions::=INTEGER (0..max-bindings)

   return $_[0]->{_error_index} || 0;
}

sub enterprise
{
   return $_[0]->{_enterprise};
}

sub agent_addr
{
   return $_[0]->{_agent_addr};
}

sub generic_trap
{
   return $_[0]->{_generic_trap};
}

sub specific_trap
{
   return $_[0]->{_specific_trap};
}

sub time_stamp
{
   return $_[0]->{_time_stamp};
}

sub var_bind_list
{
   my ($this, $vbl, $types) = @_;

   return if defined $this->{_error};

   if (@_ > 1) {

      # The VarBindList HASH is being updated from an external
      # source.  We need to update the VarBind names ARRAY to
      # correspond to the new keys of the HASH.  If the updated
      # information is valid, we will use lexicographical ordering
      # for the ARRAY entries since we do not have a PDU to use
      # to determine the ordering.  The ASN.1 types HASH is also
      # updated here if a cooresponding HASH is passed.  We double
      # check the mapping by populating the hash with the keys of
      # the VarBindList HASH. 

      if (!defined($vbl) || (ref($vbl) ne 'HASH')) {

         $this->{_var_bind_list}  = undef;
         $this->{_var_bind_names} = [];
         $this->{_var_bind_types} = undef;

      } else {

         $this->{_var_bind_list} = $vbl;

         @{$this->{_var_bind_names}} =
            map  { $_->[0] }
               sort { $a->[1] cmp $b->[1] }
                  map
                  {
                     my $oid = $_;
                     $oid =~ s/^\.//;
                     $oid =~ s/ /\.0/g;
                     [$_, pack 'N*', split m/\./, $oid]
                  } keys %{$vbl};

         if (!defined($types) || (ref($types) ne 'HASH')) {
             $types = {};
         }

         for (keys %{$vbl}) {
            $this->{_var_bind_types}->{$_} =
               exists($types->{$_}) ? $types->{$_} : undef;
         }

      }

   }

   return $this->{_var_bind_list};
}

sub var_bind_names
{
   my ($this) = @_;

   return [] if defined($this->{_error}) || !defined $this->{_var_bind_names};

   return $this->{_var_bind_names};
}

sub var_bind_types
{
   my ($this) = @_;

   return if defined $this->{_error};

   return $this->{_var_bind_types};
}

sub scoped
{
   return $_[0]->{_scoped};
}

# [private methods] ----------------------------------------------------------

sub _prepare_pdu_scope
{
   my ($this) = @_;

   return TRUE if (($this->{_version} < SNMP_VERSION_3) || ($this->{_scoped}));

   # contextName::=OCTET STRING
   if (!defined $this->prepare(OCTET_STRING, $this->context_name())) {
      return $this->_error();
   }

   # contextEngineID::=OCTET STRING
   if (!defined $this->prepare(OCTET_STRING, $this->context_engine_id())) {
      return $this->_error();
   }

   # ScopedPDU::=SEQUENCE
   if (!defined $this->prepare(SEQUENCE)) {
       return $this->_error();
   }

   # Indicate that this PDU has been scoped and return success.
   return $this->{_scoped} = TRUE;
}

sub _prepare_pdu_sequence
{
   my ($this, $type) = @_;

   # Do not do anything if there has already been an error
   return $this->_error() if defined $this->{_error};

   # Make sure the PDU type was passed
   return $this->_error('The SNMP PDU type is not defined') if (@_ != 2);

   # Set the PDU type
   $this->{_pdu_type} = $type;

   # Make sure the request-id has been set
   if (!exists $this->{_request_id}) {
      $this->{_request_id} = int rand 2147483648;
   }

   # We need to encode everything in reverse order so the
   # objects end up in the correct place.

   if ($this->{_pdu_type} != TRAP) { # PDU::=SEQUENCE

      # error-index/max-repetitions::=INTEGER 
      if (!defined $this->prepare(INTEGER, $this->{_error_index})) {
         return $this->_error();
      }

      # error-status/non-repeaters::=INTEGER
      if (!defined $this->prepare(INTEGER, $this->{_error_status})) {
         return $this->_error();
      }

      # request-id::=INTEGER  
      if (!defined $this->prepare(INTEGER, $this->{_request_id})) {
         return $this->_error();
      }

   } else { # Trap-PDU::=IMPLICIT SEQUENCE

      # time-stamp::=TimeTicks 
      if (!defined $this->prepare(TIMETICKS, $this->{_time_stamp})) {
         return $this->_error();
      }

      # specific-trap::=INTEGER 
      if (!defined $this->prepare(INTEGER, $this->{_specific_trap})) {
         return $this->_error();
      }

      # generic-trap::=INTEGER  
      if (!defined $this->prepare(INTEGER, $this->{_generic_trap})) {
         return $this->_error();
      }

      # agent-addr::=NetworkAddress 
      if (!defined $this->prepare(IPADDRESS, $this->{_agent_addr})) {
         return $this->_error();
      }

      # enterprise::=OBJECT IDENTIFIER 
      if (!defined $this->prepare(OBJECT_IDENTIFIER, $this->{_enterprise})) {
         return $this->_error();
      }

   }

   # PDUs::=CHOICE 
   if (!defined $this->prepare($this->{_pdu_type})) {
      return $this->_error();
   }

   return TRUE;
}

sub _prepare_var_bind_list
{
   my ($this, $var_bind) = @_;

   # The passed array is expected to consist of groups of four values
   # consisting of two sets of ASN.1 types and their values.

   if (@{$var_bind} % 4) {
      $this->var_bind_list(undef);
      return $this->_error(
         'The VarBind list size of %d is not a factor of 4', scalar @{$var_bind}
      );
   }

   # Initialize the "var_bind_*" data.

   $this->{_var_bind_list}  = {};
   $this->{_var_bind_names} = [];
   $this->{_var_bind_types} = {};

   # Use the object's buffer to build each VarBind SEQUENCE and then append
   # it to a local buffer.  The local buffer will then be used to create 
   # the VarBindList SEQUENCE.

   my ($buffer, $name_type, $name_value, $syntax_type, $syntax_value) = (q{});

   while (@{$var_bind}) {

      # Pull a quartet of ASN.1 types and values from the passed array.
      ($name_type, $name_value, $syntax_type, $syntax_value) =
         splice @{$var_bind}, 0, 4;

      # Reverse the order of the fields because prepare() does a prepend.

      # value::=ObjectSyntax
      if (!defined $this->prepare($syntax_type, $syntax_value)) {
         $this->var_bind_list(undef);
         return $this->_error();
      }

      # name::=ObjectName
      if ($name_type != OBJECT_IDENTIFIER) {
         $this->var_bind_list(undef);
         return $this->_error(
            'An ObjectName type of 0x%02x was expected, but 0x%02x was found',
            OBJECT_IDENTIFIER, $name_type
         );
      }
      if (!defined $this->prepare($name_type, $name_value)) {
         $this->var_bind_list(undef);
         return $this->_error();
      }

      # VarBind::=SEQUENCE
      if (!defined $this->prepare(SEQUENCE)) {
         $this->var_bind_list(undef);
         return $this->_error();
      }

      # Append the VarBind to the local buffer and clear it.
      $buffer .= $this->clear();

      # Populate the "var_bind_*" data so we can provide consistent
      # output for the methods regardless of whether we are a request 
      # or a response PDU.  Make sure the HASH key is unique if in 
      # case duplicate OBJECT IDENTIFIERs are provided.

      while (exists $this->{_var_bind_list}->{$name_value}) {
         $name_value .= q{ }; # Pad with spaces
      }

      $this->{_var_bind_list}->{$name_value}  = $syntax_value;
      $this->{_var_bind_types}->{$name_value} = $syntax_type;
      push @{$this->{_var_bind_names}}, $name_value;

   }

   # VarBindList::=SEQUENCE OF VarBind
   if (!defined $this->prepare(SEQUENCE, $buffer)) {
      $this->var_bind_list(undef);
      return $this->_error();
   }

   return TRUE;
}

sub _create_oid_null_pairs
{
   my ($this, $oids) = @_;

   return [] if !defined $oids;

   if (ref($oids) ne 'ARRAY') {
      return $this->_error(
         'The OBJECT IDENTIFIER list is expected as an array reference'
      );
   }

   my $pairs = [];

   for (@{$oids}) {
      push @{$pairs}, OBJECT_IDENTIFIER, $_, NULL, q{};
   }

   return $pairs;
}

sub _create_oid_value_pairs
{
   my ($this, $trios) = @_;

   return [] if !defined $trios;

   if (ref($trios) ne 'ARRAY') {
      return $this->_error('The trio list is expected as an array reference');
   }

   if (@{$trios} % 3) {
      return $this->_error(
         'The [OBJECT IDENTIFIER, ASN.1 type, object value] trio is expected'
      );
   }

   my $pairs = [];

   for (my $i = 0; $i < $#{$trios}; $i += 3) {
      push @{$pairs},
         OBJECT_IDENTIFIER, $trios->[$i], $trios->[$i+1], $trios->[$i+2];
   }

   return $pairs;
}

sub _process_pdu_scope
{
   my ($this) = @_;

   return TRUE if ($this->{_version} < SNMP_VERSION_3);

   # ScopedPDU::=SEQUENCE
   return $this->_error() if !defined $this->process(SEQUENCE);

   # contextEngineID::=OCTET STRING
   if (!defined $this->context_engine_id($this->process(OCTET_STRING))) {
      return $this->_error();
   }

   # contextName::=OCTET STRING
   if (!defined $this->context_name($this->process(OCTET_STRING))) {
      return $this->_error();
   }

   # Indicate that this PDU is scoped and return success.
   return $this->{_scoped} = TRUE;
}

sub _process_pdu_sequence
{
   my ($this) = @_;

   # PDUs::=CHOICE
   if (!defined ($this->{_pdu_type} = $this->process())) {
      return $this->_error();
   }

   if ($this->{_pdu_type} != TRAP) { # PDU::=SEQUENCE

      # request-id::=INTEGER
      if (!defined ($this->{_request_id} = $this->process(INTEGER))) {
         return $this->_error();
      }
      # error-status::=INTEGER
      if (!defined ($this->{_error_status} = $this->process(INTEGER))) {
         return $this->_error();
      }
      # error-index::=INTEGER
      if (!defined ($this->{_error_index} = $this->process(INTEGER))) {
         return $this->_error();
      }

      # Indicate that we have an SNMP error, but do not return an error.
      if (($this->{_error_status}) && ($this->{_pdu_type} == GET_RESPONSE)) {
         $this->_error(
            'Received %s error-status at error-index %d',
            _error_status_itoa($this->{_error_status}), $this->{_error_index}
         );
      }

   } else { # Trap-PDU::=IMPLICIT SEQUENCE

      # enterprise::=OBJECT IDENTIFIER
      if (!defined ($this->{_enterprise} = $this->process(OBJECT_IDENTIFIER))) {
         return $this->_error();
      }
      # agent-addr::=NetworkAddress
      if (!defined ($this->{_agent_addr} = $this->process(IPADDRESS))) {
         return $this->_error();
      }
      # generic-trap::=INTEGER
      if (!defined ($this->{_generic_trap} = $this->process(INTEGER))) {
         return $this->_error();
      }
      # specific-trap::=INTEGER
      if (!defined ($this->{_specific_trap} = $this->process(INTEGER))) {
         return $this->_error();
      }
      # time-stamp::=TimeTicks
      if (!defined ($this->{_time_stamp} = $this->process(TIMETICKS))) {
         return $this->_error();
      }

   }

   return TRUE;
}

sub _process_var_bind_list
{
   my ($this) = @_;

   my $value;

   # VarBindList::=SEQUENCE
   if (!defined($value = $this->process(SEQUENCE))) {
      return $this->_error();
   }

   # Using the length of the VarBindList SEQUENCE, 
   # calculate the end index.

   my $end = $this->index() + $value;

   $this->{_var_bind_list}  = {};
   $this->{_var_bind_names} = [];
   $this->{_var_bind_types} = {};

   my ($oid, $type);

   while ($this->index() < $end) {

      # VarBind::=SEQUENCE
      if (!defined $this->process(SEQUENCE)) {
         return $this->_error();
      }
      # name::=ObjectName
      if (!defined ($oid = $this->process(OBJECT_IDENTIFIER))) {
         return $this->_error();
      }
      # value::=ObjectSyntax
      if (!defined ($value = $this->process(undef, $type))) {
         return $this->_error();
      }

      # Create a hash consisting of the OBJECT IDENTIFIER as a
      # key and the ObjectSyntax as the value.  If there is a
      # duplicate OBJECT IDENTIFIER in the VarBindList, we pad
      # that OBJECT IDENTIFIER with spaces to make a unique
      # key in the hash.

      while (exists $this->{_var_bind_list}->{$oid}) {
         $oid .= q{ }; # Pad with spaces
      }

      DEBUG_INFO('{ %s => %s: %s }', $oid, asn1_itoa($type), $value);
      $this->{_var_bind_list}->{$oid}  = $value;
      $this->{_var_bind_types}->{$oid} = $type;

      # Create an array with the ObjectName OBJECT IDENTIFIERs
      # so that the order in which the VarBinds where encoded
      # in the PDU can be retrieved later.

      push @{$this->{_var_bind_names}}, $oid;

   }

   # Return an error based on the contents of the VarBindList
   # if we received a Report-PDU.

   if ($this->{_pdu_type} == REPORT) {
      return $this->_report_pdu_error();
   }

   # Return the var_bind_list hash
   return $this->{_var_bind_list};
}

{
   my @error_status = qw(
      noError
      tooBig
      noSuchName
      badValue
      readOnly
      genError
      noAccess
      wrongType
      wrongLength
      wrongEncoding
      wrongValue
      noCreation
      inconsistentValue
      resourceUnavailable
      commitFailed
      undoFailed
      authorizationError
      notWritable
      inconsistentName
   );

   sub _error_status_itoa
   {
      return '??' if (@_ != 1);

      if (($_[0] > $#error_status) || ($_[0] < 0)) {
         return sprintf '??(%d)', $_[0];
      }

      return sprintf '%s(%d)', $error_status[$_[0]], $_[0];
   }
}

{
   my %report_oids = (
      '1.3.6.1.6.3.11.2.1.1' => 'snmpUnknownSecurityModels',
      '1.3.6.1.6.3.11.2.1.2' => 'snmpInvalidMsgs',
      '1.3.6.1.6.3.11.2.1.3' => 'snmpUnknownPDUHandlers',
      '1.3.6.1.6.3.12.1.4'   => 'snmpUnavailableContexts',
      '1.3.6.1.6.3.12.1.5'   => 'snmpUnknownContexts',
      '1.3.6.1.6.3.15.1.1.1' => 'usmStatsUnsupportedSecLevels',
      '1.3.6.1.6.3.15.1.1.2' => 'usmStatsNotInTimeWindows',
      '1.3.6.1.6.3.15.1.1.3' => 'usmStatsUnknownUserNames',
      '1.3.6.1.6.3.15.1.1.4' => 'usmStatsUnknownEngineIDs',
      '1.3.6.1.6.3.15.1.1.5' => 'usmStatsWrongDigests',
      '1.3.6.1.6.3.15.1.1.6' => 'usmStatsDecryptionErrors',
   );

   sub _report_pdu_error
   {
      my ($this) = @_;

      # Remove the leading dot (if present) and replace the dotted notation
      # of the OBJECT IDENTIFIER with the text ObjectName based upon an
      # expected list of report OBJECT IDENTIFIERs.

      my %var_bind_list;

      for my $oid (@{$this->{_var_bind_names}}) {
         my $text = $oid;
         $text =~ s/^\.//;
         for (keys %report_oids) {
            if ($text =~ s/\Q$_/$report_oids{$_}/) {
               last;
            }
         }
         $var_bind_list{$text} = $this->{_var_bind_list}->{$oid};
      }

      my $count = keys %var_bind_list;

      if ($count == 1) {
         # Return the OBJECT IDENTIFIER and value.
         my $text = (keys %var_bind_list)[0];
         return $this->_error(
            'Received %s Report-PDU with value %s', $text, $var_bind_list{$text}
         );
      } elsif ($count > 1) {
         # Return a list of OBJECT IDENTIFIERs.
         return $this->_error(
            'Received Report-PDU [%s]', join ', ', keys %var_bind_list
         );
      } else {
         return $this->_error('Received empty Report-PDU');
      }

   }
}

# ============================================================================
1; # [end Net::SNMP::PDU]
