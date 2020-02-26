cdist-type__matrix_synapse(7)
======================

NAME
----
cdist-type__matrix_synapse - Install and configure Synapse, a Matrix homeserver


DESCRIPTION
-----------
This type install and configure the Synapse Matrix homeserver. This is a
signleton type.


REQUIRED PARAMETERS
-------------------
server_name
  Name of your homeserver (e.g. ungleich.ch) used as part of your MXIDs. This
  value cannot be changed without meddling with the database once the server is
  being used.

base_url
  Public URL of your homeserver (e.g. http://matrix.ungleich.ch).

database_engine
  'sqlite3' or 'postgresql'

database_name
  Path to the database if SQLite3 is used or database name if PostgresSQL is
  used.

OPTIONAL PARAMETERS
-------------------
database_host
  Database node address, only used with PostgresSQL.

database_user
  Database user, only used with PostgresSQL.

database_password
  Database password, only used with PostgresSQL.

ldap_uri
  Address of your LDAP server.

ldap_base_dn
  Base DN of your LDAP tree.

ldap_uid_attribute
  LDAP attriute mapping to Synapse's uid field, default to uid.

ldap_mail_attribute
  LDAP attriute mapping to Synapse's mail field, default to mail.

ldap_name_attribute
  LDAP attriute mapping to Synapse's name field, default to givenName.

ldap_bind_dn
  User used to authenticate against your LDAP server in 'search' mode.

ldap_bind_password
  Password used to authenticate against your LDAP server in 'search' mode.

ldap_filter
  LDAP user filter, defaulting to `(objectClass=posixAccount)`.

turn_uri
  URI to TURN server, can be provided multiple times if there is more than one
  server.

turn_shared_secret
  Shared secret used to access the TURN REST API.

turn_user_lifetime
  Lifetime of TURN credentials. Defaults to 1h.

max_upload_size
  Maximum size for user-uploaded files. Defaults to 10M.

BOOLEAN PARAMETERS
------------------
allow_registration
  Enables user registration on the homeserver.

enable_ldap_auth
  Enables ldap-backed authentication.

ldap_search_mode
  Enables 'search' mode for LDAP auth backend.

report_stats
  Whether or not to report anonymized homeserver usage statistics.

expose_metrics
  Expose metrics endpoint for Prometheus.

EXAMPLES
--------

.. code-block:: sh

    __matrix_synapse --server_name ungleich.ch \
      --base_url https://matrix.ungleich.ch \
      --database_engine sqlite3 \
      --database_name /var/lib/matrix-syanpse/homeserver.db

SEE ALSO
--------
- `cdist-type__matrix_riot(7) <cdist-type__matrix_riot.html>`_


AUTHORS
-------
Timothée Floure <timothee.floure@ungleich.ch>


COPYING
-------
Copyright \(C) 2019 Timothée Floure. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
