use strict;
use warnings;

package Net::NBName::NodeStatus;

use Net::NBName::NodeStatus::RR;

use vars '$VERSION';
$VERSION = "0.26";

sub new
{
    my $class = shift;
    my $resp = shift;

    my @rr = ();
    my $mac_address = "";

    # Don't attempt to extract any names or the mac address
    # if the response is truncated
    if (length($resp) > 56) {
        my $num_names = unpack("C", substr($resp, 56));
        my $name_data = substr($resp, 57);

        for (my $i = 0; $i < $num_names; $i++) {
            my $rr_data = substr($name_data, 18*$i, 18);
            push @rr, Net::NBName::NodeStatus::RR->new($rr_data);
        }

        $mac_address = join "-", map { sprintf "%02X", $_ }
            unpack("C*", substr($name_data, 18 * $num_names, 6));
    }

    my $self = {'names' => \@rr, 'mac_address' => $mac_address};
    bless $self, $class;
    return $self;
}

sub as_string
{
    my $self = shift;

    my $string = "";
    for my $rr (@{$self->{names}}) {
        $string .= $rr->as_string;
    }
    $string .= "MAC Address = " . $self->{mac_address} . "\n";
    return $string;
}

sub names { return @{$_[0]->{'names'}}; }
sub mac_address { return $_[0]->{'mac_address'}; }

1;

__END__

=head1 NAME

Net::NBName::NodeStatus - NetBIOS Node Status Response

=head1 DESCRIPTION

Net::NBName::NodeStatus represents a decoded
NetBIOS node status response.

=head1 METHODS

=over 4

=item $ns->names

Returns a list of NetBIOS names registered on the responding host. These are
returned as a list of C<Net::NBName::NodeStatus::RR> objects.

=item $ns->mac_address

Returns the MAC address of the responding host. Not all systems will
respond with the correct MAC address, although all Windows-based systems
did during testing.

=item $ns->as_string

Returns the object's string representation.

=back 

=head1 SEE ALSO

L<Net::NBName>

=head1 COPYRIGHT

Copyright (c) 2002, 2003, 2004 James Macfarlane. All rights reserved. This
program is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
