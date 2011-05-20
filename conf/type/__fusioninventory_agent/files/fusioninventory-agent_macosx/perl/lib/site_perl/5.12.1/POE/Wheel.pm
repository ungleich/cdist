package POE::Wheel;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw(croak);

# Used to generate unique IDs for wheels.  This is static data, shared
# by all.
my $current_id = 0;
my %active_wheel_ids;

sub new {
  my $type = shift;
  croak "$type is not meant to be used directly";
}

sub allocate_wheel_id {
  while (1) {
    last unless exists $active_wheel_ids{ ++$current_id };
  }
  return $active_wheel_ids{$current_id} = $current_id;
}

sub free_wheel_id {
  my $id = shift;
  delete $active_wheel_ids{$id};
}

sub _test_set_wheel_id {
  $current_id = shift;
}

1;

__END__

=head1 NAME

POE::Wheel - event-driven mixins for POE::Session

=head1 SYNOPSIS

This base class has no synopsis.
Please consult one of the subclasses instead.

=head1 DESCRIPTION

A POE::Wheel object encapsulates a bundle of event handlers that
perform a specific task.  It also manages the event watchers that
trigger those handlers.

Object lifetime is very important for POE wheels.  At creation time,
most wheels will add anonymous event handlers to the currently active
session.  In other words, the session that created the wheel is
modified to handle new events.  Event watchers may also be initialized
as necessary to trigger the new handlers.  These event watchers are
also owned by the session that created the wheel.

Sessions must not expose their wheels to other sessions.  Doing so
will likely cause problems because wheels are tightly integrated with
the sessions that created them.  For example, calling put() on a
POE::Wheel::ReadWrite instance may enable a write-okay watcher.  The
handler for this watcher is already defined in the wheel's owner.
Calling put() outside that session will enable the write-okay watcher
in the wrong session, and the event will never be handled.

Likewise, wheels must be destroyed from within their creator sessions.
Otherwise breakage will occur when the wheels' DESTROY methods try to
unregister event handlers and watchers from the wrong sessions.  To
simplify things, it's recommended to store POE::Wheel instances in
heaps of the sessions that created them.

For example, creating a POE::Wheel::FollowTail object will register an
event handler that periodically polls a file for new information.  It
will also start the timer that triggers the periodic polling.

  use POE;
  use POE::Wheel::FollowTail;

  my @files_to_tail = qw( messages maillog security );

  foreach my $filename (@files_to_tail) {
    POE::Session->create(
      inline_states => {
        _start => sub {
          push @{$_[HEAP]{messages}}, POE::Wheel::FollowTail->new(
            Filename   => "/var/log/$filename",
            InputEvent => "got_input",
          );
        },
        got_input => sub {
          print "$filename: $_[ARG0]\n";
        },
      }
    );
  }

  POE::Kernel->run();
  exit;

As illustrated in the previous example it is possible---sometimes
recommended---to create more than one POE::Wheel of a particular type
in the same session.  A session with multiple wheels may scale better
than separate sessions with one wheel apiece.  When in doubt,
benchmark.

Unlike components (or cheese), wheels do not stand alone.  Each wheel
must be created by a session in order to register event watchers and
handlers within that session.  Wheels are thusly tightly coupled to
their creator sessions and cannot be passed to other sessions.

=head1 FILTERS, AND DRIVERS

Many wheels perform data transfer operations on filehandles (which, as
you probably know, includes sockets, pipes, and just about anything
else that can store or transfer data).

To avoid subclass hell, POE::Wheel objects may be customized at
creation time by including other objects from the POE::Filter and
POE::Driver namespaces.

=head2 Filters

POE "filters" implement data parsers and serializers.  For example,
POE::Filter::Line parses streams into records separated by some string
(the traditional network newline by default).  The Line filter also
adds record separators to data being output.

POE::Filter::HTTPD is a more complex example.  It implements a subset
of the server-side of the HTTP protocol.  Input streams are parsed
into HTTP requests and wrapped in HTTP::Request objects.  Server code
sends HTTP::Response objects back to the client, which are serialized
so they may be sent to a socket.

Most wheels use POE::Filter::Line by default.

=head2 Drivers

POE "drivers" implement strategies for sending data to a filehandle
and receiving input from it.  A single POE::Wheel class may interact
with files, pipes, sockets, or devices by using the appropriate
driver.

POE::Driver::SysRW is the only driver that comes with POE.  sysread()
and syswrite() can handle nearly every kind of stream interaction, so
there hasn't been much call for another type of driver.

=head1 METHODS

POE::Wheel defines a common interface that most subclasses use.
Subclasses may implement other methods, especially to help perform
their unique tasks.  If something useful isn't documented here, see
the subclass before implementing a feature.

=head2 Required Methods

These methods are required by all subclasses.

=head3 new LOTS_OF_STUFF

new() instantiates and initializes a new wheel object and returns it.
The new wheel will continue to function for as long as it exists,
although other methods may alter the way it functions.

Part of any wheel's construction is the registration of anonymous
event handlers to perform wheel-specific tasks.  Event watchers are
also started to trigger the handlers when relevant activity occurs.

Every wheel has a different purpose and requires different constructor
parameters, so LOTS_OF_STUFF is documented in each particular
subclass.

=head3 DESTROY

DESTROY is Ye Olde Perl Object Destructor.  When the wheel's last
strong reference is relinquished, DESTROY triggers the wheel's
cleanup.  The object removes itself from the session that created it:
Active event watchers are stopped, and anonymous event handlers are
unregistered.

=head3 event EVENT_TYPE, EVENT_NAME [, EVENT_TYPE, EVENT_NAME, ....]

event() changes the events that a wheel will emit.  Its parameters are
one or more pairs of EVENT_TYPEs and the EVENT_NAMEs to emit when each
type of event occurs.  If an EVENT_NAME is undefined, then the wheel
will stop emitting that type of event.  Or the wheel may throw an
error if the event type is required.

EVENT_TYPEs differ for each wheel and correspond to the constructor
parameters that match /.*Event$/.  For example, POE::Wheel::ReadWrite
may emit up to five different kinds of event: InputEvent, ErrorEvent,
FlushedEvent, HighEvent, LowEvent.  The name of each emitted event may
be changed at run time.

This example changes the events to emit on new input and when output
is flushed.  It stops the wheel from emitting events when errors
occur.

  $wheel->event(
    InputEvent   => 'new_input_event',
    ErrorEvent   => undef,
    FlushedEvent => 'new_flushed_event',
  );

=head2 I/O Methods

Wheels that perform input and output may implement some or all of
these methods.  The put() method is a common omission.  Wheels that
don't perform output do not have put() methods.

=head3 put RECORD [, RECORD [, ....]]

put() sends one or more RECORDs to the wheel for transmitting.  Each
RECORD is serialized by the wheel's associated POE::Filter so that it
will be ready to transmit.  The serialized stream may be transmitted
immediately by the wheel's POE::Driver object, or it may be buffered
in the POE::Driver until it can be flushed to the output filehandle.

Most wheels use POE::Filter::Line and POE::Driver::SysRW by default,
so it's not necessary to specify them in most cases.

=head2 Class Static Functions

These functions expose information that is common to all wheels.  They
are not methods, so they should B<not> be called as methods.

  my $new_wheel_id = POE::Wheel::allocate_wheel_id();
  POE::Wheel::free_wheel_id($new_wheel_id);

=head3 allocate_wheel_id

B<This is not a class method.>

Every wheel has a unique ID.  allocate_wheel_id() returns the next
available unique wheel ID.  Wheel constructors use it to set their IDs
internally.

  package POE::Wheel::Example;
  use base qw(POE::Wheel);

  sub new {
    # ... among other things ...
    $self->[MY_WHEEL_ID] = POE::Wheel::allocate_wheel_id();
    return $self;
  }

Wheel IDs are used to tell apart events from similarly typed wheels.
For example, a multi-file tail utility may handle all file input with
the same function.  Wheel IDs may be used to tell which wheel
generated the InputEvent being handled.

Wheel IDs are often used to store wheel-local state in a session's
heap.

  sub handle_error {
    my $wheel_id = $_[ARG3];
    print "Wheel $wheel_id caught an error.  Shutting it down.\n";
    delete $_[HEAP]{wheels}{$wheel_id};
  }

It is vital for wheels to free their allocated IDs when they are
destroyed.  POE::Wheel class keeps track of allocated wheel IDs to
avoid collisions, and they will remain in memory until freed.  See
free_wheel_id().

=head3 free_wheel_id WHEEL_ID

B<This is not a class method.>

free_wheel_id() deallocates a wheel's ID so that it stops consuming
memory and may be reused later.  This is often called from a wheel's
destructor.

  package POE::Wheel::Example;
  use base qw(POE::Wheel);

  sub DESTROY {
    my $self = shift;
    # ... among other things ...
    POE::Wheel::free_wheel_id($self->[MY_WHEEL_ID]);
  }

Wheel IDs may be reused, although it has never been reported.  Two
active wheels will never share the same ID, however.

=head3 ID

B<This is usually implemented in the subclass!>

The ID() method returns a wheel's unique ID. It is commonly used to
match events with the wheels which generated them.

Again, this method is not implemented in this class! If it's missing
from the subclass, please go pester that module author---thanks!

=head1 SEE ALSO

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

L<POE::Driver> - A base class for file access drivers that POE::Wheel
may use.

L<POE::Filter> - A base class for data parsers and marshalers that
POE::Wheel may use.

L<POE::Wheel::Curses> - Non-blocking input for Curses.

L<POE::Wheel::FollowTail> - Non-blocking file and FIFO monitoring.

L<POE::Wheel::ListenAccept> - Non-blocking server for existing
sockets.

L<POE::Wheel::ReadLine> - Non-blocking console input, with full
readline support.

L<POE::Wheel::ReadWrite> - Non-blocking stream I/O.

L<POE::Wheel::Run> - Non-blocking process creation and management.

L<POE::Wheel::SocketFactory> - Non-blocking socket creation,
supporting most protocols and modes.

TODO - Link to POE::Wheel search.cpan.org module search.

=head1 BUGS

It would be nice if wheels were more like proper Unix streams.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors, contributors,
and POE;s licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
