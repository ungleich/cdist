cdist-type__prometheus_alertmanager(7)
======================================

NAME
----
cdist-type__prometheus_alertmanager - install Alertmanager


DESCRIPTION
-----------
Install and configure Prometheus Alertmanager (https://prometheus.io/docs/alerting/alertmanager/).

This type create a daemontools-compatible service directory under /service/prometheus.
Daemontools (or something compatible) must be installed (in particular, the command `svc` must be executable).


REQUIRED PARAMETERS
-------------------
config
   Alertmanager configuration file. It will be saved as /etc/alertmanager/alertmanager.yml on the target.
listen-address
   Passed as web.listen-address.


OPTIONAL PARAMETERS
-------------------
storage-path
   Where to put data. Default: /data/alertmanager. (Directory will be created if needed.)


BOOLEAN PARAMETERS
------------------
None


EXAMPLES
--------

.. code-block:: sh

    ALERTPORT=9093

    __daemontools
    __golang_from_vendor --version 1.8.1  # required for prometheus and many exporters

    require="__daemontools __golang_from_vendor" __prometheus_alertmanager \
      --with-daemontools \
      --config "$__manifest/files/alertmanager.yml" \
      --storage-path /data/alertmanager \
      --listen-address "[::]:$ALERTPORT"


SEE ALSO
--------
:strong:`cdist-type__prometheus_server`\ (7), :strong:`cdist-type__daemontools`\ (7),
Prometheus alerting documentation: https://prometheus.io/docs/alerting/overview/

AUTHORS
-------
Kamila Součková <kamila--@--ksp.sk>

COPYING
-------
Copyright \(C) 2017 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
