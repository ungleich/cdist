cdist-type__snakeoil_cert(7)
============================

NAME
----
cdist-type__snakeoil_cert - Generate self-signed certificate


DESCRIPTION
-----------
The purpose of this type is to generate **self-signed** certificate and private key
for **testing purposes**. Certificate will expire in 3650 days.

Certificate's and key's access bits will be ``644`` and ``640`` respectively.
If target system has ``ssl-cert`` group, then it will be used as key's group.
Use ``require='__snakeoil_cert/...' __file ...`` to override.


OPTIONAL PARAMETERS
-------------------
common-name
   Defaults to ``$__object_id``.

key-path
   ``%s`` in path will be replaced with ``$__object_id``.
   Defaults to ``/etc/ssl/private/%s.pem``.

key-type
   Possible values are ``rsa:$bits`` and ``ec:$name``.
   For possible EC names see ``openssl ecparam -list_curves``.
   Defaults to ``rsa:2048``.

cert-path
   ``%s`` in path will be replaced with ``$__object_id``.
   Defaults to ``/etc/ssl/certs/%s.pem``.


EXAMPLES
--------
.. code-block:: sh
	__snakeoil_cert localhost-rsa \
	    --common-name localhost \
	    --key-type rsa:4096

	__snakeoil_cert localhost-ec \
	    --common-name localhost \
	    --key-type ec:prime256v1


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2021 Ander Punnar. You can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.
