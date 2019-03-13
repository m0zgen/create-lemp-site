#!/bin/bash
#
# This script works in the /srv/www directory
# Reference article: https://sys-adm.in/sections/os-nix/830-fedora-linux-ustanovka-nastrojka-lemp-nginx-php-fpm.html
# Created by Yegeniy Goncharov, https://sys-adm.in

#
# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Arg vars
# ---------------------------------------------------\
VHOST=${VHOST}
FLAG=${FLAG}

# Additions
# ---------------------------------------------------\
Info() {
  printf "\033[1;32m$@\033[0m\n"
}

Error()
{
  printf "\033[1;31m$@\033[0m\n"
}

Warn() {
        printf "\033[1;35m$@\033[0m"
}


usage()
{
cat << EOF
Usage: $0 options
OPTIONS:
   -c      Create VirtualHost
   -r      Remove VirtualHost
   -l      List VirtualHost
Example:
$0 -c vhost
$0 -r vhost
$0 -l show

EOF
}

# Checking arguments
# ---------------------------------------------------\
while [[ $# > 1 ]]
do
  key="$1"
  shift
  case $key in
  -c|--create)
  VHOST="$1"
  FLAG="1"
  shift
  ;;
  -r|--remove)
  VHOST="$1"
  FLAG="2"
  shift
  ;;
  -l|--list)
  FLAG="3"
  shift
  ;;
esac
done

# Checking folders
# ---------------------------------------------------\
if [[ ! -d /srv/www ]]; then
  mkdir -p /srv/www
fi

if [[ ! -d /etc/nginx/sites-available ]]; then
  mkdir -p /etc/nginx/sites-available
fi

if [[ ! -d /etc/nginx/sites-enabled ]]; then
  mkdir -p /etc/nginx/sites-enabled
fi

# Show Help (usage)
# ---------------------------------------------------\
if [[ "$FLAG" == "" ]]; then
  usage
fi

# General vars
# ---------------------------------------------------\
domain="local"
DOMAIN_NAME=$VHOST.$domain

public_html="public_html"
webroot="/srv/www"

CHOWNERS="nginx:webadmins"
DIRECTORY=$webroot/$DOMAIN_NAME/$public_html
INDEX_HTML="$DIRECTORY/index.php"
PATH_TO_CONF="/etc/nginx/sites-available"
CONF_FILE="$PATH_TO_CONF/$DOMAIN_NAME.conf"
CONF_FILE_NAME="$DOMAIN_NAME.conf"
LOCAL_IP=$(hostname -I | cut -d' ' -f1)

# Functions
# ---------------------------------------------------\
genIndex(){
cat <<EOF >$INDEX_HTML
<html>
 <head>
    <title>${DOMAIN_NAME}</title>
 </head>
 <body>
    <h1>${DOMAIN_NAME} working!</h1>
 </body>
</html>
EOF
}

genConf(){
cat <<EOF >$CONF_FILE
server {
    server_name ${DOMAIN_NAME};
    access_log /srv/www/${DOMAIN_NAME}/logs/access.log;
    error_log /srv/www/${DOMAIN_NAME}/logs/error.log;
    root /srv/www/${DOMAIN_NAME}/public_html;

    location / {
        index index.html index.htm index.php;
    }

    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass  unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
}

# If argument equal -c (create new site)
# ---------------------------------------------------\
if [[ "$FLAG" == "1" ]]; then
  if [ -d "$DIRECTORY" ]; then
      # if exist
      echo -e "Directory exist"
      echo -e "Exit!"
    else
      # not exist
      Info "\nCreate: $DIRECTORY"
      /bin/mkdir -p $DIRECTORY
      mkdir $webroot/$DOMAIN_NAME/logs

      echo "Create $INDEX_HTML"
      /bin/touch $INDEX_HTML
      genIndex
      echo -e "File $INDEX_HTML created"

      echo "Change vhost folder permission..."
      /bin/chown -R $CHOWNERS $webroot/$DOMAIN_NAME
      /bin/chmod -R 775 $webroot/$DOMAIN_NAME

      echo "Create conf file $CONF_FILE"
      /bin/touch $CONF_FILE
      genConf

      cd /etc/nginx/sites-enabled/
      ln -s /etc/nginx/sites-available/$DOMAIN_NAME.conf

      echo -e "Update /etc/hosts file\nAdd $LOCAL_IP $DOMAIN_NAME"
      echo "$LOCAL_IP $DOMAIN_NAME" >> /etc/hosts
      echo "Restart NGINX..."
      systemctl restart nginx.service
      Info "Done!"
      Warn "\nPlease add include conf folder into nginx.conf parameter:\ninclude /etc/nginx/sites-enabled/*.conf;\n\n"
  fi
fi

# If argument equal -r (remove new site)
# ---------------------------------------------------\
if [[ "$FLAG" == "2" ]]
  then

  if [ -d "$DIRECTORY" ]; then
    # if exist
    Warn "\nRemoving $VHOST"

    echo "Remove directory $webroot/$DOMAIN_NAME"
    /bin/rm -rf $webroot/$DOMAIN_NAME

    echo "Remove conf file $CONF_FILE"
    /bin/rm -f $CONF_FILE

    echo "Remove link /etc/nginx/sites-enabled/$CONF_FILE_NAME"
    /bin/rm -f /etc/nginx/sites-enabled/$DOMAIN_NAME.conf

    echo "Comment /etc/hosts param..."
    /bin/sed -i "s/$LOCAL_IP $DOMAIN_NAME/#$LOCAL_IP $DOMAIN_NAME/" /etc/hosts

    echo "Restart NGINX..."
    systemctl restart nginx.service

    Info "Done!\n"

  else
    Error "\nDirectory not exist!\nPlease use remove command without extention\nExit!\n"
    exit 1
  fi

fi

# If argument equal -l (remove new site)
# ---------------------------------------------------\
if [[ "$FLAG" == "3" ]]
  then
  Info "\nSites created"
  ls /etc/nginx/sites-available/

  Info "\nSites enabled"
  ls /etc/nginx/sites-enabled

  Info "\n/srv/www folder list"
  ls /srv/www

  Info "\nTotal:"
  ls /etc/nginx/sites-available/ | wc -l
  echo -e ""
fi
