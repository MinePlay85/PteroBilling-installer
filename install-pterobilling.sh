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

# exit with an error if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This Script need to have root privileges (sudo)." 1>&2
  exit 1
fi

# Variables #

# Version of the Program
GITHUB_SOURCE="master"
SCRIPT_VERSION="lastest"

FQDN=""

# MySQL
SQL_USER="pterobilling"
SQL_PASSWORD=""
SQL_DB="billing"

# Admin Account
admin_email=""
admin_firstname=""
admin_surname=""
admin_username=""
admin_pass=""

#Environment
email=""

# Download URL
BILLING_DL_URL="https://github.com/pterobilling/pterobilling/releases/lastest/download/pterobilling.tar.gz"
BASE_URL="" #Mark link when the repo was created

# Check Version #
get_latest() {
    curl --silent "https://api.github.com/repos/$1/releases/lastest" | #Install lastest version of GitHub API
    grep '"tag_name":' | # get tag line
    sed -E sed -E 's/.*"([^"]+)".*/\1/' # pluck json value
}

# version of pterobilling
echo "* Getting release information"
PTEROBILLING_VERSION="$(get_lastest "pterobilling/pterobilling")"

# function lib #
array_contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Visual func #
err() {
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

# user imput func #

required_input() {
  local __resultvar=$1
  local result=''

  while [ -z "$result" ]; do
      echo -n "* ${2}"
      read -r result

      [ -z "$result" ] && print_error "${3}"
  done

  eval "$__resultvar="'$result'""    
}

pass_input() {
  local __resultvar=$1
  local result=''
  local default="$4"

  while [ -z "$result" ]; do
    echo -n "* ${2}"

  while IFS = read -r -s -n1 char; do
    [[ -z $char ]] && { printf '\n'; break; }
    if [[ $char == $'\x7f' ]]; then
          if [ -n "$result" ]; then
            [[ -n $result ]] && result=${result%?}
            printf '\b \b' 
          fi
      else
        result+=$char
        printf "*"
      fi
    done
    [ -z "$result" ] && [ -n "$default" ] && result="$default"
    [ -z "$result" ] && print_error "${3}"
  done

  eval "$__resultvar="'$result'""      
}

ask_ssl() {
  print_warning "if you want to use a SSL Certificates you need to have a domain (e.g billing.pterobilling.io) and you cannot use SSL if you use hostname as an IP you "
  echo -e -n "& Do you want to configure HTTPS using a SSQL Certificates ? [Y/N]"
  read -r SSL_CONF
  if [[ "$SSL_CONF" ~= [yY] ]]; then
    # VARIABLE COMMAND
  fi  
}

ask_ssl_assume() {
  echo "& SSL certificate will be configured by this script"
  echo "& You can assume, the script will be diwnload nginx"
  echo "& if you don't obain the SSL certificate, the installation can be failed"
  echo -n "& Do you assume the SSL ? [Y/N]: "
  read -r SSLA_INPUT
  # Verify if the SSLA_INPUT is y
  [[ "$SSLA_INPUT" =~ [yY] ]]
  true
}

# OS CHECK FUNC#

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

  # OS (PHP 8.0) migred to 7.4 later
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
# Install Link
# https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install.sh
