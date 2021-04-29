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
  yum -y update
  dnf -y update
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

FQDN=""

# Download URL
BILLING_DL_URL="https://github.com/pterobilling/pterobilling/releases/lastest/download/pterobilling.tar.gz"
BASE_URL="" #Mark link when the repo was created

# Check Version #
get_latest_version() {
    curl --silent "https://api.github.com/repos/$1/releases/lastest" | #Install lastest version of GitHub API
    grep '"tag_name":' | # get tag line
    sed -E 's/.*"([^"]+)".*/\1/'  # pluck json value
}

# version of pterobilling
echo "* Getting release information"
PTEROBILLING_VERSION="$(get_latest "pterobilling/pterobilling")"

# function lib #
array_contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Other Visual Func #
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
  if [[ "$SSL_CONF" =~ [yY] ]]; then
    ASSUME_SSQL=false
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

# installation funcs #

redis() {

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

db_creator() {
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

      echo "* Create MySQL user."
      mysql -u root -p -e "CREATE USER '${SQL_USER}'@'127.0.0.1' IDENTIFIED BY '${SQL_PASSWORD}';"

      echo "* Create database."
      mysql -u root -p -e "CREATE DATABASE ${SQL_DB};"

      echo "* Grant privileges."
      mysql -u root -p -e "GRANT ALL PRIVILEGES ON ${SQL_DB}.* TO '${SQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"

      echo "* Flush privileges."
      mysql -u root -p -e "FLUSH PRIVILEGES;"
    else
      echo "* Performing MySQL queries.."

      echo "* Creating MySQL user.."
      mysql -u root -e "CREATE USER '${SQL_USER}'@'127.0.0.1' IDENTIFIED BY '${SQL_PASSWORD}';"

      echo "* Creating database.."
      mysql -u root -e "CREATE DATABASE ${SQL_DB};"

      echo "* Granting privileges.."
      mysql -u root -e "GRANT ALL PRIVILEGES ON ${SQL_DB}.* TO '${SQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"

      echo "* Flushing privileges.."
      mysql -u root -e "FLUSH PRIVILEGES;"

      echo "* MySQL database created & configured!"
    fi
  else
    echo "* Performing MySQL queries.."

    echo "* Creating MySQL user.."
    mysql -u root -e "CREATE USER '${SQL_USER}'@'127.0.0.1' IDENTIFIED BY '${SQL_PASSWORD}';"

    echo "* Creating database.."
    mysql -u root -e "CREATE DATABASE ${SQL_DB};"

    echo "* Granting privileges.."
    mysql -u root -e "GRANT ALL PRIVILEGES ON ${SQL_DB}.* TO '${SQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"

    echo "* Flushing privileges.."
    mysql -u root -e "FLUSH PRIVILEGES;"

    echo "* MySQL database created & configured!"
  fi    
}


# dl pterobilling files
pterobilling_dl() {
  echo "* Downloading Pterobilling Files..."
  cd /var/www 

  #Composer Install Files
  composer create-project pterobilling/pterobilling pterobilling --no-dev --stability=alpha
  chmod -R 755 /var/www/pterobilling
  chown -R www-data:www-data /var/www/pterobilling

  # .env
  cp .env.example .env
  [ "$OS" == "centos" ] && export PATH=/usr/local/bin:$PATH
  
  php artisan key:generate --force
  echo "* PteroBilling files and Composer dependencies was installed !"
}

config() {
  app_url="http//$FQDN"
  [ "$ASSUME_SSL" == true ] && app_url="https://$FQDN"

  php artisan migrate --seed --force  
}

permission() {
  case "$OS" in
    debian | ubuntu)
      chown -R www-data:www-data ./* ;;
    centos)
      chown -R nginx:nginx ./* ;;
  esac   
}      

# OS install func #

apt_install_sudo() {
  apt-get install sudo
}

apt_update() {
  sudo apt update -q -y && sudo apt upgrade -y
}

yum_update() {
  yum -y update
}

dnf_update() {
  dnf -y upgrade
}

enable_services_deb_based() {
  service mariadb enable
  service redis-server enable
  service mariadb start
  service redis-server start
}

enable_services_centos_based() {
  # commannd enable & start
}

selinux_allow() {
  setsebool -P httpd_can_network_connect 1 || true  # these commands can fail OK
  setsebool -P httpd_execmem 1 || true
  setsebool -P httpd_unified 1 || true  
}

ubuntu20_dep() {
  echo "* Installing dependencies for Ubuntu 20.."

  # Add "add-apt-repository" command
  apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

  # Ubuntu universe repo
  add-apt-repository universe

  # Add PPA for PHP (we need 8.0 and focal only has 7.4)
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php

  # Update repositories list
  apt_update

  # Install Dependencies
  apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server redis cron

  # Enable services
  enable_services_debian_based

  echo "* Dependencies for Ubuntu installed!"
}

ubuntu18_dep() {
  echo "* Installing dependencies for Ubuntu 18.."

  # Add "add-apt-repository" command
  apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

  # Ubuntu universe repo
  add-apt-repository universe

  # Add PPA for PHP (we need 8.0 and bionic only has 7.2)
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php

  # Add the MariaDB repo (bionic has mariadb version 10.1 and we need newer than that)
  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

  # Update repositories list
  apt_update

  # Install Dependencies
  apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server redis cron

  # Enable services
  enable_services_debian_based

  echo "* Dependencies for Ubuntu installed!"
}

debian_stretch_dep() {
  echo "* Installing dependencies for Debian 8/9.."

  # MariaDB need dirmngr
  apt -y install dirmngr

  # install PHP 8.0 using sury's repo instead of PPA
  apt install ca-certificates apt-transport-https lsb-release -y
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
 
  # Add the MariaDB repo (oldstable has mariadb version 10.1 and we need newer than that)
  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

  # Update repositories list
  apt_update

  # Install Dependencies
  apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx curl tar unzip git redis-server cron

  # Enable services
  enable_services_debian_based

  echo "* Dependencies for Debian 8/9 installed!"
}

debian_dep() {
  echo "* Installing dependencies for Debian 10.."

  # MariaDB need dirmngr
  apt -y install dirmngr

  # install PHP 8.0 using sury's repo instead of default 7.2 package (in buster repo)
  apt install ca-certificates apt-transport-https lsb-release -y
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

  # Update repositories list
  apt_update

  # install dependencies
  apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx curl tar unzip git redis-server cron

  # Enable services
  enable_services_debian_based

  echo "* Dependencies for Debian 10 installed!"
}

centos7_dep() {
  echo "* Installing dependencies for CentOS 7.."

  # SELinux tools
  yum install -y policycoreutils policycoreutils-python selinux-policy selinux-policy-targeted libselinux-utils setroubleshoot-server setools setools-console mcstrans

  # Add remi repo (php8.0)
  yum install -y epel-release http://rpms.remirepo.net/enterprise/remi-release-7.rpm
  yum install -y yum-utils
  yum-config-manager -y --disable remi-php54
  yum-config-manager -y --enable remi-php80
  yum_update

  # Install MariaDB
  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

  # Install dependencies
  yum -y install php php-common php-tokenizer php-curl php-fpm php-cli php-json php-mysqlnd php-mcrypt php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache mariadb-server nginx curl tar zip unzip git redis

  # Enable services
  enable_services_centos_based

  # SELinux (allow nginx and redis)
  selinux_allow

  echo "* Dependencies for CentOS installed!"
}

centos8_dep() {
  echo "* Installing dependencies for CentOS 8.."

  # SELinux tools
  dnf install -y policycoreutils selinux-policy selinux-policy-targeted setroubleshoot-server setools setools-console mcstrans

  # add remi repo (php8.0)
  dnf install -y epel-release http://rpms.remirepo.net/enterprise/remi-release-8.rpm
  dnf module enable -y php:remi-8.0
  dnf_update

  dnf install -y php php-common php-fpm php-cli php-json php-mysqlnd php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache

  # MariaDB (use from official repo)
  dnf install -y mariadb mariadb-server

  # Other dependencies
  dnf install -y nginx curl tar zip unzip git redis

  # Enable services
  enable_services_centos_based

  # SELinux (allow nginx and redis)
  selinux_allow

  echo "* Dependencies for CentOS installed!"
}

##### OTHER OS SPECIFIC FUNCTIONS #####

centos_php() {
  curl -o /etc/php-fpm.d/www-pterodactyl.conf $GITHUB_BASE_URL/configs/www-pterodactyl.conf

  systemctl enable php-fpm
  systemctl start php-fpm
}

ssl() {
  FAILED = false

  #Cerbot
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
  certbot --nginx --redirect -d "$FQDN" || FAILED=true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    print_warning "The process of obtaining a SSL certificate failed!"
    echo -n "* Still assume SSL? (y/N): "
    read -r CONFIGURE_SSL

    if [[ "$CONFIGURE_SSL" =~ [Yy] ]]; then
      # Config NGINX and SSL
    else
      # Assume SSL
    fi
  fi
}


# Install Link
# https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install.sh
