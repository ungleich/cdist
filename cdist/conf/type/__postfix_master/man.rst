cdist-type__postfix_master(7)
=============================
Configure postfix master.cf

Steven Armstrong <steven-cdist--@--armstrong.cc>


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
- `cdist-type(7) <cdist-type.html>`_
- master(5)


COPYING
-------
Copyright \(C) 2012 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).

