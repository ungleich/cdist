# Copyrights and documentation are after __END__.

package POE;

use strict;
use Carp qw( croak );

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

sub import {
  my $self = shift;

  my @loops    = grep(/^(?:XS::)?Loop::/, @_);
  my @sessions = grep(/^(Session|NFA)$/, @_);
  my @modules  = grep(!/^(Kernel|Session|NFA|(?:XS::)?Loop::[\w:]+)$/, @_);

  croak "can't use multiple event loops at once"
    if (@loops > 1);
  croak "POE::Session and POE::NFA export conflicting constants"
    if scalar @sessions > 1;

  # If a session was specified, use that.  Otherwise use Session.
  if (@sessions) {
    unshift @modules, @sessions;
  }
  else {
    unshift @modules, 'Session';
  }

  my $package = caller();
  my @failed;

  # Load POE::Kernel in the caller's package.  This is separate
  # because we need to push POE::Loop classes through POE::Kernel's
  # import().

  {
    my $loop = "";
    if (@loops) {
      $loop = "{ loop => '" . shift (@loops) . "' }";
    }
    my $code = "package $package; use POE::Kernel $loop;";
    # warn $code;
    eval $code;
    if ($@) {
      warn $@;
      push @failed, "Kernel"
    }
  }

  # Load all the others.

  foreach my $module (@modules) {
    my $code = "package $package; use POE::$module;";
    # warn $code;
    eval($code);
    if ($@) {
      warn $@;
      push(@failed, $module);
    }
  }

  @failed and croak "could not import qw(" . join(' ', @failed) . ")";
}

1;

__END__

=head1 NAME

POE - portable multitasking and networking framework for any event loop

=head1 SYNOPSIS

  #!/usr/bin/perl -w
  use strict;

  use POE;  # Auto-includes POE::Kernel and POE::Session.

  sub handler_start {
    my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
    print "Session ", $session->ID, " has started.\n";
    $heap->{count} = 0;
    $kernel->yield('increment');
  }

  sub handler_increment {
    my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
    print "Session ", $session->ID, " counted to ", ++$heap->{count}, ".\n";
    $kernel->yield('increment') if $heap->{count} < 10;
  }

  sub handler_stop {
    print "Session ", $_[SESSION]->ID, " has stopped.\n";
  }

  for (1..10) {
    POE::Session->create(
      inline_states => {
        _start    => \&handler_start,
        increment => \&handler_increment,
        _stop     => \&handler_stop,
      }
    );
  }

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE is a framework for cooperative, event driven multitasking and
networking in Perl.  Other languages have similar frameworks.  Python
has Twisted.  TCL has "the event loop".

POE provides a unified interface for several other event loops,
including select(), L<IO::Poll|IO::Poll>, L<Glib>, L<Gtk>, L<Tk>,
L<Wx>, and L<Gtk2>.  Many of these event loop interfaces were written
by others, with the help of POE::Test::Loops.  They may be found on
the CPAN.

POE achieves its its high degree of portability to different operating
systems and Perl versions by being written entirely in Perl.  CPAN
hosts optional XS modules for POE if speed is more desirable than
portability.

POE is designed in layers.  Each layer builds atop the lower level
ones.  Programs are free to use POE at any level of abstraction, and
different levels can be mixed and matched seamlessly within a single
program.  Remember, though, that higher-level abstractions often
require more resources than lower-level ones.  The conveniences they
provide are not free.

POE's bundled abstraction layers are the tip of a growing iceberg.
L<Sprocket>, L<POE::Stage|POE::Stage>, and other CPAN distributions
build upon this work.  You're encouraged to look around.

No matter how high you go, though, it all boils down to calls to
L<POE::Kernel|POE::Kernel>.  So your down-to-earth code can easily
cooperate with stratospheric systems.

=head2 Layer 1: Kernel and Sessions

The lowest public layer is comprised of L<POE::Kernel|POE::Kernel>,
L<POE::Session|POE::Session>, and other session types.

L<POE::Kernel|POE::Kernel> does most of the heavy lifting.  It provides a portable
interface for filehandle activity detection, multiple alarms and other
timers, signal handling, and other less-common features.

L<POE::Session|POE::Session> and derived classes encapsulate the notion of an event
driven task.  They also customize event dispatch to a particular
calling convention.  L<POE::NFA|POE::NFA>, for example, is more of a proper state
machine.  The CPAN has several other kinds of sessions.

Everything ultimately builds on these classes or the concepts they
implement.  If you're short on time, the things to read besides this
are L<POE::Kernel|POE::Kernel> and L<POE::Session|POE::Session>.

=head2 Layer 2: Wheels, Filters, and Drivers

POE::Wheel objects are dynamic mix-ins for POE::Session instances. These
"wheels" perform very common, generic tasks in a highly reusable and
customizable way.  L<POE::Wheel::ReadWrite|POE::Wheel::ReadWrite>, for
example, implements non-blocking buffered I/O.  Nearly everybody needs this,
so why require people to reinvent it all the time?

L<POE::Filter|POE::Filter> objects customize wheels in a modular way.  Filters act as
I/O layers, turning raw streams into structured data, and serializing
structures into something suitable for streams.  The CPAN also has several
of these.

Drivers are where the wheels meet the road.  In this case, the road is
some type of file handle.  Drivers do the actual reading and writing
in a standard way so wheels don't need to know the difference between
send() and syswrite().

L<POE::Driver|POE::Driver> objects get relatively short shrift because very few are
needed.  The most common driver, L<POE::Driver::SysRW|POE::Driver::SysRW> is ubiquitous and
also the default, so most people will never need to specify one.

=head2 Layer 3: Components

L<POE::Component|POE::Component> classes are essentially Perl classes that use POE to
perform tasks in a non-blocking or cooperative way.  This is a very
broad definition, and POE components are all over the abstraction map.

Many components, such as L<POE::Component::Server::SMTP|POE::Component::Server::SMTP>, encapsulate the
generic details of an entire application.  Others perform rather
narrow tasks, such as L<POE::Component::DirWatch::Object|POE::Component::DirWatch::Object>.

POE components are often just plain Perl objects.  The previously
mentioned L<POE::Component::DirWatch::Object|POE::Component::DirWatch::Object> uses L<Moose|Moose>.  Other object
and meta-object frameworks are compatible.

Also of interest is L<POE::Component::Generic|POE::Component::Generic>, which is allows you to create
a POE component from nearly nearly any blocking module.

There are quite a lot of components on the CPAN.  
L<http://search.cpan.org/search?query=poe+component&mode=all>

=head2 Layer 4 and Beyond: Frameworks and Object Metaphors

It's possible to abstract POE entirely behind a different framework.
In fact we encourage people to write domain-specific abstractions that
entirely hide POE if necessary.  The nice thing here is that even at
these high levels of abstraction, things will continue to interoperate
all the way down to layer 1.

Two examples of ultra-high level abstraction are L<Sprocket>, a networking
framework that does its own thing, and L<POE::Stage|POE::Stage>, which is POE's
creator's attempt to formalize and standardize POE components.

It is also possible to communicate between POE processes.  This is called
IKC, for I<Inter-Kernel Communication>.  There are a few IKC components on
the CPAN (L<http://search.cpan.org/search?query=IKC&mode=all>), notably
L<POE::Component::IKC|POE::Component::IKC> and L<POE::TIKC|POE::TIKC>.

=head2 Layer 0: POE's Internals

POE's layered architecture continues below the surface.  POE's guts are
broken into specific L<POE::Loop|POE::Loop> classes for each event loop it supports. 
Internals are divided up by type, giving L<POE::Resource|POE::Resource> classes for
Aliases, Controls, Events, Extrefs, FileHandles, SIDs, Sessions, Signals,
and Statistics.

POE::Kernel's APIs are extensible through POE::API mix-in classes.
Some brave souls have even published new APIs on CPAN, such as
L<POE::API::Peek|POE::API::Peek> (which gives you access to some of the internal
L<POE::Resource|POE::Resource> methods).

By design, it's possible to implement new L<POE::Kernel|POE::Kernel> guts by creating
another L<POE::Resource|POE::Resource> class.  One can then expose the functionality with
a new POE::API mix-in.

=head1 DOCUMENTATION ROADMAP

You're reading the main POE documentation.  It's the general entry
point to the world of POE.  You already know this, however, so let's
talk about something more interesting.

=head2 Basic Features

POE's basic features are documented mainly in L<POE::Kernel|POE::Kernel> and
L<POE::Session|POE::Session>.  Methods are documented in the classes that implement
them.  Broader concepts are covered in the most appropriate class, and
sometimes they are divided among classes that share in their
implementation.

=head2 Basic Usage

Basic usage, even for POE.pm, is documented in L<POE::Kernel|POE::Kernel>.  That's
where most of POE's work is done, and POE.pm is little more than a
class loader.

=head2 @_[KERNEL, HEAP, etc.]

Event handler calling conventions, that weird C<@_[KERNEL, HEAP]>
stuff, is documented in L<POE::Session|POE::Session>.  That's because POE::Session
implements the calling convention, and other session types often do it
differently.

=head2 Base Classes Document Common Features

The L<POE::Wheel|POE::Wheel>, L<POE::Driver|POE::Driver>,
L<POE::Filter|POE::Filter>, and L<POE::Component|POE::Component> base
classes describe what's common among each class.  It's a good idea to at
least skim the base class documentation since the subclasses tend not to
rehash the common things.

L<POE::Queue|POE::Queue>, L<POE::Resource|POE::Resource>, and L<POE::Loop|POE::Loop> document the
concepts and sometimes the standard interfaces behind multiple
subclasses.  You're encouraged to have a look.

=head2 Helper Classes

POE includes some helper classes for portability.  L<POE::Pipe|POE::Pipe>, and its
subclasses L<POE::Pipe::OneWay|POE::Pipe::OneWay> and L<POE::Pipe::TwoWay|POE::Pipe::TwoWay> are portable pipes.

=head2 Event Loop Bridges

L<POE::Loop|POE::Loop> documents and specifies the interface for all of POE's event
loop bridges.  The individual classes may document specific details,
but generally they adhere to the spec strongly enough that they don't
need to.

Many of the existing L<POE::Loop|POE::Loop> bridges provided in POE's base
distribution will move out to separate distributions shortly.  The
documentation will probably remain the same, however.

=head2 POE::Queue and POE::Queue::Array

POE's event queue is basically a priority heap implemented as an
ordered array.  L<POE::Queue|POE::Queue> documents the standard interface for POE
event queues, and L<POE::Queue::Array|POE::Queue::Array> implements the ordered array
queue.  Tony Cook has released L<POE::XS::Queue::Array|POE::XS::Queue::Array>, which is a
drop-in C replacement for L<POE::Queue::Array|POE::Queue::Array>.  You might give it a try
if you need more performance.  POE's event queue is some of the
hottest code in the system.

=head2 This Section Isn't Complete

Help organize the documentation.  Obviously we can't think of
everything.  We're well aware of this and welcome audience
participation.

=head2 See SEE ALSO

Wherever possible, the SEE ALSO section will cross-reference one
module to related ones.

=head2 Don't Forget the Web

Finally, there are many POE resources on the web.  The CPAN contains a
growing number of POE modules.  L<http://poe.perl.org/> hosts POE's
wiki, which includes tutorials, an extensive set of examples,
documentation, and more.  Plus it's a wiki, so you can trivially pitch
in your two cents.

=head1 SYSTEM REQUIREMENTS

POE's basic requirements are rather light.  Most are included with
modern versions of Perl, and the rest (if any) should be generally
portable by now.

L<Time::HiRes|Time::HiRes> is highly recommended, even for older Perls that don't
include it.  POE will work without it, but alarms and other features will be
much more accurate if it's included. L<POE::Kernel|POE::Kernel> will use Time::HiRes
automatically if it's available.

L<POE::Filter::Reference|POE::Filter::Reference> needs a module to serialize data for transporting
it across a network.  It will use L<Storable|Storable>, L<FreezeThaw|FreezeThaw>, L<YAML|YAML>, or
some other package with freeze() and thaw() methods.  It can also use
L<Compress::Zlib|Compress::Zlib> to conserve bandwidth and reduce latency over slow links, but
it's not required.

If you want to write web servers, you'll need to install libwww-perl, which
requires libnet.  This is a small world of modules that includes
L<HTTP::Status|HTTP::Status>, L<HTTP::Request|HTTP::Request>,
L<HTTP::Date|HTTP::Date>, and L<HTTP::Response|HTTP::Response>.  They are
generally good to have, and modern versions of Perl even include them.

Programs that use L<POE::Wheel::Curses|POE::Wheel::Curses> will of course
require the L<Curses> module, which in turn requires some sort of
curses library.

If you're using POE with Tk, you'll need L<Tk> installed.

And other obvious things.  Let us know if we've overlooked a
non-obvious detail.

=head1 COMPATIBILITY ISSUES

One of POE's design goals is to be as portable as possible.  That's
why it's written in "Plain Perl".  XS versions of POE modules are
available as third-party distributions.  Parts of POE that require
nonstandard libraries are optional, and not having those libraries
should not prevent POE from installing.

Despite Chris Williams' efforts, we can't test POE everywhere.  Please
see the GETTING HELP section if you run into a problem.

POE is expected to work on most forms of UNIX, including FreeBSD,
MacOS X, Linux, Solaris.  Maybe even AIX and QNX, but we're not sure.

POE is also tested on Windows XP, using the latest version of
ActiveState, Strawberry and Cygwin Perl.  POE is fully supported with
Strawberry Perl, as it's included in the Strawberry distribution.

OS/2 and MacOS 9 have been reported to work in the past, but nobody
seems to be testing there anymore.  Reports and patches are still
welcome.

Past versions of POE have been tested with Perl versions as far back
as 5.004_03 and as recent as "blead", today's development build.  We
can no longer guarantee each release will work everywhere, but we will
be happy to work with you if you need special support for a really old
system.

POE's quality is due in large part to the fine work of Chris Williams
and the other CPAN testers.  They have dedicated resources towards
ensuring CPAN distributions pass their own tests, and we watch their
reports religiously.  You can, too.  The latest POE test reports can
be found at L<http://cpantesters.org/distro/P/POE.html>.

Thanks also go out to Benjamin Smith and the 2006 Google Summer of
Code.  Ben was awarded a grant to improve POE's test suite, which he
did admirably.

=head2 Windows Issues

POE seems to work very nicely with Perl compiled for Cygwin.  If you
must use ActiveState Perl, please use the absolute latest version.
ActiveState Perl's compatibility fluctuates from one build to another,
so we tend not to support older releases.

Windows and ActiveState Perl are considered an esoteric platform due
to the complex interactions between various versions.  POE therefore
relies on user feedback and support here.

A number of people have helped bring POE's Windows support this far,
through contributions of time, patches, and other resources.  Some of
them are: Sean Puckett, Douglas Couch, Andrew Chen, Uhlarik Ondoej,
Nick Williams, and Chris Williams (no relation).

=head2 Other Compatibility Issues

None currently known.  See GETTING HELP below if you've run into
something.

=head1 GETTING HELP

POE's developers take pride in its quality.  If you encounter a
problem, please let us know.

=head2 POE's Request Tracker

You're welcome to e-mail questions and bug reports to
<bug-POE@rt.cpan.org>.  This is not a realtime support channel,
though.  If you need a more immediate response, try one of the methods
below.

=head2 POE's Mailing List

POE has a dedicated mailing list where developers and users discuss
the software and its use.  You're welcome to join us.  Send an e-mail
to <poe-help@perl.org> for subscription instructions.  The subject and
message body are ignored.

=head2 POE's Web Site

<http://poe.perl.org> contains recent information, tutorials, and
examples.  It's also a wiki, so people are invited to share tips and
code snippets there as well.

=head2 POE's Source Code

The following command will fetch the most current version of POE into
the "poe" subdirectory:

  svn co https://poe.svn.sourceforge.net/svnroot/poe poe

=head2 SourceForge

http://sourceforge.net/projects/poe/ is POE's project page.

=head2 Internet Relay Chat (IRC)

irc.perl.org channel #poe is an informal place to waste some time and
maybe even discuss Perl and POE.  Consider an SSH relay if your
workplace frowns on IRC.  But only if they won't fire you if you're
caught.

=head2 Personal Support

Unfortunately we don't have resources to provide free one-on-one
personal support anymore.  We'll do it for a fee, though.  Send Rocco
an e-mail via his CPAN address.

=head1 SEE ALSO

Broken down by abstraction layer.

=head2 Layer 1

L<POE::Kernel>, L<POE::Session>, L<POE::NFA>

=head2 Layer 2

L<POE::Wheel>, L<POE::Wheel::Curses>, L<POE::Wheel::FollowTail>,
L<POE::Wheel::ListenAccept>, L<POE::Wheel::ReadLine>, L<POE::Wheel::ReadWrite>,
L<POE::Wheel::Run>, L<POE::Wheel::SocketFactory>

L<POE::Driver>, L<POE::Driver::SysRW>

L<POE::Filter>, L<POE::Filter::Block>, L<POE::Filter::Grep>,
L<POE::Filter::HTTPD>, L<POE::Filter::Line>, L<POE::Filter::Map>,
L<POE::Filter::RecordBlock>, L<POE::Filter::Reference>,
L<POE::Filter::Stackable>, L<POE::Filter::Stream>

=head2 Layer 3

L<POE::Component>, L<POE::Component::Client::TCP>,
L<POE::Component::Server::TCP>

=head2 Layer 0

L<POE::Loop>, L<POE::Loop::Event>, L<POE::Loop::Gtk>, L<POE::Loop::IO_Poll>,
L<POE::Loop::Select>, L<POE::Loop::Tk>

L<POE::Queue>, L<POE::Queue::Array>

L<POE::Resource>, L<POE::Resource::Aliases>, L<POE::Resource::Events>,
L<POE::Resource::Extrefs>, L<POE::Resource::FileHandles>,
L<POE::Resource::SIDs>, L<POE::Resource::Sessions>, L<POE::Resource::Signals>

=head2 Helpers

L<POE::Pipe>, L<POE::Pipe::OneWay>, L<POE::Pipe::TwoWay>

=head2 Home Page

http://poe.perl.org/

=head2 Bug Tracker

https://rt.cpan.org/Dist/Display.html?Status=Active&Queue=POE

=head2 Repository

https://poe.svn.sourceforge.net/svnroot/poe/trunk/poe

=head2 Other Resources

http://search.cpan.org/dist/POE/

=head1 AUTHORS & COPYRIGHT

POE is the combined effort of quite a lot of people.  This is an
incomplete list of some early contributors.  A more complete list can
be found in POE's change log.

=over 2

=item Ann Barcomb

Ann Barcomb is <kudra@domaintje.com>, aka C<kudra>.  Ann contributed
large portions of POE::Simple and the code that became the ReadWrite
support in POE::Component::Server::TCP.  Her ideas also inspired
Client::TCP component, introduced in version 0.1702.

=item Artur Bergman

Artur Bergman is <sky@cpan.org>.  He contributed many hours' work into
POE and quite a lot of ideas.  Years later, I decide he's right and
actually implement them.

Artur is the author of Filter::HTTPD and Filter::Reference, as well as
bits and pieces throughout POE.  His feedback, testing, design and
inspiration have been instrumental in making POE what it is today.

Artur is investing his time heavily into perl 5's iThreads and PONIE
at the moment.  This project has far-reaching implications for POE's
future.

=item Jos Boumans

Jos Boumans is <kane@cpan.org>, aka C<kane>.  Jos is a major driving
force behind the POE::Simple movement and has helped inspire the
POE::Components for TCP clients and servers.

=item Matt Cashner

Matt Cashner is <sungo@pobox.com>, aka C<sungo>.  Matt is one of POE's
core developers.  He's spearheaded the movement to simplify POE for
new users, flattening the learning curve and making the system more
accessible to everyone.  He uses the system in mission critical
applications, folding feedback and features back into the distribution
for everyone's enjoyment.

=item Andrew Chen

Andrew Chen is <achen-poe@micropixel.com>.  Andrew is the resident
POE/Windows guru.  He contributes much needed testing for Solaris on
the SPARC and Windows on various Intel platforms.

=item Douglas Couch

Douglas Couch is <dscouch@purdue.edu>.  Douglas helped port and
maintain POE for Windows early on.

=item Jeffrey Goff

Jeffrey Goff is <jgoff@blackboard.com>.  Jeffrey is the author of
several POE modules, including a tokenizing filter and a component for
managing user information, PoCo::UserBase.  He's also co-author of "A
Beginner's Introduction to POE" at www.perl.com.

=item Philip Gwyn

Philip Gwyn is <gwynp@artware.qc.ca>.  He extended the Wheels I/O
abstraction to support hot-swappable filters, and he eventually
convinced Rocco that unique session and kernel IDs were a good thing.

Philip also enhanced L<POE::Filter::Reference|POE::Filter::Reference> to
support different serialization methods.  He has also improved POE's quality
by finding and fixing several bugs.  He provided POE a much needed code
review around version 0.06.

Lately, Philip tracked down the race condition in signal handling and
fixed it with the signal pipe.

=item Arnar M. Hrafnkelsson

Arnar is <addi@umich.edu>.  Addi tested POE and L<POE::Component::IRC|POE::Component::IRC> on
Windows, finding bugs and testing fixes.  He appears throughout the Changes
file.  He has also written "cpoe", which is a POE-like library for C.

=item Dave Paris

Dave Paris is <dparis@w3works.com>.  Dave tested and benchmarked POE
around version 0.05, discovering some subtle (and not so subtle)
timing problems.  The pre-forking server sample was his idea.
Versions 0.06 and later scaled to higher loads because of his work.
He has contributed a lot of testing and feedback, much of which is
tagged in the Changes file as a-mused.  The man is scarily good at
testing and troubleshooting.

=item Dieter Pearcey

Dieter Pearcey is <dieter@bullfrog.perlhacker.org>.  He goes by several
Japanese nicknames.  Dieter's current area of expertise is in Wheels and
Filters.  He greatly improved L<POE::Wheel::FollowTail|POE::Wheel::FollowTail>, and his Filter
contributions include the basic Block filter, as well as Stackable,
RecordBlock, Grep and Map.

=item Robert Seifer

Robert Seifer is <e-mail unknown>.  He rotates IRC nicknames
regularly.

Robert contributed entirely too much time, both his own and his
computers, towards the detection and eradication of a memory
corruption bug that POE tickled in earlier Perl versions.  In the end,
his work produced a simple compile-time hack that worked around a
problem relating to anonymous subs, scope and @{} processing.

=item Matt Sergeant

Matt contributed C<POE::Kernel::Poll>, a more efficient way to watch
multiple files than select().  It's since been moved to
L<POE::Loop::IO_Poll|POE::Loop::IO_Poll>.

=item Richard Soderberg

Richard Soderberg is <poe@crystalflame.net>, aka C<coral>.  Richard is
a collaborator on several side projects involving POE.  His work
provides valuable testing and feedback from a user's point of view.

=item Dennis Taylor

Dennis Taylor is <dennis@funkplanet.com>.  Dennis has been testing,
debugging and patching bits here and there, such as Filter::Line which
he improved by leaps in 0.1102.  He's also the author of
L<POE::Component::IRC|POE::Component::IRC>, the widely popular POE-based successor to his
wildly popular L<Net::IRC|Net::IRC> library.

=item David Davis

David Davis, aka Xantus is <xantus@cpan.org>.  David contributed patches
to the HTTPD filter, and added CALLER_STATE to L<POE::Session|POE::Session>.  He is the
author of L<Sprocket>, a networking framework built on POE.

=item Others?

Please contact the author if you've been forgotten and would like to
be included here.

TODO - This section has fallen into disrepair.  A POE historian needs
to cull the CHANGES for the names of major contributors.

=back

=head2 Author

=over 2

=item Rocco Caputo

Rocco Caputo is <rcaputo@cpan.org>.  POE is his brainchild.  He wishes
to thank you for your interest, and he has more thanks than he can
count for all the people who have contributed.  POE would not be
nearly as cool without you.

Except where otherwise noted, POE is Copyright 1998-2009 Rocco Caputo.
All rights reserved.  POE is free software; you may redistribute it
and/or modify it under the same terms as Perl itself.

=back

Thank you for reading!

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
