package POE::Loop;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

1;

__END__

=head1 NAME

POE::Loop - documentation for POE's event loop bridge interface

=head1 SYNOPSIS

  $kernel->loop_initialize();
  $kernel->loop_finalize();
  $kernel->loop_do_timeslice();
  $kernel->loop_run();
  $kernel->loop_halt();

  $kernel->loop_watch_signal($signal_name);
  $kernel->loop_ignore_signal($signal_name);
  $kernel->loop_attach_uidestroy($gui_window);

  $kernel->loop_resume_time_watcher($next_time);
  $kernel->loop_reset_time_watcher($next_time);
  $kernel->loop_pause_time_watcher();

  $kernel->loop_watch_filehandle($handle, $mode);
  $kernel->loop_ignore_filehandle($handle, $mode);
  $kernel->loop_pause_filehandle($handle, $mode);
  $kernel->loop_resume_filehandle($handle, $mode);

=head1 DESCRIPTION

POE::Loop is a virtual base class that defines a standard event loop
interface.  POE::Loop subclasses mix into POE::Kernel and implement
the features needed to manage underlying event loops in a consistent
fashion.  This documentation covers the interface, which is shared by
all subclasses.

As POE::Kernel loads, it searches through %INC for event loop modules.
POE::Kernel loads the most appropriate POE::Loop subclass for the
event loop it finds.  The subclass slots its methods into POE::Kernel,
completing the class at load time.  POE and POE::Kernel provide ways
to state the desired event loop in case the auto-detection makes a
mistake or the developer prefers to be explicit.  See
L<POE::Kernel/"Using POE with Other Event Loops"> for instructions on
how to actually use POE with other event loops, event loop naming
conventions, and other details.

POE::Loop subclasses exist for many of the event loops Perl supports:
select(), IO::Poll, WxWindows, EV, Glib, Event, and so on.  See CPAN
for a full list.

=head1 GENERAL NOTES

As previously noted, POE::Loop subclasses provide additional methods
to POE::Kernel and are not proper objects in themselves.

Each POE::Loop subclass first defines its own namespace and version
within it.  This way CPAN and other things can track its version.
They then switch to the POE::Kernel package to define their additional
methods.

POE::Loop is designed as a mix-in class because Perl imposed a
performance penalty for method inheritance at the time the class was
designed.  This could be changed in the future, but it will require
cascaded changes in several other classes.

Here is a skeleton of a POE::Loop subclass:

  use strict;

  # YourToolkit bridge for POE::Kernel;

  package POE::Loop::YourToolkit;

  use vars qw($VERSION);
  $VERSION = '1.000'; # NOTE - Should be #.### (three decimal places)

  package POE::Kernel;

  # Define private lexical data here.
  # Implement the POE::Loop interface here.

  1;

  __END__

  =head1 NAME

  ... documentation goes here ...

  =cut

=head1 PUBLIC INTERFACE

POE::Loop's public interface is divided into four parts:
administrative methods, signal handler methods, time management
methods, and filehandle watcher methods.  Each group and its members
will be described in detail shortly.

POE::Loop subclasses use lexical variables to keep track of things.
Exact implementation is left up to the subclass' author.
POE::Loop::Select keeps its bit vectors for select() calls in
class-scoped (static) lexical variables.  POE::Loop::Gtk tracks a
single time watcher and multiple file watchers there.

Bridges often employ private methods as callbacks from their event
loops.  The Event, Gtk, and Tk bridges do this.  Private callback
names should begin with "_loop_" to avoid colliding with other
methods.

Developers should look at existing bridges to get a feel for things.
The C<-m> flag for perldoc will show a module in its entirety.

  perldoc -m POE::Loop::Select
  perldoc -m POE::Loop::Gtk
  ...

=head2 Administrative Methods

These methods initialize and finalize an event loop, run the loop to
process events, and halt it.

=head3 loop_initialize

Initialize the event loop.  Graphical toolkits especially need some
sort of init() call or sequence to set up.  For example, Tk requires a
widget to be created before any events will be processed, and the
program's user interface will be considered destroyed if that widget
is closed.

  sub loop_initialize {
    my $self = shift;

    $poe_main_window = Tk::MainWindow->new();
    die "could not create a main Tk window" unless defined $poe_main_window;
    $self->signal_ui_destroy($poe_main_window);
  }

POE::Loop::Select initializes its select() bit vectors.

  sub loop_initialize {
    @loop_vectors = ( '', '', '' );
    vec($loop_vectors[MODE_RD], 0, 1) = 0;
    vec($loop_vectors[MODE_WR], 0, 1) = 0;
    vec($loop_vectors[MODE_EX], 0, 1) = 0;
  }

=head3 loop_finalize

Finalize the event loop.  Most event loops do not require anything
here since they have already stopped by the time loop_finalize() is
called.  However, this is a good place to check that a bridge has not
leaked memory or data.  This example comes from POE::Loop::Event.

  sub loop_finalize {
    my $self = shift;

    foreach my $fd (0..$#fileno_watcher) {
      next unless defined $fileno_watcher[$fd];
      foreach my $mode (MODE_RD, MODE_WR, MODE_EX) {
        POE::Kernel::_warn(
          "Mode $mode watcher for fileno $fd is defined during loop finalize"
        ) if defined $fileno_watcher[$fd]->[$mode];
      }
    }

    $self->loop_ignore_all_signals();
  }

=head3 loop_do_timeslice

Wait for time to pass or new events to occur, and dispatch any events
that become due.  If the underlying event loop does this through
callbacks, then loop_do_timeslice() will either provide minimal glue
or do nothing.

For example, loop_do_timeslice() for POE::Loop::Select sets up and
calls select().  If any files or other resources become active, it
enqueues events for them.  Finally, it triggers dispatch for any
events are due.

On the other hand, the Gtk event loop handles all this, so
loop_do_timeslice() is empty for the Gtk bridge.

A sample loop_do_timeslice() implementation is not presented here
because it would either be quite large or empty.  See each
POE::Loop::IO_Poll or Select for large ones.  Event and Gtk are empty.

The bridges for Poll and Select for large ones.  The ones for Event
and Gtk are empty, and Tk's (in POE::Loop::TkCommon) is rather small.

=head3 loop_run

Run an event loop until POE has no more sessions to handle events.
This method tends to be quite small, and it is often implemented in
terms of loop_do_timeslice().  For example, POE::Loop::IO_Poll
implements it:

  sub loop_run {
    my $self = shift;
    while ($self->_data_ses_count()) {
      $self->loop_do_timeslice();
    }
  }

This method is even more trivial when an event loop handles it.  This
is from the Gtk bridge:

  sub loop_run {
    unless (defined $_watcher_timer) {
      $_watcher_timer = Gtk->idle_add(\&_loop_resume_timer);
    }
    Gtk->main;
  }

=head3 loop_halt

loop_halt() does what it says: It halts POE's underlying event loop.
It tends to be either trivial for external event loops or empty for
ones that are implemented in the bridge itself (IO_Poll, Select).

For example, the loop_run() method in the Poll bridge exits when
sessions have run out, so its loop_halt() method is empty:

  sub loop_halt {
    # does nothing
  }

Gtk, however, needs to be stopped because it does not know when POE is
done.

  sub loop_halt {
    Gtk->main_quit();
  }

=head2 Signal Management Methods

These methods enable and disable signal watchers.  They are used by
POE::Resource::Signals to manage an event loop's signal watchers.

Most event loops use Perl's %SIG to watch for signals.  This is so
common that POE::Loop::PerlSignals implements the interface on behalf
of other subclasses.

=head3 loop_watch_signal SIGNAL_NAME

Watch for a given SIGNAL_NAME.  SIGNAL_NAME is the version found in
%SIG, which tends to be the operating signal's name with the leading
"SIG" removed.

POE::Loop::PerlSignals' implementation adds callbacks to %SIG except
for CHLD/CLD, which begins a waitpid() polling loop instead.

As of this writing, all of the POE::Loop subclasses register their
signal handlers through POE::Loop::PerlSignals.

There are three types of signal handlers:

CHLD/CLD handlers, when managed by the bridges themselves, poll for
exited children.  POE::Kernel does most of this, but
loop_watch_signal() still needs to start the process.

PIPE handlers.  The PIPE signal event must be sent to the session that
is active when the signal occurred.

Everything else.  Signal events for everything else are sent to
POE::Kernel, where they are distributed to every session.

The loop_watch_signal() methods tends to be very long, so an example
is not presented here.  The Event and Select bridges have good
examples, though.

=head3 loop_ignore_signal SIGNAL_NAME

Stop watching SIGNAL_NAME.  POE::Loop::PerlSignals does this by
resetting the %SIG for the SIGNAL_NAME to a sane value.

$SIG{CHLD} is left alone so as to avoid interfering with system() and
other things.

SIGPIPE is generally harmless since POE generates events for this
condition.  Therefore $SIG{PIPE} is set to "IGNORE" when it's not
being handled.

All other signal handlers default to "DEFAULT" when not in use.

=head3 loop_attach_uidestroy WIDGET

POE, when used with a graphical toolkit, should shut down when the
user interface is closed.  loop_attach_uidestroy() is used to shut
down POE when a particular WIDGET is destroyed.

The shutdown is done by firing a UIDESTROY signal when the WIDGET's
closure or destruction callback is invoked.  UIDESTROY guarantees the
program will shut down by virtue of being terminal and non-maskable.

loop_attach_uidestroy() is only meaningful in POE::Loop subclasses
that tie into user interfaces.  All other subclasses leave the method
empty.

Here's Gtk's:

  sub loop_attach_uidestroy {
    my ($self, $window) = @_;
    $window->signal_connect(
      delete_event => sub {
        if ($self->_data_ses_count()) {
          $self->_dispatch_event(
            $self, $self,
            EN_SIGNAL, ET_SIGNAL, [ 'UIDESTROY' ],
            __FILE__, __LINE__, undef, time(), -__LINE__
          );
        }
        return 0;
      }
    );
  }

=head2 Alarm and Time Management Methods

These methods enable and disable a time watcher or alarm in the
underlying event loop.  POE only requires one, which is reused or
re-created as necessary.

Most event loops trigger callbacks when time has passed.  It is the
bridge's responsibility to register and unregister a callback as
needed.  When invoked, the callback should dispatch events that have
become due and possibly set up a new callback for the next event to be
dispatched.

The time management methods may accept NEXT_EVENT_TIME.  This is the
time the next event will become due, in UNIX epoch time.
NEXT_EVENT_TIME is a real number and may have sub-second accuracy.  It
is the bridge's responsibility to convert this value into something
the underlying event loop requires.

=head3 loop_resume_time_watcher NEXT_EVENT_TIME

Resume an already active time watcher.  It is used with
loop_pause_time_watcher() to provide less expensive timer toggling for
frequent use cases.  As mentioned above, NEXT_EVENT_TIME is in UNIX
epoch time and may have sub-second accuracy.

loop_resume_time_watcher() is used by bridges that set them watchers
in the underlying event loop.  For example, POE::Loop::Gtk implements
it this way:

  sub loop_resume_time_watcher {
    my ($self, $next_time) = @_;
    $next_time -= time();
    $next_time *= 1000;
    $next_time = 0 if $next_time < 0;
    $_watcher_timer = Gtk->timeout_add(
      $next_time, \&_loop_event_callback
    );
  }

This method is usually empty in bridges that implement their own event
loops.

=head3 loop_reset_time_watcher NEXT_EVENT_TIME

Reset a time watcher, often by stopping or destroying an existing one
and creating a new one in its place.  It is often a wrapper for
loop_resume_time_watcher() that first destroys an existing watcher.
For example, POE::Loop::Gkt's implementation:

  sub loop_reset_time_watcher {
    my ($self, $next_time) = @_;
    Gtk->timeout_remove($_watcher_timer);
    undef $_watcher_timer;
    $self->loop_resume_time_watcher($next_time);
  }

=head3 loop_pause_time_watcher

Pause a time watcher without destroying it, if the underlying event
loop supports such a thing.  POE::Loop::Event does support it:

  sub loop_pause_time_watcher {
    $_watcher_timer or return;
    $_watcher_timer->stop();
  }

=head2 File Activity Management Methods

These methods enable and disable file activity watchers.  There are
four methods: loop_watch_filehandle(), loop_ignore_filehandle(),
loop_pause_filehandle(), and loop_resume_filehandle().  The "pause"
and "resume" methods are lightweight versions of "ignore" and "watch",
respectively.

All the methods take the same two parameters: a file HANDLE and a file
access MODE.  Modes may be MODE_RD, MODE_WR, or MODE_EX.  These
constants are defined by POE::Kernel and correspond to the semantics
of POE::Kernel's select_read(), select_write(), and select_expedite()
methods.

POE calls MODE_EX "expedited" because it often signals that a file is
ready for out-of-band information.  Not all event loops handle
MODE_EX.  For example, Tk:

  sub loop_watch_filehandle {
    my ($self, $handle, $mode) = @_;
    my $fileno = fileno($handle);

    my $tk_mode;
    if ($mode == MODE_RD) {
      $tk_mode = 'readable';
    }
    elsif ($mode == MODE_WR) {
      $tk_mode = 'writable';
    }
    else {
      # The Tk documentation implies by omission that expedited
      # filehandles aren't, uh, handled.  This is part 1 of 2.
      confess "Tk does not support expedited filehandles";
    }

    # ... rest omitted ....
  }

=head3 loop_watch_filehandle FILE_HANDLE, IO_MODE

Watch a FILE_HANDLE for activity in a given IO_MODE.  Depending on the
underlying event loop, a watcher or callback will be registered for
the FILE_HANDLE.  Activity in the specified IO_MODE (read, write, or
out of band) will trigger emission of the proper event in application
space.

POE::Loop::Select sets the fileno()'s bit in the proper select() bit
vector.  It also keeps track of which file descriptors are active.

  sub loop_watch_filehandle {
    my ($self, $handle, $mode) = @_;
    my $fileno = fileno($handle);
    vec($loop_vectors[$mode], $fileno, 1) = 1;
    $loop_filenos{$fileno} |= (1<<$mode);
  }

=head3 loop_ignore_filehandle FILE_HANDLE, IO_MODE

Stop watching the FILE_HANDLE in a given IO_MODE.  Stops (and possibly
destroys) an event watcher corresponding to the FILE_HANDLE and
IO_MODE.

POE::Loop::IO_Poll's loop_ignore_filehandle() manages descriptor/mode
bits for its _poll() method here.  It also performs some cleanup if a
descriptor is no longer being watched after this ignore call.

  sub loop_ignore_filehandle {
    my ($self, $handle, $mode) = @_;
    my $fileno = fileno($handle);

    my $type = mode_to_poll($mode);
    my $current = $poll_fd_masks{$fileno} || 0;
    my $new = $current & ~$type;

    if (TRACE_FILES) {
      POE::Kernel::_warn(
        sprintf(
          "<fh> Ignore $fileno: " .
          ": Current mask: 0x%02X - removing 0x%02X = 0x%02X\n",
          $current, $type, $new
        )
      );
    }

    if ($new) {
      $poll_fd_masks{$fileno} = $new;
    }
    else {
      delete $poll_fd_masks{$fileno};
    }
  }

=head3 loop_pause_filehandle FILE_HANDLE, IO_MODE

This is a lightweight form of loop_ignore_filehandle().  It is used
along with loop_resume_filehandle() to temporarily toggle a watcher's
state for a FILE_HANDLE in a particular IO_MODE.

Some event loops, such as Event.pm, support their file watchers being
disabled and re-enabled without the need to destroy and re-create
the watcher objects.

  sub loop_pause_filehandle {
    my ($self, $handle, $mode) = @_;
    my $fileno = fileno($handle);
    $fileno_watcher[$fileno]->[$mode]->stop();
  }

By comparison, Event's loop_ignore_filehandle() method cancels and
destroys the watcher object.

  sub loop_ignore_filehandle {
    my ($self, $handle, $mode) = @_;
    my $fileno = fileno($handle);
    if (defined $fileno_watcher[$fileno]->[$mode]) {
      $fileno_watcher[$fileno]->[$mode]->cancel();
      undef $fileno_watcher[$fileno]->[$mode];
    }
  }

Ignoring and re-creating watchers is relatively expensive, so
POE::Kernel's select_pause_read() and select_resume_read() methods
(and the corresponding ones for write and expedite) use the faster
versions.

=head3 loop_resume_filehandle FILE_HANDLE, IO_MODE

This is a lightweight form of loop_watch_filehandle().  It is used
along with loop_pause_filehandle() to temporarily toggle a a watcher's
state for a FILE_HANDLE in a particular IO_MODE.

=head1 HOW POE FINDS EVENT LOOP BRIDGES

This is a rehash of L<POE::Kernel/"Using POE with Other Event Loops">.

Firstly, if a POE::Loop subclass is manually loaded before
POE::Kernel, then that will be used.  End of story.

If one isn't, POE::Kernel searches for an external event loop module
in %INC.  For each module in %INC, corresponding POE::XS::Loop and
POE::Loop subclasses are tried.

For example, if IO::Poll is loaded, POE::Kernel tries

  use POE::XS::Loop::IO_Poll;
  use POE::Loop::IO_Poll;

This is relatively expensive, but it ensures that POE::Kernel can find
new POE::Loop subclasses without defining them in a central registry.

POE::Loop::Select is the fallback event loop.  It's loaded if no other
event loop can be found in %INC.

It can't be repeated often enough that event loops must be loaded
before POE::Kernel.  Otherwise they will not be present in %INC, and
POE::Kernel will not detect them.

=head1 SEE ALSO

L<POE>, L<POE::Loop::Event>, L<POE::Loop::Gtk>, L<POE::Loop::IO_Poll>,
L<POE::Loop::Select>, L<POE::Loop::Tk>.

L<POE::Test::Loops> is POE's event loop tests released as a separate,
reusable distribution.  POE::Loop authors are encouraged to use the
tests for their own distributions.

TODO - Link to CPAN for POE::Loop modules.

=head1 BUGS

TODO - Link to POE bug queue.

=head1 AUTHORS & LICENSING

Please see L<POE> for more information about authors, contributors,
and POE's licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
