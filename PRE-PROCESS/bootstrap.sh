#!/bin/bash

# Updated: 2025-06-02
# Author: Benoit Bégin
# 
# This is the "bootstrap" script that chain the "offline" preparation of the image and
# transfer/pass the execution to the "online" configuration and build/installation steps.
#
# This script:
#   - Git clone the Github repo
#   - Read the config file and make variables global
#   - Call the sequence of scripts for the customizations and the building of apps and services
#   - Disable the Systemd unit we we're launched from
#   - Displaying a message to image the SD card to a .img file

GITHUB_SRCBASE=https://github.com/sonicprod/raspi-mame-appliance
CFGFILENAME=/home/pi/raspi-mame-appliance/_staging/Config.ExportPublicImage.cfg

# Let the network be completely ready
sleep 5

# The clock HAS to be syncronized before we apt-get install
# Let's use a generic NTP server and force an initial sync
sudo sed -i "s/^#\{0,1\}NTP=.*$/NTP=pool.ntp.org/g" /etc/systemd/timesyncd.conf

sudo systemctl restart systemd-timesyncd
sudo timedatectl set-ntp off
sudo timedatectl set-ntp on

# Let the timesync to occur...
sleep 15

# For logging and debug purpose
timedatectl status

# Initial source repo update...
sudo apt-get update

# Git clone the repo to get the latest versions of the needed files and scripts...
cd /home/pi
[ $(command -v git) ] || sudo apt-get install git -y
[-d raspi-mame-appliance ] && sudo rm -R raspi-mame-appliance
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

# Start of sequence of execution of the child-scripts...
BASEDIR=/home/pi/raspi-mame-appliance/_staging
cd $BASEDIR
chmod +x *.sh

# Execution of child-scripts under context of user 'pi'...
# Switch user context and call scripts
echo "================== RaspiOSSystemConfig.sh =================="
$BASEDIR/RaspiOSSystemConfig.sh
echo "================== RaspiOSAppsInstall.sh =================="
$BASEDIR/RaspiOSAppsInstall.sh
echo "================== RaspiOSDaemonsInstall.sh =================="
$BASEDIR/RaspiOSDaemonsInstall.sh
echo "================== MakeDataPartitionAndMoveFiles.sh =================="
$BASEDIR/MakeDataPartitionAndMoveFiles.sh
# echo "================== MakeRootFileSystemReadOnly.sh =================="
# $BASEDIR/MakeRootFileSystemReadOnly.sh

# We disable the Systemd unit we we're launched from
sudo systemctl disable bootstrap.service

# Cleanup, we remove the raspi-mame-appliance folder
cd /home/pi
sudo rm -R ./raspi-mame-appliance
sudo apt-get autoremove -y

echo "===================================================================="
echo "                     The steps are complete."
echo "===================================================================="
echo "Please double-check for any errors."
echo
echo "To see the log, issue:"
echo
echo "    journalctl | grep bootstrap"
echo
echo "If error-free, this system is now ready to be imaged to a .img file."
echo
echo
echo "                     End of online automation..."


