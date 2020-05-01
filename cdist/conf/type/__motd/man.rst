cdist-type__motd(7)
===================

NAME
----
cdist-type__motd - Manage message of the day


DESCRIPTION
-----------
This cdist type allows you to easily setup /etc/motd.

.. note::
      In some OS, motd is a bit special, check `motd(5)`.
      Currently Debian, Devuan, Ubuntu and FreeBSD are taken into account.
      If your OS of choice does something besides /etc/motd, check the source
      and contribute support for it.
      Otherwise it will likely just work.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
source
   If supplied, copy this file from the host running cdist to the target.
   If source is '-' (dash), take what was written to stdin as the file content.
   If not supplied, a default message will be placed onto the target.


EXAMPLES
--------

.. code-block:: sh

    # Use cdist defaults
    __motd

    # Supply source file from a different type
    __motd --source "$__type/files/my-motd"

    # Supply source from stdin
    __motd --source "-" <<EOF
    Take this kiss upon the brow!
    And, in parting from you now,
    Thus much let me avow-
    You are not wrong, who deem
    That my days have been a dream
    EOF


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2020 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
