#!/bin/bash
# Updated: 2025-06-03
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

SRCIMG=SDCard_Imaged.img

# Image back the SD card to an image file
echo "Please put the SD card in the  slot and press a key when done..."
dd if=/dev/sdX of=$SRCIMG status=progress

# We mount the rootfs from the image...
sudo losetup $IMGNAME -o $OFFSET    # Offset for the rootfs
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

# Overwrite free space with zeros for maximum compression ratio of the image
dd if=/dev/zero of=zero
rm zero

# Target image name
IMGNAME=rpi4up.raspios.mame-$MAMEVER.appliance.fe-edition.img
# We delete the target image, if it already exist
rm -f $IMGNAME.gz

echo -n "Compressing $IMGNAME..."
gzip -9 -k $IMGNAME
echo

ls -la $IMGNAME $IMGNAME.gz
