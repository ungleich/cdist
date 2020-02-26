cdist-type__matrix_riot(7)
======================

NAME
----
cdist-type__matrix_riot - Install and configure Riot, a web Matrix client.


DESCRIPTION
-----------
This type install and configure the Riot web client.


REQUIRED PARAMETERS
-------------------
install_dir
  Root directory of Riot's static files.

version
  Release of Riot to install.

OPTIONAL PARAMETERS
-------------------
default_server_name
  Name of matrix homeserver to connect to, defaults to 'matrix.org'.

default_server_url
  URL of matrix homeserver to connect to, defaults to 'https://matrix-client.matrix.org'.

owner
  Owner of the deployed files, passed to `chown`. Defaults to 'root'.

brand
  Web UI branding, defaults to 'Riot'.

default_country_code
  ISO 3166 alpha2 country code to use when showing country selectors, such as
  phone number inputs. Defaults to GB.

privacy_policy_url
  Defaults to 'https://riot.im/privacy'.

cookie_policy_url
  Defaults to 'https://matrix.org/docs/guides/riot_im_cookie_policy'.

homepage
  Path to custom Riot homepage, displayed once logged in.

EXAMPLES
--------

.. code-block:: sh

    __matrix_riot my-riot --install_dir /var/www/riot-web --version 1.5.6


SEE ALSO
--------
- `cdist-type__matrix_synapse(7) <cdist-type__matrix_synapse.html>`_


AUTHORS
-------
Timothée Floure <timothee.floure@ungleich.ch>


COPYING
-------
Copyright \(C) 2019 Timothée Floure. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
