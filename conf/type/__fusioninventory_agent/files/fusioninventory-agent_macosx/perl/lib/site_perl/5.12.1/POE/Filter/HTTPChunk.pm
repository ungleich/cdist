package POE::Filter::HTTPChunk;
use warnings;
use strict;

use Carp;
use bytes;
use base 'POE::Filter';

use HTTP::Response;

use constant FRAMING_BUFFER  => 0;
use constant CURRENT_STATE   => 1;
use constant CHUNK_SIZE      => 2;
use constant CHUNK_BUFFER    => 3;
use constant TRAILER_HEADERS => 4;

use constant STATE_SIZE      => 0x01;  # waiting for a status line
use constant STATE_DATA      => 0x02;  # received status, looking for header or end
use constant STATE_TRAILER   => 0x04;  # received status, looking for header or end

use constant DEBUG           => 0;

sub new {
  my ($class) = @_;

  my $self = bless [
    [],         # FRAMING_BUFFER
    STATE_SIZE, # CURRENT_STATE
    0,          # CHUNK_SIZE
    '',         # CHUNK_BUFFER
    undef,      # TRAILER_HEADERS
  ], $class;

  return $self;
}

my $HEX = qr/[\dA-Fa-f]/o;

=for later

my $TEXT = qr/[^[:cntrl:]]/o;
my $qdtext = qr/[^[:cntrl:]\"]/o; #<any TEXT except <">>
my $quoted_pair = qr/\\[[:ascii:]]/o;
my $quoted_string = qr/\"(?:$qdtext|$quoted_pair)\"/o;
my $separators = "[^()<>@,;:\\"\/\[\]\?={} \t";
my $notoken = qr/(?:[[:cntrl:]$separators]/o;

my $chunk_ext_name = $token;
my $chunk_ext_val = qr/(?:$token|$quoted_string)/o;

my $chunk_extension = qr/(?:;$chunk_ext_name(?:$chunk_ext_val)?)/o;

=cut

sub get_one_start {
  my ($self, $chunks) = @_;

  #warn "GOT MORE DATA";
  push (@{$self->[FRAMING_BUFFER]}, @$chunks);
  #warn "NUMBER OF CHUNKS is now ", scalar @{$self->[FRAMING_BUFFER]};
}

sub get_one {
  my $self = shift;

  my $retval = [];
  while (defined (my $chunk = shift (@{$self->[FRAMING_BUFFER]}))) {
    #warn "CHUNK IS SIZE ", length($chunk);
    #warn join(
    #  ",", map {sprintf("%02X", ord($_))} split (//, substr ($chunk, 0, 10))
    #);
    #warn "NUMBER OF CHUNKS is ", scalar @{$self->[FRAMING_BUFFER]};
    DEBUG and warn "STATE is ", $self->[CURRENT_STATE];

    # if we're not in STATE_DATA, we need to have a newline sequence
    # in our hunk of content to find out how far we are.
    unless ($self->[CURRENT_STATE] & STATE_DATA) {
      if ($chunk !~ /.\015?\012/s) {
        #warn "SPECIAL CASE";
        if (@{$self->[FRAMING_BUFFER]} == 0) {
          #warn "pushing $chunk back";
          unshift (@{$self->[FRAMING_BUFFER]}, $chunk);
          return $retval;
        }
        else {
          $chunk .= shift (@{$self->[FRAMING_BUFFER]});
          #warn "added to $chunk";
        }
      }
    }

    if ($self->[CURRENT_STATE] & STATE_SIZE) {
      DEBUG and warn "Finding chunk length marker";
      if (
        $chunk =~ s/^($HEX+)[^\S\015\012]*(?:;.*?)?[^\S\015\012]*\015?\012//s
      ) {
        my $length = hex($1);
        DEBUG and warn "Chunk should be $length bytes";
        $self->[CHUNK_SIZE] = $length;
        if ($length == 0) {
          $self->[TRAILER_HEADERS] = HTTP::Headers->new;
          $self->[CURRENT_STATE] = STATE_TRAILER;
        }
        else {
          $self->[CURRENT_STATE] = STATE_DATA;
        }
      }
      else {
        # ok, this is a hack. skip to the next line if we
        # don't find the chunk length, it might just be an extra
        # line or something, and the chunk length always is on
        # a line of it's own, so this seems the only way to recover
        # somewhat.
        #TODO: after discussing on IRC, the concensus was to return
        #an error Response here, and have the client shut down the
        #connection.
        DEBUG and warn "DIDN'T FIND CHUNK LENGTH $chunk";
        my $replaceN = $chunk =~ s/.*?\015?\012//s;
        unshift (@{$self->[FRAMING_BUFFER]}, $chunk) if ($replaceN == 1);
        return $retval;
      }
    }

    if ($self->[CURRENT_STATE] & STATE_DATA) {
      my $len = $self->[CHUNK_SIZE] - length ($self->[CHUNK_BUFFER]);
      DEBUG and
        warn "going for length ", $self->[CHUNK_SIZE], " (need $len more)";
      my $newchunk = $self->[CHUNK_BUFFER];
      $self->[CHUNK_BUFFER] = "";
      $newchunk .= substr ($chunk, 0, $len, '');
      #warn "got " . length($newchunk) . " bytes of data";
      if (length $newchunk != $self->[CHUNK_SIZE]) {
        #smaller, so wait
        $self->[CHUNK_BUFFER] = $newchunk;
        next;
      }
      $self->[CURRENT_STATE] = STATE_SIZE;
      #warn "BACK TO FINDING CHUNK SIZE $chunk";
      if (length ($chunk) > 0) {
        DEBUG and warn "we still have a bit $chunk ", length($chunk);
        #warn "'", substr ($chunk, 0, 10), "'";
        $chunk =~ s/^\015?\012//s;
        #warn "'", substr ($chunk, 0, 10), "'";
        unshift (@{$self->[FRAMING_BUFFER]}, $chunk);
      }
      push @$retval, $newchunk;
      #return [$newchunk];
    }

    if ($self->[CURRENT_STATE] & STATE_TRAILER) {
      while ($chunk =~ s/^([-\w]+):\s*(.*?)\015?\012//s) {
        DEBUG and warn "add trailer header $1";
        $self->[TRAILER_HEADERS]->push_header ($1, $2);
      }
      #warn "leftover: ", $chunk;
      #warn join (
      #  ",",
      #  map {sprintf("%02X", ord($_))} split (//, substr ($chunk, 0, 10))
      #), "\n";
      if ($chunk =~ s/^\015?\012//s) {
        my $headers = delete $self->[TRAILER_HEADERS];

        push (@$retval, $headers);
        DEBUG and warn "returning ", scalar @$retval, "responses";
        unshift (@{$self->[FRAMING_BUFFER]}, $chunk) if (length $chunk);
        return $retval;
      }
      if (@{$self->[FRAMING_BUFFER]}) {
          $self->[FRAMING_BUFFER]->[0] = $chunk . $self->[FRAMING_BUFFER]->[0];
      } else {
          unshift (@{$self->[FRAMING_BUFFER]}, $chunk);
          return $retval;
      }
    }
  }
  return $retval;
}

=for future

sub put {
  die "not implemented yet";
}

=cut

sub get_pending {
  my $self = shift;
  return $self->[FRAMING_BUFFER] if @{$self->[FRAMING_BUFFER]};
  return undef;
}

__END__

# {{{ POD

=head1 NAME

POE::Filter::HTTPChunk - Non-blocking incremental HTTP chunk parser.

=head1 SYNOPSIS

  # Not a complete program.
  use POE::Filter::HTTPChunk;
  use POE::Wheel::ReadWrite;
  sub setup_io {
    $_[HEAP]->{io_wheel} = POE::Wheel::ReadWrite->new(
      Filter => POE::Filter::HTTPChunk->new(),
      # See POE::Wheel::ReadWrite for other required parameters.
    );
  }

=head1 DESCRIPTION

This filter parses HTTP chunks from a data stream.  It's used by
POE::Component::Client::HTTP to do the bulk of the low-level HTTP
parsing.

=head1 CONSTRUCTOR

=head2 new

C<new> takes no parameters and returns a shiny new
POE::Filter::HTTPChunk object ready to use.

=head1 METHODS

POE::Filter::HTTPChunk supports the following methods.  Most of them
adhere to the standard POE::Filter API.  The documentation for
POE::Filter explains the API in more detail.

=head2 get_one_start ARRAYREF

Accept an arrayref containing zero or more raw data chunks.  They are
added to the filter's input buffer.  The filter will attempt to parse
that data when get_one() is called.

  $filter_httpchunk->get_one_start(\@stream_data);

=head2 get_one

Parse a single HTTP chunk from the filter's input buffer.  Data is
entered into the buffer by the get_one_start() method.  Returns an
arrayref containing zero or one parsed HTTP chunk.

  $ret_arrayref = $filter_httpchunk->get_one();

=head2 get_pending

Returns an arrayref of stream data currently pending parsing.  It's
used to seamlessly transfer unparsed data between an old and a new
filter when a wheel's filter is changed.

  $pending_arrayref = $filter_httpchunk->get_pending();

=head1 SEE ALSO

L<POE::Filter>, L<POE>.

=head1 BUGS

None are known at this time.

=head1 AUTHOR & COPYRIGHTS

POE::Filter::HTTPChunk is...

=over 2

=item

Copyright 2005-2006 Martijn van Beers

=item

Copyright 2006 Rocco Caputo

=back

All rights are reserved.  POE::Filter::HTTPChunk is free software; you
may redistribute it and/or modify it under the same terms as Perl
itself.

=head1 CONTACT

Rocco may be contacted by e-mail via L<mailto:rcaputo@cpan.org>, and
Martijn may be contacted by email via L<mailto:martijn@cpan.org>.

The preferred way to report bugs or requests is through RT though.
See
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-Client-HTTP>
or mail L<mailto:bug-POE-Component-Client-HTTP@rt.cpan.org>

For questions, try the L<POE> mailing list (poe@perl.org)

=cut

# }}} POD
