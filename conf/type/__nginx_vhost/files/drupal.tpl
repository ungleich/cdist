    index index.php;
 
    if (!-e $request_filename) {
        rewrite ^/(.*)$ /index.php?q=$1 last;
    }
 
    error_page 404 index.php;
 
    # hide protected files
    location ~* \.(engine|inc|info|install|module|profile|po|sh|.*sql|theme|tpl(\.php)?|xtmpl)$|^(code-style\.pl|Entries.*|Repository|Root|Tag|Template)$ {
      deny all;
    }
 
    # hide backup_migrate files
    location ~* ^/files/backup_migrate {
      deny all;
    }
 
    # serve static files directly
    location ~* ^.+\.(jpg|jpeg|gif|css|png|js|ico)$ {
        access_log        off;
        expires           30d;
    }  
 
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param  SCRIPT_FILENAME   $document_root$fastcgi_script_name;
        fastcgi_param  QUERY_STRING     $query_string;
        fastcgi_param  REQUEST_METHOD   $request_method;
        fastcgi_param  CONTENT_TYPE     $content_type;
        fastcgi_param  CONTENT_LENGTH   $content_length;
    }

#  Disable after installation
#  location = /install.php {
#    include /etc/nginx/fastcgi_params;
#    fastcgi_param SCRIPT_FILENAME /home/keru/www/drupal/install.php;
#    fastcgi_param QUERY_STRING q=$uri&$args;
#    fastcgi_pass 127.0.0.1:9000;
#  }


