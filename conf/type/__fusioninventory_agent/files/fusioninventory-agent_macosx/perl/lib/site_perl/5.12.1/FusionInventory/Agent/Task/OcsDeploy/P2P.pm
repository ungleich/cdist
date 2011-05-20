package FusionInventory::Agent::Task::OcsDeploy::P2P;

use POE qw(Component::Client::HTTP Component::Client::Ping);

use HTTP::Request::Common qw(GET);
use Net::IP;
use strict;
use warnings;

sub fisher_yates_shuffle {
    my $deck = shift;  # $deck is a reference to an array

    return unless @$deck; # must not be empty!

    my $i = @$deck;
    while (--$i) {
        my $j = int rand ($i+1);
        @$deck[$i,$j] = @$deck[$j,$i];
    }
}

sub findMirrorWithPOE {
    my ( $params ) = @_;

    my $orderId = $params->{orderId};
    my $fragId = $params->{fragId};

    my $logger = $params->{logger};
    my $port = $params->{port};

    $logger->debug("looking for a peer in the network");

    my @addresses;

#if ($config->{'rpc-ip'}) {
#    $addresses{$config->{'rpc-ip'}}=1;
    if ( $^O =~ /^linux/x ) {
        foreach (`/sbin/ifconfig`) {
            if
                (/inet\saddr:(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3}).*Mask:(255)\.(255).(\d+)\.(\d+)$/x) {
                    push @addresses, { 
                        ip => [ $1, $2, $3, $4 ],
                           mask => [ 255, 255, 255, $8 ]
                    };
                }

        }
    } elsif ( $^O =~ /^MSWin/x ) {
        foreach (`route print`) {
            if (/^\s+(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\s+(255)\.(255)\.(\d+)\.(\d+)/x) {
                push @addresses, { 
                    ip => [ $1, $2, $3, $4 ],
                       mask => [ 255, 255, 255, $8 ]
                };
            }
        }
    }

    my @ipToTestList;
    foreach my $addr (@addresses) {
        next if $addr->{ip}[0] == 127; # Ignore 127.x.x.x addresses
            next if $addr->{ip}[0] == 169; # Ignore 169.x.x.x range too

            my @begin;
        my @end;

        foreach my $idx (0..3) {
            push @begin, $addr->{ip}[$idx] & (255 & $addr->{mask}[$idx]);
            push @end, $addr->{ip}[$idx] | (255 - $addr->{mask}[$idx]);
        }

        my $ipStart = sprintf("%d.%d.%d.%d", @begin);
        my $ipEnd = sprintf("%d.%d.%d.%d", @end);

        my $ipInterval = new Net::IP ($ipStart.' - '.$ipEnd) || die  (Net::IP::Error());

        next if $ipStart eq $ipEnd;

        $logger->debug("Scanning from $ipStart to $ipEnd");

        if ($ipInterval->size() > 1200) {
            $logger->debug("Range to large: ".$ipInterval->size()." (max 1200)");
            next;
        }

        do {
            my $ipToTest = $ipInterval->ip();
#        next if $ip eq $ipToTest; # Ignore myself :)
            push @ipToTestList, $ipToTest;
        } while (++$ipInterval);

    }

    return scan({port => $port, logger => $logger, orderId => $orderId, fragId => $fragId}, @ipToTestList);
}


sub scan {
    my ($params, @ipToTestList) = @_;
    my $port = $params->{port};
    my $logger = $params->{logger};
    my $orderId = $params->{orderId};
    my $fragId = $params->{fragId};
    my $testP2P = $params->{testP2P};


    fisher_yates_shuffle(\@ipToTestList);

    POE::Component::Client::Ping->spawn(
            Timeout             => 5,           # defaults to 1 second
            );

    POE::Component::Client::HTTP->spawn(
            Alias   => 'ua',
            Timeout => 10,
            Streaming => 10,
            );

    my $found;
    my $running = 0;

    my $thisIsWindows = ($^O =~ /mswin32/i);

    my $ipFound;
    POE::Session->create(
            inline_states => {
            _start => sub {
            $_[KERNEL]->yield( "add", 0 ) if @ipToTestList;
            $_[KERNEL]->yield( "add", 0 ) if @ipToTestList;
            $_[KERNEL]->yield( "add", 0 ) if @ipToTestList;
            },
            add => sub {
            my $ipToTest = shift @ipToTestList;
            return unless $ipToTest;
            if ($ipToTest && !@ipToTestList && $testP2P) {
# for the test-suite, get Google page
            $_[KERNEL]->post(ua => request => got_response => GET "http://209.85.227.101/" );
            }

            $_[KERNEL]->post(
                "pinger", # Post the request to the "pingthing" component.
                "ping",      # Ask it to "ping" an address.
                "pong",      # Have it post an answer as a "pong" event.
                $ipToTest,    # This is the address we want to ping.
                );
            $_[KERNEL]->alarm( "add" => time() + 0.1  ) if @ipToTestList;

            },
            pong => sub {
                my ($request, $response) = @_[ARG0, ARG1];

                my ($addr) = @$response;

                if (!$addr) {
                    $logger->debug($request->[0]." is down");
                    $_[KERNEL]->yield( "add", 0 ) if @ipToTestList;
                    return;
                } else {
                    $logger->debug($addr." is up");
                }
                $_[KERNEL]->post(ua => request => got_response => GET "http://$addr:$port/deploy/$orderId/$orderId-$fragId" );
#$_[KERNEL]->post(ua => request => got_response => GET "http://209.85.227.101/" );

            },

# A response has arrived.  Display it.
            got_response => sub {
                my ($self, $kernel, $session, $heap, $request_packet, $response_packet, $wheel_id) = @_[OBJECT, KERNEL, SESSION, HEAP, ARG0, ARG1, ARG3];


# The original HTTP::Request object.  If several requests
# were made, this can help match the response back to its
# request.
                my $http_request = $request_packet->[0];

# The HTTP::Response object.
                my ($http_response, $data) = @$response_packet;

                if ($http_response->is_success()) {
                    $ipFound = $http_response->base->host;
                }

                if ($ipFound)  {
                    $kernel->post(ua => 'shutdown');
                }

                $_[KERNEL]->yield( "add", 0 ) if @ipToTestList;
            },
            },
                          );

# Run everything, and exit when it's all done.
    $poe_kernel->run();

    if ($ipFound) {
        $logger->debug("Peer found at ".$ipFound);
        return $ipFound;
    } else {
        $logger->debug("No peer found");
        return;
    }

}

1;
