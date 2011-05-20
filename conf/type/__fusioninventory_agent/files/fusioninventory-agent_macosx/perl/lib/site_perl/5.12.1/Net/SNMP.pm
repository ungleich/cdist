# -*- mode: perl -*-
# ============================================================================

package Net::SNMP;

# $Id: SNMP.pm,v 6.1 2010/09/10 00:01:22 dtown Rel $

# Copyright (c) 1998-2010 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# Release 4.0.0 of the Net::SNMP module was dedicated to those who died in 
# the September 11, 2001 terrorist attacks on the United States of America.

# ============================================================================

=head1 NAME

Net::SNMP - Object oriented interface to SNMP 

=head1 SYNOPSIS

The Net::SNMP module implements an object oriented interface to the Simple 
Network Management Protocol.  Perl applications can use the module to retrieve 
or update information on a remote host using the SNMP protocol.  The module 
supports SNMP version-1, SNMP version-2c (Community-Based SNMPv2), and SNMP 
version-3. The Net::SNMP module assumes that the user has a basic understanding
of the Simple Network Management Protocol and related network management 
concepts.

=head1 DESCRIPTION

The Net::SNMP module abstracts the intricate details of the Simple Network
Management Protocol by providing a high level programming interface to the
protocol.  Each Net::SNMP object provides a one-to-one mapping between a Perl
object and a remote SNMP agent or manager.  Once an object is created, it can
be used to perform the basic protocol exchange actions defined by SNMP.

A Net::SNMP object can be created such that it has either "blocking" or
"non-blocking" properties.  By default, the methods used to send SNMP messages
do not return until the protocol exchange has completed successfully or a
timeout period has expired. This behavior gives the object a "blocking"
property because the flow of the code is stopped until the method returns.

The optional named argument B<-nonblocking> can be passed to the object
constructor with a true value to give the object "non-blocking" behavior.
A method invoked by a non-blocking object queues the SNMP message and returns
immediately, allowing the flow of the code to continue. The queued SNMP 
messages are not sent until an event loop is entered by calling the 
C<snmp_dispatcher()> method.  When the SNMP messages are sent, any response to 
the messages invokes the subroutine defined by the user when the message was 
originally queued. The event loop exits when all messages have been removed 
from the queue by either receiving a response, or by exceeding the number of 
retries at the Transport Layer.

=head2 Blocking Objects

The default behavior of the methods associated with a Net::SNMP object is to
block the code flow until the method completes.  For methods that initiate a
SNMP protocol exchange requiring a response, a hash reference containing the
results of the query is returned. The undefined value is returned by all
methods when a failure has occurred. The C<error()> method can be used to
determine the cause of the failure.

The hash reference returned by a SNMP protocol exchange points to a hash
constructed from the VarBindList contained in the SNMP response message.  The
hash is created using the ObjectName and the ObjectSyntax pairs in the
VarBindList.  The keys of the hash consist of the OBJECT IDENTIFIERs in dotted
notation corresponding to each ObjectName in the VarBindList.  The value of
each hash entry is set equal to the value of the corresponding ObjectSyntax.
This hash reference can also be retrieved using the C<var_bind_list()> method.

=head2 Non-blocking Objects

When a Net::SNMP object is created having non-blocking behavior, the invocation
of a method associated with the object returns immediately, allowing the flow 
of the code to continue.  When a method is invoked that would initiate a SNMP
protocol exchange requiring a response, either a true value (i.e. 0x1) is
returned immediately or the undefined value is returned if there was a failure.
The C<error()> method can be used to determine the cause of the failure.

The contents of the VarBindList contained in the SNMP response message can be
retrieved by calling the C<var_bind_list()> method using the object reference
passed as the first argument to the callback.  The value returned by the 
C<var_bind_list()> method is a hash reference created using the ObjectName and
the ObjectSyntax pairs in the VarBindList.  The keys of the hash consist of 
the OBJECT IDENTIFIERs in dotted notation corresponding to each ObjectName 
in the VarBindList.  The value of each hash entry is set equal to the value of
the corresponding ObjectSyntax. The undefined value is returned if there has 
been a failure and the C<error()> method may be used to determine the reason.

=cut

# ============================================================================

use strict;

## Validate the version of Perl

BEGIN
{
   die 'Perl version 5.6.0 or greater is required' if ($] < 5.006);
}

## Version of the Net::SNMP module

our $VERSION = 'v6.0.1';
    $VERSION = eval $VERSION;

## Load our modules

use Net::SNMP::Dispatcher();
use Net::SNMP::PDU qw( :ALL !DEBUG_INFO );
use Net::SNMP::Security();
use Net::SNMP::Transport qw( :ports );

## Handle importing/exporting of symbols

use base qw( Exporter );

our @EXPORT = qw(
   INTEGER INTEGER32 OCTET_STRING OBJECT_IDENTIFIER IPADDRESS COUNTER
   COUNTER32 GAUGE GAUGE32 UNSIGNED32 TIMETICKS OPAQUE COUNTER64 NOSUCHOBJECT
   NOSUCHINSTANCE ENDOFMIBVIEW snmp_dispatcher 
);

our @EXPORT_OK = qw( oid_context_match );

our %EXPORT_TAGS = (
   asn1        => [
      qw( INTEGER INTEGER32 OCTET_STRING NULL OBJECT_IDENTIFIER SEQUENCE
          IPADDRESS COUNTER COUNTER32 GAUGE GAUGE32 UNSIGNED32 TIMETICKS
          OPAQUE COUNTER64 NOSUCHOBJECT NOSUCHINSTANCE ENDOFMIBVIEW
          GET_REQUEST GET_NEXT_REQUEST GET_RESPONSE SET_REQUEST TRAP
          GET_BULK_REQUEST INFORM_REQUEST SNMPV2_TRAP REPORT )
   ],
   debug       => [
      qw( DEBUG_ALL DEBUG_NONE DEBUG_MESSAGE DEBUG_TRANSPORT DEBUG_DISPATCHER
          DEBUG_PROCESSING DEBUG_SECURITY snmp_debug )
   ],
   generictrap => [
      qw( COLD_START WARM_START LINK_DOWN LINK_UP AUTHENTICATION_FAILURE
          EGP_NEIGHBOR_LOSS ENTERPRISE_SPECIFIC )
   ],
   snmp        => [
      qw( SNMP_VERSION_1 SNMP_VERSION_2C SNMP_VERSION_3 SNMP_PORT 
          SNMP_TRAP_PORT snmp_debug snmp_dispatcher snmp_dispatch_once
          snmp_type_ntop oid_base_match oid_lex_cmp oid_lex_sort ticks_to_time )
   ],
   translate   => [
      qw( TRANSLATE_NONE TRANSLATE_OCTET_STRING TRANSLATE_NULL
          TRANSLATE_TIMETICKS TRANSLATE_OPAQUE TRANSLATE_NOSUCHOBJECT
          TRANSLATE_NOSUCHINSTANCE TRANSLATE_ENDOFMIBVIEW TRANSLATE_UNSIGNED
          TRANSLATE_ALL )
   ],
);

Exporter::export_ok_tags( qw( asn1 debug generictrap snmp translate ) );

$EXPORT_TAGS{ALL} = [ @EXPORT_OK ];

## Debugging bit masks

sub DEBUG_ALL         { 0xff }  # All
sub DEBUG_NONE        { 0x00 }  # None
sub DEBUG_MESSAGE     { 0x02 }  # Message/PDU encoding/decoding
sub DEBUG_TRANSPORT   { 0x04 }  # Transport Layer
sub DEBUG_DISPATCHER  { 0x08 }  # Dispatcher
sub DEBUG_PROCESSING  { 0x10 }  # Message Processing
sub DEBUG_SECURITY    { 0x20 }  # Security

## Package variables

our $DEBUG = DEBUG_NONE;        # Debug mask 

our $DISPATCHER;                # Dispatcher instance

our $BLOCKING = 0;              # Count of blocking objects

our $NONBLOCKING = 0;           # Count of non-blocking objects

BEGIN
{
   # Validate the creation of the Dispatcher object.

   if (!defined ($DISPATCHER = Net::SNMP::Dispatcher->instance())) {
      die 'FATAL: Failed to create Dispatcher instance';
   }

   # In older versions of Perl, the UNIVERSAL::VERSION() method does not
   # handle version defined as v-strings gracefully.  We provide our
   # own handling of versions to account for this.

   if ($] < 5.009) {
      *VERSION = \&require_version;
   }
}

# [public methods] -----------------------------------------------------------

=head1 METHODS

When named arguments are expected by the methods, two different styles are 
supported.  All examples in this documentation use the dashed-option style:

       $object->method(-argument => $value);

However, the IO:: style is also allowed:

       $object->method(Argument => $value);

=over 

=item Non-blocking Objects Arguments

When a Net::SNMP object has been created with a "non-blocking" property, most
methods that generate a SNMP message take additional arguments to support this
property.

=over

=item Callback

Most methods associated with a non-blocking object have an optional named
argument called B<-callback>.  The B<-callback> argument expects a reference
to a subroutine or to an array whose first element must be a reference to a
subroutine.  The subroutine defined by the B<-callback> option is executed when
a response to a SNMP message is received, an error condition has occurred, or
the number of retries for the message has been exceeded.

When the B<-callback> argument only contains a subroutine reference, the
subroutine is evaluated passing a reference to the original Net::SNMP object 
as the only parameter.  If the B<-callback> argument was defined as an array
reference, all elements in the array are passed to subroutine after the
reference to the Net::SNMP object.  The first element, which is required to be
a reference to a subroutine, is removed before the remaining arguments are 
passed to that subroutine.

Once one method is invoked with the B<-callback> argument, this argument stays
with the object and is used by any further calls to methods using the
B<-callback> option if the argument is absent.  The undefined value may be
passed to the B<-callback> argument to delete the callback.

B<NOTE:> The subroutine being passed with the B<-callback> named argument
should not cause blocking itself.  This will cause all the actions in the event
loop to be stopped, defeating the non-blocking property of the Net::SNMP
module.

=item Delay

An optional argument B<-delay> can also be passed to non-blocking objects.  The
B<-delay> argument instructs the object to wait the number of seconds passed
to the argument before executing the SNMP protocol exchange.  The delay period 
starts when the event loop is entered.  The B<-delay> parameter is applied to 
all methods associated with the object once it is specified.  The delay value 
must be set back to 0 seconds to disable the delay parameter. 

=back

=item SNMPv3 Arguments

A SNMP context is a collection of management information accessible by a SNMP 
entity.  An item of management information may exist in more than one context 
and a SNMP entity potentially has access to many contexts.  The combination of 
a contextEngineID and a contextName unambiguously identifies a context within 
an administrative domain.  In a SNMPv3 message, the contextEngineID and 
contextName are included as part of the scopedPDU.  All methods that generate 
a SNMP message optionally take a B<-contextengineid> and B<-contextname> 
argument to configure these fields.

=over

=item Context Engine ID

The B<-contextengineid> argument expects a hexadecimal string representing
the desired contextEngineID.  The string must be 10 to 64 characters (5 to 
32 octets) long and can be prefixed with an optional "0x".  Once the 
B<-contextengineid> is specified it stays with the object until it is changed 
again or reset to default by passing in the undefined value.  By default, the 
contextEngineID is set to match the authoritativeEngineID of the authoritative
SNMP engine.

=item Context Name

The contextName is passed as a string which must be 0 to 32 octets in length 
using the B<-contextname> argument.  The contextName stays with the object 
until it is changed.  The contextName defaults to an empty string which 
represents the "default" context.

=back

=back

=cut

{
   my @trans_argv = qw(
      hostname (?:de?st|peer)?(?:addr|port) (?:src|sock|local)(?:addr|port)
      maxmsgsize mtu retries timeout domain listen
   );

   sub new
   {
      my ($class, %argv) = @_;

      # Create a new data structure for the object
      my $this = bless {
           '_callback'          =>  undef,           # Callback
           '_context_engine_id' =>  undef,           # contextEngineID
           '_context_name'      =>  undef,           # contextName
           '_delay'             =>  0,               # Message delay
           '_hostname'          =>  q{},             # Hostname
           '_discovery_queue'   =>  [],              # Pending message queue
           '_error'             =>  undef,           # Error message
           '_nonblocking'       =>  FALSE,           # [Non-]blocking flag
           '_pdu'               =>  undef,           # Message/PDU object
           '_security'          =>  undef,           # Security Model object
           '_translate'         =>  TRANSLATE_ALL,   # Translation mask 
           '_transport'         =>  undef,           # Transport Domain object
           '_transport_argv'    =>  [],              # Transport object argv
           '_version'           =>  SNMP_VERSION_1,  # SNMP version
      }, $class;

      # Parse the passed arguments 

      for (keys %argv) {

         if (/^-?debug$/i) {
            $this->debug(delete $argv{$_});
         } elsif (/^-?nonblocking$/i) {
            $this->{_nonblocking} = (delete $argv{$_}) ? TRUE : FALSE;
         } elsif (/^-?translate$/i) {
            $this->translate(delete $argv{$_});
         } elsif (/^-?version$/i) {
            $this->_version($argv{$_});
         } else {
            # Pull out arguments associated with the Transport Domain. 
            my $key = $_;
            for (@trans_argv) {
               if ($key =~ /^-?$_$/i) {
                  push @{$this->{_transport_argv}}, $key, delete $argv{$key};
                  last;
               }
            }
         }

         if (defined $this->{_error}) {
            $this->_object_type_validate();
            return wantarray ? (undef, $this->{_error}) : undef;
         }

      }

      # We must validate the object type to prevent blocking and
      # non-blocking object from existing at the same time.

      if (!defined $this->_object_type_validate()) {
         return wantarray ? (undef, $this->{_error}) : undef;
      }

      # Create a Security Model object

      ($this->{_security}, $this->{_error}) = Net::SNMP::Security->new(%argv);
      if (!defined $this->{_security}) {
         return wantarray ? (undef, $this->{_error}) : undef;
      }
      $this->_error_clear();

      # Return the object and empty error message (in list context)
      return wantarray ? ($this, q{}) : $this;
   }

}

sub open
{
   my ($this) = @_;

   # Clear any previous errors
   $this->_error_clear();

   # Create a Transport Domain object
   ($this->{_transport}, $this->{_error}) = Net::SNMP::Transport->new(
      @{$this->{_transport_argv}}
   );

   if (!defined $this->{_transport}) {
      return $this->_error();
   }
   $this->_error_clear();

   # Keep a copy of the hostname 
   $this->{_hostname} = $this->{_transport}->dest_hostname();

   # Perform SNMPv3 authoritative engine discovery.
   if ($this->version() == SNMP_VERSION_3) {
      $this->_perform_discovery();
   }

   return defined($this->{_error}) ? $this->_error() : $this->{_transport};
}

=head2 session() - create a new Net::SNMP object

   ($session, $error) = Net::SNMP->session(
                           [-hostname      => $hostname,]
                           [-port          => $port,]
                           [-localaddr     => $localaddr,]
                           [-localport     => $localport,]
                           [-nonblocking   => $boolean,]
                           [-version       => $version,]
                           [-domain        => $domain,]
                           [-timeout       => $seconds,]
                           [-retries       => $count,]
                           [-maxmsgsize    => $octets,]
                           [-translate     => $translate,]
                           [-debug         => $bitmask,]
                           [-community     => $community,]   # v1/v2c
                           [-username      => $username,]    # v3
                           [-authkey       => $authkey,]     # v3
                           [-authpassword  => $authpasswd,]  # v3
                           [-authprotocol  => $authproto,]   # v3
                           [-privkey       => $privkey,]     # v3
                           [-privpassword  => $privpasswd,]  # v3
                           [-privprotocol  => $privproto,]   # v3
                        );

This is the constructor for Net::SNMP objects.  In scalar context, a
reference to a new Net::SNMP object is returned if the creation of the object
is successful.  In list context, a reference to a new Net::SNMP object and an 
empty error message string is returned.  If a failure occurs, the object 
reference is returned as the undefined value.  The error string may be used 
to determine the cause of the error.

Most of the named arguments passed to the constructor define basic attributes
for the object and are not modifiable after the object has been created.  The
B<-timeout>, B<-retries>, B<-maxmsgsize>, B<-translate>, and B<-debug>
arguments are modifiable using an accessor method.  See their corresponding 
method definitions for a complete description of their usage, default values, 
and valid ranges.

=over

=item Transport Domain Arguments

The Net::SNMP module uses UDP/IPv4 as the default Transport Domain to exchange
SNMP messages between the local and remote devices.  The module also supports
UDP/IPv6, TCP/IPv4, and TCP/IPv6 as alternative Transport Domains.  The 
B<-domain> argument can be used to change the Transport Domain by setting the 
value to one of the following strings: 'udp6', 'udp/ipv6'; 'tcp', 'tcp4', 
'tcp/ipv4'; 'tcp6', or 'tcp/ipv6'.  The B<-domain> argument also accepts
the strings 'udp', 'udp4', or 'udp/ipv4' which correspond to the default
Transport Domain of UDP/IPv4.

The transport address of the destination SNMP device can be specified using
the B<-hostname> argument.  This argument is optional and defaults to
"localhost".  The destination port number can be specified as part of the
transport address or by using the B<-port> argument.  Either a numeric port
number or a textual service name can be specified.  A numeric port number in
parentheses can optionally follow the service name.  This port number will
be used if the service name cannot be resolved.  If the destination port number
is not specified, the well-known SNMP port number 161 is used.

By default the source transport address and port number are assigned 
dynamically by the local device on which the Net::SNMP module is being used.
This dynamic assignment can be overridden by using the B<-localaddr> and
B<-localport> arguments.  These arguments accept the same values as the
B<-hostname> and B<-port> arguments respectively.  The resolved address must
correspond to a valid address of an interface on the local device.

When using an IPv4 Transport Domain, the transport address can be specified
as either an IP network hostname or an IPv4 address in standard dotted notation.
The port information can be optionally appended to the hostname or address
delimited by a colon.  The accepted IPv4 transport address formats are 
C<address>, C<address:port>, C<hostname>, and C<hostname:port>.

When using an IPv6 Transport Domain, the transport address can be specified
as an IP hostname (which will be looked up as a DNS quad-A record) or an IPv6
address in presentation format.  The port information can optionally be 
included following a colon after the hostname or address.  When including this
information after an IPv6 address, the address must be enclosed in square 
brackets.  The scope zone index (described in RFC 4007) can be specified after
the address as a decimal value delimited by a percent sign.  The accepted
transport address formats for IPv6 are C<address>, C<address%zone>,
C<[address]:port>, C<[address%zone]:port>, C<hostname>, and C<hostname:port>.

=item Security Model Arguments

The B<-version> argument controls which other arguments are expected or 
required by the C<session()> constructor.  The Net::SNMP module supports 
SNMPv1, SNMPv2c, and SNMPv3.  The module defaults to SNMPv1 if no B<-version>
argument is specified.  The B<-version> argument expects either a digit (i.e. 
'1', '2', or '3') or a string specifying the version (i.e. 'snmpv1', 
'snmpv2c', or 'snmpv3') to define the SNMP version. 

The Security Model used by the Net::SNMP object is based on the SNMP version
associated with the object.  If the SNMP version is SNMPv1 or SNMPv2c a
Community-based Security Model will be used, while the User-based Security
Model (USM) will be used if the version is SNMPv3.  

=over

=item Community-based Security Model Argument 

If the Security Model is Community-based, the only argument available is the
B<-community> argument.  This argument expects a string that is to be used as
the SNMP community name.  By default the community name is set to 'public' 
if the argument is not present.

=item User-based Security Model Arguments 

The User-based Security Model (USM) used by SNMPv3 requires that a securityName
be specified using the B<-username> argument.  The creation of a Net::SNMP
object with the version set to SNMPv3 will fail if the B<-username> argument
is not present.  The B<-username> argument expects a string 1 to 32 octets
in length.

Different levels of security are allowed by the User-based Security Model which
address authentication and privacy concerns.  A SNMPv3 Net::SNMP object will 
derive the security level (securityLevel) based on which of the following 
arguments are specified.

By default a securityLevel of 'noAuthNoPriv' is assumed.  If the B<-authkey> 
or B<-authpassword> arguments are specified, the securityLevel becomes 
'authNoPriv'.  The B<-authpassword> argument expects a string which is at 
least 1 octet in length.  Optionally, the B<-authkey> argument can be used so 
that a plain text password does not have to be specified in a script.  The 
B<-authkey> argument expects a hexadecimal string produced by localizing the 
password with the authoritativeEngineID for the specific destination device.  
The C<snmpkey> utility included with the distribution can be used to create 
the hexadecimal string (see L<snmpkey>). 

Two different hash algorithms are defined by SNMPv3 which can be used by the 
Security Model for authentication.  These algorithms are HMAC-MD5-96 "MD5" 
(RFC 1321) and HMAC-SHA-96 "SHA-1" (NIST FIPS PUB 180-1).   The default 
algorithm used by the module is HMAC-MD5-96.  This behavior can be changed by 
using the B<-authprotocol> argument.  This argument expects either the string 
'md5' or 'sha' to be passed to modify the hash algorithm.

By specifying the arguments B<-privkey> or B<-privpassword> the securityLevel
associated with the object becomes 'authPriv'.  According to SNMPv3, privacy 
requires the use of authentication.  Therefore, if either of these two 
arguments are present and the B<-authkey> or B<-authpassword> arguments are 
missing, the creation of the object fails.  The B<-privkey> and 
B<-privpassword> arguments expect the same input as the B<-authkey> and 
B<-authpassword> arguments respectively.

The User-based Security Model described in RFC 3414 defines a single encryption
protocol to be used for privacy.  This protocol, CBC-DES "DES" (NIST FIPS PUB 
46-1), is used by default or if the string 'des' is passed to the 
B<-privprotocol> argument.  The module also supports RFC 3826 which describes
the use of CFB128-AES-128 "AES" (NIST FIPS PUB 197) in the USM.  The AES 
encryption protocol can be selected by passing 'aes' or 'aes128' to the 
B<-privprotocol> argument.  By working with the Extended Security Options
Consortium L<http://www.snmp.com/protocol/eso.shtml>, the module also supports
CBC-3DES-EDE "Triple-DES" (NIST FIPS 46-3) in the User-based Security Model.
This is defined in the draft
L<http://www.snmp.com/eso/draft-reeder-snmpv3-usm-3desede-00.txt>.  The
Triple-DES encryption protocol can be selected using the B<-privprotocol> 
argument with the string '3des' or '3desede'. 

=back

=back

=cut

sub session
{
   my $class = shift;

   my ($this, $error) = $class->new(@_);

   if (defined $this) {
      if (!defined $this->open()) {
         return wantarray ? (undef, $this->error()) : undef;
      }
   }

   return wantarray ? ($this, $error) : $this;
}

sub manager
{
   goto &session;
}

=head2 close() - clear the Transport Domain associated with the object

   $session->close(); 

This method clears the Transport Domain and any errors associated with the 
object.  Once closed, the Net::SNMP object can no longer be used to send or 
receive SNMP messages.

=cut

sub close
{
   my ($this) = @_;

   $this->_error_clear();
   $this->{_pdu}       = undef;
   $this->{_transport} = undef;
   return;
}

=head2 snmp_dispatcher() - enter the non-blocking object event loop

   $session->snmp_dispatcher();

This method enters the event loop associated with non-blocking Net::SNMP
objects.  The method exits when all queued SNMP messages have received a
response or have timed out at the Transport Layer. This method is also 
exported as the stand alone function C<snmp_dispatcher()> by default 
(see L<"EXPORTS">).

=cut

sub snmp_dispatcher
{
   return $DISPATCHER->loop();
}

sub snmp_event_loop
{
   require Carp;
   Carp::croak('snmp_event_loop() is obsolete, use snmp_dispatcher() instead');
   goto &snmp_dispatcher;
}

sub snmp_dispatch_once
{
   return $DISPATCHER->one_event();
}

=head2 get_request() - send a SNMP get-request to the remote agent

   $result = $session->get_request(
                          [-callback        => sub {},]     # non-blocking
                          [-delay           => $seconds,]   # non-blocking 
                          [-contextengineid => $engine_id,] # v3 
                          [-contextname     => $name,]      # v3
                          -varbindlist      => \@oids,
                       );

This method performs a SNMP get-request query to gather data from the remote
agent on the host associated with the Net::SNMP object.  The message is built
using the list of OBJECT IDENTIFIERs in dotted notation passed to the method
as an array reference using the B<-varbindlist> argument.  Each OBJECT 
IDENTIFIER is placed into a single SNMP GetRequest-PDU in the same order that 
it held in the original list.

A reference to a hash is returned in blocking mode which contains the contents
of the VarBindList.  In non-blocking mode, a true value is returned when no 
error has occurred.  In either mode, the undefined value is returned when an
error has occurred.  The C<error()> method may be used to determine the cause
of the failure.

=cut

sub get_request
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   if (!defined $this->_prepare_argv([qw( -callback
                                          -delay
                                          -contextengineid
                                          -contextname 
                                          -varbindlist     )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   if (!defined $this->{_pdu}->prepare_get_request(@argv)) {
      return $this->_error($this->{_pdu}->error());
   }

   return $this->_send_pdu();
}

=head2 get_next_request() - send a SNMP get-next-request to the remote agent

   $result = $session->get_next_request(
                          [-callback        => sub {},]     # non-blocking
                          [-delay           => $seconds,]   # non-blocking 
                          [-contextengineid => $engine_id,] # v3 
                          [-contextname     => $name,]      # v3
                          -varbindlist      => \@oids,
                       );

This method performs a SNMP get-next-request query to gather data from the 
remote agent on the host associated with the Net::SNMP object.  The message 
is built using the list of OBJECT IDENTIFIERs in dotted notation passed to the 
method as an array reference using the B<-varbindlist> argument.  Each OBJECT 
IDENTIFER is placed into a single SNMP GetNextRequest-PDU in the same order 
that it held in the original list.

A reference to a hash is returned in blocking mode which contains the contents
of the VarBindList.  In non-blocking mode, a true value is returned when no 
error has occurred.  In either mode, the undefined value is returned when an
error has occurred.  The C<error()> method may be used to determine the cause
of the failure.

=cut

sub get_next_request
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   if (!defined $this->_prepare_argv([qw( -callback
                                          -delay
                                          -contextengineid
                                          -contextname 
                                          -varbindlist     )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   if (!defined $this->{_pdu}->prepare_get_next_request(@argv)) {
      return $this->_error($this->{_pdu}->error());
   }

   return $this->_send_pdu();
}

=head2 set_request() - send a SNMP set-request to the remote agent

   $result = $session->set_request(
                          [-callback        => sub {},]     # non-blocking
                          [-delay           => $seconds,]   # non-blocking 
                          [-contextengineid => $engine_id,] # v3 
                          [-contextname     => $name,]      # v3
                          -varbindlist      => \@oid_value,
                       );

This method is used to modify data on the remote agent that is associated
with the Net::SNMP object using a SNMP set-request.  The message is built 
using a list of values consisting of groups of an OBJECT IDENTIFIER, an object 
type, and the actual value to be set.  This list is passed to the method as 
an array reference using the B<-varbindlist> argument.  The OBJECT IDENTIFIERs 
in each trio are to be in dotted notation.  The object type is an octet 
corresponding to the ASN.1 type of value that is to be set.  Each of the 
supported ASN.1 types have been defined and are exported by the package by 
default (see L<"EXPORTS">). 

A reference to a hash is returned in blocking mode which contains the contents
of the VarBindList.  In non-blocking mode, a true value is returned when no
error has occurred.  In either mode, the undefined value is returned when an
error has occurred.  The C<error()> method may be used to determine the cause
of the failure.

=cut

sub set_request
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   if (!defined $this->_prepare_argv([qw( -callback
                                          -delay
                                          -contextengineid
                                          -contextname 
                                          -varbindlist     )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   if (!defined $this->{_pdu}->prepare_set_request(@argv)) {
      return $this->_error($this->{_pdu}->error());
   }

   return $this->_send_pdu();
}

=head2 trap() - send a SNMP trap to the remote manager

   $result = $session->trap(
                          [-delay           => $seconds,]   # non-blocking 
                          [-enterprise      => $oid,]
                          [-agentaddr       => $ipaddress,]
                          [-generictrap     => $generic,]
                          [-specifictrap    => $specific,]
                          [-timestamp       => $timeticks,]
                          -varbindlist      => \@oid_value,
                       );

This method sends a SNMP trap to the remote manager associated with the
Net::SNMP object.  All arguments are optional and will be given the following 
defaults in the absence of a corresponding named argument: 

=over 

=item *

The default value for the trap B<-enterprise> is "1.3.6.1.4.1", which 
corresponds to "iso.org.dod.internet.private.enterprises".  The enterprise 
value is expected to be an OBJECT IDENTIFER in dotted notation. 

=item *

When the Transport Domain is UDP/IPv4 or TCP/IPv4, the default value for the
trap B<-agentaddr> is the IP address associated with the interface on which 
the trap will be transmitted.  For other Transport Domains the B<-agentaddr>
is defaulted to "0.0.0.0".  When specified, the agent-addr is expected to be
an IpAddress in dotted notation.

=item *

The default value for the B<-generictrap> type is 6 which corresponds to 
"enterpriseSpecific".  The generic-trap types are defined and can be exported
upon request (see L<"EXPORTS">).

=item *

The default value for the B<-specifictrap> type is 0.  No pre-defined values
are available for specific-trap types.

=item *

The default value for the trap B<-timestamp> is the "uptime" of the script.  
The "uptime" of the script is the number of hundredths of seconds that have 
elapsed since the script began running.  The time-stamp is expected to be a 
TimeTicks number in hundredths of seconds.

=item *

The default value for the trap B<-varbindlist> is an empty array reference.
The variable-bindings are expected to be in an array format consisting of 
groups of an OBJECT IDENTIFIER, an object type, and the actual value of the 
object.  This is identical to the list expected by the C<set_request()> method.
The OBJECT IDENTIFIERs in each trio are to be in dotted notation.  The object 
type is an octet corresponding to the ASN.1 type for the value. Each of the 
supported types have been defined and are exported by default (see 
L<"EXPORTS">).

=back

A true value is returned when the method is successful. The undefined value 
is returned when a failure has occurred.  The C<error()> method can be used to
determine the cause of the failure. Since there are no acknowledgements for 
Trap-PDUs, there is no way to determine if the remote host actually received
the trap.  

B<NOTE:> When the object is in non-blocking mode, the trap is not sent until 
the event loop is entered and no callback is ever executed.

B<NOTE:> This method can only be used when the version of the object is set to
SNMPv1.

=cut

sub trap
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   if (!defined $this->_prepare_argv([qw( -delay
                                          -enterprise
                                          -agentaddr
                                          -generictrap
                                          -specifictrap
                                          -timestamp
                                          -varbindlist  )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   if (!defined $this->{_pdu}->prepare_trap(@argv)) {
      return $this->_error($this->{_pdu}->error());
   }

   $this->_send_pdu();

   return defined($this->{_error}) ? $this->_error() : TRUE;
}

=head2 get_bulk_request() - send a SNMP get-bulk-request to the remote agent

   $result = $session->get_bulk_request(
                          [-callback        => sub {},]     # non-blocking
                          [-delay           => $seconds,]   # non-blocking 
                          [-contextengineid => $engine_id,] # v3 
                          [-contextname     => $name,]      # v3
                          [-nonrepeaters    => $non_reps,]
                          [-maxrepetitions  => $max_reps,]
                          -varbindlist      => \@oids,
                       );

This method performs a SNMP get-bulk-request query to gather data from the
remote agent on the host associated with the Net::SNMP object.  All arguments 
are optional except B<-varbindlist> and will be given the following defaults 
in the absence of a corresponding named argument: 

=over 

=item *

The default value for the get-bulk-request B<-nonrepeaters> is 0.  The 
non-repeaters value specifies the number of variables in the 
variable-bindings list for which a single successor is to be returned.

=item *

The default value for the get-bulk-request B<-maxrepetitions> is 0. The
max-repetitions value specifies the number of successors to be returned for
the remaining variables in the variable-bindings list.

=item *

The B<-varbindlist> argument expects an array reference consisting of a list of
OBJECT IDENTIFIERs in dotted notation.  Each OBJECT IDENTIFER is placed into a 
single SNMP GetBulkRequest-PDU in the same order that it held in the original 
list.

=back

A reference to a hash is returned in blocking mode which contains the contents
of the VarBindList.  In non-blocking mode, a true value is returned when no
error has occurred.  In either mode, the undefined value is returned when an
error has occurred.  The C<error()> method may be used to determine the cause
of the failure.

B<NOTE:> This method can only be used when the version of the object is set to
SNMPv2c or SNMPv3.

=cut

sub get_bulk_request
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   if (!defined $this->_prepare_argv([qw( -callback
                                          -delay
                                          -contextengineid
                                          -contextname
                                          -nonrepeaters 
                                          -maxrepetitions 
                                          -varbindlist     )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   if (!defined $this->{_pdu}->prepare_get_bulk_request(@argv)) {
      return $this->_error($this->{_pdu}->error());
   }

   return $this->_send_pdu();
}

=head2 inform_request() - send a SNMP inform-request to the remote manager

   $result = $session->inform_request(
                          [-callback        => sub {},]     # non-blocking
                          [-delay           => $seconds,]   # non-blocking 
                          [-contextengineid => $engine_id,] # v3 
                          [-contextname     => $name,]      # v3
                          -varbindlist      => \@oid_value,
                       );

This method is used to provide management information to the remote manager
associated with the Net::SNMP object using an inform-request.  The message is 
built using a list of values consisting of groups of an OBJECT IDENTIFIER, 
an object type, and the actual value to be identified.  This list is passed 
to the method as an array reference using the B<-varbindlist> argument.  The 
OBJECT IDENTIFIERs in each trio are to be in dotted notation.  The object type 
is an octet corresponding to the ASN.1 type of value that is to be identified.  
Each of the supported ASN.1 types have been defined and are exported by the 
package by default (see L<"EXPORTS">). 

The first two variable-bindings fields in the inform-request are specified
by SNMPv2 and should be:

=over

=item *

sysUpTime.0 - ('1.3.6.1.2.1.1.3.0', TIMETICKS, $timeticks) 

=item *

snmpTrapOID.0 - ('1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $oid)

=back

A reference to a hash is returned in blocking mode which contains the contents
of the VarBindList.  In non-blocking mode, a true value is returned when no
error has occurred.  In either mode, the undefined value is returned when an
error has occurred.  The C<error()> method may be used to determine the cause
of the failure.

B<NOTE:> This method can only be used when the version of the object is set to
SNMPv2c or SNMPv3.

=cut

sub inform_request
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   if (!defined $this->_prepare_argv([qw( -callback
                                          -delay
                                          -contextengineid
                                          -contextname 
                                          -varbindlist     )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   if (!defined $this->{_pdu}->prepare_inform_request(@argv)) {
      return $this->_error($this->{_pdu}->error());
   }

   return $this->_send_pdu();
}

=head2 snmpv2_trap() - send a SNMP snmpV2-trap to the remote manager

   $result = $session->snmpv2_trap(
                          [-delay           => $seconds,]   # non-blocking 
                          -varbindlist      => \@oid_value,
                       );

This method sends a snmpV2-trap to the remote manager associated with the 
Net::SNMP object.  The message is built using a list of values consisting of 
groups of an OBJECT IDENTIFIER, an object type, and the actual value to be 
identified.  This list is passed to the method as an array reference using the 
B<-varbindlist> argument.  The OBJECT IDENTIFIERs in each trio are to be in 
dotted notation.  The object type is an octet corresponding to the ASN.1 type 
of value that is to be identified.  Each of the supported ASN.1 types have 
been defined and are exported by the package by default (see L<"EXPORTS">). 

The first two variable-bindings fields in the snmpV2-trap are specified by
SNMPv2 and should be:

=over

=item *

sysUpTime.0 - ('1.3.6.1.2.1.1.3.0', TIMETICKS, $timeticks)

=item *

snmpTrapOID.0 - ('1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $oid)

=back

A true value is returned when the method is successful. The undefined value 
is returned when a failure has occurred.  The C<error()> method can be used 
to determine the cause of the failure. Since there are no acknowledgements for
SNMPv2-Trap-PDUs, there is no way to determine if the remote host actually 
received the snmpV2-trap.  

B<NOTE:> When the object is in non-blocking mode, the snmpV2-trap is not sent 
until the event loop is entered and no callback is ever executed.

B<NOTE:> This method can only be used when the version of the object is set to
SNMPv2c.  SNMPv2-Trap-PDUs are supported by SNMPv3, but require the sender of
the message to be an authoritative SNMP engine which is not currently supported
by the Net::SNMP module.

=cut

sub snmpv2_trap
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   if (!defined $this->_prepare_argv([qw( -delay
                                          -contextengineid
                                          -contextname
                                          -varbindlist )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   if (!defined $this->{_pdu}->prepare_snmpv2_trap(@argv)) {
      return $this->_error($this->{_pdu}->error());
   }

   $this->_send_pdu();

   return defined($this->{_error}) ? $this->_error() : TRUE;
}

=head2 get_table() - retrieve a table from the remote agent

   $result = $session->get_table(
                          [-callback        => sub {},]     # non-blocking
                          [-delay           => $seconds,]   # non-blocking 
                          [-contextengineid => $engine_id,] # v3 
                          [-contextname     => $name,]      # v3
                          -baseoid          => $oid,
                          [-maxrepetitions  => $max_reps,]  # v2c/v3
                       );

This method performs repeated SNMP get-next-request or get-bulk-request 
(when using SNMPv2c or SNMPv3) queries to gather data from the remote agent 
on the host associated with the Net::SNMP object.  The first message sent 
is built using the OBJECT IDENTIFIER in dotted notation passed to the method 
by the B<-baseoid> argument.   Repeated SNMP requests are issued until the 
OBJECT IDENTIFIER in the response is no longer a child of the base OBJECT 
IDENTIFIER.

The B<-maxrepetitions> argument can be used to specify the max-repetitions
value that is passed to the get-bulk-requests when using SNMPv2c or SNMPv3.  
If this argument is not present, a value is calculated based on the maximum 
message size for the Net::SNMP object.  If the value is set to 1 or less, 
get-next-requests will be used for the queries instead of get-bulk-requests.

A reference to a hash is returned in blocking mode which contains the contents
of the VarBindList.  In non-blocking mode, a true value is returned when no
error has occurred.  In either mode, the undefined value is returned when an
error has occurred.  The C<error()> method may be used to determine the cause
of the failure.

B<WARNING:> Results from this method can become very large if the base
OBJECT IDENTIFIER is close to the root of the SNMP MIB tree.

=cut

sub get_table
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   # Validate the passed arguments.  For backwards compatiblity
   # see if the first argument is an OBJECT IDENTIFIER and then
   # act accordingly.

   if ((@_) && ($_[0] =~ m/^\.?\d+(?:\.\d+)* *$/)) {
      unshift @_, '-baseoid'; # XXX: Side effects?
   }

   if (!defined $this->_prepare_argv([qw( -callback
                                          -delay
                                          -contextengineid
                                          -contextname 
                                          -baseoid         
                                          -maxrepetitions  )], \@_, \@argv))
   {
      return $this->_error();
   }

   if ($argv[0] !~ m/^\.?\d+(?:\.\d+)* *$/) {
      return $this->_error(
         'The base OBJECT IDENTIFIER "%s" is expected in dotted decimal ' .
         'notation', $argv[0]
      );
   }

   # Create a new PDU.
   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   # Create table of values that need passed along with the
   # callbacks.  This just prevents a big argument list.

   my $argv = {
      base_oid   => $argv[0],
      callback   => $this->{_pdu}->callback(),
      max_reps   => 5, # Also used as a limit for loop detection.
      repeat_cnt => 0,
      table      => undef,
      types      => undef,
      use_bulk   => FALSE
   };

   # Override the callback now that we have stored it.
   $this->{_pdu}->callback(
      sub
      {
         $this->{_pdu} = $_[0];
         $this->_error_clear();
         if ($this->{_pdu}->error()) {
            $this->_error($this->{_pdu}->error());
         }
         $this->_get_table_cb($argv);
         return;
      }
   );

   # Determine if we are going to use get-next-requests or get-bulk-requests
   # based on the SNMP version and the -maxrepetitions argument.

   if ($this->version() == SNMP_VERSION_1) {
      if (defined $argv[1]) {
         return $this->_error(
            'The max-repetitions argument is not applicable when using SNMPv1'
         );
      }
   } else {
      if (!defined $argv[1]) {
         $argv->{use_bulk} = TRUE;
         $argv->{max_reps} = $this->_msg_size_max_reps();
      } elsif ($argv[1] > 1) {
         $argv->{use_bulk} = TRUE;
         $argv->{max_reps} = $argv[1];
      }
   }

   # Create either a get-next-request or get-bulk-request PDU.

   if ($argv->{use_bulk}) {
      if (!defined $this->{_pdu}->prepare_get_bulk_request(0,
                                                           $argv->{max_reps},
                                                           [$argv[0]]))
      {
         return $this->_error($this->{_pdu}->error());
      }
   } else {
      if (!defined $this->{_pdu}->prepare_get_next_request([$argv[0]])) {
         return $this->_error($this->{_pdu}->error());
      }
   }

   return $this->_send_pdu();
}

=head2 get_entries() - retrieve table entries from the remote agent

   $result = $session->get_entries(
                          [-callback        => sub {},]     # non-blocking
                          [-delay           => $seconds,]   # non-blocking
                          [-contextengineid => $engine_id,] # v3
                          [-contextname     => $name,]      # v3
                          -columns          => \@columns,
                          [-startindex      => $start,]
                          [-endindex        => $end,]
                          [-maxrepetitions  => $max_reps,]  # v2c/v3
                       );

This method performs repeated SNMP get-next-request or get-bulk-request
(when using SNMPv2c or SNMPv3) queries to gather data from the remote agent
on the host associated with the Net::SNMP object.  Each message specifically
requests data for each OBJECT IDENTIFIER specified in the B<-columns> array.
The OBJECT IDENTIFIERs must correspond to column entries for a conceptual row 
in a table.  They may however be columns in different tables as long as each
table is indexed the same way.  The optional B<-startindex> and B<-endindex> 
arguments may be specified to limit the query to specific rows in the table(s).

The B<-startindex> can be specified as a single decimal value or in dotted
notation if the index associated with the entry so requires.  If the
B<-startindex> is specified, it will be include as part of the query results.
If no B<-startindex> is specified, the first request message will be sent
without an index.  To insure that the B<-startindex> is included, the last
sub-identifier in the index is decremented by one.  If the last sub-identifier
has a value of zero, the sub-identifier is removed from the index.

The optional B<-endindex> argument can be specified as a single decimal value
or in dotted notation.  If the B<-endindex> is specified, it will be included 
as part of the query results.  If no B<-endindex> is specified, repeated SNMP
requests are issued until the response no longer returns entries matching 
any of the columns specified in the B<-columns> array.

The B<-maxrepetitions> argument can be used to specify the max-repetitions
value that is passed to the get-bulk-requests when using SNMPv2c or SNMPv3.
If this argument is not present, a value is calculated based on the maximum
message size of the object and the number of columns specified in the
B<-columns> array.  If the value is set to 1 or less, get-next-requests will 
be used for the queries instead of get-bulk-requests. 

A reference to a hash is returned in blocking mode which contains the contents
of the VarBindList.  In non-blocking mode, a true value is returned when no
error has occurred.  In either mode, the undefined value is returned when an
error has occurred.  The C<error()> method may be used to determine the cause
of the failure.

=cut

sub get_entries
{
   my $this = shift;

   $this->_error_clear();

   my @argv;

   # Validate the passed arguments.  

   if (!defined $this->_prepare_argv([qw( -callback
                                          -delay
                                          -contextengineid
                                          -contextname
                                          -entryoid
                                          -columns
                                          -startindex
                                          -endindex  
                                          -maxrepetitions       
                                          -rowcallback     )], \@_, \@argv))
   {
      return $this->_error();
   }

   if (ref $argv[1] ne 'ARRAY') {
      return $this->_error('The columns argument expects an array reference');
   }

   if (!scalar @{$argv[1]}) {
      return $this->_error('An empty columns list was specified');
   }

   # The syntax of get_entries() changes between release 4.1.0 and
   # release 4.1.1.  For backwards compatibility, we assume the old
   # syntax is being used if the "-entryoid" argument is present
   # and we silently convert to the new syntax.  

   if (defined $argv[0]) {

      # XXX: Argument deprecated after v5.2.0, obsolete in 6.0.1.

      require Carp;
      Carp::croak(
         'The entryoid argument is obsolete, use the columns argument ' .
         'with a list of column OBJECT IDENTIFIERs'
      );

      if ($argv[0] !~ m/^\.?\d+(?:\.\d+)* *$/) {
         return $this->_error(
            'The entryoid value "%s" is expected in dotted decimal notation',
            $argv[0]
         );
      }

      my $columns = {};

      for (@{$argv[1]}) {
         if (!m/^\d+$/) {
            return $this->_error(
               'The columns list value "%s" is expected in positive numeric ' .
               'format', $_
            );
         }
         if (exists $columns->{$_}) {
            return $this->_error(
               'The columns list value "%s" is duplicated in the columns list',
               $_
            );
         } else {
            $columns->{$_} = $_;
         }
      }

      # Now create the new syntax for the columns list.

      $argv[1] = [];

      for (sort { $a <=> $b } (keys %{$columns})) {
         push @{$argv[1]}, join q{.}, $argv[0], $_;
      }

   }

   # Validate the column list. 

   for (@{$argv[1]}) {
      if (!m/^\.?\d+(?:\.\d+)* *$/) {
         return $this->_error(
            'The columns list OBJECT IDENTIFIER "%s" is expected in dotted ' .
            'decimal notation', $_
         );
      }
   }

   my $start_index = undef;

   if (defined $argv[2]) {
      if ($argv[2] !~ m/^\d+(?:\.\d+)*$/) {
         return $this->_error(
            'The start index "%s" is expected in dotted decimal notation',
            $argv[2]
         );
      }
      my @subids = split m/\./, $argv[2];
      if ($subids[-1] > 0) {
         $subids[-1]--;
      } else {
         pop @subids;
      }
      $start_index = (@subids) ? join(q{.}, @subids) : q{};
   }

   if (defined $argv[3]) {
      if ($argv[3] !~ /^\d+(?:\.\d+)*$/) {
         return $this->_error(
             'The end index "%s" is expected in dotted decimal notation',
             $argv[3]
         );
      }
      if (defined $argv[2]) {
         if (oid_lex_cmp($argv[2], $argv[3]) > 0) {
            return $this->_error(
               'The end index cannot be less than the start index'
            );
         }
      }
   }

   # Undocumented and unsupported "-rowcallback" argument.

   if (defined $argv[5]) {
      if (ref $argv[5] eq 'CODE') {
         $argv[5] = [$argv[5]];
      } elsif ((ref($argv[5]) ne 'ARRAY') || (ref($argv[5]->[0]) ne 'CODE')) {
         return $this->_error('The syntax of the row callback is invalid');
      }
   }

   # Create a new PDU.
   if (!defined $this->_create_pdu()) {
      return $this->_error();
   }

   # Create table of values that need passed along with the
   # callbacks.  This just prevents a big argument list.

   my $argv = {
      callback     => $this->{_pdu}->callback(),
      columns      => $argv[1],
      end_index    => $argv[3],
      entries      => undef,
      last_index   => undef,
      max_reps     => 0,
      row_callback => $argv[5],
      start_index  => $argv[2],
      types        => undef,
      use_bulk     => FALSE
   };

   # Override the callback now that we have stored it.
   $this->{_pdu}->callback(
      sub
      {
         $this->{_pdu} = $_[0];
         $this->_error_clear();
         if ($this->{_pdu}->error()) {
            $this->_error($this->{_pdu}->error());
         }
         $this->_get_entries_cb($argv);
         return;
      }
   );

   # Create the varBindList by indexing each column with the start index.
   my $vbl =
   [
      map {
         (defined $start_index) ? join q{.}, $_, $start_index : $_
      } @{$argv->{columns}}
   ];

   # Determine if we are going to use get-next-requests or get-bulk-requests
   # based on the SNMP version and the -maxrepetitions argument.

   if ($this->version() == SNMP_VERSION_1) {
      if (defined $argv[4]) {
         return $this->_error(
            'The max-repetitions argument is not applicable when using SNMPv1'
         );
      }
   } else {
      if (!defined $argv[4]) {
         $argv->{use_bulk} = TRUE;
         # Scale the max-repetitions based on the number of columns.
         $argv->{max_reps} =
            int($this->_msg_size_max_reps() / @{$argv->{columns}}) + 1;
      } elsif ($argv[4] > 1) {
         $argv->{use_bulk} = TRUE;
         $argv->{max_reps} = $argv[4];
      }
   }

   # Create either a get-next-request or get-bulk-request PDU.

   if ($argv->{use_bulk}) {
      if (!defined $this->{_pdu}->prepare_get_bulk_request(0,
                                                           $argv->{max_reps},
                                                           $vbl))
      {
         return $this->_error($this->{_pdu}->error());
      }
   } else {
      if (!defined $this->{_pdu}->prepare_get_next_request($vbl)) {
         return $this->_error($this->{_pdu}->error());
      }
   }

   return $this->_send_pdu();
}

=head2 version() - get the SNMP version from the object

   $rfc_version = $session->version();

This method returns the current value for the SNMP version associated with
the object.  The returned value is the corresponding version number defined by
the RFCs for the protocol version field (i.e. SNMPv1 == 0, SNMPv2c == 1, and 
SNMPv3 == 3).  The RFC versions are defined as constant by the module and can 
be exported by request (see L<"EXPORTS">). 

=cut

sub version
{
   my ($this) = @_;

   return $this->_error('The SNMP version is not modifiable') if (@_ == 2);

   return $this->{_version};
}

=head2 error() - get the current error message from the object

   $error_message = $session->error();

This method returns a text string explaining the reason for the last error.
An empty string is returned if no error has occurred.

=cut

sub error
{
   return $_[0]->{_error} || q{};
}

=head2 hostname() - get the hostname associated with the object

   $hostname = $session->hostname();

This method returns the parsed hostname string that is associated with the
object.  Any port information and formatting that can be included with the
corresponding C<session()> constructor argument will be stripped and not
included as part of the returned string.

=cut

sub hostname
{
   return $_[0]->{_hostname};
}

=head2 error_status() - get the current SNMP error-status from the object

   $error_status = $session->error_status();

This method returns the numeric value of the error-status contained in the 
last SNMP message received by the object.

=cut

sub error_status
{
   return defined($_[0]->{_pdu}) ? $_[0]->{_pdu}->error_status() : 0;
}

=head2 error_index() - get the current SNMP error-index from the object

   $error_index = $session->error_index();

This method returns the numeric value of the error-index contained in the 
last SNMP message received by the object.

=cut

sub error_index
{
   return defined($_[0]->{_pdu}) ? $_[0]->{_pdu}->error_index() : 0;
}

=head2 var_bind_list() - get the hash reference for the VarBindList values 

   $values = $session->var_bind_list();

This method returns a hash reference created using the ObjectName and the 
ObjectSyntax pairs in the VarBindList of the last SNMP message received by 
the object.  The keys of the hash consist of the OBJECT IDENTIFIERs in dotted
notation corresponding to each ObjectName in the VarBindList.  If any of the 
OBJECT IDENTIFIERs passed to the request method began with a leading dot, all
of the OBJECT IDENTIFIER hash keys will be prefixed with a leading dot.  If 
duplicate OBJECT IDENTIFIERs are present in the VarBindList they will be 
padded with spaces to make them an unique hash key.  The value of each hash
entry is set equal to the value of the corresponding ObjectSyntax.  The
undefined value is returned if there has been a failure.

=cut

sub var_bind_list
{
   return defined($_[0]->{_pdu}) ? $_[0]->{_pdu}->var_bind_list() : undef;
}

=head2 var_bind_names() - get the array of the ObjectNames in the VarBindList

   @names = $session->var_bind_names();

This method returns an array containing the OBJECT IDENTIFIERs corresponding
to the ObjectNames in the VarBindList in the order that they were received
in the last SNMP message.  The entries in the array will map directly to the
keys in the hash reference returned by the methods that perform SNMP message
exchanges and by the C<var_bind_list()> and C<var_bind_types()> methods.  The
array returned for the convenience methods C<get_table()> and C<get_entries()>
will be in lexicographical order.  An empty array is returned if there has been
a failure.

=cut

sub var_bind_names
{
   return defined($_[0]->{_pdu}) ? @{$_[0]->{_pdu}->var_bind_names()} : ();
}

=head2 var_bind_types() - get the hash reference for the VarBindList ASN.1 types

   $types = $session->var_bind_types();

This method returns a hash reference created using the ObjectName and the ASN.1
type of the ObjectSyntax in the VarBindList of the last SNMP message received
by the object.  The keys of the hash consist of the OBJECT IDENTIFIERs in 
dotted notation corresponding to each ObjectName in the VarBindList.  The
value of each hash entry is set equal to the ASN.1 type of the corresponding
ObjectSyntax.  Constants for the supported ASN.1 types have been defined and
are exported by the package by default (see L<"EXPORTS">).  The undefined value
is returned if there has been a failure.

=cut

sub var_bind_types
{
   return defined($_[0]->{_pdu}) ? $_[0]->{_pdu}->var_bind_types() : undef;
}

=head2 timeout() - set or get the current timeout period for the object 

   $seconds = $session->timeout([$seconds]);

This method returns the current value for the Transport Layer timeout for 
the Net::SNMP object.  This value is the number of seconds that the object 
will wait for a response from the agent on the remote host.  The default 
timeout is 5.0 seconds.

If a parameter is specified, the timeout for the object is set to the provided
value if it falls within the range 1.0 to 60.0 seconds.  The undefined value
is returned upon an error and the C<error()> method may be used to determine
the cause.

=cut

sub timeout
{
   my $this = shift;

   if (!defined $this->{_transport}) {
      return $this->_error('The session is closed');
   }

   if (defined (my $timeout = $this->{_transport}->timeout(@_))) {
      return $timeout;
   }

   return $this->_error($this->{_transport}->error());
}

=head2 retries() - set or get the current retry count for the object

   $count = $session->retries([$count]);

This method returns the current value for the number of times to retry
sending a SNMP message to the remote host.  The default number of retries
is 1.

If a parameter is specified, the number of retries for the object is set to
the provided value if it falls within the range 0 to 20. The undefined value
is returned upon an error and the C<error()> method may be used to determine 
the cause.

=cut

sub retries
{
   my $this = shift;

   if (!defined $this->{_transport}) {
      return $this->_error('The session is closed');
   }

   if (defined (my $retries = $this->{_transport}->retries(@_))) {
      return $retries;
   }

   return $this->_error($this->{_transport}->error());
}

=head2 max_msg_size() - set or get the current maxMsgSize for the object

   $octets = $session->max_msg_size([$octets]);

This method returns the current value for the maximum message size 
(maxMsgSize) for the Net::SNMP object.  This value is the largest message size
in octets that can be prepared or processed by the object.  The default 
maxMsgSize is 1472 octets for UDP/IPv4, 1452 octets for UDP/IPv6, 1460 octets
for TCP/IPv4, and 1440 octets for TCP/IPv6.

If a parameter is specified, the maxMsgSize is set to the provided
value if it falls within the range 484 to 65535 octets.  The undefined 
value is returned upon an error and the C<error()> method may be used to 
determine the cause.

B<NOTE:> When using SNMPv3, the maxMsgSize is actually contained in the SNMP
message (as msgMaxSize).  If the value received from a remote device is less 
than the current maxMsgSize, the size is automatically adjusted to be the 
lower value.

=cut

sub max_msg_size
{
   my $this = shift;

   if (!defined $this->{_transport}) {
      return $this->_error('The session is closed');
   }

   if (defined (my $max_size = $this->{_transport}->max_msg_size(@_))) {
      return $max_size;
   }

   return $this->_error($this->{_transport}->error());
}

sub mtu
{
   goto &max_msg_size;
}

=head2 translate() - enable or disable the translation mode for the object

   $mask = $session->translate([ 
                        $mode |
                        [ # Perl anonymous ARRAY reference 
                           ['-all'            => $mode0,]
                           ['-octetstring'    => $mode1,]
                           ['-null'           => $mode2,]
                           ['-timeticks'      => $mode3,]
                           ['-opaque'         => $mode4,]
                           ['-nosuchobject'   => $mode5,] 
                           ['-nosuchinstance' => $mode6,]
                           ['-endofmibview'   => $mode7,]
                           ['-unsigned'       => $mode8]  
                        ]
                     ]);

When the object decodes the GetResponse-PDU that is returned in response to 
a SNMP message, certain values are translated into a more "human readable" 
form.  By default the following translations occur: 

=over 

=item *

OCTET STRINGs and Opaques containing any octet which is not part of the
character set defined as a DisplayString in RFC 2679 are converted into a
hexadecimal representation prefixed with "0x".  The control codes NUL(0x00),
BEL(0x07), BS(0x08), HT(0x09), LF(0x0A), VT(0x0b), FF(0x0C), and CR(0x0D)
are part of the character set and will not trigger translation.  The sequence
'CR x' for any x other than LF or NUL is illegal and will trigger translation.

=item *

TimeTicks integer values are converted to a time format.

=item *

NULL values return the string "NULL" instead of an empty string.

=item *

noSuchObject exception values return the string "noSuchObject" instead of an
empty string.

=item *

noSuchInstance exception values return the string "noSuchInstance" instead of 
an empty string.

=item *

endOfMibView exception values return the string "endOfMibView" instead of an
empty string.

=item *

Counter64, Counter, Gauge, and TimeTick values that have been incorrectly 
encoded as signed negative values are returned as unsigned values.

=back

The C<translate()> method can be invoked with two different types of arguments.

If the argument passed is any Perl variable type except an array reference,
the translation mode for all ASN.1 types is set to either enabled or disabled, 
depending on the value of the passed parameter.  Any value that Perl would 
treat as a true value will set the mode to be enabled for all types, while a 
false value will disable translation for all types.

A reference to an array can be passed to the C<translate()> method in order to
define the translation mode on a per ASN.1 type basis.  The array is expected
to contain a list of named argument pairs for each ASN.1 type that is to
be modified.  The arguments in the list are applied in the order that they
are passed in via the array.  Arguments at the end of the list supercede 
those passed earlier in the list.  The argument "-all" can be used to specify
that the mode is to apply to all ASN.1 types.  Only the arguments for the 
ASN.1 types that are to be modified need to be included in the list.

The C<translate()> method returns a bit mask indicating which ASN.1 types
are to be translated.  Definitions of the bit to ASN.1 type mappings can be
exported using the I<:translate> tag (see L<"EXPORTS">).  The undefined value 
is returned upon an error and the C<error()> method may be used to determine 
the cause.

=cut

sub translate
{
   my ($this, $mask) = @_;

   if (@_ != 2) {
      return $this->{_translate};
   }

   if (ref($mask) ne 'ARRAY') {

      # Behave like we did before, do (not) translate everything
      $this->_translate_mask($_[1], TRANSLATE_ALL);

   } else {

      # Allow the user to turn off and on specific translations.  An
      # array is used so the order of the arguments controls how the
      # mask is defined.

      my @argv = @{$mask};
      my $arg;

      while (defined ($arg = shift @argv)) {
         if ($arg =~ /^-?all$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_ALL);
         } elsif ($arg =~ /^-?none$/i) {
            $this->_translate_mask(!(shift @argv), TRANSLATE_ALL);
         } elsif ($arg =~ /^-?octet_?string$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_OCTET_STRING);
         } elsif ($arg =~ /^-?null$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_NULL);
         } elsif ($arg =~ /^-?timeticks$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_TIMETICKS);
         } elsif ($arg =~ /^-?opaque$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_OPAQUE);
         } elsif ($arg =~ /^-?nosuchobject$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_NOSUCHOBJECT);
         } elsif ($arg =~ /^-?nosuchinstance$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_NOSUCHINSTANCE);
         } elsif ($arg =~ /^-?endofmibview$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_ENDOFMIBVIEW);
         } elsif ($arg =~ /^-?unsigned$/i) {
            $this->_translate_mask(shift(@argv), TRANSLATE_UNSIGNED);
         } else {
            return $this->_error(
               'The translate argument "%s" is unknown', $arg
            );
         }
      }

   }

   DEBUG_INFO('translate mask = 0x%02x', $this->{_translate});

   return $this->{_translate};
}

=head2 debug() - set or get the debug mode for the module 

   $mask = $session->debug([$mask]);

This method is used to enable or disable debugging for the Net::SNMP module. 
Debugging can be enabled on a per component level as defined by a bit mask
passed to the C<debug()> method.  The bit mask is broken up as follows:

=over

=item * 

0x02 - Message or PDU encoding and decoding 

=item * 

0x04 - Transport Layer 

=item * 

0x08 - Dispatcher 

=item * 

0x10 - Message Processing  

=item * 

0x20 - Security

=back

Symbols representing these bit mask values are defined by the module and can
be exported using the I<:debug> tag (see L<"EXPORTS">).  If a non-numeric
value is passed to the C<debug()> method, it is evaluated in boolean context.
Debugging for all of the components is then enabled or disabled based on the
resulting truth value.

The current debugging mask is returned by the method.  Debugging can also be
enabled using the stand alone function C<snmp_debug()>. This function can be
exported by request (see L<"EXPORTS">). 

=cut

sub debug
{
   my (undef, $mask) = @_;

   if (@_ == 2) {

      $DEBUG = ($mask =~ /^\d+$/) ? $mask : ($mask) ? DEBUG_ALL : DEBUG_NONE;

      eval { Net::SNMP::Message->debug($DEBUG & DEBUG_MESSAGE);              };
      eval { Net::SNMP::Transport->debug($DEBUG & DEBUG_TRANSPORT);          };
      eval { Net::SNMP::Dispatcher->debug($DEBUG & DEBUG_DISPATCHER);        };
      eval { Net::SNMP::MessageProcessing->debug($DEBUG & DEBUG_PROCESSING); };
      eval { Net::SNMP::Security->debug($DEBUG & DEBUG_SECURITY);            };

   }

   return $DEBUG;
}

sub snmp_debug
{
   return debug(undef, $_[0]);
}

sub pdu
{
   return $_[0]->{_pdu};
}

sub nonblocking
{
   return $_[0]->{_nonblocking};
}

sub security
{
   return $_[0]->{_security};
}

sub transport
{
   return $_[0]->{_transport};
}

=head1 SUBROUTINES

=head2 oid_base_match() - determine if an OID has a specified OID base 

   $value = oid_base_match($base_oid, $oid);

This function takes two OBJECT IDENTIFIERs in dotted notation and returns a
true value (i.e. 0x1) if the second OBJECT IDENTIFIER is equal to or is a 
child of the first OBJECT IDENTIFIER in the SNMP Management Information Base 
(MIB).  This function can be used in conjunction with the C<get-next-request()>
or C<get-bulk-request()> methods to determine when a OBJECT IDENTIFIER in the 
GetResponse-PDU is no longer in the desired MIB tree branch.

=cut

sub oid_base_match
{
   my ($base, $oid) = @_;

   defined $base || return FALSE;
   defined $oid  || return FALSE;

   $base =~ s/^\.//o;
   $oid  =~ s/^\.//o;

   $base = pack 'N*', split m/\./, $base;
   $oid  = pack 'N*', split m/\./, $oid;

   return (substr($oid, 0, length $base) eq $base) ? TRUE : FALSE;
}

sub oid_context_match
{
   require Carp;
   Carp::croak(
       'oid_context_match() is obsolete, use oid_base_match() instead'
   );

   goto &oid_base_match;
}

=head2 oid_lex_cmp() - compare two OBJECT IDENTIFIERs lexicographically

   $cmp = oid_lex_cmp($oid1, $oid2);

This function takes two OBJECT IDENTIFIERs in dotted notation and returns one
of the values 1, 0, -1 if $oid1 is respectively lexicographically greater,
equal, or less than $oid2.

=cut 

sub oid_lex_cmp
{
   my ($aa, $bb) = @_;

   for ($aa, $bb) {
      s/^\.//;
      s/ /\.0/g;
      $_ = pack 'N*', split m/\./;
   }

   return $aa cmp $bb;
}

=head2 oid_lex_sort() - sort a list of OBJECT IDENTIFIERs lexicographically

   @sorted_oids = oid_lex_sort(@oids);

This function takes a list of OBJECT IDENTIFIERs in dotted notation and returns
the listed sorted in lexicographical order.

=cut

sub oid_lex_sort
{
   if (@_ <= 1) {
      return @_;
   }

   return map { $_->[0] }
             sort { $a->[1] cmp $b->[1] }
                map
                {
                   my $oid = $_;
                   $oid =~ s/^\.//;
                   $oid =~ s/ /\.0/g;
                   [$_, pack 'N*', split m/\./, $oid]
                } @_;
}

=head2 snmp_type_ntop() - convert an ASN.1 type to presentation format

   $text = snmp_type_ntop($type);

This function takes an ASN.1 type octet and returns a text string suitable for
presentation.  Some ASN.1 type definitions map to the same octet value when
encoded.  This method cannot distinguish between these multiple mappings and
the most basic type name will be returned.

=cut

sub snmp_type_ntop
{
   goto &asn1_itoa;
}

=head2 ticks_to_time() - convert TimeTicks to formatted time

   $time = ticks_to_time($timeticks);

This function takes an ASN.1 TimeTicks value and returns a string representing
the time defined by the value.  The TimeTicks value is expected to be a 
non-negative integer value representing the time in hundredths of a second 
since some epoch.  The returned string will display the time in days, hours, 
and seconds format according to the value of the TimeTicks argument.

=cut

sub ticks_to_time
{
   goto &asn1_ticks_to_time;
}

sub DESTROY
{
   my ($this) = @_;

   # We decrement the object type count when the object goes out of
   # existance.  We assume that _object_type_validate() was called for
   # every creation or else we die.

   if ($this->{_nonblocking}) {
      if (--$NONBLOCKING < 0) {
         die 'FATAL: Invalid non-blocking object count';
      }
   } else {
      if (--$BLOCKING < 0) {
         die 'FATAL: Invalid blocking object count';
      }
   }
}

# [private methods] ----------------------------------------------------------

sub _send_pdu
{
   my ($this) = @_;

   # Check to see if we are still in the process of discovering the
   # authoritative SNMP engine.  If we are, queue the PDU if we are 
   # running in non-blocking mode.

   if ($this->{_nonblocking} && !$this->{_security}->discovered()) {
      push @{$this->{_discovery_queue}}, [$this->{_pdu}, $this->{_delay}];
      return TRUE;
   }

   # Hand the PDU off to the Dispatcher
   $DISPATCHER->send_pdu($this->{_pdu}, $this->{_delay});

   # Activate the dispatcher if we are blocking
   if (!$this->{_nonblocking}) {
      snmp_dispatcher();
   }

   # Return according to blocking mode 
   return ($this->{_nonblocking}) ? TRUE : $this->var_bind_list();
}

sub _create_pdu
{
   my ($this) = @_;

   # Create the new PDU
   ($this->{_pdu}, $this->{_error}) = Net::SNMP::PDU->new(
      -version   => $this->{_version},
      -security  => $this->{_security},
      -transport => $this->{_transport},
      -translate => $this->{_translate},
      -callback  => $this->_callback_closure(),
      -requestid => $DISPATCHER->msg_handle_alloc(),
      defined($this->{_context_engine_id}) ?
         (-contextengineid => $this->{_context_engine_id}) : (),
      defined($this->{_context_name}) ?
         (-contextname     => $this->{_context_name})      : (),
   );

   if (!defined $this->{_pdu}) {
      return $this->_error();
   }
   $this->_error_clear();

   # Return the PDU
   return $this->{_pdu};
}

{
   my $versions = {
      '(?:snmp)?v?1',     SNMP_VERSION_1,
      '(?:snmp)?v?2c?',   SNMP_VERSION_2C,
      '(?:snmp)?v?3',     SNMP_VERSION_3,
   };

   sub _version
   {
      my ($this, $version) = @_;

      # XXX: The passed $version is updated as a side effect.

      # Clear any previous error message.
      $this->_error_clear();

      if ($version eq q{}) {
         return $this->_error('An empty SNMP version was specified');
      }

      for (keys %{$versions}) {
         if ($version =~ m/^$_$/i) {
            $_[1] = $this->{_version} = $versions->{$_};
            return TRUE;
         }
      }

      return $this->_error('The SNMP version "%s" is unknown', $version);
   }

}

{
   # Arguments that apply to the object.
   my $obj_args = {
      -callback        => \&_callback,          # non-blocking only
      -contextengineid => \&_context_engine_id, # v3 only
      -contextname     => \&_context_name,      # v3 only
      -delay           => \&_delay,             # non-blocking only
   };

   sub _prepare_argv
   {
      my ($this, $allowed, $named, $unnamed) = @_;

      # XXX: Argument $unnamed is updated by reference. 

      my %argv;

      # For backwards compatibility, check to see if the first 
      # argument is an OBJECT IDENTIFIER in dotted notation.  If it
      # is, assign it to the -varbindlist argument.

      if ((@{$named}) && ($named->[0] =~ m/^\.?\d+(?:\.\d+)* *$/)) {
         $argv{-varbindlist} = $named;
      } else {
         %argv = @{$named};
      }

      # Go through the passed argument list and see if the argument is
      # allowed.  If it is, see if it applies to the object and has a 
      # matching method call or add it the the new argv list to be 
      # returned by this method.

      my %new_args;

      for my $key (keys %argv) {
         my @match = grep { /^-?\Q$key\E$/i } @{$allowed};
         if (@match == 1) {
            if (exists $obj_args->{$match[0]}) {
               if (!defined $this->${\$obj_args->{$match[0]}}($argv{$key})) {
                  return $this->_error();
               }
            } else {
               $new_args{$match[0]} = $argv{$key};
            }
         } else {
            return $this->_error('The argument "%s" is unknown', $key);
         }
      }

      # Create a new ordered unnamed argument list based on the allowed 
      # list passed, ignoring those that applied to the object.

      for (@{$allowed}) {
         next if exists $obj_args->{$_};
         push @{$unnamed}, exists($new_args{$_}) ? $new_args{$_} : undef;
      }

      return TRUE;
   }

}

sub _callback
{
   my ($this, $callback) = @_;

   # We validate the callback argument and then create an anonymous 
   # array where the first element is the subroutine reference and 
   # the second element is an array reference containing arguments 
   # to pass to the subroutine.

   if (!$this->{_nonblocking}) {
      return $this->_error(
         'The callback argument is not applicable to blocking objects'
      );
   }

   my @argv;

   if (!defined $callback) {
      $this->{_callback} = undef;
      return TRUE;
   } elsif ((ref($callback) eq 'ARRAY') && (ref($callback->[0]) eq 'CODE')) {
      ($callback, @argv) = @{$callback};
   } elsif (ref($callback) ne 'CODE') {
      return $this->_error('The syntax of the callback is invalid');
   }

   $this->{_callback} = [$callback, \@argv];

   return TRUE;
}

sub _callback_closure
{
   my ($this) = @_;

   # When a response message is received, the Dispatcher will create
   # a new PDU object and assign the callback to that object.  The
   # callback is then executed passing a reference to the PDU object 
   # as the first argument.  We use a closure to assign that passed 
   # reference to the Net:SNMP object and then invoke the user defined 
   # callback.

   if (!$this->{_nonblocking} || !defined $this->{_callback}) {
      return sub
         {
            $this->{_pdu} = $_[0];
            $this->_error_clear();
            if ($this->{_pdu}->error()) {
               $this->_error($this->{_pdu}->error());
            }
            return;
         };
   }

   my ($callback, $argv) = @{$this->{_callback}};

   return sub
      {
         $this->{_pdu} = $_[0];
         $this->_error_clear();
         if ($this->{_pdu}->error()) {
            $this->_error($this->{_pdu}->error());
         }
         $callback->($this, @{$argv});
         return;
      };
}

sub _context_engine_id
{
   my ($this, $context_engine_id) = @_;

   $this->_error_clear();

   if ($this->version() != SNMP_VERSION_3) {
      return $this->_error(
         'The contextEngineID argument is only supported in SNMPv3'
      );
   }

   if (!defined $context_engine_id) {
      $this->{_context_engine_id} = undef;
   } elsif ($context_engine_id =~ m/^(?:0x)?([A-F0-9]+)$/i) {
       my $cei = pack 'H*', length($1) %  2 ? '0'.$1 : $1;
       my $len = length $cei;
       if ($len < 5 || $len > 32) {
          return $this->_error(
             'The contextEngineID length of %d is out of range (5..32)', $len
          );
       }
       $this->{_context_engine_id} = $cei;
   } else {
      return $this->_error(
         'The contextEngineID "%s" is expected in hexadecimal format',
         $context_engine_id
      );
   }

   return TRUE;
}

sub _context_name
{
   my ($this, $context_name) = @_;

   $this->_error_clear();

   if ($this->version() != SNMP_VERSION_3) {
      return $this->_error(
         'The contextName argument is only supported in SNMPv3'
      );
   }

   if (!defined $context_name) {
      $this->{_context_name} = undef;
   } elsif (length($context_name) <= 32) {
      $this->{_context_name} = $context_name;
   } else {
      return $this->_error(
         'The contextName length of %d is out of range (0..32)',
         length $context_name
      );
   }

   return TRUE;
}

sub _delay
{
   my ($this, $delay) = @_;

   $this->_error_clear();

   if (!$this->{_nonblocking}) {
      return $this->_error(
         'The delay argument is not applicable to blocking objects'
      );
   }

   if ($delay !~ /^\d+(?:\.\d+)?$/) {
      return $this->_error(
         'The delay value "%s" is expected in positive numeric format', $delay
      );
   }

   if ($delay < 0 || $delay > 31556926) { # Seconds in a year...
      return $this->_error(
         'The delay value "%s" is out of range (0..31556926)', $delay
      );
   }

   $this->{_delay} = $delay;

   return TRUE;
}

sub _object_type_validate
{
   my ($this) = @_;

   # Since both non-blocking and blocking objects use the same
   # Dispatcher instance, allowing both objects types to exist at
   # the same time would cause problems.  This method is called
   # by the constructor to track the object counts based on the 
   # non-blocking property and returns an error if the two types
   # would exist at the same time.

   my $count = ($this->{_nonblocking}) ? ++$NONBLOCKING : ++$BLOCKING;

   if ($this->{_nonblocking} && $BLOCKING) {
      return $this->_error(
         'Cannot create non-blocking objects when blocking objects exist'
      );
   } elsif (!$this->{_nonblocking} && $NONBLOCKING) {
      return $this->_error(
         'Cannot create blocking objects when non-blocking objects exist'
      );
   }

   return $count;
}

sub _perform_discovery
{
   my ($this) = @_;

   return TRUE if ($this->{_security}->discovered());

   # RFC 3414 - Section 4: "Discovery... ...may be accomplished by
   # generating a Request message with a securityLevel of noAuthNoPriv,
   # a msgUserName of zero-length, a msgAuthoritativeEngineID value of
   # zero length, and the varBindList left empty."

   # Create a new PDU
   if (!defined $this->_create_pdu()) {
      return $this->_discovery_failed();
   }

   # Create the callback and assign it to the PDU
   $this->{_pdu}->callback(
      sub
      {
         $this->{_pdu} = $_[0];
         $this->_error_clear();
         if ($this->{_pdu}->error()) {
            $this->_error($this->{_pdu}->error() . ' during discovery');
         }
         $this->_discovery_engine_id_cb();
         return;
      }
   );

   # Prepare an empty get-request
   if (!defined $this->{_pdu}->prepare_get_request()) {
      $this->_error($this->{_pdu}->error());
      return $this->_discovery_failed();
   }

   # Send the PDU
   $DISPATCHER->send_pdu($this->{_pdu}, 0);

   if (!$this->{_nonblocking}) {
      snmp_dispatcher();
   }

   return ($this->{_error}) ? $this->_error() : TRUE;
}

sub _discovery_engine_id_cb
{
   my ($this) = @_;

   # "The response to this message will be a Report message containing 
   # the snmpEngineID of the authoritative SNMP engine...  ...with the 
   # usmStatsUnknownEngineIDs counter in the varBindList."  If another 
   # error is returned, we assume snmpEngineID discovery has failed.

   if ($this->{_error} !~ /usmStatsUnknownEngineIDs/) {
      return $this->_discovery_failed();
   }

   # Clear the usmStatsUnknownEngineIDs error
   $this->_error_clear();

   # If the security model indicates that discovery is complete,
   # we send any pending messages and return success.  If discovery
   # is not complete, we probably need to synchronize with the
   # remote authoritative engine.

   if ($this->{_security}->discovered()) {
      DEBUG_INFO('discovery complete');
      return $this->_discovery_complete();
   }

   # "If authenticated communication is required, then the discovery
   # process should also establish time synchronization with the
   # authoritative SNMP engine.  This may be accomplished by sending
   # an authenticated Request message..."

   # Create a new PDU
   if (!defined $this->_create_pdu()) {
      return $this->_discovery_failed();
   }

   # Create the callback and assign it to the PDU
   $this->{_pdu}->callback(
      sub
      {
         $this->{_pdu} = $_[0];
         $this->_error_clear();
         if ($this->{_pdu}->error()) {
            $this->_error($this->{_pdu}->error() . ' during synchronization');
         }
         $this->_discovery_synchronization_cb();
         return;
      }
   );

   # Prepare an empty get-request
   if (!defined $this->{_pdu}->prepare_get_request()) {
      $this->_error($this->{_pdu}->error());
      return $this->_discovery_failed();
   }

   # Send the PDU
   $DISPATCHER->send_pdu($this->{_pdu}, 0);

   if (!$this->{_nonblocking}) {
      snmp_dispatcher();
   }

   return ($this->{_error}) ? $this->_error() : TRUE;
}

sub _discovery_synchronization_cb
{
   my ($this) = @_;

   # "The response... ...will be a Report message containing the up 
   # to date values of the authoritative SNMP engine's snmpEngineBoots 
   # and snmpEngineTime...  It also contains the usmStatsNotInTimeWindows
   # counter in the varBindList..."  If another error is returned, we 
   # assume that the synchronization has failed.

   if (($this->{_security}->discovered()) &&
       ($this->{_error} =~ /usmStatsNotInTimeWindows/))
   {
      $this->_error_clear();
      DEBUG_INFO('discovery and synchronization complete');
      return $this->_discovery_complete();
   }

   # If we received the usmStatsNotInTimeWindows report or no error, but 
   # we are still not synchronized, provide a generic error message.

   if ((!$this->{_error}) || ($this->{_error} =~ /usmStatsNotInTimeWindows/)) {
      $this->_error_clear();
      $this->_error('Time synchronization failed during discovery');
   }

   DEBUG_INFO('synchronization failed');

   return $this->_discovery_failed();
}

sub _discovery_failed
{
   my ($this) = @_;

   # The discovery process has failed, clear the current PDU and the
   # Transport Domain so no one can use this object to send messages.

   $this->{_pdu}       = undef;
   $this->{_transport} = undef;

   # Inform the command generator about the current error.
   while (my $q = shift @{$this->{_discovery_queue}}) {
      $q->[0]->status_information($this->{_error});
   }

   return $this->_error();
}

sub _discovery_complete
{
   my ($this) = @_;

   # Discovery is complete, send any pending messages.
   while (my $q = shift @{$this->{_discovery_queue}}) {
      $DISPATCHER->send_pdu(@{$q});
   }

   return ($this->{_error}) ? $this->_error() : TRUE;
}

sub _translate_mask
{
   my ($this, $enable, $mask) = @_;

   # Define the translate bitmask for the object based on the
   # passed truth value and mask.

   if ($enable) {
      $this->{_translate} |= $mask;  # Enable
   } else {
      $this->{_translate} &= ~$mask; # Disable
   }

   return $this->{_translate};
}

sub _msg_size_max_reps
{
   my ($this) = @_;

   # Use the maxMsgSize of the object to produce a max-repetitions
   # value.  This is an attempt to avoid exceeding the maxMsgSize
   # in the responses to get-bulk-requests.  The scaling factor
   # of 0.017 produces a value of 25 with the default maxMsgSize of
   # 1472. This was the old hardcoded value used by get_table().

   if (!defined $this->{_transport}) {
      return 25;
   }

   return int $this->{_transport}->max_msg_size() * 0.017;
}

sub _get_table_cb
{
   my ($this, $argv) = @_;

   # Use get-next-requests or get-bulk-requests until the response is
   # not a subtree of the base OBJECT IDENTIFIER.  Return the table only
   # if there are no errors other than a noSuchName(2) error since the
   # table could be at the end of the tree.  Also return the table when
   # the value of the OID equals endOfMibView(2) when using SNMPv2c.

   # Get the current callback.
   my $callback = $this->{_pdu}->callback();

   # Assign the user callback to the PDU.
   $this->{_pdu}->callback($argv->{callback});

   my $list  = $this->var_bind_list();
   my $types = $this->var_bind_types();
   my @names = $this->var_bind_names();
   my $next  = undef;

   while (@names) {

      $next = shift @names;

      # Check to see if we are still in the correct subtree and have
      # not received a endOfMibView exception.

      if (!oid_base_match($argv->{base_oid}, $next) ||
          ($types->{$next} == ENDOFMIBVIEW))
      {
         $next = undef; # End of table. 
         last;
      }

      # Add the entry to the table only if it is not already present
      # and check to make sure that the remote host does not respond
      # incorrectly causing the requests to loop forever.

      if (!exists $argv->{table}->{$next}) {
         $argv->{table}->{$next} = $list->{$next};
         $argv->{types}->{$next} = $types->{$next};
      } elsif (++$argv->{repeat_cnt} > $argv->{max_reps}) {
         $this->{_pdu}->status_information(
            'A loop was detected with the table on the remote host'
         );
         return;
      }
   }

   # Queue the next request if we are not at the end of the table.
   if (defined $next) {
      $this->_get_table_entries_request_next($argv, $callback, [$next]);
      return;
   }

   # Clear the PDU error on a noSuchName(2) error status.
   if ($this->error_status() == 2) {
      $this->{_pdu}->error(undef);
   }

   # Check for an empty or nonexistent table.
   if (!$this->{_pdu}->error() && !defined $argv->{table}) {
      $this->{_pdu}->error('The requested table is empty or does not exist');
   }

   # Copy the table to the var_bind_list.
   $this->{_pdu}->var_bind_list($argv->{table}, $argv->{types});

   # Notify the command generator to process the results.
   $this->{_pdu}->process_response_pdu();

   return;
}

sub _get_entries_cb
{
   my ($this, $argv) = @_;

   # Get the current callback.
   my $callback = $this->{_pdu}->callback();

   # Assign the user callback to the PDU.
   $this->{_pdu}->callback($argv->{callback});

   # Iterate through the response OBJECT IDENTIFIERs.  The response(s)
   # will (should) be grouped in the same order as the columns that
   # were requested.  We use this assumption to map the response(s) to
   # get-next/bulk-requests.  When using get-bulk-requests, "holes" in
   # the table may cause certain columns to run ahead or behind other
   # columns, so we cache all entries and sort it out when processing
   # the row.

   my $list       = $this->var_bind_list();
   my $types      = $this->var_bind_types();
   my @names      = $this->var_bind_names();
   my $max_index  = (defined $argv->{last_index}) ? $argv->{last_index} : '0';
   my $last_entry = TRUE;
   my $cache      = {};

   while (@names) {

      my @row = ();
      my $row_index = undef;

      # Match up the responses to the requested columns.

      for my $col_num (0 .. $#{$argv->{columns}}) {

         my $name = shift @names;

         if (!defined $name) {

            # Due to transport layer limitations, the response could have
            # been truncated, so do not consider this the last entry.

            DEBUG_INFO('column number / oid number mismatch');
            $last_entry = FALSE;
            @row = ();
            last;
         }

         my $column = quotemeta $argv->{columns}->[$col_num];
         my $index;

         if ($name =~ m/$column\.(\d+(:?\.\d+)*)/) {

            # Requested column and response column match up.
            $index = $1;

         } else {

            # The response column does not map to the the request, there
            # could be a "hole" or we are out of entries.

            DEBUG_INFO('last_entry: column mismatch: %s', $name);
            $last_entry = TRUE;
            next;
         }

         DEBUG_INFO('found index [%s]', $index);

         # Validate the index of the response.

         if ((defined $argv->{start_index}) &&
             (oid_lex_cmp($index, $argv->{start_index}) < 0))
         {
            DEBUG_INFO(
               'index [%s] less than start_index [%s]',
               $index, $argv->{start_index}
            );
            if (oid_lex_cmp($index, $max_index) > 0) {
               $max_index = $index;
               $last_entry = FALSE;
               DEBUG_INFO('new max_index [%s]', $max_index);
            }
            next;
         } elsif ((defined $argv->{end_index}) &&
                  (oid_lex_cmp($index, $argv->{end_index}) > 0))
         {
            DEBUG_INFO(
               'last_entry: index [%s] greater than end_index [%s]',
                $index, $argv->{end_index}
            );
            $last_entry = TRUE;
            next;
         }

         # Cache the current column since it falls into the requested range.

         $cache->{$index}->[$col_num] = $name;

         # To handle "holes" in the conceptual row, checks need to be made
         # so that the lowest index for each group of responses is used.

         if (!defined $row_index) {
            $row_index = $index;
         }

         my $index_cmp = oid_lex_cmp($index, $row_index);

         if ($index_cmp == 0) {

            # The index for this response entry matches, so fill in
            # the corresponding row entry.

            $row[$col_num] = $name;

         } elsif ($index_cmp < 0) {

            # The index for this response is less than the current index,
            # so we throw out everything and start over.

            @row = ();
            $row_index = $index;
            $row[$col_num] = $name;
            DEBUG_INFO('new minimum row_index [%s]', $row_index);

         } else {

            # There must be a "hole" in the row, do nothing here since this
            # entry was cached and will hopefully be taken care of later.

            DEBUG_INFO(
               'index [%s] greater than current row_index [%s]',
               $index, $row_index
            );

         }

      }

      # No row information found, continue.

      if (!@row || !defined $row_index) {
         next;
      }

      # Now store the results for the conceptual row.

      for my $col_num (0 .. $#{$argv->{columns}}) {

         # Check for cached values that may have been lost due to "holes".
         if (!defined $row[$col_num]) {
            if (defined $cache->{$row_index}->[$col_num]) {
               DEBUG_INFO('using cache: %s', $cache->{$row_index}->[$col_num]);
               $row[$col_num] = $cache->{$row_index}->[$col_num];
            } else {
               next;
            }
         }

         # Actually store the results.
         if (!exists $argv->{entries}->{$row[$col_num]}) {
            $last_entry = FALSE;
            $argv->{entries}->{$row[$col_num]} = $list->{$row[$col_num]};
            $argv->{types}->{$row[$col_num]}   = $types->{$row[$col_num]};
         } else {
            DEBUG_INFO('not adding duplicate: %s', $row[$col_num]);
         }

      }

      # Execute the row callback if it is defined.
      $this->_get_entries_exec_row_cb($argv, $row_index, \@row);

      # Store the maximum index found to be used for the next request.
      if (oid_lex_cmp($row_index, $max_index) > 0) {
         $max_index = $row_index;
         DEBUG_INFO('new max_index [%s]', $max_index);
      }

   }

   # Make sure we are not stuck (looping) on a single index.

   if (defined $argv->{last_index}) {
      if (oid_lex_cmp($max_index, $argv->{last_index}) > 0) {
         $argv->{last_index} = $max_index;
      } elsif ($last_entry == FALSE) {
         DEBUG_INFO(
            'last_entry: max_index [%s] not greater than last_index [%s])',
            $max_index, $argv->{last_index}
         );
         $last_entry = TRUE;
      }
   } else {
      $argv->{last_index} = $max_index;
   }

   # If we have not reached the last requested entry, generate another
   # get-next/bulk-request message.

   if ($last_entry == FALSE) {
      my $vbl = [ map { join q{.}, $_, $max_index } @{$argv->{columns}} ];
      $this->_get_table_entries_request_next($argv, $callback, $vbl);
      return;
   }

   # Clear the PDU error on a noSuchName(2) error status.
   if ($this->error_status() == 2) {
      $this->{_pdu}->error(undef);
   }

   # Check for an empty or nonexistent table.
   if (!$this->{_pdu}->error() && !defined $argv->{entries}) {
      $this->{_pdu}->error('The requested entries are empty or do not exist');
   }

   # Copy the table to the var_bind_list.
   $this->{_pdu}->var_bind_list($argv->{entries}, $argv->{types});

   # Execute the row callback, if there has been an error.
   if ($this->{_pdu}->error()) {
      $this->_get_entries_exec_row_cb($argv, 0, []);
   }

   # Notify the command generator to process the results.
   $this->{_pdu}->process_response_pdu();

   return;
}

sub _get_table_entries_request_next
{
   my ($this, $argv, $callback, $vbl) = @_;

   # Copy the current PDU for use in error conditions.
   my $pdu = $this->{_pdu};

   # Create a new PDU.
   if (!defined $this->_create_pdu()) {
      $pdu->status_information($this->error());
      return;
   }

   # Override the callback with the saved callback.
   $this->{_pdu}->callback($callback);

   # Use the contextEngineID and contextName from the previous request
   # because the values stored in the object could change.

   if (defined $pdu->context_engine_id()) {
      $this->{_pdu}->context_engine_id($pdu->context_engine_id());
   }

   if (defined $pdu->context_name()) {
      $this->{_pdu}->context_name($pdu->context_name());
   }

   # Create the appropriate request.

   if ($argv->{use_bulk}) {
      if (!defined $this->{_pdu}->prepare_get_bulk_request(0,
                                                           $argv->{max_reps},
                                                           $vbl))
      {
         $pdu->status_information($this->{_pdu}->error());
         return;
      }
   } else {
      if (!defined $this->{_pdu}->prepare_get_next_request($vbl)) {
         $pdu->status_information($this->{_pdu}->error());
         return;
      }
   }

   # Send the next PDU with no delay.
   $DISPATCHER->send_pdu($this->{_pdu}, 0);

   return;
}

sub _get_entries_exec_row_cb
{
   my ($this, $argv, $index, $row) = @_;

   return if !defined $argv->{row_callback};

   my ($cb, @argv) = @{$argv->{row_callback}};

   # Add the "values" found for each column to the front of the
   # callback argument list.

   for (my $col_num = $#{$argv->{columns}}; $col_num >= 0; --$col_num) {
      if (defined $row->[$col_num]) {
         unshift @argv, $argv->{entries}->{$row->[$col_num]};
      } else {
         unshift @argv, undef;
      }
   }

   # Prepend the index for the conceptual row.
   unshift @argv, $index;

   return eval { $cb->(@argv); };
}

sub _error
{
   my $this = shift;

   # If the PDU callback is still defined when an error occurs, it
   # needs to be cleared to prevent the closure from holding up the
   # reference count of the object that created the closure.

   if (defined $this->{_pdu} && defined $this->{_pdu}->callback()) {
      $this->{_pdu}->callback(undef);
   }

   if (!defined $this->{_error}) {
      $this->{_error} = (@_ > 1) ? sprintf(shift(@_), @_) : $_[0];
      if ($this->debug()) {
         printf "error: [%d] %s(): %s\n",
                (caller 0)[2], (caller 1)[3], $this->{_error};
      }
   }

   return;
}

sub _error_clear
{
   return $_[0]->{_error} = undef;
}

sub require_version
{
   my ($this, @argv) = @_;

   # Provide our own method for handling x.y.z version checks and the return
   # value of VERISON() in older implementations of Perl.  V-string versions
   # in Perl 5.10.0 are now treated as version objects and handled properly. 

   if (@argv > 0) {
      my $wanted = $argv[0];
      if ($wanted =~ /(\d+)\.(\d{1,3})\.(\d{1,3})/) {
         $argv[0] = sprintf '%d.%03d%03d', $1, $2, $3;
      }
   }

   my $version = eval
   {
      sprintf '%d.%03d%03d', unpack 'C*', $this->UNIVERSAL::VERSION(@argv);
   };

   if ($@) {
      local $_ = $@;
      s/ at(?:.*)\n//;
      require Carp;
      Carp::croak($_);
   }

   return $version;
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

# [end Net::SNMP code] -------------------------------------------------------
1;
__END__

# [documentation] ------------------------------------------------------------

=head1 EXPORTS

The Net::SNMP module uses the F<Exporter> module to export useful constants 
and subroutines.  These exportable symbols are defined below and follow the
rules and conventions of the F<Exporter> module (see L<Exporter>).

=over

=item Default

&snmp_dispatcher, INTEGER, INTEGER32, OCTET_STRING, OBJECT_IDENTIFIER, 
IPADDRESS, COUNTER, COUNTER32, GAUGE, GAUGE32, UNSIGNED32, TIMETICKS, 
OPAQUE, COUNTER64, NOSUCHOBJECT, NOSUCHINSTANCE, ENDOFMIBVIEW 

=item Exportable

&snmp_debug, &snmp_dispatcher, &snmp_type_ntop, &oid_base_match, &oid_lex_cmp,
&oid_lex_sort,&ticks_to_time, INTEGER, INTEGER32, OCTET_STRING, NULL,
OBJECT_IDENTIFIER, SEQUENCE, IPADDRESS, COUNTER, COUNTER32, GAUGE, GAUGE32,
UNSIGNED32, TIMETICKS, OPAQUE, COUNTER64, NOSUCHOBJECT, NOSUCHINSTANCE,
ENDOFMIBVIEW, GET_REQUEST, GET_NEXT_REQUEST, GET_RESPONSE, SET_REQUEST, TRAP,
GET_BULK_REQUEST, INFORM_REQUEST, SNMPV2_TRAP, REPORT, DEBUG_ALL, DEBUG_NONE,
DEBUG_MESSAGE, DEBUG_TRANSPORT, DEBUG_DISPATCHER,DEBUG_PROCESSING,
DEBUG_SECURITY, COLD_START, WARM_START, LINK_DOWN, LINK_UP,
AUTHENTICATION_FAILURE, EGP_NEIGHBOR_LOSS, ENTERPRISE_SPECIFIC,
SNMP_VERSION_1, SNMP_VERSION_2C, SNMP_VERSION_3, SNMP_PORT, SNMP_TRAP_PORT,
TRANSLATE_NONE,TRANSLATE_OCTET_STRING, TRANSLATE_NULL, TRANSLATE_TIMETICKS,
TRANSLATE_OPAQUE,TRANSLATE_NOSUCHOBJECT, TRANSLATE_NOSUCHINSTANCE,
TRANSLATE_ENDOFMIBVIEW, TRANSLATE_UNSIGNED, TRANSLATE_ALL

=item Tags

=over 

=item :asn1

INTEGER, INTEGER32, OCTET_STRING, NULL, OBJECT_IDENTIFIER, SEQUENCE, 
IPADDRESS, COUNTER, COUNTER32, GAUGE, GAUGE32, UNSIGNED32, TIMETICKS, OPAQUE, 
COUNTER64, NOSUCHOBJECT, NOSUCHINSTANCE, ENDOFMIBVIEW, GET_REQUEST, 
GET_NEXT_REQUEST, GET_RESPONSE, SET_REQUEST, TRAP, GET_BULK_REQUEST, 
INFORM_REQUEST, SNMPV2_TRAP, REPORT

=item :debug

&snmp_debug, DEBUG_ALL, DEBUG_NONE, DEBUG_MESSAGE, DEBUG_TRANSPORT, 
DEBUG_DISPATCHER, DEBUG_PROCESSING, DEBUG_SECURITY

=item :generictrap

COLD_START, WARM_START, LINK_DOWN, LINK_UP, AUTHENTICATION_FAILURE,
EGP_NEIGHBOR_LOSS, ENTERPRISE_SPECIFIC

=item :snmp

&snmp_debug, &snmp_dispatcher, &snmp_type_ntop, &oid_base_match, &oid_lex_cmp,
&oid_lex_sort, &ticks_to_time, SNMP_VERSION_1, SNMP_VERSION_2C, SNMP_VERSION_3,
SNMP_PORT, SNMP_TRAP_PORT

=item :translate

TRANSLATE_NONE, TRANSLATE_OCTET_STRING, TRANSLATE_NULL, TRANSLATE_TIMETICKS,
TRANSLATE_OPAQUE, TRANSLATE_NOSUCHOBJECT, TRANSLATE_NOSUCHINSTANCE, 
TRANSLATE_ENDOFMIBVIEW, TRANSLATE_UNSIGNED, TRANSLATE_ALL

=item :ALL

All of the above exportable items.

=back

=back

=head1 EXAMPLES

=head2 1. Blocking SNMPv1 get-request for sysUpTime

This example gets the sysUpTime from a remote host.

   #! /usr/local/bin/perl

   use strict;
   use warnings;

   use Net::SNMP;

   my $OID_sysUpTime = '1.3.6.1.2.1.1.3.0';

   my ($session, $error) = Net::SNMP->session(
      -hostname  => shift || 'localhost',
      -community => shift || 'public',
   );

   if (!defined $session) {
      printf "ERROR: %s.\n", $error;
      exit 1;
   }

   my $result = $session->get_request(-varbindlist => [ $OID_sysUpTime ],);

   if (!defined $result) {
      printf "ERROR: %s.\n", $session->error();
      $session->close();
      exit 1;
   }

   printf "The sysUpTime for host '%s' is %s.\n",
          $session->hostname(), $result->{$OID_sysUpTime};

   $session->close();

   exit 0;

=head2 2. Blocking SNMPv3 set-request of sysContact

This example sets the sysContact information on the remote host to 
"Help Desk x911".  The named arguments passed to the C<session()> constructor
are for the demonstration of syntax only.  These parameters will need to be
set according to the SNMPv3 parameters of the remote host.  The C<snmpkey>
utility included with the distribution can be used to create the key values.

   #! /usr/local/bin/perl

   use strict;
   use warnings;

   use Net::SNMP;

   my $OID_sysContact = '1.3.6.1.2.1.1.4.0';

   my ($session, $error) = Net::SNMP->session(
      -hostname     => 'myv3host.example.com',
      -version      => 'snmpv3',
      -username     => 'myv3Username',
      -authprotocol => 'sha1',
      -authkey      => '0x6695febc9288e36282235fc7151f128497b38f3f',
      -privprotocol => 'des',
      -privkey      => '0x6695febc9288e36282235fc7151f1284',
   );

   if (!defined $session) {
      printf "ERROR: %s.\n", $error;
      exit 1;
   }

   my $result = $session->set_request(
      -varbindlist => [ $OID_sysContact, OCTET_STRING, 'Help Desk x911' ],
   );

   if (!defined $result) {
      printf "ERROR: %s.\n", $session->error();
      $session->close();
      exit 1;
   }

   printf "The sysContact for host '%s' was set to '%s'.\n",
          $session->hostname(), $result->{$OID_sysContact};

   $session->close();

   exit 0;

=head2 3. Non-blocking SNMPv2c get-bulk-request for ifTable

This example gets the contents of the ifTable by sending get-bulk-requests
until the responses are no longer part of the ifTable.  The ifTable can also 
be retrieved using the C<get_table()> method.  The ifPhysAddress object in
the table has a syntax of an OCTET STRING.  By default, translation is enabled
and non-printable OCTET STRINGs are translated into a hexadecimal format.
Sometimes the OCTET STRING contains all printable characters and this produces
unexpected output when it is not translated.  The example turns off translation
for OCTET STRINGs and specifically formats the output for the ifPhysAddress
objects.

   #! /usr/local/bin/perl

   use strict;
   use warnings;

   use Net::SNMP qw(:snmp);

   my $OID_ifTable = '1.3.6.1.2.1.2.2';
   my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';

   my ($session, $error) = Net::SNMP->session(
      -hostname    => shift || 'localhost',
      -community   => shift || 'public',
      -nonblocking => 1,
      -translate   => [-octetstring => 0],
      -version     => 'snmpv2c',
   );

   if (!defined $session) {
      printf "ERROR: %s.\n", $error;
      exit 1;
   }

   my %table; # Hash to store the results

   my $result = $session->get_bulk_request(
      -varbindlist    => [ $OID_ifTable ],
      -callback       => [ \&table_callback, \%table ],
      -maxrepetitions => 10,
   );

   if (!defined $result) {
      printf "ERROR: %s\n", $session->error();
      $session->close();
      exit 1;
   }

   # Now initiate the SNMP message exchange.

   snmp_dispatcher();

   $session->close();

   # Print the results, specifically formatting ifPhysAddress.

   for my $oid (oid_lex_sort(keys %table)) {
      if (!oid_base_match($OID_ifPhysAddress, $oid)) {
         printf "%s = %s\n", $oid, $table{$oid};
      } else {
         printf "%s = %s\n", $oid, unpack 'H*', $table{$oid};
      }
   }

   exit 0;

   sub table_callback
   {
      my ($session, $table) = @_;

      my $list = $session->var_bind_list();

      if (!defined $list) {
         printf "ERROR: %s\n", $session->error();
         return;
      }

      # Loop through each of the OIDs in the response and assign
      # the key/value pairs to the reference that was passed with
      # the callback.  Make sure that we are still in the table
      # before assigning the key/values.

      my @names = $session->var_bind_names();
      my $next  = undef;

      while (@names) {
         $next = shift @names;
         if (!oid_base_match($OID_ifTable, $next)) {
            return; # Table is done.
         }
         $table->{$next} = $list->{$next};
      }

      # Table is not done, send another request, starting at the last
      # OBJECT IDENTIFIER in the response.  No need to include the
      # calback argument, the same callback that was specified for the
      # original request will be used.

      my $result = $session->get_bulk_request(
         -varbindlist    => [ $next ],
         -maxrepetitions => 10,
      );

      if (!defined $result) {
         printf "ERROR: %s.\n", $session->error();
      }

      return;
   }

=head2 4. Non-blocking SNMPv1 get-request and set-request on multiple hosts

This example first polls several hosts for their sysUpTime.  If the poll of
the host is successful, the sysContact and sysLocation information is set on
the host.  The sysContact information is hardcoded to "Help Desk x911" while
the sysLocation information is passed as an argument to the callback.

   #! /usr/local/bin/perl

   use strict;
   use warnings;

   use Net::SNMP;

   my $OID_sysUpTime = '1.3.6.1.2.1.1.3.0';
   my $OID_sysContact = '1.3.6.1.2.1.1.4.0';
   my $OID_sysLocation = '1.3.6.1.2.1.1.6.0';

   # Hash of hosts and location data.

   my %host_data = (
      '10.1.1.2'  => 'Building 1, Second Floor',
      '10.2.1.1'  => 'Building 2, First Floor',
      'localhost' => 'Right here!',
   );

   # Create a session for each host and queue a get-request for sysUpTime.

   for my $host (keys %host_data) {

      my ($session, $error) = Net::SNMP->session(
         -hostname    => $host,
         -community   => 'private',
         -nonblocking => 1,
      );

      if (!defined $session) {
         printf "ERROR: Failed to create session for host '%s': %s.\n",
                $host, $error;
         next;
      }

      my $result = $session->get_request(
         -varbindlist => [ $OID_sysUpTime ],
         -callback    => [ \&get_callback, $host_data{$host} ],
      );

      if (!defined $result) {
         printf "ERROR: Failed to queue get request for host '%s': %s.\n",
                $session->hostname(), $session->error();
      }

   }

   # Now initiate the SNMP message exchange.

   snmp_dispatcher();

   exit 0;

   sub get_callback
   {
      my ($session, $location) = @_;

      my $result = $session->var_bind_list();

      if (!defined $result) {
         printf "ERROR: Get request failed for host '%s': %s.\n",
                $session->hostname(), $session->error();
         return;
      }

      printf "The sysUpTime for host '%s' is %s.\n",
              $session->hostname(), $result->{$OID_sysUpTime};

      # Now set the sysContact and sysLocation for the host.

      $result = $session->set_request(
         -varbindlist =>
         [
            $OID_sysContact,  OCTET_STRING, 'Help Desk x911',
            $OID_sysLocation, OCTET_STRING, $location,
         ],
         -callback    => \&set_callback,
      );

      if (!defined $result) {
         printf "ERROR: Failed to queue set request for host '%s': %s.\n",
                $session->hostname(), $session->error();
      }

      return;
   }

   sub set_callback
   {
      my ($session) = @_;

      my $result = $session->var_bind_list();

      if (defined $result) {
         printf "The sysContact for host '%s' was set to '%s'.\n",
                $session->hostname(), $result->{$OID_sysContact};
         printf "The sysLocation for host '%s' was set to '%s'.\n",
                $session->hostname(), $result->{$OID_sysLocation};
      } else {
         printf "ERROR: Set request failed for host '%s': %s.\n",
                $session->hostname(), $session->error();
      }

      return;
   }

=head1 REQUIREMENTS

=over

=item *

The Net::SNMP module uses syntax that is not supported in versions of Perl 
earlier than v5.6.0. 

=item *

The non-core modules F<Crypt::DES>, F<Digest::MD5>, F<Digest::SHA1>, and 
F<Digest::HMAC> are required to support SNMPv3. 

=item *

In order to support the AES Cipher Algorithm as a SNMPv3 privacy protocol, the
non-core module F<Crypt::Rijndael> is needed.

=item *

To use UDP/IPv6 or TCP/IPv6 as a Transport Domain, the non-core module 
F<Socket6> is needed.

=back

=head1 AUTHOR

David M. Town E<lt>dtown@cpan.orgE<gt>

=head1 ACKNOWLEDGMENTS

The original concept for this module was based on F<SNMP_Session.pm> 
written by Simon Leinen E<lt>simon@switch.chE<gt>.

The Abstract Syntax Notation One (ASN.1) encode and decode methods were 
originally derived by example from the CMU SNMP package whose copyright 
follows: Copyright (c) 1988, 1989, 1991, 1992 by Carnegie Mellon University. 
All rights reserved. 

=head1 LICENSE AND COPYRIGHT

Copyright (c) 1998-2010 David M. Town.  All rights reserved.

This program is free software; you may redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself. 

=cut

# ============================================================================
1; # [end Net::SNMP]
