use strict;
use warnings;

package Net::NBName::NodeStatus::RR;

use vars '$VERSION';
$VERSION = "0.26";

use vars '@nodetypes';
@nodetypes = qw/B-node P-node M-node H-node/;

sub new
{
    my $class = shift;
    my $rr_data = shift;
    my ($name, $suffix, $flags) = unpack("a15Cn", $rr_data);
    $name =~ tr/\x00-\x19/\./; # replace ctrl chars with "."
    $name =~ s/\s+//g;

    my $self = {};
    $self->{'name'} = $name;
    $self->{'suffix'} = $suffix;
    $self->{'G'} = ($flags & 2**15) ? "GROUP" : "UNIQUE";
    $self->{'ONT'} = $nodetypes[($flags >> 13) & 3];
    $self->{'DRG'} = ($flags & 2**12) ? "Deregistering" : "Registered";
    $self->{'CNF'} = ($flags & 2**11) ? "Conflict" : "";
    $self->{'ACT'} = ($flags & 2**10) ? "Active" : "Inactive";
    $self->{'PRM'} = ($flags & 2**9) ? "Permanent" : "";

    bless $self, $class;
    return $self;
}

sub as_string
{
    my $self = shift;

    return sprintf "%-15s<%02X> %-6s %-6s %-10s %-8s %-8s %-4s\n",
        $self->{'name'},
        $self->{'suffix'},
        $self->{'G'},
        $self->{'ONT'},
        $self->{'DRG'},
        $self->{'ACT'},
        $self->{'CNF'},
        $self->{'PRM'};
}

sub name { return $_[0]->{'name'}; }
sub suffix { return $_[0]->{'suffix'}; }
sub G { return $_[0]->{'G'}; }
sub ONT { return $_[0]->{'ONT'}; }
sub DRG { return $_[0]->{'DRG'}; }
sub ACT { return $_[0]->{'ACT'}; }
sub CNF { return $_[0]->{'CNF'}; }
sub PRM { return $_[0]->{'PRM'}; }

1;

__END__

=head1 NAME

Net::NBName::NodeStatus::RR - NetBIOS Node Status Response Resource Record

=head1 DESCRIPTION

Net::NBName::NodeStatus::RR represents a name table entry returned
as part of a NetBIOS node status response.

=head1 METHODS

=over 4

=item $rr->name

Returns the registered name (a string of up to 15 characters).

=item $rr->suffix

The suffix of the registered name (the 16th character of the registered name).

Some common suffixes include:

    0x00 Redirector
    0x00 Domain (Group)
    0x03 Messenger
    0x1B Domain Master Browser
    0x1C Domain Controllers (Special Group)
    0x1D Master Browser
    0x1E Browser Elections (Group)
    0x20 Server

=item $rr->G

Group flag. Indicates whether the name is a unique or a group name. It is
returned as a string: either "UNIQUE" or "GROUP" will be returned.

For example, the following name types are UNIQUE:

    0x00 Redirector
    0x03 Messenger
    0x1B Domain Master Browser
    0x1D Master Browser
    0x20 Server

And the following name types are GROUP:

    0x00 Domain (Group)
    0x1C Domain Controllers (Special Group)
    0x1E Browser Elections (Group)

=item $rr->ONT

Owner Node Type flag. Indicates if the systems are B, P, H, or M-node. It will
be returned as a string.

=item $rr->DRG

Deregistering flag. "Deregistering" will be returned if the name is not
currently registered.

=item $rr->ACT

Active flag.

=item $rr->CNF

Conflict flag.

=item $rr->PRM

Permanent flag.

=item $rr->as_string

Returns the object's string representation.

=back

=head1 SEE ALSO

L<Net::NBName>, L<Net::NBName::NodeStatus>

=head1 COPYRIGHT

Copyright (c) 2002, 2003, 2004 James Macfarlane. All rights reserved. This
program is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
