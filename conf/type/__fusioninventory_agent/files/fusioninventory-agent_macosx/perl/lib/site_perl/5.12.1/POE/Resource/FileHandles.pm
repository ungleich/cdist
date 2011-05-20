# Manage file handles, associated descriptors, and read/write modes
# thereon.

package POE::Resource::FileHandles;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

# These methods are folded into POE::Kernel;
package POE::Kernel;

use strict;

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use IO::Handle ();
use FileHandle ();

### Some portability things.

# Provide dummy constants so things at least compile.  These constants
# aren't used if we're RUNNING_IN_HELL, but Perl needs to see them.

BEGIN {
  # older perls than 5.10 needs a kick in the arse to AUTOLOAD the constant...
  eval "F_GETFL" if $] < 5.010;

  if ( ! defined &Fcntl::F_GETFL ) {
    if ( ! defined prototype "F_GETFL" ) {
      *F_GETFL = sub { 0 };
      *F_SETFL = sub { 0 };
    } else {
      *F_GETFL = sub () { 0 };
      *F_SETFL = sub () { 0 };
    }
  }
}

### A local reference to POE::Kernel's queue.

my $kr_queue;

### Fileno structure.  This tracks the sessions that are watching a
### file, by its file number.  It used to track by file handle, but
### several handles can point to the same underlying fileno.  This is
### more unique.

my %kr_filenos;
BEGIN { $poe_kernel->[KR_FILENOS] = \%kr_filenos; }

sub FNO_MODE_RD      () { MODE_RD } # [ [ (fileno read mode structure)
# --- BEGIN SUB STRUCT 1 ---        #
sub FMO_REFCOUNT     () { 0      }  #     $fileno_total_use_count,
sub FMO_ST_ACTUAL    () { 1      }  #     $requested_file_state (see HS_PAUSED)
sub FMO_SESSIONS     () { 2      }  #     { $session_watching_this_handle =>
                                    #       { $handle_watched_as =>
# --- BEGIN SUB STRUCT 2 ---        #
sub HSS_HANDLE       () { 0      }  #         [ $blessed_handle,
sub HSS_SESSION      () { 1      }  #           $blessed_session,
sub HSS_STATE        () { 2      }  #           $event_name,
sub HSS_ARGS         () { 3      }  #           \@callback_arguments
                                    #         ],
                                    #       },
# --- CEASE SUB STRUCT 2 ---        #     },
# --- CEASE SUB STRUCT 1 ---        #   ],
                                    #
sub FNO_MODE_WR      () { MODE_WR } #   [ (write mode structure is the same)
                                    #   ],
                                    #
sub FNO_MODE_EX      () { MODE_EX } #   [ (expedite mode struct is the same)
                                    #   ],
                                    #
sub FNO_TOT_REFCOUNT () { 3      }  #   $total_number_of_file_watchers,
                                    # ]

### These are the values for FMO_ST_ACTUAL.

sub HS_STOPPED   () { 0x00 }   # The file has stopped generating events.
sub HS_PAUSED    () { 0x01 }   # The file temporarily stopped making events.
sub HS_RUNNING   () { 0x02 }   # The file is running and can generate events.

### Handle to session.

my %kr_ses_to_handle;

                            #    { $session =>
                            #      $handle =>
# --- BEGIN SUB STRUCT ---  #        [
sub SH_HANDLE     () {  0 } #          $blessed_file_handle,
sub SH_REFCOUNT   () {  1 } #          $total_reference_count,
sub SH_MODECOUNT  () {  2 } #          [ $read_reference_count,     (MODE_RD)
                            #            $write_reference_count,    (MODE_WR)
                            #            $expedite_reference_count, (MODE_EX)
# --- CEASE SUB STRUCT ---  #          ],
                            #        ],
                            #        ...
                            #      },
                            #    },

### Begin-run initialization.

sub _data_handle_initialize {
  my ($self, $queue) = @_;
  $kr_queue = $queue;
}

### End-run leak checking.

sub _data_handle_finalize {
  my $finalized_ok = 1;

  while (my ($fd, $fd_rec) = each(%kr_filenos)) {
    my ($rd, $wr, $ex, $tot) = @$fd_rec;
    $finalized_ok = 0;

    _warn "!!! Leaked fileno: $fd (total refcnt=$tot)\n";

    _warn(
      "!!!\tRead:\n",
      "!!!\t\trefcnt  = $rd->[FMO_REFCOUNT]\n",
    );
    while (my ($ses, $ses_rec) = each(%{$rd->[FMO_SESSIONS]})) {
      _warn "!!!\t\tsession = $ses\n";
      while (my ($handle, $hnd_rec) = each(%{$ses_rec})) {
        _warn(
          "!!!\t\t\thandle  = $hnd_rec->[HSS_HANDLE]\n",
          "!!!\t\t\tsession = $hnd_rec->[HSS_SESSION]\n",
          "!!!\t\t\tevent   = $hnd_rec->[HSS_STATE]\n",
          "!!!\t\t\targs    = (@{$hnd_rec->[HSS_ARGS]})\n",
        );
      }
    }

    _warn(
      "!!!\tWrite:\n",
      "!!!\t\trefcnt  = $wr->[FMO_REFCOUNT]\n",
    );
    while (my ($ses, $ses_rec) = each(%{$wr->[FMO_SESSIONS]})) {
      _warn "!!!\t\tsession = $ses\n";
      while (my ($handle, $hnd_rec) = each(%{$ses_rec})) {
        _warn(
          "!!!\t\t\thandle  = $hnd_rec->[HSS_HANDLE]\n",
          "!!!\t\t\tsession = $hnd_rec->[HSS_SESSION]\n",
          "!!!\t\t\tevent   = $hnd_rec->[HSS_STATE]\n",
          "!!!\t\t\targs    = (@{$hnd_rec->[HSS_ARGS]})\n",
        );
      }
    }

    _warn(
      "!!!\tException:\n",
      "!!!\t\trefcnt  = $ex->[FMO_REFCOUNT]\n",
    );
    while (my ($ses, $ses_rec) = each(%{$ex->[FMO_SESSIONS]})) {
      _warn "!!!\t\tsession = $ses\n";
      while (my ($handle, $hnd_rec) = each(%{$ses_rec})) {
        _warn(
          "!!!\t\t\thandle  = $hnd_rec->[HSS_HANDLE]\n",
          "!!!\t\t\tsession = $hnd_rec->[HSS_SESSION]\n",
          "!!!\t\t\tevent   = $hnd_rec->[HSS_STATE]\n",
          "!!!\t\t\targs    = (@{$hnd_rec->[HSS_ARGS]})\n",
        );
      }
    }
  }

  while (my ($ses, $hnd_rec) = each(%kr_ses_to_handle)) {
    $finalized_ok = 0;
    _warn "!!! Leaked handle in $ses\n";
    while (my ($hnd, $rc) = each(%$hnd_rec)) {
      _warn(
        "!!!\tHandle: $hnd (tot refcnt=$rc->[SH_REFCOUNT])\n",
        "!!!\t\tRead      refcnt: $rc->[SH_MODECOUNT]->[MODE_RD]\n",
        "!!!\t\tWrite     refcnt: $rc->[SH_MODECOUNT]->[MODE_WR]\n",
        "!!!\t\tException refcnt: $rc->[SH_MODECOUNT]->[MODE_EX]\n",
      );
    }
  }

  return $finalized_ok;
}

### Enqueue "select" events for a list of file descriptors in a given
### access mode.

sub _data_handle_enqueue_ready {
  my ($self, $mode) = splice(@_, 0, 2);

  my $now = time();
  foreach my $fileno (@_) {
    if (ASSERT_DATA) {
      _trap "internal inconsistency: undefined fileno" unless defined $fileno;
    }

    # By-pass the event queue for things that come over the pipe:
    # this reduces signal latency
    if( USE_SIGNAL_PIPE ) {
      # _warn "fileno=$fileno signal_pipe_read=$POE::Kernel::signal_pipe_read_fd";
      if( $fileno == $POE::Kernel::signal_pipe_read_fd ) {
        $self->_data_sig_pipe_read( $fileno, $mode );
        next;
      }
    }

    # Avoid autoviviying an empty $kr_filenos record if the fileno has
    # been deactivated.  This can happen if a file descriptor is ready
    # in multiple modes, and an earlier dispatch removes it before a
    # later dispatch happens.
    next unless exists $kr_filenos{$fileno};

    # Gather and dispatch all the events for this fileno/mode pair.

    foreach my $select (
      map { values %$_ }
      values %{ $kr_filenos{$fileno}[$mode][FMO_SESSIONS] }
    ) {
      $self->_dispatch_event(
        $select->[HSS_SESSION], $select->[HSS_SESSION],
        $select->[HSS_STATE], ET_SELECT, [
          $select->[HSS_HANDLE],  # EA_SEL_HANDLE
          $mode,                  # EA_SEL_MODE
          @{$select->[HSS_ARGS]}, # EA_SEL_ARGS
        ],
        __FILE__, __LINE__, undef, $now, -__LINE__
      );
    }
  }

  $self->_data_ses_gc_sweep();
}

### Test whether POE is tracking a file handle.

sub _data_handle_is_good {
  my ($self, $handle, $mode) = @_;

  # Don't bother if the kernel isn't tracking the file.
  return 0 unless exists $kr_filenos{fileno $handle};

  # Don't bother if the kernel isn't tracking the file mode.
  return 0 unless $kr_filenos{fileno $handle}->[$mode]->[FMO_REFCOUNT];

  return 1;
}

### Add a select to the session, and possibly begin a watcher.

sub _data_handle_add {
  my ($self, $handle, $mode, $session, $event, $args) = @_;
  my $fd = fileno($handle);

  # First time watching the file descriptor.  Do some heavy setup.
  #
  # NB - This means we can't optimize away the delete() calls here and
  # there, because they probably ensure that the structure exists.
  unless (exists $kr_filenos{$fd}) {

    $kr_filenos{$fd} =
      [ [ 0,          # FMO_REFCOUNT    MODE_RD
          HS_PAUSED,  # FMO_ST_ACTUAL
          { },        # FMO_SESSIONS
        ],
        [ 0,          # FMO_REFCOUNT    MODE_WR
          HS_PAUSED,  # FMO_ST_ACTUAL
          { },        # FMO_SESSIONS
        ],
        [ 0,          # FMO_REFCOUNT    MODE_EX
          HS_PAUSED,  # FMO_ST_ACTUAL
          { },        # FMO_SESSIONS
        ],
        0,            # FNO_TOT_REFCOUNT
      ];

    if (TRACE_FILES) {
      _warn "<fh> adding $handle fd ($fd) in mode ($mode)";
    }

    $self->_data_handle_condition( $handle );
  }

  # Cache some high-level lookups.
  my $kr_fileno  = $kr_filenos{$fd};
  my $kr_fno_rec = $kr_fileno->[$mode];

  # The session is already watching this fileno in this mode.

  if ($kr_fno_rec->[FMO_SESSIONS]->{$session}) {

    # The session is also watching it by the same handle.  Treat this
    # as a "resume" in this mode.

    if (exists $kr_fno_rec->[FMO_SESSIONS]->{$session}->{$handle}) {
      if (TRACE_FILES) {
        _warn("<fh> running $handle fileno($fd) mode($mode)");
      }
      $self->loop_resume_filehandle($handle, $mode);
      $kr_fno_rec->[FMO_ST_ACTUAL] = HS_RUNNING;
    }

    # The session is watching it by a different handle.  It can't be
    # done yet, but maybe later when drivers are added to the mix.
    #
    # TODO - This can occur if someone closes a filehandle without
    # calling select_foo() to deregister it from POE.  In that case,
    # the operating system reuses the file descriptor, but we still
    # have something registered for it here.

    else {
      foreach my $watch_session (keys %{$kr_fno_rec->[FMO_SESSIONS]}) {
        foreach my $hdl_rec (
          values %{$kr_fno_rec->[FMO_SESSIONS]->{$watch_session}}
        ) {
          my $other_handle = $hdl_rec->[HSS_HANDLE];

          my $why;
          unless (defined(fileno $other_handle)) {
            $why = "closed";
          }
          elsif (fileno($handle) == fileno($other_handle)) {
            $why = "open";
          }
          else {
            $why = "open with different file descriptor";
          }

          if ($session eq $watch_session) {
            _die(
              "A session was caught watching two different file handles that\n",
              "reference the same file descriptor in the same mode ($mode).\n",
              "This error is usually caused by a file descriptor leak.  The\n",
              "most common cause is explicitly closing a filehandle without\n",
              "first unregistering it from POE.\n",
              "\n",
              "Some possibly helpful information:\n",
              "  Session    : ", $self->_data_alias_loggable($session), "\n",
              "  Old handle : $other_handle (currently $why)\n",
              "  New handle : $handle\n",
              "\n",
              "Please correct the program and try again.\n",
            );
          }
          else {
            _die(
              "Two sessions were caught watching the same file descriptor\n",
              "in the same mode ($mode).  This error is usually caused by\n",
              "a file descriptor leak.  The most common cause is explicitly\n",
              "closing a filehandle without first unregistering it from POE.\n",
              "\n",
              "Some possibly helpful information:\n",
              "  Old session: ",
              $self->_data_alias_loggable($hdl_rec->[HSS_SESSION]), "\n",
              "  Old handle : $other_handle (currently $why)\n",
              "  New session: ", $self->_data_alias_loggable($session), "\n",
              "  New handle : $handle\n",
              "\n",
              "Please correct the program and try again.\n",
            );
          }
        }
      }
      _trap "internal inconsistency";
    }
  }

  # The session is not watching this fileno in this mode.  Record
  # the session/handle pair.

  else {
    $kr_fno_rec->[FMO_SESSIONS]->{$session}->{$handle} = [
      $handle,   # HSS_HANDLE
      $session,  # HSS_SESSION
      $event,    # HSS_STATE
      $args,     # HSS_ARGS
    ];

    # Fix reference counts.
    $kr_fileno->[FNO_TOT_REFCOUNT]++;
    $kr_fno_rec->[FMO_REFCOUNT]++;

    # If this is the first time a file is watched in this mode, then
    # have the event loop bridge watch it.

    if ($kr_fno_rec->[FMO_REFCOUNT] == 1) {
      $self->loop_watch_filehandle($handle, $mode);
      $kr_fno_rec->[FMO_ST_ACTUAL]  = HS_RUNNING;
    }
  }

  # If the session hasn't already been watching the filehandle, then
  # register the filehandle in the session's structure.

  unless (exists $kr_ses_to_handle{$session}->{$handle}) {
    $kr_ses_to_handle{$session}->{$handle} = [
      $handle,  # SH_HANDLE
      0,        # SH_REFCOUNT
      [ 0,      # SH_MODECOUNT / MODE_RD
        0,      # SH_MODECOUNT / MODE_WR
        0       # SH_MODECOUNT / MODE_EX
      ]
    ];
    $self->_data_ses_refcount_inc($session);
  }

  # Modify the session's handle structure's reference counts, so the
  # session knows it has a reason to live.

  my $ss_handle = $kr_ses_to_handle{$session}->{$handle};
  unless ($ss_handle->[SH_MODECOUNT]->[$mode]) {
    $ss_handle->[SH_MODECOUNT]->[$mode]++;
    $ss_handle->[SH_REFCOUNT]++;
  }
}

### Condition a file handle so that it is ready for select et al
sub _data_handle_condition {
    my( $self, $handle ) = @_;

    # For DOSISH systems like OS/2.  Wrapped in eval{} in case it's a
    # tied handle that doesn't support binmode.
    eval { binmode *$handle };

    # Turn off blocking unless it's tied or a plain file.
    unless (tied *$handle or -f $handle) {

      unless (RUNNING_IN_HELL) {
        if ($] >= 5.008) {
          $handle->blocking(0);
        }
        else {
          # Long, drawn out, POSIX way.
          my $flags = fcntl($handle, F_GETFL, 0)
            or _trap "fcntl($handle, F_GETFL, 0) fails: $!\n";
          until (fcntl($handle, F_SETFL, $flags | O_NONBLOCK)) {
            _trap(
              "fcntl($handle [" . fileno($handle) . "], F_SETFL [" .
              F_SETFL . "], $flags | O_NONBLOCK [" . O_NONBLOCK .
              "]) fails: $!"
            ) unless $! == EAGAIN or $! == EWOULDBLOCK;
          }
        }
      }
      else {
        # Do it the Win32 way.
        my $set_it = "1";

        # 126 is FIONBIO (some docs say 0x7F << 16)
        ioctl(
          $handle,
          0x80000000 | (4 << 16) | (ord('f') << 8) | 126,
          \$set_it
        ) or _trap(
          "ioctl($handle, FIONBIO, $set_it) fails: errno " . ($!+0) . " = $!\n"
        );
      }
    }

    # Turn off buffering.
    CORE::select((CORE::select($handle), $| = 1)[0]);
}



### Remove a select from the kernel, and possibly trigger the
### session's destruction.

sub _data_handle_remove {
  my ($self, $handle, $mode, $session) = @_;
  my $fd = fileno($handle);

  # Make sure the handle is deregistered with the kernel.

  if (defined($fd) and exists($kr_filenos{$fd})) {
    my $kr_fileno  = $kr_filenos{$fd};
    my $kr_fno_rec = $kr_fileno->[$mode];

    # Make sure the handle was registered to the requested session.

    if (
      exists($kr_fno_rec->[FMO_SESSIONS]->{$session}) and
      exists($kr_fno_rec->[FMO_SESSIONS]->{$session}->{$handle})
    ) {

      TRACE_FILES and
        _warn(
          "<fh> removing handle ($handle) fileno ($fd) mode ($mode) from " .
          Carp::shortmess
        );

      # Remove the handle from the kernel's session record.

      my $handle_rec =
        delete $kr_fno_rec->[FMO_SESSIONS]->{$session}->{$handle};

      my $kill_session = $handle_rec->[HSS_SESSION];
      my $kill_event   = $handle_rec->[HSS_STATE];

      # Remove any events destined for that handle.
      my $my_select = sub {
        return 0 unless $_[0]->[EV_TYPE]    &  ET_SELECT;
        return 0 unless $_[0]->[EV_SESSION] == $kill_session;
        return 0 unless $_[0]->[EV_NAME]    eq $kill_event;
        return 0 unless $_[0]->[EV_ARGS]->[EA_SEL_HANDLE] == $handle;
        return 0 unless $_[0]->[EV_ARGS]->[EA_SEL_MODE]   == $mode;
        return 1;
      };

      foreach ($kr_queue->remove_items($my_select)) {
        my ($time, $id, $event) = @$_;
        $self->_data_ev_refcount_dec( @$event[EV_SESSION, EV_SOURCE] );

        TRACE_EVENTS and _warn(
          "<ev> removing select event $id ``$event->[EV_NAME]''" .
          Carp::shortmess
        );
      }

      # Decrement the handle's reference count.

      $kr_fno_rec->[FMO_REFCOUNT]--;

      if (ASSERT_DATA) {
        _trap "<dt> fileno mode refcount went below zero"
          if $kr_fno_rec->[FMO_REFCOUNT] < 0;
      }

      # If the "mode" count drops to zero, then stop selecting the
      # handle.

      unless ($kr_fno_rec->[FMO_REFCOUNT]) {
        $self->loop_ignore_filehandle($handle, $mode);
        $kr_fno_rec->[FMO_ST_ACTUAL]  = HS_STOPPED;

        # The session is not watching handles anymore.  Remove the
        # session entirely the fileno structure.
        delete $kr_fno_rec->[FMO_SESSIONS]->{$session}
          unless keys %{$kr_fno_rec->[FMO_SESSIONS]->{$session}};
      }

      # Decrement the kernel record's handle reference count.  If the
      # handle is done being used, then delete it from the kernel's
      # record structure.  This initiates Perl's garbage collection on
      # it, as soon as whatever else in "user space" frees it.

      $kr_fileno->[FNO_TOT_REFCOUNT]--;

      if (ASSERT_DATA) {
        _trap "<dt> fileno refcount went below zero"
          if $kr_fileno->[FNO_TOT_REFCOUNT] < 0;
      }

      unless ($kr_fileno->[FNO_TOT_REFCOUNT]) {
        if (TRACE_FILES) {
          _warn "<fh> deleting handle ($handle) fileno ($fd) entirely";
        }
        delete $kr_filenos{$fd};
      }
    }
    elsif (TRACE_FILES) {
      _warn(
        "<fh> session doesn't own handle ($handle) fileno ($fd) mode ($mode)"
      );
    }
  }
  elsif (TRACE_FILES) {
    _warn(
      "<fh> handle ($handle) fileno ($fd) is not registered with POE::Kernel"
    );
  }

  # SS_HANDLES - Remove the select from the session, assuming there is
  # a session to remove it from.  TODO Key it on fileno?

  if (
    exists($kr_ses_to_handle{$session}) and
    exists($kr_ses_to_handle{$session}->{$handle})
  ) {

    # Remove it from the session's read, write or expedite mode.

    my $ss_handle = $kr_ses_to_handle{$session}->{$handle};
    if ($ss_handle->[SH_MODECOUNT]->[$mode]) {

      # Hmm... what is this?  Was POE going to support multiple selects?

      $ss_handle->[SH_MODECOUNT]->[$mode] = 0;

      # Decrement the reference count, and delete the handle if it's done.

      $ss_handle->[SH_REFCOUNT]--;

      if (ASSERT_DATA) {
        _trap "<dt> refcount went below zero"
          if $ss_handle->[SH_REFCOUNT] < 0;
      }

      unless ($ss_handle->[SH_REFCOUNT]) {
        delete $kr_ses_to_handle{$session}->{$handle};
        $self->_data_ses_refcount_dec($session);
        delete $kr_ses_to_handle{$session}
          unless keys %{$kr_ses_to_handle{$session}};
      }
    }
    elsif (TRACE_FILES) {
      _warn(
        "<fh> handle ($handle) fileno ($fd) is not registered with",
        $self->_data_alias_loggable($session)
      );
    }
  }
}

### Resume a filehandle.  If there are no events in the queue for this
### handle/mode pair, then we go ahead and set the actual state now.
### Otherwise it must wait until the queue empties.

sub _data_handle_resume {
  my ($self, $handle, $mode) = @_;

  my $kr_fileno = $kr_filenos{fileno($handle)};
  my $kr_fno_rec = $kr_fileno->[$mode];

  if (TRACE_FILES) {
    _warn(
      "<fh> resume test: $handle fileno(" . fileno($handle) . ") mode($mode)"
    );
  }

  $self->loop_resume_filehandle($handle, $mode);
  $kr_fno_rec->[FMO_ST_ACTUAL] = HS_RUNNING;
}

### Pause a filehandle.  If there are no events in the queue for this
### handle/mode pair, then we go ahead and set the actual state now.
### Otherwise it must wait until the queue empties.

sub _data_handle_pause {
  my ($self, $handle, $mode) = @_;

  my $kr_fileno = $kr_filenos{fileno($handle)};
  my $kr_fno_rec = $kr_fileno->[$mode];

  if (TRACE_FILES) {
    _warn(
      "<fh> pause test: $handle fileno(" . fileno($handle) . ") mode($mode)"
    );
  }

  $self->loop_pause_filehandle($handle, $mode);
  $kr_fno_rec->[FMO_ST_ACTUAL] = HS_PAUSED;
}

### Return the number of active filehandles in the entire system.

sub _data_handle_count {
  return scalar keys %kr_filenos;
}

### Return the number of active handles for a single session.

sub _data_handle_count_ses {
  my ($self, $session) = @_;
  return 0 unless exists $kr_ses_to_handle{$session};
  return scalar keys %{$kr_ses_to_handle{$session}};
}

### Clear all the handles owned by a session.

sub _data_handle_clear_session {
  my ($self, $session) = @_;
  return unless exists $kr_ses_to_handle{$session}; # avoid autoviv
  my @handles = values %{$kr_ses_to_handle{$session}};
  foreach (@handles) {
    my $handle = $_->[SH_HANDLE];
    my $refcount = $_->[SH_MODECOUNT];

    $self->_data_handle_remove($handle, MODE_RD, $session)
      if $refcount->[MODE_RD];
    $self->_data_handle_remove($handle, MODE_WR, $session)
      if $refcount->[MODE_WR];
    $self->_data_handle_remove($handle, MODE_EX, $session)
      if $refcount->[MODE_EX];
  }
}

# TODO Testing accessors.  Maybe useful for introspection.  May need
# modification before that.

sub _data_handle_fno_refcounts {
  my ($self, $fd) = @_;
  return(
    $kr_filenos{$fd}->[FNO_TOT_REFCOUNT],
    $kr_filenos{$fd}->[FNO_MODE_RD]->[FMO_REFCOUNT],
    $kr_filenos{$fd}->[FNO_MODE_WR]->[FMO_REFCOUNT],
    $kr_filenos{$fd}->[FNO_MODE_EX]->[FMO_REFCOUNT],
  )
}

sub _data_handle_fno_states {
  my ($self, $fd) = @_;
  return(
    $kr_filenos{$fd}->[FNO_MODE_RD]->[FMO_ST_ACTUAL],
    $kr_filenos{$fd}->[FNO_MODE_WR]->[FMO_ST_ACTUAL],
    $kr_filenos{$fd}->[FNO_MODE_EX]->[FMO_ST_ACTUAL],
  );
}

sub _data_handle_fno_sessions {
  my ($self, $fd) = @_;

  return(
    $kr_filenos{$fd}->[FNO_MODE_RD]->[FMO_SESSIONS],
    $kr_filenos{$fd}->[FNO_MODE_WR]->[FMO_SESSIONS],
    $kr_filenos{$fd}->[FNO_MODE_EX]->[FMO_SESSIONS],
  );
}

sub _data_handle_handles {
  my $self = shift;
  return %kr_ses_to_handle;
}

1;

__END__

=head1 NAME

POE::Resource::FileHandles - internal filehandle manager for POE::Kernel

=head1 SYNOPSIS

There is no public API.

=head1 DESCRIPTION

POE::Resource::FileHandles is a mix-in class for POE::Kernel.  It
provides the low-level features to manage filehandles.  It is used
internally by POE::Kernel, so it has no public interface.

=head1 SEE ALSO

See L<POE::Kernel/I/O Watchers (Selects)> for the public file watcher
API.

See L<POE::Kernel/Resources> for for public information about POE
resources.

See L<POE::Resource> for general discussion about resources and the
classes that manage them.

=head1 BUGS

POE watches I/O based on filehandles rather than file descriptors,
which means there can be clashes between its API and an underlying
descriptor-based event loop.  This is usually not a problem, but it
may require a work-around in certain edge cases.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
