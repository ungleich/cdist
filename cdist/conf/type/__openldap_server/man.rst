cdist-type__openldap_server(7)
==============================

NAME
----
cdist-type__openldap_server - Setup an openldap(4) server instance


DESCRIPTION
-----------
This type can be used to bootstrap an LDAP environment using openldap as slapd.


REQUIRED PARAMETERS
-------------------
manager-dn
    The rootdn to set up in the directory.
    E.g. `cn=manager,dc=ungleich,dc=ch`. See `slapd.conf(5)`.

manager-password-hash
    The password for `manager-dn` in the directory.
    This should be valid for `slapd.conf` like `{SSHA}qV+mCs3u8Q2sCmUXT4Ybw7MebHTASMyr`.
    Generate e.g. with: `slappasswd -s weneedgoodsecurity`.
    See `slappasswd(8C)`, `slapd.conf(5)`.
    TODO: implement this: http://blog.adamsbros.org/2015/06/09/openldap-ssha-salted-hashes-by-hand/
      to allow for a manager-password parameter and ensure idempotency (care with salts).
      Such manager-password parameter should be mutually exclusive with this one.

serverid
    The server for the directory.
    E.g. `dc=ungleich,dc=ch`. See `slapd.conf(5)`.

suffix
    The suffix for the directory.
    E.g. `dc=ungleich,dc=ch`. See `slapd.conf(5)`.


OPTIONAL PARAMETERS
-------------------
syncrepl-credentials
    Only has an effect if `replicate` is set; required in that case.
    This secret is shared amongst the hosts that will replicate the directory.
    Note that each replication server needs this secret and it is saved in
    plain text in the directory.

syncrepl-searchbase
    Only has an effect if `replicate` is set; required in that case.
    The searchbase to use for replication.
    E.g. `dc=ungleich,dc=ch`. See `slapd.conf(5)`.

tls-cert
    If defined, `__letsencrypt_cert` is not used and this must be the path in
    the remote hosts to the PEM-encoded TLS certificate.
    Requires: `tls-privkey` and `tls-ca`.
    Permissions, existence and renewal of these files are left up to the
    type's user.

tls-privkey
    Required if `tls-cert` is defined.
    Path in the remote hosts to the PEM-encoded private key file.

tls-ca
    Required if `tls-cert` is defined.
    Path in the remote hosts to the PEM-encoded CA certificate file.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
syncrepl-host
    Only has an effect if `replicate` is set; required in that case.
    Set once per host that will replicate the directory.

module
    LDAP module to load. See `slapd.conf(5)`.
    Default value is OS-dependent, see manifest.

schema
    Name of LDAP schema to load. Must be the name without extension of a
    `.schema` file in slapd's schema directory (usually `/etc/slapd/schema` or
    `/usr/local/etc/openldap/schema`).
    Example value: `inetorgperson`
    The type user must ensure that the schema file is deployed.
    This defaults to a sensible subset, for details see the type definition.

BOOLEAN PARAMETERS
------------------
staging
    Passed to `cdist-type__letsencrypt_cert`; has otherwise no use.
    Obtain a test certificate from a staging server.

replicate
    Whether to setup replication or not.
    If present `syncrepl-credentials` and `syncrepl-host` are also required.

EXAMPLES
--------

.. code-block:: sh

    # Modify the ruleset on $__target_host:
    __pf_ruleset --state present --source /my/pf/ruleset.conf
    require="__pf_ruleset" \
       __pf_apply

    # Remove the ruleset on $__target_host (implies disabling pf(4):
    __pf_ruleset --state absent
    require="__pf_ruleset" \
       __pf_apply

    root@ldap-for-guacamole:~# cat ldapbase.ldif
    dn: dc=guaca-test,dc=ungleich,dc=ch
    objectClass: top
    objectClass: dcObject
    objectClass: organization
    o: Some description
    dc: guaca-test


    # Sample usage:
    #
    # id=1
    # for host in ldap-test1.ungleich.ch ldap-test2.ungleich.ch; do
    #     echo "__ungleich_ldap ${host} \
    #         --manager-dn 'cn=manager,dc=ungleich,dc=ch' \
    #         --manager-password '{SSHA}fooo' \
    #         --serverid '${id}' \
    #         --staging \
    #         --suffix 'dc=ungleich,dc=ch' \
    #         --searchbase 'dc=ungleich,dc=ch' \
    #         --syncrepl-credentials 'fooo' \
    #         --syncrepl-host 'ldap-test1.ungleich.ch' \
    #         --syncrepl-host 'ldap-test2.ungleich.ch' \
    #         --descriptiont 'Ungleich LDAP server'" \
    #         | cdist config -i - -v ${host}
    #     id=$((id + 1))
    # done


SEE ALSO
--------
:strong:`cdist-type__letsencrypt_cert`\ (7)


AUTHORS
-------
ungleich <foss--@--ungleich.ch>
Evilham <contact--@--evilham.com>


COPYING
-------
Copyright \(C) 2020 ungleich glarus ag. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
