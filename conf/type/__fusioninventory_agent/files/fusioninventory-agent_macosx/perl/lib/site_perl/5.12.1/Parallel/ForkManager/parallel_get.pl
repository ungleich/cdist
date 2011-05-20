#!/usr/bin/perl -w
use Parallel::ForkManager;
use LWP::Simple;
my $pm=new Parallel::ForkManager(10);
for my $link (@ARGV) {
  $pm->start and next;
  my ($fn)= $link =~ /^.*\/(.*?)$/;
  if (!$fn) {
    warn "Cannot determine filename from $fn\n";
  } else {
    $0.=" ".$fn;
    print "Getting $fn from $link\n";
    my $rc=getstore($link,$fn);
    print "$link downloaded. response code: $rc\n";
  };
  $pm->finish;
};
