#!/bin/sh
#
# Prevent daemons from being started at install time.
#

name="${0##*/}"
logger -i -p daemon.info -t "$name" "$name $@"

exit 101

