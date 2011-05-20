# Copyrights and documentation are after __END__.

package POE::Component;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

1;

__END__

=head1 NAME

POE::Component - event driven objects or subsystems

=head1 SYNOPSIS

See specific components.

=head1 DESCRIPTION

POE "components" are event-driven modules that generally encapsulate
mid- to high-level program features.  For example,
POE::Component::Client::DNS performs message-based asynchronous
resolver lookups.  POE::Component::Server::TCP is a basic asynchronous
network server.

The POE::Component namespace was started as place for contributors to
publish their POE-based modules without requiring coordination with
the main POE distribution.  The namespace predates the -X convention,
otherwise you'd be reading about POEx instead.

As with many things in Perl, there is more than one way to implement
component interfaces.  Newer components sport OO interfaces, and some
even use Moose, but older ones are solely message driven.

=head1 OBJECT ORIENTED COMPONENTS

One way to create object-oriented components is to embed a
POE::Session instance within an object.  This is done by creating the
session during the object's constructor, and setting the session's
alias to a stringified version of the object reference.

  package Asynchrotron;

  sub new {
    my $class = shift;
    my $self = bless { }, $class;
    POE::Session->create(
      object_states => [
        $self => {
          _start       => "_poe_start",
          do_something => "_poe_do_something",
        },
      ],
    );
    return $self;
  }

  sub _poe_start {
    $_[KERNEL]->alias_set("$_[OBJECT]");
  }

The alias allows object methods to pass events into the session
without having to store something about the session.  The POE::Kernel
call() transfers execution from the caller session's context into the
component's session.

  sub do_something {
    my $self = shift;
    print "Inside the caller's session right now: @_\n";
    $poe_kernel->call("$self", "do_something", @_);
  }

  sub _poe_do_something {
    my @args = @_[ARG0..$#_];
    print "Inside the component's session now: @args\n";
    $_[OBJECT]{count}++;
  }

Both $_[HEAP] and $_[OBJECT] are visible within the component's
session.  $_[HEAP] can be used for ultra-private encapsulation, while
$_[OBJECT] may be used for data visible by accessors.

  sub get_count {
    my $self = shift;
    return $self->{count}; # $_[OBJECT]{count} above
  }

Too many sessions may bog down object creation and destruction, so
avoid creating them for every object.

=head1 SEE ALSO

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

L<POE::Stage> is a nascent project to formalize POE components, make
POE::Kernel more object-oriented, and provide syntactic and semantic
sugar for many common aspects of POE::Component development.  It's
also easier to type.  Please investigate the project.  Ideas and I<tuits>
are badly needed to help get the project off the ground.

=head1 TO DO

Document the customary (but not mandatory!) process of creating and
publishing a component.

=head1 AUTHORS & COPYRIGHTS

Each component is written and copyrighted separately.

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
