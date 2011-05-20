package POE::Resource;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

1;

__END__

=head1 NAME

POE::Resource - internal resource managers for POE::Kernel

=head1 SYNOPSIS

Varies, although most POE::Resource subclasses do not have public
APIs.

=head1 DESCRIPTION

POE manages several types of information internally.  Its Resource
classes are mix-ins designed to manage those types of information
behind tidy, mostly private interfaces.  This was done to facilitate
testing and a conversion to C without the need to port POE::Kernel all
at once.

POE::Resource subclasses are generally different from one another, but
there are some similarities to note.

Every resource should have an initializer and finalizer method.
Initializers set up initial data and link resources into POE::Kernel.
Finalizers clean up any remaining data and verify that each resource
subsystem was left in a consistent state.

One common theme in resource implementations is that they don't need
to perform much error checking, if any.  Resource methods are used
internally by POE::Kernel and/or POE::API classes, so it's up to them
to ensure correct usage.

Resource methods follow the naming convention _data_???_activity,
where ??? is an abbreviation for the type of resource it belongs to:

  POE::Resource::Events      _data_ev_initialize
  POE::Resource::FileHandles _data_handle_initialize
  POE::Resource::Signals     _data_sig_initialize

Finalizer methods end in "_finalize".

  _data_ev_finalize
  _data_handle_finalize
  _data_sig_finalize

Finalizers return true if a resource shut down cleanly, or false if
there were inconsistencies or leaks during end-of-run checking.  The
t/res/*.t tests rely on these return values.

=head1 SEE ALSO

L<POE::Resource::Aliases>,
L<POE::Resource::Events>,
L<POE::Resource::Extrefs>,
L<POE::Resource::FileHandles>,
L<POE::Resource::SIDs>,
L<POE::Resource::Sessions>,
L<POE::Resource::Signals>

Also see L<POE::Kernel/Resources> for for public information about POE
resources.

=head1 BUGS

None known.

=head1 AUTHORS & LICENSING

Please see L<POE> for more information about its authors,
contributors, and licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
