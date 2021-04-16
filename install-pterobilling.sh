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

# Check if using curl
if ! [ -x "$(command -v curl)"] then
  echo "* curl is require for this script."
  echo "* install using apt (for debian) or yum/dnf (CentOS)"
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
SQL_DB="pterobilling"

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

    
}
