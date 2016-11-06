PreOS
=====

Description
-----------
With cdist you can install and configure new machines. First you need to boot
new machines. You can use cdist for this. You use cdist to create PreOS,
minimal OS which purpose is to boot new machine. After that machine is ready
for installing and configuring.

PreOS creation
--------------
With cdist you can create PreOS. Currently, supported PreOS-es include:

* debian
* ubuntu.

PreOS is created using cdist preos command, for example, to create ubuntu
PreOS you use:

.. code-block:: sh

    $ cdist preos ubuntu /preos/preos-ubuntu -b -C \
        -k ~/.ssh/id_rsa.pub -p /preos/pxe-ubuntu \
        -t "/usr/bin/curl 192.168.111.5:3000/install/"

For more info about available options see cdist manual page.

This will bootstrap (-b) ubuntu PreOS in '/preos/preos-ubuntu' directory, it
will be configured (-C) with specified ssh authorized key (-k) and with
specified trigger command (-t). After bootstrapping and configuration PXE
boot directory will be created (p) in '/preos/pxe-ubuntu'.

After PreOS is created new machines can be booted using created PXE (after
proper dhcp, tftp setting).

While PreOS is configured with ssh authorized key it can be accessed throguh
ssh, i.e. it can be further installed and configured with cdist.

Triggering installation/configuration
-------------------------------------
When installing and configuring new machines using cdist's PreOS concept
cdist also supports triggering for host installation/configuration.
At management node you start trigger server as:

.. code-block:: sh

    $ cdist trigger -b -v -i ~/.cdist/manifest/init-for-triggered

This will start cdist trigger server in verbose mode. It accepts simple
requests for configuration and for installation:

* :strong:`/install/.*` for installation
* :strong:`/config/.*` for configuration.

When new machine is booted with PreOS then trigger command is executed.
Machine will connect to cdist trigger server. If the request is, for example,
for installation then cdist trigger server will start install command for the
client host using parameters specified at trigger server startup. For the
above example that means that client will be installed using specified initial
manifest '~/.cdist/manifest/init-for-triggered'.

Implementing new PreOS sub-command
----------------------------------
TODO: describe preos plugin system and how to add new preos/preos sub-command
You can create your custom PreOS-es in ~/.cdist/preos directory. Create it if
it does not exist.
