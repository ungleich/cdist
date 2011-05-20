package POE::Wheel::ReadLine;

use warnings;
use strict;
BEGIN { eval { require bytes } and bytes->import; }

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw( croak carp );
use Symbol qw(gensym);
use POE qw( Wheel );
use base qw(POE::Wheel);
use POSIX ();

if ($^O eq "MSWin32") {
  die "$^O cannot run " . __PACKAGE__;
}

# After a massive hackathon on Cygwin/perl/windows/POE it was determined that
# having TERM='dumb' is worthless and VERY problematic to work-around...
# Actually, the problem lies deep in Term::Cap's internals - it blows up
# when we try to do "$termcap->Trequire( qw( cl ku kd kl kr) )" in new()
# eval{} will not catch the croak() in the sub
# Cygwin v1.7.1-1 on Windows Server 2008 64bit with Perl v5.10.1 with Term::Cap v1.12 with POE v1.287
# For detailed info, please consult RT#55365
# sorry about the defined $ENV{TERM} check, it was needed to make sure we spew no warnings...
if ($^O eq 'cygwin' and defined $ENV{TERM} and $ENV{TERM} eq 'dumb') {
  die "$^O with TERM='$ENV{TERM}' cannot run " . __PACKAGE__;
}

# Things we'll need to interact with the terminal.
use Term::Cap ();
use Term::ReadKey qw( ReadKey ReadMode GetTerminalSize );

my $initialised = 0;
my $termcap;         # Termcap entry.
my $tc_bell;         # How to ring the terminal.
my $tc_visual_bell;  # How to ring the terminal.
my $tc_has_ce;       # Termcap can clear to end of line.

# Private STDIN and STDOUT.
my $stdin  = gensym();
open($stdin, "<&STDIN") or die "Can't open private STDIN: $!";

my $stdout = gensym;
open($stdout, ">&STDOUT") or die "Can't open private STDOUT: $!";

# Offsets into $self.
sub SELF_INPUT          () {  0 }
sub SELF_CURSOR_INPUT   () {  1 }
sub SELF_EVENT_INPUT    () {  2 }
sub SELF_READING_LINE   () {  3 }
sub SELF_STATE_READ     () {  4 }
sub SELF_PROMPT         () {  5 }
sub SELF_HIST_LIST      () {  6 }
sub SELF_HIST_INDEX     () {  7 }
sub SELF_INPUT_HOLD     () {  8 }
sub SELF_KEY_BUILD      () {  9 }
sub SELF_INSERT_MODE    () { 10 }
sub SELF_PUT_MODE       () { 11 }
sub SELF_PUT_BUFFER     () { 12 }
sub SELF_IDLE_TIME      () { 13 }
sub SELF_STATE_IDLE     () { 14 }
sub SELF_HAS_TIMER      () { 15 }
sub SELF_CURSOR_DISPLAY () { 16 }
sub SELF_UNIQUE_ID      () { 17 }
sub SELF_KEYMAP         () { 18 }
sub SELF_OPTIONS        () { 19 }
sub SELF_APP            () { 20 }
sub SELF_ALL_KEYMAPS    () { 21 }
sub SELF_PENDING        () { 22 }
sub SELF_COUNT          () { 23 }
sub SELF_MARK           () { 24 }
sub SELF_MARKLIST       () { 25 }
sub SELF_KILL_RING      () { 26 }
sub SELF_LAST           () { 27 }
sub SELF_PENDING_FN     () { 28 }
sub SELF_SOURCE         () { 29 }
sub SELF_SEARCH         () { 30 }
sub SELF_SEARCH_PROMPT  () { 31 }
sub SELF_SEARCH_MAP     () { 32 }
sub SELF_PREV_PROMPT    () { 33 }
sub SELF_SEARCH_DIR     () { 34 }
sub SELF_SEARCH_KEY     () { 35 }
sub SELF_UNDO           () { 36 }

sub CRIMSON_SCOPE_HACK ($) { 0 }

#------------------------------------------------------------------------------

# Build a hash of input characters and their "normalized" display
# versions.  ISO Latin-1 characters (8th bit set "ASCII") are
# mishandled.  European users, please forgive me.  If there's a good
# way to handle this-- perhaps this is an interesting use for
# Unicode-- please let me know.

my (%normalized_character, @normalized_extra_width);

#------------------------------------------------------------------------------
# Gather information about the user's terminal.  This just keeps
# getting uglier.

my $ospeed = undef;
my $termios = undef;
my $term = undef;
my $tc_left = undef;
my $trk_cols = undef;
my $trk_rows = undef;

sub _curs_left {
  my $amount = shift;

  if ($tc_left eq "LE") {
    $termcap->Tgoto($tc_left, 1, $amount, $stdout);
    return;
  }

  for (1..$amount) {
    $termcap->Tgoto($tc_left, 1, 1, $stdout);
  }
}


our $defuns = {
"abort"                                  => \&rl_abort,
"accept-line"                            => \&rl_accept_line,
"backward-char"                          => \&rl_backward_char,
"backward-delete-char"                   => \&rl_backward_delete_char,
"backward-kill-line"                     => \&rl_unix_line_discard, # reuse emacs
"backward-kill-word"                     => \&rl_backward_kill_word,
"backward-word"                          => \&rl_backward_word,
"beginning-of-history"                   => \&rl_beginning_of_history,
"beginning-of-line"                      => \&rl_beginning_of_line,
"capitalize-word"                        => \&rl_capitalize_word,
"character-search"                       => \&rl_character_search,
"character-search-backward"              => \&rl_character_search_backward,
"clear-screen"                           => \&rl_clear_screen,
"complete"                               => \&rl_complete,
"copy-region-as-kill"                    => \&rl_copy_region_as_kill,
"delete-char"                            => \&rl_delete_char,
"delete-horizontal-space"                => \&rl_delete_horizontal_space,
"digit-argument"                         => \&rl_digit_argument,
"ding"                                   => \&rl_ding,
"downcase-word"                          => \&rl_downcase_word,
"dump-key"                               => \&rl_dump_key,
"dump-macros"                            => \&rl_dump_macros,
"dump-variables"                         => \&rl_dump_variables,
"emacs-editing-mode"                     => \&rl_emacs_editing_mode,
"end-of-history"                         => \&rl_end_of_history,
"end-of-line"                            => \&rl_end_of_line,
"forward-char"                           => \&rl_forward_char,
"forward-search-history"                 => \&rl_forward_search_history,
"forward-word"                           => \&rl_forward_word,
"insert-comment"                         => \&rl_insert_comment,
"insert-completions"                     => \&rl_insert_completions,
"insert-macro"                           => \&rl_insert_macro,
"interrupt"                              => \&rl_interrupt,
"isearch-again"                          => \&rl_isearch_again,
"kill-line"                              => \&rl_kill_line,
"kill-region"                            => \&rl_kill_region,
"kill-whole-line"                        => \&rl_kill_whole_line,
"kill-word"                              => \&rl_kill_word,
"next-history"                           => \&rl_next_history,
"non-incremental-forward-search-history" => \&rl_non_incremental_forward_search_history,
"non-incremental-reverse-search-history" => \&rl_non_incremental_reverse_search_history,
"overwrite-mode"                         => \&rl_overwrite_mode,
"poe-wheel-debug"                        => \&rl_poe_wheel_debug,
"possible-completions"                   => \&rl_possible_completions,
"previous-history"                       => \&rl_previous_history,
"quoted-insert"                          => \&rl_quoted_insert,
"re-read-init-file"                      => \&rl_re_read_init_file,
"redraw-current-line"                    => \&rl_redraw_current_line,
"reverse-search-history"                 => \&rl_reverse_search_history,
"revert-line"                            => \&rl_revert_line,
"search-abort"                           => \&rl_search_abort,
"search-finish"                          => \&rl_search_finish,
"search-key"                             => \&rl_search_key,
"self-insert"                            => \&rl_self_insert,
"set-keymap"                             => \&rl_set_keymap,
"set-mark"                               => \&rl_set_mark,
"tab-insert"                             => \&rl_ding, # UNIMPLEMENTED
"tilde-expand"                           => \&rl_tilde_expand,
"transpose-chars"                        => \&rl_transpose_chars,
"transpose-words"                        => \&rl_transpose_words,
"undo"                                   => \&rl_undo,
"unix-line-discard"                      => \&rl_unix_line_discard,
"unix-word-rubout"                       => \&rl_unix_word_rubout,
"upcase-word"                            => \&rl_upcase_word,
"vi-append-eol"                          => \&rl_vi_append_eol,
"vi-append-mode"                         => \&rl_vi_append_mode,
"vi-arg-digit"                           => \&rl_vi_arg_digit,
"vi-change-case"                         => \&rl_vi_change_case,
"vi-change-char"                         => \&rl_vi_change_char,
"vi-change-to"                           => \&rl_vi_change_to,
"vi-char-search"                         => \&rl_vi_char_search,
"vi-column"                              => \&rl_vi_column,
"vi-complete"                            => \&rl_vi_cmplete,
"vi-delete"                              => \&rl_vi_delete,
"vi-delete-to"                           => \&rl_vi_delete_to,
"vi-editing-mode"                        => \&rl_vi_editing_mode,
"vi-end-spec"                            => \&rl_vi_end_spec,
"vi-end-word"                            => \&rl_vi_end_word,
"vi-eof-maybe"                           => \&rl_vi_eof_maybe,
"vi-fetch-history"                       => \&rl_beginning_of_history, # re-use emacs version
"vi-first-print"                         => \&rl_vi_first_print,
"vi-goto-mark"                           => \&rl_vi_goto_mark,
"vi-insert-beg"                          => \&rl_vi_insert_beg,
"vi-insertion-mode"                      => \&rl_vi_insertion_mode,
"vi-match"                               => \&rl_vi_match,
"vi-movement-mode"                       => \&rl_vi_movement_mode,
"vi-next-word"                           => \&rl_vi_next_word,
"vi-prev-word"                           => \&rl_vi_prev_word,
"vi-put"                                 => \&rl_vi_put,
"vi-redo"                                => \&rl_vi_redo,
"vi-replace"                             => \&rl_vi_replace,
"vi-search"                              => \&rl_vi_search,
"vi-search-accept"                       => \&rl_vi_search_accept,
"vi-search-again"                        => \&rl_vi_search_again,
"vi-search-key"                          => \&rl_vi_search_key,
"vi-set-mark"                            => \&rl_vi_set_mark,
"vi-spec-beginning-of-line"              => \&rl_vi_spec_beginning_of_line,
"vi-spec-end-of-line"                    => \&rl_vi_spec_end_of_line,
"vi-spec-first-print"                    => \&rl_vi_spec_first_print,
"vi-spec-forward-char"                   => \&rl_vi_spec_forward_char,
"vi-spec-mark"                           => \&rl_vi_spec_mark,
"vi-spec-word"                           => \&rl_vi_spec_word,
"vi-subst"                               => \&rl_vi_subst,
"vi-tilde-expand"                        => \&rl_vi_tilde_expand,
"vi-undo"                                => \&rl_undo, # re-use emacs version
"vi-yank-arg"                            => \&rl_vi_yank_arg,
"vi-yank-to"                             => \&rl_vi_yank_to,
"yank"                                   => \&rl_yank,
"yank-last-arg"                          => \&rl_yank_last_arg,
"yank-nth-arg"                           => \&rl_yank_nth_arg,
"yank-pop"                               => \&rl_yank_pop,
};

# what functions are for counting
my @fns_counting = (
  'rl_vi_arg_digit',
  'rl_digit_argument',
  'rl_universal-argument',
);

# what functions are purely for movement...
my @fns_movement = (
  'rl_beginning_of_line',
  'rl_backward_char',
  'rl_forward_char',
  'rl_backward_word',
  'rl_forward_word',
  'rl_end_of_line',
  'rl_character_search',
  'rl_character_search_backward',
  'rl_vi_prev_word',
  'rl_vi_next_word',
  'rl_vi_goto_mark',
  'rl_vi_end_word',
  'rl_vi_column',
  'rl_vi_first_print',
  'rl_vi_char_search',
  'rl_vi_spec_char_search',
  'rl_vi_spec_end_of_line',
  'rl_vi_spec_beginning_of_line',
  'rl_vi_spec_first_print',
  'rl_vi_spec_word',
  'rl_vi_spec_mark',
);

# the list of functions that we don't want to record for
# later redo usage in vi mode.
my @fns_anon = (
  'rl_vi_redo',
  @fns_counting,
  @fns_movement,
);


my $defaults_inputrc = <<'INPUTRC';
set comment-begin #
INPUTRC

my $emacs_inputrc = <<'INPUTRC';
C-a: beginning-of-line
C-b: backward-char
C-c: interrupt
C-d: delete-char
C-e: end-of-line
C-f: forward-char
C-g: abort
C-h: backward-delete-char
C-i: complete
C-j: accept-line
C-k: kill-line
C-l: clear-screen
C-m: accept-line
C-n: next-history
C-p: previous-history
C-q: poe-wheel-debug
C-r: reverse-search-history
C-s: forward-search-history
C-t: transpose-chars
C-u: unix-line-discard
C-v: quoted-insert
C-w: unix-word-rubout
C-y: yank
C-]: character-search
C-_: undo
del: backward-delete-char
rubout: backward-delete-char

M-C-g: abort
M-C-h: backward-kill-word
M-C-i: tab-insert
M-C-j: vi-editing-mode
M-C-r: revert-line
M-C-y: yank-nth-arg
M-C-[: complete
M-C-]: character-search-backward
M-space: set-mark
M-#: insert-comment
M-&: tilde-expand
M-*: insert-completions
M--: digit-argument
M-.: yank-last-arg
M-0: digit-argument
M-1: digit-argument
M-2: digit-argument
M-3: digit-argument
M-4: digit-argument
M-5: digit-argument
M-6: digit-argument
M-7: digit-argument
M-8: digit-argument
M-9: digit-argument
M-<: beginning-of-history
M->: end-of-history
M-?: possible-completions

M-b: backward-word
M-c: capitalize-word
M-d: kill-word
M-f: forward-word
M-l: downcase-word
M-n: non-incremental-forward-search-history
M-p: non-incremental-reverse-search-history
M-r: revert-line
M-t: transpose-words
M-u: upcase-word
M-y: yank-pop
M-\: delete-horizontal-space
M-~: tilde-expand
M-del: backward-kill-word
M-_: yank-last-arg

C-xC-r: re-read-init-file
C-xC-g: abort
C-xDel: backward-kill-line
C-xm: dump-macros
C-xv: dump-variables
C-xk: dump-key

home: beginning-of-line
end: end-of-line
ins: overwrite-mode
del: delete-char
left: backward-char
right: forward-char
up: previous-history
down: next-history
bs: backward-delete-char
INPUTRC

my $vi_inputrc = <<'INPUTRC';

# VI uses two keymaps, depending on which mode we're in.
set keymap vi-insert

C-d: vi-eof-maybe
C-h: backward-delete-char
C-i: complete
C-j: accept-line
C-m: accept-line
C-r: reverse-search-history
C-s: forward-search-history
C-t: transpose-chars
C-u: unix-line-discard
C-v: quoted-insert
C-w: unix-word-rubout
C-y: yank
C-[: vi-movement-mode
C-_: undo
C-?: backward-delete-char

set keymap vi-command
C-d: vi-eof-maybe
C-e: emacs-editing-mode
C-g: abort
C-h: backward-char
C-j: accept-line
C-k: kill-line
C-l: clear-screen
C-m: accept-line
C-n: next-history
C-p: previous-history
C-q: quoted-insert
C-r: reverse-search-history
C-s: forward-search-history
C-t: transpose-chars
C-u: unix-line-discard
C-v: quoted-insert
C-w: unix-word-rubout
C-y: yank
C-_: vi-undo
" ": forward-char
"#": insert-comment
"$": end-of-line
"%": vi-match
"&": vi-tilde-expand
"*": vi-complete
"+": next-history
",": vi-char-search
"-": previous-history
".": vi-redo
"/": vi-search
"0": vi-arg-digit
"1": vi-arg-digit
"2": vi-arg-digit
"3": vi-arg-digit
"4": vi-arg-digit
"5": vi-arg-digit
"6": vi-arg-digit
"7": vi-arg-digit
"8": vi-arg-digit
"9": vi-arg-digit
";": vi-char-search
"=": vi-complete
"?": vi-search
A: vi-append-eol
B: vi-prev-word
C: vi-change-to
D: vi-delete-to
E: vi-end-word
F: vi-char-search
G: vi-fetch-history
I: vi-insert-beg
N: vi-search-again
P: vi-put
R: vi-replace
S: vi-subst
T: vi-char-search
U: revert-line
W: vi-next-word
X: backward-delete-char
Y: vi-yank-to
"\": vi-complete
"^": vi-first-print
"_": vi-yank-arg
"`": vi-goto-mark
a: vi-append-mode
b: backward-word
c: vi-change-to
d: vi-delete-to
e: vi-end-word
h: backward-char
i: vi-insertion-mode
j: next-history
k: previous-history
l: forward-char
m: vi-set-mark
n: vi-search-again
p: vi-put
r: vi-change-char
s: vi-subst
t: vi-char-search
w: vi-next-word
x: vi-delete
y: vi-yank-to
"|": vi-column
"~": vi-change-case

set keymap vi-specification
"^": vi-spec-first-print
"`": vi-spec-mark
"$": vi-spec-end-of-line
"0": vi-spec-beginning-of-line
"1": vi-arg-digit
"2": vi-arg-digit
"3": vi-arg-digit
"4": vi-arg-digit
"5": vi-arg-digit
"6": vi-arg-digit
"7": vi-arg-digit
"8": vi-arg-digit
"9": vi-arg-digit
w: vi-spec-word
t: vi-spec-forward-char

INPUTRC

my $search_inputrc = <<'INPUTRC';
set keymap isearch
C-r: isearch-again
C-s: isearch-again

set keymap vi-search
C-j: vi-search-accept
C-m: vi-search-accept
INPUTRC

#------------------------------------------------------------------------------
# Helper functions.

sub _vislength {
  return 0 unless $_[0];
  my $len = length($_[0]);
  while ($_[0] =~ m{(\\\[.*?\\\])}g) {
    $len -= length($1);
  }
  return $len;
}

# Wipe the current input line.
sub _wipe_input_line {
  my ($self) = shift;

  # Clear the current prompt and input, and home the cursor.
  _curs_left( $self->[SELF_CURSOR_DISPLAY] + _vislength($self->[SELF_PROMPT]));

  if ( $tc_has_ce ) {
    print $stdout $termcap->Tputs( 'ce', 1 );
  } else {
    my $wlen = _vislength($self->[SELF_PROMPT]) + _display_width($self->[SELF_INPUT]);
    print $stdout ( ' ' x $wlen);
    _curs_left($wlen);
  }
}

# Helper to flush any buffered output.
sub _flush_output_buffer {
  my ($self) = shift;

  # Flush anything buffered.
  if ( @{ $self->[SELF_PUT_BUFFER] } ) {
    print $stdout @{ $self->[SELF_PUT_BUFFER] };

    # Do not change the interior arrayref, or the event handlers will
    # become confused.
    @{ $self->[SELF_PUT_BUFFER] } = ();
  }
}

# Set up the prompt and input line like nothing happened.
sub _repaint_input_line {
  my ($self) = shift;
  my $sp = $self->[SELF_PROMPT];
  $sp =~ s{\\[\[\]]}{}g;
  print $stdout $sp, _normalize($self->[SELF_INPUT]);

  if ( $self->[SELF_CURSOR_INPUT] != length( $self->[SELF_INPUT]) ) {
    _curs_left(
      _display_width($self->[SELF_INPUT]) - $self->[SELF_CURSOR_DISPLAY]
    );
  }
}

sub _clear_to_end {
  my ($self) = @_;
  if (length $self->[SELF_INPUT]) {
    if ($tc_has_ce) {
      print $stdout $termcap->Tputs( 'ce', 1 );
    } else {
      my $display_width = _display_width($self->[SELF_INPUT]);
      print $stdout ' ' x $display_width;
      _curs_left($display_width);
    }
  }
}

sub _delete_chars {
  my ($self, $from, $howmany) = @_;
  # sanitize input
  if ($howmany < 0) {
    $from -= $howmany;
    $howmany = -$howmany;
    if ($from < 0) {
      $howmany -= $from;
      $from = 0;
    }
  }

  my $old = substr($self->[SELF_INPUT], $from, $howmany);
  my $killed_width = _display_width($old);
  substr($self->[SELF_INPUT], $from, $howmany) = '';
  if ($self->[SELF_CURSOR_INPUT] > $from) {
    my $newdisp = length(_normalize(substr($self->[SELF_INPUT], 0, $from)));
    _curs_left($self->[SELF_CURSOR_DISPLAY] - $newdisp);
    $self->[SELF_CURSOR_INPUT] = $from;
    $self->[SELF_CURSOR_DISPLAY] = $newdisp;
  }

  my $normal_remaining = _normalize(substr($self->[SELF_INPUT], $from));
  print $stdout $normal_remaining;
  my $normal_remaining_length = length($normal_remaining);

  if ($tc_has_ce) {
    print $stdout $termcap->Tputs( 'ce', 1 );
  } else {
    print $stdout ' ' x $killed_width;
    $normal_remaining_length += $killed_width;
  }

  _curs_left($normal_remaining_length)
  if $normal_remaining_length;

  return $old;
}

sub _search {
  my ($self, $rebuild) = @_;
  if ($rebuild) {
    $self->_wipe_input_line;
    $self->_build_search_prompt;
  }
  # find in history....
  my $found = 0;
  for (
    my $i = $self->[SELF_HIST_INDEX];
    $i < scalar @{$self->[SELF_HIST_LIST]} && $i >= 0;
    $i += $self->[SELF_SEARCH_DIR]
  ) {
    next unless $self->[SELF_HIST_LIST]->[$i] =~ /$self->[SELF_SEARCH]/;

    $self->[SELF_HIST_INDEX] = $i;
    $self->[SELF_INPUT] = $self->[SELF_HIST_LIST]->[$i];
    $self->[SELF_CURSOR_INPUT] = 0;
    $self->[SELF_CURSOR_DISPLAY] = 0;
    $self->[SELF_UNDO] = [ $self->[SELF_INPUT], 0, 0 ]; # reset undo info
    $found++;
    last;
  }
  $self->rl_ding unless $found;
  $self->_repaint_input_line;
}

# Return a normalized version of a string.  This includes destroying
# 8th-bit-set characters, turning them into strange multi-byte
# sequences.  Apologies to everyone; please let me know of a portable
# way to deal with this.
sub _normalize {
  local $_ = shift;
  s/([^ -~])/$normalized_character{$1}/g;
  return $_;
}

sub _readable_key {
  my ($raw_key) = @_;
  my @text = ();
  foreach my $l (split(//, $raw_key)) {
    if (ord($l) == 0x1B) {
      push(@text, 'Meta-');
      next;
    }
    if (ord($l) < 32) {
      push(@text, 'Control-' . chr(ord($l)+64));
      next;
    }
    if (ord($l) > 127) {
      my $l = ord($l)-128;
      if ($l < 32) {
        $l = "Control-" . chr($l+64);
      }
      push(@text, 'Meta-' . chr($l));
      next;
    }
    if (ord($l) == 127) {
      push @text, "^?";
      next;
    }
    push(@text, $l);
  }
  return join("", @text);
}

# Calculate the display width of a string.  The display width is
# sometimes wider than the actual string because some characters are
# represented on the terminal as multiple characters.

sub _display_width {
  local $_ = shift;
  my $width = length;
  $width += $normalized_extra_width[ord] foreach (m/([\x00-\x1F\x7F-\xFF])/g);
  return $width;
}

sub _build_search_prompt {
  my ($self) = @_;
  $self->[SELF_PROMPT] = $self->[SELF_SEARCH_PROMPT];
  $self->[SELF_PROMPT] =~ s{%s}{$self->[SELF_SEARCH]};
}

sub _global_init {
  return if $initialised;

  # Get the terminal speed for Term::Cap.
  $termios = POSIX::Termios->new();
  $termios->getattr();
  $ospeed = $termios->getospeed() || eval { POSIX::B38400() } || 0;

  # Get the current terminal's capabilities.
  $term = $ENV{TERM} || 'vt100';
  $termcap = eval { Term::Cap->Tgetent( { TERM => $term, OSPEED => $ospeed } ) };
  die "could not find termcap entry for ``$term'': $!" unless defined $termcap;

  # Require certain capabilities.
  $termcap->Trequire( qw( cl ku kd kl kr) );

  # Cursor movement.
  $tc_left = "LE";
  eval { $termcap->Trequire($tc_left) };
  if ($@) {
    $tc_left = "le";
    eval { $termcap->Trequire($tc_left) };
    if ($@) {
      # try out to see if we have a better terminfo defun.
      # it may well not work (hence eval the lot), but it's worth a shot
      eval {
        my @tc = `infocmp -C $term`;
        chomp(@tc);
        splice(@tc, 0, 1); # remove header line
        $ENV{TERMCAP} = join("", @tc);
        $termcap = Term::Cap->Tgetent( { TERM => $term, OSPEED => $ospeed } );
        $termcap->Trequire($tc_left);
      };
    }
    die "POE::Wheel::ReadLine requires a termcap that supports LE or le" if $@;
  }

  # Terminal size.
  # We initialize the values once on start-up,
  # and then from then on, we check them on every entry into
  # the input state engine (so that we have valid values) and
  # before handing control back to the user (so that they get
  # an up-to-date value).
  eval { ($trk_cols, $trk_rows) = GetTerminalSize($stdout) };
  ($trk_cols, $trk_rows) = (80, 25) if $@;

  # Configuration...
  # Some things are optional.
  eval { $termcap->Trequire( 'ce' ) };
  $tc_has_ce = 1 unless $@;

  # o/` You can ring my bell, ring my bell. o/`
  my $bell = $termcap->Tputs( bl => 1 );
  $bell = $termcap->Tputs( vb => 1 ) unless defined $bell;
  $tc_bell = (defined $bell) ? $bell : '';
  $bell = $termcap->Tputs( vb => 1 ) || '';
  $tc_visual_bell = $bell;

  my $convert_meta = 1;
  for (my $ord = 0; $ord < 256; $ord++) {
    my $str = chr($ord);
    if ($ord > 127) {
      if ($convert_meta) {
        $str = "^[";
        if (($ord - 128) < 32) {
          $str .= "^" . lc(chr($ord-128+64));
        } else {
          $str .= lc(chr($ord-128));
        }
      } else {
        $str = sprintf "<%2x>", $ord;
      }
    } elsif ($ord < 32) {
      $str = '^' . lc(chr($ord+64));
    }
    elsif ($ord == 127) {
      $str = "^?";
    }
    $normalized_character{chr($ord)} = $str;
    $normalized_extra_width[$ord] = length ( $str ) - 1;
  }
  $initialised++;
}

#------------------------------------------------------------------------------
# The methods themselves.

# Create a new ReadLine wheel.
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my %params = @_;
  croak "$class requires a working Kernel" unless defined $poe_kernel;

  my $input_event = delete $params{InputEvent};
  croak "$class requires an InputEvent parameter" unless defined $input_event;

  my $put_mode = delete $params{PutMode};
  $put_mode = 'idle' unless defined $put_mode;
  croak "$class PutMode must be either 'immediate', 'idle', or 'after'"
    unless $put_mode =~ /^(immediate|idle|after)$/;

  my $idle_time = delete $params{IdleTime};
  $idle_time = 2 unless defined $idle_time;

  my $app = delete($params{AppName}) || delete($params{appname});
  delete $params{appname}; # in case AppName was present
  $app ||= 'poe-readline';

  if (scalar keys %params) {
    carp(
      "unknown parameters in $class constructor call: ",
      join(', ', keys %params)
    );
  }

  my $self = undef;
  if (ref $proto) {
    $self = bless [], $class;
    @$self = @$proto;
    $self->[SELF_SOURCE] = $proto;
    # ensure we're not bound to the old handler
    $poe_kernel->select_read($stdin);
  } else {
    $self = bless [
      '',           # SELF_INPUT
      0,            # SELF_CURSOR_INPUT
      $input_event, # SELF_EVENT_INPUT
      0,            # SELF_READING_LINE
      undef,        # SELF_STATE_READ
      '>',          # SELF_PROMPT
      [ ],          # SELF_HIST_LIST
      0,            # SELF_HIST_INDEX
      '',           # SELF_INPUT_HOLD
      '',           # SELF_KEY_BUILD
      1,            # SELF_INSERT_MODE
      $put_mode,    # SELF_PUT_MODE
      [ ],          # SELF_PUT_BUFFER
      $idle_time,   # SELF_IDLE_TIME
      undef,        # SELF_STATE_IDLE
      0,            # SELF_HAS_TIMER
      0,            # SELF_CURSOR_DISPLAY
      &POE::Wheel::allocate_wheel_id(),  # SELF_UNIQUE_ID
      undef,        # SELF_KEYMAP
      { },          # SELF_OPTIONS
      $app,         # SELF_APP
      {},           # SELF_ALL_KEYMAPS
      undef,        # SELF_PENDING
      0,            # SELF_COUNT
      0,            # SELF_MARK
      {},           # SELF_MARKLIST
      [],           # SELF_KILL_RING
      '',           # SELF_LAST
      undef,        # SELF_PENDING_FN
      undef,        # SELF_SOURCE
      '',           # SELF_SEARCH
      undef,        # SELF_SEARCH_PROMPT
      undef,        # SELF_SEARCH_MAP
      '',           # SELF_PREV_PROMPT
      0,            # SELF_SEARCH_DIR
      '',           # SELF_SEARCH_KEY
      [],           # SELF_UNDO
    ], $class;

    _global_init();
    $self->rl_re_read_init_file();
  }

  # Turn off $stdout buffering.
  select((select($stdout), $| = 1)[0]);

  # Set up the event handlers.  Idle goes first.
  $self->[SELF_STATE_IDLE] = (
    ref($self) . "(" . $self->[SELF_UNIQUE_ID] . ") -> input timeout"
  );

  $self->[SELF_STATE_READ] = (
    ref($self) . "(" . $self->[SELF_UNIQUE_ID] . ") -> select read"
  );

  # TODO - The following hack breaks a circular reference on $self.
  {
    my $weak_self = $self;
    use Scalar::Util qw(weaken);
    weaken $weak_self;

    $poe_kernel->state(
      $self->[SELF_STATE_IDLE],
      sub { _idle_state($weak_self, @_[1..$#_]) }
    );

    $poe_kernel->state(
      $self->[SELF_STATE_READ],
      sub { _read_state($weak_self, @_[1..$#_]) }
    );
  }

  return $self;
}

#------------------------------------------------------------------------------
# Destroy the ReadLine wheel.  Clean up the terminal.

sub DESTROY {
  my $self = shift;

  return unless $initialised;

  # Stop selecting on the handle.
  $poe_kernel->select_read($stdin);

  # Detach our tentacles from the parent session.
  if ($self->[SELF_STATE_READ]) {
    $poe_kernel->state($self->[SELF_STATE_READ]);
    $self->[SELF_STATE_READ] = undef;
  }

  if ($self->[SELF_STATE_IDLE]) {
    $poe_kernel->alarm($self->[SELF_STATE_IDLE]);
    $poe_kernel->state($self->[SELF_STATE_IDLE]);
    $self->[SELF_STATE_IDLE] = undef;
  }

  # tell the terminal that we want to leave 'application' mode
  print $termcap->Tputs('ke' => 1) if $termcap->Tputs('ke');
  # Restore the console.
  ReadMode('restore');

  &POE::Wheel::free_wheel_id($self->[SELF_UNIQUE_ID]);
}

#------------------------------------------------------------------------------
# Redefine the idle handler.  This also uses stupid closure tricks.
# See the comments for &_define_read_state for more information about
# these closure tricks.

sub _idle_state {
  my ($self) = $_[OBJECT];

  if (@{$self->[SELF_PUT_BUFFER]}) {
    $self->_wipe_input_line;
    $self->_flush_output_buffer;
    $self->_repaint_input_line;
  }

  # No more timer.
  $self->[SELF_HAS_TIMER] = 0;
}

sub _read_state {
  my ($self, $k) = @_[OBJECT, KERNEL];

  # Read keys, non-blocking, as long as there are some.
  while (defined(my $raw_key = ReadKey(-1))) {

    # Not reading a line; discard the input.
    next unless $self->[SELF_READING_LINE];

    # Update the timer on significant input.
    if ( $self->[SELF_PUT_MODE] eq 'idle' ) {
      $k->delay( $self->[SELF_STATE_IDLE], $self->[SELF_IDLE_TIME] );
      $self->[SELF_HAS_TIMER] = 1;
    }

    push(
      @{$self->[SELF_UNDO]}, [
        $self->[SELF_INPUT],
        $self->[SELF_CURSOR_INPUT],
        $self->[SELF_CURSOR_DISPLAY]
      ]
    );

    # Build-multi character codes and make the keystroke printable.
    $self->[SELF_KEY_BUILD] .= $raw_key;
    $raw_key = $self->[SELF_KEY_BUILD];
    my $key = _normalize($raw_key);

    if ($self->[SELF_PENDING_FN]) {
      my $old = $self->[SELF_INPUT];
      my $oldref = $self->[SELF_PENDING_FN];
      push(
        @{$self->[SELF_UNDO]}, [
          $old,
          $self->[SELF_CURSOR_INPUT],
          $self->[SELF_CURSOR_DISPLAY]
        ]
      );
      $self->[SELF_PENDING_FN]->($self, $key, $raw_key);
      pop(@{$self->[SELF_UNDO]}) if ($old eq $self->[SELF_INPUT]);
      $self->[SELF_KEY_BUILD] = '';
      if ($self->[SELF_PENDING_FN] && "$self->[SELF_PENDING_FN]" eq $oldref) {
        $self->[SELF_PENDING_FN] = undef;
      }
      next;
    }

    # Keep glomming keystrokes until they stop existing in the
    # hash of meta prefixes.
    next if exists $self->[SELF_KEYMAP]->{prefix}->{$raw_key};

    # PROCESS KEY
    my $old = $self->[SELF_INPUT];
    push(
      @{$self->[SELF_UNDO]}, [
        $old,
        $self->[SELF_CURSOR_INPUT],
        $self->[SELF_CURSOR_DISPLAY]
      ]
    );
    $self->[SELF_KEY_BUILD] = '';
    $self->_apply_key($key, $raw_key);

    pop(@{$self->[SELF_UNDO]}) if ($old eq $self->[SELF_INPUT]);
  }
}

sub _apply_key {
  my ($self, $key, $raw_key) = @_;
  my $mapping = $self->[SELF_KEYMAP];
  my $fn = $mapping->{default};

  if (exists $mapping->{binding}->{$raw_key}) {
    $fn = $mapping->{binding}->{$raw_key};
  }

  # print "\r\ninvoking $fn for $key\r\n";$self->_repaint_input_line;
  if ($self->[SELF_COUNT] && !grep { $_ eq $fn } @fns_counting) {
    $self->[SELF_COUNT] = int($self->[SELF_COUNT]);
    $self->[SELF_COUNT] ||= 1;
    while ($self->[SELF_COUNT] > 0) {
      if (ref $fn) {
        $self->$fn($key, $raw_key);
      } else {
        &{$defuns->{$fn}}($self, $key, $raw_key);
      }
      $self->[SELF_COUNT]--;
    }
    $self->[SELF_COUNT] = "";
  } else {
    if (ref $fn) {
      $self->$fn($key, $raw_key);
    } else {
      &{$defuns->{$fn}}($self, $key, $raw_key);
    }
  }
  $self->[SELF_LAST] = $fn unless grep { $_ eq $fn } @fns_anon;
}

# Send a prompt; get a line.
sub get {
  my ($self, $prompt) = @_;

  # Already reading a line here, people.  Sheesh!
  return if $self->[SELF_READING_LINE];
  # recheck the terminal size every prompt, in case the size
  # has changed
  eval { ($trk_cols, $trk_rows) = GetTerminalSize($stdout) };
  ($trk_cols, $trk_rows) = (80, 25) if $@;

  ReadMode('ultra-raw');
  # Tell the terminal that we want to be in 'application' mode.
  print $termcap->Tputs('ks' => 1) if $termcap->Tputs('ks');

  # Set up for the read.
  $self->[SELF_READING_LINE]   = 1;
  $self->[SELF_PROMPT]         = $prompt;
  $self->[SELF_INPUT]          = '';
  $self->[SELF_CURSOR_INPUT]   = 0;
  $self->[SELF_CURSOR_DISPLAY] = 0;
  $self->[SELF_HIST_INDEX]     = @{$self->[SELF_HIST_LIST]};
  $self->[SELF_INSERT_MODE]    = 1;
  $self->[SELF_UNDO]           = [];
  $self->[SELF_LAST]           = '';

  # Watch the filehandle.  STDIN is made blocking to avoid buffer
  # overruns when put()ing large quantities of data.
  # TODO - Why does it matter to STDOUT whether STDIN is blocking?
  # TODO - Why does AIX require STDIN to be non-blocking?
  $poe_kernel->select($stdin, $self->[SELF_STATE_READ]);
  $stdin->blocking(1) unless $^O eq 'aix';

  my $sp = $prompt;
  $sp =~ s{\\[\[\]]}{}g;

  print $stdout $sp;
}

# Write a line on the terminal.
sub put {
  my $self = shift;
  my @lines = map { $_ . "\x0D\x0A" } @_;

  # Write stuff immediately under certain conditions: (1) The wheel is
  # in immediate mode.  (2) The wheel currently isn't reading a line.
  # (3) The wheel is in idle mode, and there.

  if (
    $self->[SELF_PUT_MODE] eq 'immediate' or
    !$self->[SELF_READING_LINE] or
    ( $self->[SELF_PUT_MODE] eq 'idle' and !$self->[SELF_HAS_TIMER] )
  ) {

    # Only clear the input line if we're reading input already
    $self->_wipe_input_line if ($self->[SELF_READING_LINE]);

    # Print the new stuff.
    $self->_flush_output_buffer;
    print $stdout @lines;

    # Only repaint the input if we're reading a line.
    $self->_repaint_input_line if ($self->[SELF_READING_LINE]);

    return;
  }

  # Otherwise buffer stuff.
  push @{$self->[SELF_PUT_BUFFER]}, @lines;

  # Set a timer, if timed.
  if ( $self->[SELF_PUT_MODE] eq 'idle' and !$self->[SELF_HAS_TIMER] ) {
    $poe_kernel->delay( $self->[SELF_STATE_IDLE], $self->[SELF_IDLE_TIME] );
    $self->[SELF_HAS_TIMER] = 1;
  }
}

# Clear the screen.
sub clear {
  my $self = shift;
  $termcap->Tputs( cl => 1, $stdout );
}

sub terminal_size {
  return ($trk_cols, $trk_rows);
}

# Add things to the edit history.
sub add_history {
  my $self = shift;
  push @{$self->[SELF_HIST_LIST]}, @_;
}

# RCC 2008-06-15. Backwards compatibility.
*addhistory = *add_history;

sub get_history {
  my $self = shift;
  return @{$self->[SELF_HIST_LIST]};
}

# RCC 2008-06-15. Backwards compatibility.
*GetHistory = *get_history;

sub write_history {
  my ($self, $file) = @_;
  $file ||= "$ENV{HOME}/.history";
  open(HIST, ">$file") || return undef;
  print HIST join("\n", @{$self->[SELF_HIST_LIST]}) . "\n";
  close(HIST);
  return 1;
}

# RCC 2008-06-15. Backwards compatibility.
*WriteHistory = *write_history;

sub read_history {
  my ($self, $file, $from, $to) = @_;
  $from ||= 0;
  $to = -1 unless defined $to;
  $file ||= "$ENV{HOME}/.history";
  open(HIST, $file) or return undef;
  my @hist = <HIST>;
  close(HIST);
  my $line = 0;
  foreach my $h (@hist) {
    chomp($h);
    $self->add_history($h) if ($line >= $from && ($to < $from || $line <= $to));
    $line++;
  }
  return 1;
}

# RCC 2008-06-15. Backwards compatibility.
*ReadHistory = *read_history;

sub history_truncate_file {
  my ($self, $file, $lines) = @_;
  $lines ||= 0;
  $file ||= "$ENV{HOME}/.history";
  open(HIST, $file) or return undef;
  my @hist = <HIST>;
  close(HIST);
  chomp(@hist);

  if ((scalar @hist) > $lines) {
    open(HIST, ">$file") or return undef;
    if ($lines) {
      splice(@hist, 0, (scalar @hist)-$lines);
      @{$self->[SELF_HIST_LIST]} = @hist;
      print HIST "$_\n" foreach @hist;
    } else {
      @{$self->[SELF_HIST_LIST]} = ();
    }
    close(HIST);
  }
  return 1;
}

# Get the wheel's ID.
sub ID {
  return $_[0]->[SELF_UNIQUE_ID];
}

sub attribs {
  my ($self) = @_;
  return $self->[SELF_OPTIONS];
}

# RCC 2008-06-15. Backwards compatibility.
*Attribs = *attribs;

sub option {
  my ($self, $arg) = @_;
  $arg = lc($arg);
  return "" unless exists $self->[SELF_OPTIONS]->{$arg};
  return $self->[SELF_OPTIONS]->{$arg};
}

sub _init_keymap {
  my ($self, $default, @names) = @_;
  my $name = $names[0];
  if (!exists $defuns->{$default}) {
    die("cannot initialise keymap $name, since default function $default is unknown")
  }
  my $map = POE::Wheel::ReadLine::Keymap->init(
    default => $default,
    name    => $name,
    termcap => $termcap
  );
  foreach my $n (@names) {
    $self->[SELF_ALL_KEYMAPS]->{$n} = $map;
  }
  return $map;
}

sub rl_re_read_init_file {
  my ($self) = @_;

  $self->_init_keymap('self-insert', 'emacs');
  $self->_init_keymap('ding', 'vi-command', 'vi');
  $self->_init_keymap('self-insert', 'vi-insert');

  # searching
  my $isearch = $self->_init_keymap('search-finish', 'isearch');
  my $vi_search = $self->_init_keymap('search-finish', 'vi-search');
  $self->_parse_inputrc($search_inputrc);

  # A keymap to take the VI range specification commands
  # used by the -to commands (e.g. change-to, etc)
  $self->_init_keymap('vi-end-spec', 'vi-specification');

  $self->_parse_inputrc($defaults_inputrc);

  $self->rl_set_keymap('vi');
  $self->_parse_inputrc($vi_inputrc);

  $self->rl_set_keymap('emacs');
  $self->_parse_inputrc($emacs_inputrc);

  my $personal = exists $ENV{INPUTRC} ? $ENV{INPUTRC} : "$ENV{HOME}/.inputrc";
  foreach my $file ($personal) {
    my $input = "";
    if (open(IN, $file)) {
      local $/ = undef;
      $input = <IN>;
      close(IN);
      $self->_parse_inputrc($input);
    }
  }

  if (!$self->option('editing-mode')) {
    $self->[SELF_OPTIONS]->{'editing-mode'} = 'emacs';
  }

  if ($self->option('editing-mode') eq 'vi') {
    # by default, start in insert mode already
    $self->rl_set_keymap('vi-insert');
  }

  my $isearch_term = $self->option('isearch-terminators') || 'C-[ C-J';
  foreach my $key (split(/\s+/, $isearch_term)) {
    $isearch->bind_key($key, 'search-abort');
  }
  foreach my $key (ord(' ') .. ord('~')) {
    $isearch->bind_key('"' . chr($key) . '"', 'search-key');
    $vi_search->bind_key('"' . chr($key) . '"', 'vi-search-key');
  }
}

sub _parse_inputrc {
  my ($self, $input, $depth) = @_;
  $depth ||= 0;
  my @cond = (); # allows us to nest conditionals.

  foreach my $line (split(/\n+/, $input)) {
    next if $line =~ /^#/;
    if ($line =~ /^\$(.*)/) {
      my (@parms) = split(/[ \t+=]/,$1);
      if ($parms[0] eq 'if') {
        my $bool = 0;
        if ($parms[1] eq 'mode') {
          if ($self->option('editing-mode') eq $parms[2]) {
            $bool = 1;
          }
        } elsif ($parms[1] eq 'term') {
          my ($half, $full) = ($ENV{TERM} =~ /^([^-]*)(-.*)?$/);
          if ($half eq $parms[2] || ($full && $full eq $parms[2])) {
            $bool = 1;
          }
        } elsif ($parms[1] eq $self->[SELF_APP]) {
          $bool = 1;
        }
        push(@cond, $bool);
      } elsif ($parms[0] eq 'else') {
        $cond[$#cond] = not $cond[$#cond];
      } elsif ($parms[0] eq 'endif') {
        pop(@cond);
      } elsif ($parms[0] eq 'include') {
        if ($depth > 10) {
          print STDERR "WARNING: ignoring ``include $parms[1] directive, since we're too deep''";
        } else {
          my $fh = gensym;
          if (open $fh, "< $parms[1]\0") {
            my $contents = do { local $/; <$fh> };
            close $fh;
            $self->_parse_inputrc($contents, $depth+1);
          }
        }
      }
    } else {
      next if (scalar @cond and not $cond[$#cond]);
      if ($line =~ /^set\s+([\S]+)\s+([\S]+)/) {
        my ($var,$val) = ($1, $2);
        $self->[SELF_OPTIONS]->{lc($var)} = $val;
        my $fn = "rl_set_" . lc($var);
        $fn =~ s{-}{_}g;
        if ($self->can($fn)) {
          $self->$fn($self->[SELF_OPTIONS]->{$var});
        }
      } elsif ($line =~ /^([^:]+):\s*(.*)/) {
        my ($seq, $fn) = ($1, lc($2));
        chomp($fn);
        $self->[SELF_KEYMAP]->bind_key($seq, $fn);
      }
    }
  }
}

# take a key and output it in a form nice to read...
sub _dump_key_line {
  my ($self, $key, $raw_key) = @_;
  if (exists $self->[SELF_KEYMAP]->{prefix}->{$raw_key}) {
    $self->[SELF_PENDING_FN] = sub {
      my ($s, $k, $rk) = @_;
      $s->_dump_key_line($key.$k, $raw_key.$rk);
    };
    return;
  }

  my $fn = $self->[SELF_KEYMAP]->{default};
  if (exists $self->[SELF_KEYMAP]->{binding}->{$raw_key}) {
    $fn = $self->[SELF_KEYMAP]->{binding}->{$raw_key};
  }
  if (ref $fn) {
    $fn = "[coderef]";
  }

  print "\x0D\x0A" . _readable_key($raw_key) . ": " . $fn . "\x0D\x0A";
  $self->_repaint_input_line;
}

sub bind_key {
  my ($self, $seq, $fn, $map) = @_;
  $map ||= $self->[SELF_KEYMAP];
  $map->bind_key($seq, $fn);
}

sub add_defun {
  my ($self, $name, $fn) = @_;
  $defuns->{$name} = $fn;
}

# -----------------------------------------------------
# Any variable assignments that we care about
# -----------------------------------------------------
sub rl_set_keymap {
  my ($self, $arg) = @_;
  $arg = lc($arg);
  if (exists $self->[SELF_ALL_KEYMAPS]->{$arg}) {
    $self->[SELF_KEYMAP] = $self->[SELF_ALL_KEYMAPS]->{$arg};
    $self->[SELF_OPTIONS]->{keymap} = $self->[SELF_KEYMAP]->{name};
  }
  # always reset overstrike mode on keymap change
  $self->[SELF_INSERT_MODE] = 1;
}

# ----------------------------------------------------
# From here on, we have the helper functions which can
# be bound to keys. The functions are named after the
# readline counterparts.
# ----------------------------------------------------

sub rl_self_insert {
  my ($self, $key, $raw_key) = @_;

  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    if ($self->[SELF_INSERT_MODE]) {
      # Insert.
      my $normal = _normalize(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]));
      substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 0) = $raw_key;
      print $stdout $key, $normal;
      $self->[SELF_CURSOR_INPUT] += length($raw_key);
      $self->[SELF_CURSOR_DISPLAY] += length($key);
      _curs_left(length($normal));
    } else {
      # Overstrike.
      my $replaced_width = _display_width(
        substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], length($raw_key))
      );
      substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], length($raw_key)) = $raw_key;

      print $stdout $key;
      $self->[SELF_CURSOR_INPUT] += length($raw_key);
      $self->[SELF_CURSOR_DISPLAY] += length($key);

      # Expand or shrink the display if unequal replacement.
      if (length($key) != $replaced_width) {
        my $rest = _normalize(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]));
        # Erase trailing screen cruft if it's shorter.
        if (length($key) < $replaced_width) {
          $rest .= ' ' x ($replaced_width - length($key));
        }
        print $stdout $rest;
        _curs_left(length($rest));
      }
    }
  } else {
    # Append.
    print $stdout $key;
    $self->[SELF_INPUT] .= $raw_key;
    $self->[SELF_CURSOR_INPUT] += length($raw_key);
    $self->[SELF_CURSOR_DISPLAY] += length($key);
  }
}

sub rl_insert_macro {
  my ($self, $key) = @_;
  my $macro = $self->[SELF_KEYMAP]->{macros}->{$key};
  $macro =~ s{\\a}{$tc_bell}g;
  $macro =~ s{\\r}{\r}g;
  $macro =~ s{\\n}{\n}g;
  $macro =~ s{\\t}{\t}g;
  $self->rl_self_insert($macro, $macro);
}

sub rl_insert_comment {
  my ($self) = @_;
  my $comment = $self->option('comment-begin');
  $self->_wipe_input_line;
  if ($self->[SELF_COUNT]) {
    if (substr($self->[SELF_INPUT], 0, length($comment)) eq $comment) {
      substr($self->[SELF_INPUT], 0, length($comment)) = "";
    } else {
      $self->[SELF_INPUT] = $comment . $self->[SELF_INPUT];
    }
    $self->[SELF_COUNT] = 0;
  } else {
    $self->[SELF_INPUT] = $comment . $self->[SELF_INPUT];
  }
  $self->_repaint_input_line;
  $self->rl_accept_line;
}

sub rl_revert_line {
  my ($self) = @_;
  return $self->rl_ding unless scalar @{$self->[SELF_UNDO]};
  $self->_wipe_input_line;
  (
    $self->[SELF_INPUT],
    $self->[SELF_CURSOR_INPUT],
    $self->[SELF_CURSOR_DISPLAY]
  ) = @{$self->[SELF_UNDO]->[0]};
  $self->[SELF_UNDO] = [];
  $self->_repaint_input_line;
}

sub rl_yank_last_arg {
  my ($self) = @_;
  if ($self->[SELF_HIST_INDEX] == 0) {
    return $self->rl_ding;
  }
  if ($self->[SELF_COUNT]) {
    return &rl_yank_nth_arg;
  }
  my $prev = $self->[SELF_HIST_LIST]->[$self->[SELF_HIST_INDEX]-1];
  my ($arg) = ($prev =~ m{(\S+)$});
  $self->rl_self_insert($arg, $arg);
  1;
}

sub rl_yank_nth_arg {
  my ($self) = @_;
  if ($self->[SELF_HIST_INDEX] == 0) {
    return $self->rl_ding;
  }
  my $prev = $self->[SELF_HIST_LIST]->[$self->[SELF_HIST_INDEX]-1];
  my @args = split(/\s+/, $prev);
  my $pos = $self->[SELF_COUNT] || 1;
  $self->[SELF_COUNT] = 0;
  if ($pos < 0) {
    $pos = (scalar @args) + $pos;
  }
  if ($pos > scalar @args || $pos < 0) {
    return $self->rl_ding;
  }
  $self->rl_self_insert($args[$pos], $args[$pos]);
}

sub rl_dump_key {
  my ($self) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s,$k,$rk) = @_;
    $s->_dump_key_line($k, $rk);
  };
}

sub rl_dump_macros {
  my ($self) = @_;
  print $stdout "\x0D\x0A";
  my $c = 0;
  foreach my $macro (keys %{$self->[SELF_KEYMAP]->{macros}}) {
    print $stdout '"' . _normalize($macro) . "\": \"$self->[SELF_KEYMAP]->{macros}->{$macro}\"\x0D\x0A";
    $c++;
  }
  if (!$c) {
    print "# no macros defined\x0D\x0A";
  }
  $self->_repaint_input_line;
}

sub rl_dump_variables {
  my ($self) = @_;
  print $stdout "\x0D\x0A";
  my $c = 0;
  foreach my $var (keys %{$self->[SELF_OPTIONS]}) {
    print $stdout "set $var $self->[SELF_OPTIONS]->{$var}\x0D\x0A";
    $c++;
  }
  if (!$c) {
    print "# no variables defined\x0D\x0A";
  }
  $self->_repaint_input_line;
}

sub rl_set_mark {
  my ($self) = @_;
  if ($self->[SELF_COUNT]) {
    $self->[SELF_MARK] = $self->[SELF_COUNT];
  } else {
    $self->[SELF_MARK] = $self->[SELF_CURSOR_INPUT];
  }
  $self->[SELF_COUNT] = 0;
}

sub rl_digit_argument {
  my ($self, $key) = @_;
  $self->[SELF_COUNT] .= $key;
}

sub rl_beginning_of_line {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT]) {
    _curs_left($self->[SELF_CURSOR_DISPLAY]);
    $self->[SELF_CURSOR_DISPLAY] = $self->[SELF_CURSOR_INPUT] = 0;
  }
}

sub rl_end_of_line {
  my ($self, $key) = @_;
  my $max = length($self->[SELF_INPUT]);
  $max-- if ($self->[SELF_KEYMAP]->{name} =~ /vi/);
  if ($self->[SELF_CURSOR_INPUT] < $max) {
    my $right_string = substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]);
    print _normalize($right_string);
    my $right = _display_width($right_string);
    if ($self->[SELF_KEYMAP]->{name} =~ /vi/) {
      $self->[SELF_CURSOR_DISPLAY] += $right - 1;
      $self->[SELF_CURSOR_INPUT] = length($self->[SELF_INPUT]) - 1;
      _curs_left(1);
    } else {
      $self->[SELF_CURSOR_DISPLAY] += $right;
      $self->[SELF_CURSOR_INPUT] = length($self->[SELF_INPUT]);
    }
  }
}

sub rl_backward_char {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT]) {
    $self->[SELF_CURSOR_INPUT]--;
    my $left = _display_width(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1));
    _curs_left($left);
    $self->[SELF_CURSOR_DISPLAY] -= $left;
  }
  else {
    $self->rl_ding;
  }
}

sub rl_forward_char {
  my ($self, $key) = @_;
  my $max = length($self->[SELF_INPUT]);
  $max-- if ($self->[SELF_KEYMAP]->{name} =~ /vi/);
  if ($self->[SELF_CURSOR_INPUT] < $max) {
    my $normal = _normalize(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1));
    print $stdout $normal;
    $self->[SELF_CURSOR_INPUT]++;
    $self->[SELF_CURSOR_DISPLAY] += length($normal);
  } else {
    $self->rl_ding;
  }
}

sub rl_forward_word {
  my ($self, $key) = @_;
  if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\W*\w+)/) {
    $self->[SELF_CURSOR_INPUT] += length($1);
    my $right = _display_width($1);
    print _normalize($1);
    $self->[SELF_CURSOR_DISPLAY] += $right;
  } else {
    $self->rl_ding;
  }
}

sub rl_backward_word {
  my ($self, $key) = @_;
  if (substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]) =~ /(\w+\W*)$/) {
    $self->[SELF_CURSOR_INPUT] -= length($1);
    my $left = _display_width($1);
    _curs_left($left);
    $self->[SELF_CURSOR_DISPLAY] -= $left;
  } else {
    $self->rl_ding;
  }
}

sub rl_backward_kill_word {
  my ($self) = @_;
  if ($self->[SELF_CURSOR_INPUT]) {
    substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]) =~ /(\w*\W*)$/;
    my $kill = $self->_delete_chars($self->[SELF_CURSOR_INPUT] - length($1), length($1));
    push(@{$self->[SELF_KILL_RING]}, $kill);
  } else {
    $self->rl_ding;
  }
}

sub rl_kill_region {
  my ($self) = @_;
  my $kill = $self->_delete_chars($self->[SELF_CURSOR_INPUT], $self->[SELF_CURSOR_INPUT] - $self->[SELF_MARK]);
  push(@{$self->[SELF_KILL_RING]}, $kill);
}

sub rl_kill_word {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\W*\w*\W*)/;
    my $kill = $self->_delete_chars($self->[SELF_CURSOR_INPUT], length($1));
    push(@{$self->[SELF_KILL_RING]}, $kill);
  } else {
    $self->rl_ding;
  }
}

sub rl_kill_line {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    my $kill = $self->_delete_chars($self->[SELF_CURSOR_INPUT], length($self->[SELF_INPUT]) - $self->[SELF_CURSOR_INPUT]);
    push(@{$self->[SELF_KILL_RING]}, $kill);
  } else {
    $self->rl_ding;
  }
}

sub rl_unix_word_rubout {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT]) {
    substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]) =~ /(\S*\s*)$/;
    my $kill = $self->_delete_chars($self->[SELF_CURSOR_INPUT] - length($1), length($1));
    push(@{$self->[SELF_KILL_RING]}, $kill);
  } else {
    $self->rl_ding;
  }
}

sub rl_delete_horizontal_space {
  my ($self) = @_;
  substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]) =~ /(\s*)$/;
  my $left = length($1);
  substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*)/;
  my $right = length($1);

  if ($left + $right) {
    $self->_delete_chars($self->[SELF_CURSOR_INPUT] - $left, $left + $right);
  } else {
    $self->rl_ding;
  }
}

sub rl_copy_region_as_kill {
  my ($self) = @_;
  my $from = $self->[SELF_CURSOR_INPUT];
  my $howmany = $self->[SELF_CURSOR_INPUT] - $self->[SELF_MARK];
  if ($howmany < 0) {
    $from -= $howmany;
    $howmany = -$howmany;
    if ($from < 0) {
      $howmany -= $from;
      $from = 0;
    }
  }
  my $old = substr($self->[SELF_INPUT], $from, $howmany);
  push(@{$self->[SELF_KILL_RING]}, $old);
}

sub rl_abort {
  my ($self, $key) = @_;
  print $stdout uc($key), "\x0D\x0A";
  $poe_kernel->select_read($stdin);
  if ($self->[SELF_HAS_TIMER]) {
    $poe_kernel->delay( $self->[SELF_STATE_IDLE] );
    $self->[SELF_HAS_TIMER] = 0;
  }
  $poe_kernel->yield(
    $self->[SELF_EVENT_INPUT],
    undef, 'cancel', $self->[SELF_UNIQUE_ID]
  );
  $self->[SELF_READING_LINE] = 0;
  $self->[SELF_HIST_INDEX] = @{$self->[SELF_HIST_LIST]};
  $self->_flush_output_buffer;
}

sub rl_interrupt {
  my ($self, $key) = @_;
  print $stdout uc($key), "\x0D\x0A";
  $poe_kernel->select_read($stdin);
  if ($self->[SELF_HAS_TIMER]) {
    $poe_kernel->delay( $self->[SELF_STATE_IDLE] );
    $self->[SELF_HAS_TIMER] = 0;
  }
  $poe_kernel->yield( $self->[SELF_EVENT_INPUT], undef, 'interrupt', $self->[SELF_UNIQUE_ID] );
  $self->[SELF_READING_LINE] = 0;
  $self->[SELF_HIST_INDEX] = @{$self->[SELF_HIST_LIST]};

  $self->_flush_output_buffer;
}

# Delete a character.  On an empty line, it throws an
# "eot" exception, just like Term::ReadLine does.
sub rl_delete_char {
  my ($self, $key) = @_;
  if (length $self->[SELF_INPUT] == 0) {
    print $stdout uc($key), "\x0D\x0A";
    $poe_kernel->select_read($stdin);
    if ($self->[SELF_HAS_TIMER]) {
      $poe_kernel->delay( $self->[SELF_STATE_IDLE] );
      $self->[SELF_HAS_TIMER] = 0;
    }
    $poe_kernel->yield(
      $self->[SELF_EVENT_INPUT],
      undef, "eot", $self->[SELF_UNIQUE_ID]
    );
    $self->[SELF_READING_LINE] = 0;
    $self->[SELF_HIST_INDEX] = @{$self->[SELF_HIST_LIST]};

    $self->_flush_output_buffer;
    return;
  }

  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    $self->_delete_chars($self->[SELF_CURSOR_INPUT], 1);
  } else {
    $self->rl_ding;
  }
}

sub rl_backward_delete_char {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT]) {
    $self->_delete_chars($self->[SELF_CURSOR_INPUT]-1, 1);
  } else {
    $self->rl_ding;
  }
}

sub rl_accept_line {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    my $right_string = substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]);
    print _normalize($right_string);
    my $right = _display_width($right_string);
    $self->[SELF_CURSOR_DISPLAY] += $right;
    $self->[SELF_CURSOR_INPUT] = length($self->[SELF_INPUT]);
  }
  # home the cursor.
  $self->[SELF_CURSOR_DISPLAY] = 0;
  $self->[SELF_CURSOR_INPUT] = 0;
  print $stdout "\x0D\x0A";
  $poe_kernel->select_read($stdin);
  if ($self->[SELF_HAS_TIMER]) {
    $poe_kernel->delay( $self->[SELF_STATE_IDLE] );
    $self->[SELF_HAS_TIMER] = 0;
  }
  $poe_kernel->yield( $self->[SELF_EVENT_INPUT], $self->[SELF_INPUT], $self->[SELF_UNIQUE_ID] );
  $self->[SELF_READING_LINE] = 0;
  $self->[SELF_HIST_INDEX] = @{$self->[SELF_HIST_LIST]};
  $self->_flush_output_buffer;
  ReadMode('restore');
  eval { ($trk_cols, $trk_rows) = GetTerminalSize($stdout) };
  ($trk_cols, $trk_rows) = (80, 25) if $@;
  if ($self->[SELF_KEYMAP]->{name} =~ /vi/) {
    $self->rl_set_keymap('vi-insert');
  }
}

sub rl_clear_screen {
  my ($self, $key) = @_;
  my $left = _display_width(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]));
  $termcap->Tputs( 'cl', 1, $stdout );
  my $sp = $self->[SELF_PROMPT];
  $sp =~ s{\\[\[\]]}{}g;
  print $stdout $sp, _normalize($self->[SELF_INPUT]);
  _curs_left($left) if $left;
}

sub rl_transpose_chars {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT] > 0 and $self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    my $width_left = _display_width(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT] - 1, 1));

    my $transposition = reverse substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT] - 1, 2);
    substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT] - 1, 2) = $transposition;

    _curs_left($width_left);
    print $stdout _normalize($transposition);
    _curs_left($width_left);
  } else {
    $self->rl_ding;
  }
}

sub rl_transpose_words {
  my ($self, $key) = @_;
  my ($previous, $left, $space, $right, $rest);

  # This bolus of code was written to replace a single
  # regexp after finding out that the regexp's negative
  # zero-width look-behind assertion doesn't work in
  # perl 5.004_05.  For the record, this is that regexp:
  # s/^(.{0,$cursor_sub_one})(?<!\S)(\S+)(\s+)(\S+)/$1$4$3$2/

  if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1) =~ /\s/) {
    my ($left_space, $right_space);
    ($previous, $left, $left_space) = (
      substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]) =~ /^(.*?)(\S+)(\s*)$/
    );
    ($right_space, $right, $rest) = (
      substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s+)(\S+)(.*)$/
    );
    $space = $left_space . $right_space;
  } elsif ( substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]) =~ /^(.*?)(\S+)(\s+)(\S*)$/ ) {
    ($previous, $left, $space, $right) = ($1, $2, $3, $4);
    if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\S*)(.*)$/) {
      $right .= $1 if defined $1;
      $rest = $2;
    }
  } elsif ( substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\S+)(\s+)(\S+)(.*)$/ ) {
    ($left, $space, $right, $rest) = ($1, $2, $3, $4);
    if ( substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]) =~ /^(.*?)(\S+)$/ ) {
      $previous = $1;
      $left = $2 . $left;
    }
  } else {
    $self->rl_ding;
    next;
  }

  $previous = '' unless defined $previous;
  $rest     = '' unless defined $rest;

  $self->[SELF_INPUT] = $previous . $right . $space . $left . $rest;

  if ($self->[SELF_CURSOR_DISPLAY] - _display_width($previous)) {
    _curs_left($self->[SELF_CURSOR_DISPLAY] - _display_width($previous));
  }
  print $stdout _normalize($right . $space . $left);
  $self->[SELF_CURSOR_INPUT] = length($previous. $left . $space . $right);
  $self->[SELF_CURSOR_DISPLAY] = _display_width($previous . $left . $space . $right);
}

sub rl_unix_line_discard {
  my ($self, $key) = @_;
  if (length $self->[SELF_INPUT]) {
    my $kill = $self->_delete_chars(0, $self->[SELF_CURSOR_INPUT]);
    push(@{$self->[SELF_KILL_RING]}, $kill);
  } else {
    $self->rl_ding;
  }
}

sub rl_kill_whole_line {
  my ($self, $key) = @_;
  if (length $self->[SELF_INPUT]) {
    # Back up to the beginning of the line.
    if ($self->[SELF_CURSOR_INPUT]) {
      _curs_left($self->[SELF_CURSOR_DISPLAY]);
      $self->[SELF_CURSOR_DISPLAY] = $self->[SELF_CURSOR_INPUT] = 0;
    }
    $self->_clear_to_end;

    # Clear the input buffer.
    push(@{$self->[SELF_KILL_RING]}, $self->[SELF_INPUT]);
    $self->[SELF_INPUT] = '';
  } else {
    $self->rl_ding;
  }
}

sub rl_yank {
  my ($self) = @_;
  my $pos = scalar @{$self->[SELF_KILL_RING]};
  return $self->rl_ding unless ($pos);

  $pos--;
  $self->rl_self_insert($self->[SELF_KILL_RING]->[$pos], $self->[SELF_KILL_RING]->[$pos]);
}

sub rl_yank_pop {
  my ($self) = @_;
  return $self->rl_ding unless ($self->[SELF_LAST] =~ /yank/);
  my $pos = scalar @{$self->[SELF_KILL_RING]};
  return $self->rl_ding unless ($pos);

  my $top = pop @{$self->[SELF_KILL_RING]};
  unshift(@{$self->[SELF_KILL_RING]}, $top);
  $self->rl_yank;
}

sub rl_previous_history {
  my ($self, $key) = @_;
  if ($self->[SELF_HIST_INDEX]) {
    # Moving away from a new input line; save it in case
    # we return.
    if ($self->[SELF_HIST_INDEX] == @{$self->[SELF_HIST_LIST]}) {
        $self->[SELF_INPUT_HOLD] = $self->[SELF_INPUT];
    }

    # Move cursor to start of input.
    if ($self->[SELF_CURSOR_INPUT]) {
        _curs_left($self->[SELF_CURSOR_DISPLAY]);
    }
    $self->_clear_to_end;

    # Move the history cursor back, set the new input
    # buffer, and show what the user's editing.  Set the
    # cursor to the end of the new line.
    my $normal;
    print $stdout $normal = _normalize($self->[SELF_INPUT] = $self->[SELF_HIST_LIST]->[--$self->[SELF_HIST_INDEX]]);
    $self->[SELF_UNDO] = [ [ $self->[SELF_INPUT], 0, 0 ] ]; # reset undo info
    $self->[SELF_CURSOR_INPUT] = length($self->[SELF_INPUT]);
    $self->[SELF_CURSOR_DISPLAY] = length($normal);
    $self->rl_backward_char if (length($self->[SELF_INPUT]) && $self->[SELF_KEYMAP]->{name} =~ /vi/);
  } else {
    # At top of history list.
    $self->rl_ding;
  }
}

sub rl_next_history {
  my ($self, $key) = @_;
  if ($self->[SELF_HIST_INDEX] < @{$self->[SELF_HIST_LIST]}) {
    # Move cursor to start of input.
    if ($self->[SELF_CURSOR_INPUT]) {
      _curs_left($self->[SELF_CURSOR_DISPLAY]);
    }
    $self->_clear_to_end;

    my $normal;
    if (++$self->[SELF_HIST_INDEX] == @{$self->[SELF_HIST_LIST]}) {
      # Just past the end of the history.  Whatever was
      # there when we left it.
      print $stdout $normal = _normalize($self->[SELF_INPUT] = $self->[SELF_INPUT_HOLD]);
    } else {
      # There's something in the history list.  Make that
      # the current line.
      print $stdout $normal = _normalize($self->[SELF_INPUT] = $self->[SELF_HIST_LIST]->[$self->[SELF_HIST_INDEX]]);
    }

    $self->[SELF_UNDO] = [ [ $self->[SELF_INPUT], 0, 0 ] ]; # reset undo info
    $self->[SELF_CURSOR_INPUT] = length($self->[SELF_INPUT]);
    $self->[SELF_CURSOR_DISPLAY] = length($normal);
    $self->rl_backward_char if (length($self->[SELF_INPUT]) && $self->[SELF_KEYMAP]->{name} =~ /vi/);
  } else {
    $self->rl_ding;
  }
}

sub rl_beginning_of_history {
  my ($self) = @_;
  # First in history.
  if ($self->[SELF_HIST_INDEX]) {
    # Moving away from a new input line; save it in case
    # we return.
    if ($self->[SELF_HIST_INDEX] == @{$self->[SELF_HIST_LIST]}) {
      $self->[SELF_INPUT_HOLD] = $self->[SELF_INPUT];
    }

    # Move cursor to start of input.
    if ($self->[SELF_CURSOR_INPUT]) {
      _curs_left($self->[SELF_CURSOR_DISPLAY]);
    }
    $self->_clear_to_end;

    # Move the history cursor back, set the new input
    # buffer, and show what the user's editing.  Set the
    # cursor to the end of the new line.
    print $stdout my $normal =
      _normalize($self->[SELF_INPUT] = $self->[SELF_HIST_LIST]->[$self->[SELF_HIST_INDEX] = 0]);
    $self->[SELF_CURSOR_INPUT] = length($self->[SELF_INPUT]);
    $self->[SELF_CURSOR_DISPLAY] = length($normal);
    $self->[SELF_UNDO] = [ [ $self->[SELF_INPUT], 0, 0 ] ]; # reset undo info
  } else {
    # At top of history list.
    $self->rl_ding;
  }
}

sub rl_end_of_history {
  my ($self) = @_;
  if ($self->[SELF_HIST_INDEX] != @{$self->[SELF_HIST_LIST]} - 1) {

    # Moving away from a new input line; save it in case
    # we return.
    if ($self->[SELF_HIST_INDEX] == @{$self->[SELF_HIST_LIST]}) {
      $self->[SELF_INPUT_HOLD] = $self->[SELF_INPUT];
    }

    # Move cursor to start of input.
    if ($self->[SELF_CURSOR_INPUT]) {
      _curs_left($self->[SELF_CURSOR_DISPLAY]);
    }
    $self->_clear_to_end;

    # Move the edit line down to the last history line.
    $self->[SELF_HIST_INDEX] = @{$self->[SELF_HIST_LIST]} - 1;
    print $stdout my $normal = _normalize($self->[SELF_INPUT] = $self->[SELF_HIST_LIST]->[$self->[SELF_HIST_INDEX]]);
    $self->[SELF_CURSOR_INPUT] = length($self->[SELF_INPUT]);
    $self->[SELF_CURSOR_DISPLAY] = length($normal);
    $self->[SELF_UNDO] = [ [ $self->[SELF_INPUT], 0, 0 ] ]; # reset undo info
  } else {
    $self->rl_ding;
  }
}

sub rl_forward_search_history {
  my ($self, $key) = @_;
  $self->_wipe_input_line;
  $self->[SELF_PREV_PROMPT] = $self->[SELF_PROMPT];
  $self->[SELF_SEARCH_PROMPT] = '(forward-i-search)`%s\': ';
  $self->[SELF_SEARCH_MAP] = $self->[SELF_KEYMAP];
  $self->[SELF_SEARCH_DIR] = +1;
  $self->[SELF_SEARCH_KEY] = $key;
  $self->_build_search_prompt;
  $self->_repaint_input_line;
  $self->rl_set_keymap('isearch');
}

sub rl_reverse_search_history {
  my ($self, $key) = @_;
  $self->_wipe_input_line;
  $self->[SELF_PREV_PROMPT] = $self->[SELF_PROMPT];
  $self->[SELF_SEARCH_PROMPT] = '(reverse-i-search)`%s\': ';
  $self->[SELF_SEARCH_MAP] = $self->[SELF_KEYMAP];
  $self->[SELF_SEARCH_DIR] = -1;
  $self->[SELF_SEARCH_KEY] = $key;
  # start at the previous line...
  $self->[SELF_HIST_INDEX]-- if $self->[SELF_HIST_INDEX];
  $self->_build_search_prompt;
  $self->_repaint_input_line;
  $self->rl_set_keymap('isearch');
}

sub rl_capitalize_word {
  my ($self, $key) = @_;
  # Capitalize from cursor on.
  if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*)(\S+)/) {
    # Track leading space, and uppercase word.
    my $space = $1; $space = '' unless defined $space;
    my $word  = ucfirst(lc($2));

    # Replace text with the uppercase version.
    substr(
      $self->[SELF_INPUT],
      $self->[SELF_CURSOR_INPUT] + length($space),
      length($word)
    ) = $word;

    # Display the new text; move the cursor after it.
    print $stdout $space, _normalize($word);
    $self->[SELF_CURSOR_INPUT] += length($space . $word);
    $self->[SELF_CURSOR_DISPLAY] += length($space) + _display_width($word);
  } else {
    $self->rl_ding;
  }
}

sub rl_upcase_word {
  my ($self, $key) = @_;
  # Uppercase from cursor on.
  # Modeled after capitalize.
  if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*)(\S+)/) {
    my $space = $1; $space = '' unless defined $space;
    my $word  = uc($2);
    substr(
      $self->[SELF_INPUT],
      $self->[SELF_CURSOR_INPUT] + length($space),
      length($word)
    ) = $word;
    print $stdout $space, _normalize($word);
    $self->[SELF_CURSOR_INPUT] += length($space . $word);
    $self->[SELF_CURSOR_DISPLAY] += length($space) + _display_width($word);
  } else {
    $self->rl_ding;
  }
}


sub rl_downcase_word {
  my ($self, $key) = @_;
  # Lowercase from cursor on.
  # Modeled after capitalize.
  if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*)(\S+)/) {
    my $space = $1; $space = '' unless defined $space;
    my $word  = lc($2);
    substr(
      $self->[SELF_INPUT],
      $self->[SELF_CURSOR_INPUT] + length($space),
      length($word)
    ) = $word;
    print $stdout $space, _normalize($word);
    $self->[SELF_CURSOR_INPUT] += length($space . $word);
    $self->[SELF_CURSOR_DISPLAY] += length($space) + _display_width($word);
  } else {
    $self->rl_ding;
  }
}

sub rl_quoted_insert {
  my ($self, $key) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s,$k,$rk) = @_;
    $s->rl_self_insert($k, $rk);
  };
}

sub rl_overwrite_mode {
  my ($self, $key) = @_;
  $self->[SELF_INSERT_MODE] = !$self->[SELF_INSERT_MODE];
  if ($self->[SELF_COUNT]) {
    if ($self->[SELF_COUNT] > 0) {
      $self->[SELF_INSERT_MODE] = 0;
    } else {
      $self->[SELF_INSERT_MODE] = 1;
    }
  }
}

sub rl_vi_replace {
  my ($self) = @_;
  $self->rl_vi_insertion_mode;
  $self->rl_overwrite_mode;
}

sub rl_tilde_expand {
  my ($self) = @_;
  my $pre = substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]);
  my ($append) = (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\w+)/);
  my ($left,$user) = ("$pre$append" =~  /^(.*)~(\S+)$/);
  if ($user) {
    my $dir = (getpwnam($user))[7];
    if (!$dir) {
      print "\x0D\x0Ausername '$user' not found\x0D\x0A";
      $self->_repaint_input_line;
      return $self->rl_ding;
    }
    $self->_wipe_input_line;
    substr($self->[SELF_INPUT], length($left), length($user) + 1) = $dir; # +1 for tilde
    $self->[SELF_CURSOR_INPUT] += length($dir) - length($user) - 1;
    $self->[SELF_CURSOR_DISPLAY] += length($dir) - length($user) - 1;
    $self->_repaint_input_line;
    return 1;
  } else {
    return $self->rl_ding;
  }
}

sub _complete_match {
  my ($self) = @_;
  my $lookfor = substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]);
  $lookfor =~ /(\S+)$/;
  $lookfor = defined($1) ? $1 : "";
  my $point = $self->[SELF_CURSOR_INPUT] - length($lookfor);

  my @clist = ();
  if ($self->option("completion_function")) {
    my $fn = $self->[SELF_OPTIONS]->{completion_function};
    @clist = &$fn($lookfor, $self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]);
  }
  my @poss = @clist;
  if ($lookfor) {
    my $l = length $lookfor;
    @poss = grep { substr($_, 0, $l) eq $lookfor } @clist;
  }

  return @poss;
}

sub _complete_list {
  my ($self, @poss) = @_;
  my $width = 0;
  if ($self->option('print-completions-horizontally') eq 'on') {
    map { $width = (length($_) > $width) ? length($_) : $width } @poss;
    my $cols = int($trk_cols / $width);
    $cols = int($trk_cols / ($width+$cols)); # ensure enough room for spaces
    $width = int($trk_cols / $cols);

    print $stdout "\x0D\x0A";
    my $c = 0;
    foreach my $word (@poss) {
      print $stdout $word . (" " x ($width - length($word)));
      if (++$c == $cols) {
        print $stdout "\x0D\x0A";
        $c = 0;
      }
    }
    print "\x0D\x0A" if $c;
  } else {
    print "\x0D\x0A";
    foreach my $word (@poss) {
      print $stdout $word . "\x0D\x0A";
    }
  }
  $self->_repaint_input_line;
}

sub rl_possible_completions {
  my ($self, $key) = @_;

  my @poss = $self->_complete_match;
  if (scalar @poss == 0) {
    return $self->rl_ding;
  }
  $self->_complete_list(@poss);
}

sub rl_complete {
  my ($self, $key) = @_;

  my $lookfor = substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]);
  $lookfor =~ /(\S+)$/;
  $lookfor = defined($1) ? $1 : "";
  my $point = $self->[SELF_CURSOR_INPUT] - length($lookfor);
  my @poss = $self->_complete_match;
  if (scalar @poss == 0) {
    return $self->rl_ding;
  }

  if (scalar @poss == 1) {
    substr($self->[SELF_INPUT], $point, $self->[SELF_CURSOR_INPUT]) = $poss[0];
    my $rest = substr($self->[SELF_INPUT], $point+length($lookfor));
    print $stdout $rest;
    _curs_left(length($rest)-length($poss[0]));
    $self->[SELF_CURSOR_INPUT] += length($poss[0])-length($lookfor);
    $self->[SELF_CURSOR_DISPLAY] += length($poss[0])-length($lookfor);
    return 1;
  }

  # so at this point, we have multiple possibilities
  # find out how much more is in common with the possibilities.
  my $max = length($lookfor);
  while (1) {
    my $letter = undef;
    my $ok = 1;
    foreach my $p (@poss) {
      if ((length $p) < $max) {
        $ok = 0;
        last;
      }
      if (!$letter) {
        $letter = substr($p, $max, 1);
        next;
      }
      if (substr($p, $max, 1) ne $letter) {
        $ok = 0;
        last;
      }
    }
    if ($ok) {
      $max++;
    } else {
      last;
    }
  }
  if ($max > length($lookfor)) {
    my $partial = substr($poss[0], 0, $max);
    substr($self->[SELF_INPUT], $point, $self->[SELF_CURSOR_INPUT]) = $partial;
    my $rest = substr($self->[SELF_INPUT], $point+length($lookfor));
    print $stdout $rest;
    _curs_left(length($rest)-length($partial));
    $self->[SELF_CURSOR_INPUT]   += length($partial)-length($lookfor);
    $self->[SELF_CURSOR_DISPLAY] += length($partial)-length($lookfor);
    return $self->rl_ding if @poss == 1;
  }

  if ($self->[SELF_LAST] !~ /complete/ && !$self->option('show-all-if-ambiguous')) {
    return $self->rl_ding;
  }
  $self->_complete_list(@poss);
  return 0;
}

sub rl_insert_completions {
  my ($self) = @_;
  my @poss = $self->_complete_match;
  if (scalar @poss == 0) {
    return $self->rl_ding;
  }
  # need to back up the current text
  my $lookfor = substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]);
  $lookfor =~ /(\S+)$/;
  $lookfor = $1;
  my $point = length($lookfor);
  while ($point--) {
    $self->rl_backward_delete_char;
  }
  my $text = join(" ", @poss);
  $self->rl_self_insert($text, $text);
}

sub rl_ding {
  my ($self) = @_;
  if (!$self->option('bell-style') || $self->option('bell-style') eq 'audible') {
    print $stdout $tc_bell;
  } elsif ($self->option('bell-style') eq 'visible') {
    print $stdout $tc_visual_bell;
  }
  return 0;
}

sub rl_redraw_current_line {
  my ($self) = @_;
  $self->_wipe_input_line;
  $self->_repaint_input_line;
}

sub rl_poe_wheel_debug {
  my ($self, $key) = @_;
  my $left = _display_width(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]));
  my $sp = $self->[SELF_PROMPT];
  $sp =~ s{\\[\[\]]}{}g;
  print( $stdout
   "\x0D\x0A",
   "ID=$self->[SELF_UNIQUE_ID] ",
   "cursor_input($self->[SELF_CURSOR_INPUT]) ",
   "cursor_display($self->[SELF_CURSOR_DISPLAY]) ",
   "term_columns($trk_cols)\x0D\x0A",
   $sp, _normalize($self->[SELF_INPUT])
  );
  _curs_left($left) if $left;
}

sub rl_vi_movement_mode {
  my ($self) = @_;
  $self->rl_set_keymap('vi');
  $self->rl_backward_char if ($self->[SELF_INPUT]);
}

sub rl_vi_append_mode {
  my ($self) = @_;
  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    # we can't just call forward-char, coz we don't want bell to ring.
    my $normal = _normalize(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1));
    print $stdout $normal;
    $self->[SELF_CURSOR_INPUT]++;
    $self->[SELF_CURSOR_DISPLAY] += length($normal);
  }
  $self->rl_set_keymap('vi-insert');
}

sub rl_vi_append_eol {
  my ($self) = @_;
  $self->rl_end_of_line;
  $self->rl_vi_append_mode;
}

sub rl_vi_insertion_mode {
  my ($self) = @_;
  $self->rl_set_keymap('vi-insert');
}

sub rl_vi_insert_beg {
  my ($self) = @_;
  $self->rl_beginning_of_line;
  $self->rl_vi_insertion_mode;
}

sub rl_vi_editing_mode {
  my ($self) = @_;
  $self->rl_set_keymap('vi');
}

sub rl_emacs_editing_mode {
  my ($self) = @_;
  $self->rl_set_keymap('emacs');
}

sub rl_vi_eof_maybe {
  my ($self, $key) = @_;
  if (length $self->[SELF_INPUT] == 0) {
    print $stdout uc($key), "\x0D\x0A";
    $poe_kernel->select_read($stdin);
    if ($self->[SELF_HAS_TIMER]) {
      $poe_kernel->delay( $self->[SELF_STATE_IDLE] );
      $self->[SELF_HAS_TIMER] = 0;
    }
    $poe_kernel->yield(
      $self->[SELF_EVENT_INPUT],
      undef, "eot", $self->[SELF_UNIQUE_ID]
    );
    $self->[SELF_READING_LINE] = 0;
    $self->[SELF_HIST_INDEX] = @{$self->[SELF_HIST_LIST]};

    $self->_flush_output_buffer;
    return 0;
  } else {
    return $self->rl_ding;
  }
}

sub rl_vi_change_case {
  my ($self) = @_;
  my $char = substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1);
  if ($char lt 'a') {
    substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1) = lc($char);
  } else {
    substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1) = uc($char);
  }
  $self->rl_forward_char;
}

sub rl_vi_prev_word {
  &rl_backward_word;
}

sub rl_vi_next_word {
  my ($self, $key) = @_;
  if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*\S+\s)/) {
    $self->[SELF_CURSOR_INPUT] += length($1);
    my $right = _display_width($1);
    print _normalize($1);
    $self->[SELF_CURSOR_DISPLAY] += $right;
  } else {
    return $self->rl_ding;
  }
}

sub rl_vi_end_word {
  my ($self, $key) = @_;
  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    $self->rl_forward_char;
    if (substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*\S+)/) {
      $self->[SELF_CURSOR_INPUT] += length($1)-1;
      my $right = _display_width($1);
      print _normalize($1);
      $self->[SELF_CURSOR_DISPLAY] += $right-1;
      _curs_left(1);
    }
  } else {
    return $self->rl_ding;
  }
}

sub rl_vi_column {
  my ($self) = @_;
  $self->[SELF_COUNT] ||= 0;
  $self->rl_beginning_of_line;
  while ($self->[SELF_COUNT]--) {
    $self->rl_forward_char;
  }
  $self->[SELF_COUNT] = 0;
}

sub rl_vi_match {
  my ($self) = @_;
  return $self->rl_ding unless $self->[SELF_INPUT];
  # what paren are we after? look forwards down the line for the closest
  my $pos = $self->[SELF_CURSOR_INPUT];
  my $where = substr($self->[SELF_INPUT], $pos);
  my ($adrift) = ($where =~ m/([^\(\)\{\}\[\]]*)/);
  my $paren = substr($where, length($adrift), 1);
  $pos += length($adrift);

  return $self->rl_ding unless $paren;
  my $what_to_do = {
    '(' => [ ')', 1 ],
    '{' => [ '}', 1 ],
    '[' => [ ']', 1 ],
    ')' => [ '(', -1 ],
    '}' => [ '{', -1 ],
    ']' => [ '[', -1 ],
  }->{$paren};
  my($opp,$dir) = @{$what_to_do};
  my $level = 1;
  while ($level) {
    if ($dir > 0) {
      return $self->rl_ding if ($pos == length($self->[SELF_INPUT]));
      $pos++;
    } else {
      return $self->rl_ding unless $pos;
      $pos--;
    }
    my $c = substr($self->[SELF_INPUT], $pos, 1);
    if ($c eq $opp) {
      $level--;
    } elsif ($c eq $paren) {
      $level++
    }
  }
  $self->[SELF_COUNT] = $pos;
  $self->rl_vi_column;
  return 1;
}

sub rl_vi_first_print {
  my ($self) = @_;
  $self->rl_beginning_of_line;
  substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*)/;
  if (length($1)) {
    $self->[SELF_CURSOR_INPUT] += length($1);
    my $right = _display_width($1);
    print _normalize($1);
    $self->[SELF_CURSOR_DISPLAY] += $right;
  }
}

sub rl_vi_delete {
  my ($self) = @_;
  if ($self->[SELF_CURSOR_INPUT] < length($self->[SELF_INPUT])) {
    $self->_delete_chars($self->[SELF_CURSOR_INPUT], 1);
    if ($self->[SELF_INPUT] && $self->[SELF_CURSOR_INPUT] >= length($self->[SELF_INPUT])) {
      $self->[SELF_CURSOR_INPUT]--;
      $self->[SELF_CURSOR_DISPLAY]--;
      _curs_left(1);
    }
  } else {
    return $self->rl_ding;
  }
}

sub rl_vi_put {
  my ($self, $key) = @_;
  my $pos = scalar @{$self->[SELF_KILL_RING]};
  return $self->rl_ding unless ($pos);
  $pos--;
  if ($self->[SELF_INPUT] && $key eq 'p') {
    my $normal = _normalize(substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], 1));
    print $stdout $normal;
    $self->[SELF_CURSOR_INPUT]++;
    $self->[SELF_CURSOR_DISPLAY] += length($normal);
  }
  $self->rl_self_insert($self->[SELF_KILL_RING]->[$pos], $self->[SELF_KILL_RING]->[$pos]);
  if ($self->[SELF_CURSOR_INPUT] >= length($self->[SELF_INPUT])) {
    $self->[SELF_CURSOR_INPUT]--;
    $self->[SELF_CURSOR_DISPLAY]--;
    _curs_left(1);
  }
}

sub rl_vi_yank_arg {
  my ($self) = @_;
  $self->rl_vi_append_mode;
  if ($self->rl_yank_last_arg) {
    $self->rl_set_keymap('vi-insert');
  } else {
    $self->rl_set_keymap('vi-command');
  }
}

sub rl_vi_end_spec {
  my ($self) = @_;
  $self->[SELF_PENDING] = undef;
  $self->rl_ding;
  $self->rl_set_keymap('vi');
}

sub rl_vi_spec_end_of_line {
  my ($self) = @_;
  $self->rl_set_keymap('vi');
  $self->_vi_apply_spec($self->[SELF_CURSOR_INPUT], length($self->[SELF_INPUT]) - $self->[SELF_CURSOR_INPUT]);
}

sub rl_vi_spec_beginning_of_line {
  my ($self) = @_;
  $self->rl_set_keymap('vi');
  $self->_vi_apply_spec(0, $self->[SELF_CURSOR_INPUT]);
}

sub rl_vi_spec_first_print {
  my ($self) = @_;
  substr($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT]) =~ /^(\s*)/;
  my $len = length($1) || 0;
  my $from = $self->[SELF_CURSOR_INPUT];
  if ($from > $len) {
    my $tmp = $from;
    $from = $len;
    $len = $tmp - $from;
  }
  $self->_vi_apply_spec($from, $len);
}


sub rl_vi_spec_word {
  my ($self) = @_;

  my $from = $self->[SELF_CURSOR_INPUT];
  my $len  = length($self->[SELF_INPUT]) - $from + 1;
  if (substr($self->[SELF_INPUT], $from) =~ /^(\s*\S+\s)/) {
    my $word = $1;
    $len = length($word);
  }
  $self->rl_set_keymap('vi');
  $self->_vi_apply_spec($from, $len);
}

sub rl_character_search {
  my ($self) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s, $key) = @_;
    return $s->rl_ding unless substr($s->[SELF_INPUT], $s->[SELF_CURSOR_INPUT]) =~ /(.*)$key/;
    $s->[SELF_COUNT] = $s->[SELF_INPUT] + length($1);
    $s->vi_column;
  };
}

sub rl_character_search_backward {
  my ($self) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s, $key) = @_;
    return $s->rl_ding unless substr($s->[SELF_INPUT], 0, $s->[SELF_CURSOR_INPUT]) =~ /$key([^$key])*$/;
    $s->[SELF_COUNT] = $s->[SELF_INPUT] - length($1);
    $s->vi_column;
  };
}

sub rl_vi_spec_forward_char {
  my ($self) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s, $key) = @_;
    return $s->rl_ding unless substr($s->[SELF_INPUT], $s->[SELF_CURSOR_INPUT]) =~ /(.*)$key/;
    $s->_vi_apply_spec($s->[SELF_CURSOR_INPUT], length($1));
  };
}

sub rl_vi_spec_mark {
  my ($self) = @_;

  $self->[SELF_PENDING_FN] = sub {
    my ($s, $key) = @_;
    return $s->rl_ding unless exists $s->[SELF_MARKLIST]->{$key};
    my $pos = $s->[SELF_CURSOR_INPUT];
    my $len = $s->[SELF_MARKLIST]->{$key} - $s->[SELF_CURSOR_INPUT];
    if ($len < 0) {
      $pos += $len;
      $len = -$len;
    }
    $s->_vi_apply_spec($pos, $len);
  };
}

sub _vi_apply_spec {
  my ($self, $from, $howmany) = @_;
  $self->[SELF_PENDING]->($self, $from, $howmany);
  $self->[SELF_PENDING] = undef if ($self->[SELF_COUNT] <= 1);
}

sub rl_vi_yank_to {
  my ($self, $key) = @_;
  $self->[SELF_PENDING] = sub {
    my ($s, $from, $howmany) = @_;
    push(@{$s->[SELF_KILL_RING]}, substr($s->[SELF_INPUT], $from, $howmany));
  };
  if ($key eq 'Y') {
    $self->rl_vi_spec_end_of_line;
  } else {
    $self->rl_set_keymap('vi-specification');
  }
}

sub rl_vi_delete_to {
  my ($self, $key) = @_;
  $self->[SELF_PENDING] = sub {
    my ($s, $from, $howmany) = @_;
    $s->_delete_chars($from, $howmany);
    if ($s->[SELF_INPUT] && $s->[SELF_CURSOR_INPUT] >= length($s->[SELF_INPUT])) {
      $s->[SELF_CURSOR_INPUT]--;
      $s->[SELF_CURSOR_DISPLAY]--;
      _curs_left(1);
    }
    $s->rl_set_keymap('vi');
  };
  if ($key eq 'D') {
    $self->rl_vi_spec_end_of_line;
  } else {
    $self->rl_set_keymap('vi-specification');
  }
}

sub rl_vi_change_to {
  my ($self, $key) = @_;
  $self->[SELF_PENDING] = sub {
    my ($s, $from, $howmany) = @_;
    $s->_delete_chars($from, $howmany);
    $s->rl_set_keymap('vi-insert');
  };
  if ($key eq 'C') {
    $self->rl_vi_spec_end_of_line;
  } else {
    $self->rl_set_keymap('vi-specification');
  }
}

sub rl_vi_arg_digit {
  my ($self, $key) = @_;
  if ($key == '0' && !$self->[SELF_COUNT]) {
    $self->rl_beginning_of_line;
  } else {
    $self->[SELF_COUNT] .= $key;
  }
}

sub rl_vi_tilde_expand {
  my ($self) = @_;
  if ($self->rl_tilde_expand) {
    $self->rl_vi_append_mode;
  }
}

sub rl_vi_complete {
  my ($self) = @_;
  if ($self->rl_complete) {
    $self->rl_set_keymap('vi-insert');
  }
}

sub rl_vi_goto_mark {
  my ($self) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s, $key) = @_;
    return $s->rl_ding unless exists $s->[SELF_MARKLIST]->{$key};
    $s->[SELF_COUNT] = $s->[SELF_MARKLIST]->{$key};
    $s->rl_vi_column;
  };
}

sub rl_vi_set_mark  {
  my ($self) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s, $key) = @_;
    return $s->rl_ding unless ($key >= 'a' && $key <= 'z');
    $s->[SELF_MARKLIST]->{$key} = $s->[SELF_CURSOR_INPUT];
  };
}

sub rl_search_abort {
  my ($self) = @_;
  $self->_wipe_input_line;
  $self->[SELF_PROMPT] = $self->[SELF_PREV_PROMPT];
  $self->_repaint_input_line;
  $self->[SELF_KEYMAP] = $self->[SELF_SEARCH_MAP];
  $self->[SELF_SEARCH_MAP] = undef;
  $self->[SELF_SEARCH] = undef;
}

sub rl_search_finish {
  my ($self, $key, $raw) = @_;
  $self->_wipe_input_line;
  $self->[SELF_PROMPT] = $self->[SELF_PREV_PROMPT];
  $self->_repaint_input_line;
  $self->[SELF_KEYMAP] = $self->[SELF_SEARCH_MAP];
  $self->[SELF_SEARCH_MAP] = undef;
  $self->[SELF_SEARCH] = undef;
  $self->_apply_key($key, $raw);
}

sub rl_search_key {
  my ($self, $key) = @_;
  $self->[SELF_SEARCH] .= $key;
  $self->_search(1);
}

sub rl_vi_search_key {
  my ($self, $key) = @_;
  $self->rl_self_insert($key, $key);
}

sub rl_vi_search {
  my ($self, $key) = @_;
  $self->_wipe_input_line;
  $self->[SELF_SEARCH_MAP] = $self->[SELF_KEYMAP];
  if ($key eq '/' && $self->[SELF_HIST_INDEX] < scalar @{$self->[SELF_HIST_LIST]}) {
    $self->[SELF_SEARCH_DIR] = -1;
  } else {
    $self->[SELF_SEARCH_DIR] = +1;
  }
  $self->[SELF_SEARCH_KEY] = $key;
  $self->[SELF_INPUT] = $key;
  $self->[SELF_CURSOR_INPUT] = 1;
  $self->[SELF_CURSOR_DISPLAY] = 1;
  $self->_repaint_input_line;
  $self->rl_set_keymap('vi-search');
}

sub rl_vi_search_accept {
  my ($self) = @_;
  $self->_wipe_input_line;
  $self->[SELF_CURSOR_INPUT] = 0;
  $self->[SELF_CURSOR_DISPLAY] = 0;
  $self->[SELF_INPUT] =~ s{^[/?]}{};
  $self->[SELF_SEARCH] = $self->[SELF_INPUT] if $self->[SELF_INPUT];
  $self->_search(0);
  $self->[SELF_KEYMAP] = $self->[SELF_SEARCH_MAP];
  $self->[SELF_SEARCH_MAP] = undef;
}

sub rl_vi_search_again {
  my ($self, $key) = @_;
  return $self->rl_ding unless $self->[SELF_SEARCH];
  $self->[SELF_HIST_INDEX] += $self->[SELF_SEARCH_DIR];
  if ($self->[SELF_HIST_INDEX] < 0) {
    $self->[SELF_HIST_INDEX] = 0;
    return $self->rl_ding;
  } elsif ($self->[SELF_HIST_INDEX] >= scalar @{$self->[SELF_HIST_LIST]}) {
    $self->[SELF_HIST_INDEX] = (scalar @{$self->[SELF_HIST_LIST]}) - 1;
    return $self->rl_ding;
  }
  $self->_wipe_input_line;
  $self->_search(0);
}

sub rl_isearch_again {
  my ($self, $key) = @_;
  if ($key ne $self->[SELF_SEARCH_KEY]) {
    $self->[SELF_SEARCH_KEY] = $key;
    $self->[SELF_SEARCH_DIR] = -$self->[SELF_SEARCH_DIR];
  }
  $self->[SELF_HIST_INDEX] += $self->[SELF_SEARCH_DIR];
  if ($self->[SELF_HIST_INDEX] < 0) {
    $self->[SELF_HIST_INDEX] = 0;
    return $self->rl_ding;
  } elsif ($self->[SELF_HIST_INDEX] >= scalar @{$self->[SELF_HIST_LIST]}) {
    $self->[SELF_HIST_INDEX] = (scalar @{$self->[SELF_HIST_LIST]}) - 1;
    return $self->rl_ding;
  }
  $self->_search(1);
}

sub rl_non_incremental_forward_search_history {
  my ($self) = @_;
  $self->_wipe_input_line;
  $self->[SELF_CURSOR_INPUT] = 0;
  $self->[SELF_CURSOR_DISPLAY] = 0;
  $self->[SELF_SEARCH_DIR] = +1;
  $self->[SELF_SEARCH] = substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]);
  $self->_search(0);
}

sub rl_non_incremental_reverse_search_history {
  my ($self) = @_;
  $self->[SELF_HIST_INDEX] --;
  if ($self->[SELF_HIST_INDEX] < 0) {
    $self->[SELF_HIST_INDEX] = 0;
    return $self->rl_ding;
  }
  $self->_wipe_input_line;
  $self->[SELF_CURSOR_INPUT] = 0;
  $self->[SELF_CURSOR_DISPLAY] = 0;
  $self->[SELF_SEARCH_DIR] = -1;
  $self->[SELF_SEARCH] = substr($self->[SELF_INPUT], 0, $self->[SELF_CURSOR_INPUT]);
  $self->_search(0);
}

sub rl_undo {
  my ($self) = @_;
  $self->rl_ding unless scalar @{$self->[SELF_UNDO]};
  my $tuple = pop @{$self->[SELF_UNDO]};
  ($self->[SELF_INPUT], $self->[SELF_CURSOR_INPUT], $self->[SELF_CURSOR_DISPLAY]) = @$tuple;
}

sub rl_vi_redo {
  my ($self, $key) = @_;
  return $self->rl_ding unless $self->[SELF_LAST];
  my $fn = $self->[SELF_LAST];
  $self->$fn();
}

sub rl_vi_char_search {
  my ($self, $key) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s,$k,$rk) = @_;
    $rk = "\\" . $rk if ($rk !~ /\w/);
    return $s->rl_ding unless substr($s->[SELF_INPUT], $s->[SELF_CURSOR_INPUT]) =~ /([^$rk]*)$rk/;
    $s->[SELF_COUNT] = $s->[SELF_CURSOR_INPUT] + length($1);
    $s->rl_vi_column;
  };
}

sub rl_vi_change_char {
  my ($self, $key) = @_;
  $self->[SELF_PENDING_FN] = sub {
    my ($s,$k,$rk) = @_;
    $s->rl_delete_char;
    $s->rl_self_insert($k,$rk);
    $s->rl_backward_char;
  };
}

sub rl_vi_subst {
  my ($self, $key) = @_;
  if ($key eq 's') {
    $self->rl_vi_delete;
  } else {
    $self->rl_beginning_of_line;
    $self->rl_kill_line;
  }
  $self->rl_vi_insertion_mode;
}

# ============================================================
# THE KEYMAP CLASS ITSELF
# ============================================================

package POE::Wheel::ReadLine::Keymap;

my %english_to_termcap = (
  'up'        => 'ku',
  'down'      => 'kd',
  'left'      => 'kl',
  'right'     => 'kr',
  'insert'    => 'kI',
  'ins'       => 'kI',
  'delete'    => 'kD',
  'del'       => 'kD',
  'home'      => 'kh',
  'end'       => 'kH',
  'backspace' => 'kb',
  'bs'        => 'kb',
);

my %english_to_key = (
  'space'     => " ",
  'esc'       => "\e",
  'escape'    => "\e",
  'tab'       => "\cI",
  'ret'       => "\cJ",
  'return'    => "\cJ",
  'newline'   => "\cM",
  'lfd'       => "\cL",
  'rubout'    => chr(127),
);

sub init {
  my ($proto, %opts) = @_;
  my $class = ref($proto) || $proto;

  my $default = delete $opts{default} or die("no default specified for keymap");
  my $name    = delete $opts{name} or die("no name specified for keymap");
  my $termcap = delete $opts{termcap} or die("no termcap specified for keymap");

  my $self = {
    name    => $name,
    default => $default,
    binding => {},
    prefix  => {},
    termcap => $termcap,
  };

  return bless $self, $class;
}

sub decode  {
  my ($self, $seq) = @_;
  if (exists $english_to_termcap{lc($seq)}) {
    my $key = $self->{termcap}->Tputs($english_to_termcap{lc($seq)}, 1);
    $seq = defined($key) ? $key : "";
  } elsif (exists $english_to_key{lc($seq)}) {
    $seq = $english_to_key{lc($seq)};
  }

  return $seq;
}

sub control {
  my $c = shift;
  return chr(0x7F) if $c eq "?";
  return chr(ord(uc($c))-64);
}

sub meta    { return "\x1B" . $_[0] };
sub bind_key {
  my ($self, $inseq, $fn) = @_;
  my $seq = $inseq;
  my $macro = undef;
  if (!ref $fn) {
    if ($fn =~ /^["'](.*)['"]$/) {
      # A macro
      $macro = $1;
      $fn = 'insert-macro';
    } else {
      if (!exists $POE::Wheel::ReadLine::defuns->{$fn}) {
        print "ignoring $inseq, since function '$fn' is not known\r\n";
        next;
      }
    }
  }

  # Need to parse key sequence into a trivial lookup form.
  if ($seq =~ s{^"(.*)"$}{$1}) {
    $seq =~ s{\\C-(.)}{control($1)}ge;
    $seq =~ s{\\M-(.)}{meta($1)}ge;
    $seq =~ s{\\e}{\x1B}g;
    $seq =~ s{\\\\}{\\}g;
    $seq =~ s{\\"}{"}g;
    $seq =~ s{\\'}{'}g;
  } else {
    my $orig = $seq;
    do {
      $orig = $seq;
      $seq =~ s{(\w*)$}{$self->decode($1)}ge;
      # horrible regex, coz we need to work backwards, to allow
      # for things like C-M-r, or C-xC-x
      $seq =~ s{C(ontrol)?-(.)([^-]*)$}{control($2).$3}ge;
      $seq =~ s{M(eta)?-(.)([^-]*)$}{meta($2).$3}ge;
    } while ($seq ne $orig);
  }

  $self->{binding}->{$seq} = $fn if length $seq;
  $self->{macros}->{$seq} = $macro if $macro;
  #print "bound $inseq (" . POE::Wheel::ReadLine::_normalize($seq) . ") to $fn in map $self->{name}\r\n";

  if (length($seq) > 1) {
    # XXX: Should store rawkey prefixes, to avoid the ^ problem.
    # requires converting seq into raw, then applying normalize
    # later on for binding. May not need last step if we keep
    # everything as raw.
    # Some keystrokes generate multi-byte sequences.  Record the prefixes
    # for multi-byte sequences so the keystroke builder knows it's in the
    # middle of something.
    while (length($seq) > 1) {
      chop $seq;
      $self->{prefix}->{$seq}++;
    }
  }
}

1;

__END__

=head1 NAME

POE::Wheel::ReadLine - non-blocking Term::ReadLine for POE

=head1 SYNOPSIS

  #!perl

  use warnings;
  use strict;

  use POE qw(Wheel::ReadLine);

  POE::Session->create(
    inline_states=> {
      _start => \&setup_console,
      got_user_input => \&handle_user_input,
    }
  );

  POE::Kernel->run();
  exit;

  sub handle_user_input {
    my ($input, $exception) = @_[ARG0, ARG1];
    my $console = $_[HEAP]{console};

    unless (defined $input) {
      $console->put("$exception caught.  B'bye!");
      $_[KERNEL]->signal($_[KERNEL], "UIDESTROY");
      $console->write_history("./test_history");
      return;
    }

    $console->put("  You entered: $input");
    $console->addhistory($input);
    $console->get("Go: ");
  }

  sub setup_console {
    $_[HEAP]{console} = POE::Wheel::ReadLine->new(
      InputEvent => 'got_user_input'
    );
    $_[HEAP]{console}->read_history("./test_history");
    $_[HEAP]{console}->clear();
    $_[HEAP]{console}->put(
      "Enter some text.",
      "Ctrl+C or Ctrl+D exits."
    );
    $_[HEAP]{console}->get("Go: ");
  }

=head1 DESCRIPTION

POE::Wheel::ReadLine is a non-blocking form of Term::ReadLine that's
compatible with POE.  It uses Term::Cap to interact with the terminal
display and Term::ReadKey to interact with the keyboard.

POE::Wheel::ReadLine handles almost all common input editing keys.  It
provides an input history list.  It has both vi and emacs modes.  It
supports incremental input search.  It's fully customizable, and it's
compatible with standard readline(3) implementations such as
Term::ReadLine::Gnu.

POE::Wheel::ReadLine is configured by placing commands in an "inputrc"
initialization file.  The file's name is taken from the C<INPUTRC>
environment variable, or ~/.inputrc by default.  POE::Wheel::ReadLine
will read the inputrc file and configure itself according to the
commands and variables therein.  See readline(3) for details about
inputrc files.

The default editing mode will be emacs-style, although this can be
configured by setting the 'editing-mode' variable within an inputrc
file.  If all else fails, POE::Wheel::ReadLine will determine the
user's favorite editor by examining the EDITOR environment variable.

=head1 PUBLIC METHODS

=head2 Constructor

Most of POE::Wheel::ReadLine's interaction is through its constructor,
new().

=head3 new

new() creates and returns a new POE::Wheel::ReadLine object.  Be sure
to instantiate only one, as multiple console readers would conflict.

=head4 InputEvent

C<InputEvent> names the event that will indicate a new line of console
input.  See L</PUBLIC EVENTS> for more details.

=head4 PutMode

C<PutMode> controls how output is displayed when put() is called
during user input.

When set to "immediate", put() pre-empts the user immediately.  The
input prompt and user's input to date are redisplayed after put() is
done.

The "after" C<PutMode> tells put() to wait until after the user enters
or cancels her input.

Finally, "idle" will allow put() to pre-empt user input if the user
stops typing for L</IdleTime> seconds.  This mode behaves like "after"
if the user can't stop typing long enough.  This is
POE::Wheel::ReadLine's default mode.

=head4 IdleTime

C<IdleTime> tells POE::Wheel::ReadLine how long the keyboard must be
idle before C<put()> becomes immediate or buffered text is flushed to
the display.  It is only meaningful when L</PutMode> is "idle".
C<IdleTime> defaults to 2 seconds.

=head4 AppName

C<AppName> registers an application name which is used to retrieve
application-specific key bindings from the inputrc file.  The default
C<AppName> is "poe-readline".

  # If using POE::Wheel::ReadLine, set
  # the key mapping to emacs mode and
  # trigger debugging output on a certain
  # key sequence.
  $if poe-readline
  set keymap emacs
  Control-xP: poe-wheel-debug
  $endif

=head2 History List Management

POE::Wheel::ReadLine supports an input history, with searching.

=head3 add_history

add_history() accepts a list of lines to add to the input history.
Generally it's called with a single line: the last line of input
received from the terminal.  The L</SYNOPSIS> shows add_history() in
action.

=head3 get_history

get_history() returns a list containing POE::Wheel::ReadLine's current
input history.  It may not contain everything entered into the wheel

TODO - Example.

=head3 write_history

write_history() writes the current input history to a file.  It
accepts one optional parameter: the name of the file where the input
history will be written.  write_history() will write to ~/.history if
no file name is specified.

Returns true on success, or false if not.

The L</SYNOPSIS> shows an example of write_history() and the
corresponding read_history().

=head3 read_history

read_history(FILENAME, START, END) reads a previously saved input
history from a named file, or from ~/.history if no file name is
specified.  It may also read a subset of the history file if it's
given optional START and END parameters.  The file will be read from
the beginning if START is omitted or zero.  It will be read to the end
if END is omitted or earlier than START.

Returns true on success, or false if not.

The L</SYNOPSIS> shows an example of read_history() and the
corresponding write_history().

Read the first ten history lines:

  $_[HEAP]{console}->read_history("filename", 0, 9);

=head3 history_truncate_file

history_truncate_file() truncates a history file to a certain number
of lines.  It accepts two parameters: the name of the file to
truncate, and the maximum number of history lines to leave in the
file.  The history file will be cleared entirely if the line count is
zero or omitted.

The file to be truncated defaults to ~/.history.  So calling
history_truncate_file() with no parameters clears ~/.history.

Returns true on success, or false if not.

Note that history_trucate_file() removes the earliest lines from the
file.  The later lines remain intact since they were the ones most
recently entered.

Keep ~/.history down to a manageable 100 lines:

  $_[HEAP]{console}->history_truncate_file(undef, 100);

=head2 Key Binding Methods

=head3 bind_key

bind_key(KEYSTROKE, FUNCTION) binds a FUNCTION to a named KEYSTROKE
sequence.  The keystroke sequence can be in any of the forms defined
within readline(3).  The function should either be a pre-defined name,
such as "self-insert" or a function reference.  The binding is made in
the current keymap.  Use the rl_set_keymap() method to change keymaps,
if desired.

=head3 add_defun NAME FN

add_defun(NAME, FUNCTION) defines a new global FUNCTION, giving it a
specific NAME.  The function may then be bound to keystrokes by that
NAME.

=head2 Console I/O Methods

=head3 clear

Clears the terminal.

=head3 terminal_size

Returns what POE::Wheel::ReadLine thinks are the current dimensions of
the terminal.  Returns a list of two values: the number of columns and
number of rows, respectively.

  sub some_event_handler {
    my ($columns, $rows) = $_[HEAP]{console}->terminal_size;
    $_[HEAP]{console}->put(
      "Terminal columns: $columns",
      "Terminal rows: $rows",
    );
  }

=head3 get

get() causes POE::Wheel::ReadLine to display a prompt and then wait
for input.  Input is not noticed unless get() has enabled the wheel's
internal I/O watcher.

After get() is called, the next line of input or exception on the
console will trigger an C<InputEvent> with the appropriate parameters.
POE::Wheel::ReadLine will then enter an inactive state until get() is
called again.

See the L</SYNOPSIS> for sample usage.

=head3 put

put() accepts a list of lines to put on the terminal.
POE::Wheel::ReadLine is line-based.  See L<POE::Wheel::Curses> for
more funky display options.

Please do not use print() with POE::Wheel::ReadLine.  print()
invariably gets the newline wrong, leaving an application's output to
stairstep down the terminal.  Also, put() understands when a user is
entering text, and C<PutMode> may be used to avoid interrupting the
user.

=head2 ReadLine Option Methods

=head3 attribs

attribs() returns a reference to a hash of readline options.  The
returned hash may be used to query or modify POE::Wheel::ReadLine's
behavior.

=head3 option

option(NAME) returns a specific member of the hash returned by
attribs().  It's a more convenient way to query POE::Wheel::ReadLine
options.

=head1 PUBLIC EVENTS

POE::Wheel::ReadLine emits only a single event.

=head2 InputEvent

C<InputEvent> names the event that will be emitted upon any kind of
complete terminal input.  Every C<InputEvent> handler receives three
parameters:

C<$_[ARG0]> contains a line of input.  It may be an empty string if
the user entered an empty line.  An undefined C<$_[ARG0]> indicates
some exception such as end-of-input or the fact that the user canceled
their input or pressed C-c (^C).

C<$_[ARG1]> describes an exception, if one occurred.  It may contain
one of the following strings:

=over 2

=item cancel

The "cancel" exception indicates when a user has canceled a line of
input.  It's sent when the user triggers the "abort" function, which
is bound to C-g (^G) by default.

=item eot

"eot" is the ASCII code for "end of tape".  It's emitted when the user
requests that the terminal be closed.  By default, it's triggered when
the user presses C-d (^D) on an empty line.

=item interrupt

"interrupt" is sent as a result of the user pressing C-c (^C) or
otherwise triggering the "interrupt" function.

=back

Finally, C<$_[ARG2]> contains the ID for the POE::Wheel::ReadLine
object that sent the C<InputEvent>.

=head1 CUSTOM BINDINGS

POE::Wheel::ReadLine allows custom functions to be bound to
keystrokes.  The function must be made visible to the wheel before it
can be bound.  To register a function, use POE::Wheel::ReadLine's
add_defun() method:

  POE::Wheel::ReadLine->add_defun('reverse-line', \&reverse_line);

When adding a new defun, an optional third parameter may be provided
which is a key sequence to bind to.  This should be in the same format
as that understood by the inputrc parsing.

Bound functions receive three parameters: A reference to the wheel
object itself, the key sequence that triggered the function (in
printable form), and the raw key sequence.  The bound function is
expected to dig into the POE::Wheel::ReadLine data members to do its
work and display the new line contents itself.

This is less than ideal, and it may change in the future.

=head1 CUSTOM COMPLETION

An application may modify POE::Wheel::ReadLine's "completion_function"
in order to customize how input should be completed.  The new
completion function must accept three scalar parameters: the word
being completed, the entire input text, and the position within the
input text of the word being completed.

The completion function should return a list of possible matches.  For
example:

  my $attribs = $wheel->attribs();
  $attribs->{completion_function} = sub {
    my ($text, $line, $start) = @_;
    return qw(a list of candidates to complete);
  }

This is the only form of completion currently supported.

=head1 IMPLEMENTATION DIFFERENCES

Although POE::Wheel::ReadLine is modeled after the readline(3)
library, there are some areas which have not been implemented.  The
only option settings which have effect in this implementation are:
bell-style, editing-mode, isearch-terminators, comment-begin,
print-completions-horizontally, show-all-if-ambiguous and
completion_function.

The function 'tab-insert' is not implemented, nor are tabs displayed
properly.

=head1 SEE ALSO

L<POE::Wheel> describes the basic operations of all wheels in more
depth.  You need to know this.

readline(3), L<Term::Cap>, L<Term::ReadKey>.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

L<Term::Visual> is an alternative to POE::Wheel::ReadLine.  It
provides scrollback and a status bar in addition to editable user
input.  Term::Visual supports POE despite the lack of "POE" in its
name.

=head1 BUGS

POE::Wheel::ReadLine has some known issues:

=head2 Perl 5.8.0 is Broken

Non-blocking input with Term::ReadKey does not work with Perl 5.8.0,
especially on Linux systems for some reason.  Upgrading Perl will fix
things.  If you can't upgrade Perl, consider alternative input
methods, such as Term::Visual.

L<http://rt.cpan.org/Ticket/Display.html?id=4524> and related tickets
explain the issue in detail.  If you suspect your system is one where
Term::ReadKey fails, you can run this test program to be sure.

  #!/usr/bin/perl
  use Term::ReadKey;
  print "Press 'q' to quit this test.\n";
  ReadMode 5; # Turns off controls keys
  while (1) {
    while (not defined ($key = ReadKey(-1))) {
      print "Didn't get a key.  Sleeping 1 second.\015\012";
      sleep (1);
    }
    print "Got key: $key\015\012";
    ($key eq 'q') and last;
  }
  ReadMode 0; # Reset tty mode before exiting
  exit;

=head2 Non-Optimal Code

Dissociating the input and display cursors introduced a lot of code.
Much of this code was thrown in hastily, and things can probably be
done with less work.

TODO: Apply some thought to what's already been done.

TODO: Ensure that the screen updates as quickly as possible,
especially on slow systems.  Do little or no calculation during
displaying; either put it all before or after the display.  Do it
consistently for each handled keystroke, so that certain pairs of
editing commands don't have extra perceived latency.

=head2 Unimplemented Features

Input editing is not kept on one line.  If it wraps, and a terminal
cannot wrap back through a line division, the cursor will become lost.

Unicode support.  I feel real bad about throwing away native
representation of all the 8th-bit-set characters.  I also have no idea
how to do this, and I don't have a system to test this.  Patches are
very much welcome.

=head1 GOTCHAS / FAQ

=head2 Lost Prompts

Q: Why do I lose my prompt every time I send output to the screen?

A: You probably are using print or printf to write screen output.
ReadLine doesn't track STDOUT itself, so it doesn't know when to
refresh the prompt after you do this.  Use ReadLine's put() method to
write lines to the console.

=head2 Edit Keystrokes Display as ^C

Q: None of the editing keystrokes work.  Ctrl-C displays "^c" rather
than generating an interrupt.  The arrow keys don't scroll through my
input history.  It's generally a bad experience.

A: You're probably a vi/vim user.  In the absence of a ~/.inputrc
file, POE::Wheel::ReadLine checks your EDITOR environment variable for
clues about your editing preference.  If it sees /vi/ in there, it
starts in vi mode.  You can override this by creating a ~/.inputrc
file containing the line "set editing-mode emacs", or adding that line
to your existing ~/.inputrc.  While you're in there, you should
totally get acquainted with all the other cool stuff you can do with
.inputrc files.

=head2 Lack of Windows Support

Q: Why doesn't POE::Wheel::ReadLine work on Windows?  Term::ReadLine
does.

A: POE::Wheel::ReadLine requires select(), because that's what POE
uses by default to detect keystrokes without blocking.  About half the
flavors of Perl on Windows implement select() in terms of the same
function in the WinSock library, which limits select() to working only
with sockets.  Your console isn't a socket, so select() doesn't work
with your version of Perl on Windows.

Really good workarounds are possible but don't exist as of this
writing.  They involve writing a special POE::Loop for Windows that
either uses a Win32-specific module for better multiplexing, that
polls for input, or that uses blocking I/O watchers in separate
threads.

=head2 Cygwin Support

Q: Why does POE::Wheel::ReadLine complain about my "dumb" terminal?

A: Do you have Strawberry Perl installed? Due to the way it works, on
installation it sets a global environment variable in MSWin32 for
TERM=dumb. ( it may be fixed in a future version, but it's here to stay
for now, ha! ) In this case, logging into the Cygwin shell via the
cygwin.bat launcher results in a nonfunctional readline.

Normally, Cygwin will set TERM=cygwin in the launcher. However, if the 
TERM was already set it will not alter the value. Hence, the "bug"
appears! What you can do is to hack the cygwin.bat file to add this line:

  SET TERM=cygwin

Other users reported that you can have better results by editing the
~/.bash_profile file to set TERM=cygwin because on a Cygwin upgrade it
overwrites the cygwin.bat file.

Alternatively, you could install different terminals like "xterm" or "rxvt"
as shown here: L<http://c2.com/cgi/wiki?BetterCygwinTerminal>. Please let
us know if you encounter problems using any terminal other than "dumb".

If you feel brave, you can peruse the RT ticket at 
L<http://rt.cpan.org/Ticket/Display.html?id=55365> for more information
on this problem.

=head1 AUTHORS & COPYRIGHTS

POE::Wheel::ReadLine was originally written by Rocco Caputo.

Nick Williams virtually rewrote it to support a larger subset of GNU
readline.

Please see L<POE> for more information about other authors and
contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
