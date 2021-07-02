#!/bin/bash

set -e


###
#
# PteroBilling Installer Script
# GNL 3.0 License !
#
###

# check root privileges
if [[ $EUID -ne 0 ]]; then
  echo "*You need to have root privileges for execue that (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* Installation aborted ! Curl is required."
  exit 1
fi

# Check if is CentOS
if [ "$OS" == "centos" ]; then
  echo "The installer is not finished with centos"
  exit 1
fi

echo -n "Do you want to install the update (this is in no-stable the pterobilling app can be obstructed).  [Y/N]: "
read -r INSTALLYES

if [[ ! "$INSTALLYES" =~ [Yy] ]]; then 
  echo "INSTALLATION ABORTED !"
  exit 1
fi

# Update system
update() {
  apt update -q -y && apt upgrade -y
}

# The Pterobilling update
update_pterobilling() {
    echo "* Pterobilling Updating files..."

    cd /var/www || exit
    cp pterobilling pterobilling-backup
    cd /var/www/pterobilling || exit
    php artisan down
    cd /var/www || exit
    composer create-project pterobilling/pterobilling pterobilling --stability=dev --no-dev
    chmod -R 755 /var/www/pterobilling
    chown -R www-data:www-data /var/www/pterobilling
    cd /var/www/pterobilling
    php artisan migrate --seed --force
    php artisan config:cache
    php artisan view:cache
    php artisan queue:restart
    php artisan up
}

# Execute program
update
update_pterobilling
