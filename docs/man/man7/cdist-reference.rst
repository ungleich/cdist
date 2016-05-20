cdist-reference(7)
==================
Variable, path and type reference for cdist

Nico Schottelius <nico-cdist--@--schottelius.org>


EXPLORERS
---------
The following global explorers are available:

- cpu_cores
- cpu_sockets
- hostname
- init
- interfaces
- lsb_codename
- lsb_description
- lsb_id
- lsb_release
- machine
- machine_type
- memory
- os
- os_version
- runlevel

PATHS
-----
$HOME/.cdist
    The standard cdist configuration directory relative to your home directory
    This is usually the place you want to store your site specific configuration

cdist/conf/
    The distribution configuration directory
    This contains types and explorers to be used

confdir
    Cdist will use all available configuration directories and create
    a temporary confdir containing links to the real configuration directories.
    This way it is possible to merge configuration directories.
    By default it consists of everything in $HOME/.cdist and cdist/conf/.
    For more details see cdist(1)

confdir/manifest/init
    This is the central entry point.
    It is an executable (+x bit set) shell script that can use
    values from the explorers to decide which configuration to create
    for the specified target host.
    Its intent is to used to define mapping from configurations to hosts.

confdir/manifest/*
    All other files in this directory are not directly used by cdist, but you
    can separate configuration mappings, if you have a lot of code in the
    conf/manifest/init file. This may also be helpful to have different admins
    maintain different groups of hosts.

confdir/explorer/<name>
    Contains explorers to be run on the target hosts, see cdist-explorer(7).

confdir/type/
    Contains all available types, which are used to provide
    some kind of functionality. See cdist-type(7).

confdir/type/<name>/
    Home of the type <name>.
    This directory is referenced by the variable __type (see below).

confdir/type/<name>/man.rst
    Manpage in reStructuredText format (required for inclusion into upstream)

confdir/type/<name>/manifest
    Used to generate additional objects from a type.

confdir/type/<name>/gencode-local
    Used to generate code to be executed on the source host

confdir/type/<name>/gencode-remote
    Used to generate code to be executed on the target host

confdir/type/<name>/parameter/required
    Parameters required by type, \n separated list.

confdir/type/<name>/parameter/optional
    Parameters optionally accepted by type, \n separated list.

confdir/type/<name>/parameter/default/*
    Default values for optional parameters.
    Assuming an optional parameter name of 'foo', it's default value would
    be read from the file confdir/type/<name>/parameter/default/foo.

confdir/type/<name>/parameter/boolean
    Boolean parameters accepted by type, \n separated list.

confdir/type/<name>/explorer
    Location of the type specific explorers.
    This directory is referenced by the variable __type_explorer (see below).
    See cdist-explorer(7).

confdir/type/<name>/files
    This directory is reserved for user data and will not be used
    by cdist at any time. It can be used for storing supplementary
    files (like scripts to act as a template or configuration files).

out/
    This directory contains output of cdist and is usually located
    in a temporary directory and thus will be removed after the run.
    This directory is referenced by the variable __global (see below).

out/explorer
    Output of general explorers.

out/object
    Objects created for the host.

out/object/<object>
    Contains all object specific information.
    This directory is referenced by the variable __object (see below).

out/object/<object>/explorers
    Output of type specific explorers, per object.

TYPES
-----
The following types are available:

- \__apt_key (`cdist-type__apt_key(7) <cdist-type__apt_key.html>`_)
- \__apt_key_uri (`cdist-type__apt_key_uri(7) <cdist-type__apt_key_uri.html>`_)
- \__apt_norecommends (`cdist-type__apt_norecommends(7) <cdist-type__apt_norecommends.html>`_)
- \__apt_ppa (`cdist-type__apt_ppa(7) <cdist-type__apt_ppa.html>`_)
- \__apt_source (`cdist-type__apt_source(7) <cdist-type__apt_source.html>`_)
- \__apt_update_index (`cdist-type__apt_update_index(7) <cdist-type__apt_update_index.html>`_)
- \__block (`cdist-type__block(7) <cdist-type__block.html>`_)
- \__ccollect_source (`cdist-type__ccollect_source(7) <cdist-type__ccollect_source.html>`_)
- \__cdist (`cdist-type__cdist(7) <cdist-type__cdist.html>`_)
- \__cdistmarker (`cdist-type__cdistmarker(7) <cdist-type__cdistmarker.html>`_)
- \__config_file (`cdist-type__config_file(7) <cdist-type__config_file.html>`_)
- \__consul (`cdist-type__consul(7) <cdist-type__consul.html>`_)
- \__consul_agent (`cdist-type__consul_agent(7) <cdist-type__consul_agent.html>`_)
- \__consul_check (`cdist-type__consul_check(7) <cdist-type__consul_check.html>`_)
- \__consul_reload (`cdist-type__consul_reload(7) <cdist-type__consul_reload.html>`_)
- \__consul_service (`cdist-type__consul_service(7) <cdist-type__consul_service.html>`_)
- \__consul_template (`cdist-type__consul_template(7) <cdist-type__consul_template.html>`_)
- \__consul_template_template (`cdist-type__consul_template_template(7) <cdist-type__consul_template_template.html>`_)
- \__consul_watch_checks (`cdist-type__consul_watch_checks(7) <cdist-type__consul_watch_checks.html>`_)
- \__consul_watch_event (`cdist-type__consul_watch_event(7) <cdist-type__consul_watch_event.html>`_)
- \__consul_watch_key (`cdist-type__consul_watch_key(7) <cdist-type__consul_watch_key.html>`_)
- \__consul_watch_keyprefix (`cdist-type__consul_watch_keyprefix(7) <cdist-type__consul_watch_keyprefix.html>`_)
- \__consul_watch_nodes (`cdist-type__consul_watch_nodes(7) <cdist-type__consul_watch_nodes.html>`_)
- \__consul_watch_service (`cdist-type__consul_watch_service(7) <cdist-type__consul_watch_service.html>`_)
- \__consul_watch_services (`cdist-type__consul_watch_services(7) <cdist-type__consul_watch_services.html>`_)
- \__cron (`cdist-type__cron(7) <cdist-type__cron.html>`_)
- \__debconf_set_selections (`cdist-type__debconf_set_selections(7) <cdist-type__debconf_set_selections.html>`_)
- \__directory (`cdist-type__directory(7) <cdist-type__directory.html>`_)
- \__dog_vdi (`cdist-type__dog_vdi(7) <cdist-type__dog_vdi.html>`_)
- \__file (`cdist-type__file(7) <cdist-type__file.html>`_)
- \__firewalld_rule (`cdist-type__firewalld_rule(7) <cdist-type__firewalld_rule.html>`_)
- \__git (`cdist-type__git(7) <cdist-type__git.html>`_)
- \__group (`cdist-type__group(7) <cdist-type__group.html>`_)
- \__hostname (`cdist-type__hostname(7) <cdist-type__hostname.html>`_)
- \__iptables_apply (`cdist-type__iptables_apply(7) <cdist-type__iptables_apply.html>`_)
- \__iptables_rule (`cdist-type__iptables_rule(7) <cdist-type__iptables_rule.html>`_)
- \__issue (`cdist-type__issue(7) <cdist-type__issue.html>`_)
- \__jail (`cdist-type__jail(7) <cdist-type__jail.html>`_)
- \__key_value (`cdist-type__key_value(7) <cdist-type__key_value.html>`_)
- \__line (`cdist-type__line(7) <cdist-type__line.html>`_)
- \__link (`cdist-type__link(7) <cdist-type__link.html>`_)
- \__locale (`cdist-type__locale(7) <cdist-type__locale.html>`_)
- \__motd (`cdist-type__motd(7) <cdist-type__motd.html>`_)
- \__mount (`cdist-type__mount(7) <cdist-type__mount.html>`_)
- \__mysql_database (`cdist-type__mysql_database(7) <cdist-type__mysql_database.html>`_)
- \__package (`cdist-type__package(7) <cdist-type__package.html>`_)
- \__package_apt (`cdist-type__package_apt(7) <cdist-type__package_apt.html>`_)
- \__package_emerge (`cdist-type__package_emerge(7) <cdist-type__package_emerge.html>`_)
- \__package_emerge_dependencies (`cdist-type__package_emerge_dependencies(7) <cdist-type__package_emerge_dependencies.html>`_)
- \__package_luarocks (`cdist-type__package_luarocks(7) <cdist-type__package_luarocks.html>`_)
- \__package_opkg (`cdist-type__package_opkg(7) <cdist-type__package_opkg.html>`_)
- \__package_pacman (`cdist-type__package_pacman(7) <cdist-type__package_pacman.html>`_)
- \__package_pip (`cdist-type__package_pip(7) <cdist-type__package_pip.html>`_)
- \__package_pkg_freebsd (`cdist-type__package_pkg_freebsd(7) <cdist-type__package_pkg_freebsd.html>`_)
- \__package_pkg_openbsd (`cdist-type__package_pkg_openbsd(7) <cdist-type__package_pkg_openbsd.html>`_)
- \__package_pkgng_freebsd (`cdist-type__package_pkgng_freebsd(7) <cdist-type__package_pkgng_freebsd.html>`_)
- \__package_rubygem (`cdist-type__package_rubygem(7) <cdist-type__package_rubygem.html>`_)
- \__package_update_index (`cdist-type__package_update_index(7) <cdist-type__package_update_index.html>`_)
- \__package_upgrade_all (`cdist-type__package_upgrade_all(7) <cdist-type__package_upgrade_all.html>`_)
- \__package_yum (`cdist-type__package_yum(7) <cdist-type__package_yum.html>`_)
- \__package_zypper (`cdist-type__package_zypper(7) <cdist-type__package_zypper.html>`_)
- \__pacman_conf (`cdist-type__pacman_conf(7) <cdist-type__pacman_conf.html>`_)
- \__pacman_conf_integrate (`cdist-type__pacman_conf_integrate(7) <cdist-type__pacman_conf_integrate.html>`_)
- \__pf_apply (`cdist-type__pf_apply(7) <cdist-type__pf_apply.html>`_)
- \__pf_ruleset (`cdist-type__pf_ruleset(7) <cdist-type__pf_ruleset.html>`_)
- \__postfix (`cdist-type__postfix(7) <cdist-type__postfix.html>`_)
- \__postfix_master (`cdist-type__postfix_master(7) <cdist-type__postfix_master.html>`_)
- \__postfix_postconf (`cdist-type__postfix_postconf(7) <cdist-type__postfix_postconf.html>`_)
- \__postfix_postmap (`cdist-type__postfix_postmap(7) <cdist-type__postfix_postmap.html>`_)
- \__postfix_reload (`cdist-type__postfix_reload(7) <cdist-type__postfix_reload.html>`_)
- \__postgres_database (`cdist-type__postgres_database(7) <cdist-type__postgres_database.html>`_)
- \__postgres_role (`cdist-type__postgres_role(7) <cdist-type__postgres_role.html>`_)
- \__process (`cdist-type__process(7) <cdist-type__process.html>`_)
- \__pyvenv (`cdist-type__pyvenv(7) <cdist-type__pyvenv.html>`_)
- \__qemu_img (`cdist-type__qemu_img(7) <cdist-type__qemu_img.html>`_)
- \__rbenv (`cdist-type__rbenv(7) <cdist-type__rbenv.html>`_)
- \__rsync (`cdist-type__rsync(7) <cdist-type__rsync.html>`_)
- \__rvm (`cdist-type__rvm(7) <cdist-type__rvm.html>`_)
- \__rvm_gem (`cdist-type__rvm_gem(7) <cdist-type__rvm_gem.html>`_)
- \__rvm_gemset (`cdist-type__rvm_gemset(7) <cdist-type__rvm_gemset.html>`_)
- \__rvm_ruby (`cdist-type__rvm_ruby(7) <cdist-type__rvm_ruby.html>`_)
- \__ssh_authorized_key (`cdist-type__ssh_authorized_key(7) <cdist-type__ssh_authorized_key.html>`_)
- \__ssh_authorized_keys (`cdist-type__ssh_authorized_keys(7) <cdist-type__ssh_authorized_keys.html>`_)
- \__ssh_dot_ssh (`cdist-type__ssh_dot_ssh(7) <cdist-type__ssh_dot_ssh.html>`_)
- \__staged_file (`cdist-type__staged_file(7) <cdist-type__staged_file.html>`_)
- \__start_on_boot (`cdist-type__start_on_boot(7) <cdist-type__start_on_boot.html>`_)
- \__timezone (`cdist-type__timezone(7) <cdist-type__timezone.html>`_)
- \__update_alternatives (`cdist-type__update_alternatives(7) <cdist-type__update_alternatives.html>`_)
- \__user (`cdist-type__user(7) <cdist-type__user.html>`_)
- \__user_groups (`cdist-type__user_groups(7) <cdist-type__user_groups.html>`_)
- \__yum_repo (`cdist-type__yum_repo(7) <cdist-type__yum_repo.html>`_)
- \__zypper_repo (`cdist-type__zypper_repo(7) <cdist-type__zypper_repo.html>`_)
- \__zypper_service (`cdist-type__zypper_service(7) <cdist-type__zypper_service.html>`_)


OBJECTS
-------
For object to object communication and tests, the following paths are
usable within a object directory:

files
    This directory is reserved for user data and will not be used
    by cdist at any time. It can be used freely by the type 
    (for instance to store template results).
changed
    This empty file exists in an object directory, if the object has
    code to be executed (either remote or local)
stdin
    This file exists and contains data, if data was provided on stdin 
    when the type was called.


ENVIRONMENT VARIABLES (FOR READING)
-----------------------------------
The following environment variables are exported by cdist:

__explorer
    Directory that contains all global explorers.
    Available for: initial manifest, explorer, type explorer, shell
__manifest
    Directory that contains the initial manifest.
    Available for: initial manifest, type manifest, shell
__global
    Directory that contains generic output like explorer.
    Available for: initial manifest, type manifest, type gencode, shell
__messages_in
    File to read messages from.
    Available for: initial manifest, type manifest, type gencode
__messages_out
    File to write messages.
    Available for: initial manifest, type manifest, type gencode
__object
    Directory that contains the current object.
    Available for: type manifest, type explorer, type gencode and code scripts
__object_id
    The type unique object id.
    Available for: type manifest, type explorer, type gencode and code scripts
    Note: The leading and the trailing "/" will always be stripped (caused by
    the filesystem database and ensured by the core).
    Note: Double slashes ("//") will not be fixed and result in an error.
__object_name
    The full qualified name of the current object.
    Available for: type manifest, type explorer, type gencode
__target_host
    The host we are deploying to.
    Available for: explorer, initial manifest, type explorer, type manifest, type gencode, shell
__type
    Path to the current type.
    Available for: type manifest, type gencode
__type_explorer
    Directory that contains the type explorers.
    Available for: type explorer

ENVIRONMENT VARIABLES (FOR WRITING)
-----------------------------------
The following environment variables influence the behaviour of cdist:

require
    Setup dependencies between objects (see cdist-manifest(7))

CDIST_LOCAL_SHELL
    Use this shell locally instead of /bin/sh to execute scripts

CDIST_REMOTE_SHELL
    Use this shell remotely instead of /bin/sh to execute scripts

CDIST_OVERRIDE
    Allow overwriting type parameters (see cdist-manifest(7))

CDIST_ORDER_DEPENDENCY
    Create dependencies based on the execution order (see cdist-manifest(7))

CDIST_REMOTE_EXEC
    Use this command for remote execution (should behave like ssh)

CDIST_REMOTE_COPY
    Use this command for remote copy (should behave like scp)

SEE ALSO
--------
- `cdist(1) <../man1/cdist.html>`_


COPYING
-------
Copyright \(C) 2011-2014 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
