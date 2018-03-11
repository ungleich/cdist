cdist-type__prometheus_alertmanager(7)
======================================

NAME
----
cdist-type__prometheus_alertmanager - install Alertmanager


DESCRIPTION
-----------
Install and configure Prometheus Alertmanager (https://prometheus.io/docs/alerting/alertmanager/).

Note that due to significant differences between Prometheus 1.x and 2.x, only 2.x is supported. It is your responsibility to make sure that your package manager installs 2.x. (On Devuan Ascii, the parameter `--install-from-backports` helps.)


REQUIRED PARAMETERS
-------------------
config
   Alertmanager configuration file. It will be saved as /etc/alertmanager/alertmanager.yml on the target.


OPTIONAL PARAMETERS
-------------------
storage-path
   Where to put data. Default: /data/alertmanager. (Directory will be created if needed.)
retention-days
   How long to retain data. Default: 90 days.


BOOLEAN PARAMETERS
------------------
install-from-backports
   Valid on Devuan only. Will enable the backports apt source and install the package from there. Useful for getting a newer version.


EXAMPLES
--------

.. code-block:: sh

    __prometheus_alertmanager \
        --install-from-backports \
        --config "$__manifest/files/alertmanager.yml" \
        --storage-path /data/alertmanager


SEE ALSO
--------
:strong:`cdist-type__prometheus_server`\ (7), :strong:`cdist-type__grafana_dashboard`\ (7),
Prometheus alerting documentation: https://prometheus.io/docs/alerting/overview/

AUTHORS
-------
Kamila Součková <kamila--@--ksp.sk>

COPYING
-------
Copyright \(C) 2018 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
