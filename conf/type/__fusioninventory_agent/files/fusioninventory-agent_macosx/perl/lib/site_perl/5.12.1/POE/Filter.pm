package POE::Filter;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw(croak);

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  croak "$type is not meant to be used directly";
}

# Return all the messages possible to parse in the current input
# buffer.  This uses the newer get_one_start() and get_one(), which is
# implementation dependent.

sub get {
  my ($self, $stream) = @_;
  my @return;

  $self->get_one_start($stream);
  while (1) {
    my $next = $self->get_one();
    last unless @$next;
    push @return, @$next;
  }

  return \@return;
}

sub clone {
  my $self = shift;
  my $buf = (ref($self->[0]) eq 'ARRAY') ? [ ] : '';
  my $nself = bless [
    $buf,                     # BUFFER
    @$self[1..$#$self],  # everything else
  ], ref $self;
  return $nself;
}

1;

__END__

=head1 NAME

POE::Filter - protocol abstractions for POE::Wheel and standalone use

=head1 SYNOPSIS

To use with POE::Wheel classes, pass a POE::Filter object to one of
the "...Filter" constructor parameters:

  #!perl

  use POE qw(Filter::Line Wheel::FollowTail);

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

Standalone use without POE:

  #!perl

  use warnings;
  use strict;
  use POE::Filter::Line;

  my $filter = POE::Filter::Line->new( Literal => "\n" );

  # Prints three lines: one, two three.

  $filter->get_one_start(["one\ntwo\nthr", "ee\nfour"]);
  while (1) {
    my $line = $filter->get_one();
    last unless @$line;
    print $line->[0], "\n";
  }

  # Prints two lines: four, five.

  $filter->get_one_start(["\nfive\n"]);
  while (1) {
    my $line = $filter->get_one();
    last unless @$line;
    print $line->[0], "\n";
  }

=head1 DESCRIPTION

POE::Filter objects plug into the wheels and define how the data will
be serialized for writing and parsed after reading.  POE::Wheel
objects are responsible for moving data, and POE::Filter objects
define how the data should look.

POE::Filter objects are simple by design.  They do not use POE
internally, so they are limited to serialization and parsing.  This
may complicate implementation of certain protocols (like HTTP 1.x),
but it allows filters to be used in stand-alone programs.

Stand-alone use is very important.  It allows application developers
to create lightweight blocking libraries that may be used as simple
clients for POE servers.  POE::Component::IKC::ClientLite is a notable
example.  This lightweight, blocking event-passing client supports
thin clients for gridded POE applications.  The canonical use case is
to inject events into an IKC application or grid from CGI interfaces,
which require lightweight resource use.

POE filters and drivers pass data in array references.  This is
slightly awkward, but it minimizes the amount of data that must be
copied on Perl's stack.

=head1 PUBLIC INTERFACE

All POE::Filter classes must support the minimal interface, defined
here.  Specific filters may implement and document additional methods.

=head2 new PARAMETERS

new() creates and initializes a new filter.  Constructor parameters
vary from one POE::Filter subclass to the next, so please consult the
documentation for your desired filter.

=head2 clone

clone() creates and initializes a new filter based on the constructor
parameters of the existing one.  The new filter is a near-identical
copy, except that its buffers are empty.

Certain components, such as POE::Component::Server::TCP, use clone().
These components accept a master or template filter at creation time,
then clone() that filter for each new connection.

  my $new_filter = $old_filter->clone();

=head2 get_one_start ARRAYREF

get_one_start() accepts an array reference containing unprocessed
stream chunks.  The chunks are added to the filter's internal buffer
for parsing by get_one().

The L</SYNOPSIS> shows get_one_start() in use.

=head2 get_one

get_one() parses zero or one complete item from the filter's internal
buffer.  The data is returned as an ARRAYREF suitable for passing to
another filter or a POE::Wheel object.  Filters will return empty
ARRAYREFs if they don't have enough raw data to build a complete item.

get_one() is the lazy form of get().  It only parses only one item at
a time from the filter's buffer.  This is vital for applications that
may switch filters in mid-stream, as it ensures that the right filter
is in use at any given time.

The L</SYNOPSIS> shows get_one() in use.  Note how it assumes the
return is always an ARRAYREF, and it implicitly handles empty ones.

=head2 get ARRAYREF

get() is the greedy form of get_one().  It accepts an array reference
containing unprocessed stream chunks, and it adds that data to the
filter's internal buffer.  It then parses as many full items as
possible from the buffer and returns them in another array reference.
Any unprocessed data remains in the filter's buffer for the next call.

As with get_one(), get() will return an empty array reference if the
filter doesn't contain enough raw data to build a complete item.

In fact, get() is implemented in POE::Filter in terms of
get_one_start() and get_one().

Here's the get() form of the SYNOPSIS stand-alone example:

  #!perl

  use warnings;
  use strict;
  use POE::Filter::Line;

  my $filter = POE::Filter::Line->new( Literal => "\n" );

  # Prints three lines: one, two three.

  my $lines = $filter->get(["one\ntwo\nthr", "ee\nfour"]);
  foreach my $line (@$lines) {
    print "$line\n";
  }

  # Prints two lines: four, five.

  $lines = $filter->get(["\nfive\n"]);
  foreach my $line (@$lines) {
    print "$line\n";
  }

get() should not be used with wheels that support filter switching.
Its greedy nature means that it often parses streams well in advance
of a wheel's events.  By the time an application changes the wheel's
filter, it's too late: The old filter has already parsed the rest of
the received data.

Consider a stream of letters, numbers, and periods.  The periods
signal when to switch filters from one that parses letters to one that
parses numbers.

In our hypothetical application, letters must be handled one at a
time, but numbers may be handled in chunks.  We'll use
POE::Filter::Block with a BlockSize of 1 to parse letters, and
POE::FIlter::Line with a Literal terminator of "." to handle numbers.

Here's the sample stream:

  abcdefg.1234567.hijklmnop.890.q

We'll start with a ReadWrite wheel configured to parse characters.

  $_[HEAP]{wheel} = POE::Wheel::ReadWrite->new(
    Filter => POE::Filter::Block->new( BlockSize => 1 ),
    Handle => $socket,
    InputEvent => "got_letter",
  );

The "got_letter" handler will be called 8 times.  One for each letter
from a through g, and once for the period following g.  Upon receiving
the period, it will switch the wheel into number mode.

  sub handle_letter {
    my $letter = $_[ARG0];
    if ($letter eq ".") {
      $_[HEAP]{wheel}->set_filter(
        POE::Filter::Line->new( Literal => "." )
      );
      $_[HEAP]{wheel}->event( InputEvent => "got_number" );
    }
    else {
      print "Got letter: $letter\n";
    }
  }

If the greedy get() were used, the entire input stream would have been
parsed as characters in advance of the first handle_letter() call.
The set_filter() call would have been moot, since there would be no
data left to be parsed.

The "got_number" handler receives contiguous runs of digits as
period-terminated lines.  The greedy get() would cause a similar
problem as above.

  sub handle_numbers {
    my $numbers = $_[ARG0];
    print "Got number(s): $numbers\n";
    $_[HEAP]->{wheel}->set_filter(
      POE::Filter::Block->new( BlockSize => 1 )
    );
    $_[HEAP]->{wheel}->event( InputEvent => "got_letter" );
  }

So don't do it!

=head2 put ARRAYREF

put() serializes items into a stream of octets that may be written to
a file or sent across a socket.  It accepts a reference to a list of
items, and it returns a reference to a list of marshalled stream
chunks.  The number of output chunks is not necessarily related to the
number of input items.

In stand-alone use, put()'s output may be sent directly:

  my $line_filter = POE::Filter::Line->new();
  my $lines = $line_filter->put(\@list_of_things);
  foreach my $line (@$lines) {
    print $line;
  }

The list reference it returns may be passed directly to a driver or
filter.  Drivers and filters deliberately share the same put()
interface so that things like this are possible:

  $driver->put(
    $transfer_encoding_filter->put(
      $content_encoding_filter->put(
        \@items
      )
    )
  );

  1 while $driver->flush(\*STDOUT);

=head2 get_pending

get_pending() returns any data remaining in a filter's input buffer.
The filter's input buffer is not cleared, however.  get_pending()
returns a list reference if there's any data, or undef if the filter
was empty.

POE::Wheel objects use get_pending() during filter switching.
Unprocessed data is fetched from the old filter with get_pending() and
injected into the new filter with get_one_start().

  use POE::Filter::Line;
  use POE::Filter::Stream;

  my $line_filter = POE::Filter::Line->new();
  $line_filter->get_one_start([ "not a complete line" ]);

  my $stream_filter = POE::Filter::Stream->new();
  my $line_buffer = $line_filter->get_pending();
  $stream_filter->get_one_start($line_buffer) if $line_buffer;

  print "Stream: $_\n" foreach (@{ $stream_filter->get_one });

Full items are serialized whole, so there is no corresponding "put"
buffer or accessor.

=head1 SEE ALSO

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

POE is bundled with the following filters:

L<POE::Filter::Block>
L<POE::Filter::Grep>
L<POE::Filter::HTTPD>
L<POE::Filter::Line>
L<POE::Filter::Map>
L<POE::Filter::RecordBlock>
L<POE::Filter::Reference>
L<POE::Filter::Stackable>
L<POE::Filter::Stream>

=head1 BUGS

In theory, filters should be interchangeable.  In practice, stream and
block protocols tend to be incompatible.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
