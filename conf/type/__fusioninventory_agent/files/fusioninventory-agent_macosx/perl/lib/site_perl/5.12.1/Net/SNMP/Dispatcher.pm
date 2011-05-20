# -*- mode: perl -*- 
# ============================================================================

package Net::SNMP::Dispatcher;

# $Id: Dispatcher.pm,v 4.1 2010/09/10 00:01:22 dtown Rel $

# Object that dispatches SNMP messages and handles the scheduling of events.

# Copyright (c) 2001-2010 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as the Perl 5 programming language system itself.

# ============================================================================

use strict;
use Errno;

use Net::SNMP::MessageProcessing();
use Net::SNMP::Message qw( TRUE FALSE );

## Version of the Net::SNMP::Dispatcher module

our $VERSION = v4.0.1;

## Package variables

our $INSTANCE;            # Reference to our Singleton object

our $DEBUG = FALSE;       # Debug flag

our $MESSAGE_PROCESSING;  # Reference to the Message Processing object

## Event array indexes

sub _ACTIVE    { 0 }      # State of the event
sub _TIME      { 1 }      # Execution time
sub _CALLBACK  { 2 }      # Callback reference
sub _PREVIOUS  { 3 }      # Previous event
sub _NEXT      { 4 }      # Next event

BEGIN
{
   # Use a higher resolution of time() and possibly a monotonically
   # increasing time value if the Time::HiRes module is available. 

   if (eval 'require Time::HiRes') {
      Time::HiRes->import('time');
      no warnings;
      if (eval 'Time::HiRes::clock_gettime(Time::HiRes::CLOCK_MONOTONIC())' > 0)
      {
         *time = sub () {
            Time::HiRes::clock_gettime(Time::HiRes::CLOCK_MONOTONIC());
         };
      }
   }

   # Validate the creation of the Message Processing object. 

   if (!defined($MESSAGE_PROCESSING = Net::SNMP::MessageProcessing->instance()))
   {
      die 'FATAL: Failed to create Message Processing instance';
   }
}

# [public methods] -----------------------------------------------------------

sub instance
{
   return $INSTANCE ||= Net::SNMP::Dispatcher->_new();
}

sub loop
{
   my ($this) = @_;

   return TRUE if ($this->{_active});

   $this->{_active} = TRUE;

   # Process while there are events and file descriptor handlers.
   while (defined $this->{_event_queue_h} || keys %{$this->{_descriptors}}) {
      $this->_event_handle(undef);
   }

   return $this->{_active} = FALSE;
}

sub one_event
{
   my ($this) = @_;

   return TRUE if ($this->{_active});

   if (defined $this->{_event_queue_h} || keys %{$this->{_descriptors}}) {
      $this->{_active} = TRUE;
      $this->_event_handle(0);
      $this->{_active} = FALSE;
   }

   return (defined $this->{_event_queue_h} || keys %{$this->{_descriptors}});
}

sub activate
{
   goto &loop;
}

sub listen
{
   goto &loop;
}

sub send_pdu
{
   my ($this, $pdu, $delay) = @_;

   # Clear any previous errors
   $this->_error_clear();

   if ((@_ < 2) || !ref $pdu) {
      return $this->_error('The required PDU object is missing or invalid');
   }

   # If the Dispatcher is active and the delay value is negative,
   # send the message immediately.

   if ($delay < 0) {
      if ($this->{_active}) {
         return $this->_send_pdu($pdu, $pdu->retries());
      }
      $delay = 0;
   }

   $this->schedule($delay, [\&_send_pdu, $pdu, $pdu->retries()]);

   return TRUE;
}

sub return_response_pdu
{
   my ($this, $pdu) = @_;

   return $this->send_pdu($pdu, -1);
}

sub msg_handle_alloc
{
   return $MESSAGE_PROCESSING->msg_handle_alloc();
}

sub schedule
{
   my ($this, $time, $callback) = @_;

   return $this->_event_create($time, $this->_callback_create($callback));
}

sub cancel
{
   my ($this, $event) = @_;

   return $this->_event_delete($event);
}

sub register
{
   my ($this, $transport, $callback) = @_;

   # Transport Domain and file descriptor must be valid.
   my $fileno;

   if (!defined($transport) || !defined($fileno = $transport->fileno())) {
      return $this->_error('The Transport Domain object is invalid');
   }

   # NOTE: The callback must read the data associated with the
   #       file descriptor or the Dispatcher will continuously
   #       call the callback and get stuck in an infinite loop.

   if (!exists $this->{_descriptors}->{$fileno}) {

      # Make sure that the "readable" vector is defined.
      if (!defined $this->{_rin}) {
         $this->{_rin} = q{};
      }

      # Add the file descriptor to the list.
      $this->{_descriptors}->{$fileno} = [
         $this->_callback_create($callback), # Callback
         $transport,                         # Transport Domain object 
         1                                   # Reference count
      ];

      # Add the file descriptor to the "readable" vector.
      vec($this->{_rin}, $fileno, 1) = 1;

      DEBUG_INFO('added handler for descriptor [%d]', $fileno);

   } else {
      # Bump up the reference count.
      $this->{_descriptors}->{$fileno}->[2]++;
   }

   return $transport;
}

sub deregister
{
   my ($this, $transport) = @_;

   # Transport Domain and file descriptor must be valid.
   my $fileno;

   if (!defined($transport) || !defined($fileno = $transport->fileno())) {
      return $this->_error('The Transport Domain object is invalid');
   }

   if (exists $this->{_descriptors}->{$fileno}) {

      # Check reference count.
      if (--$this->{_descriptors}->{$fileno}->[2] < 1) {

         # Remove the file descriptor from the list.
         delete $this->{_descriptors}->{$fileno};

         # Remove the file descriptor from the "readable" vector.
         vec($this->{_rin}, $fileno, 1) = 0;

         # Undefine the vector if there are no file descriptors,
         # some systems expect this to make select() work properly.

         if (!keys %{$this->{_descriptors}}) {
            $this->{_rin} = undef;
         }

         DEBUG_INFO('removed handler for descriptor [%d]', $fileno);
      }

   } else {
      return $this->_error('The Transport Domain object is not registered');
   }

   return $transport;
}

sub error
{
   return $_[0]->{_error} || q{};
}

sub debug
{
   return (@_ == 2) ? $DEBUG = ($_[1]) ? TRUE : FALSE : $DEBUG;
}

# [private methods] ----------------------------------------------------------

sub _new
{
   my ($class) = @_;

   # The constructor is private since we only want one 
   # Dispatcher object.

   return bless {
      '_active'        => FALSE,  # State of this Dispatcher object
      '_error'         => undef,  # Error message
      '_event_queue_h' => undef,  # Head of the event queue
      '_event_queue_t' => undef,  # Tail of the event queue
      '_rin'           => undef,  # Readable vector for select()
      '_descriptors'   => {},     # List of file descriptors to monitor
   }, $class;
}

sub _send_pdu
{
   my ($this, $pdu, $retries) = @_;

   # Pass the PDU to Message Processing so that it can
   # create the new outgoing message.

   my $msg = $MESSAGE_PROCESSING->prepare_outgoing_msg($pdu);

   if (!defined $msg) {
      # Inform the command generator about the Message Processing error.
      $pdu->status_information($MESSAGE_PROCESSING->error());
      return;
   }

   # Actually send the message.

   if (!defined $msg->send()) {

      # Delete the msgHandle.
      if ($pdu->expect_response()) {
         $MESSAGE_PROCESSING->msg_handle_delete($msg->msg_id());
      }

      # A crude attempt to recover from temporary failures.
      if (($retries-- > 0) && ($!{EAGAIN} || $!{EWOULDBLOCK})) {
         DEBUG_INFO('attempting recovery from temporary failure');
         $this->schedule($pdu->timeout(), [\&_send_pdu, $pdu, $retries]);
         return FALSE;
      }

      # Inform the command generator about the send() error.
      $pdu->status_information($msg->error());

      return;
   }

   # Schedule the timeout handler if the message expects a response.

   if ($pdu->expect_response()) {
      $this->register($msg->transport(), [\&_transport_response_received]);
      $msg->timeout_id(
         $this->schedule(
            $pdu->timeout(),
            [\&_transport_timeout, $pdu, $retries, $msg->msg_id()]
         )
      );
   }

   return TRUE;
}

sub _transport_timeout
{
   my ($this, $pdu, $retries, $handle) = @_;

   # Stop waiting for responses.
   $this->deregister($pdu->transport());

   # Delete the msgHandle.
   $MESSAGE_PROCESSING->msg_handle_delete($handle);

   if ($retries-- > 0) {

      # Resend a new message.
      DEBUG_INFO('retries left %d', $retries);
      return $this->_send_pdu($pdu, $retries);

   } else {

      # Inform the command generator about the timeout. 
      $pdu->status_information(
          q{No response from remote host "%s"}, $pdu->hostname()
      );
      return;

   }
}

sub _transport_response_received
{
   my ($this, $transport) = @_;

   # Clear any previous errors
   $this->_error_clear();

   if (!ref $transport) {
      die 'FATAL: The Transport Domain object is invalid';
   }

   # Create a new Message object to receive the response
   my ($msg, $error) = Net::SNMP::Message->new(-transport => $transport);

   if (!defined $msg) {
      die sprintf 'Failed to create Message object: %s', $error;
   }

   # Read the message from the Transport Layer  
   if (!defined $msg->recv()) {
      if (!$transport->connectionless()) {
         $this->deregister($transport);
      }
      return $this->_error($msg->error());
   }

   # For connection-oriented Transport Domains, it is possible to
   # "recv" an empty buffer if reassembly is required.

   if (!$msg->length()) {
      DEBUG_INFO('ignoring zero length message');
      return FALSE;
   }

   # Hand the message over to Message Processing.
   if (!defined $MESSAGE_PROCESSING->prepare_data_elements($msg)) {
      return $this->_error($MESSAGE_PROCESSING->error());
   }

   # Set the error if applicable. 
   if ($MESSAGE_PROCESSING->error()) {
      $msg->error($MESSAGE_PROCESSING->error());
   }

   # Cancel the timeout.
   $this->cancel($msg->timeout_id());

   # Stop waiting for responses.
   $this->deregister($transport);

   # Notify the command generator to process the response.
   return $msg->process_response_pdu();
}

sub _event_create
{
   my ($this, $time, $callback) = @_;

   # Create a new event anonymous array and add it to the queue.   
   # The event is initialized based on the currrent state of the 
   # Dispatcher object.  If the Dispatcher is not currently running
   # the event needs to be created such that it will get properly
   # initialized when the Dispatcher is started.

   return $this->_event_insert(
      [
         $this->{_active},                          # State of the object
         $this->{_active} ? time() + $time : $time, # Execution time
         $callback,                                 # Callback reference
         undef,                                     # Previous event
         undef,                                     # Next event 
      ]
   );
}

sub _event_insert
{
   my ($this, $event) = @_;

   # If the head of the list is not defined, we _must_ be the only
   # entry in the list, so create a new head and tail reference.

   if (!defined $this->{_event_queue_h}) {
      DEBUG_INFO('created new head and tail [%s]', $event);
      return $this->{_event_queue_h} = $this->{_event_queue_t} = $event;
   }

   # Estimate the midpoint of the list by calculating the average of
   # the time associated with the head and tail of the list.  Based
   # on this value either start at the head or tail of the list to
   # search for an insertion point for the new Event.

   my $midpoint = (($this->{_event_queue_h}->[_TIME] +
                    $this->{_event_queue_t}->[_TIME]) / 2);


   if ($event->[_TIME] >= $midpoint) {

      # Search backwards from the tail of the list

      for (my $e = $this->{_event_queue_t}; defined $e; $e = $e->[_PREVIOUS]) {
         if ($e->[_TIME] <= $event->[_TIME]) {
            $event->[_PREVIOUS] = $e;
            $event->[_NEXT] = $e->[_NEXT];
            if ($e eq $this->{_event_queue_t}) {
               DEBUG_INFO('modified tail [%s]', $event);
               $this->{_event_queue_t} = $event;
            } else {
               DEBUG_INFO('inserted [%s] into list', $event);
               $e->[_NEXT]->[_PREVIOUS] = $event;
            }
            return $e->[_NEXT] = $event;
         }
      }

      DEBUG_INFO('added [%s] to head of list', $event);
      $event->[_NEXT] = $this->{_event_queue_h};
      $this->{_event_queue_h} = $this->{_event_queue_h}->[_PREVIOUS] = $event;

   } else {

      # Search forward from the head of the list

      for (my $e = $this->{_event_queue_h}; defined $e; $e = $e->[_NEXT]) {
         if ($e->[_TIME] > $event->[_TIME]) {
            $event->[_NEXT] = $e;
            $event->[_PREVIOUS] = $e->[_PREVIOUS];
            if ($e eq $this->{_event_queue_h}) {
               DEBUG_INFO('modified head [%s]', $event);
               $this->{_event_queue_h} = $event;
            } else {
               DEBUG_INFO('inserted [%s] into list', $event);
               $e->[_PREVIOUS]->[_NEXT] = $event;
            }
            return $e->[_PREVIOUS] = $event;
         }
      }

      DEBUG_INFO('added [%s] to tail of list', $event);
      $event->[_PREVIOUS] = $this->{_event_queue_t};
      $this->{_event_queue_t} = $this->{_event_queue_t}->[_NEXT] = $event;

   }

   return $event;
}

sub _event_delete
{
   my ($this, $event) = @_;

   my $info = q{};

   # Update the previous event
   if (defined $event->[_PREVIOUS]) {
      $event->[_PREVIOUS]->[_NEXT] = $event->[_NEXT];
   } elsif ($event eq $this->{_event_queue_h}) {
      if (defined ($this->{_event_queue_h} = $event->[_NEXT])) {
          $info = sprintf ', defined new head [%s]', $event->[_NEXT];
      } else {
         DEBUG_INFO('deleted [%s], list is now empty', $event);
         $this->{_event_queue_t} = undef @{$event};
         return FALSE; # Indicate queue is empty
      }
   } else {
      die 'FATAL: Attempted to delete Event object with an invalid head';
   }

   # Update the next event
   if (defined $event->[_NEXT]) {
      $event->[_NEXT]->[_PREVIOUS] = $event->[_PREVIOUS];
   } elsif ($event eq $this->{_event_queue_t}) {
      $info .= sprintf ', defined new tail [%s]', $event->[_PREVIOUS];
      $this->{_event_queue_t} = $event->[_PREVIOUS];
   } else {
      die 'FATAL: Attempted to delete Event object with an invalid tail';
   }

   DEBUG_INFO('deleted [%s]%s', $event, $info);
   undef @{$event};

   # Indicate queue still has entries
   return TRUE;
}

sub _event_init
{
   my ($this, $event) = @_;

   DEBUG_INFO('initializing event [%s]', $event);

   # Save the time and callback because they will be cleared.
   my ($time, $callback) = @{$event}[_TIME, _CALLBACK];

   # Remove the event from the queue.
   $this->_event_delete($event);

   # Update the appropriate fields.
   $event->[_ACTIVE]   = $this->{_active};
   $event->[_TIME]     = $this->{_active} ? time() + $time : $time;
   $event->[_CALLBACK] = $callback;

   # Insert the event back into the queue.
   $this->_event_insert($event);

   return TRUE;
}

sub _event_handle
{
   my ($this, $timeout) = @_;

   my $time = time();

   if (defined (my $event = $this->{_event_queue_h})) {

      # If the event was inserted with a non-zero delay while the
      # Dispatcher was not active, the scheduled time of the event
      # needs to be updated.

      if (!$event->[_ACTIVE] && $event->[_TIME]) {
         return $this->_event_init($event);
      }

      if ($event->[_TIME] <= $time) {

         # If the scheduled time of the event is past, execute it and
         # set the timeout to zero to poll the descriptors immediately.

         $this->_callback_execute($event->[_CALLBACK]);
         $this->_event_delete($event);
         $timeout = 0;

      } elsif (!defined $timeout) {

         # Calculate the timeout for the next event unless one was
         # specified by the caller.

         $timeout = $event->[_TIME] - $time;
         DEBUG_INFO('event [%s], timeout = %.04f', $event, $timeout);

      }

   }

   # Check the file descriptors for activity.

   my $nfound = select(my $rout = $this->{_rin}, undef, undef, $timeout);

   if (!defined $nfound || $nfound < 0) {

      if ($!{EINTR}) { # Recoverable error
         return FALSE;
      } else {
         die sprintf 'FATAL: select() error: %s', $!;
      }

   } elsif ($nfound > 0) {

      # Find out which file descriptors have data ready for reading.

      if (defined $rout) {
         for (keys %{$this->{_descriptors}}) {
            if (vec $rout, $_, 1) {
               DEBUG_INFO('descriptor [%d] ready for read', $_);
               $this->_callback_execute(@{$this->{_descriptors}->{$_}}[0,1]);
            }
         }
      }

   }

   return TRUE;
}

sub _callback_create
{
   my ($this, $callback) = @_;

   # Callbacks can be passed in two different ways.  If the callback
   # has options, the callback must be passed as an ARRAY reference
   # with the first element being a CODE reference and the remaining
   # elements the arguments.  If the callback has no options it is
   # just passed as a CODE reference.

   if ((ref($callback) eq 'ARRAY') && (ref($callback->[0]) eq 'CODE')) {
      return $callback;
   } elsif (ref($callback) eq 'CODE') {
      return [$callback];
   } else {
      return [];
   }
}

sub _callback_execute
{
   my ($this, @argv) = @_;

   # The callback is invoked passing a reference to this object
   # with the parameters passed by the user next and then any
   # parameters that the caller provides.

   my ($callback, @user_argv) = @{shift @argv};

   # Protect ourselves from user error.
   eval { $callback->($this, @user_argv, @argv); };

   return ($@) ? $this->_error($@) : TRUE;
}

sub _error
{
   my $this = shift;

   if (!defined $this->{_error}) {
      $this->{_error} = (@_ > 1) ? sprintf(shift(@_), @_) : $_[0];
      if ($this->debug()) {
         printf "error: [%d] %s(): %s\n",
                (caller 0)[2], (caller 1)[3], $this->{_error};
      }
   }

   return;
}

sub _error_clear
{
   return $_[0]->{_error} = undef;
}

sub DEBUG_INFO
{
   return $DEBUG if (!$DEBUG);

   return printf
      sprintf('debug: [%d] %s(): ', (caller 0)[2], (caller 1)[3]) .
      ((@_ > 1) ? shift(@_) : '%s') .
      "\n",
      @_;
}

# ============================================================================
1; # [end Net::SNMP::Dispatcher]
