package Net::DNS::Resolver::Win32;
#
# $Id: Win32.pm 795 2009-01-26 17:28:44Z olaf $
#

use strict;
use vars qw(@ISA $VERSION);

use Net::DNS::Resolver::Base ();

@ISA     = qw(Net::DNS::Resolver::Base);
$VERSION = (qw$LastChangedRevision: 795 $)[1];

use Win32::IPHelper;
use Win32::TieRegistry;
use Data::Dumper;
sub init {
  
        my $debug=0;
	my ($class) = @_;
	
	my $defaults = $class->defaults;


	my $FIXED_INFO={};

	my $ret = Win32::IPHelper::GetNetworkParams($FIXED_INFO);
	
	if ($ret == 0)
	  {
		  print Dumper $FIXED_INFO if $debug;
	  }
	else
	  {
		  
		  Carp::croak "GetNetworkParams() error %u: %s\n", $ret, Win32::FormatMessage($ret);
	  }
	

	my @nameservers = map { $_->{'IpAddress'} } @{$FIXED_INFO->{'DnsServersList'}};
	

	if (@nameservers) {
		# remove blanks and dupes
		my @a;
		my %h;
		foreach my $ns (@nameservers) {
			push @a, $ns unless (!$ns || $h{$ns});
			$h{$ns} = 1;
		}
		$defaults->{'nameservers'} = [map { m/(.*)/ } @a];
	}

	my $domain=$FIXED_INFO->{'DomainName'}||'';
	my $searchlist = "$domain" ;
	

	#
	# The Win32::IPHelper  does not return searchlist. Lets do a best effort attempt to get 
	# a searchlist from the registry.

	my $resobj;

	my $root = 'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters';
	my $opened_registry =1;
	$resobj = $Registry->{"LMachine\\$root"};
	if (!$resobj) {
		# Didn't work, maybe we are on 95/98/Me?
		$root = 'SYSTEM\CurrentControlSet\Services\VxD\MSTCP';
		$resobj = $Registry->{"LMachine\\$root"}
			or  $opened_registry =0;
	}

	
	if ($domain) {
		$defaults->{'domain'} = $domain;
	}

	my $usedevolution = $resobj->{'UseDomainNameDevolution'};
	if ($searchlist) {
		# fix devolution if configured, and simultaneously make sure no dups (but keep the order)
		my @a;
		my %h;
		foreach my $entry (split(m/[\s,]+/, $searchlist)) {
			push(@a, $entry) unless $h{$entry};
			$h{$entry} = 1;
			if ($usedevolution) {
				# as long there's more than two pieces, cut
				while ($entry =~ m#\..+\.#) {
					$entry =~ s#^[^\.]+\.(.+)$#$1#;
					push(@a, $entry) unless $h{$entry};
					$h{$entry} = 1;
					}
				}
			}
		$defaults->{'searchlist'} = \@a;
	}

	$class->read_env;

	if (!$defaults->{'domain'} && @{$defaults->{'searchlist'}}) {
		$defaults->{'domain'} = $defaults->{'searchlist'}[0];
	} elsif (!@{$defaults->{'searchlist'}} && $defaults->{'domain'}) {
		$defaults->{'searchlist'} = [ $defaults->{'domain'} ];
	}

	print Dumper $defaults if $debug;

}

1;
__END__


=head1 NAME

Net::DNS::Resolver::Win32 - Windows Resolver Class

=head1 SYNOPSIS

 use Net::DNS::Resolver;

=head1 DESCRIPTION

This class implements the windows specific portions of C<Net::DNS::Resolver>.

No user serviceable parts inside, see L<Net::DNS::Resolver|Net::DNS::Resolver>
for all your resolving needs.

=head1 COPYRIGHT

Copyright (c) 1997-2002 Michael Fuhr. 

Portions Copyright (c) 2002-2004 Chris Reinhardt.

Portions Copyright (c) 2009 Olaf Kolkman, NLnet Labs

All rights reserved.  This program is free software; you may redistribute
it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, L<Net::DNS::Resolver>

=cut
