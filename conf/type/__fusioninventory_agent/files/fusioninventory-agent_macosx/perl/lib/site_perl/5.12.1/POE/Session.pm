package POE::Session;

use strict;

use vars qw($VERSION);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)

use Carp qw(carp croak);
use Errno;

sub SE_NAMESPACE    () { 0 }
sub SE_OPTIONS      () { 1 }
sub SE_STATES       () { 2 }

sub CREATE_ARGS     () { 'args' }
sub CREATE_OPTIONS  () { 'options' }
sub CREATE_INLINES  () { 'inline_states' }
sub CREATE_PACKAGES () { 'package_states' }
sub CREATE_OBJECTS  () { 'object_states' }
sub CREATE_HEAP     () { 'heap' }

sub OPT_TRACE       () { 'trace' }
sub OPT_DEBUG       () { 'debug' }
sub OPT_DEFAULT     () { 'default' }

sub EN_START        () { '_start' }
sub EN_DEFAULT      () { '_default' }
sub EN_SIGNAL       () { '_signal' }

#------------------------------------------------------------------------------
# Debugging flags for subsystems.  They're done as double evals here
# so that someone may define them before using POE::Session (or POE),
# and the pre-defined value will take precedence over the defaults
# here.

# Shorthand for defining an assert constant.

sub _define_assert {
  no strict 'refs';
  foreach my $name (@_) {

    local $^W = 0;

    next if defined *{"ASSERT_$name"}{CODE};
    if (defined *{"POE::Kernel::ASSERT_$name"}{CODE}) {
      eval(
        "sub ASSERT_$name () { " .
        *{"POE::Kernel::ASSERT_$name"}{CODE}->() .
        "}"
      );
      die if $@;
    }
    else {
      eval "sub ASSERT_$name () { ASSERT_DEFAULT }";
      die if $@;
    }
  }
}

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

  _define_assert("STATES");
  _define_trace("DESTROY");
}

#------------------------------------------------------------------------------
# Export constants into calling packages.  This is evil; perhaps
# EXPORT_OK instead?  The parameters NFA has in common with SESSION
# (and other sessions) must be kept at the same offsets as each-other.

sub OBJECT  () {  0 } # TODO - deprecate and replace with SELF
sub SESSION () {  1 }
sub KERNEL  () {  2 }
sub HEAP    () {  3 }
sub STATE   () {  4 } # TODO - deprecate and replace with EVENT
sub SENDER  () {  5 }
# NFA keeps its state in 6.  unused in session so that args match up.
sub CALLER_FILE () { 7 }
sub CALLER_LINE () { 8 }
sub CALLER_STATE () { 9 } # TODO - deprecate and replace with CALLER_EVENT
sub ARG0    () { 10 }
sub ARG1    () { 11 }
sub ARG2    () { 12 }
sub ARG3    () { 13 }
sub ARG4    () { 14 }
sub ARG5    () { 15 }
sub ARG6    () { 16 }
sub ARG7    () { 17 }
sub ARG8    () { 18 }
sub ARG9    () { 19 }

sub import {
  my $package = caller();
  no strict 'refs';
  *{ $package . '::OBJECT'  } = \&OBJECT;
  *{ $package . '::SESSION' } = \&SESSION;
  *{ $package . '::KERNEL'  } = \&KERNEL;
  *{ $package . '::HEAP'    } = \&HEAP;
  *{ $package . '::STATE'   } = \&STATE;
  *{ $package . '::SENDER'  } = \&SENDER;
  *{ $package . '::ARG0'    } = \&ARG0;
  *{ $package . '::ARG1'    } = \&ARG1;
  *{ $package . '::ARG2'    } = \&ARG2;
  *{ $package . '::ARG3'    } = \&ARG3;
  *{ $package . '::ARG4'    } = \&ARG4;
  *{ $package . '::ARG5'    } = \&ARG5;
  *{ $package . '::ARG6'    } = \&ARG6;
  *{ $package . '::ARG7'    } = \&ARG7;
  *{ $package . '::ARG8'    } = \&ARG8;
  *{ $package . '::ARG9'    } = \&ARG9;
  *{ $package . '::CALLER_FILE' } = \&CALLER_FILE;
  *{ $package . '::CALLER_LINE' } = \&CALLER_LINE;
  *{ $package . '::CALLER_STATE' } = \&CALLER_STATE;
}

sub instantiate {
  my $type = shift;

  croak "$type requires a working Kernel"
    unless defined $POE::Kernel::poe_kernel;

  my $self =
    bless [ { }, # SE_NAMESPACE
            { }, # SE_OPTIONS
            { }, # SE_STATES
          ], $type;

  if (ASSERT_STATES) {
    $self->[SE_OPTIONS]->{+OPT_DEFAULT} = 1;
  }

  return $self;
}

sub try_alloc {
  my ($self, @args) = @_;
  # Verify that the session has a special start state, otherwise how
  # do we know what to do?  Don't even bother registering the session
  # if the start state doesn't exist.

  if (exists $self->[SE_STATES]->{+EN_START}) {
    $POE::Kernel::poe_kernel->session_alloc($self, @args);
  }
  else {
    carp( "discarding session ",
          $POE::Kernel::poe_kernel->ID_session_to_id($self),
          " - no '_start' state"
        );
    $self = undef;
  }

  $self;
}

#------------------------------------------------------------------------------
# New style constructor.  This uses less DWIM and more DWIS, and it's
# more comfortable for some folks; especially the ones who don't quite
# know WTM.

sub create {
  my ($type, @params) = @_;
  my @args;

  # We treat the parameter list strictly as a hash.  Rather than dying
  # here with a Perl error, we'll catch it and blame it on the user.

  if (@params & 1) {
    croak "odd number of events/handlers (missing one or the other?)";
  }
  my %params = @params;

  my $self = $type->instantiate(\%params);

  # Process _start arguments.  We try to do the right things with what
  # we're given.  If the arguments are a list reference, map its items
  # to ARG0..ARGn; otherwise make whatever the heck it is be ARG0.

  if (exists $params{+CREATE_ARGS}) {
    if (ref($params{+CREATE_ARGS}) eq 'ARRAY') {
      push @args, @{$params{+CREATE_ARGS}};
    }
    else {
      push @args, $params{+CREATE_ARGS};
    }
    delete $params{+CREATE_ARGS};
  }

  # Process session options here.  Several options may be set.

  if (exists $params{+CREATE_OPTIONS}) {
    if (ref($params{+CREATE_OPTIONS}) eq 'HASH') {
      $self->[SE_OPTIONS] = $params{+CREATE_OPTIONS};
    }
    else {
      croak "options for $type constructor is expected to be a HASH reference";
    }
    delete $params{+CREATE_OPTIONS};
  }

  # Get down to the business of defining states.

  while (my ($param_name, $param_value) = each %params) {

    # Inline states are expected to be state-name/coderef pairs.

    if ($param_name eq CREATE_INLINES) {
      croak "$param_name does not refer to a hash"
        unless (ref($param_value) eq 'HASH');

      while (my ($state, $handler) = each(%$param_value)) {
        croak "inline state for '$state' needs a CODE reference"
          unless (ref($handler) eq 'CODE');
        $self->_register_state($state, $handler);
      }
    }

    # Package states are expected to be package-name/list-or-hashref
    # pairs.  If the second part of the pair is a arrayref, then the
    # package methods are expected to be named after the states
    # they'll handle.  If it's a hashref, then the keys are state
    # names and the values are package methods that implement them.

    elsif ($param_name eq CREATE_PACKAGES) {
      croak "$param_name does not refer to an array"
        unless (ref($param_value) eq 'ARRAY');
      croak "the array for $param_name has an odd number of elements"
        if (@$param_value & 1);

      # Copy the parameters so they aren't destroyed.
      my @param_value = @$param_value;
      while (my ($package, $handlers) = splice(@param_value, 0, 2)) {

        # TODO What do we do if the package name has some sort of
        # blessing?  Do we use the blessed thingy's package, or do we
        # maybe complain because the user might have wanted to make
        # object states instead?

        # An array of handlers.  The array's items are passed through
        # as both state names and package method names.

        if (ref($handlers) eq 'ARRAY') {
          foreach my $method (@$handlers) {
            $self->_register_state($method, $package, $method);
          }
        }

        # A hash of handlers.  Hash keys are state names; values are
        # package methods to implement them.

        elsif (ref($handlers) eq 'HASH') {
          while (my ($state, $method) = each %$handlers) {
            $self->_register_state($state, $package, $method);
          }
        }

        else {
          croak( "states for package '$package' " .
                 "need to be a hash or array ref"
               );
        }
      }
    }

    # Object states are expected to be object-reference/
    # list-or-hashref pairs.  They must be passed to &create in a list
    # reference instead of a hash reference because making object
    # references into hash keys loses their blessings.

    elsif ($param_name eq CREATE_OBJECTS) {
      croak "$param_name does not refer to an array"
        unless (ref($param_value) eq 'ARRAY');
      croak "the array for $param_name has an odd number of elements"
        if (@$param_value & 1);

      # Copy the parameters so they aren't destroyed.
      my @param_value = @$param_value;
      while (@param_value) {
        my ($object, $handlers) = splice(@param_value, 0, 2);

        # Verify that the object is an object.  This may catch simple
        # mistakes; or it may be overkill since it already checks that
        # $param_value is a arrayref.

        carp "'$object' is not an object" unless ref($object);

        # An array of handlers.  The array's items are passed through
        # as both state names and object method names.

        if (ref($handlers) eq 'ARRAY') {
          foreach my $method (@$handlers) {
            $self->_register_state($method, $object, $method);
          }
        }

        # A hash of handlers.  Hash keys are state names; values are
        # package methods to implement them.

        elsif (ref($handlers) eq 'HASH') {
          while (my ($state, $method) = each %$handlers) {
            $self->_register_state($state, $object, $method);
          }
        }

        else {
          croak "states for object '$object' need to be a hash or array ref";
        }

      }
    }

    # Import an external heap.  This is a convenience, since it
    # eliminates the need to connect _start options to heap values.

    elsif ($param_name eq CREATE_HEAP) {
      $self->[SE_NAMESPACE] = $param_value;
    }

    else {
      croak "unknown $type parameter: $param_name";
    }
  }

  return $self->try_alloc(@args);
}

#------------------------------------------------------------------------------

sub DESTROY {
  my $self = shift;

  # Session's data structures are destroyed through Perl's usual
  # garbage collection.  TRACE_DESTROY here just shows what's in the
  # session before the destruction finishes.

  TRACE_DESTROY and do {
    require Data::Dumper;
    POE::Kernel::_warn(
      "----- Session $self Leak Check -----\n",
      "-- Namespace (HEAP):\n",
      Data::Dumper::Dumper($self->[SE_NAMESPACE]),
      "-- Options:\n",
    );
    foreach (sort keys (%{$self->[SE_OPTIONS]})) {
      POE::Kernel::_warn("   $_ = ", $self->[SE_OPTIONS]->{$_}, "\n");
    }
    POE::Kernel::_warn("-- States:\n");
    foreach (sort keys (%{$self->[SE_STATES]})) {
      POE::Kernel::_warn("   $_ = ", $self->[SE_STATES]->{$_}, "\n");
    }
  };
}

#------------------------------------------------------------------------------

sub _invoke_state {
  my ($self, $source_session, $state, $etc, $file, $line, $fromstate) = @_;

  # Trace the state invocation if tracing is enabled.

  if ($self->[SE_OPTIONS]->{+OPT_TRACE}) {
    POE::Kernel::_warn(
      $POE::Kernel::poe_kernel->ID_session_to_id($self),
      " -> $state (from $file at $line)\n"
    );
  }

  # The desired destination state doesn't exist in this session.
  # Attempt to redirect the state transition to _default.

  unless (exists $self->[SE_STATES]->{$state}) {

    # There's no _default either; redirection's not happening today.
    # Drop the state transition event on the floor, and optionally
    # make some noise about it.

    unless (exists $self->[SE_STATES]->{+EN_DEFAULT}) {
      $! = exists &Errno::ENOSYS ? &Errno::ENOSYS : &Errno::EIO;
      if ($self->[SE_OPTIONS]->{+OPT_DEFAULT} and $state ne EN_SIGNAL) {
        my $loggable_self =
          $POE::Kernel::poe_kernel->_data_alias_loggable($self);
        POE::Kernel::_warn(
          "a '$state' event was sent from $file at $line to $loggable_self ",
          "but $loggable_self has neither a handler for it ",
          "nor one for _default\n"
        );
      }
      return undef;
    }

    # If we get this far, then there's a _default state to redirect
    # the transition to.  Trace the redirection.

    if ($self->[SE_OPTIONS]->{+OPT_TRACE}) {
      POE::Kernel::_warn(
        $POE::Kernel::poe_kernel->ID_session_to_id($self),
        " -> $state redirected to _default\n"
      );
    }

    # Transmogrify the original state transition into a corresponding
    # _default invocation.  ARG1 is copied from $etc so it can't be
    # altered from a distance.

    $etc   = [ $state, [@$etc] ];
    $state = EN_DEFAULT;
  }

  # If we get this far, then the state can be invoked.  So invoke it
  # already!

  # Inline states are invoked this way.

  if (ref($self->[SE_STATES]->{$state}) eq 'CODE') {
    return $self->[SE_STATES]->{$state}->
      ( undef,                          # object
        $self,                          # session
        $POE::Kernel::poe_kernel,       # kernel
        $self->[SE_NAMESPACE],          # heap
        $state,                         # state
        $source_session,                # sender
        undef,                          # unused #6
        $file,                          # caller file name
        $line,                          # caller file line
        $fromstate,                     # caller state
        @$etc                           # args
      );
  }

  # Package and object states are invoked this way.

  my ($object, $method) = @{$self->[SE_STATES]->{$state}};
  return
    $object->$method                    # package/object (implied)
      ( $self,                          # session
        $POE::Kernel::poe_kernel,       # kernel
        $self->[SE_NAMESPACE],          # heap
        $state,                         # state
        $source_session,                # sender
        undef,                          # unused #6
        $file,                          # caller file name
        $line,                          # caller file line
    $fromstate,            # caller state
        @$etc                           # args
      );
}

#------------------------------------------------------------------------------
# Add, remove or replace states in the session.

sub _register_state {
  my ($self, $name, $handler, $method) = @_;
  $method = $name unless defined $method;

  # Deprecate _signal.
  # RC 2004-09-07 - Decided to leave this in because it blames
  # problems with _signal on the user for using it.  It should
  # probably go away after a little while, but not during the other
  # deprecations.

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
      carp( "redefining handler for event($name) for session(",
            $POE::Kernel::poe_kernel->ID_session_to_id($self), ")"
          )
        if ( $self->[SE_OPTIONS]->{+OPT_DEBUG} &&
             (exists $self->[SE_STATES]->{$name})
           );
      $self->[SE_STATES]->{$name} = $handler;
    }

    # Non-coderef handlers may be package or object states.  See if
    # the method belongs to the handler.

    elsif ($handler->can($method)) {
      carp( "redefining handler for event($name) for session(",
            $POE::Kernel::poe_kernel->ID_session_to_id($self), ")"
          )
        if ( $self->[SE_OPTIONS]->{+OPT_DEBUG} &&
             (exists $self->[SE_STATES]->{$name})
           );
      $self->[SE_STATES]->{$name} = [ $handler, $method ];
    }

    # Something's wrong.  This code also seems wrong, since
    # ref($handler) can't be 'CODE'.

    else {
      if ( (ref($handler) eq 'CODE') and
           $self->[SE_OPTIONS]->{+OPT_TRACE}
         ) {
        carp( $POE::Kernel::poe_kernel->ID_session_to_id($self),
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
    delete $self->[SE_STATES]->{$name};
  }
}

#------------------------------------------------------------------------------
# Return the session's ID.  This is a thunk into POE::Kernel, where
# the session ID really lies.

sub ID {
  $POE::Kernel::poe_kernel->ID_session_to_id(shift);
}

#------------------------------------------------------------------------------
# Set or fetch session options.

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

      $return_values{$flag} = $self->[SE_OPTIONS]->{$flag};
      $self->[SE_OPTIONS]->{$flag} = $value;
    }

    # Remove the option if the value is undefined.

    else {
      $return_values{$flag} = delete $self->[SE_OPTIONS]->{$flag};
    }
  }

  # If only one option is left, then there's no value to set, so we
  # fetch its value.

  if (@_) {
    my $flag = lc(shift);
    $return_values{$flag} =
      ( exists($self->[SE_OPTIONS]->{$flag})
        ? $self->[SE_OPTIONS]->{$flag}
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

# Fetch the session's heap.  In rare cases, libraries may need to
# break encapsulation this way, probably also using
# $kernel->get_current_session as an accessory to the crime.

sub get_heap {
  my $self = shift;
  return $self->[SE_NAMESPACE];
}

#------------------------------------------------------------------------------
# Create an anonymous sub that, when called, posts an event back to a
# session.  This maps postback references (stringified; blessing, and
# thus refcount, removed) to parent session IDs.  Members are set when
# postbacks are created, and postbacks' DESTROY methods use it to
# perform the necessary cleanup when they go away.  Thanks to njt for
# steering me right on this one.

my %anonevent_parent_id;
my %anonevent_weakened;

# I assume that when the postback owner loses all reference to it,
# they are done posting things back to us.  That's when the postback's
# DESTROY is triggered, and referential integrity is maintained.

sub POE::Session::AnonEvent::DESTROY {
  my $self = shift;
  my $parent_id = delete $anonevent_parent_id{$self};
  unless (delete $anonevent_weakened{$self}) {
    $POE::Kernel::poe_kernel->refcount_decrement( $parent_id, 'anon_event' );
  }
}

sub POE::Session::AnonEvent::weaken {
  my $self = shift;
  unless ($anonevent_weakened{$self}) {
    my $parent_id = $anonevent_parent_id{$self};
    $POE::Kernel::poe_kernel->refcount_decrement( $parent_id, 'anon_event' );
    $anonevent_weakened{$self} = 1;
  }
  return $self;
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
  my $id = $POE::Kernel::poe_kernel->ID_session_to_id($self);

  my $postback = bless sub {
    $POE::Kernel::poe_kernel->post( $id, $event, [ @etc ], [ @_ ] );
    return 0;
  }, 'POE::Session::AnonEvent';

  $anonevent_parent_id{$postback} = $id;
  $POE::Kernel::poe_kernel->refcount_increment( $id, 'anon_event' );

  # Tk blesses its callbacks, so we must present one that isn't
  # blessed.  Otherwise Tk's blessing would divert our DESTROY call to
  # its own, and that's not right.

  return sub { $postback->(@_) } if USING_TK;
  return $postback;
}

# Create a synchronous callback closure.  The return value will be
# passed to whatever is handed the callback.

sub callback {
  my ($self, $event, @etc) = @_;
  my $id = $POE::Kernel::poe_kernel->ID_session_to_id($self);

  my $callback = bless sub {
    $POE::Kernel::poe_kernel->call( $id, $event, [ @etc ], [ @_ ] );
  }, 'POE::Session::AnonEvent';

  $anonevent_parent_id{$callback} = $id;
  $POE::Kernel::poe_kernel->refcount_increment( $id, 'anon_event' );

  # Tk blesses its callbacks, so we must present one that isn't
  # blessed.  Otherwise Tk's blessing would divert our DESTROY call to
  # its own, and that's not right.

  return sub { $callback->(@_) } if USING_TK;
  return $callback;
}

1;

__END__

=head1 NAME

POE::Session - a generic event-driven task

=head1 SYNOPSIS

  use POE; # auto-includes POE::Kernel and POE::Session

  POE::Session->create(
    inline_states => {
      _start => sub { $_[KERNEL]->yield("next") },
      next   => sub {
        print "tick...\n";
        $_[KERNEL]->delay(next => 1);
      },
    },
  );

  POE::Kernel->run();
  exit;

POE::Session can also dispatch to object and class methods through
L</object_states> and L</package_states> callbacks.

=head1 DESCRIPTION

POE::Session and its subclasses translate events from POE::Kernel's
generic dispatcher into the particular calling conventions suitable for
application code.  In design pattern parlance, POE::Session classes
are adapters between L<POE::Kernel> and application code.

The L<sessions|POE::Kernel/Sessions> that POE::Kernel manages are more
like generic task structures.  Unfortunately these two disparate
concepts have virtually identical names.

=head2 A note on nomenclature

This documentation will refer to event handlers as "states" in certain
unavoidable situations.  Sessions were originally meant to be
event-driven state machines, but their purposes evolved over time.
Some of the legacy vocabulary lives on in the API for backward
compatibility, however.

Confusingly, L<POE::NFA> is a class for implementing actual
event-driven state machines.  Its documentation uses "state" in the
proper sense.

=head1 USING POE::Session

POE::Session has two main purposes.  First, it maps event names to the
code that will handle them.  Second, it maps a consistent event
dispatch interface to those handlers.

Consider the L</SYNOPSIS> for example.  A POE::Session instance is
created with two C<inline_states>, each mapping an event name
("_start" and "next") to an inline subroutine.  POE::Session ensures
that L</$_[KERNEL]> and so on are meaningful within an event handler.

Event handlers may also be object or class methods, using
L</object_states> and L</package_states> respectively.  The create()
syntax is different than for C<inline_states>, but the calling
convention is nearly identical.

Notice that the created POE::Session object has not been saved to a
variable.  The new POE::Session object gives itself to POE::Kernel,
which then manages it and all the resources it uses.

It's possible to keep references to new POE::Session objects, but it's
not usually necessary.  If an application is not careful about
cleaning up these references you will create circular references,
which will leak memory when POE::Kernel would normally destroy the
POE::Session object.  It is recommended that you keep the session's
L<ID> instead.

=head2 POE::Session's Calling Convention

The biggest syntactical hurdle most people have with POE is
POE::Session's unconventional calling convention.  For example:

  sub handle_event {
    my ($kernel, $heap, $parameter) = @_[KERNEL, HEAP, ARG0];
    ...;
  }

Or the use of C<$_[KERNEL]>, C<$_[HEAP]> and C<$_[ARG0]> inline,
as is done in most examples.

What's going on here is rather basic.  Perl passes parameters into
subroutines or methods using the @_ array.  C<KERNEL>, C<HEAP>,
C<ARG0> and others are constants exported by POE::Session (which is
included for free when a program uses POE).

So C<$_[KERNEL]> is an event handler's KERNELth parameter.
C<@_[HEAP, ARG0]> is a slice of @_ containing the HEAPth and ARG0th
parameters.

While this looks odd, it's perfectly plain and legal Perl syntax.  POE
uses it for a few reasons:

=over 4

=item 1

In the common case, passing parameters in C<@_> is faster than passing
hash or array references and then dereferencing them in the handler.

=item 2

Typos in hash-based parameter lists are either subtle run-time
errors or requires constant run-time checking.  Constants are either
known at compile time, or are clear compile-time errors.

=item 3

Referencing C<@_> offsets by constants allows parameters to move
in the future without breaking application code.

=item 4

Most event handlers don't need all of C<@_>.  Slices allow handlers to
use only the parameters they're interested in.

=back

=head2 POE::Session Parameters

Event handlers receive most of their run-time context in up to nine
callback parameters.  POE::Kernel provides many of them.

=head3 $_[OBJECT]

C<$_[OBJECT]> is $self for event handlers that are an object method.  It is
the class (package) name for class-based event handlers.  It is undef
for plain coderef callbacks, which have no special C<$self>-ish value.

C<OBJECT> is always zero, since C<$_[0]> is always C<$self> or C<$class>
in object and class methods.  Coderef handlers are called with
an C<undef> placeholder in C<$_[0]> so that the other offsets remain valid.

It's often useful for method-based event handlers to call other
methods in the same object.  C<$_[OBJECT]> helps this happen.

  sub ui_update_everything {
    my $self = $_[OBJECT];
    $self->update_menu();
    $self->update_main_window();
    $self->update_status_line();
  }

You may also use method inheritance.  Here we invoke
$self->a_method(@_).  Since Perl's C<<->>> operator unshifts $self
onto the beginning of @_, we must first shift a copy off to maintain
POE's parameter offsets:

  sub a_method {
    my $self = shift;
    $self->SUPER::a_method( @_ );
    # ... more work ...
  }

=head3 $_[SESSION]

C<$_[SESSION]> is a reference to the current session object.  This lets event
handlers access their session's methods.  Programs may also compare
C<$_[SESSION]> to C<$_[SENDER]> to verify that intra-session events did not
come from other sessions.

C<$_[SESSION]> may also be used as the destination for intra-session
L<post()|POE::Kernel/post> and L<call()|POE::Kernel/call>.  L<yield()|POE::Kernel/yield> is marginally more convenient and
efficient than C<post($_[SESSION], ...)> however.

It is bad form to access another session directly.  The recommended
approach is to manipulate a session through an event handler.

  sub enable_trace {
    my $previous_trace = $_[SESSION]->option( trace => 1 );
    my $id = $_[SESSION]->ID;
    if ($previous_trace) {
      print "Session $id: dispatch trace is still on.\n";
    }
    else {
      print "Session $id: dispatch trace has been enabled.\n";
    }
  }

=head3 $_[KERNEL]

The KERNELth parameter is always a reference to the application's
singleton L<POE::Kernel> instance.  It is most often used to call
POE::Kernel methods from event handlers.

  # Set a 10-second timer.
  $_[KERNEL]->delay( time_is_up => 10 );

=head3 $_[HEAP]

Every POE::Session object contains its own variable namespace known as
the session's C<HEAP>.  It is modeled and named after process memory
heaps (not priority heaps).  Heaps are by default anonymous hash
references, but they may be initialized in L<create()|/create> to be almost
anything.  POE::Session itself never uses C<$_[HEAP]>, although some POE
components do.

Heaps do not overlap between sessions, although create()'s "heap"
parameter can be used to make this happen.

These two handlers time the lifespan of a session:

  sub _start_handler {
    $_[HEAP]{ts_start} = time();
  }

  sub _stop_handler {
    my $time_elapsed = time() - $_[HEAP]{ts_start};
    print "Session ", $_[SESSION]->ID, " elapsed seconds: $elapsed\n";
  }

=head3 $_[STATE]

The STATEth handler parameter contains the name of the event being
dispatched in the current callback.  This can be important since the
event and handler names may significantly differ.  Also, a single
handler may be assigned to more than one event.

  POE::Session->create(
    inline_states => {
      one => \&some_handler,
      two => \&some_handler,
      six => \&some_handler,
      ten => \&some_handler,
      _start => sub {
        $_[KERNEL]->yield($_) for qw(one two six ten);
      }
    }
  );

  sub some_handler {
    print(
      "Session ", $_[SESSION]->ID,
      ": some_handler() handled event $_[STATE]\n"
    );
  }

It should be noted however that having event names and handlers names match
will make your code easier to navigate.

=head3 $_[SENDER]

Events must come from somewhere.  C<$_[SENDER]> contains the currently
dispatched event's source.

C<$_[SENDER]> is commonly used as a return address for responses.  It may
also be compared against C<$_[KERNEL]> to verify that timers and other
POE::Kernel-generated events were not spoofed.

This C<echo_handler()> reponds to the sender with an "echo" event that
contains all the parameters it received.  It avoids a feedback loop by
ensuring the sender session and event (STATE) are not identical to the
current ones.

  sub echo_handler {
    return if $_[SENDER] == $_[SESSION] and $_[STATE] eq "echo";
    $_[KERNEL]->post( $_[SENDER], "echo", @_[ARG0..$#_] );
  }

TODO - Document which events should have $_[SENDER] == $_[KERNEL].
Probably in POE::Kernel.

=head3 $_[CALLER_FILE], $_[CALLER_LINE] and $_[CALLER_STATE]

These parameters are a form of caller(), but they describe where the
currently dispatched event originated.  CALLER_FILE and CALLER_LINE
are fairly plain.  CALLER_STATE contains the name of the event that
was being handled when the event was created, or when the event
watcher that ultimately created the event was registered.

TODO - Rename SENDER_FILE, SENDER_LINE, SENDER_STATE?

=head3 @_[ARG0..ARG9] or @_[ARG0..$#_]

Parameters $_[ARG0] through the end of @_ contain parameters provided
by application code, event watchers, or higher-level libraries.  These
parameters are guaranteed to be at the end of @_ so that @_[ARG0..$#_]
will always catch them all.

$#_ is the index of the last value in @_.  Blame Perl if it looks odd.
It's merely the $#array syntax where the array name is an underscore.

Consider

  $_[KERNEL]->yield( ev_whatever => qw( zero one two three ) );

The handler for ev_whatever will be called with "zero" in $_[ARG0],
"one" in $_[ARG1], and so on.  @_[ARG0..$#_] will contain all four
words.

  sub ev_whatever {
    $_[OBJECT]->whatever( @_[ARG0..$#_] );
  }

=head2 Using POE::Session With Objects

One session may handle events across many objects.  Or looking at it
the other way, multiple objects can be combined into one session.  And
what the heck---go ahead and mix in some inline code as well.

  POE::Session->create(
    object_states => [
      $object_1 => { event_1a => "method_1a" },
      $object_2 => { event_2a => "method_2a" },
    ],
    inline_states => {
      event_3 => \&piece_of_code,
    },
  );

However only one handler may be assigned to a given event name.
Duplicates will overwrite earlier ones.

event_1a is handled by calling C<< $object_1->method_1a(...) >>.  C<$_[OBJECT]>
is C<$object_1> in this case.  C<$_[HEAP]> belongs to the session, which
means anything stored there will be available to any other event
handler regardless of the object.

event_2a is handled by calling C<< $object_2->method_2a(...) >>.  In this
case C<$_[OBJECT]> is $object_2.  C<$_[HEAP]> is the same anonymous hashref
that was passed to the event_1a handler, though.  The methods are resolved
when the event is handled (late-binding).

event_3 is handled by calling C<piece_of_code(...)>.  C<$_[OBJECT]> is C<undef>
here because there's no object.  And once again, C<$_[HEAP]> is the same
shared hashref that the handlers for event_1a and event_2a saw.

Interestingly, there's no technical reason that a
single object can't handle events from more than one session:

  for (1..2) {
    POE::Session->create(
      object_states => [
        $object_4 => { event_4 => "method_4" },
      ]
    );
  }

Now C<< $object_4->method_4(...) >> may be called to handle events from one of
two sessions.  In both cases, C<$_[OBJECT]> will be C<$object_4>, but
C<$_[HEAP]> will hold data for a particular session.

The same goes for inline states.  One subroutine may handle events
from many sessions.  C<$_[SESSION]> and C<$_[HEAP]> can be used within the
handler to easily access the context of the session in which the event
is being handled.

=head1 PUBLIC METHODS

POE::Session has just a few public methods.

=head2 create LOTS_OF_STUFF

C<create()> starts a new session running.  It returns a new POE::Session
object upon success, but most applications won't need to save it.

C<create()> invokes the newly started session's _start event handler
before returning.

C<create()> also passes the new POE::Session object to L<POE::Kernel>.
POE's kernel holds onto the object in order to dispatch events to it.
POE::Kernel will release the object when it detects the object has
become moribund.  This should cause Perl to destroy the object if
application code has not saved a copy of it.

C<create()> accepts several named parameters, most of which are optional.
Note however that the parameters are not part of a hashref.

TODO - Is it time to bring new() back as a synonym for create()?
TODO PG - NO!  IMHO ->new implies simply creating the object, and 
TODO that you have to hold onto the object.  ->create implies other actions
TODO are happening, and that you don't want to hold on to it.

TODO - Provide forward-compatible "handler" options and methods as
synonyms for the "state" versions currently supported?
TODO PG - No, that's for 1.01

TODO - Add a "class_handlers" as a synonym for "package_handlers"?
TODO PG - Maybe. However, to many synonyms can be a pain for an API.  

TODO - The above TODOs may be summarized: "deprecate old language"?
TODO PG - Oh, you are thinking of deprecating the old language... erm... no?



TODO PG - I notice these =head3 are in alphabetical order.  I think
TODO all the *_states options should be together.  Followed by heap, args,
TODO options


=head3 args => ARRAYREF

The C<args> parameter accepts a reference to a list of parameters that
will be passed to the session's _start event handler in C<@_> positions
C<ARG0> through C<$#_> (the end of C<@_>).

This example would print "arg0 arg1 etc.":

  POE::Session->create(
    inline_states => {
      _start => sub {
        print "Session started with arguments: @_[ARG0..$#_]\n";
      },
    },
    args => [ 'arg0', 'arg1', 'etc.' ],
  );

=head3 heap => ANYTHING

The C<heap> parameter allows a session's heap to be initialized
differently at instantiation time.  Heaps are usually anonymous
hashrefs, but C<heap> may set them to be array references or even
objects.

This example prints "tree":

  POE::Session->create(
    inline_states => {
      _start => sub {
        print "Slot 0 = $_[HEAP][0]\n";
      },
    },
    heap => [ 'tree', 'bear' ],
  );

Be careful when initializing the heap to be something that doesn't behave
like a hashref.  Some libraries assume hashref heap semantics, and
they will fail if the heap doesn't work that way.

=head3 inline_states => HASHREF

C<inline_states> maps events names to the subroutines that will handle
them.  Its value is a hashref that maps event names to the coderefs of
their corresponding handlers:

  POE::Session->create(
    inline_states => {
      _start => sub {
        print "arg0=$_[ARG0], arg1=$_[ARG1], etc.=$_[ARG2]\n";
      },
      _stop  => \&stop_handler,
    },
    args => [qw( arg0 arg1 etc. )],
  );

The term "inline" comes from the fact that coderefs can be inlined
anonymous subroutines.

Be very careful with closures, however.  L</Beware circular references>.

=head3 object_states => ARRAYREF

C<object_states> associates one or more objects to a session and maps
event names to the object methods that will handle them.  It's value
is an C<ARRAYREF>; C<HASHREFs> would stringify the objects, ruining them
for method invocation.

Here _start is handled by C<< $object->_session_start() >> and _stop triggers
C<< $object->_session_stop() >>:

  POE::Session->create(
    object_states => [
      $object => {
        _start => '_session_start',
        _stop  => '_session_stop',
      }
    ]
  );

POE::Session also supports a short form where the event and method
names are identical.  Here _start invokes $object->_start(), and _stop
triggers $object->_stop():

  POE::Session->create(
    object_states => [
      $object => [ '_start', '_stop' ],
    ]
  );

Methods are verified when the session is created, but also resolved when the
handler is called (late binding).  Most of the time, a method won't change.
But in some circumstance, such as dynamic inheritance, a method could
resolve to a different subroutine.

=head3 options => HASHREF

POE::Session sessions support a small number of options, which may be
initially set with the C<option> constructor parameter and changed at
run time with the C<option()|/option> mehtod.

C<option> takes a hashref with option =E<gt> value pairs:

  POE::Session->create(
    ... set up handlers ...,
    options => { trace => 1, debug => 1 },
  );

This is equivalent to the previous example:

  POE::Session->create(
    ... set up handlers ...,
  )->option( trace => 1, debug => 1 );

The supported options and values are documented with the C<option()|/option>
method.

=head3 package_states => ARRAYREF

C<package_states> associates one or more classes to a session and maps
event names to the class methods that will handle them.  Its function
is analogous to C<object_states>, but package names are specified
rather than objects.

In fact, the following documentation is a copy of the C<object_states>
description with some word substitutions.

The value for C<package_states> is an B<ARRAYREF> to be consistent
with C<object_states>, even though class names (also known as package names) are
already strings, so it's not necessary to avoid stringifying them.

Here _start is handled by C<< $class_name->_session_start() >> and _stop
triggers C<< $class_name->_session_stop() >>:

  POE::Session->create(
    package_states => [
      $class_name => {
        _start => '_session_start',
        _stop  => '_session_stop',
      }
    ]
  );

POE::Session also supports a short form where the event and method
names are identical.  Here _start invokes C<< $class_name->_start() >>, and
_stop triggers C<< $class_name->_stop() >>:

  POE::Session->create(
    package_states => [
      $class_name => [ '_start', '_stop' ],
    ]
  );

=head2 ID

C<ID()> returns the session instance's unique identifier.  This is an
integer that starts at 1 and counts up forever, or until the number
wraps around.

It's theoretically possible that a session ID will not be unique, but
this requires at least 4.29 billion sessions to be created within a
program's lifespan.  POE guarantees that no two sessions will have the
same ID at the same time, however;  your computer doesn't have enough memory
to store 4.29 billion session objects.

A session's ID is unique within a running process, but multiple
processes are likely to have the same session IDs.  If a global ID is
required, it will need to include both C<< $_[KERNEL]->ID >> and
C<< $_[SESSION]->ID >>.

=head2 option OPTION_NAME [, OPTION_VALUE [, OPTION_NAME, OPTION_VALUE]... ]

C<option()> sets and/or retrieves the values of various session options.
The options in question are implemented by POE::Session and do not
have any special meaning anywhere else.

It may be called with a single OPTION_NAME to retrieve the value of
that option.

  my $trace_value = $_[SESSION]->option('trace');

C<option()> sets an option's value when called with a single OPTION_NAME,
OPTION_VALUE pair.  In this case, C<option()> returns the option's
previous value.

  my $previous_trace = $_[SESSION]->option(trace => 1);

C<option()> may also be used to set the values of multiple options at
once.  In this case, C<option()> returns all the specified options'
previous values in an anonymous hashref:

  my $previous_values = $_[SESSION]->option(
    trace => 1,
    debug => 1,
  );

  print "Previous option values:\n";
  while (my ($option, $old_value) = each %$previous_values) {
    print "  $option = $old_value\n";
  }

POE::Session currently supports three options:

=head3 The "debug" option.

The "debug" option is intended to enable additional warnings when
strange things are afoot within POE::Session.  At this time, there is
only one additional warning:

=over 4

=item * 

Redefining an event handler does not usually cause a warning, but it
will when the "debug" option is set.

=back

=head3 The "default" option.

Enabling the "default" option causes unknown events to become
warnings, if there is no _default handler to catch them.

The class-level C<POE::Session::ASSERT_STATES> flag is implemented by
enabling the "default" option on all new sessions.

=head3 The "trace" option.

Turn on the "trace" option to dump a log of all the events dispatched
to a particular session.  This is a session-specific trace option that
allows individual sessions to be debugged.

Session-level tracing also indicates when events are redirected to
_default.  This can be used to discover event naming errors.

=head3 User-defined options.

C<option()> does not verify whether OPTION_NAMEs are known, so C<option()>
may be used to store and retrieve user-defined information.

Choose option names with caution.  There is no established convention
to avoid namespace collisions between user-defined options and future
internal options.

=head2 postback EVENT_NAME, EVENT_PARAMETERS

C<postback()> manufactures callbacks that post POE events.  It returns an
anonymous code reference that will post EVENT_NAME to the target
session, with optional EVENT_PARAMETERS in an array reference in ARG0.
Parameters passed to the callback will be sent in an array reference
in ARG1.

In other words, ARG0 allows the postback's creator to pass context
through the postback.  ARG1 allows the caller to return information.

This example creates a coderef that when called posts "ok_button" to
C<$some_session> with ARG0 containing C<[ 8, 6, 7 ]>.

  my $postback = $some_session->postback( "ok_button", 8, 6, 7 );

Here's an example event handler for "ok_button".

  sub handle_ok_button {
    my ($creation_args, $called_args) = @_[ARG0, ARG1];
    print "Postback created with (@$creation_args).\n";
    print "Postback called with (@$called_args).\n";
  }

Calling $postback->(5, 3, 0, 9) would perform the equivalent of...

  $poe_kernel->post(
    $some_session, "ok_button",
    [ 8, 6, 7 ],
    [ 5, 3, 0, 9 ]
  );

This would be displayed when "ok_button" was dispatched to
handle_ok_button():

  Postback created with (8 6 7).
  Postback called with (5 3 0 9).

Postbacks hold references to their target sessions.  Therefore
sessions with outstanding postbacks will remain active.  Under every
event loop except Tk, postbacks are blessed so that DESTROY may be
called when their users are done.  This triggers a decrement on their
reference counts, allowing sessions to stop.

Postbacks have one method, weaken(), which may be used to reduce their
reference counts upon demand.  weaken() returns the postback, so you
can do:

  my $postback = $session->postback("foo")->weaken();

Postbacks were created as a thin adapter between callback libraries
and POE.  The problem at hand was how to turn callbacks from the Tk
graphical toolkit's widgets into POE events without subclassing
several Tk classes.  The solution was to provide Tk with plain old
callbacks that posted POE events.

Since C<postback()> and C<callback()> are Session methods, they may be
called on C<$_[SESSION]> or C<$_[SENDER]>, depending on particular needs.
There are usually better ways to interact between sessions than
abusing postbacks, however.

Here's a brief example of attaching a L<Gtk2> button to a POE event
handler:

  my $btn = Gtk2::Button->new("Clear");
  $btn->signal_connect( "clicked", $_[SESSION]->postback("ev_clear") );

Points to remember: The session will remain alive as long as $btn
exists and holds a copy of $_[SESSION]'s postback.  Any parameters
passed by the Gtk2 button will be in ARG1.

=head2 callback EVENT_NAME, EVENT_PARAMETERS

callback() manufactures callbacks that use C<< $poe_kernel->call() >> to
deliver POE events rather than C<< $poe_kernel->post() >>.  It is identical
to C<postback()> in every other respect.

callback() was created to avoid race conditions that arise when
external libraries assume callbacks will execute synchronously.
L<File::Find> is an obvious (but not necessarily appropriate) example.
It provides a lot of information in local variables that stop being
valid after the callback.  The information would be unavailable by the
time a post()ed event was dispatched.

=head2 get_heap

C<get_heap()> returns a reference to a session's heap.  This is the same
value as C<$_[HEAP]> for the target session.  C<get_heap()> is intended to
be used with C<$poe_kernel> and POE::Kernel's C<get_active_session()> so
that libraries do not need these three common values explicitly passed
to them.

That is, it prevents the need for:

  sub some_helper_function {
    my ($kernel, $session, $heap, @specific_parameters) = @_;
    ...;
  }

Rather, helper functions may use:

  use POE::Kernel; # exports $poe_kernel
  sub some_helper_function {
    my (@specific_parameters) = @_;
    my $session = $poe_kernel->get_active_session();
    my $heap = $session->get_heap();
  }

This isn't very convenient for people writing libraries, but it makes
the libraries much more convenient to use.

Using C<get_heap()> to break another session's encapsulation is strongly
discouraged.

=head2 instantiate CREATE_PARAMETERS

C<instantiate()> creates and returns an empty POE::Session object.  It is
called with the CREATE_PARAMETERS in a hash reference just before
C<create()> processes them.  Modifications to the CREATE_PARAMETERS will
affect how C<create()> initializes the new session.

Subclasses may override C<instantiate()> to alter the underlying
session's structure.  They may extend C<instantiate()> to add new
parameters to C<create()>.

Any parameters not recognized by C<create()> must be removed from the
CREATE_PARAMETERS before C<instantiate()> returns.  C<create()> will
L<croak|Carp>
if it discovers unknown parameters.

Be sure to return C<$self> from instantiate.

  sub instantiate {
    my ($class, $create_params) = @_;

    # Have the base class instantiate the new session.
    my $self = $class->SUPER::instantiate($create_parameters);

    # Extend the parameters recognized by create().
    my $new_option = delete $create_parameters->{new_option};
    if (defined $new_option) {
      # ... customize $self here ...
    }

    return $self;
  }

=head2 try_alloc START_ARGS

C<try_alloc()> calls POE::Kernel's C<session_alloc()> to allocate a session
structure and begin managing the session within POE's kernel.  It is
called at the end of POE::Session's C<create()>.  It returns C<$self>.

It is a subclassing hook for late session customization prior to
C<create()> returning.  It may also affect the contents of C<@_[ARG0..$#_]>
that are passed to the session's _start handler.

  sub try_alloc {
    my ($self, @start_args) = @_;

    # Perform late initialization.
    # ...

    # Give $self to POE::Kernel.
    return $self->SUPER::try_alloc(@args);
  }

=head1 POE::Session's EVENTS

Please do not define new events that begin with a leading underscore.
POE claims /^_/ events as its own.

POE::Session only generates one event, _default.  All other internal
POE events are generated by (and documented in) POE::Kernel.

=head2 _default

_default is the C<AUTOLOAD> of event handlers.  If POE::Session can't
find a handler at dispatch time, it attempts to redirect the event to
_default's handler instead.

If there's no _default handler, POE::Session will silently drop the
event unless the "default" option is set.

To preserve the original information, the original event is slightly
changed before being redirected to the _default handler:  The original
event parameters are moved to an array reference in ARG1, and the
original event name is passed to _default in ARG0.

  sub handle_default {
    my ($event, $args) = @_[ARG0, ARG1];
    print(
      "Session ", $_[SESSION]->ID,
      " caught unhandled event $event with (@$args).\n"
    );
  }

_default is quite flexible.  It may be used for debugging, or to
handle dynamically generated event names without pre-defining their
handlers.  In the latter sense, _default performs analogously to
Perl's C<AUTOLOAD>.

_default may also be used as the default or "otherwise" clause of a
switch statement.  Consider an input handler that throws events based
on a command name:

  sub parse_command {
    my ($command, @parameters) = split /\s+/, $_[ARG0];
    $_[KERNEL]->post( "cmd_$command", @parameters );
  }

A _default handler may be used to emit errors for unknown commands:

  sub handle_default {
    my $event = $_[ARG0];
    return unless $event =~ /^cmd_(\S+)/;
    warn "Unknown command: $1\n";
  }

The _default behavior is implemented in POE::Session, so it may be
different for other session types.

=head2 POE::Session's Debugging Features

POE::Session contains one debugging assertion, for now.

=head3 ASSERT_STATES

Setting ASSERT_STATES to true causes every Session to warn when they
are asked to handle unknown events.  Session.pm implements the guts of
ASSERT_STATES by defaulting the "default" option to true instead of
false.  See the option() method earlier in this document for details
about the "default" option.

TODO - It's not much of an assertion if it only warns.

=head1 SEE ALSO

L<POE::Kernel>.

The SEE ALSO section in L<POE> contains a table of contents covering
the entire POE distribution.

=head1 BUGS

There is a chance that session IDs may collide after Perl's integer
value wraps.  This can occur after as I<few> as 4.29 billion sessions.

=head2 Beware circular references

As you're probably aware, a circular reference is when a variable is
part of a reference chain that eventually refers back to itself.  Perl
will not reclaim the memory involved in such a reference chain until
the chain is manually broken.

Here a POE::Session is created that refers to itself via an external
scalar.  The event handlers import $session via closures which are in
turn stored within $session.  Even if this session stops, the circular
references will remain.

  my $session;
  $session = POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]->{todo} = [ qw( step1 step2 step2a ) ],
        $_[KERNEL]->post( $session, 'next' );
      },
      next => sub {
        my $next = shift @{ $_[HEAP]->{todo} };
        return unless $next;
        $_[KERNEL]->post( $session, $next );
      }
      # ....
    }
  );

Reduced to its essence:

  my %event_handlers;
  $event_handler{_start} = sub { \%event_handlers };

Note also that a anonymous sub creates a closure on all lexical
variables in the scope it was defined in, even if it doesn't reference
them.  $session is still being held in a circular reference here:

  my $self = $package->new;
  my $session;
  $session = POE::Session->create(
    inline_state => {
      _start => sub { $self->_start( @_[ARG0..$#_] ) }
    }
  );

To avoid this, a session may set an alias for itself.  Other parts of
the program may then refer to it by alias.  In this case, one needn't
keep track of the session themselves (POE::Kernel will do it anyway).

  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]->{todo} = [ qw( step1 step2 step2a ) ],
        $_[KERNEL]->alias_set('step_doer');
        $_[KERNEL]->post( 'step_doer', 'next' );
      },
      next => sub {
        my $next = shift @{ $_[HEAP]->{todo} };
        return unless $next;
        $_[KERNEL]->post( 'step_doer', $next );
      }
      # ....
    }
  );

Aliases aren't even needed in the previous example because the session
refers to itself.  One could instead use POE::Kernel's yield() method
to post the event back to the current session:

  next => sub {
    my $next = shift @{ $_[HEAP]->{todo} };
    return unless $next;
    $_[KERNEL]->yield( $next );
  }

Or the L</$_[SESSION]> parameter passed to every event handler, but
yield() is more efficient.

  next => sub {
    my $next = shift @{ $_[HEAP]->{todo} };
    return unless $next;
    $_[KERNEL]->post( $_[SESSION], $next );
  }

Along the same lines as L</$_[SESSION]>, a session can respond back to
the sender of an event by posting to L</$_[SENDER]>.  This is great for
responding to requests.

If a program must hold onto some kind of dynamic session reference,
it's recommended to use the session's numeric ID rather than the
object itself.  A session ID may be converted back into its object,
but post() accepts session IDs as well as objects and aliases:

  my $session_id;
  $session_id = POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]->{todo} = [ qw( step1 step2 step2a ) ],
        $_[KERNEL]->post( $session_id, 'next' );
      },
      # ....
    }
  )->ID;

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors and contributors.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
