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

S_VERSION="0.5"
PUBLIC_REPO="https://github.com/MinePlay85/PteroBilling-installer" #Mark repo of the installer
SPONSOR="https://paypal.me/alaisterleung" 
INSTALL_LINK="https://raw.githubusercontent.com/MinePlay85/pterobilling-installer/dev/install-pterobilling.sh"

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

billinginstall() {
  bash <(curl -s $INSTALL_LINK)
}

stop() {
  echo "* Installation Aborted"
  exit 1
}

update() {
  echo "PteroBilling not released ! Impossible to install the update"
  exit 1
}

while [ "$finish" == false ]; do
  option=(
    "Install PteroBilling"
    "Update PteroBilling to the latest\n"

    "Don't install it"
  )

  actions=(
    "billinginstall"
    "update"

    "stop"
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
