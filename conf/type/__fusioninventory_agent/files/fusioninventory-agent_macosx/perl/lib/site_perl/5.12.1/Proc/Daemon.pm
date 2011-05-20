##---------------------------------------------------------------------------##
##  File:
##	@(#) Daemon.pm 1.3 03/06/19 17:50:34
##  Author:
##	Earl Hood	earl@earlhood.com
##  Description:
##	POD at end-of-file.
##---------------------------------------------------------------------------##
##  Copyright (C) 1997-1999	Earl Hood, earl@earlhood.com
##      All rights reserved.
##
##  This program is free software; you can redistribute it and/or modify
##  it under the terms of either:
##
##  a) the GNU General Public License as published by the Free Software
##     Foundation; either version 1, or (at your option) any later
##     version, or
##
##  b) the "Artistic License" which comes with Perl.
##---------------------------------------------------------------------------##

package Proc::Daemon;

use strict;
use vars qw( $VERSION @ISA @EXPORT_OK );
use Exporter;
@ISA = qw( Exporter );

$VERSION = "0.03";
@EXPORT_OK = qw( Fork OpenMax );

##---------------------------------------------------------------------------##

use Carp;
use POSIX;

##---------------------------------------------------------------------------##
##	Fork(): Try to fork if at all possible.  Function will croak
##	if unable to fork.
##
sub Fork {
    my($pid);
    FORK: {
	if (defined($pid = fork)) {
	    return $pid;
	} elsif ($! =~ /No more process/) {
	    sleep 5;
	    redo FORK;
	} else {
	    croak "Can't fork: $!";
	}
    }
}

##---------------------------------------------------------------------------##
##	OpenMax(): Return the maximum number of possible file descriptors.
##	If sysconf() does not give us value, we punt with our own value.
##
sub OpenMax {
    my $openmax = POSIX::sysconf( &POSIX::_SC_OPEN_MAX );
    (!defined($openmax) || $openmax < 0) ? 64 : $openmax;
}

##---------------------------------------------------------------------------##
##	Init(): Become a daemon.
##
sub Init {
    my $oldmode = shift || 0;
    my($pid, $sess_id, $i);

    ## Fork and exit parent
    if ($pid = Fork) { exit 0; }

    ## Detach ourselves from the terminal
    croak "Cannot detach from controlling terminal"
	unless $sess_id = POSIX::setsid();

    ## Prevent possibility of acquiring a controling terminal
    if (!$oldmode) {
	$SIG{'HUP'} = 'IGNORE';
	if ($pid = Fork) { exit 0; }
    }

    ## Change working directory
    chdir "/";

    ## Clear file creation mask
    umask 0;

    ## Close open file descriptors
    foreach $i (0 .. OpenMax) { POSIX::close($i); }

    ## Reopen stderr, stdout, stdin to /dev/null
    open(STDIN,  "+>/dev/null");
    open(STDOUT, "+>&STDIN");
    open(STDERR, "+>&STDIN");

    $oldmode ? $sess_id : 0;
}
*init = \&Init;

##---------------------------------------------------------------------------##

1;

__END__

=head1 NAME

Proc::Daemon - Run Perl program as a daemon process

=head1 SYNOPSIS

    use Proc::Daemon;
    Proc::Daemon::Init;

=head1 DESCRIPTION

This module contains the routine B<Init> which can be called by
a Perl program to initialize itself as a daemon.  A daemon is a
process that runs in the background with no controlling terminal.
Generally servers (like FTP and HTTP servers) run as daemon processes.
Note, do not make the mistake that a daemon == server.

The B<Proc::Daemon::Init> function does the following:

=over 4

=item 1

Forks a child and exits the parent process.

=item 2

Becomes a session leader (which detaches the program from
the controlling terminal).

=item 3

Forks another child process and exits first child.  This prevents
the potential of acquiring a controlling terminal.

=item 4

Changes the current working directory to "/".

=item 5

Clears the file creation mask.

=item 6

Closes all open file descriptors.

=back

You will notice that no logging facility, or other functionality
is performed.  B<Proc::Daemon::Init> just performs the main steps
to initialize a program as daemon.  Since other funtionality can vary
depending on the nature of the program, B<Proc::Daemon> leaves
the implementation of other desired functionality to the
caller, or other module/library (like B<Sys::Syslog>).

There is no meaningful return value B<Proc::Daemon::Init>.  If an
error occurs in B<Init> so it cannot perform the above steps, than
it croaks with an error message.  One can prevent program termination
by using eval.

=head1 OTHER FUNCTIONS

B<Proc::Daemon> also defines some other functions.  These functions
can be imported into the callers name space if the function names
are specified during the B<use> declaration:

=head2 Fork

B<Fork> is like the built-in B<fork>, but will try to fork if at all
possible, retrying if necessary.  If not possible, B<Fork> will
croak.

=head2 OpenMax

B<OpenMax> returns the maximum file descriptor number.
If undetermined, 64 will be returned.

=head1 NOTES

=over 4

=item *

B<Proc::Daemon::init> is still available for backwards capatibilty.
However, it will not perform the double fork, and will return the
session ID.

=back

=head1 AUTHOR

Earl Hood, earl@earlhood.com

http://www.earlhood.com/

=head1 CREDITS

Implementation of B<Proc::Daemon> derived from the following sources:

=over 4

=item *

B<Advanced Programming in the UNIX Environment>, by W. Richard Stevens.
Addison-Wesley, Copyright 1992.

=item *

B<UNIX Network Progamming>, Vol 1, by W. Richard Stevens.
Prentice-Hall PTR, Copyright 1998.

=back

=head1 DEPENDENCIES

B<Carp>, B<POSIX>.

=head1 SEE ALSO

L<POSIX>,
L<Sys::Syslog>

=cut

