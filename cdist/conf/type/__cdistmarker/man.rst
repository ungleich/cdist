cdist-type__cdistmarker(7)
==========================

NAME
----
cdist-type__cdistmarker - Add a timestamped cdist marker.


DESCRIPTION
-----------
This type is used to add a common marker file which indicates that a given
machine is being managed by cdist. The contents of this file consist of a
timestamp, which can be used to determine the most recent time at which cdist
was run against the machine in question.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
destination
    The path and filename of the marker.
    Default: /etc/cdist-configured

format
    The format of the timestamp. This is passed directly to system 'date'.
    Default: -u


EXAMPLES
--------

.. code-block:: sh

    # Creates the marker as normal.
    __cdistmarker

    # Creates the marker differently.
    __cdistmarker --destination /tmp/cdist_marker --format '+%s'


AUTHORS
-------
Daniel Maher <phrawzty+cdist--@--gmail.com>


COPYING
-------
Copyright \(C) 2011 Daniel Maher. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
