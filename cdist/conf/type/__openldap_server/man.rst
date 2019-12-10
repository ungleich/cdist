cdist-type__openldap_server(7)
==============================

NAME
----
cdist-type__openldap_server - Setup an openldap(4) server instance


DESCRIPTION
-----------
This type can be used to bootstrap an LDAP environment using openldap as slapd.

It bootstraps the LDAP server with sane defaults and creates and manages the
base DN defined by `suffix`.


REQUIRED PARAMETERS
-------------------
manager-dn
    The rootdn to set up in the directory.
    E.g. `cn=manager,dc=ungleich,dc=ch`. See `slapd.conf(5)`.

manager-password
    The password for `manager-dn` in the directory.
    This will be used to connect to the LDAP server on the first `slapd-url`
    with the given `manager-dn`.

manager-password-hash
    The password for `manager-dn` in the directory.
    This should be valid for `slapd.conf` like `{SSHA}qV+mCs3u8Q2sCmUXT4Ybw7MebHTASMyr`.
    Generate e.g. with: `slappasswd -s weneedgoodsecurity`.
    See `slappasswd(8C)`, `slapd.conf(5)`.
    TODO: implement this: http://blog.adamsbros.org/2015/06/09/openldap-ssha-salted-hashes-by-hand/
      to derive from the manager-password parameter and ensure idempotency (care with salts).
      At that point, manager-password-hash should be deprecated and ignored.

serverid
    The server for the directory.
    E.g. `dc=ungleich,dc=ch`. See `slapd.conf(5)`.

suffix
    The suffix for the directory.
    E.g. `dc=ungleich,dc=ch`. See `slapd.conf(5)`.


REQUIRED MULTIPLE PARAMETERS
----------------------------
slapd-url
    A URL for slapd to listen on.
    Pass once for each URL you want to support,
    e.g.: `--slapd-url ldaps://my.fqdn/ --slapd-url ldap://my.fqdn/`.
    The first instance that is passed will be used as the main URL to
    connect to this LDAP server
    See the `-h` flag in `slapd(8C)`.


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

admin-email
    Passed to `cdist-type__letsencrypt_cert`; has otherwise no use.
    Required if using `__letsencrypt_cert`.
    Where to send Let's Encrypt emails like "certificate needs renewal".

tls-cipher-suite
    Setting for TLSCipherSuite.
    Defaults to `NORMAL` in a Debian-like OS and `HIGH:MEDIUM:+SSLv2` on FreeBSD.
    See `slapd.conf(5)`.

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

description
    The description of the base DN passed in the `suffix` parameter.
    Defaults to `Managed by cdist, do not edit manually.`


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

    # Example of a simple server with manual certificate management.
    pki_prefix="/usr/local/etc/pki/realms/ldap.camilion.cloud"
    __openldap_server \
        --manager-dn 'cn=manager,dc=camilion,dc=cloud' \
        --manager-password "foo" \
        --manager-password-hash '{SSHA}foo' \
        --serverid 0 \
        --suffix 'dc=camilion,dc=cloud' \
        --slapd-url 'ldaps://ldap.camilion.cloud' \
        --tls-cert "${pki_prefix}/default.crt" \
        --tls-privkey "${pki_prefix}/default.key" \
        --tls-ca "${pki_prefix}/CA.crt"

    # The created basedn looks as follows:
    #
    # dn: dc=camilion,dc=cloud
    # objectClass: top
    # objectClass: dcObject
    # objectClass: organization
    # o: Managed by cdist, do not edit manually.
    # dc: camilion
    #
    # Do not change it manually, the type will overwrite your changes.


    #
    # Changing to a replicated setup is a simple change to something like:
    #
    # Example for multiple servers with replication and automatic
    # Let's Encrypt certificate management through certbot.
    id=1
    for host in ldap-test1.ungleich.ch ldap-test2.ungleich.ch; do
        echo "__ungleich_ldap \
            --manager-dn 'cn=manager,dc=ungleich,dc=ch' \
            --manager-psasword 'foo' \
            --manager-password-hash '{SSHA}fooo' \
            --serverid '${id}' \
            --suffix 'dc=ungleich,dc=ch' \
            --slapd-url ldap://${host} \
            --searchbase 'dc=ungleich,dc=ch' \
            --syncrepl-credentials 'fooo' \
            --syncrepl-host 'ldap-test1.ungleich.ch' \
            --syncrepl-host 'ldap-test2.ungleich.ch' \
            --description 'Ungleich LDAP server'" \
            --staging \
            | cdist config -i - -v ${host}
        id=$((id + 1))
    done

    # The created basedn looks as follows:
    #
    # dn: dc=ungleich,dc=ch
    # objectClass: top
    # objectClass: dcObject
    # objectClass: organization
    # o: Ungleich LDAP server
    # dc: ungleich
    #
    # Do not change it manually, the type will overwrite your changes.


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
