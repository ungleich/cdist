cdist-type__consul_template(7)
==============================

NAME
----
cdist-type__consul_template - Manage the consul-template service


DESCRIPTION
-----------
Downloads and installs the consul-template binary from
https://github.com/hashicorp/consul-template/releases/download/.
Generates a global config file and creates directory for per template config files.
Note that the consul-template binary is downloaded on the server (the machine running
cdist) and then deployed to the target host using the __file type.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
auth-username
   specify a username for basic authentication.

auth-password
   specify a password for basic authentication.

batch-size
   the size of the batch when polling multiple dependencies.

consul
   the location of the Consul instance to query (may be an IP address or FQDN) with port.
   Defaults to 'localhost:8500'.

log-level
   The log level for output. This applies to the stdout/stderr logging as well
   as syslog logging (if enabled). Valid values are "debug", "info", "warn",
   and "err". The default value is "warn".

max-stale
   the maximum staleness of a query. If specified, Consul will distribute work among all
   servers instead of just the leader.

retry
   the amount of time to wait if Consul returns an error when communicating
   with the API.

state
   either 'present' or 'absent'. Defaults to 'present'

ssl-cert
   Path to an SSL client certificate to use to authenticate to the consul server.
   Useful if the consul server "verify_incoming" option is set.

ssl-ca-cert
   Path to a CA certificate file, containing one or more CA certificates to
   use to validate the certificate sent by the consul server to us. This is a
   handy alternative to setting --ssl-no-verify if you are using your own CA.

syslog-facility
   The facility to use when sending to syslog. This requires the use of --syslog.
   The default value is LOCAL0.

token
   the Consul API token.

vault-address
   the location of the Vault instance to query (may be an IP address or FQDN) with port.

vault-token
   the Vault API token.

vault-ssl-cert
   Path to an SSL client certificate to use to authenticate to the vault server.

vault-ssl-ca-cert
   Path to a CA certificate file, containing one or more CA certificates to
   use to validate the certificate sent by the vault server to us.

version
   which version of consul-template to install. See ./files/versions for a list of
   supported versions. Defaults to the latest known version.

wait
   the minimum(:maximum) to wait before rendering a new template to disk and
   triggering a command, separated by a colon (:). If the optional maximum
   value is omitted, it is assumed to be 4x the required minimum value.


BOOLEAN PARAMETERS
------------------
ssl
   use HTTPS while talking to Consul. Requires the Consul server to be configured to serve secure connections.

ssl-no-verify
   ignore certificate warnings. Only used if ssl is enabled.

syslog
   Send log output to syslog (in addition to stdout and stderr).

vault-ssl
   use HTTPS while talking to Vault. Requires the Vault server to be configured to serve secure connections.

vault-ssl-no-verify
   ignore certificate warnings. Only used if vault is enabled.


EXAMPLES
--------

.. code-block:: sh

    __consul_template \
       --consul consul.service.consul:8500 \
       --retry 30s

    # specific version
    __consul_template \
       --version 0.6.5 \
       --retry 30s


SEE ALSO
--------
consul documentation at: <https://github.com/hashicorp/consul-template>.


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2015 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
