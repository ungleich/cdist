package POE::Driver;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw(croak);

#------------------------------------------------------------------------------

sub new {
  my $type = shift;
  croak "$type is not meant to be used directly";
}

#------------------------------------------------------------------------------
1;

__END__

=head1 NAME

POE::Driver - an abstract interface for buffered, non-blocking I/O

=head1 SYNOPSIS

This is a contrived example of how POE::Filter and POE::Driver objects
may be used in a stand-alone application.

  my $driver = POE::Driver::SysRW->new();
  my $filter = POE::Filter::Line->new();

  my $list_of_octet_chunks = $filter->put("A line of text.");

  $driver->put( $list_of_octet_chunks );

  my $octets_remaining_in_buffer = $driver->flush($filehandle);
  die "couldn't flush everything" if $octets_remaining_in_buffer;

  while (1) {
    my $octets_list = $driver->get($filehandle);
    die $! unless defined $octets_list;

    $filter->get_one_start($octets_list);
    while (my $line = $filter->get_one()) {
      print "Input: $line\n";
    }
  }

Most programs will use POE::Filter and POE::Driver objects as
parameters to POE::Wheel constructors.  See the synopses for
particular classes for details.

=head1 DESCRIPTION

POE::Driver is a common API for I/O drivers that can read from and
write to various files, sockets, pipes, and other devices.

POE "drivers" implement the specifics of reading and writing to
devices.  Drivers plug into POE::Wheel objects so that wheels may
support a large number of device types without implementing a separate
subclass for each.

As mentioned in the SYNOPSIS, POE::Driver objects may be used in
stand-alone applications.

=head2 Public Driver Methods

These methods are the generic Driver interface, and every driver must
implement them.  Specific drivers may have additional methods related
to their particular tasks.

=head3 new

new() creates, initializes, and returns a new driver.  Specific
drivers may have different constructor parameters.  The default
constructor parameters should configure the driver for the most common
use case.

=head3 get FILEHANDLE

get() immediately tries to read information from a FILEHANDLE.  It
returns an array reference on success---even if nothing was read from
the FILEHANDLE.  get() returns undef on error, and $! will be set to
the reason why get() failed.

The returned arrayref will be empty if nothing was read from the
FILEHANDLE.

In an EOF condition, get() returns undef with the numeric value of $!
set to zero.

The arrayref returned by get() is suitable for passing to any
POE::Filter's get() or get_one_start() method.  Wheels do exactly this
internally.

=over

=item put ARRAYREF

put() accepts an ARRAYREF of raw octet chunks.  These octets are added
to the driver's internal output queue or buffer.  put() returns the
number of octets pending output after the new octets are buffered.

Some drivers may flush data immediately from their put() methods.

=item flush FILEHANDLE

flush() attempts to write a driver's buffered data to a given
FILEHANDLE.  The driver should flush as much data as possible in a
single flush() call.

flush() returns the number of octets remaining in the driver's output
queue or buffer after the maximum amount of data has been written.

flush() denotes success or failure by the value of $! after it
returns.  $! will always numerically equal zero on success.  On
failure, $! will contain the usual Errno value.  In either case,
flush() will return the number of octets in the driver's output queue.

=item get_out_messages_buffered

get_out_messages_buffered() returns the number of messages enqueued in
the driver's output queue, rounded up to the nearest whole message.
Some applications require the message count rather than the octet
count.

Messages are raw octet chunks enqueued by put().  The following put()
call enqueues two messages for a total of six octets:

  $filter->put( [ "one", "two" ] );

It is possible for a flush() call to write part of a message.  A
partial message still counts as one message.

=back

=head1 SEE ALSO

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

L<POE::Wheel> - A base class for POE::Session mix-ins.

L<POE::Filter> - A base class for data parsers and serializers.

L<POE::Driver::SysRW> - A driver that encapsulates sysread() and
buffered syswrite().

=head1 BUGS

There is no POE::Driver::SendRecv, but nobody has needed one so far.
sysread() and syswrite() manage to do almost everything people need.

In theory, drivers should be pretty much interchangeable.  In
practice, there seems to be an impermeable barrier between the
different SOCK_* types.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
