#!/usr/bin/perl

use strict;
my $opt_debug=0;

my $groupFile="/cdist/conf/groups";

if(!$ARGV[0]) { die "Usage: $0 <system>\n"; }
my $system=$ARGV[0];
my @groups;

open(IN,$groupFile) || die "Could not open $groupFile for reading\n";
while(<IN>) {
  if (/^#/ || /^\s*$/) { next; }
  chomp;
  my($group,$members)=split(/:/);
  debug("Checking group:$group with members:$members\n");
  foreach my $m (split(/ /,$members)) {
    debug("Checking system:$system against member:$m\n");
    if ($m eq $system) { push(@groups,$group); }
  }
}

foreach my $g (@groups) {
  print "$g ";
}
print "\n";

sub debug { print $_[0] if $opt_debug; }
