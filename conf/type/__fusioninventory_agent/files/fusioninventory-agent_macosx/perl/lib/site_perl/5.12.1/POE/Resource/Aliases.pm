# Manage the POE::Kernel data structures necessary to keep track of
# session aliases.

package POE::Resource::Aliases;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

# These methods are folded into POE::Kernel;
package POE::Kernel;

use strict;

### The table of session aliases, and the sessions they refer to.

my %kr_aliases;
#  ( $alias => $session_ref,
#    ...,
#  );

my %kr_ses_to_alias;
#  ( $session_ref =>
#    { $alias => $placeholder_value,
#      ...,
#    },
#    ...,
#  );

sub _data_alias_initialize {
  $poe_kernel->[KR_ALIASES] = \%kr_aliases;
}

### End-run leak checking.  Returns true if finalization was ok, or
### false if it failed.

sub _data_alias_finalize {
  my $finalized_ok = 1;
  while (my ($alias, $ses) = each(%kr_aliases)) {
    _warn "!!! Leaked alias: $alias = $ses\n";
    $finalized_ok = 0;
  }
  while (my ($ses, $alias_rec) = each(%kr_ses_to_alias)) {
    my @aliases = keys(%$alias_rec);
    _warn "!!! Leaked alias cross-reference: $ses (@aliases)\n";
    $finalized_ok = 0;
  }
  return $finalized_ok;
}

# Add an alias to a session.
#
# TODO This has a potential problem: setting the same alias twice on a
# session will increase the session's reference count twice.  Removing
# the alias will only decrement it once.  That potentially causes
# reference counts that never go away.  The public interface for this
# function, alias_set(), does not allow this to occur.  We should add
# a test to make sure it never does.
#
# TODO It is possible to add aliases to sessions that do not exist.
# The public alias_set() function prevents this from happening.

sub _data_alias_add {
  my ($self, $session, $alias) = @_;
  $self->_data_ses_refcount_inc($session);
  $kr_aliases{$alias} = $session;
  $kr_ses_to_alias{$session}->{$alias} = 1;
}

# Remove an alias from a session.
#
# TODO Happily allows the removal of aliases from sessions that don't
# exist.  This will cause problems with reference counting.

sub _data_alias_remove {
  my ($self, $session, $alias) = @_;
  delete $kr_aliases{$alias};
  delete $kr_ses_to_alias{$session}->{$alias};
  $self->_data_ses_refcount_dec($session);
}

### Clear all the aliases from a session.

sub _data_alias_clear_session {
  my ($self, $session) = @_;
  return unless exists $kr_ses_to_alias{$session}; # avoid autoviv
  foreach (keys %{$kr_ses_to_alias{$session}}) {
    $self->_data_alias_remove($session, $_);
  }
  delete $kr_ses_to_alias{$session};
}

### Resolve an alias.  Just an alias.

sub _data_alias_resolve {
  my ($self, $alias) = @_;
  return undef unless exists $kr_aliases{$alias};
  return $kr_aliases{$alias};
}

### Return a list of aliases for a session.

sub _data_alias_list {
  my ($self, $session) = @_;
  return () unless exists $kr_ses_to_alias{$session};
  return sort keys %{$kr_ses_to_alias{$session}};
}

### Return the number of aliases for a session.

sub _data_alias_count_ses {
  my ($self, $session) = @_;
  return 0 unless exists $kr_ses_to_alias{$session};
  return scalar keys %{$kr_ses_to_alias{$session}};
}

### Return a session's ID in a form suitable for logging.

sub _data_alias_loggable {
  my ($self, $session) = @_;

  if (ASSERT_DATA) {
    _trap unless ref($session);
  }

  "session " . $session->ID . " (" .
    ( (exists $kr_ses_to_alias{$session})
      ? join(", ", $self->_data_alias_list($session))
      : $session
    ) . ")"
}

1;

__END__

=head1 NAME

POE::Resource::Aliases - internal session alias manager for POE::Kernel

=head1 SYNOPSIS

There is no public API.

=head1 DESCRIPTION

POE::Resource::Aliases is a mix-in class for POE::Kernel.  It provides
the features to manage session aliases.  It is used internally by
POE::Kernel, so it has no public interface.

=head1 SEE ALSO

See L<POE::Kernel/Session Identifiers (IDs and Aliases)> for the
public alias API.

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
