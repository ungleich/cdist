cdist-type__nfs_export(7)
=========================
Manage nfs exports

Steven Armstrong <steven-cdist--@--armstrong.cc>


DESCRIPTION
-----------
This cdist type allows you to manage entries in /etc/exports.d.
For older distributions (currently ubuntu lucid) that don't support 
/etc/exports.d the entries are merged into the /etc/exports file.


REQUIRED PARAMETERS
-------------------
client
   space delimited list of client ip/networks for use in /etc/exports. See exports(5)


OPTIONAL PARAMETERS
-------------------
options
   export options for use in /etc/exports. See exports(5)

export
   the directory to export. Defaults to object_id

state
   Either present or absent. Defaults to present.


EXAMPLES
--------

.. code-block:: sh

    __nfs_export /local/chroot/lucid-amd64 \
       --client "192.168.0.1/24 10.0.0.1/16" \
       --options "ro,async,no_all_squash,no_root_squash,subtree_check"


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_
- exports(5)


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
