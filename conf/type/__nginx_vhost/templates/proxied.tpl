#!/bin/sh
cat <<EOF
# Upstream Ruby process cluster for load balancing
upstream ${SERVERNAME}-proxy {
    server $PROXY_URI;
}

server {
    listen       *:80;
    server_name  $SERVERNAME;

    access_log  /var/log/nginx/$SERVERNAME-proxy-access;
    error_log   /var/log/nginx/$SERVERNAME-proxy-error;

    include proxy.include;
    root $ROOT;
    proxy_redirect off;

    location / {
        try_files /index.html .html  @cluster;
    }

    location @cluster {
        proxy_pass http://${SERVERNAME}-proxy;
    }
}
EOF
