#!/bin/bash

set -e 

###########
#
#           PteroBilling Installation
#
#   The organization was made by Alaister
#
#   Protected with a MIT License
#   Need Pterodactyl Panel v1.2.2 or above
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

# Check if is CentOS
if [ "$OS" == "centos" ]; then
  echo "The installer is not finished with centos"
  exit 1
fi

update() {
  apt update -q -y && apt upgrade -y
}

echo -n "Do you want to add an FQDN (e.g billing.pterobilling.xyz): "
read -r FQDN

# OS func #

detect_distro() {
  OS=$(awk '/DISTRIB_ID=/' /etc/*-release | sed 's/DISTRIB_ID=//' | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  VERSION=$(awk '/DISTRIB_RELEASE=/' /etc/*-release | sed 's/DISTRIB_RELEASE=//' | sed 's/[.]0/./')

  if [ -z "$OS" ]; then
    OS=$(awk '{print $1}' /etc/*-release | tr '[:upper:]' '[:lower:]')
  fi

  if [ -z "$VERSION" ]; then
    VERSION=$(awk '{print $3}' /etc/*-release)
  fi

  echo "Your OS Version: $OS"
  echo "Your CPU ARCH $ARCH"
  echo "Your OS Version: $VERSION"
}

# Variables #

# Version of the Program
GITHUB_SOURCE="master"
SCRIPT_VERSION="lastest"

# Download URL
BILLING_DL_URL="https://github.com/pterobilling/pterobilling/releases/lastest/download/pterobilling.tar.gz"
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
    if [ "$OS" == "debian" || "$OS" == "ubuntu" ]; then
      sudo add-apt-repository ppa:ondrej/php
      sudo apt install apt-transport-https lsb-release ca-certificates wget -y
      sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg 
      sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
      sudo apt update
      apt -y install php8.0 php8.0-common php8.0-bcmath php8.0-ctype php8.0-fileinfo php8.0-mbstring openssl php8.0-pdo php8.0-mysql php8.0-tokenizer php8.0-xml php8.0-gd php8.0-curl php8.0-zip php8.0-fpm
      systemctl enable php8.0-fpm
      systemctl start php8.0-fpm
    elif [ "$OS" == "centos" || "$VERSIION" == "8" ]; then
      sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
      sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
      sudo dnf module list PHP
      sudo dnf module enable php:remi-8.0 -y
      sudo dnf install php php-cli php-common
      sudo dnf install php php-cli php-common php-fpm
      sudo systemctl restart httpd
      sudo systemctl restart nginx
    elif [ "$OS" == "centos" || "$VERSION" == "7" ]; then
      sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
      sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
      sudo dnf module list PHP
      sudo dnf module enable php:remi-8.0 -y
      sudo dnf install php php-cli php-common
      sudo dnf install php php-cli php-common php-fpm
      sudo systemctl restart httpd
      sudo systemctl restart nginx
    fi
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
    apt install -y mariadb-common mariadb-server mariadb-client
    systemctl start mariadb
    systemctl enable mariadb    
    mysql_secure_installation
  fi  

  echo -n "You already nginx installed ? (y/N): "
  read -r NGINX_INSTALL

  if [[ ! "$NGINX_INSTALL" =~ [yY] ]]; then
    apt install -y nginx
    systemctl start nginx
  fi

  echo -n "You already setup database ? (y/N): "
  read -r DBSETUP

  if [[ ! "$DBSETUP" =~ [Yy] ]]; then
    echo "* Create Database..."
    echo "* Put MySQL root Password"
    mysql -e "USE mysql;"
    mysql -e "CREATE USER 'pterobilling'@'127.0.0.1' IDENTIFIED BY 'password';"
    mysql -e "CREATE DATABASE billing;"
    mysql -p -e "GRANT ALL PRIVILEGES ON billing.* TO 'pterobilling'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -e "FLUSH PRIVILEGES;"
  fi
  apt -y install redis-server
  systemctl start redis-server
}

# dl pterobilling files
pterobilling_dl() {
  echo "* Downloading Pterobilling Files..."
  cd /var/www 

  #Composer Install Files
  # composer create-project pterobilling/pterobilling pterobilling --no-dev --stability=alpha
  git clone $GIT_CLONE_URL
  cd /var/www/pterobilling
  cp .env.example .env
  composer create-project
  chmod -R 755 /var/www/pterobilling
  chown -R www-data:www-data /var/www/pterobilling

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
  certbot certonly -d "$FQDN"

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
  detect_distro
  dependencies
  pterobilling_dl
  config_nginx
  config
  ssl
}

bye() {
  echo "* Installation Finished ! Enjoy ! Bye! "
  exit 1
}

#run script
install_files
bye

# Install Link
# https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install.sh

