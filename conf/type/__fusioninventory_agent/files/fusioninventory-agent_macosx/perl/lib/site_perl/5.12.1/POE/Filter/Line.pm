package POE::Filter::Line;

use strict;
use POE::Filter;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Filter);

use Carp qw(carp croak);

sub DEBUG () { 0 }

sub FRAMING_BUFFER   () { 0 }
sub INPUT_REGEXP     () { 1 }
sub OUTPUT_LITERAL   () { 2 }
sub AUTODETECT_STATE () { 3 }

sub AUTO_STATE_DONE   () { 0x00 }
sub AUTO_STATE_FIRST  () { 0x01 }
sub AUTO_STATE_SECOND () { 0x02 }

#------------------------------------------------------------------------------

sub new {
  my $type = shift;

  croak "$type requires an even number of parameters" if @_ and @_ & 1;
  my %params = @_;

  croak "$type cannot have both Regexp and Literal line endings" if (
    defined $params{Regexp} and defined $params{Literal}
  );

  my ($input_regexp, $output_literal);
  my $autodetect = AUTO_STATE_DONE;

  # Literal newline for both incoming and outgoing.  Every other known
  # parameter conflicts with this one.
  if (defined $params{Literal}) {
    croak "A defined Literal must have a nonzero length"
      unless defined($params{Literal}) and length($params{Literal});
    $input_regexp   = quotemeta $params{Literal};
    $output_literal = $params{Literal};
    if (
      exists $params{InputLiteral} or # undef means something
      defined $params{InputRegexp} or
      defined $params{OutputLiteral}
    ) {
      croak "$type cannot have Literal with any other parameter";
    }
  }

  # Input and output are specified separately, then.
  else {

    # Input can be either a literal or a regexp.  The regexp may be
    # compiled or not; we don't rightly care at this point.
    if (exists $params{InputLiteral}) {
      $input_regexp = $params{InputLiteral};

      # InputLiteral is defined.  Turn it into a regexp and be done.
      # Otherwise we will autodetect it.
      if (defined($input_regexp) and length($input_regexp)) {
        $input_regexp = quotemeta $input_regexp;
      }
      else {
        $autodetect   = AUTO_STATE_FIRST;
        $input_regexp = '';
      }

      croak "$type cannot have both InputLiteral and InputRegexp"
        if defined $params{InputRegexp};
    }
    elsif (defined $params{InputRegexp}) {
      $input_regexp = $params{InputRegexp};
      croak "$type cannot have both InputLiteral and InputRegexp"
        if defined $params{InputLiteral};
    }
    else {
      $input_regexp = "(\\x0D\\x0A?|\\x0A\\x0D?)";
    }

    if (defined $params{OutputLiteral}) {
      $output_literal = $params{OutputLiteral};
    }
    else {
      $output_literal = "\x0D\x0A";
    }
  }

  delete @params{qw(Literal InputLiteral OutputLiteral InputRegexp)};
  carp("$type ignores unknown parameters: ", join(', ', sort keys %params))
    if scalar keys %params;

  my $self = bless [
    '',              # FRAMING_BUFFER
    $input_regexp,   # INPUT_REGEXP
    $output_literal, # OUTPUT_LITERAL
    $autodetect,     # AUTODETECT_STATE
  ], $type;

  DEBUG and warn join ':', @$self;

  $self;
}


#------------------------------------------------------------------------------
# get() is inherited from POE::Filter.

#------------------------------------------------------------------------------
# 2001-07-27 RCC: Add get_one_start() and get_one() to correct filter
# changing and make input flow control possible.

sub get_one_start {
  my ($self, $stream) = @_;

  DEBUG and do {
    my $temp = join '', @$stream;
    $temp = unpack 'H*', $temp;
    warn "got some raw data: $temp\n";
  };

  $self->[FRAMING_BUFFER] .= join '', @$stream;
}

# TODO There is a lot of code duplicated here.  What can be done?

sub get_one {
  my $self = shift;

  # Process as many newlines an we can find.
  LINE: while (1) {

    # Autodetect is done, or it never started.  Parse some buffer!
    unless ($self->[AUTODETECT_STATE]) {
      DEBUG and warn unpack 'H*', $self->[INPUT_REGEXP];
      last LINE
        unless $self->[FRAMING_BUFFER] =~ s/^(.*?)$self->[INPUT_REGEXP]//s;
      DEBUG and warn "got line: <<", unpack('H*', $1), ">>\n";

      return [ $1 ];
    }

    # Waiting for the first line ending.  Look for a generic newline.
    if ($self->[AUTODETECT_STATE] & AUTO_STATE_FIRST) {
      last LINE
        unless $self->[FRAMING_BUFFER] =~ s/^(.*?)(\x0D\x0A?|\x0A\x0D?)//;

      my $line = $1;

      # The newline can be complete under two conditions.  First: If
      # it's two characters.  Second: If there's more data in the
      # framing buffer.  Loop around in case there are more lines.
      if ( (length($2) == 2) or
           (length $self->[FRAMING_BUFFER])
         ) {
        DEBUG and warn "detected complete newline after line: <<$1>>\n";
        $self->[INPUT_REGEXP] = $2;
        $self->[AUTODETECT_STATE] = AUTO_STATE_DONE;
      }

      # The regexp has matched a potential partial newline.  Save it,
      # and move to the next state.  There is no more data in the
      # framing buffer, so we're done.
      else {
        DEBUG and warn "detected suspicious newline after line: <<$1>>\n";
        $self->[INPUT_REGEXP] = $2;
        $self->[AUTODETECT_STATE] = AUTO_STATE_SECOND;
      }

      return [ $line ];
    }

    # Waiting for the second line beginning.  Bail out if we don't
    # have anything in the framing buffer.
    if ($self->[AUTODETECT_STATE] & AUTO_STATE_SECOND) {
      return [ ] unless length $self->[FRAMING_BUFFER];

      # Test the first character to see if it completes the previous
      # potentially partial newline.
      if (
        substr($self->[FRAMING_BUFFER], 0, 1) eq
        ( $self->[INPUT_REGEXP] eq "\x0D" ? "\x0A" : "\x0D" )
      ) {

        # Combine the first character with the previous newline, and
        # discard the newline from the buffer.  This is two statements
        # for backward compatibility.
        DEBUG and warn "completed newline after line: <<$1>>\n";
        $self->[INPUT_REGEXP] .= substr($self->[FRAMING_BUFFER], 0, 1);
        substr($self->[FRAMING_BUFFER], 0, 1) = '';
      }
      elsif (DEBUG) {
        warn "decided prior suspicious newline is okay\n";
      }

      # Regardless, whatever is in INPUT_REGEXP is now a complete
      # newline.  End autodetection, post-process the found newline,
      # and loop to see if there are other lines in the buffer.
      $self->[INPUT_REGEXP] = $self->[INPUT_REGEXP];
      $self->[AUTODETECT_STATE] = AUTO_STATE_DONE;
      next LINE;
    }

    die "consistency error: AUTODETECT_STATE = $self->[AUTODETECT_STATE]";
  }

  return [ ];
}

#------------------------------------------------------------------------------
# New behavior.  First translate system newlines ("\n") into whichever
# newlines are supposed to be sent.  Second, add a trailing newline if
# one doesn't already exist.  Since the referenced output list is
# supposed to contain one line per element, we also do a split and
# join.  Bleah. ... why isn't the code doing what the comment says?

sub put {
  my ($self, $lines) = @_;

  my @raw;
  foreach (@$lines) {
    push @raw, $_ . $self->[OUTPUT_LITERAL];
  }

  \@raw;
}

#------------------------------------------------------------------------------

sub get_pending {
  my $self = shift;
  return [ $self->[FRAMING_BUFFER] ] if length $self->[FRAMING_BUFFER];
  return undef;
}

1;

__END__

=head1 NAME

POE::Filter::Line - serialize and parse terminated records (lines)

=head1 SYNOPSIS

  #!perl

  use POE qw(Wheel::FollowTail Filter::Line);

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
          Filename => "/var/log/system.log",
          InputEvent => "got_log_line",
          Filter => POE::Filter::Line->new(),
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

POE::Filter::Line parses stream data into terminated records.  The
default parser interprets newlines as the record terminator, and the
default serializer appends network newlines (CR/LF, or "\x0D\x0A") to
outbound records.

Record terminators are removed from the data POE::Filter::Line
returns.

POE::Filter::Line supports a number of other ways to parse lines.
Constructor parameters may specify literal newlines, regular
expressions, or that the filter should detect newlines on its own.

=head1 PUBLIC FILTER METHODS

POE::Filter::Line's new() method has some interesting parameters.

=head2 new

new() accepts a list of named parameters.

In all cases, the data interpreted as the record terminator is
stripped from the data POE::Filter::Line returns.

C<InputLiteral> may be used to parse records that are terminated by
some literal string.  For example, POE::Filter::Line may be used to
parse and emit C-style lines, which are terminated with an ASCII NUL:

  my $c_line_filter = POE::Filter::Line->new(
    InputLiteral => chr(0),
    OutputLiteral => chr(0),
  );

C<OutputLiteral> allows a filter to put() records with a different
record terminator than it parses.  This can be useful in applications
that must translate record terminators.

C<Literal> is a shorthand for the common case where the input and
output literals are identical.  The previous example may be written
as:

  my $c_line_filter = POE::Filter::Line->new(
    Literal => chr(0),
  );

An application can also allow POE::Filter::Line to figure out which
newline to use.  This is done by specifying C<InputLiteral> to be
undef:

  my $whichever_line_filter = POE::Filter::Line->new(
    InputLiteral => undef,
    OutputLiteral => "\n",
  );

C<InputRegexp> may be used in place of C<InputLiteral> to recognize
line terminators based on a regular expression.  In this example,
input is terminated by two or more consecutive newlines.  On output,
the paragraph separator is "---" on a line by itself.

  my $paragraph_filter = POE::Filter::Line->new(
    InputRegexp => "([\x0D\x0A]{2,})",
    OutputLiteral => "\n---\n",
  );

=head1 PUBLIC FILTER METHODS

POE::Filter::Line has no additional public methods.

=head1 SEE ALSO

Please see L<POE::Filter> for documentation regarding the base
interface.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

The default input newline parser is a regexp that has an unfortunate
race condition.  First the regular expression:

  /(\x0D\x0A?|\x0A\x0D?)/

While it quickly recognizes most forms of newline, it can sometimes
detect an extra blank line.  This happens when a two-byte newline
character is broken between two reads.  Consider this situation:

  some stream dataCR
  LFother stream data

The regular expression will see the first CR without its corresponding
LF.  The filter will properly return "some stream data" as a line.
When the next packet arrives, the leading "LF" will be treated as the
terminator for a 0-byte line.  The filter will faithfully return this
empty line.

B<It is advised to specify literal newlines or use the autodetect
feature in applications where blank lines are significant.>

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
