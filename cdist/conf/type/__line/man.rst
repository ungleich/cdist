cdist-type__line(7)
===================

NAME
----
cdist-type__line - Manage lines in files


DESCRIPTION
-----------
This cdist type allows you to add lines and remove lines from files.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
after
    Insert the given line after this pattern.

before
    Insert the given line before this pattern.

file
    If supplied, use this as the destination file.
    Otherwise the object_id is used.

line
    Specifies the line which should be absent or present.

    Must be present, if state is 'present'.
    Ignored if regex is given and state is 'absent'.

regex
    If state is 'present', search for this pattern and if it matches add
    the given line.

    If state is 'absent', ensure all lines matching the regular expression
    are absent.

    The regular expression is interpreted by awk's match function.

state
    'present' or 'absent', defaults to 'present'

onchange
    The code to run if line is added, removed or updated.


BOOLEAN PARAMETERS
------------------
None.


MESSAGES
--------
added
    The line was added.

updated
    The line or its position was changed.

removed
    The line was removed.


EXAMPLES
--------

.. code-block:: sh

    # Manage a hosts entry for www.example.com.
    __line /etc/hosts \
        --line '127.0.0.2 www.example.com'

    # Manage another hosts entry for test.example.com.
    __line hosts:test.example.com \
        --file /etc/hosts \
        --line '127.0.0.3 test.example.com'

    # Remove the line starting with TIMEZONE from the /etc/rc.conf file.
    __line legacy_timezone \
       --file /etc/rc.conf \
       --regex 'TIMEZONE=.*' \
       --state absent

    # Insert a line before another one.
    __line password-auth-local:classify \
        --file /etc/pam.d/password-auth-local \
        --line '-session required pam_exec.so debug log=/tmp/classify.log /usr/local/libexec/classify' \
        --before '^session[[:space:]]+include[[:space:]]+password-auth-ac$'

    # Insert a line after another one.
    __line password-auth-local:classify \
        --file /etc/pam.d/password-auth-local \
        --line '-session required pam_exec.so debug log=/tmp/classify.log /usr/local/libexec/classify' \
        --after '^session[[:space:]]+include[[:space:]]+password-auth-ac$'


SEE ALSO
--------
:strong:`cdist-type`\ (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2018 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
