# Portable one-way pipe creation, trying as many different methods as
# we can.

package POE::Pipe::OneWay;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Symbol qw(gensym);
use IO::Socket qw( AF_UNIX SOCK_STREAM PF_UNSPEC );
use POE::Pipe;

@POE::Pipe::OneWay::ISA = qw( POE::Pipe );

sub DEBUG () { 0 }

sub new {
  my $type         = shift;
  my $conduit_type = shift;

  # Dummy object used to inherit the base POE::Pipe class.
  my $self = bless [], $type;

  # Generate symbols to be used as filehandles for the pipe's ends.
  my $a_read  = gensym();
  my $b_write = gensym();

  if (defined $conduit_type) {
    return ($a_read, $b_write)
      if $self->_try_type($conduit_type, \$a_read, \$b_write);
  }

  while (my $try_type = $self->_get_next_preference()) {
    return ($a_read, $b_write)
      if $self->_try_type($try_type, \$a_read, \$b_write);
    $self->_shift_preference();
  }

  # There's nothing left to try.
  DEBUG and warn "nothing worked";
  return;
}

# Try a pipe by type.

sub _try_type {
  my ($self, $type, $a_read, $b_write) = @_;

  # Try a pipe().
  if ($type eq "pipe") {
    eval {
      pipe($$a_read, $$b_write) or die "pipe failed: $!";
    };

    # Pipe failed.
    if (length $@) {
      warn "pipe failed: $@" if DEBUG;
      return;
    }

    DEBUG and do {
      warn "using a pipe";
      warn "ar($$a_read) bw($$b_write)\n";
    };

    # Turn off buffering.  POE::Kernel does this for us, but
    # someone might want to use the pipe class elsewhere.
    select((select($$b_write), $| = 1)[0]);
    return 1;
  }

  # Try a UNIX-domain socketpair.
  if ($type eq "socketpair") {
    eval {
      socketpair($$a_read, $$b_write, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or die "socketpair failed: $!";
    };

    if (length $@) {
      warn "socketpair failed: $@" if DEBUG;
      return;
    }

    DEBUG and do {
      warn "using a UNIX domain socketpair";
      warn "ar($$a_read) bw($$b_write)\n";
    };

    # It's one-way, so shut down the unused directions.
    shutdown($$a_read,  1);
    shutdown($$b_write, 0);

    # Turn off buffering.  POE::Kernel does this for us, but someone
    # might want to use the pipe class elsewhere.
    select((select($$b_write), $| = 1)[0]);
    return 1;
  }

  # Try a pair of plain INET sockets.
  if ($type eq "inet") {
    eval {
      ($$a_read, $$b_write) = $self->_make_socket();
    };

    if (length $@) {
      warn "make_socket failed: $@" if DEBUG;
      return;
    }

    DEBUG and do {
      warn "using a plain INET socket";
      warn "ar($$a_read) bw($$b_write)\n";
    };

    # It's one-way, so shut down the unused directions.
    shutdown($$a_read,  1);
    shutdown($$b_write, 0);

    # Turn off buffering.  POE::Kernel does this for us, but someone
    # might want to use the pipe class elsewhere.
    select((select($$b_write), $| = 1)[0]);
    return 1;
  }

  # There's nothing left to try.
  DEBUG and warn "unknown OneWay socket type ``$type''";
  return;
}

1;

__END__

=head1 NAME

POE::Pipe::OneWay - a portable API for one-way pipes

=head1 SYNOPSIS

  my ($read, $write) = POE::Pipe::OneWay->new();
  die "couldn't create a pipe: $!" unless defined $read;

=head1 DESCRIPTION

The right way to create an anonymous pipe varies from one operating
system to the next.  Some operating systems support C<pipe()>.  Others
require C<socketpair()>.  And a few operating systems support neither,
so a plain old socket must be created.

POE::Pipe::OneWay will attempt to create a unidirectional pipe using
C<pipe()>, C<socketpair()>, and IO::Socket::INET, in that order.
Exceptions are hardcoded for operating systems with broken or
nonstandard behaviors.

The upshot of all this is that an application can portably create a
one-way pipe by instantiating POE::Pipe::OneWay.  The work of deciding
how to create the pipe and opening the handles will be taken care of
internally.

POE::Pipe::OneWay may be used outside of POE, as it doesn't use POE
internally.

=head1 PUBLIC METHODS

=head2 new [TYPE]

Create a new one-way pipe, optionally constraining it to a particular
TYPE of pipe.  One-way pipes have two ends: a "read" end and a "write"
end.  On success, new() returns two handles: one for the "read" end
and one for the "write" end.  Returns nothing on failure, and sets $!
to explain why the constructor failed.

  my ($read, $write) = POE::Pipe::OneWay->new();
  die $! unless defined $read;

TYPE may be one of "pipe", "socketpair", or "inet".  When set,
POE::Pipe::OneWay will constrain its search to either C<pipe()>, a
UNIX-domain C<socketpair()>, or plain old sockets, respectively.
Otherwise new() will try each method in order, or a particular method
predetermined to be the best one for the current operating
environment.

=head1 BUGS

POE::Pipe::OneWay may block up to one second on some systems if
failure occurs while trying to create "inet" sockets.

=head1 SEE ALSO

L<POE::Pipe>, L<POE::Pipe::TwoWay>.

=head1 AUTHOR & COPYRIGHT

POE::Pipe::OneWay is copyright 2000-2008 by Rocco Caputo.  All rights
reserved.  POE::Pipe::OneWay is free software; you may redistribute it
and/or modify it under the same terms as Perl itself.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
