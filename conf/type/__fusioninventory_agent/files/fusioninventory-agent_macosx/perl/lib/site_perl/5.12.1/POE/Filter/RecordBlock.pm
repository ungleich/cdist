# 2001/01/25 shizukesa@pobox.com

package POE::Filter::RecordBlock;

use strict;
use POE::Filter;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Filter);

use Carp qw(croak);

sub BLOCKSIZE () { 0 };
sub GETBUFFER () { 1 };
sub PUTBUFFER () { 2 };
sub CHECKPUT  () { 3 };

#------------------------------------------------------------------------------

sub new {
  my $type = shift;

  croak "$type must be given an even number of parameters" if @_ & 1;
  my %params = @_;

  croak "BlockSize must be greater than 0" unless (
    defined($params{BlockSize}) && ($params{BlockSize} > 0)
  );

  my $self = bless [
    $params{BlockSize}, # BLOCKSIZE
    [],                 # GETBUFFER
    [],                 # PUTBUFFER
    $params{CheckPut},  # CHECKPUT
  ], $type;
}

sub clone {
  my $self = shift;
  my $clone = bless [
    $self->[0], # BLOCKSIZE
    [],         # GETBUFFER
    [],         # PUTBUFFER
    $self->[3], # CHECKPUT
  ], ref $self;
  $clone;
}

#------------------------------------------------------------------------------
# get() is inherited from POE::Filter.

#------------------------------------------------------------------------------
# 2001-07-27 RCC: Add get_one_start() and get_one() to correct filter
# changing and make input flow control possible.

sub get_one_start {
  my ($self, $data) = @_;
  push @{$self->[GETBUFFER]}, @$data;
}

sub get_one {
  my $self = shift;

  return [ ] unless @{$self->[GETBUFFER]} >= $self->[BLOCKSIZE];
  return [ [ splice @{$self->[GETBUFFER]}, 0, $self->[BLOCKSIZE] ] ];
}

#------------------------------------------------------------------------------

sub put {
  my ($self, $data) = @_;
  my @result;

  if ($self->[CHECKPUT]) {
    foreach (@$data) {
      push @{$self->[PUTBUFFER]}, @$_;
    }
    while (@{$self->[PUTBUFFER]} >= $self->[BLOCKSIZE]) {
      push @result, splice @{$self->[PUTBUFFER]}, 0, $self->[BLOCKSIZE];
    }
  }
  else {
    push @result, splice(@{$self->[PUTBUFFER]}, 0);
    foreach (@$data) {
      push @result, @$_;
    }
  }
  \@result;
}

#------------------------------------------------------------------------------

sub get_pending {
  my $self = shift;
  return undef unless @{$self->[GETBUFFER]};
  return [ @{$self->[GETBUFFER]} ];
}

#------------------------------------------------------------------------------

sub put_pending {
  my ($self) = @_;
  return undef unless $self->[CHECKPUT];
  return undef unless @{$self->[PUTBUFFER]};
  return [ @{$self->[PUTBUFFER]} ];
}

#------------------------------------------------------------------------------

sub blocksize {
  my ($self, $size) = @_;
  if (defined($size) && ($size > 0)) {
    $self->[BLOCKSIZE] = $size;
  }
  $self->[BLOCKSIZE];
}

#------------------------------------------------------------------------------

sub checkput {
  my ($self, $val) = @_;
  if (defined($val)) {
    $self->[CHECKPUT] = $val;
  }
  $self->[CHECKPUT];
}

1;

__END__

=head1 NAME

POE::Filter::RecordBlock - translate between discrete records and blocks of them

=head1 SYNOPSIS

Hello, dear reader.  This SYNOPSIS does not contain a fully
functioning sample program because your humble documenter cannot come
up with a short, reasonable use case for this module.  Please contact
the maintainer if this module is useful to you.  Otherwise you may wake
up one morning to discover that it has been deprecated.

  $filter = new POE::Filter::RecordBlock( BlockSize => 4 );
  $arrayref_of_arrayrefs = $filter->get($arrayref_of_raw_data);
  $arrayref_of_raw_chunks = $filter->put($arrayref_of_arrayrefs);
  $arrayref_of_raw_chunks = $filter->put($single_arrayref);
  $arrayref_of_leftovers = $filter->get_pending;
  $arrayref_of_leftovers = $filter->put_pending;

=head1 DESCRIPTION

On input, POE::Filter::RecordBlock translates a stream of discrete
items into a "block" of them.  It does this by collecting items until
it has BlockSize of them, then returning the lot of them in an array
reference.

On output, this module flattens array references.

This module may be deprecated in the future.  Please contact the
maintainer if this module is useful to you.

=head1 PUBLIC FILTER METHODS

In addition to the usual POE::Filter methods, POE::Filter::RecordBlock
supports the following.

=head2 new

new() takes at least one mandatory argument, BlockSize, which must be
defined and greater than zero.  new() also accepts a CheckPut Boolean
parameter that indicates whether put() should check for the proper
BlockSize before allowing data to be serialized.

Using CheckPut is not recommended, as it enables a write buffer in the
filter, therefore breaking put() for normal use.

=head2 put_pending

put_pending() returns an arrayref of any records that are waiting to
be sent.  It is the outbound equivalent of POE::Filter's get_pending()
accessor.  put_pending() is not part of the canonical POE::Filter API,
so nothing will use it.  It's up to applications to handle pending
output, whenever it's appropriate to do so.

=head2 blocksize

blocksize() is an accessor/mutator for POE::Filter::RecordBlock's
BlockSize value.

=head2 checkput

checkput() is an accessor/mutator for POE::Filter::RecordBlock's
CheckPut flag.

=head1 SEE ALSO

L<POE::Filter> for more information about filters in general.

L<POE::Filter::Stackable> for more details on stacking filters.

=head1 BUGS

This filter may maintain an output buffer that no other part of POE
will know about.

This filter implements a highly specialized and seemingly not
generally useful feature.

Does anyone use this filter?  This filter may be deprecated if nobody
speaks up.

=head1 AUTHORS & COPYRIGHTS

The RecordBlock filter was contributed by Dieter Pearcey.
Documentation is provided by Rocco Caputo.

Please see the L<POE> manpage for more information about authors and
contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
