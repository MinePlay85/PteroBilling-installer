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
error() {
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

# Update dep
update() {
  apt update -y && apt upgrade -y
  yum -y update
  dnf -y update
}

# PHP8.0 Install
php_installer() {
  apt -y install php8.0 php8.0-common php8.0-bcmath php8.0-ctype php8.0-fileinfo php8.0-mbstring openssl php8.0-pdo php8.0-mysql php8.0-tokenizer php8.0-xml php8.0-gd php8.0-curl php8.0-zip php8.0-fpm
  systemctl enable php8.0-fpm
  systemctl start php8.0-fpm
}

# Redis Server Install
redis() {
  apt -y install redis-server
  systemctl enable redis-Server
  systemctl start redis-server
}

# Composer Install
ask_have_composer() {
  echo -n "You already composer installed ? (y/N)"
  read -r COMPOSER

  if [[ ! "$COMPOSER" =~ [Yy] ]]; then
    echo "Installing composer.."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo "Composer installed!"
  fi
}

# MariaDB install
db_installer() {
  echo -n "You already installed MySQL ?"
  read -r MYSQLINSTALLATION

  if [[ ! "$MYSQLINSTALLATION" =~ [yY] ]]; then
    echo "Installing MariaDB..."
    apt install -y mariadb-common mariadb-server mariadb-client
    systemctl start mariadb
    systemctl enable mariadb    

    mysql_secure_installation
  fi  
}

# Nginx Install
nginx_install() {
  echo -n "You already nginx installed ? (y/N)"
  read -r NGINX_INSTALL

  if [[ ! "$NGINX_INSTALL" =~ [yY] ]]; then
    apt install -y nginx
    systemctl start nginx
  fi
}

# Certbot Install
certbot_install() {
  apt install -y certbot
}

# MySQL Database creator #

mysql_database() {
  echo "* Create Database."
  mysql -u root -p -e "CREATE USER 'pterobilling'@'127.0.0.1' IDENTIFIED BY 'password';"
  mysql -u root -p -e "CREATE DATABASE billing;"
  mysql -u root -p -e "GRANT ALL PRIVILEGES ON billing.* TO 'pterobilling'@'127.0.0.1' WITH GRANT OPTION;"
  mysql -u root -p -e "FLUSH PRIVILEGES;"
}



install_dep() {
  [ ! "$OS" == "centos" ]
  ask_have_composer
  certbot_install
  nginx_install
  db_installer
  mysql_database
  redis
  php_installer
  update
}

#run script
install_dep

# Repo Link: https://github.com/MinePlay85/PteroBilling-installer