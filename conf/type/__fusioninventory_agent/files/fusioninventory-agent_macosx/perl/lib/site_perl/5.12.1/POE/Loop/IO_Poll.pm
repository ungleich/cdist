# IO::Poll event loop bridge for POE::Kernel.  The theory is that this
# will be faster for large scale applications.  This file is
# contributed by Matt Sergeant (baud).

# Empty package to appease perl.
package POE::Loop::IO_Poll;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

# Include common signal handling.
use POE::Loop::PerlSignals;

# Everything plugs into POE::Kernel;
package POE::Kernel;

=for poe_tests

sub skip_tests {
  return "IO::Poll is not 100% compatible with $^O" if $^O eq "MSWin32";
  return "IO::Poll tests require the IO::Poll module" if (
    do { eval "use IO::Poll"; $@ }
  );
}

=cut

use strict;

# Be sure we're using a contemporary version of IO::Poll.  There were
# issues with certain versios of IO::Poll prior to 0.05.  The latest
# version is 0.01, however.
use IO::Poll 0.01;

# Hand off to POE::Loop::Select if we're running under ActivePerl.
BEGIN {
  if ($^O eq "MSWin32") {
    warn "IO::Poll is defective on $^O.  Falling back to IO::Select.\n";
    require POE::Loop::Select;
    POE::Loop::Select->import();
    die "not really dying";
  }
}

use Errno qw(EINPROGRESS EWOULDBLOCK EINTR);

use IO::Poll qw(
  POLLRDNORM POLLWRNORM POLLRDBAND POLLERR POLLHUP POLLNVAL
);

# Many systems' IO::Poll don't define POLLRDNORM.
# Usually upgrading IO::Poll helps.
BEGIN {
  my $x = eval { POLLRDNORM };
  if ($@ or not defined $x) {
    warn(
      "Your IO::Poll doesn't define POLLRDNORM.  Falling back to IO::Select.\n"
    );
    require POE::Loop::Select;
    POE::Loop::Select->import();
    die "not really dying";
  }
}

my %poll_fd_masks;

# Allow $^T to change without affecting our internals.
my $start_time = $^T;

#------------------------------------------------------------------------------
# Loop construction and destruction.

sub loop_initialize {
  my $self = shift;
  %poll_fd_masks = ();
}

sub loop_finalize {
  my $self = shift;
  $self->loop_ignore_all_signals();
}

#------------------------------------------------------------------------------
# Signal handler maintenance functions.

sub loop_attach_uidestroy {
  # does nothing
}

#------------------------------------------------------------------------------
# Maintain time watchers.  For this loop, we simply save the next
# event time in a scalar.  loop_do_timeslice() will use the saved
# value.  A "paused" time watcher is just a timeout for some future
# time.

my $_next_event_time = time();

sub loop_resume_time_watcher {
  $_next_event_time = $_[1];
}

sub loop_reset_time_watcher {
  $_next_event_time = $_[1];
}

sub loop_pause_time_watcher {
  $_next_event_time = time() + 3600;
}

# A static function; not some object method.

sub mode_to_poll {
  return POLLRDNORM if $_[0] == MODE_RD;
  return POLLWRNORM if $_[0] == MODE_WR;
  return POLLRDBAND if $_[0] == MODE_EX;
  croak "unknown I/O mode $_[0]";
}

#------------------------------------------------------------------------------
# Maintain filehandle watchers.

sub loop_watch_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  my $type = mode_to_poll($mode);
  my $current = $poll_fd_masks{$fileno} || 0;
  my $new = $current | $type;

  if (TRACE_FILES) {
    POE::Kernel::_warn(
      sprintf(
        "<fh> Watch $fileno: " .
        "Current mask: 0x%02X - including 0x%02X = 0x%02X\n",
        $current, $type, $new
      )
    );
  }

  $poll_fd_masks{$fileno} = $new;
}

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

sub loop_pause_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  my $type = mode_to_poll($mode);
  my $current = $poll_fd_masks{$fileno} || 0;
  my $new = $current & ~$type;

  if (TRACE_FILES) {
    POE::Kernel::_warn(
      sprintf(
        "<fh> Pause $fileno: " .
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

sub loop_resume_filehandle {
  my ($self, $handle, $mode) = @_;
  my $fileno = fileno($handle);

  my $type = mode_to_poll($mode);
  my $current = $poll_fd_masks{$fileno} || 0;
  my $new = $current | $type;

  if (TRACE_FILES) {
    POE::Kernel::_warn(
      sprintf(
        "<fh> Resume $fileno: " .
        "Current mask: 0x%02X - including 0x%02X = 0x%02X\n",
        $current, $type, $new
      )
    );
  }

  $poll_fd_masks{$fileno} = $new;
}

#------------------------------------------------------------------------------
# The event loop itself.

sub loop_do_timeslice {
  my $self = shift;

  # Check for a hung kernel.
  $self->_test_if_kernel_is_idle();

  # Set the poll timeout based on current queue conditions.  If there
  # are FIFO events, then the poll timeout is zero and move on.
  # Otherwise set the poll timeout until the next pending event, if
  # there are any.  If nothing is waiting, set the timeout for some
  # constant number of seconds.

  my $timeout = $_next_event_time;

  my $now = time();
  if (defined $timeout) {
    $timeout -= $now;
    $timeout = 0 if $timeout < 0;
  }
  else {
    die "shouldn't happen" if ASSERT_DATA;
    $timeout = 3600;
  }

  if (TRACE_EVENTS) {
    POE::Kernel::_warn(
      '<ev> Kernel::run() iterating.  ' .
      sprintf(
        "now(%.4f) timeout(%.4f) then(%.4f)\n",
        $now-$start_time, $timeout, ($now-$start_time)+$timeout
       )
    );
  }

  if (TRACE_FILES) {
    foreach (sort { $a<=>$b} keys %poll_fd_masks) {
      my @types;
      push @types, "plain-file"        if -f;
      push @types, "directory"         if -d;
      push @types, "symlink"           if -l;
      push @types, "pipe"              if -p;
      push @types, "socket"            if -S;
      push @types, "block-special"     if -b;
      push @types, "character-special" if -c;
      push @types, "tty"               if -t;
      my @modes;
      my $flags = $poll_fd_masks{$_};
      push @modes, 'r' if $flags & (POLLRDNORM | POLLHUP | POLLERR);
      push @modes, 'w' if $flags & (POLLWRNORM | POLLHUP | POLLERR);
      push @modes, 'x' if $flags & (POLLRDBAND | POLLHUP | POLLERR);
      POE::Kernel::_warn(
        "<fh> file descriptor $_ = modes(@modes) types(@types)\n"
      );
    }
  }

  # Avoid looking at filehandles if we don't need to.
  # TODO The added code to make this sleep is non-optimal.  There is a
  # way to do this in fewer tests.

  if (scalar keys %poll_fd_masks) {

    # There are filehandles to poll, so do so.

    # Check filehandles, or wait for a period of time to elapse.
    my $hits = IO::Poll::_poll($timeout * 1000, my @results = %poll_fd_masks);

    if (ASSERT_FILES) {
      if ($hits < 0) {
        POE::Kernel::_trap("<fh> poll returned $hits (error): $!")
          unless ( ($! == EINPROGRESS) or
                   ($! == EWOULDBLOCK) or
                   ($! == EINTR) or
                   ($! == 0)      # SIGNAL_PIPE strangeness
                 );
      }
    }

    if (TRACE_FILES) {
      if ($hits > 0) {
        POE::Kernel::_warn "<fh> poll hits = $hits\n";
      }
      elsif ($hits == 0) {
        POE::Kernel::_warn "<fh> poll timed out...\n";
      }
    }

    # If poll has seen filehandle activity, then gather up the
    # active filehandles and synchronously dispatch events to the
    # appropriate handlers.

    if ($hits > 0) {

      # This is where they're gathered.

      my (@rd_ready, @wr_ready, @ex_ready);
      my %poll_fd_results = @results;
      while (my ($fd, $got_mask) = each %poll_fd_results) {
        next unless $got_mask;

        my $watch_mask = $poll_fd_masks{$fd};
        if (
          $watch_mask & POLLRDNORM and
          $got_mask & (POLLRDNORM | POLLHUP | POLLERR | POLLNVAL)
        ) {
          if (TRACE_FILES) {
            POE::Kernel::_warn "<fh> enqueuing read for fileno $fd";
          }

          push @rd_ready, $fd;
        }

        if (
          $watch_mask & POLLWRNORM and
          $got_mask & (POLLWRNORM | POLLHUP | POLLERR | POLLNVAL)
        ) {
          if (TRACE_FILES) {
            POE::Kernel::_warn "<fh> enqueuing write for fileno $fd";
          }

          push @wr_ready, $fd;
        }

        if (
          $watch_mask & POLLRDBAND and
          $got_mask & (POLLRDBAND | POLLHUP | POLLERR | POLLNVAL)
        ) {
          if (TRACE_FILES) {
            POE::Kernel::_warn "<fh> enqueuing expedite for fileno $fd";
          }

          push @ex_ready, $fd;
        }
      }

      @rd_ready and $self->_data_handle_enqueue_ready(MODE_RD, @rd_ready);
      @wr_ready and $self->_data_handle_enqueue_ready(MODE_WR, @wr_ready);
      @ex_ready and $self->_data_handle_enqueue_ready(MODE_EX, @ex_ready);
    }
  }
  elsif ($timeout) {

    # No filehandles to poll on.  Try to sleep instead.  Use sleep()
    # itself on MSWin32.  Use a dummy four-argument select() everywhere
    # else.

    if ($^O eq 'MSWin32') {
      sleep($timeout);
    }
    else {
      CORE::select(undef, undef, undef, $timeout);
    }
  }

  if (TRACE_STATISTICS) {
    $self->_data_stat_add('idle_seconds', time() - $now);
  }

  # Dispatch whatever events are due.
  $self->_data_ev_dispatch_due();
}

### Run for as long as there are sessions to service.

sub loop_run {
  my $self = shift;
  while ($self->_data_ses_count()) {
    $self->loop_do_timeslice();
  }
}

sub loop_halt {
  # does nothing
}

1;

__END__

=head1 NAME

POE::Loop::IO_Poll - a bridge that allows POE to be driven by IO::Poll

=head1 SYNOPSIS

See L<POE::Loop>.

=head1 DESCRIPTION

POE::Loop::IO_Poll implements the interface documented in L<POE::Loop>.
Therefore it has no documentation of its own.  Please see L<POE::Loop>
for more details.

=head1 SEE ALSO

L<POE>, L<POE::Loop>, L<IO::Poll>, L<POE::Loop::PerlSignals>

=head1 AUTHORS & LICENSING

Please see L<POE> for more information about authors, contributors,
and POE's licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
