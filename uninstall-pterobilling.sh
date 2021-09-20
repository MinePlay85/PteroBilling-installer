#!/bin/bash

set -e 

###########
#
#           PteroBlling Installer
#
#               This installer is free and was made by MinePlay85 and contributor
#               We use for this installer a GNU 3.0 LICENSE
#               For PteroBilling we use MIT LICENSE
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
