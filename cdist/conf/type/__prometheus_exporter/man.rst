cdist-type__prometheus_exporter(7)
==================================

NAME
----
cdist-type__prometheus_exporter - install some Prometheus exporters


DESCRIPTION
-----------
Install and configure some exporters to be used by the Prometheus monitoring system (https://prometheus.io/).

This type creates a daemontools-compatible service directory under /service/$__object_id.
Daemontools (or something compatible) must be installed (in particular, the command `svc` must be executable).

This type installs and builds the latest version from git, using go get. A recent version of golang as well
as build tools (make, g++, etc.) must be available.

Currently supported exporters:

- node
- blackbox
- ceph


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
exporter
   Which exporter to install and configure. Default: $__object_id.
   Currently supported: node, blackbox, ceph.


BOOLEAN PARAMETERS
------------------
add-consul-service
   Add this exporter as a Consul service for automatic service discovery.


EXAMPLES
--------

.. code-block:: sh

    __daemontools
    __golang_from_vendor --version 1.9  # required for prometheus and many exporters

    require="__daemontools __golang_from_vendor" __prometheus_exporter node


SEE ALSO
--------
:strong:`cdist-type__daemontools`\ (7), :strong:`cdist-type__golang_from_vendor`\ (7),
:strong:`cdist-type__prometheus_server`\ (7),
Prometheus documentation: https://prometheus.io/docs/introduction/overview/

AUTHORS
-------
Kamila Součková <kamila--@--ksp.sk>

COPYING
-------
Copyright \(C) 2017 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
