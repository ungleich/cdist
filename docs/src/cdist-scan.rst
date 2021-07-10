Scan
=====

Description
-----------
Runs cdist as a daemon that discover/watch on hosts and reconfigure them
periodically. It is especially useful in netboot-based environment where hosts
boot unconfigured, and to ensure your infrastructure stays in sync with your
configuration.

This feature is still consider to be in **beta** stage, and only operate on
IPv6 (including link-local).

Usage (Examples)
----------------

Discover hosts on local network and configure those whose name is resolved by
the name mapper script.

.. code-block:: sh

    $ cdist scan --beta --interface eth0 \
      --mode scan --name-mapper path/to/script \
      --mode trigger --mode config

List known hosts and exit.

.. code-block:: sh

    $ cdist scan --beta --list --name-mapper path/to/script

Please refer to `cdist(1)` for a detailed list of parameters.

Modes
-----

The scanner has 3 modes that can be independently toggled. If the `--mode`
parameter is not specified, only `tigger` and `scan` are enabled (= hosts are
not configured).

trigger
  Send ICMPv6 requests to specific hosts or broadcast over IPv6 link-local to
  trigger detection by the `scan` module.

scan
  Watch for incoming ICMPv6 replies and optionally configure detected hosts.

config
  Enable configuration of hosts detected by `scan`.

Name Mapper Script
------------------

The name mapper script takes an IPv6 address as first argument and writes the
resolved name to stdout - if any. The script must be executable.

Simplest script:

.. code-block:: sh

  #!/bin/sh

  case "$1" in
  	"fe80::20d:b9ff:fe57:3524")
  		printf "my-host-01"
  		;;
  	"fe80::7603:bdff:fe05:89bb")
  		printf "my-host-02"
  		;;
  esac

Resolving name from `PTR` DNS record:

.. code-block:: sh

  #!/bin/sh

  for cmd in dig sed; do
  	if ! command -v $cmd > /dev/null; then
  		exit 1
  	fi
  done

  dig +short -x "$1" | sed -e 's/.$//'
