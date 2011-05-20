# Filter::Reference partial copyright 1998 Artur Bergman
# <artur@vogon-solutions.com>.  Partial copyright 1999 Philip Gwyn.

package POE::Filter::Reference;

use strict;
use POE::Filter;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Filter);

use Carp qw(carp croak);

sub BUFFER ()   { 0 }
sub FREEZE ()   { 1 }
sub THAW ()     { 2 }
sub COMPRESS () { 3 }

#------------------------------------------------------------------------------
# Try to require one of the default freeze/thaw packages.
use vars qw( $DEF_FREEZER $DEF_FREEZE $DEF_THAW );
BEGIN {
  local $SIG{'__DIE__'} = 'DEFAULT';

  my @packages = qw(Storable FreezeThaw YAML);
  foreach my $package (@packages) {
    eval { require "$package.pm"; import $package (); };
    if ($@) {
      warn $@;
      next;
    }

    # Found a good freezer!
    $DEF_FREEZER = $package;
    last;
  }
  die "Filter::Reference requires one of @packages" unless defined $DEF_FREEZER;
}

# Some processing here
($DEF_FREEZE, $DEF_THAW) = _get_methods($DEF_FREEZER);

#------------------------------------------------------------------------------
# Try to acquire Compress::Zlib at run time.

my $zlib_status = undef;
sub _include_zlib {
  local $SIG{'__DIE__'} = 'DEFAULT';

  unless (defined $zlib_status) {
    eval "use Compress::Zlib qw(compress uncompress)";
    if ($@) {
      $zlib_status = $@;
      eval(
        "sub compress   { @_ }\n" .
        "sub uncompress { @_ }"
      );
    }
    else {
      $zlib_status = '';
    }
  }

  $zlib_status;
}

#------------------------------------------------------------------------------

sub _get_methods {
  my($freezer)=@_;
  my $freeze=$freezer->can('nfreeze') || $freezer->can('freeze');
  my $thaw=$freezer->can('thaw');
  return unless $freeze and $thaw;
  return ($freeze, $thaw);
}

#------------------------------------------------------------------------------

sub new {
  my($type, $freezer, $compression) = @_;

  my($freeze, $thaw);
  unless (defined $freezer) {
    # Okay, load the default one!
    $freezer = $DEF_FREEZER;
    $freeze  = $DEF_FREEZE;
    $thaw    = $DEF_THAW;
  }
  else {
    # What did we get?
    if (ref $freezer) {
      # It's an object, create an closure
      my($freezetmp, $thawtmp) = _get_methods($freezer);
      $freeze = sub { $freezetmp->($freezer, @_) };
      $thaw   = sub { $thawtmp->  ($freezer, @_) };
    }
    else {
      # A package name?
      # First, find out if the package has the necessary methods.
      ($freeze, $thaw) = _get_methods($freezer);

      # If not, try to reload the module.
      unless ($freeze and $thaw) {
        my $path = $freezer;
        $path =~ s{::}{/}g;
        $path .= '.pm';

        # Force a reload if necessary.  This is naive and can leak
        # memory, so we only do it until we get the desired methods.
        delete $INC{$path};

        eval {
          local $^W = 0;
          require $path;
          $freezer->import();
        };

        carp $@ if $@;
        ($freeze, $thaw) = _get_methods($freezer);
      }
    }
  }

  # Now get the methods we want
  carp "$freezer doesn't have a freeze or nfreeze method" unless $freeze;
  carp "$freezer doesn't have a thaw method" unless $thaw;

  # Should ->new() return undef() it if fails to find the methods it
  # wants?
  return unless $freeze and $thaw;

  # Compression
  $compression ||= 0;
  if ($compression) {
    my $zlib_status = _include_zlib();
    if ($zlib_status ne '') {
      warn "Compress::Zlib load failed with error: $zlib_status\n";
      carp "Filter::Reference compression option ignored";
      $compression = 0;
    }
  }

  my $self = bless [
    '',           # BUFFER
    $freeze,      # FREEZE
    $thaw,        # THAW
    $compression, # COMPRESS
  ], $type;
  $self;
}

#------------------------------------------------------------------------------

sub get {
  my ($self, $stream) = @_;
  my @return;

  $self->get_one_start($stream);
  while (1) {
    my $next = $self->get_one();
    last unless @$next;
    push @return, @$next;
  }

  return \@return;
}

#------------------------------------------------------------------------------
# 2001-07-27 RCC: The get_one() variant of get() allows Wheel::Xyz to
# retrieve one filtered block at a time.  This is necessary for filter
# changing and proper input flow control.

sub get_one_start {
  my ($self, $stream) = @_;
  $self->[BUFFER] .= join('', @$stream);
}

sub get_one {
  my $self = shift;

  # Need to check lengths in octets, not characters.
  BEGIN { eval { require bytes } and bytes->import; }

  if (
    $self->[BUFFER] =~ /^(\d+)\0/ and
    length($self->[BUFFER]) >= $1 + length($1) + 1
  ) {
    substr($self->[BUFFER], 0, length($1) + 1) = "";
    my $return = substr($self->[BUFFER], 0, $1);
    substr($self->[BUFFER], 0, $1) = "";
    $return = uncompress($return) if $self->[COMPRESS];
    return [ $self->[THAW]->($return) ];
  }

  return [ ];
}

#------------------------------------------------------------------------------
# freeze one or more references, and return a string representing them

sub put {
  my ($self, $references) = @_;

  # Need to check lengths in octets, not characters.
  BEGIN { eval { require bytes } and bytes->import; }

  my @raw = map {
    my $frozen = $self->[FREEZE]->($_);
    $frozen = compress($frozen) if $self->[COMPRESS];
    length($frozen) . "\0" . $frozen;
  } @$references;
  \@raw;
}

#------------------------------------------------------------------------------
# Return everything we have outstanding.  Do not destroy our framing
# buffer, though.

sub get_pending {
  my $self = shift;
  return undef unless length $self->[BUFFER];
  return [ $self->[BUFFER] ];
}

1;

__END__

=head1 NAME

POE::Filter::Reference - freeze and thaw arbitrary Perl data

=head1 SYNOPSIS

  #!perl

  use YAML;
  use POE qw(Wheel::ReadWrite Filter::Reference);

  POE::Session->create(
    inline_states => {
      _start => sub {
        pipe(my($read, $write)) or die $!;
        $_[HEAP]{io} = POE::Wheel::ReadWrite->new(
          InputHandle => $read,
          OutputHandle => $write,
          Filter => POE::Filter::Reference->new(),
          InputEvent => "got_perl_data",
        );

        $_[HEAP]{io}->put(
          { key_1 => 111, key_2 => 222 }
        );
      },
      got_perl_data => sub {
        print "Got data:\n", YAML::Dump($_[ARG0]);
        print "Bye!\n";
        delete $_[HEAP]{io};
      }
    }
  );

  POE::Kernel->run();
  exit;

=head1 DESCRIPTION

POE::Filter::Reference allows programs to send and receive arbitrary
Perl data structures without worrying about a line protocol.  Its
put() method serializes Perl data into a byte stream suitable for
transmission.  get_one() parses the data structures back out of such a
stream.

By default, POE::Filter::Reference uses Storable to do its magic.  A
different serializer may be specified at construction time.

=head1 PUBLIC FILTER METHODS

POE::Filter::Reference deviates from the standard POE::Filter API in
the following ways.

=head2 new [SERIALIZER [, COMPRESSION]]

new() creates and initializes a POE::Filter::Reference object.  It
will use Storable as its default SERIALIZER if none other is
specified.

If COMPRESSION is true, Compress::Zlib will be called upon to reduce
the size of serialized data.  It will also decompress the incoming
stream data.

Any class that supports nfreeze() (or freeze()) and thaw() may be used
as a SERIALIZER.  If a SERIALIZER implements both nfreeze() and
freeze(), then the "network" version will be used.

SERIALIZER may be a class name:

  # Use Storable explicitly, specified by package name.
  my $filter = POE::Filter::Reference->new("Storable");

  # Use YAML instead.  Compress its output, as it may be verbose.
  my $filter = POE::Filter::Reference->new("YAML", 1);

SERIALIZER may also be an object:

  # Use an object.
  my $serializer = Data::Serializer::Something->new();
  my $filter = POE::Filter::Reference->new($serializer);

If SERIALIZER is omitted or undef, the Reference filter will try to
use Storable, FreezeThaw, and YAML in that order.
POE::Filter::Reference will die if it cannot find one of these
serializers, but this rarely happens now that Storable and YAML are
bundled with Perl.

  # A choose-your-own-serializer adventure!
  # We'll still deal with compressed data, however.
  my $filter = POE::Filter::Reference->new(undef, 1);

POE::Filter::Reference will try to compress frozen strings and
uncompress them before thawing if COMPRESSION is true.  It uses
Compress::Zlib for this.  POE::Filter::Reference doesn't need
Compress::Zlib if COMPRESSION is false.

new() will try to load any classes it needs.

=head1 SERIALIZER API

Here's what POE::Filter::Reference expects of its serializers.

=head2 thaw SERIALIZED

thaw() is required.  It accepts two parameters: $self and a scalar
containing a SERIALIZED byte stream representing a single Perl data
structure.  It returns a reconstituted Perl data structure.

  sub thaw {
    my ($self, $stream) = @_;
    my $reference = $self->_deserialization_magic($stream);
    return $reference;
  }

=head2 nfreeze REFERENCE

Either nfreeze() or freeze() is required.  They behave identically,
except that nfreeze() is guaranteed to be portable across networks and
between machine architectures.

These freezers accept two parameters: $self and a REFERENCE to Perl
data.  They return a serialized version of the REFERENCEd data.

  sub nfreeze {
    my ($self, $reference) = @_;
    my $stream = $self->_serialization_magic($reference);
    return $stream;
  }

=head2 freeze REFERENCE

freeze() is an alternative form of nfreeze().  It has the same call
signature as nfreeze(), but it doesn't guarantee that serialized data
will be portable across machine architectures.

If you must choose between implementing freeze() and nfreeze() for use
with POE::Filter::Reference, go with nfreeze().

=head1 SEE ALSO

Please see L<POE::Filter> for documentation regarding the base
interface.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

Not so much bugs as caveats:

It's important to use identical serializers on each end of a
connection.  Even different versions of the same serializer can break
data in transit.

Most (if not all) serializers will re-bless data at the destination,
but many of them will not load the necessary classes to make their
blessings work.

=head1 AUTHORS & COPYRIGHTS

The Reference filter was contributed by Artur Bergman, with changes
by Philip Gwyn.

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
