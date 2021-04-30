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

update() {
  apt update -q -y && apt upgrade -y
}

echo -n "Do you want to add an FQDN (IP of your VPS if not have a domain) (e.g billing.pterobilling.xyz): "
read -r FQDN

# OS fucn #

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

  # OS 
  case "$OS" in
    ubuntu)
      PHP_SOCKET="/run/php/php8.0-fpm.sock"
      [ "$OS_VER_MAJOR" == "18" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "20" ] && SUPPORTED=true
      ;;
    debian)
      PHP_SOCKET="/run/php/php8.0-fpm.sock"
      [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
      ;;
    centos)
      PHP_SOCKET="/var/run/php-fpm/pterodactyl.sock"
      [ "$OS_VER_MAJOR" == "7" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "8" ] && SUPPORTED=true
      ;;
    *)
      SUPPORTED=false ;;
  esac     

  # exit if not supported
  if [ "$SUPPORTED" == true ]; then
    echo "* $OS $OS_VER is supported."
  else
    echo "* $OS $OS_VER is not supported"
    print_error "Unsupported OS"
    exit 1
  fi
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

ask_ssl() {
  print_warning "if you want to use a SSL Certificates you need to have a domain (e.g billing.pterobilling.io) and you cannot use SSL if you use hostname as an IP you "
  echo -e -n "& Do you want to configure HTTPS using a SSL Certificates ? [Y/N]: "
  read -r SSL_CONF
  if [[ "$SSL_CONF" =~ [yY] ]]; then
    ASSUME_SSL=false
  fi  
}

ask_ssl_assume() {
  echo "& SSL certificate will be configured by this script"
  echo "& You can assume, the script will be diwnload nginx"
  echo "& if you don't obain the SSL certificate, the installation can be failed"
  echo -n "& Do you assume the SSL ? [Y/N]: "
  read -r SSLA_INPUT
  # Verify if the SSLA_INPUT is y
  [[ "$SSLA_INPUT" =~ [yY] ]] && ASSUME_SSL=true
  true
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
  app_url="http//$FQDN"
  [ "$ASSUME_SSL" == true ] && app_url="https://$FQDN"

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
    echo -n "* Still assume SSL? (y/N): "
    read -r CONFIGURE_SSL

    if [[ "$CONFIGURE_SSL" =~ [Yy] ]]; then
      SSL_ASSUME=true
      CONFIG_SSL=false
      config_nginx
    else
      SSL_ASSUME=false
      CONFIG_SSL=false
    fi
  fi
}

# WebServer #
config_nginx() {
  if [ $CONFIG_SSL == true ] && [ $SSL_ASSUME == true ]; then
    CONFIG_FILE="ssl_nginx.conf"
  else
    CONFIG_FILE="nginx.conf"
  fi  
  echo "Nginx Config: "

  # Download config PteroBillng
  curl -o /etc/nginx/sites-available/pterobilling.conf $BASE_URL/nginx-config/$CONFIG_FILE

  # Replace <domain> by Domain name
  sed -i -e "s@domain@${FQDN}@g" /etc/nginx/sites-available/pterobilling.conf

  # enable pterobilling nginx
  ln -s /etc/nginx/sites-available/pterobilling.conf /etc/nginx/sites-enabled/pterobilling.conf
}

install_files() {
  [ ! "$OS" == "centos" ]
  pterobilling_dl
  ask_ssl
  ask_ssl_assume
  config_nginx
  config
  ssl
}

bye() {
  echo "* Installation Finished ! Enjoy ! Bye! "
  exit
}

#run script
install_files
bye

# Install Link
# https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install.sh

