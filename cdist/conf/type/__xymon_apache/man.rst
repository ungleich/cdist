cdist-type__xymon_apache(7)
===========================

NAME
----
cdist-type__xymon_apache - Configure apache2-webserver for Xymon


DESCRIPTION
-----------
This cdist type installs and configures apache2 to be used "exclusively" (in
the sense that no other use is taken care of) with Xymon (the systems and
network monitor).

It depends on `__xymon_server`.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
   'present', 'absent', defaults to 'present'.

ipacl
   IP(-ranges) that have access to the Xymon webpages and CGIs. Apache2-style
   syntax suitable for `Require ip ...`. Example: `192.168.1.0/24 10.0.0.0/8`


MESSAGES
--------
mod:rewrite enabled
   apache module enabled
conf:xymon enabled
   apache config for xymon enabled
apache restarted
   apache2.service was reloaded
apache reloaded
   apache2.service was restarted


EXPLORERS
---------
active-conf
   lists apache2 `conf-enabled`
active-modules
   lists active apache2-modules


EXAMPLES
--------

.. code-block:: sh

    # minmal, only localhost-access:
    __xymon_apache
    # allow more IPs to access the Xymon-webinterface:
    __xymon_apache --ipacl "192.168.0.0/16 10.0.0.0/8" --state "present"


SEE ALSO
--------
:strong:`cdist__xymon_server`\ (7)


AUTHORS
-------
Thomas Eckert <tom--@--it-eckert.de>


COPYING
-------
Copyright \(C) 2018-2019 Thomas Eckert. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
