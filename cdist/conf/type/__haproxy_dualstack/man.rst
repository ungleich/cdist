cdist-type__haproxy_dualstack(7)
================================


NAME
----
cdist-type__haproxy_dualstack - Proxy services from a dual-stack server


DESCRIPTION
-----------
This (singleton) type installs and configures haproxy to act as a dual-stack
proxy for single-stack services.

This can be useful to add IPv4 support to IPv6-only services while only using
one IPv4 for many such services.

By default this type uses the plain TCP proxy mode, which means that there is no
need for TLS termination on this host when SNI is supported.
This also means that proxied services will not receive the client's IP address,
but will see the proxy's IP address instead (that of `$__target_host`).

This can be solved by using the PROXY protocol, but do take into account that,
e.g. nginx cannot serve both regular HTTP(S) and PROXY protocols on the same
port, so you will need to use other ports for that.

As a recommendation in this type: use TCP ports 8080 and 591 respectively to
serve HTTP and HTTPS using the PROXY protocol.

See the EXAMPLES for more details.


OPTIONAL PARAMETERS
-------------------
v4proxy
    Proxy incoming IPv4 connections to the equivalent IPv6 endpoint.
    In its simplest use, it must be a NAME with an `AAAA` DNS entry, which is
    the IP address actually providing the proxied services.
    The full format of this argument is:
    `[proxy:]NAME[[:PROTOCOL_1=PORT_1]...[:PROTOCOL_N=PORT_N]]`
    Where starting with `proxy:` determines that the PROXY protocol must be
    used and each `:PROTOCOL=PORT` (e.g. `:http=8080` or `:https=591`) is a PORT
    override for the given PROTOCOL (see `--protocol`), if not present the
    PROTOCOL's default port will be used.


v6proxy
    Proxy incoming IPv6 connections to the equivalent IPv4 endpoint.
    In its simplest use, it must be a NAME with an `A` DNS entry, which is
    the IP address actually providing the proxied services.
    See `--v4proxy` for more options and details.

protocol
    Can be passed multiple times or as a space-separated list of protocols.
    Currently supported protocols are: `http`, `https`, `imaps`, `smtps`.
    This defaults to: `http https imaps smtps`.


EXAMPLES
--------

.. code-block:: sh

    # Proxy the IPv6-only services so IPv4-only clients can access them
    # This uses HAProxy's TCP mode for http, https, imaps and smtps
    __haproxy_dualstack \
        --v4proxy ipv6.chat \
        --v4proxy matrix.ungleich.ch

    # Proxy the IPv6-only HTTP(S) services so IPv4-only clients can access them
    # Note this means that the backend IPv6-only server will only see
    # the IPv6 address of the haproxy host managed by cdist, which can be
    # troublesome if this information is relevant for analytics/security/...
    # See the PROXY example below
    __haproxy_dualstack \
        --protocol http --protocol https \
        --v4proxy ipv6.chat \
        --v4proxy matrix.ungleich.ch

    # Use the PROXY protocol to proxy the IPv6-only HTTP(S) services enabling
    # IPv4-only clients to access them while maintaining the client's IP address
    __haproxy_dualstack \
        --protocol http --protocol https \
        --v4proxy proxy:ipv6.chat:http=8080:https=591 \
        --v4proxy proxy:matrix.ungleich.ch:http=8080:https=591
    # Note however that the PROXY protocol is not compatible with regular
    # HTTP(S) protocols, so your nginx will have to listen on different ports
    # with the PROXY settings.
    # Note that you will need to restrict access to the 8080 port to prevent
    # Client IP spoofing.
    # This can be something like:
    # server {
    #     # listen for regular HTTP connections
    #     listen [::]:80 default_server;
    #     listen 80 default_server;
    #     # listen for PROXY HTTP connections
    #     listen [::]:8080 proxy_protocol;
    #     # Accept the Client's IP from the PROXY protocol
    #     real_ip_header proxy_protocol;
    # }


SEE ALSO
--------
- https://www.haproxy.com/blog/enhanced-ssl-load-balancing-with-server-name-indication-sni-tls-extension/
- https://www.haproxy.com/blog/haproxy/proxy-protocol/
- https://docs.nginx.com/nginx/admin-guide/load-balancer/using-proxy-protocol/


AUTHORS
-------
ungleich <foss--@--ungleich.ch>
Evilham <cvs--@--evilham.com>


COPYING
-------
Copyright \(C) 2021 ungleich glarus ag. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
