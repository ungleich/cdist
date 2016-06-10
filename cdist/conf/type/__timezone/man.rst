cdist-type__timezone(7)
=======================
Allows one to configure the desired localtime timezone.

Ramon Salvadó <rsalvado--@--gnuine--dot--com>


DESCRIPTION
-----------
This type creates a symlink (/etc/localtime) to the selected timezone
(which should be available in /usr/share/zoneinfo).


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
None.


EXAMPLES
--------

.. code-block:: sh

    #Set up Europe/Andorra as our timezone.
    __timezone Europe/Andorra

    #Set up US/Central as our timezone.
    __timezone US/Central


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_


COPYING
-------
Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
