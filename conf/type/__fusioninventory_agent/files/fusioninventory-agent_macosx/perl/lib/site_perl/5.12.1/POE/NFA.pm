package POE::NFA;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw(carp croak);

sub SPAWN_INLINES       () { 'inline_states' }
sub SPAWN_OBJECTS       () { 'object_states' }
sub SPAWN_PACKAGES      () { 'package_states' }
sub SPAWN_OPTIONS       () { 'options' }
sub SPAWN_RUNSTATE      () { 'runstate' }

sub OPT_TRACE           () { 'trace' }
sub OPT_DEBUG           () { 'debug' }
sub OPT_DEFAULT         () { 'default' }

sub EN_DEFAULT          () { '_default' }
sub EN_START            () { '_start' }
sub EN_STOP             () { '_stop' }
sub EN_SIGNAL           () { '_signal' }

sub NFA_EN_GOTO_STATE   () { 'poe_nfa_goto_state' }
sub NFA_EN_POP_STATE    () { 'poe_nfa_pop_state' }
sub NFA_EN_PUSH_STATE   () { 'poe_nfa_push_state' }
sub NFA_EN_STOP         () { 'poe_nfa_stop' }

sub SELF_RUNSTATE       () { 0 }
sub SELF_OPTIONS        () { 1 }
sub SELF_STATES         () { 2 }
sub SELF_CURRENT        () { 3 }
sub SELF_STATE_STACK    () { 4 }
sub SELF_INTERNALS      () { 5 }
sub SELF_CURRENT_NAME   () { 6 }
sub SELF_IS_IN_INTERNAL () { 7 }

sub STACK_STATE         () { 0 }
sub STACK_EVENT         () { 1 }

#------------------------------------------------------------------------------

# Shorthand for defining a trace constant.

sub _define_trace {
  no strict 'refs';

  local $^W = 0;

  foreach my $name (@_) {
    next if defined *{"TRACE_$name"}{CODE};
    if (defined *{"POE::Kernel::TRACE_$name"}{CODE}) {
      eval(
        "sub TRACE_$name () { " .
        *{"POE::Kernel::TRACE_$name"}{CODE}->() .
        "}"
      );
      die if $@;
    }
    else {
      eval "sub TRACE_$name () { TRACE_DEFAULT }";
      die if $@;
    }
  }
}

#------------------------------------------------------------------------------

BEGIN {

  # ASSERT_DEFAULT changes the default value for other ASSERT_*
  # constants.  It inherits POE::Kernel's ASSERT_DEFAULT value, if
  # it's present.

  unless (defined &ASSERT_DEFAULT) {
    if (defined &POE::Kernel::ASSERT_DEFAULT) {
      eval( "sub ASSERT_DEFAULT () { " . &POE::Kernel::ASSERT_DEFAULT . " }" );
    }
    else {
      eval 'sub ASSERT_DEFAULT () { 0 }';
    }
  };

  # TRACE_DEFAULT changes the default value for other TRACE_*
  # constants.  It inherits POE::Kernel's TRACE_DEFAULT value, if
  # it's present.

  unless (defined &TRACE_DEFAULT) {
    if (defined &POE::Kernel::TRACE_DEFAULT) {
      eval( "sub TRACE_DEFAULT () { " . &POE::Kernel::TRACE_DEFAULT . " }" );
    }
    else {
      eval 'sub TRACE_DEFAULT () { 0 }';
    }
  };

  _define_trace("DESTROY");
}

#------------------------------------------------------------------------------
# Export constants into calling packages.  This is evil; perhaps
# EXPORT_OK instead?  The parameters NFA has in common with SESSION
# (and other sessions) must be kept at the same offsets as each-other.

sub OBJECT      () {  0 }
sub MACHINE     () {  1 }
sub KERNEL      () {  2 }
sub RUNSTATE    () {  3 }
sub EVENT       () {  4 }
sub SENDER      () {  5 }
sub STATE       () {  6 }
sub CALLER_FILE () {  7 }
sub CALLER_LINE () {  8 }
sub CALLER_STATE () {  9 }
sub ARG0        () { 10 }
sub ARG1        () { 11 }
sub ARG2        () { 12 }
sub ARG3        () { 13 }
sub ARG4        () { 14 }
sub ARG5        () { 15 }
sub ARG6        () { 16 }
sub ARG7        () { 17 }
sub ARG8        () { 18 }
sub ARG9        () { 19 }

sub import {
  my $package = caller();
  no strict 'refs';
  *{ $package . '::OBJECT'   } = \&OBJECT;
  *{ $package . '::MACHINE'  } = \&MACHINE;
  *{ $package . '::KERNEL'   } = \&KERNEL;
  *{ $package . '::RUNSTATE' } = \&RUNSTATE;
  *{ $package . '::EVENT'    } = \&EVENT;
  *{ $package . '::SENDER'   } = \&SENDER;
  *{ $package . '::STATE'    } = \&STATE;
  *{ $package . '::ARG0'     } = \&ARG0;
  *{ $package . '::ARG1'     } = \&ARG1;
  *{ $package . '::ARG2'     } = \&ARG2;
  *{ $package . '::ARG3'     } = \&ARG3;
  *{ $package . '::ARG4'     } = \&ARG4;
  *{ $package . '::ARG5'     } = \&ARG5;
  *{ $package . '::ARG6'     } = \&ARG6;
  *{ $package . '::ARG7'     } = \&ARG7;
  *{ $package . '::ARG8'     } = \&ARG8;
  *{ $package . '::ARG9'     } = \&ARG9;
}

#------------------------------------------------------------------------------
# Spawn a new state machine.

sub _add_ref_states {
  my ($states, $refs) = @_;

  foreach my $state (keys %$refs) {
    $states->{$state} = {};

    my $data = $refs->{$state};
    croak "the data for state '$state' should be an array" unless (
      ref $data eq 'ARRAY'
    );
    croak "the array for state '$state' has an odd number of elements" if (
      @$data & 1
    );

    while (my ($ref, $events) = splice(@$data, 0, 2)) {
      if (ref $events eq 'ARRAY') {
        foreach my $event (@$events) {
          $states->{$state}->{$event} = [ $ref, $event ];
        }
      }
      elsif (ref $events eq 'HASH') {
        foreach my $event (keys %$events) {
          my $method = $events->{$event};
          $states->{$state}->{$event} = [ $ref, $method ];
        }
      }
      else {
        croak "events with '$ref' for state '$state' " .
        "need to be a hash or array ref";
      }
    }
  }
}

sub spawn {
  my ($type, @params) = @_;
  my @args;

  # We treat the parameter list strictly as a hash.  Rather than dying
  # here with a Perl error, we'll catch it and blame it on the user.

  croak "odd number of events/handlers (missing one or the other?)"
    if @params & 1;
  my %params = @params;

  croak "$type requires a working Kernel"
    unless defined $POE::Kernel::poe_kernel;

  # Options are optional.
  my $options = delete $params{+SPAWN_OPTIONS};
  $options = { } unless defined $options;

  # States are required.
  croak(
    "$type constructor requires at least one of the following parameters: " .
    join (", ", SPAWN_INLINES, SPAWN_OBJECTS, SPAWN_PACKAGES)
  ) unless (
    exists $params{+SPAWN_INLINES} or
    exists $params{+SPAWN_OBJECTS} or
    exists $params{+SPAWN_PACKAGES}
  );

  my $states = delete($params{+SPAWN_INLINES}) || {};

  if (exists $params{+SPAWN_OBJECTS}) {
    my $objects = delete $params{+SPAWN_OBJECTS};
    _add_ref_states($states, $objects);
  }

  if (exists $params{+SPAWN_PACKAGES}) {
    my $packages = delete $params{+SPAWN_PACKAGES};
    _add_ref_states($states, $packages);
  }

  my $runstate = delete($params{+SPAWN_RUNSTATE}) || {};

  # These are unknown.
  croak(
    "$type constructor does not recognize these parameter names: ",
    join(', ', sort(keys(%params)))
  ) if keys %params;

  # Build me.
  my $self = bless [
    $runstate,  # SELF_RUNSTATE
    $options,   # SELF_OPTIONS
    $states,    # SELF_STATES
    undef,      # SELF_CURRENT
    [ ],        # SELF_STATE_STACK
    { },        # SELF_INTERNALS
    '(undef)',  # SELF_CURRENT_NAME
    0,          # SELF_IS_IN_INTERNAL
  ], $type;

  # Register the machine with the POE kernel.
  $POE::Kernel::poe_kernel->session_alloc($self);

  # Return it for immediate reuse.
  return $self;
}

#------------------------------------------------------------------------------
# Another good inheritance candidate.

sub DESTROY {
  my $self = shift;

  # NFA's data structures are destroyed through Perl's usual garbage
  # collection.  TRACE_DESTROY here just shows what's in the session
  # before the destruction finishes.

  TRACE_DESTROY and do {
    POE::Kernel::_warn(
      "----- NFA $self Leak Check -----\n",
      "-- Namespace (HEAP):\n"
    );
    foreach (sort keys (%{$self->[SELF_RUNSTATE]})) {
      POE::Kernel::_warn("   $_ = ", $self->[SELF_RUNSTATE]->{$_}, "\n");
    }
    POE::Kernel::_warn("-- Options:\n");
    foreach (sort keys (%{$self->[SELF_OPTIONS]})) {
      POE::Kernel::_warn("   $_ = ", $self->[SELF_OPTIONS]->{$_}, "\n");
    }
    POE::Kernel::_warn("-- States:\n");
    foreach (sort keys (%{$self->[SELF_STATES]})) {
      POE::Kernel::_warn("   $_ = ", $self->[SELF_STATES]->{$_}, "\n");
    }
  };
}

#------------------------------------------------------------------------------

sub _invoke_state {
  my ($self, $sender, $event, $args, $file, $line, $fromstate) = @_;

  # Trace the state invocation if tracing is enabled.

  if ($self->[SELF_OPTIONS]->{+OPT_TRACE}) {
    POE::Kernel::_warn(
      $POE::Kernel::poe_kernel->ID_session_to_id($self), " -> $event\n"
    );
  }

  # Discard troublesome things.
  return if $event eq EN_START;
  return if $event eq EN_STOP;

  # Stop request has come through the queue.  Shut us down.
  if ($event eq NFA_EN_STOP) {
    $POE::Kernel::poe_kernel->_data_ses_stop( $self );
    return;
  }

  # Make a state transition.
  if ($event eq NFA_EN_GOTO_STATE) {
    my ($new_state, $enter_event, @enter_args) = @$args;

    # Make sure the new state exists.
    POE::Kernel::_die(
      $POE::Kernel::poe_kernel->ID_session_to_id($self),
      " tried to enter nonexistent state '$new_state'\n"
    )
    unless exists $self->[SELF_STATES]->{$new_state};

    # If an enter event was specified, make sure that exists too.
    POE::Kernel::_die(
      $POE::Kernel::poe_kernel->ID_session_to_id($self),
      " tried to invoke nonexistent enter event '$enter_event' ",
      "in state '$new_state'\n"
    )
    unless (
      not defined $enter_event or
      ( length $enter_event and
        exists $self->[SELF_STATES]->{$new_state}->{$enter_event}
      )
    );

    # Invoke the current state's leave event, if one exists.
    $self->_invoke_state( $self, 'leave', [], undef, undef, undef )
      if exists $self->[SELF_CURRENT]->{leave};

    # Enter the new state.
    $self->[SELF_CURRENT]      = $self->[SELF_STATES]->{$new_state};
    $self->[SELF_CURRENT_NAME] = $new_state;

    # Invoke the new state's enter event, if requested.
    $self->_invoke_state(
      $self, $enter_event, \@enter_args, undef, undef, undef
    ) if defined $enter_event;

    return undef;
  }

  # Push a state transition.
  if ($event eq NFA_EN_PUSH_STATE) {

    my @args = @$args;
    push(
      @{$self->[SELF_STATE_STACK]},
      [ $self->[SELF_CURRENT_NAME], # STACK_STATE
        shift(@args),               # STACK_EVENT
      ]
    );
    $self->_invoke_state(
      $self, NFA_EN_GOTO_STATE, \@args, undef, undef, undef
    );

    return undef;
  }

  # Pop a state transition.
  if ($event eq NFA_EN_POP_STATE) {

    POE::Kernel::_die(
      $POE::Kernel::poe_kernel->ID_session_to_id($self),
      " tried to pop a state from an empty stack\n"
    )
    unless @{ $self->[SELF_STATE_STACK] };

    my ($previous_state, $previous_event) = @{
      pop @{ $self->[SELF_STATE_STACK] }
    };
    $self->_invoke_state(
      $self, NFA_EN_GOTO_STATE,
      [ $previous_state, $previous_event, @$args ],
      undef, undef, undef
    );

    return undef;
  }

  # Stop.

  # Try to find the event handler in the current state or the internal
  # event handlers used by wheels and the like.
  my ( $handler, $is_in_internal );

  if (exists $self->[SELF_CURRENT]->{$event}) {
    $handler = $self->[SELF_CURRENT]->{$event};
  }

  elsif (exists $self->[SELF_INTERNALS]->{$event}) {
    $handler = $self->[SELF_INTERNALS]->{$event};
    $is_in_internal = ++$self->[SELF_IS_IN_INTERNAL];
  }

  # If it wasn't found in either of those, then check for _default in
  # the current state.
  elsif (exists $self->[SELF_CURRENT]->{+EN_DEFAULT}) {
    # If we get this far, then there's a _default event to redirect
    # the event to.  Trace the redirection.
    if ($self->[SELF_OPTIONS]->{+OPT_TRACE}) {
      POE::Kernel::_warn(
        $POE::Kernel::poe_kernel->ID_session_to_id($self),
        " -> $event redirected to EN_DEFAULT in state ",
        "'$self->[SELF_CURRENT_NAME]'\n"
      );
    }

    $handler = $self->[SELF_CURRENT]->{+EN_DEFAULT};

    # Transform the parameters for _default.  ARG1 and beyond are
    # copied so they can't be altered at a distance.
    $args  = [ $event, [@$args] ];
    $event = EN_DEFAULT;
  }

  # No external event handler, no internal event handler, and no
  # external _default handler.  This is a grievous error, and now we
  # must die.
  elsif ($event ne EN_SIGNAL) {
    POE::Kernel::_die(
      "a '$event' event was sent from $file at $line to session ",
      $POE::Kernel::poe_kernel->ID_session_to_id($self),
      ", but session ", $POE::Kernel::poe_kernel->ID_session_to_id($self),
      " has neither a handler for it nor one for _default ",
      "in its current state, '$self->[SELF_CURRENT_NAME]'\n"
    );
  }

  # Inline event handlers are invoked this way.

  my $return;
  if (ref($handler) eq 'CODE') {
    $return = $handler->(
      undef,                      # OBJECT
      $self,                      # MACHINE
      $POE::Kernel::poe_kernel,   # KERNEL
      $self->[SELF_RUNSTATE],     # RUNSTATE
      $event,                     # EVENT
      $sender,                    # SENDER
      $self->[SELF_CURRENT_NAME], # STATE
      $file,                      # CALLER_FILE_NAME
      $line,                      # CALLER_FILE_LINE
      $fromstate,                 # CALLER_STATE
      @$args                      # ARG0..
    );
  }

  # Package and object handlers are invoked this way.

  else {
    my ($object, $method) = @$handler;
    $return = $object->$method(   # OBJECT (package, implied)
      $self,                      # MACHINE
      $POE::Kernel::poe_kernel,   # KERNEL
      $self->[SELF_RUNSTATE],     # RUNSTATE
      $event,                     # EVENT
      $sender,                    # SENDER
      $self->[SELF_CURRENT_NAME], # STATE
      $file,                      # CALLER_FILE_NAME
      $line,                      # CALLER_FILE_LINE
      $fromstate,                 # CALLER_STATE
      @$args                      # ARG0..
    );
  }

  $self->[SELF_IS_IN_INTERNAL]-- if $is_in_internal;

  return $return;
}

#------------------------------------------------------------------------------
# Add, remove or replace event handlers in the session.  This is going
# to be tricky since wheels need this but the event handlers can't be
# limited to a single state.  I think they'll go in a hidden internal
# state, or something.

sub _register_state {
  my ($self, $name, $handler, $method) = @_;
  $method = $name unless defined $method;

  # Deprecate _signal.
  if ($name eq EN_SIGNAL) {

    # Report the problem outside POE.
    my $caller_level = 0;
    local $Carp::CarpLevel = 1;
    while ( (caller $caller_level)[0] =~ /^POE::/ ) {
      $caller_level++;
      $Carp::CarpLevel++;
    }

    croak(
      ",----- DEPRECATION ERROR -----\n",
      "| The _signal event is deprecated.  Please use sig() to register\n",
      "| an explicit signal handler instead.\n",
      "`-----------------------------\n",
    );
  }
  # There is a handler, so try to define the state.  This replaces an
  # existing state.

  if ($handler) {

    # Coderef handlers are inline states.

    if (ref($handler) eq 'CODE') {
      POE::Kernel::_carp(
        "redefining handler for event($name) for session(",
        $POE::Kernel::poe_kernel->ID_session_to_id($self), ")"
      )
      if (
        $self->[SELF_OPTIONS]->{+OPT_DEBUG} and
        (exists $self->[SELF_INTERNALS]->{$name})
      );
      $self->[SELF_INTERNALS]->{$name} = $handler;
    }

    # Non-coderef handlers may be package or object states.  See if
    # the method belongs to the handler.

    elsif ($handler->can($method)) {
      POE::Kernel::_carp(
        "redefining handler for event($name) for session(",
        $POE::Kernel::poe_kernel->ID_session_to_id($self), ")"
      )
      if (
        $self->[SELF_OPTIONS]->{+OPT_DEBUG} &&
        (exists $self->[SELF_INTERNALS]->{$name})
      );
      $self->[SELF_INTERNALS]->{$name} = [ $handler, $method ];
    }

    # Something's wrong.  This code also seems wrong, since
    # ref($handler) can't be 'CODE'.

    else {
      if (
        (ref($handler) eq 'CODE') and
        $self->[SELF_OPTIONS]->{+OPT_TRACE}
      ) {
        POE::Kernel::_carp(
          $self->fetch_id(),
          " : handler for event($name) is not a proper ref - not registered"
        )
      }
      else {
        unless ($handler->can($method)) {
          if (length ref($handler)) {
            croak "object $handler does not have a '$method' method"
          }
          else {
            croak "package $handler does not have a '$method' method";
          }
        }
      }
    }
  }

  # No handler.  Delete the state!

  else {
    delete $self->[SELF_INTERNALS]->{$name};
  }
}

#------------------------------------------------------------------------------
# Return the session's ID.  This is a thunk into POE::Kernel, where
# the session ID really lies.  This is a good inheritance candidate.

sub ID {
  $POE::Kernel::poe_kernel->ID_session_to_id(shift);
}

#------------------------------------------------------------------------------
# Return the session's current state's name.

sub get_current_state {
  my $self = shift;
  return $self->[SELF_CURRENT_NAME];
}

#------------------------------------------------------------------------------

# Fetch the session's run state.  In rare cases, libraries may need to
# break encapsulation this way, probably also using
# $kernel->get_current_session as an accessory to the crime.

sub get_runstate {
  my $self = shift;
  return $self->[SELF_RUNSTATE];
}

#------------------------------------------------------------------------------
# Set or fetch session options.  This is virtually identical to
# POE::Session and a good inheritance candidate.

sub option {
  my $self = shift;
  my %return_values;

  # Options are set in pairs.

  while (@_ >= 2) {
    my ($flag, $value) = splice(@_, 0, 2);
    $flag = lc($flag);

    # If the value is defined, then set the option.

    if (defined $value) {

      # Change some handy values into boolean representations.  This
      # clobbers the user's original values for the sake of DWIM-ism.

      ($value = 1) if ($value =~ /^(on|yes|true)$/i);
      ($value = 0) if ($value =~ /^(no|off|false)$/i);

      $return_values{$flag} = $self->[SELF_OPTIONS]->{$flag};
      $self->[SELF_OPTIONS]->{$flag} = $value;
    }

    # Remove the option if the value is undefined.

    else {
      $return_values{$flag} = delete $self->[SELF_OPTIONS]->{$flag};
    }
  }

  # If only one option is left, then there's no value to set, so we
  # fetch its value.

  if (@_) {
    my $flag = lc(shift);
    $return_values{$flag} = (
      exists($self->[SELF_OPTIONS]->{$flag})
      ? $self->[SELF_OPTIONS]->{$flag}
      : undef
    );
  }

  # If only one option was set or fetched, then return it as a scalar.
  # Otherwise return it as a hash of option names and values.

  my @return_keys = keys(%return_values);
  if (@return_keys == 1) {
    return $return_values{$return_keys[0]};
  }
  else {
    return \%return_values;
  }
}

#------------------------------------------------------------------------------
# This stuff is identical to the stuff in POE::Session.  Good
# inheritance candidate.

# Create an anonymous sub that, when called, posts an event back to a
# session.  This is highly experimental code to support Tk widgets and
# maybe Event callbacks.  There's no guarantee that this code works
# yet, nor is there one that it'll be here in the next version.

# This maps postback references (stringified; blessing, and thus
# refcount, removed) to parent session IDs.  Members are set when
# postbacks are created, and postbacks' DESTROY methods use it to
# perform the necessary cleanup when they go away.  Thanks to njt for
# steering me right on this one.

my %postback_parent_id;

# I assume that when the postback owner loses all reference to it,
# they are done posting things back to us.  That's when the postback's
# DESTROY is triggered, and referential integrity is maintained.

sub POE::NFA::Postback::DESTROY {
  my $self = shift;
  my $parent_id = delete $postback_parent_id{$self};
  $POE::Kernel::poe_kernel->refcount_decrement( $parent_id, 'postback' );
}

# Tune postbacks depending on variations in toolkit behavior.

BEGIN {
  # Tk blesses its callbacks internally, so we need to wrap our
  # blessed callbacks in unblessed ones.  Otherwise our postback's
  # DESTROY method probably won't be called.
  if (exists $INC{'Tk.pm'}) {
    eval 'sub USING_TK () { 1 }';
  }
  else {
    eval 'sub USING_TK () { 0 }';
  }
};

# Create a postback closure, maintaining referential integrity in the
# process.  The next step is to give it to something that expects to
# be handed a callback.

sub postback {
  my ($self, $event, @etc) = @_;
  my $id = $POE::Kernel::poe_kernel->ID_session_to_id(shift);

  my $postback = bless sub {
    $POE::Kernel::poe_kernel->post( $id, $event, [ @etc ], [ @_ ] );
    return 0;
  }, 'POE::NFA::Postback';

  $postback_parent_id{$postback} = $id;
  $POE::Kernel::poe_kernel->refcount_increment( $id, 'postback' );

  # Tk blesses its callbacks, so we must present one that isn't
  # blessed.  Otherwise Tk's blessing would divert our DESTROY call to
  # its own, and that's not right.

  return sub { $postback->(@_) } if USING_TK;
  return $postback;
}

# Create a synchronous callback closure.  The return value will be
# passed to whatever is handed the callback.
#
# TODO - Should callbacks hold reference counts like postbacks do?

sub callback {
  my ($self, $event, @etc) = @_;
  my $id = $POE::Kernel::poe_kernel->ID_session_to_id($self);

  my $callback = sub {
    return $POE::Kernel::poe_kernel->call( $id, $event, [ @etc ], [ @_ ] );
  };

  $callback;
}

#==============================================================================
# New methods.

sub goto_state {
  my ($self, $new_state, $entry_event, @entry_args) = @_;

  if (defined $self->[SELF_CURRENT]) {
    $POE::Kernel::poe_kernel->post(
      $self, NFA_EN_GOTO_STATE,
      $new_state, $entry_event, @entry_args
    );
  }
  else {
    $POE::Kernel::poe_kernel->call(
      $self, NFA_EN_GOTO_STATE,
      $new_state, $entry_event, @entry_args
    );
  }
}

sub stop {
  my $self = shift;
  $POE::Kernel::poe_kernel->post( $self, NFA_EN_STOP );
}

sub call_state {
  my ($self, $return_event, $new_state, $entry_event, @entry_args) = @_;
  $POE::Kernel::poe_kernel->post(
    $self, NFA_EN_PUSH_STATE,
    $return_event,
    $new_state, $entry_event, @entry_args
  );
}

sub return_state {
  my ($self, @entry_args) = @_;
  $POE::Kernel::poe_kernel->post( $self, NFA_EN_POP_STATE, @entry_args );
}

1;

__END__

=head1 NAME

POE::NFA - an event-driven state machine (nondeterministic finite automaton)

=head1 SYNOPSIS

  use POE::Kernel;
  use POE::NFA;
  use POE::Wheel::ReadLine;

  # Spawn an NFA and enter its initial state.
  POE::NFA->spawn(
    inline_states => {
      initial => {
        setup => \&setup_stuff,
      },
      state_login => {
        on_entry => \&login_prompt,
        on_input => \&save_login,
      },
      state_password => {
        on_entry => \&password_prompt,
        on_input => \&check_password,
      },
      state_cmd => {
        on_entry => \&command_prompt,
        on_input => \&handle_command,
      },
    },
  )->goto_state(initial => "setup");

  POE::Kernel->run();
  exit;

  sub setup_stuff {
    $_[RUNSTATE]{io} = POE::Wheel::ReadLine->new(
      InputEvent => 'on_input',
    );
    $_[MACHINE]->goto_state(state_login => "on_entry");
  }

  sub login_prompt { $_[RUNSTATE]{io}->get('Login: '); }

  sub save_login {
    $_[RUNSTATE]{login} = $_[ARG0];
    $_[MACHINE]->goto_state(state_password => "on_entry");
  }

  sub password_prompt { $_[RUNSTATE]{io}->get('Password: '); }

  sub check_password {
    if ($_[RUNSTATE]{login} eq $_[ARG0]) {
      $_[MACHINE]->goto_state(state_cmd => "on_entry");
    }
    else {
      $_[MACHINE]->goto_state(state_login => "on_entry");
    }
  }

  sub command_prompt { $_[RUNSTATE]{io}->get('Cmd: '); }

  sub handle_command {
    $_[RUNSTATE]{io}->put("  <<$_[ARG0]>>");
    if ($_[ARG0] =~ /^(?:quit|stop|exit|halt|bye)$/i) {
      $_[RUNSTATE]{io}->put('Bye!');
      $_[MACHINE]->stop();
    }
    else {
      $_[MACHINE]->goto_state(state_cmd => "on_entry");
    }
  }

=head1 DESCRIPTION

POE::NFA implements a different kind of POE session: A
non-deterministic finite automaton.  Let's break that down.

A finite automaton is a state machine with a bounded number of states
and transitions.  Technically, POE::NFA objects may modify themselves
at run time, so they aren't really "finite".  Run-time modification
isn't currently supported by the API, so plausible deniability is
maintained!

Deterministic state machines are ones where all possible transitions
are known at compile time.  POE::NFA is "non-deterministic" because
transitions may change based on run-time conditions.

But more simply, POE::NFA is like POE::Session but with banks of event
handlers that may be swapped according to the session's run-time state.
Consider the SYNOPSIS example, which has "on_entry" and "on_input"
handlers that do different things depending on the run-time state.
POE::Wheel::ReadLine throws "on_input", but different things happen
depending whether the session is in its "login", "password" or
"command" state.

POE::NFA borrows heavily from POE::Session, so this document will only
discuss the differences.  Please see L<POE::Session> for things which
are similar.

=head1 PUBLIC METHODS

This document mainly focuses on the differences from POE::Session.

=head2 get_current_state

Each machine state has a name.  get_current_state() returns the name
of the machine's current state.  get_current_state() is mainly used to
retrieve the state of some other machine.  It's easier (and faster) to
use C<$_[STATE]> in a machine's own event handlers.

=head2 get_runstate

get_runstate() returns the machine's current runstate.  Runstates are
equivalent to POE::Session HEAPs, so this method does pretty much the
same as POE::Session's get_heap().  It's easier (and faster) to use
C<$_[RUNSTATE]> in a machine's own event handlers, however.

=head2 spawn STATE_NAME => HANDLERS_HASHREF[, ...]

spawn() is POE::NFA's constructor.  The name reflects the idea that
new state machines are spawned like threads or processes rather than
instantiated like objects.

The machine itself is defined as a list of state names and hashes that
map events to handlers within each state.

  my %states = (
    state_1 => {
      event_1 => \&handler_1,
      event_2 => \&handler_2,
    },
    state_2 => {
      event_1 => \&handler_3,
      event_2 => \&handler_4,
    },
  );

A single event may be handled by many states.  The proper handler will
be called depending on the machine's current state.  For example, if
C<event_1> is dispatched while the machine is in C<state_2>, then
handler_3() will be called to handle the event.  The state -> event ->
handler map looks like this:

  $machine{state_2}{event_1} = \&handler_3;

Instead of C<inline_states>, C<object_states> or C<package_states> may
be used. These map the events of a state to an object or package method
respectively.

  object_states => {
    state_1 => [
      $object_1 => [qw(event_1 event_2)],
    ],
    state_2 => [
      $object_2 => {
        event_1 => method_1,
        event_2 => method_2,
      }
    ]
  }

In the example above, in the case of C<event_1> coming in while the machine
is in C<state_1>, method C<event_1> will be called on $object_1. If the
machine is in C<state_2>, method C<method_1> will be called on $object_2.

C<package_states> is very similar, but instead of using an $object, you
pass in a C<Package::Name>

The C<runstate> parameter allows C<RUNSTATE> to be initialized differently 
at instantiation time. C<RUNSTATE>, like heaps, are usually anonymous hashrefs, 
but C<runstate> may set them to be array references or even objects.

=head2 goto_state NEW_STATE[, ENTRY_EVENT[, EVENT_ARGS]]

goto_state() puts the machine into a new state.  If an ENTRY_EVENT is
specified, then that event will be dispatched after the machine enters
the new state.  EVENT_ARGS, if included, will be passed to the entry
event's handler via C<ARG0..$#_>.

  # Switch to the next state.
  $_[MACHINE]->goto_state( 'next_state' );

  # Switch to the next state, and call a specific entry point.
  $_[MACHINE]->goto_state( 'next_state', 'entry_event' );

  # Switch to the next state; call an entry point with some values.
  $_[MACHINE]->goto_state( 'next_state', 'entry_event', @parameters );

=head2 stop

stop() forces a machine to stop.  The machine will also stop
gracefully if it runs out of things to do, just like POE::Session.

stop() is heavy-handed.  It will force resources to be cleaned up.
However, circular references in the machine's C<RUNSTATE> are not
POE's responsibility and may cause memory leaks.

  $_[MACHINE]->stop();

=head2 call_state RETURN_EVENT, NEW_STATE[, ENTRY_EVENT[, EVENT_ARGS]]

call_state() is similar to goto_state(), but it pushes the current
state on a stack.  At some later point, a handler can call
return_state() to pop the call stack and return the machine to its old
state.  At that point, a C<RETURN_EVENT> will be posted to notify the
old state of the return.

  $machine->call_state( 'return_here', 'new_state', 'entry_event' );

As with goto_state(), C<ENTRY_EVENT> is the event that will be emitted
once the machine enters its new state.  C<ENTRY_ARGS> are parameters
passed to the C<ENTRY_EVENT> handler via C<ARG0..$#_>.

=head2 return_state [RETURN_ARGS]

return_state() returns to the most recent state in which call_state()
was invoked.  If the preceding call_state() included a return event
then its handler will be invoked along with some optional
C<RETURN_ARGS>.  The C<RETURN_ARGS> will be passed to the return
handler via C<ARG0..$#_>.

  $_[MACHINE]->return_state( 'success', @success_values );

=head2 Methods that match POE::Session

The following methods behave identically to the ones in POE::Session.

=over 2

=item ID

=item option

=item postback

=item callback

=back

=head2 About new() and create()

POE::NFA's constructor is spawn(), not new() or create().

=head1 PREDEFINED EVENT FIELDS

POE::NFA's predefined event fields are the same as POE::Session's with
the following three exceptions.

=head2 MACHINE

C<MACHINE> is equivalent to Session's C<SESSION> field.  It holds a
reference to the current state machine, and is useful for calling
its methods.

See POE::Session's C<SESSION> field for more information.

  $_[MACHINE]->goto_state( $next_state, $next_state_entry_event );

=head2 RUNSTATE

C<RUNSTATE> is equivalent to Session's C<HEAP> field.  It holds an
anonymous hash reference which POE is guaranteed not to touch.  Data
stored in C<RUNSTATE> will persist between handler invocations.

=head2 STATE

C<STATE> contains the name of the machine's current state.  It is not
equivalent to anything from POE::Session.

=head2 EVENT

C<EVENT> is equivalent to Session's C<STATE> field.  It holds the name
of the event which invoked the current handler.  See POE::Session's
C<STATE> field for more information.

=head1 PREDEFINED EVENT NAMES

POE::NFA defines four events of its own.  These events are used
internally and may not be overridden by application code.

See POE::Session's "PREDEFINED EVENT NAMES" section for more
information about other predefined events.

The events are: C<poe_nfa_goto_state>, C<poe_nfa_push_state>,
C<poe_nfa_pop_state>, C<poe_nfa_stop>.

Yes, all the internal events begin with "poe_nfa_".  More may be
forthcoming, but they will always begin the same way.  Therefore
please do not define events beginning with "poe_nfa_".

=head1 SEE ALSO

Many of POE::NFA's features are taken directly from POE::Session.
Please see L<POE::Session> for more information.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

See POE::Session's documentation.

POE::NFA is not as feature-complete as POE::Session.  Your feedback is
appreciated.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
