cdist-type__postfix_master(7)
=============================

NAME
----
cdist-type__postfix_master - Configure postfix master.cf


DESCRIPTION
-----------
See master(5) for more information.


REQUIRED PARAMETERS
-------------------
type
   See master(5)
command
   See master(5)


BOOLEAN PARAMETERS
------------------
noreload
   don't reload postfix after changes


OPTIONAL PARAMETERS
-------------------
state
   present or absent, defaults to present

service

private

unpriv

chroot

wakeup

maxproc

option
   Pass an option to a service. Same as using -o in master.cf.
   Can be specified multiple times.

comment
   a textual comment to add with the master.cf entry


EXAMPLES
--------

.. code-block:: sh

    __postfix_master smtp --type inet --command smtpd

    __postfix_master smtp --type inet --chroot y --command smtpd \
       --option smtpd_enforce_tls=yes \
       --option smtpd_sasl_auth_enable=yes \
       --option smtpd_client_restrictions=permit_sasl_authenticated,reject

    __postfix_master submission --type inet --command smtpd \
       --comment "Run alternative smtp on submission port"


SEE ALSO
--------
:strong:`master`\ (5)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
