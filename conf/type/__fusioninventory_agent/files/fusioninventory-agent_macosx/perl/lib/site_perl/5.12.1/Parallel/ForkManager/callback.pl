#!/usr/bin/perl -w
use lib '.';
use strict;
use Parallel::ForkManager;

my $max_procs = 5;
my @names = qw( Fred Jim Lily Steve Jessica Bob Dave Christine Rico Sara );
# hash to resolve PID's back to child specific information

my $pm =  new Parallel::ForkManager($max_procs);

# Setup a callback for when a child finishes up so we can
# get it's exit code
$pm->run_on_finish(
  sub { my ($pid, $exit_code, $ident) = @_;
    print "** $ident just got out of the pool ".
      "with PID $pid and exit code: $exit_code\n";
  }
);

$pm->run_on_start(
  sub { my ($pid,$ident)=@_;
    print "** $ident started, pid: $pid\n";
  }
);

$pm->run_on_wait(
  sub {
    print "** Have to wait for one children ...\n"
  },
  0.5,
);

foreach my $child ( 0 .. $#names ) {
  my $pid = $pm->start($names[$child]) and next;

  # This code is the child process
  print "This is $names[$child], Child number $child\n";
  sleep ( 2 * $child );
  print "$names[$child], Child $child is about to get out...\n";
  sleep 1;
  $pm->finish($child); # pass an exit code to finish
}

print "Waiting for Children...\n";
$pm->wait_all_children;
print "Everybody is out of the pool!\n";

