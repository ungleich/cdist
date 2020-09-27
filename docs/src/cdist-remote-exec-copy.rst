Remote exec and copy commands
=============================

Cdist interacts with the target host in two ways:

- it executes code (__remote_exec)
- and it copies files (__remote_copy)

By default this is accomplished with ssh and scp respectively.
The default implementations used by cdist are::

    __remote_exec: ssh -o User=root
    __remote_copy: scp -o User=root -q

The user can override these defaults by providing custom implementations and
passing them to cdist with the --remote-exec and/or --remote-copy arguments.

For __remote_exec, the custom implementation must behave as if it where ssh.
For __remote_copy, it must behave like scp.
Please notice, custom implementations should work like ssh/scp so __remote_copy
must support IPv6 addresses enclosed in square brackets. For __remote_exec you
must take into account that for some options (like -L) IPv6 addresses can be
specified by enclosed in square brackets (see :strong:`ssh`\ (1) and
:strong:`scp`\ (1)).

With this simple interface the user can take total control of how cdist
interacts with the target when required, while the default implementation 
remains as simple as possible.


Examples
--------

Here are examples of using alternative __remote_copy and __remote_exec scripts.

All scripts from below are present in cdist sources in `other/examples/remote`
directory.

ssh
~~~

Same as cdist default.

**copy**

Usage: cdist config --remote-copy "/path/to/this/script" target_host

.. code-block:: sh

    #echo "$@" | logger -t "cdist-ssh-copy"
    scp -o User=root -q $@

**exec**

Usage: cdist config --remote-exec "/path/to/this/script" target_host

.. code-block:: sh

    #echo "$@" | logger -t "cdist-ssh-exec"
    ssh -o User=root $@

local
~~~~~

This effectively turns remote calling into local calling. Probably most useful
for the unit testing.

**copy**

.. code-block:: sh

    code="$(echo "$@" | sed "s|\([[:space:]]\)$__target_host:|\1|g")"
    cp -L $code

**exec**

.. code-block:: sh

    target_host=$1; shift
    echo "$@" | /bin/sh 

chroot
~~~~~~

**copy**

Usage: cdist config --remote-copy "/path/to/this/script /path/to/your/chroot" target-id

.. code-block:: sh

    log() {
       #echo "$@" | logger -t "cdist-chroot-copy"
       :
    }

    chroot="$1"; shift
    target_host="$__target_host"

    # replace target_host with chroot location
    code="$(echo "$@" | sed "s|$target_host:|$chroot|g")"

    log "target_host: $target_host"
    log "chroot: $chroot"
    log "$@"
    log "$code"

    # copy files into chroot
    cp $code

    log "-----"

**exec**

Usage: cdist config --remote-exec "/path/to/this/script /path/to/your/chroot" target-id

.. code-block:: sh

    log() {
       #echo "$@" | logger -t "cdist-chroot-exec"
       :
    }

    chroot="$1"; shift
    target_host="$1"; shift

    script=$(mktemp "${chroot}/tmp/chroot-${0##*/}.XXXXXXXXXX")
    trap cleanup INT TERM EXIT
    cleanup() {
       [ $__cdist_debug ] || rm "$script"
    }

    log "target_host: $target_host"
    log "script: $script"
    log "@: $@"
    echo "#!/bin/sh -l" > "$script"
    echo "$@" >> "$script"
    chmod +x "$script"

    relative_script="${script#$chroot}"
    log "relative_script: $relative_script"

    # run in chroot
    chroot "$chroot" "$relative_script"

    log "-----"

rsync
~~~~~

**copy**

Usage: cdist config --remote-copy /path/to/this/script target_host

.. code-block:: sh

    # For rsync to do the right thing, the source has to end with "/" if it is
    # a directory. The below preprocessor loop takes care of that.

    # second last argument is the source
    source_index=$(($#-1))
    index=0
    for arg in $@; do
       if [ $index -eq 0 ]; then
          # reset $@
          set --
       fi
       index=$((index+=1))
       if [ $index -eq $source_index -a -d "$arg" ]; then
          arg="${arg%/}/"
       fi
       set -- "$@" "$arg"
    done

    rsync --backup --suffix=~cdist -e 'ssh -o User=root' $@

schroot
~~~~~~~

__remote_copy and __remote_exec scripts to run cdist against a chroot on the
target host over ssh.

**copy**

Usage: cdist config --remote-copy "/path/to/this/script schroot-chroot-name" target_host


.. code-block:: sh

    log() {
       #echo "$@" | logger -t "cdist-schroot-copy"
       :
    }

    chroot_name="$1"; shift
    target_host="$__target_host"

    # get directory for given chroot_name
    chroot="$(ssh -o User=root -q $target_host schroot -c $chroot_name --config | awk -F = '/directory=/ {print $2}')"

    # prefix destination with chroot
    code="$(echo "$@" | sed "s|$target_host:|$target_host:$chroot|g")"

    log "target_host: $target_host"
    log "chroot_name: $chroot_name"
    log "chroot: $chroot"
    log "@: $@"
    log "code: $code"

    # copy files into remote chroot
    scp -o User=root -q $code

    log "-----"

**exec**

Usage: cdist config --remote-exec "/path/to/this/script schroot-chroot-name" target_host

.. code-block:: sh

    log() {
       #echo "$@" | logger -t "cdist-schroot-exec"
       :
    }

    chroot_name="$1"; shift
    target_host="$1"; shift

    code="ssh -o User=root -q $target_host schroot -c $chroot_name -- $@"

    log "target_host: $target_host"
    log "chroot_name: $chroot_name"
    log "@: $@"
    log "code: $code"

    # run in remote chroot
    $code

    log "-----"

schroot-uri
~~~~~~~~~~~

__remote_exec/__remote_copy script to run cdist against a schroot target URI.

Usage::

    cdist config \
        --remote-exec "/path/to/this/script exec" \
        --remote-copy "/path/to/this/script copy" \
        target_uri

    # target_uri examples:
    schroot:///chroot-name
    schroot://foo.ethz.ch/chroot-name
    schroot://user-name@foo.ethz.ch/chroot-name

    # and how to match them in .../manifest/init
    case "$target_host" in
    schroot://*)
        # any schroot
    ;;
    schroot://foo.ethz.ch/*)
        # any schroot on specific host
    ;;
    schroot://foo.ethz.ch/chroot-name)
        # specific schroot on specific host
    ;;
    schroot:///chroot-name)
        # specific schroot on localhost
    ;;
    esac

**copy/exec**

.. code-block:: sh

    my_name="${0##*/}"
    mode="$1"; shift

    log() {
       # uncomment me for debugging
       #echo "$@" | logger -t "cdist-$my_name-$mode"
       :
    }

    die() {
       echo "$@" >&2
       exit 1
    }


    uri="$__target_host"

    scheme="${uri%%:*}"; rest="${uri#$scheme:}"; rest="${rest#//}"
    authority="${rest%%/*}"; rest="${rest#$authority}"
    path="${rest%\?*}"; rest="${rest#$path}"
    schroot_name="${path#/}"

    [ "$scheme" = "schroot" ] || die "Failed to parse scheme from __target_host ($__target_host). Expected 'schroot', got '$scheme'"
    [ -n "$schroot_name" ] || die "Failed to parse schroot name from __target_host: $__target_host"

    case "$authority" in
       '')
          # authority is empty, neither user nor host given
          user=""
          host=""
       ;; 
       *@*)
          # authority contains @, take user from authority
          user="${authority%@*}"
          host="${authority#*@}"
       ;; 
       *) 
          # no user in authority, default to root
          user="root"
          host="$authority"
       ;;
    esac

    log "mode: $mode"
    log "@: $@"
    log "uri: $uri"
    log "scheme: $scheme"
    log "authority: $authority"
    log "user: $user"
    log "host: $host"
    log "path: $path"
    log "schroot_name: $schroot_name"

    exec_prefix=""
    copy_prefix=""
    if [ -n "$host" ]; then
       # we are working on a remote host
       exec_prefix="ssh -o User=$user -q $host"
       copy_prefix="scp -o User=$user -q"
       copy_destination_prefix="$host:"
    else
       # working on local machine
       copy_prefix="cp"
       copy_destination_prefix=""
    fi
    log "exec_prefix: $exec_prefix"
    log "copy_prefix: $copy_prefix"
    log "copy_destination_prefix: $copy_destination_prefix"

    case "$mode" in
       exec)
          # In exec mode the first argument is the __target_host which we already got from env. Get rid of it.
          shift
          code="$exec_prefix schroot -c $schroot_name -- sh -c '$@'"
       ;;
       copy)
          # get directory for given chroot_name
          schroot_directory="$($exec_prefix schroot -c $schroot_name --config | awk -F = '/directory=/ {print $2}')"
          [ -n "$schroot_directory" ] || die "Failed to retreive schroot directory for schroot: $schroot_name"
          log "schroot_directory: $schroot_directory"
          # prefix destination with chroot
          code="$copy_prefix $(echo "$@" | sed "s|$uri:|${copy_destination_prefix}${schroot_directory}|g")"
       ;;
       *) die "Unknown mode: $mode";;
    esac

    log "code: $code"

    # Run the code
    $code

    log "-----"

sudo
~~~~

**copy**

Use rsync over ssh to copy files. Uses the "--rsync-path" option
to run the remote rsync instance with sudo.

This command assumes your ssh configuration is already set up in ~/.ssh/config.

Usage: cdist config --remote-copy /path/to/this/script target_host

.. code-block:: sh

    # For rsync to do the right thing, the source has to end with "/" if it is
    # a directory. The below preprocessor loop takes care of that.

    # second last argument is the source
    source_index=$(($#-1))
    index=0
    for arg in $@; do
       if [ $index -eq 0 ]; then
          # reset $@
          set --
       fi
       index=$((index+=1))
       if [ $index -eq $source_index -a -d "$arg" ]; then
          arg="${arg%/}/"
       fi
       set -- "$@" "$arg"
    done

    rsync --copy-links --rsync-path="sudo rsync" -e 'ssh' "$@"

**exec**

Prefixes all remote commands with sudo.

This command assumes your ssh configuration is already set up in ~/.ssh/config.

Usage: cdist config --remote-exec "/path/to/this/script" target_host

.. code-block:: sh

    host="$1"; shift
    ssh -q "$host" sudo sh -c \""$@"\"
