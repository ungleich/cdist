package Net::DNS::Domain;

#
# $Id: Domain.pm 836 2009-12-30 09:41:53Z olaf $
#
use vars qw($VERSION);
$VERSION = (qw$LastChangedRevision 700$)[1];


=head1 NAME

    Net::DNS::Domain - Domain Name System domains

=head1 SYNOPSIS

    use Net::DNS::Domain

=head1 DESCRIPTION

The C<Net::DNS::Domain> module implements a class of abstract
DNS domain objects with associated class and instance methods.

Each domain object instance represents a single DNS domain which
has a fixed identity throughout its lifetime.

Internally, the primary representation is a (possibly empty) list
of ASCII domain labels, and optional link to an ancestor domain
object topologically closer to the root of the DNS namespace.

The presentation form of the domain name is generated on demand
and the result cached within the object.

=cut


use strict;
use integer;
use Carp;

use constant ASCII => eval { chr(91) eq '['; };

require Encode unless ASCII;


=head1 METHODS

=head2 new

    $domain = new Net::DNS::Domain('example.com');

Creates a domain object which represents the DNS domain
identified by the character string argument.  The identifier
consists of a sequence of labels delimited by dots.

The argument string consists of printable characters from the
7-bit ASCII repertoire.

A character preceded by \ represents itself, without any special
interpretation.

Any 8-bit code point can be represented by \ followed by exactly
three decimal digits.
Character code points are ASCII, irrespective of the encoding
employed by the underlying platform.
No characters are associated with code points beyond 127.

Argument strings should be delimited by single quotes to avoid
escape sequences being misinterpreted by the compiler.

The character string presentation format follows the conventions
for zone files described in RFC1035.

=cut

sub new {
	my $self = bless {}, shift;
	my $identifier = shift;
	confess 'domain identifier undefined' unless defined $identifier;

	if ( $identifier =~ /\\/o ) {
		$identifier =~ s/\\\\/\\092/go;			# disguise escaped escape
		$identifier =~ s/\\\./\\046/go;			# disguise escaped dot

		@{$self->{raw}} = map { _unescape($_) } split /\.+/o, $identifier if ASCII;

		@{$self->{raw}} = map { Encode::encode( 'iso-8859-1', _unescape($_) ) }
				split /\.+/o, $identifier
				unless ASCII;

	} else {

		@{$self->{raw}} = split /\.+/o, $identifier if ASCII;

		@{$self->{raw}} = split /\056+/o, Encode::encode( 'iso-8859-1', $identifier ) unless ASCII;

	}

	foreach ( @{$self->{raw}} ) {
		next if ( length $_ || croak 'unexpected null domain label' ) < 64;
		my $length = length $_;
		carp "$length octet domain label truncated";
		substr( $_, 63 ) = '';
	}

	return $self;
}


=head2 decode

    $domain = decode Net::DNS::Domain( \$buffer, $offset, $hash );

    ( $domain, $next ) = decode Net::DNS::Domain( \$buffer, $offset, $hash );

Creates a domain object which represents the DNS domain
identified by the compressed name at the indicated offset within
the data buffer.

The argument list consists of a reference to a scalar containing
the wire-format data, specified offset and reference to a hash
used to represent compressed names.

The returned offset value indicates the start of the next item
in the data buffer.

=cut

sub decode {
	my $class  = shift;
	my $self   = bless {}, $class;
	my $buffer = shift;					# reference to data buffer
	my $offset = shift || 0;				# offset within buffer
	my $hash   = shift || {};				# hashed domain by offset

	my $buflen = length $$buffer;
	my $index  = $offset;

	while ( $index < $buflen ) {
		unless ( my $length = unpack( "\@$index C", $$buffer ) ) {
			$hash->{$offset} = $self;
			return wantarray ? ( $self, ++$index ) : $self;

		} elsif ( $length < 64 ) {
			push( @{$self->{raw}}, substr( $$buffer, ++$index, $length ) );
			$index += $length;

		} elsif ( $length < 0xc0 ) {
			croak 'corrupt wire-format label';

		} else {
			my $link = 0x3fff & unpack( "\@$index n", $$buffer );
			last unless $link < $offset;
			my $tail = $hash->{$link} || decode( $class, $buffer, $link, $hash );
			$self->{pointer} = $tail;
			$hash->{$offset} = defined $self->{raw} ? $self : $tail;
			return wantarray ? ( $self, $index + 2 ) : $self;
		}
	}
	croak 'corrupt wire-format data';
}


=head2 encode

    $data = $domain->encode( $offset, $hash );

Returns the wire-format representation of the domain object
suitable for inclusion in a DNS packet buffer.

The optional arguments are the offset within the packet data
where the domain name is to be stored and a reference to a
hash table used to index compressed names within the packet.

=cut

sub encode {
	my $self   = shift;
	my $offset = shift;					# offset in data buffer

	if ( my $hash = shift ) {				# hashed offset by name
		my $data   = '';				# compressed wire format
		my @labels = $self->_wire;
		while (@labels) {
			my $name = join( '.', @labels );

			return $data . pack( 'n', $hash->{$name} ) if defined $hash->{$name};

			my $label  = shift @labels;
			my $length = length $label;
			$data .= pack( 'C a*', $length, $label );

			next unless $offset < 0xc000;
			$hash->{$name} = 0xc000 | $offset;
			$offset += 1 + $length;
		}
		$data .= chr(0);

	} else {
		my $data = '';					# DNSSEC canonical uncompressed
		foreach ( $self->_wire ) {
			$data .= pack( 'C a*', length $_, lc $_ );
		}
		$data .= chr(0);
	}
}


=head2 name

    $name = $domain->name;

Returns a character string corresponding to the "typical" form of
domain name to which section 11 of RFC2181 alludes.

The string consists of printable characters from the 7-bit ASCII
repertoire.  Code points outside this set are represented by the
appropriate numerical escape sequence.

=cut

sub name {
	_strip( shift->string );
}


=head2 mailbox

    $mail = $domain->mailbox;

Returns a character string containing the mailbox interpretation
of the domain name as described in RFC1035 section 8.

=cut

sub mailbox {
	my @mail = map { _escape($_) } shift->_wire if ASCII;
	@mail = map { Encode::decode( 'ascii', _escape($_) ) } shift->_wire unless ASCII;

	my $mbox = shift(@mail) || '<>';
	$mbox =~ s/\\\./\./g;					# unescape dot
	_strip( join '@', $mbox, join( '.', @mail ) || () );
}


=head2 string

    $fqdn = $domain->string;

Returns a character string containing the absolute name of the
domain as described in RFC1035 section 5.1.

The string consists of printable characters from the 7-bit ASCII
repertoire.  Code points outside this set are represented by the
appropriate numerical escape sequence.

Characters which have special meaning in a zone file, dots which
are part of a domain label, and the escape character itself are
represented by escape sequences which remove any such meaning.

=cut

sub string {
	my $self = shift;

	return $self->{string} if $self->{string};

	my @label = map { _escape($_) } @{$self->{raw} || []} if ASCII;
	@label = map { Encode::decode( 'ascii', _escape($_) ) } @{$self->{raw} || []} unless ASCII;

	return $self->{string} = join( '.', @label ) . '.' unless $self->{pointer};

	return $self->{string} = join( '.', @label, $self->{pointer}->string );
}


########################################

my %escape = eval {				## precalculated ASCII escape table
	my %table;

	foreach ( 34, 36, 40, 41, 46, 59, 64, 92 ) {		# \x	" $ ( ) . ; @ \
		$table{chr($_)} = pack 'C*', 92, $_;
	}

	foreach ( 0 .. 32, 127 .. 255 ) {			# \ddd
		my $seq = sprintf( '\\%03u', $_ );
		$seq = Encode::encode( 'ascii', $seq ) unless ASCII;
		$table{chr($_)} = $seq;
	}

	return %table;
};


sub _escape {				## Escape non-printable characters in ASCII string
	join( '', map { $escape{$_} || $_ } split( //, shift ) );
}


sub _unescape {				## Interpret escape sequences in character string
	my $label = shift;

	while ( $label =~ /\\(\d\d\d)/o ) {
		my $x = chr($1);
		$x .= $x if $1 eq '092';
		$x = Encode::decode( 'iso-8859-1', $x ) unless ASCII;
		$label =~ s/\\$1/$x/g;
	}

	$label =~ s/\\(.)/$1/g;
	return $label;
}


sub _strip {				## Post-process domain name
	my $name = shift || return '.';
	$name =~ s/(\\\.)/\\$1/g;				# disguise escaped dot
	$name =~ s/(\\\d)/\\$1/g;				# disguise numeric escape
	$name =~ s/\\(.)/$1/g;					# strip character escapes
	chop $name if $name =~ /.+\.$/;				# strip final dot
	return $name;
}


sub _wire {				## Generate list of wire-format labels
	my $self = shift;

	return @{$self->{raw} || []} unless $self->{pointer};

	return ( @{$self->{raw} || []}, $self->{pointer}->_wire );
}


use vars qw($AUTOLOAD);

sub AUTOLOAD {				## Default method
	no strict;
	@_ = ("method $AUTOLOAD undefined");
	goto &{'Carp::confess'};
}


sub DESTROY { }				## Avoid tickling AUTOLOAD (in cleanup)


1;
__END__


########################################

=head1 BUGS

Platform-specific parts of the code are designed to be optimised
away by the compiler for reasons of efficiency. This is achieved
at considerable expense in terms of readability.


=head1 COPYRIGHT

Copyright (c)2009 Dick Franks.

All rights reserved.

This program is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.


=head1 SEE ALSO

L<perl(1)>, L<Net::DNS>, RFC1035, RFC2181.

=cut

