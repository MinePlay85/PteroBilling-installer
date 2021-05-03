#!bin/bash

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

S_VERSION="0.0.1"
PUBLIC_REPO="https://github.com/MinePlay85/PteroBilling-installer" #Mark repo of the installer
SPONSOR="" #Mark the sponsor link
INSTALL_LINK="https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install-pterobilling.sh" #Mark the installing link of all files
DEP_DEB_INSTALL_LINK="https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install-dep-debian.sh"
DEP_UBU_INSTALL_LINK="https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install-dep-ubuntu.sh"
DEP_CENT_INSTALL_LINK="https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/master/install-dep-centos.sh"

# exit with error if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "*You need to have root privileges for execue that (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* Installation aborted ! Curl is required."
  exit 1
fi

output() {
  echo -e "* ${1}"
}

# if error send this to the terminal
error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo ""
  echo -e "* ${COLOR_RED}ERROR WITH THE SCRIPT${COLOR_NC}: $1"
  echo -e "* ${COLOR_RED}if the problem persists contact support${COLOR_NC}"
  echo -e "* ${COLOR_RED}Discord Server for help: https://discord.gg/EjHe3QpJjd${COLOR_NC}"
  echo ""
  echo ""
}

finish=false

output "PteroBilling installation Sctipt"
output "Version @ $S_VERSION"
output ""
output ""
output "Copyright (C) 2021, PteroBilling"
output "$PUBLIC_REPO"
output ""
output ""
output "Sponsoring PteroBilling: $SPONSOR"
output ""

output

release() {
  bash <(curl -s $INSTALL_LINK)
}

dep() {
  bash <(curl -s $DEP_DEB_INSTALL_LINK)
}

dep_centos() {
  bash <(curl -s $DEP_CENT_INSTALL_LINK)
}

dep_ubu() {
  bash <(curl -s $DEP_UBU_INSTALL_LINK)
}  

while [ "$finish" == false ]; do
  option=(
    "Install PteroBilling And Dependencies ?\n"
 
    "Install dependencies
    "Install PteroBilling"
  )

  actions=(
    "dep; release"

    "dep"
    "release"
  )

  output "Do you want to install PteroBilling ?"

  for i in "${!option[@]}"; do
    output "[$i] ${option[$i]}"
  done

  echo -n "* Input 0-$((${#actions[@]}-1)): "
  read -r action

  [ -z "$action" ] && error "You need to add an Input" && continue

  valid_input=("$(for ((i=0;i<=${#actions[@]}-1;i+=1)); do echo "${i}"; done)")
  [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Invalid option you need to choose (1/2)"
  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && eval "${actions[$action]}"
done
