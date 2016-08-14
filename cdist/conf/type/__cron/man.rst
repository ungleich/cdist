cdist-type__cron(7)
===================

NAME
----
cdist-type__cron - Installs and manages cron jobs


DESCRIPTION
-----------
This cdist type allows you to manage entries in a users crontab.


REQUIRED PARAMETERS
-------------------
user
   The user who's crontab is edited
command
   The command to run.


OPTIONAL PARAMETERS
-------------------
state
   Either present or absent. Defaults to present.
minute
   See crontab(5). Defaults to *
hour
   See crontab(5). Defaults to *
day_of_month
   See crontab(5). Defaults to *
month
   See crontab(5). Defaults to *
day_of_week
   See crontab(5). Defaults to *
raw
   Take whatever the user has given instead of time and date fields.
   If given, all other time and date fields are ignored.
   Can for example be used to specify cron EXTENSIONS like reboot, yearly etc.
   See crontab(5) for the extensions if any that your cron implementation
   implements.
raw_command
   Take whatever the user has given in the command and ignore everything else.
   If given, the command will be added to crontab.
   Can for example be used to define variables like SHELL or MAILTO.


EXAMPLES
--------

.. code-block:: sh

    # run Monday to Saturday at 23:15
    __cron some-id --user root --command "/path/to/script" \
       --hour 23 --minute 15 --day_of_week 1-6

    # run on reboot
    __cron some-id --user root --command "/path/to/script" \
       --raw @reboot

    # remove cronjob
    __cron some-id --user root --command "/path/to/script" --state absent

    # define default shell
    __cron some-id --user root --raw_command --command "SHELL=/bin/bash" \
       --state present


SEE ALSO
--------
:strong:`crontab`\ (5)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011-2013 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
