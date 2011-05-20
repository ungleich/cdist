# Plain Perl signal handling is something shared by several event
# loops.  The invariant code has moved out here so that each loop may
# use it without reinventing it.  This will save maintenance and
# shrink the distribution.  Yay!

package POE::Loop::PerlSignals;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

# Everything plugs into POE::Kernel.
package POE::Kernel;

use strict;
use POE::Kernel;

# Flag so we know which signals are watched.  Used to reset those
# signals during finalization.
my %signal_watched;

#------------------------------------------------------------------------------
# Signal handlers/callbacks.

sub _loop_signal_handler_generic {
  if( USE_SIGNAL_PIPE ) {
    POE::Kernel->_data_sig_pipe_send( $_[0] );
  }
  else {
    _loop_signal_handler_generic_bottom( $_[0] );
  }
}

sub _loop_signal_handler_generic_bottom {
  if (TRACE_SIGNALS) {
    POE::Kernel::_warn "<sg> Enqueuing generic SIG$_[0] event";
  }

  $poe_kernel->_data_ev_enqueue(
    $poe_kernel, $poe_kernel, EN_SIGNAL, ET_SIGNAL, [ $_[0] ],
    __FILE__, __LINE__, undef, time()
  );
  $SIG{$_[0]} = \&_loop_signal_handler_generic;
}

##
sub _loop_signal_handler_pipe {
  if( USE_SIGNAL_PIPE ) {
    POE::Kernel->_data_sig_pipe_send( $_[0] );
  }
  else {
    _loop_signal_handler_pipe_bottom( $_[0] );
  }
}

sub _loop_signal_handler_pipe_bottom {
  if (TRACE_SIGNALS) {
    POE::Kernel::_warn "<sg> Enqueuing PIPE-like SIG$_[0] event";
  }

  $poe_kernel->_data_ev_enqueue(
    $poe_kernel, $poe_kernel, EN_SIGNAL, ET_SIGNAL, [ $_[0] ],
    __FILE__, __LINE__, undef, time()
  );
  $SIG{$_[0]} = \&_loop_signal_handler_pipe;
}

## only used under USE_SIGCHLD
sub _loop_signal_handler_chld {
  if( USE_SIGNAL_PIPE ) {
    POE::Kernel->_data_sig_pipe_send( 'CHLD' );
  }
  else {
    _loop_signal_handler_chld_bottom( $_[0] );
  }
}

sub _loop_signal_handler_chld_bottom {
  if (TRACE_SIGNALS) {
    POE::Kernel::_warn "<sg> Enqueuing CHLD-like SIG$_[0] event";
  }

  $poe_kernel->_data_sig_enqueue_poll_event($_[0]);
}

#------------------------------------------------------------------------------
# Signal handler maintenance functions.

sub loop_watch_signal {
  my ($self, $signal) = @_;

  $signal_watched{$signal} = 1;

  # Child process has stopped.
  if ($signal eq 'CHLD' or $signal eq 'CLD') {
    if ( USE_SIGCHLD ) {
      # Poll once for signals.  Will set the signal handler when done.
      $self->_data_sig_enqueue_poll_event($signal);
    } else {
      # We should never twiddle $SIG{CH?LD} under POE, unless we want to
      # override system() and friends. --hachi
      # $SIG{$signal} = "DEFAULT";
      $self->_data_sig_begin_polling($signal);
    }
    return;
  }

  # Broken pipe.
  if ($signal eq 'PIPE') {
    $SIG{$signal} = \&_loop_signal_handler_pipe;
    return;
  }

  # Everything else.
  $SIG{$signal} = \&_loop_signal_handler_generic;
}

sub loop_ignore_signal {
  my ($self, $signal) = @_;

  delete $signal_watched{$signal};

  if ($signal eq 'CHLD' or $signal eq 'CLD') {
    if ( USE_SIGCHLD ) {
      if( $self->_data_sig_child_procs) {
        # We need SIGCHLD to stay around after shutdown, so that
        # child processes may be reaped and kr_child_procs=0
        if (TRACE_SIGNALS) {
          POE::Kernel::_warn "<sg> Keeping SIG$signal anyway!";
        }
        return;
      }
    } else {
      $self->_data_sig_cease_polling();
      # We should never twiddle $SIG{CH?LD} under poe, unless we want to
      # override system() and friends. --hachi
      # $SIG{$signal} = "IGNORE";
      return;
    }
  }

  delete $signal_watched{$signal};

  my $state = 'DEFAULT';
  if ($signal eq 'PIPE') {
    $state = "IGNORE";
  }

  if (TRACE_SIGNALS) {
    POE::Kernel::_warn "<sg> $state SIG$signal";
  }
  $SIG{$signal} = $state;
}

sub loop_ignore_all_signals {
  my $self = shift;
  foreach my $signal (keys %signal_watched) {
    $self->loop_ignore_signal($signal);
  }
}

1;

__END__

=head1 NAME

POE::Loop::PerlSignals - common signal handling routines for POE::Loop bridges

=head1 SYNOPSIS

See L<POE::Loop>.

=head1 DESCRIPTION

POE::Loop::PerlSignals implements common code to handle signals for
many different event loops.  Most loops don't handle signals natively,
so this code has been abstracted into a reusable mix-in module.

POE::Loop::PerlSignals follows POE::Loop's public interface for signal
handling.  Therefore, please see L<POE::Loop> for more details.

=head1 SEE ALSO

L<POE>, L<POE::Loop>

=head1 AUTHORS & LICENSING

Please see L<POE> for more information about authors, contributors,
and POE's licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
