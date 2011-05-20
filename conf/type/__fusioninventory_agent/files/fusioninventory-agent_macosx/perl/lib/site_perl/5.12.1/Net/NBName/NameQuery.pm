use strict;
use warnings;

package Net::NBName::NameQuery;

use Net::NBName::NameQuery::RR;

use vars '$VERSION';
$VERSION = '0.26';

sub new
{
    my $class = shift;
    my $resp = shift;

    my @header = unpack("n6", $resp);

    my $rcode = $header[1] & 15;
    if ($rcode == 0x0) { # positive name query response
        my $results = substr($resp, 50); # skip original query data
        my ($ttl, $rdlength) = unpack("Nn", $results);

        my @rr = ();
        for (my $i = 0; $i < $rdlength / 6; $i++) {
            my $nb_data = substr($results, 6+6*$i, 6);
            push @rr, Net::NBName::NameQuery::RR->new($nb_data);
        }

        my $self = {'addresses' => \@rr,
                    'ttl' => $ttl,
                    'AA' => ($header[1] & 0x0400) ? 1 : 0,
                    'TC' => ($header[1] & 0x0200) ? 1 : 0,
                    'RD' => ($header[1] & 0x0100) ? 1 : 0,
                    'RA' => ($header[1] & 0x0080) ? 1 : 0,
                    'B'  => ($header[1] & 0x0010) ? 1 : 0};
        bless $self, $class;
        return $self;
    } else {
        # probably rcode = 0x3, a negative name query response
        return undef;
    }
}

sub as_string
{
    my $self = shift;

    my $string = "";
    for my $rr (@{$self->{addresses}}) {
        $string .= $rr->as_string;
    }
    $string .= "ttl = $self->{ttl} (default is 300000)\n";
    $string .= "RA set, this was an NBNS server\n" if $self->{'RA'};
    return $string;
}

sub addresses { return @{$_[0]->{'addresses'}}; }
sub ttl { return $_[0]->{'ttl'}; }
sub RA { return $_[0]->{'RA'}; }

1;

__END__

=head1 NAME

Net::NBName::NameQuery - NetBIOS Name Query Response

=head1 DESCRIPTION

Net::NBName::NameQuery represents a decoded
NetBIOS name query response.

=head1 METHODS

=over 4

=item $nq->addresses

Returns a list of ip addresses returned for the queried name. These are
returned as a list of C<Net::NBName::NameQuery::RR> records.

Most name queries will only return one ip address, but you will get multiple ip
addresses returned for names registered by multihomed hosts or for group name
queries.

=item $nq->ttl

Time to live. This is the lifespan of the name registration.

=item $nq->RA

Recursion available. This flag is typically set if the responding host is an
NBNS server, and can be used to determine if it was an NBNS server that
responded.

=item $nq->as_string

Returns the object's string representation.

=back

=head1 SEE ALSO

L<Net::NBName>

=head1 COPYRIGHT

Copyright (c) 2002, 2003, 2004 James Macfarlane. All rights reserved. This
program is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
