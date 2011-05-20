# Data and accessors to manage POE's events.

package POE::Resource::Events;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

# These methods are folded into POE::Kernel;
package POE::Kernel;

use strict;

# A local copy of the queue so we can manipulate it directly.
my $kr_queue;

my %event_count;
#  ( $session => $count,
#    ...,
#  );

my %post_count;
#  ( $session => $count,
#    ...,
#  );

### Begin-run initialization.

sub _data_ev_initialize {
  my ($self, $queue) = @_;
  $kr_queue = $queue;
}

### End-run leak checking.

sub _data_ev_finalize {
  my $finalized_ok = 1;
  while (my ($ses, $cnt) = each(%event_count)) {
    $finalized_ok = 0;
    _warn("!!! Leaked event-to count: $ses = $cnt\n");
  }

  while (my ($ses, $cnt) = each(%post_count)) {
    $finalized_ok = 0;
    _warn("!!! Leaked event-from count: $ses = $cnt\n");
  }
  return $finalized_ok;
}

### Enqueue an event.

sub FIFO_TIME_EPSILON () { 0.000001 }
my $last_fifo_time = time();

sub _data_ev_enqueue {
  my (
    $self,
    $session, $source_session, $event, $type, $etc,
    $file, $line, $fromstate, $time
  ) = @_;

  if (ASSERT_DATA) {
    unless ($self->_data_ses_exists($session)) {
      _trap(
        "<ev> can't enqueue event ``$event'' for nonexistent session $session\n"
      );
    }
  }

  # This is awkward, but faster than using the fields individually.
  my $event_to_enqueue = [ @_[1..8] ];

  my $new_id;
  my $old_head_priority = $kr_queue->get_next_priority();

  unless ($type & ET_MASK_DELAYED) {
    $time = $last_fifo_time + FIFO_TIME_EPSILON if $time <= $last_fifo_time;
    $last_fifo_time = $time;
  }

  $new_id = $kr_queue->enqueue($time, $event_to_enqueue);

  if (TRACE_EVENTS) {
    _warn(
      "<ev> enqueued event $new_id ``$event'' from ",
      $self->_data_alias_loggable($source_session), " to ",
      $self->_data_alias_loggable($session),
      " at $time"
    );
  }

  unless (defined $old_head_priority) {
    $self->loop_resume_time_watcher($time);
  }
  elsif ($time < $old_head_priority) {
    $self->loop_reset_time_watcher($time);
  }

  # This is the counterpart to _data_ev_refcount_dec().  It's only
  # used in one place, so it's not in its own function.

  $self->_data_ses_refcount_inc($session) unless $event_count{$session}++;

  return $new_id if $session == $source_session;

  $self->_data_ses_refcount_inc($source_session) unless (
    $post_count{$source_session}++
  );

  return $new_id;
}

### Remove events sent to or from a specific session.

sub _data_ev_clear_session {
  my ($self, $session) = @_;

  # Events sent to the session.
  PENDING: {
    my $pending_count = $event_count{$session};
    last PENDING unless $pending_count;

    foreach (
      $kr_queue->remove_items(
        sub { $_[0][EV_SESSION] == $session },
        $pending_count
      )
    ) {
      $self->_data_ev_refcount_dec(
        @{$_->[ITEM_PAYLOAD]}[EV_SOURCE, EV_SESSION]
      );
      $pending_count--;
    }

    last PENDING unless $pending_count;

    croak "lingering pending count: $pending_count" if $pending_count;
  }

  # Events sent by the session.
  SENT: {
    my $sent_count = $post_count{$session};
    last SENT unless $sent_count;

    foreach (
      $kr_queue->remove_items(
        sub { $_[0][EV_SOURCE] == $session },
        $sent_count
      )
    ) {
      $self->_data_ev_refcount_dec(
        @{$_->[ITEM_PAYLOAD]}[EV_SOURCE, EV_SESSION]
      );
      $sent_count--;
    }

    last SENT unless $sent_count;

    croak "lingering sent count: $sent_count" if $sent_count;
  }

  croak "lingering event count" if delete $event_count{$session};
  croak "lingering post count" if delete $post_count{$session};
}

# TODO Alarm maintenance functions may move out to a separate
# POE::Resource module in the future.  Why?  Because alarms may
# eventually be managed by something other than the event queue.
# Especially if we incorporate a proper Session scheduler.  Be sure to
# move the tests to a corresponding t/res/*.t file.

### Remove a specific alarm by its name.  This is in the events
### section because alarms are currently implemented as events with
### future due times.

sub _data_ev_clear_alarm_by_name {
  my ($self, $session, $alarm_name) = @_;

  my $my_alarm = sub {
    return 0 unless $_[0]->[EV_TYPE] & ET_ALARM;
    return 0 unless $_[0]->[EV_SESSION] == $session;
    return 0 unless $_[0]->[EV_NAME] eq $alarm_name;
    return 1;
  };

  foreach ($kr_queue->remove_items($my_alarm)) {
    $self->_data_ev_refcount_dec(@{$_->[ITEM_PAYLOAD]}[EV_SOURCE, EV_SESSION]);
  }
}

### Remove a specific alarm by its ID.  This is in the events section
### because alarms are currently implemented as events with future due
### times.  TODO It's possible to remove non-alarms; is that wrong?

sub _data_ev_clear_alarm_by_id {
  my ($self, $session, $alarm_id) = @_;

  my $my_alarm = sub {
    $_[0]->[EV_SESSION] == $session;
  };

  my ($time, $id, $event) = $kr_queue->remove_item($alarm_id, $my_alarm);
  return unless defined $time;

  if (TRACE_EVENTS) {
    _warn(
      "<ev> removed event $id ``", $event->[EV_NAME], "'' to ",
      $self->_data_alias_loggable($session), " at $time"
    );
  }

  $self->_data_ev_refcount_dec( @$event[EV_SOURCE, EV_SESSION] );
  return ($time, $event);
}

### Remove all the alarms for a session.  Whoot!

sub _data_ev_clear_alarm_by_session {
  my ($self, $session) = @_;

  my $my_alarm = sub {
    return 0 unless $_[0]->[EV_TYPE] & ET_ALARM;
    return 0 unless $_[0]->[EV_SESSION] == $session;
    return 1;
  };

  my @removed;
  foreach ($kr_queue->remove_items($my_alarm)) {
    my ($time, $event) = @$_[ITEM_PRIORITY, ITEM_PAYLOAD];
    $self->_data_ev_refcount_dec( @$event[EV_SOURCE, EV_SESSION] );
    push @removed, [ $event->[EV_NAME], $time, @{$event->[EV_ARGS]} ];
  }

  return @removed;
}

### Decrement a post refcount

sub _data_ev_refcount_dec {
  my ($self, $source_session, $dest_session) = @_;

  if (ASSERT_DATA) {
    _trap $dest_session unless exists $event_count{$dest_session};
  }

  $self->_data_ses_refcount_dec($dest_session) unless (
    --$event_count{$dest_session}
  );

  return if $dest_session == $source_session;

  if (ASSERT_DATA) {
    _trap $source_session unless exists $post_count{$source_session};
  }

  $self->_data_ses_refcount_dec($source_session) unless (
    --$post_count{$source_session}
  );
}

### Fetch the number of pending events sent to a session.

sub _data_ev_get_count_to {
  my ($self, $session) = @_;
  return $event_count{$session} || 0;
}

### Fetch the number of pending events sent from a session.

sub _data_ev_get_count_from {
  my ($self, $session) = @_;
  return $post_count{$session} || 0;
}

### Dispatch events that are due for "now" or earlier.

sub _data_ev_dispatch_due {
  my $self = shift;

  if (TRACE_EVENTS) {
    foreach ($kr_queue->peek_items(sub { 1 })) {
      my @event = map { defined() ? $_ : "(undef)" } @{$_->[ITEM_PAYLOAD]};
      _warn(
        "<ev> time($_->[ITEM_PRIORITY]) id($_->[ITEM_ID]) ",
        "event(@event)\n"
      );
    }
  }

  my $now = time();
  my $next_time;
  while (
    defined($next_time = $kr_queue->get_next_priority()) and
    $next_time <= $now
  ) {
    my ($due_time, $id, $event) = $kr_queue->dequeue_next();

    if (TRACE_EVENTS) {
      _warn("<ev> dispatching event $id ($event->[EV_NAME])");
    }

    # An event is "blocked" if its due time is earlier than the
    # current time.  This means that the event has had to wait before
    # being dispatched.  As far as I can tell, all events will be
    # "blocked" according to these rules.

    if (TRACE_STATISTICS) {
      if ($due_time < $now) {
        $self->_data_stat_add('blocked', 1);
        $self->_data_stat_add('blocked_seconds', $now - $due_time);
      }
    }

    # TODO - Why can't we reverse these two lines?
    # TODO - Reversing them could avoid entering and removing GC marks.
    $self->_data_ev_refcount_dec($event->[EV_SOURCE], $event->[EV_SESSION]);
    $self->_dispatch_event(@$event, $due_time, $id);

    # Stop the system if an unhandled exception occurred.
    # This wipes out all sessions and associated resources.
    next unless $POE::Kernel::kr_exception;
    POE::Kernel->stop();
  }

  # Sweep for dead sessions.  The sweep may alter the next queue time.

  $self->_data_ses_gc_sweep();
  $next_time = $kr_queue->get_next_priority();

  # Tell the event loop to wait for the next event, if there is one.
  # Otherwise we're going to wait indefinitely for some other event.

  if (defined $next_time) {
    $self->loop_reset_time_watcher($next_time);
  }
  else {
    $self->loop_pause_time_watcher();
  }
}

1;

__END__

=head1 NAME

POE::Resource::Events - internal event manager for POE::Kernel

=head1 SYNOPSIS

There is no public API.

=head1 DESCRIPTION

POE::Resource::Events is a mix-in class for POE::Kernel.  It hides the
complexity of managing POE's events from even POE itself.  It is used
internally by POE::Kernel, so it has no public interface.

=head1 SEE ALSO

See L<POE::Kernel/Asynchronous Messages (FIFO Events)> for one public
events API.

See L<POE::Kernel/Resources> for for public information about POE
resources.

See L<POE::Resource> for general discussion about resources and the
classes that manage them.

=head1 BUGS

None known.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
