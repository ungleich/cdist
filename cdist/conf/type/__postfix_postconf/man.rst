cdist-type__postfix_postconf(7)
===============================

NAME
----
cdist-type__postfix_postconf - Configure postfix main.cf


DESCRIPTION
-----------
See postconf(5) for possible keys and values.

Note that this type directly runs the postconf executable.
It does not make changes to /etc/postfix/main.cf itself.


REQUIRED PARAMETERS
-------------------
value
   the value for the postfix parameter


OPTIONAL PARAMETERS
-------------------
key
   the name of the parameter. Defaults to __object_id


EXAMPLES
--------

.. code-block:: sh

    __postfix_postconf mydomain --value somedomain.com

    __postfix_postconf bind-to-special-ip --key smtp_bind_address --value 127.0.0.5


SEE ALSO
--------
:strong:`postconf`\ (5)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
