# -*- mode: perl -*-
# ============================================================================

package Net::SNMP::Security;

# $Id: Security.pm,v 2.0 2009/09/09 15:05:33 dtown Rel $

# Base object that implements the Net::SNMP Security Models.

# Copyright (c) 2001-2009 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;

use Net::SNMP::Message qw(
   :securityLevels :securityModels :versions TRUE FALSE 
);

## Version of the Net::SNMP::Security module

our $VERSION = v2.0.0;

## Handle importing/exporting of symbols

use base qw( Exporter );

our @EXPORT_OK = qw( DEBUG_INFO );

our %EXPORT_TAGS = (
   levels => [
      qw( SECURITY_LEVEL_NOAUTHNOPRIV SECURITY_LEVEL_AUTHNOPRIV
          SECURITY_LEVEL_AUTHPRIV )
   ],
   models => [
      qw( SECURITY_MODEL_ANY SECURITY_MODEL_SNMPV1 SECURITY_MODEL_SNMPV2C
          SECURITY_MODEL_USM )
   ]
);

Exporter::export_ok_tags( qw( levels models ) );

$EXPORT_TAGS{ALL} = [ @EXPORT_OK ];

## Package variables

our $DEBUG = FALSE;  # Debug flag

our $AUTOLOAD;       # Used by the AUTOLOAD method

#perl2exe_include    Net::SNMP::Security::USM

# [public methods] -----------------------------------------------------------

sub new
{
   my ($class, %argv) = @_;

   my $version = SNMP_VERSION_1;

   # See if a SNMP version has been passed
   for (keys %argv) {
      if (/^-?version$/i) {
         if (($argv{$_} == SNMP_VERSION_1)  ||
             ($argv{$_} == SNMP_VERSION_2C) ||
             ($argv{$_} == SNMP_VERSION_3))
         {
            $version = $argv{$_};
         }
      }
   }

   # Return the appropriate object based upon the SNMP version.  To
   # avoid consuming unnecessary resources, only load the appropriate
   # module when requested.   The Net::SNMP::Security::USM module
   # requires four non-core modules.  If any of these modules are not
   # present, we gracefully return an error.

   if ($version == SNMP_VERSION_3) {

      if (defined(my $error = load_module('Net::SNMP::Security::USM'))) {
         $error = 'SNMPv3 support is unavailable ' . $error;
         return wantarray ? (undef, $error) : undef;
      }

      return Net::SNMP::Security::USM->new(%argv);
   }

   # Load the default Security module without eval protection.

   require Net::SNMP::Security::Community;
   return  Net::SNMP::Security::Community->new(%argv);
}

sub version
{
   my ($this) = @_;

   if (@_ > 1) {
      $this->_error_clear();
      return $this->_error('The SNMP version is not modifiable');
   }

   return $this->{_version};
}

sub discovered
{
   return TRUE;
}

sub security_model
{
   # RFC 3411 - SnmpSecurityModel::=TEXTUAL-CONVENTION

   return SECURITY_MODEL_ANY;
}

sub security_level
{
   # RFC 3411 - SnmpSecurityLevel::=TEXTUAL-CONVENTION

   return SECURITY_LEVEL_NOAUTHNOPRIV;
}

sub security_name
{
   return q{};
}

sub debug
{
   return (@_ == 2) ? $DEBUG = ($_[1]) ? TRUE : FALSE : $DEBUG;
}

sub error
{
   return $_[0]->{_error} || q{};
}

sub AUTOLOAD
{
   my ($this) = @_;

   return if $AUTOLOAD =~ /::DESTROY$/;

   $AUTOLOAD =~ s/.*://;

   if (ref $this) {
      $this->_error_clear();
      return $this->_error(
         'The method "%s" is not supported by this Security Model', $AUTOLOAD
      );
   } else {
      require Carp;
      Carp::croak(sprintf 'The function "%s" is not supported', $AUTOLOAD);
   }

   # Never get here.
   return;
}

# [private methods] ----------------------------------------------------------

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

sub _error_clear
{
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
         if ($@ =~ m/locate (\S+\.pm)/) {
            $modules{$module} = err_msg('(Required module %s not found)', $1);
         } elsif ($@ =~ m/(.*)\n/) {
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
   return if (!$DEBUG);

   return printf
      sprintf('debug: [%d] %s(): ', (caller 0)[2], (caller 1)[3]) .
      ((@_ > 1) ? shift(@_) : '%s') .
      "\n",
      @_;
}

# ============================================================================
1; # [end Net::SNMP::Security]

