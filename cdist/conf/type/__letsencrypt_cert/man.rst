cdist-type__letsencrypt_cert(7)
===============================

NAME
----
cdist-type__letsencrypt_cert - Get an SSL certificate from Let's Encrypt


DESCRIPTION
-----------
Automatically obtain a Let's Encrypt SSL certificate. Uses certbot's webroot
method. You must set up your web server to work with webroot.


REQUIRED PARAMETERS
-------------------
webroot
   The path to your webroot, as set up in your webserver config.


OPTIONAL PARAMETERS
-------------------
admin-email
   Where to send Let's Encrypt emails like "certificate needs renewal". Defaults to root@localhost.


EXAMPLES
--------

.. code-block:: sh

    __letsencrypt_cert example.com --webroot /data/letsencrypt/root


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>
Kamila Součková <kamila--@--ksp.sk>


COPYING
-------
Copyright \(C) 2017 Nico Schottelius, Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
