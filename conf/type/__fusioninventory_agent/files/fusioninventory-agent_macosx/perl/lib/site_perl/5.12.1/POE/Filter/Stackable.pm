# 2001/01/25 shizukesa@pobox.com

# This implements a filter stack, which turns ReadWrite into something
# very, very interesting.

# 2001-07-26 RCC: I have no idea how to make this support get_one, so
# I'm not going to right now.

package POE::Filter::Stackable;

use strict;
use POE::Filter;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Filter);

use Carp qw(croak);

sub FILTERS () { 0 }

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  croak "$type must be given an even number of parameters" if @_ & 1;
  my %params = @_;

  $params{Filters} = [ ] unless defined $params{Filters};
  # Sanity check the filters
  if ( ref $params{Filters} eq 'ARRAY') {

    my $self = bless [
      $params{Filters}, # FILTERS
    ], $type;

    return $self;
  } else {
    croak "Filters is not an ARRAY reference!";
  }
}

sub clone {
  my $self = shift;
  my $clone = bless [
    [ ],    # FILTERS
  ], ref $self;
  foreach my $filter (@{$self->[FILTERS]}) {
    push (@{$clone->[FILTERS]}, $filter->clone());
  }
  $clone;
}

#------------------------------------------------------------------------------

sub get_one_start {
  my ($self, $data) = @_;
  $self->[FILTERS]->[0]->get_one_start($data);
}

# RCC 2005-06-28: get_one() needs to strobe through all the filters
# regardless whether there's data to input to each.  This is because a
# later filter in the chain may produce multiple things from one piece
# of input.  If we stop even though there's no subsequent input, we
# may lose something.
#
# Keep looping through the filters we manage until get_one() returns a
# record, or until none of the filters exchange data.

sub get_one {
  my ($self) = @_;

  my $return = [ ];

  while (!@$return) {
    my $exchanged = 0;

    foreach my $filter (@{$self->[FILTERS]}) {

      # If we have something to input to the next filter, do that.
      if (@$return) {
        $filter->get_one_start($return);
        $exchanged++;
      }

      # Get what we can from the current filter.
      $return = $filter->get_one();
    }

    last unless $exchanged;
  }

  return $return;
}

# get() is inherited from POE::Filter.

#------------------------------------------------------------------------------

sub put {
  my ($self, $data) = @_;
  foreach my $filter (reverse @{$self->[FILTERS]}) {
    $data = $filter->put($data);
    last unless @$data;
  }
  $data;
}

#------------------------------------------------------------------------------

sub get_pending {
  my ($self) = @_;
  my $data;
  for (@{$self->[FILTERS]}) {
    $_->put($data) if $data && @{$data};
    $data = $_->get_pending;
  }
  $data || [];
}

#------------------------------------------------------------------------------

sub filter_types {
   map { ref($_) } @{$_[0]->[FILTERS]};
}

#------------------------------------------------------------------------------

sub filters {
  @{$_[0]->[FILTERS]};
}

#------------------------------------------------------------------------------

sub shift {
  my ($self) = @_;
  my $filter = shift @{$self->[FILTERS]};
  my $pending = $filter->get_pending;
  $self->[FILTERS]->[0]->put( $pending ) if $pending;
  $filter;
}

#------------------------------------------------------------------------------

sub unshift {
  my ($self, @filters) = @_;

  # Sanity check
  foreach my $elem ( @filters ) {
    if ( ! defined $elem or ! UNIVERSAL::isa( $elem, 'POE::Filter' ) ) {
      croak "Filter element is not a POE::Filter instance!";
    }
  }

  unshift(@{$self->[FILTERS]}, @filters);
}

#------------------------------------------------------------------------------

sub push {
  my ($self, @filters) = @_;

  # Sanity check
  foreach my $elem ( @filters ) {
    if ( ! defined $elem or ! UNIVERSAL::isa( $elem, 'POE::Filter' ) ) {
      croak "Filter element is not a POE::Filter instance!";
    }
  }

  push(@{$self->[FILTERS]}, @filters);
}

#------------------------------------------------------------------------------

sub pop {
  my ($self) = @_;
  my $filter = pop @{$self->[FILTERS]};
  my $pending = $filter->get_pending;
  $self->[FILTERS]->[-1]->put( $pending ) if $pending;
  $filter;
}

1;

__END__

=head1 NAME

POE::Filter::Stackable - combine multiple POE::Filter objects

=head1 SYNOPSIS

  #!perl

  use POE qw(
    Wheel::FollowTail
    Filter::Line Filter::Grep Filter::Stackable
  );

  POE::Session->create(
    inline_states => {
      _start => sub {
        my $parse_input_as_lines = POE::Filter::Line->new();

        my $select_sudo_log_lines = POE::Filter::Grep->new(
          Put => sub { 1 },
          Get => sub {
            my $input = shift;
            return $input =~ /sudo\[\d+\]/i;
          },
        );

        my $filter_stack = POE::Filter::Stackable->new(
          Filters => [
            $parse_input_as_lines, # first on get, last on put
            $select_sudo_log_lines, # first on put, last on get
          ]
        );

        $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
          Filename => "/var/log/system.log",
          InputEvent => "got_log_line",
          Filter => $filter_stack,
        );
      },
      got_log_line => sub {
        print "Log: $_[ARG0]\n";
      }
    }
  );

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE::Filter::Stackable combines multiple filters together in such a
way that they appear to be a single filter.  All the usual POE::Filter
methods work, but data is secretly passed through the stacked filters
before it is returned.  POE::Wheel objects and stand-alone programs
need no modifications to work with a filter stack.

In the L</SYNOPSIS>, POE::Filter::Line and POE::Filter::Grep are
combined into one filter that only returns a particular kind of line.
This can be more efficient than filtering lines in application space,
as fewer events may need to be dispatched and handled.

Internally, filters are stored in an array.

Data added by get_one_start() will flow through the filter array in
increasing index order.  Filter #0 will have first crack at it,
followed by filter #1 and so.  The get_one() call will return an item
after it has passed through the last filter.

put() passes data through the filters in descending index order.  Data
will go through the filter with the highest index first, and put()
will return the results after data has passed through filter #0.

=head1 PUBLIC FILTER METHODS

In addition to the usual POE::Filter methods, POE::Filter::Stackable
also supports the following.

=head2 new

By default, new() creates an empty filter stack that behaves like
POE::Filter::Stream.  It may be given optional parameters to
initialize the stack with an array of filters.

  my $sudo_lines = POE::Filter::Stackable->new(
    Filters => [
      POE::Filter::Line->new(),
      POE::Filter::Grep->new(
        Put => sub { 1 }, # put all items
        Get => sub { shift() =~ /sudo\[\d+\]/i },
      ),
    ]
  );

=head2 pop

Behaves like Perl's built-in pop() for the filter stack.  The
highest-indexed filter is removed from the stack and returned.  Any
data remaining in the filter's input buffer is lost, but an
application may always call L<POE::Filter/get_pending> on the returned
filter.

  my $last_filter = $stackable->pop();
  my $last_buffer = $last_filter->get_pending();

=head2 shift

Behaves like Perl's built-in shift() for the filter stack.  The 0th
filter is removed from the stack and returned.  Any data remaining in
the filter's input buffer is passed to the new head of the stack, or
it is lost if the stack becomes empty.  An application may also call
L<POE::Filter/get_pending> on the returned filter to examine the
filter's input buffer.

  my $first_filter = $stackable->shift();
  my $first_buffer = $first_filter->get_pending();

=head2 push FILTER[, FILTER]

push() adds one or more new FILTERs to the end of the stack.  The
newly pushed FILTERs will process input last, and they will handle
output first.

  # Reverse data read through the stack.
  # rot13 encode data sent through the stack.
  $stackable->push(
    POE::Filter::Map->(
      Get => sub { return scalar reverse shift() },
      Put => sub { local $_ = shift(); tr[a-zA-Z][n-za-mN-ZA-M]; $_ },
    )
  );

=head2 unshift FILTER[, FILTER]

unshift() adds one or more new FILTERs to the beginning of the stack.
The newly unshifted FILTERs will process input first, and they will
handle output last.

=head2 filters

filters() returns a list of the filters inside the Stackable filter,
in the stack's native order.

Calling C<<$filter_stack->filters()>> in the L</SYNOPSIS> would return
a list of two filter objects:

  POE::Filter::Line=ARRAY(0x8b5ee0)
  POE::Filter::Grep=ARRAY(0x8b5f7c)

=head2 filter_types

filter_types() returns a list of class names for each filter in the
stack, in the stack's native order.

Calling C<<$filter_stack->filter_types()>> in the L</SYNOPSIS> would
return a list of two class names:

  POE::FIlter::Line
  POE::Filter::Grep

It could easily be replaced by:

  my @filter_types = map { ref } $filter_stack->filters;

=head1 SEE ALSO

L<POE::Filter> for more information about filters in general.

Specific filters, amongst which are:
L<POE::Filter::Block>,
L<POE::Filter::Grep>,
L<POE::Filter::HTTPD>,
L<POE::Filter::Line>,
L<POE::Filter::Map>,
L<POE::Filter::RecordBlock>,
L<POE::Filter::Reference>,
L<POE::Filter::Stream>

=head1 BUGS

None currently known.

=head1 AUTHORS & COPYRIGHTS

The Stackable filter was contributed by Dieter Pearcey.  Documentation
provided by Rocco Caputo.

Please see the L<POE> manpage for more information about authors and
contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
