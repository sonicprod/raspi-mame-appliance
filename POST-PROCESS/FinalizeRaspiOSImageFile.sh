#!/bin/bash
# Updated: 2025-06-04
# Author: Benoit Bégin

# This script:
# - Image back the SD card to an image file
# - Mount the boot partition
# - Mount the rootfs partition
# - Remove (rm) the bootstrap.service unit file and associated links (if applicable)
# - Copy POST-PROCESS/Expand-Data-Partition.sh to /usr/lib/raspi-config/
# - Install the first-run.service, wich calls /usr/lib/raspi-config/Expand-Data-Partition.sh
# - Comment Storage= in /etc/systemd/journald.conf
# - Cleanup command history, journalctl, rm ~/.sudo_as_admin_successful ~/.lesshst
# - Fill the free space with zeros (/dev/zero) to make a more compact .img file, once compressed
# - Compress the image file with gzip
# - Print a message to inform that the SD card is ready to be published

# TO BE UPDATED - TO BE UPDATED - TO BE UPDATED - TO BE UPDATED - TO BE UPDATED -TO BE UPDATED -

CFGURL=https://raw.githubusercontent.com/sonicprod/raspi-mame-appliance/refs/heads/main/_staging
CFGFILENAME=Config.ExportPublicImage.cfg

SRCIMG=SDCard_Imaged.img

# We re-fetch the config file and parse it
CFG=$(wget -q -O - $CFGURL/$CFGFILENAME)
# Load config file settings for effective cleanup...
if [ ! -z $CFG ]; then
  while IFS="= " read VAR VALUE; do
    [ ! -z $VAR ] && [ "${VAR:0:1}" != "#" ] && export $VAR="$VALUE"
  done <<< "$CFG"
else
  echo "Config file ($CFGFILENAME) was not found! Fatal error, end of script."
  exit
fi

# Image back the SD card to an image file
echo "Please put the SD card in the  slot and press a key when done..."
dd if=/dev/sdX of=$SRCIMG status=progress

# ------------------------------------
# We mount the rootfs from the image...
sudo losetup $IMGNAME -o $ROOTOFFSET    # Offset for the rootfs
sudo mkdir /mnt/loop0
sudo mount /dev/loop0 /mnt/loop0

# Install first-run.service and enable it (link)
sudo cp POST-PROCESS/first-run.service $ROOTMNT/etc/systemd/system
sudo ln -sf /etc/systemd/system/first-run.service /mnt/loop0/etc/systemd/system/multi-user.target.wants/first-run.service

# Remove the bootstrap.service unit file and associated link (if present)
sudo rm -f /mnt/loop0/etc/systemd/system/bootstrap.service
sudo rm -f /mnt/loop0/etc/systemd/system/multi-user.target/bootstrap.service

# Get the MAME version inside the rootfs partition
cd /mnt/loop0/home/pi
MAMEVER=$(find . -maxdepth 1 -type d -name "mame*" -printf '%P\n' -quit)
MAMEVER=${MAMEVER#mame}

# Flush ALL journalctl entries
sudo rm -R /var/log/journal/*

# Flush history data
cd /mnt/loop0/home/pi
rm .bash_history .sudo_as_admin_successful .lesshst .wget-hsts

# ------------------------------------
# Overwrite free space with zeros for maximum compression ratio of the image
dd if=/dev/zero of=zero
rm zero

# Unmount rootfs
sudo umount /mnt/loop0
sudo rmdir /mnt/loop0

# ------------------------------------
# Mount data r/w filesystem
sudo losetup $IMGNAME -o $DATAOFFSET    # Offset for the data
sudo mkdir /mnt/loop0
sudo mount /dev/loop0 /mnt/loop0

# Jump into the data filesystem and remove test ROM and related files, if present
[ ! -z $TestGame ] && find /mnt/loop0/mame -type f -name $TestGame.* | xargs rm

# Cleanup traces of MAME ROM tests
sudo sed -i 's/last_used_machine.*$/last_used_machine          /g' /mnt/loop0/mame/ini/ui.ini

# ------------------------------------
cd /mnt/loop0/
# Overwrite free space with zeros for maximum compression ratio of the image
dd if=/dev/zero of=zero
rm zero

# Unmount data
sudo umount /mnt/loop0
sudo rmdir /mnt/loop0


# Target image name
IMGNAME=rpi4up.raspios.mame-$MAMEVER.appliance.fe-edition.img
# We delete the target image, if it already exist
rm -f $IMGNAME.xz

echo -n "Compressing $IMGNAME with xz..."
# We keep the original file with -k
xz -k $IMGNAME
echo

ls -la $IMGNAME $IMGNAME.xz
