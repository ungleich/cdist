# Copyrights and documentation are at the end.

package POE::Queue::Array;

use strict;

use vars qw($VERSION @ISA);
$VERSION = '1.293'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Queue);

use Errno qw(ESRCH EPERM);
use Carp qw(confess);

sub DEBUG () { 0 }

### Helpful offsets.

sub ITEM_PRIORITY () { 0 }
sub ITEM_ID       () { 1 }
sub ITEM_PAYLOAD  () { 2 }

sub import {
  my $package = caller();
  no strict 'refs';
  *{ $package . '::ITEM_PRIORITY' } = \&ITEM_PRIORITY;
  *{ $package . '::ITEM_ID'       } = \&ITEM_ID;
  *{ $package . '::ITEM_PAYLOAD'  } = \&ITEM_PAYLOAD;
}

# Item IDs are unique across all queues.

my $queue_seq = 0;
my %item_priority;

### A very simple constructor.

sub new {
  bless [], shift();
}

### Add an item to the queue.  Returns the new item's ID.

sub enqueue {
  my ($self, $priority, $payload) = @_;

  # Get the next item ID.  This clever loop will hang indefinitely if
  # you ever run out of integers to store things under.  Map the ID to
  # its due time for search-by-ID functions.

  my $item_id;
  1 while exists $item_priority{$item_id = ++$queue_seq};
  $item_priority{$item_id} = $priority;

  my $item_to_enqueue = [
    $priority, # ITEM_PRIORITY
    $item_id,  # ITEM_ID
    $payload,  # ITEM_PAYLOAD
  ];

  # Special case: No items in the queue.  The queue IS the item.
  unless (@$self) {
    $self->[0] = $item_to_enqueue;
    DEBUG and warn $self->_dump_splice(0);
    return $item_id;
  }

  # Special case: The new item belongs at the end of the queue.
  if ($priority >= $self->[-1]->[ITEM_PRIORITY]) {
    push @$self, $item_to_enqueue;
    DEBUG and warn $self->_dump_splice(@$self-1);
    return $item_id;
  }

  # Special case: The new item belongs at the head of the queue.
  if ($priority < $self->[0]->[ITEM_PRIORITY]) {
    unshift @$self, $item_to_enqueue;
    DEBUG and warn $self->_dump_splice(0);
    return $item_id;
  }

  # Special case: There are only two items in the queue.  This item
  # naturally belongs between them.
  if (@$self == 2) {
    splice @$self, 1, 0, $item_to_enqueue;
    DEBUG and warn $self->_dump_splice(1);
    return $item_id;
  }

  # And finally we have a nontrivial queue.  Insert the item using a
  # binary seek.

  $self->_insert_item(0, $#$self, $priority, $item_to_enqueue);
  return $item_id;
}

### Dequeue the next thing from the queue.  Returns an empty list if
### the queue is empty.  There are different flavors of this
### operation.

sub dequeue_next {
  my $self = shift;

  return unless @$self;
  my ($priority, $id, $stuff) = @{shift @$self};
  delete $item_priority{$id};
  return ($priority, $id, $stuff);
}

### Return the next item's priority, undef if the queue is empty.
# This is POE's most-called method.  We could greatly benefit from
# finding ways to reduce the number of calls.

sub get_next_priority {
  # This is Ton Hospel's optimization.
  # He measured a 4% improvement by avoiding $self.
  return (shift->[0] || return undef)->[ITEM_PRIORITY];
}

### Return the number of items currently in the queue.

sub get_item_count {
  return scalar @{$_[0]};
}

### Internal method to insert an item using a binary seek and splice.
### We accept the bounds as parameters because the alarm adjustment
### functions may also use it.

sub _insert_item {
  my ($self, $lower, $upper, $priority, $item) = @_;

  while (1) {
    my $midpoint = ($upper + $lower) >> 1;

    # Upper and lower bounds crossed.  Insert at the lower point.
    if ($upper < $lower) {
      splice @$self, $lower, 0, $item;
      DEBUG and warn $self->_dump_splice($lower);
      return;
    }

    # We're looking for a priority lower than the one at the midpoint.
    # Set the new upper point to just before the midpoint.
    if ($priority < $self->[$midpoint]->[ITEM_PRIORITY]) {
      $upper = $midpoint - 1;
      next;
    }

    # We're looking for a priority greater or equal to the one at the
    # midpoint.  The new lower bound is just after the midpoint.
    $lower = $midpoint + 1;
  }
}

### Internal method to find a queue item by its priority and ID.  We
### assume the priority and ID have been verified already, so the item
### must exist.  Returns the index of the item that matches the
### priority/ID pair.

sub _find_item {
  my ($self, $id, $priority) = @_;

  # Use a binary seek.

  my $upper = $#$self; # Last index of @$self.
  my $lower = 0;
  while (1) {
    my $midpoint = ($upper + $lower) >> 1;

    # Upper and lower bounds crossed.  The lower point is aimed at an
    # element with a priority higher than our target.
    last if $upper < $lower;

    # We're looking for a priority lower than the one at the midpoint.
    # Set the new upper point to just before the midpoint.
    if ($priority < $self->[$midpoint]->[ITEM_PRIORITY]) {
      $upper = $midpoint - 1;
      next;
    }

    # We're looking for a priority greater or equal to the one at the
    # midpoint.  The new lower bound is just after the midpoint.
    $lower = $midpoint + 1;
  }

  # The lower index is pointing to an element with a priority higher
  # than our target.  Scan backwards until we find the item with the
  # target ID.
  while ($lower-- >= 0) {
    return $lower if $self->[$lower]->[ITEM_ID] == $id;
  }

  die "should never get here... maybe the queue is out of order";

}

### Remove an item by its ID.  Takes a coderef filter, too, for
### examining the payload to be sure it really wants to leave.  Sets
### $! and returns undef on failure.

sub remove_item {
  my ($self, $id, $filter) = @_;

  my $priority = $item_priority{$id};
  unless (defined $priority) {
    $! = ESRCH;
    return;
  }

  # Find that darn item.
  my $item_index = $self->_find_item($id, $priority);

  # Test the item against the filter.
  unless ($filter->($self->[$item_index]->[ITEM_PAYLOAD])) {
    $! = EPERM;
    return;
  }

  # Remove the item, and return it.
  delete $item_priority{$id};
  return @{splice @$self, $item_index, 1};
}

### Remove items matching a filter.  Regrettably, this must scan the
### entire queue.  An optional count limits the number of items to
### remove, and it may shorten execution times.  Returns a list of
### references to priority/id/payload lists.  This is intended to
### return all the items matching the filter, and the function's
### behavior is undefined when $count is less than the number of
### matching items.

sub remove_items {
  my ($self, $filter, $count) = @_;
  $count = @$self unless $count;

  my @items;
  my $i = @$self;
  while ($i--) {
    if ($filter->($self->[$i]->[ITEM_PAYLOAD])) {
      my $removed_item = splice(@$self, $i, 1);
      delete $item_priority{$removed_item->[ITEM_ID]};
      unshift @items, $removed_item;
      last unless --$count;
    }
  }

  return @items;
}

### Adjust the priority of an item by a relative amount.  Adds $delta
### to the priority of the $id'd object (if it matches $filter), and
### moves it in the queue.

sub adjust_priority {
  my ($self, $id, $filter, $delta) = @_;

  my $old_priority = $item_priority{$id};
  unless (defined $old_priority) {
    $! = ESRCH;
    return;
  }

  # Find that darn item.
  my $item_index = $self->_find_item($id, $old_priority);

  # Test the item against the filter.
  unless ($filter->($self->[$item_index]->[ITEM_PAYLOAD])) {
    $! = EPERM;
    return;
  }

  # Nothing to do if the delta is zero.
  # TODO Actually we may need to ensure that the item is moved to the
  # end of its current priority bucket, since it should have "moved".
  return $self->[$item_index]->[ITEM_PRIORITY] unless $delta;

  # Remove the item, and adjust its priority.
  my $item = splice(@$self, $item_index, 1);
  my $new_priority = $item->[ITEM_PRIORITY] += $delta;
  $item_priority{$id} = $new_priority;

  $self->_reinsert_item($new_priority, $delta, $item_index, $item);
}

### Set the priority to a specific amount.  Replaces the item's
### priority with $new_priority (if it matches $filter), and moves it
### to the new location in the queue.

sub set_priority {
  my ($self, $id, $filter, $new_priority) = @_;

  my $old_priority = $item_priority{$id};
  unless (defined $old_priority) {
    $! = ESRCH;
    return;
  }

  # Nothing to do if the old and new priorities match.
  # TODO Actually we may need to ensure that the item is moved to the
  # end of its current priority bucket, since it should have "moved".
  return $new_priority if $new_priority == $old_priority;

  # Find that darn item.
  my $item_index = $self->_find_item($id, $old_priority);

  # Test the item against the filter.
  unless ($filter->($self->[$item_index]->[ITEM_PAYLOAD])) {
    $! = EPERM;
    return;
  }

  # Remove the item, and calculate the delta.
  my $item = splice(@$self, $item_index, 1);
  my $delta = $new_priority - $old_priority;
  $item->[ITEM_PRIORITY] = $item_priority{$id} = $new_priority;

  $self->_reinsert_item($new_priority, $delta, $item_index, $item);
}

### Sanity-check the results of an item insert.  Verify that it
### belongs where it was put.  Only called during debugging.

sub _dump_splice {
  my ($self, $index) = @_;
  my @return;
  my $at = $self->[$index]->[ITEM_PRIORITY];
  if ($index > 0) {
    my $before = $self->[$index-1]->[ITEM_PRIORITY];
    push @return, "before($before)";
    confess "out of order: $before should be < $at" if $before > $at;
  }
  push @return, "at($at)";
  if ($index < $#$self) {
    my $after = $self->[$index+1]->[ITEM_PRIORITY];
    push @return, "after($after)";
    my @priorities = map {$_->[ITEM_PRIORITY]} @$self;
    confess "out of order: $at should be < $after (@priorities)" if (
      $at >= $after
    );
  }
  return "@return";
}

### Reinsert an item into the queue.  It has just been removed by
### adjust_priority() or set_priority() and needs to be replaced.
### This tries to be clever by not doing more work than necessary.

sub _reinsert_item {
  my ($self, $new_priority, $delta, $item_index, $item) = @_;

  # Now insert it back.
  # The special cases are duplicates from enqueue().  We use the delta
  # (direction) of the move and the old item index to narrow down the
  # subsequent nontrivial insert if none of the special cases apply.

  # Special case: No events in the queue.  The queue IS the item.
  unless (@$self) {
    $self->[0] = $item;
    DEBUG and warn $self->_dump_splice(0);
    return $new_priority;
  }

  # Special case: The item belongs at the end of the queue.
  if ($new_priority >= $self->[-1]->[ITEM_PRIORITY]) {
    push @$self, $item;
    DEBUG and warn $self->_dump_splice(@$self-1);
    return $new_priority;
  }

  # Special case: The item belongs at the head of the queue.
  if ($new_priority < $self->[0]->[ITEM_PRIORITY]) {
    unshift @$self, $item;
    DEBUG and warn $self->_dump_splice(0);
    return $new_priority;
  }

  # Special case: There are only two items in the queue.  This item
  # naturally belongs between them.

  if (@$self == 2) {
    splice @$self, 1, 0, $item;
    DEBUG and warn $self->_dump_splice(1);
    return $new_priority;
  }

  # The item has moved towards an end of the queue, but there are a
  # lot of items into which it may be inserted.  We'll binary seek.

  my ($upper, $lower);
  if ($delta > 0) {
    $upper = $#$self; # Last index in @$self.
    $lower = $item_index;
  }
  else {
    $upper = $item_index;
    $lower = 0;
  }

  $self->_insert_item($lower, $upper, $new_priority, $item);
  return $new_priority;
}

### Peek at items that match a filter.  Returns a list of payloads
### that match the supplied coderef.

sub peek_items {
  my ($self, $filter, $count) = @_;
  $count = @$self unless $count;

  my @items;
  my $i = @$self;
  while ($i--) {
    if ($filter->($self->[$i]->[ITEM_PAYLOAD])) {
      unshift @items, $self->[$i];
      last unless --$count;
    }
  }

  return @items;
}

1;

__END__

=head1 NAME

POE::Queue::Array - a high-performance array-based priority queue

=head1 SYNOPSIS

See L<POE::Queue>.

=head1 DESCRIPTION

This class is an implementation of the abstract POE::Queue interface.
As such, its documentation may be found in L<POE::Queue>.

POE::Queue::Array implements a priority queue using Perl arrays,
splice, and copious application of cleverness.

Despite its name, POE::Queue::Array may be used as a stand-alone
priority queue without the rest of POE.

=head1 SEE ALSO

L<POE>, L<POE::Queue>

=head1 BUGS

None known.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors, contributors,
and POE's licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
