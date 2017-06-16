cdist-type__prometheus_server(7)
================================

NAME
----
cdist-type__prometheus_server - install Prometheus


DESCRIPTION
-----------
Install and configure Prometheus (https://prometheus.io/).

This type creates a daemontools-compatible service directory under /service/prometheus.
Daemontools (or something compatible) must be installed (in particular, the command `svc` must be executable).


REQUIRED PARAMETERS
-------------------
config
   Prometheus configuration file. It will be saved as /etc/prometheus/prometheus.yml on the target.
listen-address
   Passed as web.listen-address.
alertmanager-url
   Passed as alertmanager.url


OPTIONAL PARAMETERS
-------------------
retention-days
   How long to keep data. Default: 30
rule-files
   Path to rule files. They will be installed under /etc/prometheus/<filename>. You need to include `rule_files: [/etc/prometheus/<your-pattern>]` in the config file if you use this.
storage-path
   Where to put data. Default: /data/prometheus. (Directory will be created if needed.)
target-heap-size
   Passed as storage.local.target-heap-size. Default: 1/2 of RAM.


BOOLEAN PARAMETERS
------------------
None


EXAMPLES
--------

.. code-block:: sh

    PROMPORT=9090
    ALERTPORT=9093

    __daemontools
    __golang_from_vendor --version 1.8.1  # required for prometheus and many exporters

    require="__daemontools __golang_from_vendor" __prometheus_server \
        --with-daemontools \
        --config "$__manifest/files/prometheus.yml" \
        --retention-days 14 \
        --storage-path /data/prometheus \
        --listen-address "[::]:$PROMPORT" \
        --rule-files "$__manifest/files/*.rules" \
        --alertmanager-url "http://monitoring1.node.consul:$ALERTPORT,http://monitoring2.node.consul:$ALERTPORT"


SEE ALSO
--------
:strong:`cdist-type__prometheus_alertmanager`\ (7), :strong:`cdist-type__daemontools`\ (7),
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
