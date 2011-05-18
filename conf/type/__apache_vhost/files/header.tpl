server {
  listen                          80;
  server_name                     $SERVERNAME;
  root                            $ROOT;

  access_log /var/log/nginx/$SERVERNAME_access.log
  error_log /var/log/nginx/$SERVERNAME_error.log


