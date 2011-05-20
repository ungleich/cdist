# The data necessary to manage tagged extra/external reference counts
# on sessions, and the accessors to get at them sanely from other
# files.

package POE::Resource::Extrefs;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

# These methods are folded into POE::Kernel;
package POE::Kernel;

use strict;

### The count of all extra references used in the system.

my %kr_extra_refs;
#  ( $session =>
#    { $tag => $count,
#       ...,
#     },
#     ...,
#   );

### End-run leak checking.

sub _data_extref_finalize {
  my $finalized_ok = 1;
  foreach my $session (keys %kr_extra_refs) {
    $finalized_ok = 0;
    _warn "!!! Leaked extref: $session\n";
    foreach my $tag (keys %{$kr_extra_refs{$session}}) {
      _warn "!!!\t`$tag' = $kr_extra_refs{$session}->{$tag}\n";
    }
  }
  return $finalized_ok;
}

# Increment a session's tagged reference count.  If this is the first
# time the tag is used in the session, then increment the session's
# reference count as well.  Returns the tag's new reference count.
#
# TODO Allows incrementing reference counts on sessions that don't
# exist, but the public interface catches that.
#
# TODO Need to track extref ownership for signal-based session
# termination.  One problem seen is that signals terminate sessions
# out of order.  Owners think extra refcounts exist for sessions that
# are no longer around.  Ownership trees give us a few benefits: We
# can make sure sessions destruct in a cleaner order.  We can detect
# refcount loops and possibly prevent that.

sub _data_extref_inc {
  my ($self, $session, $tag) = @_;
  my $refcount = ++$kr_extra_refs{$session}->{$tag};

  # TODO We could probably get away with only incrementing the
  # session's master refcount once, as long as any extra refcount is
  # positive.  Then the session reference count would be a flag
  # instead of a counter.
  $self->_data_ses_refcount_inc($session) if $refcount == 1;

  if (TRACE_REFCNT) {
    _warn(
      "<rc> incremented extref ``$tag'' (now $refcount) for ",
      $self->_data_alias_loggable($session)
    );
  }

  return $refcount;
}

# Decrement a session's tagged reference count, removing it outright
# if the count reaches zero.  Return the new reference count or undef
# if the tag doesn't exist.
#
# TODO Allows negative reference counts, and the resulting hilarity.
# Hopefully the public interface won't allow it.

sub _data_extref_dec {
  my ($self, $session, $tag) = @_;

  if (ASSERT_DATA) {
    # Prevents autoviv.
    _trap("<dt> decrementing extref for session without any")
      unless exists $kr_extra_refs{$session};

    unless (exists $kr_extra_refs{$session}->{$tag}) {
      _trap(
        "<dt> decrementing extref for nonexistent tag ``$tag'' in ",
        $self->_data_alias_loggable($session)
      );
    }
  }

  my $refcount = --$kr_extra_refs{$session}->{$tag};

  if (TRACE_REFCNT) {
    _warn(
      "<rc> decremented extref ``$tag'' (now $refcount) for ",
      $self->_data_alias_loggable($session)
    );
  }

  $self->_data_extref_remove($session, $tag) unless $refcount;
  return $refcount;
}

### Remove an extra reference from a session, regardless of its count.

sub _data_extref_remove {
  my ($self, $session, $tag) = @_;

  if (ASSERT_DATA) {
    # Prevents autoviv.
    _trap("<dt> removing extref from session without any")
      unless exists $kr_extra_refs{$session};
    unless (exists $kr_extra_refs{$session}->{$tag}) {
      _trap(
        "<dt> removing extref for nonexistent tag ``$tag'' in ",
        $self->_data_alias_loggable($session)
      );
    }
  }

  delete $kr_extra_refs{$session}->{$tag};
  delete $kr_extra_refs{$session}
    unless scalar keys %{$kr_extra_refs{$session}};
  $self->_data_ses_refcount_dec($session);
}

### Clear all the extra references from a session.

sub _data_extref_clear_session {
  my ($self, $session) = @_;

  # TODO - Should there be a _trap here if the session doesn't exist?

  return unless exists $kr_extra_refs{$session}; # avoid autoviv
  foreach (keys %{$kr_extra_refs{$session}}) {
    $self->_data_extref_remove($session, $_);
  }

  if (ASSERT_DATA) {
    if (exists $kr_extra_refs{$session}) {
      _trap(
        "<dt> extref clear did not remove session ",
        $self->_data_alias_loggable($session)
      );
    }
  }
}

# Fetch the number of sessions with extra references held in the
# entire system.

sub _data_extref_count {
  return scalar keys %kr_extra_refs;
}

# Fetch whether a session has extra references.

sub _data_extref_count_ses {
  my ($self, $session) = @_;
  return 0 unless exists $kr_extra_refs{$session};
  return scalar keys %{$kr_extra_refs{$session}};
}

1;

__END__

=head1 NAME

POE::Resource::Extrefs - internal reference counts manager for POE::Kernel

=head1 SYNOPSIS

There is no public API.

=head1 DESCRIPTION

POE::Resource::Extrefs is a mix-in class for POE::Kernel.  It provides
the features to manage session reference counts, specifically the ones
that applications may use.  POE::Resource::Extrefs is used internally
by POE::Kernel, so it has no public interface.

=head1 SEE ALSO

See L<POE::Kernel/Public Reference Counters> for the public extref
API.

See L<POE::Kernel/Resources> for for public information about POE
resources.

See L<POE::Resource> for general discussion about resources and the
classes that manage them.

=head1 BUGS

Reference counters have no ownership information, so one entity's
reference counts may conflict with another's.  This is usually not a
problem if all entities behave.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
