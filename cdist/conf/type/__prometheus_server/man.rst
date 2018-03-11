cdist-type__prometheus_server(7)
================================

NAME
----
cdist-type__prometheus_server - install Prometheus


DESCRIPTION
-----------
Install and configure Prometheus (https://prometheus.io/).

Note that due to significant differences between Prometheus 1.x and 2.x, only 2.x is supported. It is your responsibility to make sure that your package manager installs 2.x. (On Devuan Ascii, the parameter `--install-from-backports` helps.)

REQUIRED PARAMETERS
-------------------
config
   Prometheus configuration file. It will be saved as /etc/prometheus/prometheus.yml on the target.


OPTIONAL PARAMETERS
-------------------
retention-days
   How long to keep data. Default: 30
rule-files
   Path to rule files. They will be installed under /etc/prometheus/<filename>. You need to include `rule_files: [/etc/prometheus/<your-pattern>]` in the config file if you use this.
storage-path
   Where to put data. Default: /data/prometheus. (Directory will be created if needed.)


BOOLEAN PARAMETERS
------------------
install-from-backports
   Valid on Devuan only. Will enable the backports apt source and install the package from there. Useful for getting a newer version.


EXAMPLES
--------

.. code-block:: sh

    PROMPORT=9090
    ALERTPORT=9093

    __prometheus_server \
        --install-from-backports \
        --config "$__manifest/files/prometheus.yml" \
        --retention-days 14 \
        --storage-path /data/prometheus \
        --rule-files "$__manifest/files/*.rules"


SEE ALSO
--------
:strong:`cdist-type__prometheus_alertmanager`\ (7), :strong:`cdist-type__grafana_dashboard`\ (7),
Prometheus documentation: https://prometheus.io/docs/introduction/overview/

AUTHORS
-------
Kamila Součková <kamila--@--ksp.sk>

COPYING
-------
Copyright \(C) 2018 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
