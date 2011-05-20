package POE::Filter::Stream;

use strict;
use POE::Filter;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Filter);

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  my $buffer = '';
  my $self = bless \$buffer, $type;
  $self;
}

sub clone {
  my $self = shift;
  my $buffer = '';
  my $clone = bless \$buffer, ref $self;
}

#------------------------------------------------------------------------------
# get() is inherited from POE::Filter.

#------------------------------------------------------------------------------
# 2001-07-27 RCC: The get_one() variant of get() allows Wheel::Xyz to
# retrieve one filtered block at a time.  This is necessary for filter
# changing and proper input flow control.  Although it's kind of
# pointless for Stream, but it has to follow the proper interface.

sub get_one_start {
  my ($self, $stream) = @_;
  $$self .= join '', @$stream;
}

sub get_one {
  my $self = shift;
  return [ ] unless length $$self;
  my $chunk = $$self;
  $$self = '';
  return [ $chunk ];
}

#------------------------------------------------------------------------------

sub put {
  my ($self, $chunks) = @_;
  [ @$chunks ];
}

#------------------------------------------------------------------------------

sub get_pending {
  my $self = shift;
  return [ $$self ] if length $$self;
  return undef;
}

1;

__END__

=head1 NAME

POE::Filter::Stream - a no-op filter that passes data through unchanged

=head1 SYNOPSIS

  #!perl

  use Term::ReadKey;
  use POE qw(Wheel::ReadWrite Filter::Stream);

  POE::Session->create(
    inline_states => {
      _start => sub {
        ReadMode "ultra-raw";
        $_[HEAP]{io} = POE::Wheel::ReadWrite->new(
          InputHandle => \*STDIN,
          OutputHandle => \*STDOUT,
          InputEvent => "got_some_data",
          Filter => POE::Filter::Stream->new(),
        );
      },
      got_some_data => sub {
        $_[HEAP]{io}->put("<$_[ARG0]>");
        delete $_[HEAP]{io} if $_[ARG0] eq "\cC";
      },
      _stop => sub {
        ReadMode "restore";
        print "\n";
      },
    }
  );

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE::Filter::Stream passes data through without changing it.  It
follows POE::Filter's API and implements no new functionality.

In the L</SYNOPSIS>, POE::Filter::Stream is used to collect keystrokes
without any interpretation and display output without any
embellishments.

=head1 SEE ALSO

L<POE::Filter> for more information about filters in general.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

None known.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
