cdist-type__letsencrypt_cert(7)
===============================


NAME
----

cdist-type__letsencrypt_cert - Get an SSL certificate from Let's Encrypt


DESCRIPTION
-----------

Automatically obtain a Let's Encrypt SSL certificate using Certbot.

This type attempts to setup automatic renewals always. In many Linux
distributions, that is the case out of the box, see:
https://certbot.eff.org/docs/using.html#automated-renewals

For Alpine Linux and Arch Linux, we setup a system-wide cronjob that
attempts to renew certificates daily.

If you are using FreeBSD, we configure periodic(8) as recommended by
the port mantainer, so there will be a weekly attempt at renewal.

If your OS is not mentioned here or on Certbot's docs as having
support for automated renewals, please make sure you check your OS
and possibly patch this type so the system-wide cronjob is installed.


REQUIRED PARAMETERS
-------------------

object id
    A cert name. If domain parameter is not specified then it is used
    as a domain to be included in the certificate.

admin-email
    Where to send Let's Encrypt emails like "certificate needs renewal".


OPTIONAL PARAMETERS
-------------------

state
    'present' or 'absent', defaults to 'present' where:

    present
        if the certificate does not exist, it will be obtained
    absent
        the certificate will be removed

webroot
    The path to your webroot, as set up in your webserver config. If this
    parameter is not present, Certbot will be run in standalone mode.


OPTIONAL MULTIPLE PARAMETERS
----------------------------

domain
    Domains to be included in the certificate. When specified then object id
    is not used as a domain.

deploy-hook
    Command to be executed only when the certificate associated with this
    ``$__object_id`` is issued or renewed.
    You can specify it multiple times, but any failure will prevent further
    commands from being executed.

    For this command, the
    shell variable ``$RENEWED_LINEAGE`` will point to the
    config live subdirectory (for example,
    ``/etc/letsencrypt/live/${__object_id}``) containing the
    new certificates and keys; the shell variable
    ``$RENEWED_DOMAINS`` will contain a space-delimited list
    of renewed certificate domains (for example,
    ``example.com www.example.com``)

pre-hook
    Command to be run in a shell before obtaining any
    certificates.
    You can specify it multiple times, but any failure will prevent further
    commands from being executed.

    Note these run regardless of which certificate is attempted, you may want to
    manage these system-wide hooks with ``__file`` in
    ``/etc/letsencrypt/renewal-hooks/pre/``.

    Intended primarily for renewal, where it
    can be used to temporarily shut down a webserver that
    might conflict with the standalone plugin. This will
    only be called if a certificate is actually to be
    obtained/renewed.

post-hook
    Command to be run in a shell after attempting to
    obtain/renew certificates.
    You can specify it multiple times, but any failure will prevent further
    commands from being executed.

    Note these run regardless of which certificate was attempted, you may want to
    manage these system-wide hooks with ``__file`` in
    ``/etc/letsencrypt/renewal-hooks/post/``.

    Can be used to deploy
    renewed certificates, or to restart any servers that
    were stopped by --pre-hook. This is only run if an
    attempt was made to obtain/renew a certificate.


BOOLEAN PARAMETERS
------------------

staging
    Obtain a test certificate from a staging server.


MESSAGES
--------

change
    Certificate was changed.

create
    Certificate was created.

remove
    Certificate was removed.


EXAMPLES
--------

.. code-block:: sh

    # use object id as domain
    __letsencrypt_cert example.com \
        --admin-email root@example.com \
        --deploy-hook "service nginx reload" \
        --webroot /data/letsencrypt/root

.. code-block:: sh

    # domain parameter is specified so object id is not used as domain
    # and example.com needs to be included again with domain parameter
    __letsencrypt_cert example.com \
        --admin-email root@example.com \
        --domain example.com \
        --domain foo.example.com \
        --domain bar.example.com \
        --deploy-hook "service nginx reload" \
        --webroot /data/letsencrypt/root

AUTHORS
-------

| Nico Schottelius <nico-cdist--@--schottelius.org>
| Kamila Součková <kamila--@--ksp.sk>
| Darko Poljak <darko.poljak--@--gmail.com>
| Ľubomír Kučera <lubomir.kucera.jr at gmail.com>
| Evilham <contact@evilham.com>


COPYING
-------

Copyright \(C) 2017-2021 Nico Schottelius, Kamila Součková, Darko Poljak and
Ľubomír Kučera. You can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.
