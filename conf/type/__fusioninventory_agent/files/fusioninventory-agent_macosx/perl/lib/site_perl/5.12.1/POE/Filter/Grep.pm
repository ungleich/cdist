# 2001/01/25 shizukesa@pobox.com

package POE::Filter::Grep;

use strict;
use POE::Filter;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Filter);

use Carp qw(croak carp);

sub BUFFER   () { 0 }
sub CODEGET  () { 1 }
sub CODEPUT  () { 2 }

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  croak "$type must be given an even number of parameters" if @_ & 1;
  my %params = @_;

  croak "$type requires a Code or both Get and Put parameters" unless (
    defined($params{Code}) or
    (defined($params{Get}) and defined($params{Put}))
  );
  croak "Code element is not a subref"
    unless (defined $params{Code} ? ref $params{Code} eq 'CODE' : 1);
  croak "Get or Put element is not a subref"
    unless ((defined $params{Get} ? (ref $params{Get} eq 'CODE') : 1)
      and   (defined $params{Put} ? (ref $params{Put} eq 'CODE') : 1));

  my $self = bless [
    [ ],           # BUFFER
    $params{Code} || $params{Get},  # CODEGET
    $params{Code} || $params{Put},  # CODEPUT
  ], $type;
}

#------------------------------------------------------------------------------
# get() is inherited from POE::Filter.

#------------------------------------------------------------------------------
# 2001-07-27 RCC: The get_one variant of get() allows Wheel::Xyz to
# retrieve one filtered record at a time.  This is necessary for
# filter changing and proper input flow control.

sub get_one_start {
  my ($self, $stream) = @_;
  push( @{$self->[BUFFER]}, @$stream ) if defined $stream;
}

sub get_one {
  my $self = shift;

  # Must be a loop so that the buffer will be altered as items are
  # tested.
  while (@{$self->[BUFFER]}) {
    my $next_record = shift @{$self->[BUFFER]};
    return [ $next_record ] if (
      grep { $self->[CODEGET]->($_) } $next_record
    );
  }

  return [ ];
}

#------------------------------------------------------------------------------

sub put {
  my ($self, $data) = @_;
  [ grep { $self->[CODEPUT]->($_) } @$data ];
}

#------------------------------------------------------------------------------
# 2001-07-27 RCC: This filter now tracks state, so get_pending has
# become useful.

sub get_pending {
  my $self = shift;
  return undef unless @{$self->[BUFFER]};
  [ @{$self->[BUFFER]} ];
}

#------------------------------------------------------------------------------

sub modify {
  my ($self, %params) = @_;

  for (keys %params) {
    (carp("Modify $_ element must be given a coderef") and next) unless (ref $params{$_} eq 'CODE');
    if (lc eq 'code') {
        $self->[CODEGET] = $params{$_};
        $self->[CODEPUT] = $params{$_};
    }
    elsif (lc eq 'put') {
        $self->[CODEPUT] = $params{$_};
    }
    elsif (lc eq 'get') {
        $self->[CODEGET] = $params{$_};
    }
  }
}

1;

__END__

=head1 NAME

POE::Filter::Grep - select or remove items based on simple rules

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

POE::Filter::Grep selects or removes items based on simple tests.  It
may be used to filter input, output, or both.  This filter is named
and modeled after Perl's built-in grep() function.

POE::Filter::Grep is designed to be combined with other filters
through POE::Filter::Stackable.  In the L</SYNOPSIS> example, a filter
stack is created to parse logs as lines and remove all entries that
don't pertain to a sudo process.  (Or if your glass is half full, the
stack only selects entries that DO mention sudo.)

=head1 PUBLIC FILTER METHODS

In addition to the usual POE::Filter methods, POE::Filter::Grep also
supports the following.

=head2 new

new() constructs a new POE::Filter::Grep object.  It must either be
called with a single Code parameter, or both a Put and a Get
parameter.  The values for Code, Put, and Get are code references
that, when invoked, return true to select an item or false to reject
it.  A Code function will be used for both input and output, while Get
and Put functions allow input and output to be filtered in different
ways.  The item in question will be passed as the function's sole
parameter.

  sub reject_bidoofs {
    my $pokemon = shift;
    return 1 if $pokemon ne "bidoof";
    return;
  }

  my $gotta_catch_nearly_all = POE::Filter::Grep->new(
    Code => \&reject_bidoofs,
  );

Enforce read-only behavior:

  my $read_only = POE::Filter::Grep->new(
    Get => sub { 1 },
    Put => sub { 0 },
  );

=head2 modify

modify() changes a POE::Filter::Grep object's behavior at run-time.
It accepts the same parameters as new(), and it replaces the existing
tests with new ones.

  # Don't give away our Dialgas.
  $gotta_catch_nearly_all->modify(
    Get => sub { 1 },
    Put => sub { return shift() ne "dialga" },
  );

=head1 SEE ALSO

L<POE::Filter> for more information about filters in general.

L<POE::Filter::Stackable> for more details on stacking filters.

=head1 BUGS

None known.

=head1 AUTHORS & COPYRIGHTS

The Grep filter was contributed by Dieter Pearcey.  Documentation is
provided by Rocco Caputo.

Please see the L<POE> manpage for more information about authors and
contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
