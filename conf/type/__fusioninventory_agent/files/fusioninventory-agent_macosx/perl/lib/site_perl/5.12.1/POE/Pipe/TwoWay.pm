# Portable two-way pipe creation, trying as many different methods as
# we can.

package POE::Pipe::TwoWay;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Symbol qw(gensym);
use IO::Socket qw( AF_UNIX SOCK_STREAM PF_UNSPEC );
use POE::Pipe;

@POE::Pipe::TwoWay::ISA = qw( POE::Pipe );

sub DEBUG () { 0 }

sub new {
  my $type         = shift;
  my $conduit_type = shift;

  # Dummy object used to inherit the base POE::Pipe class.
  my $self = bless [], $type;

  # Generate symbols to be used as filehandles for the pipe's ends.
  my $a_read  = gensym();
  my $a_write = gensym();
  my $b_read  = gensym();
  my $b_write = gensym();

  if (defined $conduit_type) {
    return ($a_read, $a_write, $b_read, $b_write) if
      $self->_try_type(
        $conduit_type,
        \$a_read, \$a_write,
        \$b_read, \$b_write
      );
  }

  while (my $try_type = $self->_get_next_preference()) {
    return ($a_read, $a_write, $b_read, $b_write) if
      $self->_try_type(
        $try_type,
        \$a_read, \$a_write,
        \$b_read, \$b_write
      );
    $self->_shift_preference();
  }

  # There's nothing left to try.
  DEBUG and warn "nothing worked";
  return;
}

# Try a pipe by type.

sub _try_type {
  my ($self, $type, $a_read, $a_write, $b_read, $b_write) = @_;

  # Try a socketpair().
  if ($type eq "socketpair") {
    eval {
      socketpair($$a_read, $$b_read, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or die "socketpair 1 failed: $!";
    };

    # Socketpair failed.
    if (length $@) {
      warn "socketpair failed: $@" if DEBUG;
      return;
    }

    DEBUG and do {
      warn "using UNIX domain socketpairs";
      warn "ar($$a_read) aw($$a_write) br($$b_read) bw($$b_write)\n";
    };

    # It's two-way, so each reader is also a writer.
    $$a_write = $$a_read;
    $$b_write = $$b_read;

    # Turn off buffering.  POE::Kernel does this for us, but someone
    # might want to use the pipe class elsewhere.
    select((select($$a_write), $| = 1)[0]);
    select((select($$b_write), $| = 1)[0]);
    return 1;
  }

  # Try a couple pipe() calls.
  if ($type eq "pipe") {
    eval {
      pipe($$a_read, $$b_write) or die "pipe 1 failed: $!";
      pipe($$b_read, $$a_write) or die "pipe 2 failed: $!";
    };

    # Pipe failed.
    if (length $@) {
      warn "pipe failed: $@" if DEBUG;
      return;
    }

    DEBUG and do {
      warn "using a pipe";
      warn "ar($$a_read) aw($$a_write) br($$b_read) bw($$b_write)\n";
    };

    # Turn off buffering.  POE::Kernel does this for us, but someone
    # might want to use the pipe class elsewhere.
    select((select($$a_write), $| = 1)[0]);
    select((select($$b_write), $| = 1)[0]);
    return 1;
  }

  # Try a pair of plain INET sockets.
  if ($type eq "inet") {
    eval {
      ($$a_read, $$b_read) = $self->_make_socket();
    };

    # Sockets failed.
    if (length $@) {
      warn "make_socket failed: $@" if DEBUG;
      return;
    }

    DEBUG and do {
      warn "using a plain INET socket";
      warn "ar($$a_read) aw($$a_write) br($$b_read) bw($$b_write)\n";
    };

    $$a_write = $$a_read;
    $$b_write = $$b_read;

    # Turn off buffering.  POE::Kernel does this for us, but someone
    # might want to use the pipe class elsewhere.
    select((select($$a_write), $| = 1)[0]);
    select((select($$b_write), $| = 1)[0]);
    return 1;
  }

  DEBUG and warn "unknown TwoWay socket type ``$type''";
  return;
}

1;

__END__

=head1 NAME

POE::Pipe::TwoWay - a portable API for two-way pipes

=head1 SYNOPSIS

  my ($a_read, $a_write, $b_read, $b_write) = POE::Pipe::TwoWay->new();
  die "couldn't create a pipe: $!" unless defined $a_read;

=head1 DESCRIPTION

Pipes are troublesome beasts because there are a few different,
incompatible ways to create them, and many operating systems implement
some subset of them.  Therefore it's impossible to rely on a
particular method for their creation.

POE::Pipe::TwoWay will attempt to create a bidirectional pipe using an
appropriate method.  If that fails, it will fall back to some other
means until success or all methods have been exhausted.  Some
operating systems require certain exceptions, which are hardcoded into
the library.

The upshot of all this is that an application can use
POE::Pipe::TwoWay to create a bidirectional pipe without worrying
about the mechanism that works in the current run-time environment.

By the way, POE::Pipe::TwoWay doesn't use POE internally, so it may be
used in stand-alone applications without POE.

=head1 PUBLIC METHODS

=head2 new [TYPE]

Create a new two-way pipe, optionally constraining it to a particular
TYPE of pipe.  Two-way pipes have two ends, both of which can be read
from and written to.  Therefore, a successful new() call will return
four handles: read and write for one end, and read and write for the
other.  On failure, new() sets $! to describe the error and returns
nothing.

  my ($a_read, $a_write, $b_read, $b_write) = POE::Pipe::TwoWay->new();
  die $! unless defined $a_read;

TYPE may be one of "pipe", "socketpair", or "inet".  When set,
POE::Pipe::TwoWay will constrain its search to either C<pipe()>, a
UNIX-domain C<socketpair()>, or plain old sockets, respectively.
Otherwise new() will try each method in order, or a particular method
predetermined to be the best one for the current operating
environment.

=head1 BUGS

POE::Pipe::OneWay may block up to one second on some systems if
failure occurs while trying to create "inet" sockets.

=head1 SEE ALSO

L<POE::Pipe>, L<POE::Pipe::OneWay>.

=head1 AUTHOR & COPYRIGHT

POE::Pipe::TwoWay is copyright 2000-2008 by Rocco Caputo.  All rights
reserved.  POE::Pipe::TwoWay is free software; you may redistribute it
and/or modify it under the same terms as Perl itself.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
