cdist-type__apt_unattended_upgrades(7)
======================================

NAME
----
cdist-type__apt_unattended_upgrades - automatic installation of updates


DESCRIPTION
-----------

Install and configure unattended-upgrades package.


OPTIONAL PARAMETERS
-------------------
mail
   Send email to this address for problems or packages upgrades.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
blacklist
   Python regular expressions, matching packages to exclude from upgrading.


BOOLEAN PARAMETERS
------------------
mail-on-error
   Get emails only on errors.


EXAMPLES
--------

.. code-block:: sh

    __apt_unattended_upgrades \
        --mail root \
        --mail-on-error \
        --blacklist multipath-tools \
        --blacklist open-iscsi

AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2020 Ander Punnar. You can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.
