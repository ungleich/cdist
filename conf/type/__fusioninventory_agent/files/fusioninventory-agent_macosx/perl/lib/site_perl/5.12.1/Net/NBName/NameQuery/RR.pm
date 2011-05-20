use strict;
use warnings;

package Net::NBName::NameQuery::RR;

use vars '$VERSION';
$VERSION = "0.26";

use vars '@nodetypes';
@nodetypes = qw/B-node P-node M-node H-node/;

sub new
{
    my $class = shift;
    my $nb_data = shift;
    my ($flags, $packed_address) = unpack("na4", $nb_data);
    my $address = join ".", unpack("C4", $packed_address);

    my $self = {};
    $self->{'address'} = $address;
    $self->{'G'} = ($flags & 2**15) ? "GROUP" : "UNIQUE";
    $self->{'ONT'} = $nodetypes[($flags >> 13) & 3];

    bless $self, $class;
    return $self;
}

sub as_string
{
    my $self = shift;

    return sprintf "%-15s %-6s %-6s\n",
        $self->{'address'},
        $self->{'G'},
        $self->{'ONT'};
}

sub address { return $_[0]->{'address'}; }
sub G { return $_[0]->{'G'}; }
sub ONT { return $_[0]->{'ONT'}; }

1;

__END__

=head1 NAME

Net::NBName::NameQuery::RR - NetBIOS Name Query Response Resource Record

=head1 DESCRIPTION

Net::NBName::NameQuery::RR represents an ip address entry returned
as part of a NetBIOS name query response.

=head1 METHODS

=over 4

=item $rr->address

Returns the ip address as a dotted quad.

=item $rr->G

Group flag. Indicates whether the name is a unique or a group name. It is
returned as a string: either "UNIQUE" or "GROUP" will be returned.

=item $rr->ONT

Owner Node Type flag. Indicates if the systems are B, P, H, or M-node. It will
be returned as a string.

=item $rr->as_string

Returns the object's string representation.

=back

=head1 SEE ALSO

L<Net::NBName>, L<Net::NBName::NameQuery>

=head1 COPYRIGHT

Copyright (c) 2002, 2003, 2004 James Macfarlane. All rights reserved. This
program is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
