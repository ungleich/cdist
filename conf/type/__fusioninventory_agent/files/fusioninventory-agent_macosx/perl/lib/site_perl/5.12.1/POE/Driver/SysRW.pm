# Copyright 1998 Rocco Caputo <rcaputo@cpan.org>.  All rights
# reserved.  This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.

package POE::Driver::SysRW;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Errno qw(EAGAIN EWOULDBLOCK);
use Carp qw(croak);

sub OUTPUT_QUEUE        () { 0 }
sub CURRENT_OCTETS_DONE () { 1 }
sub CURRENT_OCTETS_LEFT () { 2 }
sub BLOCK_SIZE          () { 3 }
sub TOTAL_OCTETS_LEFT   () { 4 }

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  my $self = bless [
    [ ],   # OUTPUT_QUEUE
    0,     # CURRENT_OCTETS_DONE
    0,     # CURRENT_OCTETS_LEFT
    65536, # BLOCK_SIZE
    0,     # TOTAL_OCTETS_LEFT
  ], $type;

  if (@_) {
    if (@_ % 2) {
      croak "$type requires an even number of parameters, if any";
    }
    my %args = @_;
    if (defined $args{BlockSize}) {
      $self->[BLOCK_SIZE] = delete $args{BlockSize};
      croak "$type BlockSize must be greater than 0"
        if ($self->[BLOCK_SIZE] <= 0);
    }
    if (keys %args) {
      my @bad_args = sort keys %args;
      croak "$type has unknown parameter(s): @bad_args";
    }
  }

  $self;
}

#------------------------------------------------------------------------------

sub put {
  my ($self, $chunks) = @_;
  my $old_queue_octets = $self->[TOTAL_OCTETS_LEFT];

  # Need to check lengths in octets, not characters.
  BEGIN { eval { require bytes } and bytes->import; }

  foreach (grep { length } @$chunks) {
    $self->[TOTAL_OCTETS_LEFT] += length;
    push @{$self->[OUTPUT_QUEUE]}, $_;
  }

  if ($self->[TOTAL_OCTETS_LEFT] && (!$old_queue_octets)) {
    $self->[CURRENT_OCTETS_LEFT] = length($self->[OUTPUT_QUEUE]->[0]);
    $self->[CURRENT_OCTETS_DONE] = 0;
  }

  $self->[TOTAL_OCTETS_LEFT];
}

#------------------------------------------------------------------------------

sub get {
  my ($self, $handle) = @_;

  my $result = sysread($handle, my $buffer = '', $self->[BLOCK_SIZE]);

  # sysread() returned a positive number of octets.  Return whatever
  # was read.
  return [ $buffer ] if $result;

  # 18:01 <dngor> sysread() clears $! when it returns 0 for eof?
  # 18:01 <merlyn> nobody clears $!
  # 18:01 <merlyn> returning 0 is not an error
  # 18:01 <merlyn> returning -1 is an error, and sets $!
  # 18:01 <merlyn> eof is not an error. :)

  # 18:21 <dngor> perl -wle '$!=1; warn "\$!=",$!+0; \
  #               warn "sysread=",sysread(STDIN,my $x="",100); \
  #               die "\$!=",$!+0' < /dev/null
  # 18:23 <lathos> $!=1 at foo line 1.
  # 18:23 <lathos> sysread=0 at foo line 1.
  # 18:23 <lathos> $!=0 at foo line 1.
  # 18:23 <lathos> 5.6.0 on Darwin.
  # 18:23 <dngor> Same, 5.6.1 on fbsd 4.4-stable.
  #               read(2) must be clearing errno or something.

  # sysread() returned 0, signifying EOF.  Although $! is magically
  # set to 0 on EOF, it may not be portable to rely on this.
  if (defined $result) {
    $! = 0;
    return undef;
  }

  # Nonfatal sysread() error.  Return an empty list.
  return [ ] if $! == EAGAIN or $! == EWOULDBLOCK;

  # In perl 5.005_04 on FreeBSD, $! is not set properly unless this
  # silly no-op is executed.  Turn off warnings in case $result isn't
  # defined.  TODO - Make it optimizable at compile time.
  local $^W = 0;
  $result = "$result";

  # fatal sysread error
  undef;
}

#------------------------------------------------------------------------------

sub flush {
  my ($self, $handle) = @_;

  # Need to check lengths in octets, not characters.
  BEGIN { eval { require bytes } and bytes->import; }

  # syswrite() it, like we're supposed to
  while (@{$self->[OUTPUT_QUEUE]}) {
    my $wrote_count = syswrite(
      $handle,
      $self->[OUTPUT_QUEUE]->[0],
      $self->[CURRENT_OCTETS_LEFT],
      $self->[CURRENT_OCTETS_DONE],
    );

    # Errors only count if syswrite() failed.
    $! = 0 if defined $wrote_count;

    unless ($wrote_count) {
      $! = 0 if $! == EAGAIN or $! == EWOULDBLOCK;
      last;
    }

    $self->[CURRENT_OCTETS_DONE] += $wrote_count;
    $self->[TOTAL_OCTETS_LEFT] -= $wrote_count;
    unless ($self->[CURRENT_OCTETS_LEFT] -= $wrote_count) {
      shift(@{$self->[OUTPUT_QUEUE]});
      if (@{$self->[OUTPUT_QUEUE]}) {
        $self->[CURRENT_OCTETS_DONE] = 0;
        $self->[CURRENT_OCTETS_LEFT] = length($self->[OUTPUT_QUEUE]->[0]);
      }
      else {
        $self->[CURRENT_OCTETS_DONE] = $self->[CURRENT_OCTETS_LEFT] = 0;
      }
    }
  }

  $self->[TOTAL_OCTETS_LEFT];
}

#------------------------------------------------------------------------------

sub get_out_messages_buffered {
  scalar(@{$_[0]->[OUTPUT_QUEUE]});
}

1;

__END__

=head1 NAME

POE::Driver::SysRW - buffered, non-blocking I/O using sysread and syswrite

=head1 SYNOPSIS

L<POE::Driver/SYNOPSIS> illustrates how the interface works.  This
module is merely one implementation.

=head1 DESCRIPTION

This driver implements L<POE::Driver> using sysread and syswrite.

=head1 PUBLIC METHODS

POE::Driver::SysRW introduces some additional features not covered in
the base interface.

=head2 new [BlockSize => OCTETS]

new() creates a new buffered I/O driver that uses sysread() to read
data from a handle and syswrite() to flush data to that handle.  The
constructor accepts one optional named parameter, C<BlockSize>, which
indicates the maximum number of OCTETS that will be read at one time.

C<BlockSize> is 64 kilobytes (65536 octets) by default.  Higher values
may improve performance in streaming applications, but the trade-off
is a lower event granularity and increased resident memory usage.

Lower C<BlockSize> values reduce memory consumption somewhat with
corresponding throughput penalties.

  my $driver = POE::Driver::SysRW->new;

  my $driver = POE::Driver::SysRW->new( BlockSize => $block_size );

Drivers are commonly instantiated within POE::Wheel constructor calls:

  $_[HEAP]{wheel} = POE::Wheel::ReadWrite->new(
    InputHandle => \*STDIN,
    OutputHandle => \*STDOUT,
    Driver => POE::Driver::SysRW->new(),
    Filter => POE::Filter::Line->new(),
  );

Applications almost always use POE::Driver::SysRW, so POE::Wheel
objects almost always will create their own if no Driver is specified.

=head2 All Other Methods

POE::Driver::SysRW documents the abstract interface documented in
POE::Driver.  Please see L<POE::Driver> for more details about the
following methods:

=over 4

=item flush

=item get

=item get_out_messages_buffered

=item put

=back

=head1 SEE ALSO

L<POE::Driver>, L<POE::Wheel>.

Also see the SEE ALSO section of L<POE>, which contains a brief
roadmap of POE's documentation.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
