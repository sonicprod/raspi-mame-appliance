#/bin/bash

# Updated: 2025-04-16
# Author: Benoit Bégin
# 
# This is the "bootstrap" script that chain the "offline" preparation of the image and
# transfer/pass the execution to the "online" configuration and build/installation steps.
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

# Initial source repo update...
sudo apt-get update

# Git clone the repo to get the latest versions of the needed files and scripts...
cd /home/pi
[ $(command -v git) ] || sudo apt-get install git -y
git clone $GITHUB_SRCBASE

# Load config file settings for automated/unattended image creation...
if [ -f $CFGFILENAME ]; then
  while IFS="= " read VAR VALUE; do
    [ ! -z $VAR ] && [ "${VAR:0:1}" != "#" ] && export $VAR="$VALUE"
  done < $CFGFILENAME
else
  echo "Config file ($CFGFILENAME) was not found! Fatal error, end of script."
  exit
fi

BOOTDIR=$(findmnt /dev/mmcblk0p1 -n -o TARGET)
# We remove ourself from the kernel cmdline (init=/usr/lib/raspi-config/bootstrap.sh)
[ $BOOTDIR ] && sudo sed -ie 's/init=\/usr\/lib\/raspi-config\/bootstrap.sh//g' $BOOTDIR/cmdline.txt

# Start of sequence of execution of the child-scripts...
BASEDIR=/home/pi/raspi-mame-appliance/_staging
cd $BASEDIR
chmod +x *.sh

# Execution of child-scripts under context of user 'pi'...
# Switch user context and call scripts
$BASEDIR/RaspiOSSystemConfig.sh
$BASEDIR/RaspiOSAppsInstall.sh
$BASEDIR/RaspiOSDaemonsInstall.sh

# $BASEDIR/MakeDataPartitionAndMoveFiles.sh
# $BASEDIR/MakeRootFileSystemReadOnly.sh

echo "===================================================================="
echo "The steps are complete."
echo "Please double-check for any errors."
echo
echo "If error-free, this system is now ready to be imaged to a .img file."
echo
read -n1 -srp "Press any key to shutdown the system ..."
echo

echo "Shutting down..."
sudo poweroff
