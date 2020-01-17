cdist-type__apt_unattended_upgrades(7)
======================================

NAME
----
cdist-type__apt_unattended_upgrades - automatic installation of updates


DESCRIPTION
-----------

Install and configure unattended-upgrades package.

For more information see https://wiki.debian.org/UnattendedUpgrades.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
option
   Set options for unattended-upgrades. See examples.

   Supported options with default values (as of 2020-01-17) are:

   - AutoFixInterruptedDpkg, default is "true"
   - MinimalSteps, default is "true"
   - InstallOnShutdown, default is "false"
   - Mail, default is "" (empty)
   - MailOnlyOnError, default is "false"
   - Remove-Unused-Kernel-Packages, default is "true"
   - Remove-New-Unused-Dependencies, default is "true"
   - Remove-Unused-Dependencies, default is "false"
   - Automatic-Reboot, default is "false"
   - Automatic-Reboot-WithUsers, default is "true"
   - Automatic-Reboot-Time, default is "02:00"
   - SyslogEnable, default is "false"
   - SyslogFacility, default is "daemon"
   - OnlyOnACPower, default is "true"
   - Skip-Updates-On-Metered-Connections, default is "true"
   - Verbose, default is "false"
   - Debug, default is "false"

blacklist
   Python regular expressions, matching packages to exclude from upgrading.


EXAMPLES
--------

.. code-block:: sh

    __apt_unattended_upgrades \
        --option Mail=root \
        --option MailOnlyOnError=true \
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
