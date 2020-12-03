cdist-type__postgres_conf(7)
============================

Configure a PostgreSQL server.

NOTE: This type might need to be run multiple times to apply all bits of the
configuration due to ordering requirements.

SSRQ <cdist--@--ssrq-sds-fds.ch>


DESCRIPTION
-----------
Configure a PostgreSQL server using ALTER SYSTEM.


REQUIRED PARAMETERS
-------------------
value
    The value to setup (can be omitted when state is set to "absent").


OPTIONAL PARAMETERS
-------------------
state
    "present" or "absent". Defaults to "present".


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

	# set timezone
    __postgres_conf timezone --value Europe/Zurich

    # reset maximum number of concurrent connections to default (normally 100)
    __postgres_conf max_connections --state absent


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_


COPYING
-------
Copyright \(C) 2020 SSRQ (www.ssrq-sds-fds.ch).
Free use of this software is granted under the terms
of the GNU General Public License version 3 (GPLv3).
