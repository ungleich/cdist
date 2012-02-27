#!/usr/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;
my ($debug,$listall);

GetOptions("debug|d" => \$debug, "listall" => \$listall);

my $groupFile="/cdist/conf/groups";

if(!$ARGV[0] && !$listall) { die "Usage: $0 [--listall] <system>\n"; }
my $system=$ARGV[0];
my @groups;
my %allsystems;

open(IN,$groupFile) || die "Could not open $groupFile for reading\n";
while(<IN>) {
  if (/^#/ || /^\s*$/) { next; }
  chomp;
  my($group,$members)=split(/:/);
  debug("Checking group:$group with members:$members\n");
  foreach my $m (split(/ /,$members)) {
    debug("Checking system:$system against member:$m\n");
    if ($m eq $system) { push(@groups,$group); }
    $allsystems{$m}=1;
  }
}
if($debug) { print Dumper(%allsystems); }

if ($listall) {
  foreach my $s (sort keys %allsystems) {
    print "$s ";
  }
  print "\n";
  exit 0;
} elsif (scalar @groups > 0) {
  foreach my $g (@groups) {
    print "$g ";
  }
  print "\n";
  exit 0;
} else {
  exit 1;
}

sub debug { print $_[0] if $debug; }
