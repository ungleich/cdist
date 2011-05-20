use strict;
use warnings;

package Net::NBName;

use Net::NBName::NodeStatus;
use Net::NBName::NameQuery;

use vars '$VERSION';
$VERSION = "0.26";

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    return $self;
}

sub node_status
{
    my $self = shift;
    my $host = shift;
    my $timeout = shift;

    my $req = Net::NBName::Request->new;
    $req->data(0, "*", "\x00", 0, 0x21);
    my $resp = $req->unicast($host, $timeout);
    if ($resp) {
        my $ns = Net::NBName::NodeStatus->new($resp);
        return $ns;
    } else {
        return undef;
    }
}

sub name_query
{
    my $self = shift;
    my $host = shift;
    my $name = shift;
    my $suffix = shift;
    my $flags = shift || 0x0100;
    my $timeout = shift;

    my $req = Net::NBName::Request->new;
    $req->data($flags, $name, ' ', $suffix, 0x20);
    my ($resp, $from_ip);
    if (defined($host)) {
        $resp = $req->unicast($host, $timeout);
    } else {
        ($resp, $from_ip) = $req->broadcast($timeout);
    }

    if ($resp) {
        my $nq = Net::NBName::NameQuery->new($resp);
        return $nq;
    } else {
        return undef;
    }
}
 
package Net::NBName::Request;

use Socket;

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    return $self;
}

sub data
{
    my $self = shift;
    my ($flags, $name, $pad, $suffix, $qtype) = @_;

    my $data = "";
    $data .= pack("n*", $$, $flags, 1, 0, 0, 0);
    $data .= _encode_name($name, $pad, $suffix);
    $data .= pack("n*", $qtype, 0x0001);

    $self->{data} = $data;
}

sub _encode_name
{
    my $name = uc(shift);
    my $pad = shift || "\x20";
    my $suffix = shift || 0x00;

    $name .= $pad x (16-length($name));
    substr($name, 15, 1) = chr($suffix & 0xFF);

    my $encoded_name = "";
    for my $c (unpack("C16", $name)) {
        $encoded_name .= chr(ord('A') + (($c & 0xF0) >> 4));
        $encoded_name .= chr(ord('A') + ($c & 0xF));
    }

    # Note that the _encode_name function doesn't add any scope,
    # nor does it calculate the length (32), it just prefixes it
    return "\x20" . $encoded_name . "\x00";
}

sub unicast
{
    my $self = shift;
    my $host = shift;
    # Timeout should be 250ms according to RFC1002
    my $timeout = shift || 0.25;

    my $data = $self->{data};

    my $protocol = getprotobyname('udp');
    my $port = 137;
    socket(SOCK, AF_INET, SOCK_DGRAM, $protocol) or return undef;
    my $to_saddr = sockaddr_in($port, inet_aton($host));

    send(SOCK, $data, 0, $to_saddr) or return undef;

    my $rin = "";
    my $rout;
    vec($rin, fileno(SOCK), 1) = 1;

    my ($nfound, $timeleft) = select($rout = $rin, undef, undef, $timeout);
    if ($nfound) {
        my $resp;
        if (my $from_saddr = recv(SOCK, $resp, 2000, 0)) {
            my ($from_port, $from_ip) = sockaddr_in($from_saddr);
            close(SOCKET);
            return $resp;
        } else { # socket error
            #printf "Errno %d %s\n", $!, $^E;
            close(SOCKET);
            return undef;
        }
    } else { # timed out
        close(SOCKET);
        return undef;
    }
}

sub broadcast
{
    my $self = shift;
    # Timeout should be 5s according to rfc1002 (but I've used 1s)
    my $timeout = shift || 1;

    my $host = "255.255.255.255";
    my $data = $self->{data};

    my $protocol = getprotobyname('udp');
    my $port = 137;
    socket(SOCK, AF_INET, SOCK_DGRAM, $protocol) or return undef;
    setsockopt(SOCK, SOL_SOCKET, SO_BROADCAST, 1);
    
    my $to_saddr = sockaddr_in($port, inet_aton($host));

    send(SOCK, $data, 0, $to_saddr) or return undef;
    my $rin = "";
    my $rout;
    vec($rin, fileno(SOCK), 1) = 1;

    my ($nfound, $timeleft) = select($rout = $rin, undef, undef, $timeout);
    if ($nfound) {
        my $resp;
        if (my $from_saddr = recv(SOCK, $resp, 2000, 0)) {
            my ($from_port, $from_ip) = sockaddr_in($from_saddr);
            close(SOCKET);
            return $resp, inet_ntoa($from_ip);
        } else { # socket error
            #printf "Errno %d %s\n", $!, $^E;
            close(SOCKET);
            return undef;
        }
    } else { # timed out
        close(SOCKET);
        return undef;
    }
}

1;

__END__

=head1 NAME

Net::NBName - NetBIOS Name Service Requests

=head1 SYNOPSIS

  use Net::NBName;
  my $nb = Net::NBName->new;

  # a unicast node status request
  my $ns = $nb->node_status("10.0.0.1");
  if ($ns) {
      print $ns->as_string;
  }

  # a unicast name query request
  my $nq = $nb->name_query("10.0.1.80", "SPARK", 0x00);
  if ($nq) {
      print $nq->as_string;
  }

  # a broadcast name query request
  my $nq = $nb->name_query(undef, "SPARK", 0x00);
  if ($nq) {
      print $nq->as_string;
  }

=head1 DESCRIPTION

Net::NBName is a class that allows you to perform simple NetBIOS Name
Service Requests in your Perl code. It performs these NetBIOS operations over
TCP/IP using Perl's built-in socket support.

I've currently implemented two NBNS requests: the node status request
and the name query request.

=over 4

=item NetBIOS Node Status Request

This allows you to determine the registered NetBIOS names for a
specified remote host.

The decoded response is returned as a C<Net::NBName::NodeStatus> object.

    querying 192.168.0.10 for node status...
    SPARK          <20> UNIQUE M-node Registered Active
    SPARK          <00> UNIQUE M-node Registered Active
    PLAYGROUND     <00> GROUP  M-node Registered Active
    PLAYGROUND     <1C> GROUP  M-node Registered Active
    PLAYGROUND     <1B> UNIQUE M-node Registered Active
    PLAYGROUND     <1E> GROUP  M-node Registered Active
    SPARK          <03> UNIQUE M-node Registered Active
    PLAYGROUND     <1D> UNIQUE M-node Registered Active
    ..__MSBROWSE__.<01> GROUP  M-node Registered Active
    MAC Address = 00-1C-2B-3A-49-58

=item NetBIOS Name Query Request

This allows you to resolve a name to an IP address using NetBIOS Name
Resolution. These requests can either be unicast (e.g. if you are querying
an NBNS server) or broadcast on the local subnet.

In either case, the decoded response is returned as an
C<Net::NBName::NameQuery> object.

    querying 192.168.0.10 for playground<00>...
    255.255.255.255 GROUP  B-node
    ttl = 0 (default is 300000)
    RA set, this was an NBNS server

    broadcasting for playground<1C>...
    192.168.0.10    GROUP  B-node
    ttl = 0 (default is 300000)
    RA set, this was an NBNS server

    broadcasting for spark<20>...
    192.168.0.10    UNIQUE H-node
    ttl = 0 (default is 300000)
    RA set, this was an NBNS server

=back

=head1 CONSTRUCTOR

=over 4

=item $nb = Net::NBName->new

Creates a new C<Net::NBName> object. This can be used to perform NetBIOS
Name Service requests.

=back

=head1 METHODS

=over 4

=item $ns = $nb->node_status( $host [, $timeout] )

This will query the host for its node status. The response will
be returned as a C<Net::NBName::NodeStatus> object.

If no response is received from the host, the method will return undef.

You can also optionally specify the timeout in seconds for the node status
request. The timeout defaults to .25 seconds.

=item $nq = $nb->name_query( $host, $name, $suffix [, $flags [, $timeout] ] )

This will query the host for the specified name. The response will
be returned as a C<Net::NBName::NameQuery> object.

If $host is undef, then a broadcast name query will
be performed; otherwise, a unicast name query will be performed.

Broadcast name queries can sometimes receive multiple responses.
Only the first positive response will be decoded and returned as a
C<Net::NBName::NameQuery> object.

If no response is received or a negative name query response is received,
the method will return undef.

You can override the flags in the NetBIOS name request, if you *really*
want to. See the notes on Hacking Name Query Flags.

You can also optionally specify the timeout in seconds for the name query
request. It defaults to .25 seconds for unicast name queries and 1 second
for broadcast name queries.

=back

=head1 EXAMPLES

=head2 Querying NetBIOS Names

You can use this example to query for a NetBIOS name. If you specify a host,
it will perform a unicast query; if you don't specify a host, it will
perform a broadcast query. I've used the shorthand of specifying the name
as <name>#<suffix> where the suffix should be in hex.

"namequery.pl spark#0" 

"namequery.pl spark#20 192.168.0.10"

    use strict;
    use Net::NBName;

    my $nb = Net::NBName->new;
    my $param = shift;
    my $host = shift;
    if ($param =~ /^([\w-]+)\#(\w{1,2})$/) {
        my $name = $1;
        my $suffix = hex $2;

        my $nq;
        if (defined($host) && $host =~ /\d+\.\d+\.\d+\.\d+/) {
            printf "querying %s for %s<%02X>...\n", $host, $name, $suffix;
            $nq = $nb->name_query($host, $name, $suffix);
        } else {
            printf "broadcasting for %s<%02X>...\n", $name, $suffix;
            $nq = $nb->name_query(undef, $name, $suffix);
        }
        if ($nq) {
            print $nq->as_string;
        }
    } else {
        die "expected: <name>#<suffix> [<host>]\n";
    }

=head2 Querying Remote Name Table

This example emulates the windows nbtstat -A command. By specifying
the ip address of the remote host, you can check its NetBIOS Name Table.

"nodestat.pl 192.168.0.10"

    use Net::NBName;

    my $nb = Net::NBName->new;
    my $host = shift;
    if (defined($host) && $host =~ /\d+\.\d+\.\d+\.\d+/) {
        my $ns = $nb->node_status($host);
        if ($ns) {
            print $ns->as_string;
        } else {
            print "no response\n";
        }
    } else {
        die "expected: <host>\n";
    }

=head2 Scanning for NetBIOS hosts

This example can be used to scan for NetBIOS hosts on a subnet. It uses
Net::Netmask to parse the subnet parameter and enumerate the hosts in
that subnet.

"nodescan.pl 192.168.0.0/24"

    use Net::NBName;
    use Net::Netmask;

    $mask = shift or die "expected: <subnet>\n";

    $nb = Net::NBName->new;
    $subnet = Net::Netmask->new2($mask);
    for $ip ($subnet->enumerate) {
        print "$ip ";
        $ns = $nb->node_status($ip);
        if ($ns) {
            for my $rr ($ns->names) {
                if ($rr->suffix == 0 && $rr->G eq "GROUP") {
                    $domain = $rr->name;
                }
                if ($rr->suffix == 3 && $rr->G eq "UNIQUE") {
                    $user = $rr->name;
                }
                if ($rr->suffix == 0 && $rr->G eq "UNIQUE") {
                    $machine = $rr->name unless $rr->name =~ /^IS~/;
                }
            }
            $mac_address = $ns->mac_address;
            print "$mac_address $domain\\$machine $user";
        }
        print "\n";
    }

=head1 NOTES

=head2 Microsoft's WINS Server Implementation

When performing name queries, you should note that when Microsoft implemented
their NBNS Name Server (Microsoft WINS Server) they mapped group names to the
single IP address 255.255.255.255 (the limited broadcast address). In order to
support I<real> group names, Microsoft modified WINS to provide support for
special groups. These groups appear differently in WINS. For example, the
Domain Controllers (0x1C) group appears as "Domain Name" instead of "Group".

The complete set of WINS mapping types is:

    Unique
    Group
    Domain Name
    Internet group
    Multihomed

Unique and Group map to a single IP address. Domain Name, Internet group, and
Multihomed are special groups that can include up to 25 IP addresses.

=head2 Hacking Name Query Flags

NetBIOS Name Service Requests have a number of flags associated with them.
These are set to sensible defaults by the code when sending node status
and name query requests.

However, it is possible to override these settings by calling the
name_query method of a C<Net::NBName> object with a fourth parameter:

    $nb->name_query( $host, $name, $suffix, $flags );

For a unicast name query, the flags default to 0x0100 which sets the RD
(recursion desired) flag. For a broadcast name query, the flags default to
0x0010 which sets the B (broadcast) flag.

Experimentation gave the following results:

=over 4

=item *

If B is set, the remote name table will be used. There will be no response if
the queried name is not present.

=item *

If B is not set and the host is an NBNS server, the NBNS server will be used
before the remote name table and you will get a negative response if the name
is not present; if the host is not an NBNS server, you will get no response if
the name is not present.

=back

=head1 COPYRIGHT

Copyright (c) 2002, 2003, 2004 James Macfarlane. All rights reserved. This
program is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
