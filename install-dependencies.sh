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

# Visual func #
errpr() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo ""
  echo -e "* ${COLOR_RED}INTERNAL ERROR${COLOR_NC}"
  echo -e "* ${COLOR_RED}if the problem persists contact support"
  echo -e "* ${COLOR_RED}Discord Server for help: https://discord.gg/EjHe3QpJjd"  
  echo ""
  echo ""
}

warn() {
  COLOR_YELLOW='\033[1;33m'
  COLOR_NC='\033[0m'

  echo ""
  echo ""
  echo -e "* ${COLOR_YELLOW}WARN${COLOR_NC}: $1"
  echo ""
  echo ""
}


detect_distro() {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS="SuSE"
    OS_VER="?"
  elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS="Red Hat/CentOS"
    OS_VER="?"
  else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

cpu_comp() {
  CPU_ARCH=$(uname -m)
  if [ "${CPU_ARCH}" != "x86_64" ]; then 
    print_warning "Detected CPU architecture $CPU_ARCH"
    print_warning "Using any another CPU than 64 bit (x86_64) will be cause problem"

    echo -e  -n "& Are you sure you want to proceed? [Y/n]"
    read -r choice
    if [[ ! "$choice" =~ [Yy] ]]; then
      print_error "Installation Failed!"
      exit 1
    fi
  fi

  # exit if not supported
  if [ "$SUPPORTED" == true ]; then
    echo "* $OS $OS_VER is supported."
  else
    echo "* $OS $OS_VER is not supported"
    print_error "Unsupported OS"
    exit 1
  fi
}

# installation funcs #

redis() {
  apt -y install redis-server
  systemctl enable redis-Server
  systemctl start redis-server
}

ask_have_composer() {
  echo -n "You already composer installed ? (y/N)"
  read -r COMPOSER

  if [[ ! "$COMPOSER" =~ [Yy] ]]; then
    echo "Installing composer.."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo "Composer installed!"
  fi
}

db-installer() {
  echo -n "You already installed MySQL ?"
  read -r MYSQLINSTALLATION

  if [[ ! "$MYSQLINSTALLATION" =~ [yY] ]]; then
    if [ "$OS" == "centos" ]; then 
      # Installing MariaDB/MySQL
      echo "* MySQL Installation..."
      echo "* Set root password? [Y/n] Y"
      echo "* Remove anonymous users? [Y/n] Y"
      echo "* Disallow root login remotely? [Y/n] Y"
      echo "* Remove test database and access to it? [Y/n] Y"
      echo "* Reload privilege tables now? [Y/n] Y"
      echo "*"

      mysql_secure_installation

      echo "* The script should have asked you to set the MySQL root password earlier (not to be confused with the pterodactyl database user password)"
      echo "* MySQL will now ask you to enter the password before each command."
    else
      echo "* MySQL Installation..."
      echo "* Set root password? [Y/n] Y"
      echo "* Remove anonymous users? [Y/n] Y"
      echo "* Disallow root login remotely? [Y/n] Y"
      echo "* Remove test database and access to it? [Y/n] Y"
      echo "* Reload privilege tables now? [Y/n] Y"
      echo "*"

      mysql_secure_installation
    fi
      
}

