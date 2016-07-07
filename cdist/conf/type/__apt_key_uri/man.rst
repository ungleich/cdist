cdist-type__apt_key_uri(7)
==========================

NAME
----
cdist-type__apt_key_uri - Add apt key from uri


DESCRIPTION
-----------
Download a key from an uri and add it to the apt keyring.


REQUIRED PARAMETERS
-------------------
uri
   the uri from which to download the key


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent', defaults to 'present'

name
   a name for this key, used when testing if it is already installed.
   Defaults to __object_id


EXAMPLES
--------

.. code-block:: sh

    __apt_key_uri rabbitmq \
       --name 'RabbitMQ Release Signing Key <info@rabbitmq.com>' \
       --uri http://www.rabbitmq.com/rabbitmq-signing-key-public.asc \
       --state present


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011-2014 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
