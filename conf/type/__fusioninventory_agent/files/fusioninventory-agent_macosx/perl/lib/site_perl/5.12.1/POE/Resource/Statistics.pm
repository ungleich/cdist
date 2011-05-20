# Data and methods to collect run-time statistics about POE, allowing
# clients to look at how much work their POE server is performing.
# None of this stuff will activate unless TRACE_STATISTICS or
# TRACE_PROFILE are enabled.

package POE::Resource::Statistics;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

# We fold all this stuff back into POE::Kernel
package POE::Kernel;

use strict;

# We keep a number of metrics (idle time, user time, etc).
# Every tick (by default 30secs), we compute the rolling average
# of those metrics. The rolling average is computed based on
# the number of readings specified in $_stat_window_size.

my $_stat_metrics     = []; # the data itself
my $_stat_interval    = 30; # how frequently we take readings
my $_stat_window_size = 4;  # how many readings we average across
my $_stat_wpos        = 0;  # where to currently write metrics (circ. buffer)
my $_stat_rpos        = 0;  # where to currently write metrics (circ. buffer)
my %average;

# This is for collecting event frequencies if TRACE_PROFILE is
# enabled.
my %profile;

# Per-session profiling data.
my %profile_session;

sub _data_stat_initialize {
  my ($self) = @_;
  $self->_data_stat_reset;
  $self->_data_ev_enqueue(
    $self, $self, EN_STAT, ET_STAT, [ ],
    __FILE__, __LINE__, undef, time() + $_stat_interval
  );
}

sub _data_stat_finalize {
  my ($self) = @_;
  $self->_data_stat_tick();

  if (TRACE_STATISTICS) {
    POE::Kernel::_warn(
      '<pr> ,----- Observed Statistics ' , ('-' x 47), ",\n"
    );

    # we make a local copy so we can munge with the data
    my %avg = %average;

    unless (keys %avg) {
      POE::Kernel::_warn '<pr> `', ('-' x 73), "'\n";
      return;
    }

    # Division by zero sucks. Warnings sucks too.
    $avg{interval}    ||= 1;
    $avg{user_events} ||= 1;
    $avg{avg_blocked} ||= 0;
    foreach my $k (keys %avg) {
      $avg{$k} ||= 0;
    }

    foreach (sort keys %avg) {
      next if /epoch/;
      POE::Kernel::_warn(
        sprintf "<pr> | %60.60s %9.1f  |\n", $_, $avg{$_}
      );
    }

    POE::Kernel::_warn(
      '<pr> +----- Derived Statistics ', ('-' x 48), "+\n",
      sprintf(
        "<pr> | %60.60s %9.1f%% |\n",
        'idle', 100 * $avg{avg_idle_seconds} / $avg{interval}
      ),
      sprintf(
        "<pr> | %60.60s %9.1f%% |\n",
        'user', 100 * $avg{avg_user_seconds} / $avg{interval}
      ),
      sprintf(
        "<pr> | %60.60s %9.1f%% |\n",
        'blocked', 100 * $avg{avg_blocked} / $avg{user_events}
      ),
      sprintf(
        "<pr> | %60.60s %9.1f  |\n",
        'user load', $avg{avg_user_events} / $avg{interval}
      ),
      '<pr> `', ('-' x 73), "'\n"
    );
  }

  if (TRACE_PROFILE) {
    stat_show_profile();
  }
}

sub _data_stat_add {
  my ($self, $key, $count) = @_;
  $_stat_metrics->[$_stat_wpos] ||= {};
  $_stat_metrics->[$_stat_wpos]->{$key} += $count;
}

sub _data_stat_tick {
  my ($self) = @_;

  my $pos = $_stat_rpos;
  $_stat_wpos = ($_stat_wpos+1) % $_stat_window_size;
  if ($_stat_wpos == $_stat_rpos) {
    $_stat_rpos = ($_stat_rpos+1) % $_stat_window_size;
  }

  my $count = 0;
  %average = ();
  my $epoch = 0;
  while ($count < $_stat_window_size && $_stat_metrics->[$pos]->{epoch}) {
    $epoch = $_stat_metrics->[$pos]->{epoch} unless $epoch;
    while (my ($k,$v) = each %{$_stat_metrics->[$pos]}) {
      next if $k eq 'epoch';
      $average{$k} += $v;
    }
    $count++;
    $pos = ($pos+1) % $_stat_window_size;
  }

  if ($count) {
    my $now = time();
    map { $average{"avg_$_"} = $average{$_} / $count } keys %average;
    $average{total_duration} = $now - $epoch;
    $average{interval}       = ($now - $epoch) / $count;
  }

  $self->_data_stat_reset;
  $self->_data_ev_enqueue(
    $self, $self, EN_STAT, ET_STAT, [ ],
    __FILE__, __LINE__, undef, time() + $_stat_interval
  ) if $self->_data_ses_count() > 1;
}

sub _data_stat_reset {
  $_stat_metrics->[$_stat_wpos] = {
    epoch => time,
    idle_seconds => 0,
    user_seconds => 0,
    kern_seconds => 0,
    blocked_seconds => 0,
  };
}

sub _data_stat_clear_session {
  my ($self, $session) = @_;
  delete $profile_session{$session};
  return;
}

# Profile this event.

sub _stat_profile {
  my ($self, $event, $session) = @_;
  $profile{$event}++;
  $profile_session{$session}{$event}++;
  return;
}

# Public routines...

sub stat_getdata {
  return %average;
}

sub stat_getprofile {
  my ($self, $session) = @_;

  # Nothing to do if tracing is off.  But someone may call this anyway.
  return unless TRACE_PROFILE;

  # Return global profile if session isn't specified.
  return %profile unless defined $session;

  # Return a session profile, if the session resolves.
  my $resolved_session = $poe_kernel->_resolve_session( $session );
  return unless $resolved_session;

  # No need to avoid autovivification.  The session is guaranteed to
  # exist, so session cleanup will remove it anyway.
  return %{$profile_session{$resolved_session}};
}

sub stat_show_profile {
  POE::Kernel::_warn('<pr> ,----- Event Profile ' , ('-' x 53), ",\n");
  foreach (sort keys %profile) {
    POE::Kernel::_warn(
      sprintf "<pr> | %60.60s %9d  |\n", $_, $profile{$_}
    );
  }
  POE::Kernel::_warn '<pr> `', ('-' x 73), "'\n";
}

1;

__END__

=head1 NAME

POE::Resource::Statistics -- experimental run-time statistics for POE

=head1 SYNOPSIS

  my %stats = $poe_kernel->stat_getdata;
  printf "Idle = %3.2f\n", 100*$stats{avg_idle_seconds}/$stats{interval};

=head1 DESCRIPTION

POE::Resource::Statistics is a mix-in class for POE::Kernel.  It
provides features for gathering run-time statistics about POE::Kernel
and the applications that use it.

Statistics gathering is enabled with the TRACE_STATISTICS constant.
There is no run-time performance penalty when tracing is disabled.

Statistics are totaled every 30 seconds, and a rolling average is
maintained for the last two minutes.  The data may be retrieved at any
time with the stat_getdata() method.  Statistics will also be
displayed on the console shortly before POE::Kernel's run() returns.

The time() function is used to gather statistics over time.  If
Time::HiRes is available, it will be used automatically.  Otherwise
time is measured in whole seconds, and the resulting rounding errors
will make the statistics much less useful.

Run-time statistics gathering was added to POE 0.28.  It is considered
B<highly experimental>.  Please be advised that the statistics it
gathers are quite likely wrong.  They may in fact be useless.  The
reader is invited to investigate and improve the module's
methodologies.

=head1 Gathered Statistics

stat_getdata() returns a hashref with a small number of accumulated
values.  For each accumulator, there will be a corresponding field
prefixed "avg_" which is the rolling average for that accumulator.

=head2 blocked

C<blocked> contains the number of events (both user and kernel) which
were delayed due to a user event running for too long.  On conclusion
of the program, POE will display the blocked count.

In theory, one can compare C<blocked> with C<user_events> to determine
how much lag is produced by user code.  C<blocked> should be as low as
possible to ensure minimum user-generated event lag.

In practice, C<blocked> is often near or above C<user_events>.  Events
that are even the slightest bit late count as being "blocked".  See
C<blocked_seconds> for a potentially more useful metric.

=head2 blocked_seconds

C<blocked_seconds> contains the total number of seconds that events
waited in the queue beyond their nominal dispatch times.  The average
(C<avg_blocked_seconds>) is generally more useful.

=head2 idle_seconds

C<idle_seconds> is the amount of time that POE spent doing nothing at
all.  Typically this time is spent waiting for I/O or timers rather
than dispatching events.

=head2 interval

C<interval> is the average interval over which the statistics counters
are recorded.  This will typically be 30 seconds, but it can be more
if long-running user events prevent statistics from being gathered on
time.  C<interval> may also be less for programs that finish in under
half a minute.

C<avg_interval> may often be lower, as the very last measurement taken
before POE::Kernel's run() returns will almost always have an
C<interval> less than 30 seconds.

=head2 total_duration

C<total_duration> contains the total time over which the average was
calculated.  The "avg_" accumulators are averaged over a 2-minute
interval.  C<total_duration> may vary from 120 seconds due to the same
reasons as described in L</interval>.

=head2 user_events

C<user_events> contains the number of events that have been dispatched
to user code.  "User" events do not include POE's internal events,
although it will include events dispatched on behalf of wheels.

Shortly before POE::Kernel's run() returns, a C<user_load> value will
be computed showing the average number of user events that have been
dispatched per second.  A very active web server should have a high
C<user_load> value.  The higher the user load, the more important it
is to have small C<blocked> and C<blocked_seconds> values.

=head2 user_seconds

C<user_seconds> is the time that was spent handling user events,
including those handled by wheels.  C<user_seconds> + C<idle_seconds>
should typically add up to C<total_duration>.  Any difference is
unaccounted time in POE, and indicates a flaw in the statistics
gathering methodology.

=head1 SEE ALSO

See L<POE::Kernel/TRACE_STATISTICS> for instructions to enable
statistics gathering.

=head1 BUGS

Statistics may be highly inaccurate.  This feature is B<highly
experimental> and may change significantly over time.

=head1 AUTHORS & COPYRIGHTS

Contributed by Nick Williams <Nick.Williams@morganstanley.com>.

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
