cdist-type__yum_repo(7)
=======================

NAME
----
cdist-type__yum_repo - Manage yum repositories


DESCRIPTION
-----------
For all undocumented parameters see yum.conf(5).


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent'. Defaults to 'present'

repositoryid
   Defaults to __object_id.

name

baseurl
   Can be specified multiple times.

metalink

mirrorlist

gpgkey
   Can be specified multiple times.

gpgcakey

gpgcheck

exclude

includepkgs

failovermethod

timeout

http_caching

retries

throttle

bandwidth

sslcacert

sslverify

sslclientcert

sslclientkey

ssl_check_cert_permissions

metadata_expire

mirrorlist_expire

proxy

proxy_username

proxy_password

username

password

cost


BOOLEAN PARAMETERS
------------------
enabled

repo_gpgcheck

disablegroups
   ! enablegroups

keepalive

skip_if_unavailable


EXAMPLES
--------

.. code-block:: sh

    __yum_repo epel \
       --name 'Extra Packages for Enterprise Linux 6 - $basearch' \
       --mirrorlist 'https://mirrors.fedoraproject.org/metalink?repo=epel-$releasever&arch=$basearch' \
       --failovermethod priority \
       --enabled \
       --gpgcheck 1 \
       --gpgkey https://fedoraproject.org/static/0608B895.txt


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2014 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
