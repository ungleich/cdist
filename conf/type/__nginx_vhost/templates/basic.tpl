#!/bin/sh
cat << EOF
server {
  listen                          80;
  server_name                     $SERVERNAME;
  root                            $ROOT;

  access_log /var/log/nginx/${SERVERNAME}_access.log
  error_log /var/log/nginx/${SERVERNAME}_error.log

  location  $LOCATION {
    root	$ROOT;
    index	$INDEX;
  }
}
EOF
