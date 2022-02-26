#!/bin/bash

set -e 

###########
#
#
#               PteroBilling Installer
#             Copyright (C) 2021 - 2022, MinePlay85
#
#           Script Version: 1.3
#           PteroBilling Version: Unstable
#           Script made by MinePlay85
#           Thanks to all contributors for help me.
#           License: https://github.com/MinePlay85/PteroBilling-installer/blob/master/LICENSE
#           Discord: https://discord.gg/bhAFfr9Kwe
#
#
###########

# General Checks #

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

# Color #
# Thanks to https://techstop.github.io/bash-script-colors/ for color code
GREEN="\e[0;92m"
YELLOW="\033[1;33m"
reset="\e[0m"
red='\033[0;31m'

echo -n -e "Do you want to add an FQDN (e.g billing.pterobilling.org): "
read -r FQDN

echo -n -e "${GREEN}What is your Database Hostname ? ${YELLOW}(127.0.0.1)${reset}: "
read -r DBHOST

if [[ "$DBHOST" == "" ]]; then
  DBHOST="127.0.0.1"
fi

echo -n -e "${GREEN}What is your Database Name ? ${YELLOW}(billing)${reset}: "
read -r DBNAME

if [[ "$DBNAME" == "" ]]; then
  DBNAME="billing"  
fi

echo -n -e "${GREEN}What is your Database User ? ${YELLOW}(pterobilling)${reset}: "
read -r DBUSER

if [[ "$DBUSER" == "" ]]; then
  DBUSER="pterobilling"  
fi

echo -n -e "${GREEN}What is your Database Password ?${reset}: "
read -s -r DBPASS

# While if Password have input !
while true; do
  #echo -n -e "${GREEN}What is your Database Password ?${reset}: \n"
  #read -s DBPASS
  if [[ "$DBPASS" == "" ]]; then
    echo -e "${red}The Password must be required !"
    echo -n -e "${GREEN}What is your Database Password ?${reset}: "
    read -s -r DBPASS
  else
    echo -e "${GREEN}Password is Okay !${reset}" 
    break 
  fi
done

# OS fucn #

OS=""
VERSION=""
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$(echo "$ID" | awk '{print tolower($0)}')
  VERSION=$(echo "$VERSION_ID" | awk '{print tolower($0)}')
elif [ -f /etc/lsb-release ]; then
  . /etc/lsb-release
  OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
  VERSION=$DISTRIB_RELEASE 
elif [ -f /etc/centos-release ]; then
  OS="centos"
  VERSION=$(cat /etc/centos-release)
elif [ -f /etc/debian_version ]; then
  OS="debian"
  VERSION=$(cat /etc/debian_version)
fi

echo -e "$ARCH"



# Variables #

# Version of the Program
GITHUB_SOURCE="master"
#SCRIPT_VERSION="lastest"

# Download URL
#BILLING_DL_URL="https://github.com/pterobilling/pterobilling/releases/lastest/download/pterobilling.tar.gz"
BASE_URL="https://raw.githubusercontent.com/MinePlay85/PteroBilling-Installer/master" #Mark link when the repo was created
GIT_CLONE_URL="https://github.com/pterobilling/pterobilling"

# Check Version #
get_latest_version() {
    curl --silent "https://api.github.com/repos/$1/releases/lastest" | #Install lastest version of GitHub API
    grep '"tag_name":' | # get tag line
    sed -E 's/.*"([^"]+)".*/\1/'  # pluck json value
}

# version of pterobilling
echo "* Getting release information"
PTEROBILLING_VERSION="$(get_latest_version "pterobilling/pterobilling")"

# function lib #
array_contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Visual Func #

print_error() {
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

print_warning() {
  COLOR_YELLOW='\033[1;33m'
  COLOR_NC='\033[0m'

  echo ""
  echo ""
  echo -e "* ${COLOR_YELLOW}WARN${COLOR_NC}: $1"
  echo ""
  echo ""
}

brake() {
  for ((n=0;n<$1;n++));
    do
      echo -n "#"
    done
   echo ""   
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

# Dependecies #
dependencies() {
  echo -n "Do you already have PHP8.0 ? (y/N): "
  read -r ASKPHP

  if [[ ! "$ASKPHP" =~ [yY] ]]; then 

    case "$OS" in
    debian)
      sudo apt install apt-transport-https lsb-release ca-certificates wget -y
      sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg 
      sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
      sudo apt-get update
      apt -y install php8.0 php8.0-common php8.0-bcmath php8.0-ctype php8.0-fileinfo php8.0-mbstring openssl php8.0-pdo php8.0-mysql php8.0-tokenizer php8.0-xml php8.0-gd php8.0-curl php8.0-zip php8.0-fpm
      systemctl enable php8.0-fpm
      systemctl start php8.0-fpm
      systemctl stop apache2
      ;;
    ubuntu)
      sudo apt install software-properties-common
      sudo add-apt-repository ppa:ondrej/php
      sudo apt-get update
      apt -y install php8.0 php8.0-common php8.0-bcmath php8.0-ctype php8.0-fileinfo php8.0-mbstring openssl php8.0-pdo php8.0-mysql php8.0-tokenizer php8.0-xml php8.0-gd php8.0-curl php8.0-zip php8.0-fpm
      systemctl enable php8.0-fpm
      systemctl start php8.0-fpm
      ;;
    centos)
      case $VERSION in
      8)
        yum install dnf
        yum install git
        yum install sudo
        sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
        sudo dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
        sudo dnf -y install yum-utils
        sudo dnf module reset php
        sudo dnf module install php:remi-8.0 -y
        sudo dnf install php -y
        sudo dnf -y install php-{common,bcmath,ctype,fileinfo,mbstring,openssl,pdo,mysql,tokenizer,xml,gd,curl,zip,fpm}
        ;;
      7)
        yum install dnf
        yum install git
        yum install sudo
        sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
        sudo dnf module list PHP
        sudo dnf module enable php:remi-8.0 -y
        sudo dnf install php php-common php-bcmath php-ctype php-fileinfo php-mbstring openssl php-pdo php-mysql php-tokenizer php-xml php-gd php-curl php-zip php-fpm
        ;;
      esac
      ;;
    esac
  fi    

  echo -n "Do you already have composer ? (y/N): "
  read -r ASKCOMPOSER

  if [[ ! "$ASKCOMPOSER" =~ [yY] ]]; then 
    echo "Installing composer.."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo "Composer installed!"
  fi

  echo -n "You already installed MySQL ? (y/N): "
  read -r MYSQLINSTALLATION

  if [[ ! "$MYSQLINSTALLATION" =~ [yY] ]]; then
    echo "Installing MariaDB..."
    case "$OS" in 
    debian | ubuntu)
      apt install -y mariadb-common mariadb-server mariadb-client
      systemctl start mariadb
      systemctl enable mariadb    
      mysql_secure_installation
      ;;
    centos)
      case $VERSION in
      7)
        sudo yum install wget
        wget https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
        chmod +x mariadb_repo_setup
        sudo ./mariadb_repo_setup
        sudo yum install MariaDB-server
        sudo systemctl start mariadb.service
        sudo mysql_secure_installation
        ;;
      8)
        sudo dnf install mariadb-server
        sudo systemctl start mariadb
        ;;
      esac
      
      ;;
    esac  
  fi  

  echo -n "You already nginx installed ? (y/N): "
  read -r NGINX_INSTALL

  if [[ ! "$NGINX_INSTALL" =~ [yY] ]]; then
    case "$OS" in 
    debian | ubuntu)
      apt install -y nginx
      systemctl start nginx
      ;;
    centos)
      case $VERSION in
      7)
        sudo yum -y update
        sudo yum install -y epel-release
        sudo yum –y install nginx
        sudo systemctl start nginx.service
        ;;
      8)
        sudo yum -y update
        yum –y install nginx
        sudo systemctl start nginx.service
        ;;
      esac
      
      ;;
    esac
  fi

  echo "* Create Database..."
  echo "* Put MySQL root Password"
  mysql -e "USE mysql;"
  mysql -e "CREATE USER '${DBUSER}'@'${DBHOST}' IDENTIFIED BY '${DBPASS}';"
  mysql -e "CREATE DATABASE ${DBNAME};"
  mysql -p -e "GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'${DBHOST}' WITH GRANT OPTION;"
  mysql -e "FLUSH PRIVILEGES;"

  apt -y install redis-server
  systemctl start redis-server
}

# dl pterobilling files
pterobilling_dl() {
  echo "* Downloading Pterobilling Files..."
  apt update -qq && apt-get full-upgrade
  cd /var/www 

  #Composer Install Files
  # composer create-project pterobilling/pterobilling pterobilling --no-dev --stability=alpha
  apt install git
  git clone $GIT_CLONE_URL
  cd /var/www/pterobilling
  cp .env.example .env
  composer create-project
  chmod -R 755 /var/www/pterobilling
  chown -R www-data:www-data /var/www/pterobilling

  sed -i -e "s@127.0.0.1@${DBHOST}@g" /var/www/pterobilling/.env
  sed -i -e "s@pterobilling@${DBUSER}@g" /var/www/pterobilling/.env 
  sed -i -e "s@billing@${DBNAME}@g" /var/www/pterobilling/.env
  #sed -i -e "s@pterobilling@${DBUSER}@g" /var/www/pterobilling/.env
  #sed -i -e "s@billing@${DBNAME}@g" /var/www/pterobilling/.env
  sed -i -e "s@password@${DBPASS}@g" /var/www/pterobilling/.env

  # .env
  [ "$OS" == "centos" ] && export PATH=/usr/local/bin:$PATH
  
  #php artisan key:generate --force
  echo "* PteroBilling files and Composer dependencies was installed !"
}

config() {
  php artisan migrate --seed --force  
  php artisan config:cache
  php artisan view:cache
}     

# SSL Func #
ssl() {

  #Certbot
  case "$OS" in
    debian | ubuntu)
      apt-get -y install certbot python3-certbot-nginx
      ;;
    centos)
      [ "$OS_VER_MAJOR" == "7" ] && yum -y -q install certbot python-certbot-nginx
      [ "$OS_VER_MAJOR" == "8" ] && dnf -y -q install certbot python3-certbot-nginx
      ;;
  esac
  # Obtain certificate
  service nginx stop || true
  certbot certonly -d "$FQDN"
  service nginx start

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ]; then
    print_warning "The process of obtaining a SSL certificate failed!"
    print_error "Installation aborted !"
  fi
}

# WebServer #
config_nginx() {
  CONFIG_FILE="ssl_nginx.conf"
  echo "Nginx Config..."

  # Download config PteroBillng
  curl -o /etc/nginx/sites-available/pterobilling.conf $BASE_URL/nginx-config/$CONFIG_FILE

  # Replace <domain> by Domain name
  sed -i -e "s@domain@${FQDN}@g" /etc/nginx/sites-available/pterobilling.conf

  # enable pterobilling nginx
  ln -s /etc/nginx/sites-available/pterobilling.conf /etc/nginx/sites-enabled/pterobilling.conf
}

install_files() {
  dependencies
  pterobilling_dl
  config_nginx
  config
  ssl
}

bye() {
  echo "----------------------"
  echo "The Installation is Finished !"
  echo "PteroBilling Docs: https://docs.pterobilling.org"
  echo "PteroBilling WebSite: https://pterobilling.org"
  echo "PteroBilling Discord: https://discord.gg/EjHe3QpJjd"
  echo "Your Information: "
  echo "FQDN: ${FQDN}"
  echo "MySQL Database Name: ${DBNAME}"
  echo "MySQL Database Hostname: ${DBHOST}"
  echo "MySQL Database Username: ${DBUSER}"
  echo "Pterobilling Folder Path: /var/www/pterobilling"
  echo "env File Path: /var/www/pterobilling/.env"
  echo "PteroBilling Version: ${PTEROBILLING_VERSION}"
  echo "GitHub Branch: ${GITHUB_SOURCE}"
  echo "----------------------"
  exit 1
}

wrong_os() {
  echo "Installation Aborted !"
  echo "Wrong OS ! Check SECURITY.md on GitHub Page !"
  exit 1
}

process_installation() {
  install_files
  bye
}

#run script
case "$OS" in
  debian)
    case "$VERSION" in
      9 | 10)
        process_installation
        ;;
      11)
        wrong_os
        ;;
    esac
  ;;
  ubuntu)
    process_installation
    ;;
  centos)
    case "$VERSION" in
      6)
        wrong_os
        ;;
      7 | 8)
        process_installation
        ;;
    esac
esac

# Install Link
# https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install.sh

