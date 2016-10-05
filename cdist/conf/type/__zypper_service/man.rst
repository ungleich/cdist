cdist-type__zypper_service(7)
=============================

NAME
----
cdist-type__zypper_service - Service management with zypper


DESCRIPTION
-----------
zypper is usually used on SuSE systems to manage services.


REQUIRED PARAMETERS
-------------------
uri
    Uri of the service


OPTIONAL PARAMETERS
-------------------
service_desc
    If supplied, use the service_desc and not the object id as description for the service.

state
    Either "present" or "absent", defaults to "present"

type
    Defaults to "ris", the standard type of services at SLES11. For other values, see manpage of zypper.


BOOLEAN PARAMETERS
------------------
remove-all-other-services
   Drop all other services found on the target host before adding the new one.

remove-all-repos
   If supplied, remove all existing repos prior to setup the new service.


EXAMPLES
--------

.. code-block:: sh

    # Ensure that internal SLES11 SP3 RIS is in installed and all other services and repos are discarded
    __zypper_service INTERNAL_SLES11_SP3 --service_desc "Internal SLES11 SP3 RIS" --uri "http://path/to/your/ris/dir" --remove-all-other-services --remove-all-repos

    # Ensure that internal SLES11 SP3 RIS is in installed, no changes to ohter services or repos
    __zypper_service INTERNAL_SLES11_SP3 --service_desc "Internal SLES11 SP3 RIS" --uri "http://path/to/your/ris/dir"

    # Drop service by uri, no changes to ohter services or repos
    __zypper_service INTERNAL_SLES11_SP3 --state absent --uri "http://path/to/your/ris/dir"


AUTHORS
-------
Daniel Heule <hda--@--sfs.biz>


COPYING
-------
Copyright \(C) 2013 Daniel Heule. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
