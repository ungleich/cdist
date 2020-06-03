Dive into real world cdist
==========================

Introduction
------------

This walkthrough shows real world cdist configuration example.

Sample target host is named **test.ungleich.ch**.
Just replace **test.ungleich.ch** with your target hostname.

Our goal is to configure python application hosting. For writing sample
application we will use `Bottle <http://bottlepy.org>`_ WSGI micro web-framework.
It will use PostgreSQL database and it will list items from **items** table.
It will be served by uWSGI server. We will also use the Nginx web server
as a reverse proxy and we want HTTPS.
For HTTPS we will use Let's Encrypt certificate.

For setting up hosting we want to use cdist so we will write a new type
for that. This type will:

- install required packages
- create OS user, user home directory and application home directory
- create PostgreSQL database
- configure uWSGI
- configure Let's Encrypt certificate
- configure nginx.

Our type will not create the actual python application. Its intention is only
to configure hosting for specified user and project. It is up to the user to
create his/her applications.

So let's start.

Creating type layout
--------------------

We will create a new custom type. Let's call it **__sample_bottle_hosting**.

Go to **~/.cdist/type** directory (create it if it does not exist) and create
new type layout::

    cd ~/.cdist/type
    mkdir __sample_bottle_hosting
    cd __sample_bottle_hosting
    touch manifest gencode-remote
    mkdir parameter
    touch parameter/required

Creating __sample_bottle_hosting type parameters
------------------------------------------------

Our type will be configurable through the means of parameters. Let's define
the following parameters:

projectname
    name for the project, needed for uWSGI ini file

user
    user name

domain
    target host domain, needed for Let's Encrypt certificate.

We define parameters to make our type reusable for different projects, user and domain.

Define required parameters::

    printf "projectname\n" >> parameter/required
    printf "user\n" >> parameter/required
    printf "domain\n" >> parameter/required

For details on type parameters see `Defining parameters <cdist-type.html#defining-parameters>`_.

Creating __sample_bottle_hosting type manifest
----------------------------------------------

Next step is to define manifest (~/.cdist/type/__sample_bottle_hosting/manifest).
We also want our type to currently support only Devuan. So we will start by
checking target host OS.  We will use `os <cdist-reference.html#explorers>`_
global explorer::

    os=$(cat "$__global/explorer/os")

    case "$os" in
        devuan)
            :
        ;;
        *)
            echo "OS $os currently not supported" >&2
            exit 1
        ;;
    esac

If target host OS is not Devuan then we print error message to stderr
and exit. For other OS-es support we should check and change package names
we should install, because packages differ in different OS-es and in different
OS distributions like GNU/Linux distributions. There can also be a different
configuration locations (e.g. nginx config directory could be in /usr/local tree).
If we detected unsupported OS we should error out. cdist will stop configuration
process and output error message.

Creating user and user directories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Then we create user and his/her home directory and application home directory.
We will use existing cdist types `__user <man7/cdist-type__user.html>`_ and `__directory <man7/cdist-type__directory.html>`_::

    user="$(cat "$__object/parameter/user")"
    home="/home/$user"
    apphome="$home/app"

    # create user
    __user "$user" --home "$home" --shell /bin/bash
    # create user home dir
    require="__user/$user" __directory "$home" \
        --owner "$user" --group "$user" --mode 0755
    # create app home dir
    require="__user/$user __directory/$home" __directory "$apphome" \
        --state present --owner "$user" --group "$user" --mode 0755

First we define *user*, *home* and *apphome* variables. User is defined by type's
**user** parameter. Here we use **require** which is cdist's way to define dependencies.
User home directory should be created **after** user is created. And application
home directory is created **after** both user and user home directory are created.
For details on **require** see `Dependencies <cdist-manifest.html#dependencies>`_.

Installing packages
~~~~~~~~~~~~~~~~~~~

Install required packages using existing `__package <man7/cdist-type__package.html>`_ type.
Before installing package we want to update apt package index using
`__apt_update_index <man7/cdist-type__apt_update_index.html>`_::

    # define packages that need to be installed
    packages_to_install="nginx uwsgi-plugin-python3 python3-dev python3-pip postgresql postgresql-contrib libpq-dev python3-venv uwsgi python3-psycopg2"

    # update package index
    __apt_update_index
    # install packages
    for package in $packages_to_install
        do require="__apt_update_index" __package $package --state=present
    done

Here we use shell for loop. It executes **require="__apt_update_index" __package**
for each member in a list we define in **packages_to_install** variable.
This is much nicer then having as many **require="__apt_update_index" __package**
lines as there are packages we want to install.

For python packages we use `__package_pip <man7/cdist-type__package_pip.html>`_::

    # install pip3 packages
    for package in bottle bottle-pgsql; do
        __package_pip --pip pip3 $package
    done

Creating PostgreSQL database
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create PostgreSQL database using `__postgres_database <man7/cdist-type__postgres_database.html>`_
and `__postgres_role <man7/cdist-type__postgres_role.html>`_ for creating database user::

    #PostgreSQL db & user
    postgres_server=postgresql

    # create PostgreSQL db user
    require="__package/postgresql" __postgres_role $user --login --createdb
    # create PostgreSQL db
    require="__postgres_role/$user __package/postgresql" __postgres_database $user \
        --owner $user

Configuring uWSGI
~~~~~~~~~~~~~~~~~

Configure uWSGI using `__file <man7/cdist-type__file.html>`_ type::

    # configure uWSGI
    projectname="$(cat "$__object/parameter/projectname")"
    require="__package/uwsgi" __file /etc/uwsgi/apps-enabled/$user.ini \
                --owner root --group root --mode 0644 \
                --state present \
                --source - << EOF
    [uwsgi]
    socket = $apphome/uwsgi.sock
    chdir = $apphome
    wsgi-file = $projectname/wsgi.py
    touch-reload = $projectname/wsgi.py
    processes = 4
    threads = 2
    chmod-socket = 666
    daemonize=true
    vacuum = true
    uid = $user
    gid = $user
    EOF

We require package uWSGI present in order to create **/etc/uwsgi/apps-enabled/$user.ini** file.
Installation of uWSGI also creates configuration layout: **/etc/uwsgi/apps-enabled**.
If this directory does not exist then **__file** type would error.
We also use stdin as file content source. For details see `Input from stdin <cdist-type.html#input-from-stdin>`_.
For feeding stdin we use here-document (**<<** operator). It allows redirection of subsequent
lines read by the shell to the input of a command until a line containing only the delimiter
and a newline, with no blank characters in between (EOF in our case).

Configuring nginx for Let's Encrypt and HTTPS redirection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Next configure nginx for Let's Encrypt and for HTTP -> HTTPS redirection. For this
purpose we will create new type **__sample_nginx_http_letsencrypt_and_ssl_redirect**
and use it here::

    domain="$(cat "$__object/parameter/domain")"
    webroot="/var/www/html"
    __sample_nginx_http_letsencrypt_and_ssl_redirect "$domain" --webroot "$webroot"

Configuring certificate creation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After HTTP nginx configuration we will create Let's Encrypt certificate using
`__letsencrypt_cert <man7/cdist-type__letsencrypt_cert.html>`_ type.
For Let's Encrypt cert configuration ensure that there is a DNS entry for your
domain. We assure that cert creation is applied after nginx HTTP is configured
for Let's Encrypt to work::

    # create SSL cert
    require="__package/nginx __sample_nginx_http_letsencrypt_and_ssl_redirect/$domain" \
        __letsencrypt_cert --admin-email admin@test.ungleich.ch \
            --webroot "$webroot" \
            --automatic-renewal \
            --renew-hook "service nginx reload" \
            --domain "$domain" \
            "$domain"

Configuring nginx HTTPS server with uWSGI upstream
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Then we can configure nginx HTTPS server that will use created Let's Encrypt certificate::

    # configure nginx
    require="__package/nginx __letsencrypt_cert/$domain" \
        __file "/etc/nginx/sites-enabled/https-$domain" \
        --source - --mode 0644 << EOF
    upstream _bottle {
        server unix:$apphome/uwsgi.sock;
    }

    server {
        listen 443;
        listen [::]:443;

        server_name $domain;

        access_log  /var/log/nginx/access.log;

        ssl on;
        ssl_certificate      /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key  /etc/letsencrypt/live/$domain/privkey.pem;

        client_max_body_size 256m;

        location / {
            try_files \$uri @uwsgi;
        }

        location @uwsgi {
            include uwsgi_params;
            uwsgi_pass _bottle;
        }
    }
    EOF

Now our manifest is finished.

Complete __sample_bottle_hosting type manifest listing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Here is complete __sample_bottle_hosting type manifest listing,
located in ~/.cdist/type/__sample_bottle_hosting/manifest::

    #!/bin/sh

    os=$(cat "$__global/explorer/os")

    case "$os" in
        devuan)
            :
        ;;
        *)
            echo "OS $os currently not supported" >&2
            exit 1
        ;;
    esac

    projectname="$(cat "$__object/parameter/projectname")"
    user="$(cat "$__object/parameter/user")"
    home="/home/$user"
    apphome="$home/app"
    domain="$(cat "$__object/parameter/domain")"

    # create user
    __user "$user" --home "$home" --shell /bin/bash
    # create user home dir
    require="__user/$user" __directory "$home" \
        --owner "$user" --group "$user" --mode 0755
    # create app home dir
    require="__user/$user __directory/$home" __directory "$apphome" \
        --state present --owner "$user" --group "$user" --mode 0755

    # define packages that need to be installed
    packages_to_install="nginx uwsgi-plugin-python3 python3-dev python3-pip postgresql postgresql-contrib libpq-dev python3-venv uwsgi python3-psycopg2"

    # update package index
    __apt_update_index
    # install packages
    for package in $packages_to_install
        do require="__apt_update_index" __package $package --state=present
    done
    # install pip3 packages
    for package in bottle bottle-pgsql; do
        __package_pip --pip pip3 $package
    done

    #PostgreSQL db & user
    postgres_server=postgresql

    # create PostgreSQL db user
    require="__package/postgresql" __postgres_role $user --login --createdb
    # create PostgreSQL db
    require="__postgres_role/$user __package/postgresql" __postgres_database $user \
        --owner $user
    # configure uWSGI
    require="__package/uwsgi" __file /etc/uwsgi/apps-enabled/$user.ini \
                --owner root --group root --mode 0644 \
                --state present \
                --source - << EOF
    [uwsgi]
    socket = $apphome/uwsgi.sock
    chdir = $apphome
    wsgi-file = $projectname/wsgi.py
    touch-reload = $projectname/wsgi.py
    processes = 4
    threads = 2
    chmod-socket = 666
    daemonize=true
    vacuum = true
    uid = $user
    gid = $user
    EOF

    # setup nginx HTTP for Let's Encrypt and SSL redirect
    domain="$(cat "$__object/parameter/domain")"
    webroot="/var/www/html"
    __sample_nginx_http_letsencrypt_and_ssl_redirect "$domain" --webroot "$webroot"

    # create SSL cert
    require="__package/nginx __sample_nginx_http_letsencrypt_and_ssl_redirect/$domain" \
        __letsencrypt_cert --admin-email admin@test.ungleich.ch \
            --webroot "$webroot" \
            --automatic-renewal \
            --renew-hook "service nginx reload" \
            --domain "$domain" \
            "$domain"

    # configure nginx
    require="__package/nginx __letsencrypt_cert/$domain" \
        __file "/etc/nginx/sites-enabled/https-$domain" \
        --source - --mode 0644 << EOF
    upstream _bottle {
        server unix:$apphome/uwsgi.sock;
    }

    server {
        listen 443;
        listen [::]:443;

        server_name $domain;

        access_log  /var/log/nginx/access.log;

        ssl on;
        ssl_certificate      /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key  /etc/letsencrypt/live/$domain/privkey.pem;

        client_max_body_size 256m;

        location / {
            try_files \$uri @uwsgi;
        }

        location @uwsgi {
            include uwsgi_params;
            uwsgi_pass _bottle;
        }
    }
    EOF

Creating __sample_bottle_hosting type gencode-remote
----------------------------------------------------

Now define **gencode-remote** script: ~/.cdist/type/__sample_bottle_hosting/gencode-remote.
After manifest is applied it should restart uWSGI and nginx services so that our
configuration is active. Our gencode-remote looks like the following::

    echo "service uwsgi restart"
    echo "service nginx restart"

Our **__sample_bottle_hosting** type is now finished.

Creating __sample_nginx_http_letsencrypt_and_ssl_redirect type
--------------------------------------------------------------

Let's now create **__sample_nginx_http_letsencrypt_and_ssl_redirect** type::

    cd ~/.cdist/type
    mkdir __sample_nginx_http_letsencrypt_and_ssl_redirect
    cd __sample_nginx_http_letsencrypt_and_ssl_redirect
    mkdir parameter
    echo webroot > parameter/required
    touch manifest
    touch gencode-remote

Edit manifest::

    domain="$__object_id"
    webroot="$(cat "$__object/parameter/webroot")"
    # make sure we have nginx package
    __package nginx
    # setup Let's Encrypt HTTP acme challenge, redirect HTTP to HTTPS
    require="__package/nginx" __file "/etc/nginx/sites-enabled/http-$domain" \
        --source - --mode 0644 << EOF
    server {
        listen *:80;
        listen [::]:80;

        server_name $domain;

        # Let's Encrypt
        location /.well-known/acme-challenge/ {
            root $webroot;
        }

        # Everything else -> SSL
        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    EOF

Edit gencode-remote::

    echo "service nginx reload"

Creating init manifest
----------------------

Next create init manifest::

    cd ~/.cdist/manifest
    printf "__sample_bottle_hosting --projectname sample --user app --domain \$__target_host sample\n" > sample

Using this init manifest our target host will be configured using our **__sample_bottle_hosting**
type with projectname *sample*, user *app* and domain equal to **__target_host**.
Here the last positional argument *sample* is type's object id. For details on
**__target_host** and **__object_id** see
`Environment variables (for reading) <cdist-reference.html#environment-variables-for-reading>`_
reference.

Configuring host
----------------

Finally configure test.ungleich.ch::

    cdist config -v -i ~/.cdist/manifest/sample test.ungleich.ch

After cdist configuration is successfully finished our host is ready.

Creating python bottle application
----------------------------------

We now need to create Bottle application. As you remember from the beginning
of this walkthrough our type does not create the actual python application,
its intention is only to configure hosting for specified user and project.
It is up to the user to create his/her applications.

Become app user::

    su -l app

Preparing database
~~~~~~~~~~~~~~~~~~

We need to prepare database for our application. Create table and
insert some items::

    psql -c "create table items (item varchar(255));"

    psql -c "insert into items(item) values('spam');"
    psql -c "insert into items(item) values('eggs');"
    psql -c "insert into items(item) values('sausage');"

Creating application
~~~~~~~~~~~~~~~~~~~~

Next create sample app::

    cd /home/app/app
    mkdir sample
    cd sample

Create app.py with the following content::

    #!/usr/bin/env python3

    import bottle
    import bottle_pgsql

    app = application = bottle.Bottle()
    plugin = bottle_pgsql.Plugin('dbname=app user=app password=')
    app.install(plugin)

    @app.route('/')
    def show_index(db):
        db.execute('select * from items')
        items = db.fetchall() or []
        rv = '<html><body><h3>Items:</h3><ul>'
        for item in items:
            rv += '<li>' + str(item['item']) + '</li>'
        rv += '</ul></body></html>'
        return rv

    if __name__ == '__main__':
        bottle.run(app=app, host='0.0.0.0', port=8080)

Create wsgi.py with the following content::

    import os

    os.chdir(os.path.dirname(__file__))

    import app
    application = app.app

We have configured uWSGI with **touch-reload = $projectname/wsgi.py** so after
we have changed our **wsgi.py** file uWSGI reloads the application.

Our application selects and lists items from **items** table.

Opening application
~~~~~~~~~~~~~~~~~~~~

Finally try the application::

    http://test.ungleich.ch/

It should redirect to HTTPS and return:

.. container:: highlight

    .. raw:: html

        <h3>Items:</h3>

        <ul>
            <li>spam</li>
            <li>eggs</li>
            <li>sausage</li>
        </ul>

What's next?
------------

Continue reading next sections ;)
