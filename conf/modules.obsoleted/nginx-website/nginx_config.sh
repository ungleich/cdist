cat << eof
#
# D-INFK SANS MANAGED FILE
# ========================
#
# Do not change this file. Changes will be overwritten by puppet.
#

server {
   # Only bind on the reserved IP address
   listen $nginx_website;
   server_name $server_name;

   location / {
      root /home/services/www/$username/$server_name/www;
   }
}
eof
