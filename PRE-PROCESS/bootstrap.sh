#/bin/bash

# Updated: 2025-04-04
# Author: Benoit Bégin
# 
# This script:
#   - Git clone the Github repo
#   - Read the config file and make variables global
#   - Remove itself from the kernel command-line (cmdline.txt)
#   - Call the sequence of scripts for the customizations and the building of apps and services
#   - Displaying a message to image the SD card to a .img file
#   - Shutdown the system

GITHUB_SRCBASE=https://github.com/sonicprod/raspi-mame-appliance
CFGFILENAME=/home/pi/raspi-mame-appliance/_staging/Config.ExportPublicImage.cfg

# Git clone the repo to get the latest versions of the needed files and scripts...
cd /home/pi
git clone $GITHUB_SRCBASE

# Load config file settings for automated/unattended image creation...
if [ -f $CFGFILENAME ]; then
  while IFS="= " read VAR VALUE; do
    [ ! -z $VAR ] && [ "${VAR:0:1}" != "#" ] && export $VAR="$VALUE"
  done < $CFGFILENAME
fi

BOOTDIR=$(findmnt /dev/mmcblk0p1 -n -o TARGET)
# We remove ourself from the kernel cmdline (init=/usr/lib/raspi-config/bootstrap.sh)
[ $BOOTDIR ] && sudo sed -ie 's/init=\/usr\/lib\/raspi-config\/bootstrap.sh//g' $BOOTDIR/cmdline.txt

