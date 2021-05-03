#!/bin/bash

set -e 

###########
#
#           PteroBilling Installation
#
#   The organization was made by Alaister
#
#   Protected with a MIT License
#   Need Pterodactyl Panel v1.3.0 or above
#   And PHP8.0, Composer 2, Redis-Server, nginx, CertBot, MariaDB and other
#   CentOS, Debian 9 and 10, ubuntu 20.4 and 18.4  
###########

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

# Check if is the correct os
if [ ! "$OS" == "centos" ]; then
  echo "* Installation Aborted wrong choice ! not your OS"
  exit 1
fi


