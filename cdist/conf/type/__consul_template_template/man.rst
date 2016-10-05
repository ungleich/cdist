cdist-type__consul_template_template(7)
=======================================

NAME
----
cdist-type__consul_template_template - Manage consul-template templates


DESCRIPTION
-----------
Generate and deploy template definitions for a consul-template.
See https://github.com/hashicorp/consul-template#examples for documentation.
Templates are written in the Go template format.
Either the --source or the --source-file parameter must be given.


REQUIRED PARAMETERS
-------------------
destination
   the destination where the generated file should go.


OPTIONAL PARAMETERS
-------------------
command
   an optional command to run after rendering the template to its destination.

source
   path to the template source. Conflicts --source-file.

source-file
   path to a local file which is uploaded using the __file type and configured
   as the source.
   If source is '-' (dash), take what was written to stdin as the file content.
   Conflicts --source.

state
   if this template is 'present' or 'absent'. Defaults to 'present'.

wait
   The `minimum(:maximum)` time to wait before rendering a new template to
   disk and triggering a command, separated by a colon (`:`). If the optional
   maximum value is omitted, it is assumed to be 4x the required minimum value.
   This is a numeric time with a unit suffix ("5s"). There is no default value.
   The wait value for a template takes precedence over any globally-configured
   wait.


EXAMPLES
--------

.. code-block:: sh

    # configure template on the target
    __consul_template_template nginx \
       --source /etc/my-consul-templates/nginx.ctmpl \
       --destination /etc/nginx/nginx.conf \
       --command 'service nginx restart'


    # upload a local file to the target and configure it
    __consul_template_template nginx \
       --wait '2s:6s' \
       --source-file "$__manifest/files/nginx.ctmpl" \
       --destination /etc/nginx/nginx.conf \
       --command 'service nginx restart'


SEE ALSO
--------
:strong:`cdist-type__consul_template`\ (7), :strong:`cdist-type__consul_template_config`\ (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2015-2016 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
