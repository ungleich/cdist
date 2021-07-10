cdist-type__apt_key(7)
======================

NAME
----
cdist-type__apt_key - Manage the list of keys used by apt


DESCRIPTION
-----------
Manages the list of keys used by apt to authenticate packages.

This is done by placing the requested key in a file named
``$__object_id.gpg`` in the ``keydir`` directory.

This is supported by modern releases of Debian-based distributions.

In order of preference, exactly one of: ``source``, ``uri`` or ``keyid``
must be specified.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
keydir
   keyring directory, defaults to ``/etc/apt/trusted.pgp.d``, which is
   enabled system-wide by default.

source
   path to a file containing the GPG key of the repository.
   Using this is recommended as it ensures that the manifest/type manintainer
   has validated the key.
   If ``-``, the GPG key is read from the type's stdin.

state
   'present' or 'absent'. Defaults to 'present'

uri
   the URI from which to download the key.
   It is highly recommended that you only use protocols with TLS like HTTPS.
   This uses ``__download`` but does not use checksums, if you want to ensure
   that the key doesn't change, you are better off downloading it and using
   ``--source``.


DEPRECATED OPTIONAL PARAMETERS
------------------------------
keyid
   the id of the key to download from the ``keyserver``.
   This is to be used in absence of ``--source`` and ``--uri`` or together
   with ``--use-deprecated-apt-key`` for key removal.
   Defaults to ``$__object_id``.

keyserver
   the keyserver from which to fetch the key.
   Defaults to ``pool.sks-keyservers.net``.


DEPRECATED BOOLEAN PARAMETERS
-----------------------------
use-deprecated-apt-key
   ``apt-key(8)`` will last be available in Debian 11 and Ubuntu 22.04.
   You can use this parameter to force usage of ``apt-key(8)``.
   Please only use this parameter to *remove* keys from the keyring,
   in order to prepare for removal of ``apt-key``.
   Adding keys should be done without this parameter.
   This parameter will be removed when Debian 11 stops being supported.


EXAMPLES
--------

.. code-block:: sh

    # add a key that has been verified by a type maintainer
    __apt_key jitsi_meet_2021 \
       --source cdist-contrib/type/__jitsi_meet/files/apt_2021.gpg

    # remove an old, deprecated or expired key
    __apt_key jitsi_meet_2016 --state absent

    # Get rid of a key that might have been added to
    # /etc/apt/trusted.gpg with apt-key
    __apt_key 0x40976EAF437D05B5 --use-deprecated-apt-key --state absent

    # add a key that we define in-line
    __apt_key jitsi_meet_2021 --source '-' <<EOF
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    [...]
    -----END PGP PUBLIC KEY BLOCK-----
    EOF

    # download or update key from the internet
    __apt_key rabbitmq_2007 \
       --uri https://www.rabbitmq.com/rabbitmq-signing-key-public.asc


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>
Ander Punnar <ander-at-kvlt-dot-ee>
Evilham <contact~~@~~evilham.com>


COPYING
-------
Copyright \(C) 2011-2021 Steven Armstrong, Ander Punnar and Evilham. You can
redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
