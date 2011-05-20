package POE::Resources;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

my @resources = qw(
  POE::XS::Resource::Aliases
  POE::XS::Resource::Events
  POE::XS::Resource::Extrefs
  POE::XS::Resource::FileHandles
  POE::XS::Resource::SIDs
  POE::XS::Resource::Sessions
  POE::XS::Resource::Signals
  POE::XS::Resource::Statistics
);

sub load {
  my $package = (caller())[0];

  foreach my $resource (@resources) {
    eval "package $package; use $resource";
    if ($@) {
      # Retry the resource, removing XS:: if it couldn't be loaded.
      # If there's no XS:: to be removed, fall through and die.
      redo if $@ =~ /Can't locate.*?in \@INC/ and $resource =~ s/::XS::/::/;
      die;
    }
  }
}

1;

__END__

=head1 NAME

POE::Resources - loader of POE resources

=head1 SYNOPSIS

  # Intended for internal use by POE::Kernel.
  use POE::Resources;
  POE::Resources->load();

=head1 DESCRIPTION

POE::Kernel is internally split into different resources that are
separately managed by individual mix-in classes.

POE::Resources is designed as a high-level macro manager for
POE::Resource classes.  Currently it implements a single method,
load(), which loads all the POE::Resource classes.

=head1 METHODS

POE::Resources has a public interface, but it is intended to be used
internally by POE::Kernel.  Application programmers should never need
to use POE::Resources directly.

=head2 load

POE::Kernel calls load() to loads all the known POE::Resource modules.

Each resource may be handled by a pure perl module, or by an XS
module.  For each resource class, load() first tries to load the
C<POE::XS::Resource::...> version of the module.  If that fails,
load() falls back to C<POE::Resource::...>.

=head1 SEE ALSO

See L<POE::Kernel/Resources> for for public information about POE
resources.

See L<POE::Resource> for general discussion about resources and the
classes that manage them.

=head1 AUTHORS & LICENSING

Please see L<POE> for more information about its authors,
contributors, and POE's licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
