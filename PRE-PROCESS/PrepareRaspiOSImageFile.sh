#!/bin/bash

# Updated: 2025-04-23
# Author: Benoit Bégin
# 
# This script:
#   - Download the latest official image file of Raspberry Pi OS Lite (arm64)
#   - Expand the 2nd partition and the ext4 root filesystem with an additional 16 GB of space
#   - Add a 3rd partition (type 83, Linux) with a size of 100 MB
#   - Format the 3rd partition with f2fs filesystem
#   - Enable SSH Server on first boot
#   - Auto-creating pi user with default password (raspberry)
#   - Install bootstrap.service Systemd unit file and script (bootstrap.sh) so the process can start automatically at first boot
#   - Optionnaly write the prepped disk image to a physical SD Card

IMGFILE=$(find . -maxdepth 1 -type f -name '20*.img.xz' -print)
IMGFILE=${IMGFILE#"./"}	# Remove the ./ prefix
FETCHURL=https://downloads.raspberrypi.org/raspios_lite_arm64_latest
REEPOBASEURL=https://github.com/sonicprod/raspi-mame-appliance

if [ -n $IMGFILE ] && [ -f "$IMGFILE" ]; then
  echo "$IMGFILE already exist (already processed), aborting..."
  exit
fi

# Ask for sudo password at the beginning of the script so it can run uninterrupted
sudo echo -n

# Remove pre-existing prepped image, if exist
rm -f *_Prepped.img

echo "=========== Downloading the latest RaspiOS Lite arm64..."
# Get the latest RaspiOS Lite for arm64
wget --trust-server-names $FETCHURL

IMGFILE=$(find . -maxdepth 1 -type f -ctime -1 -name '20*.img.xz' -print)
IMGFILE=${IMGFILE#"./"}	# Remove the ./ prefix

if [ ! -f "$IMGFILE" ]; then
  echo "$IMGFILE does not exist, aborting..."
  exit
fi

echo -n "=========== Extracting the compressed image file..."
# Decompress the archive
[ -f ${IMGFILE%.*} ] && rm ${IMGFILE%.*}
unxz $IMGFILE
echo

# Remove the .xz extension
IMGFILE=${IMGFILE%.*}

echo "=========== PARTITIONS OPERATIONS ==========="
# Get the current partition table
PARTTAB=$(sfdisk -d $IMGFILE)

# Rootfs partition is #2
PARTNUM=2

# Grow the image file: add 16 GB to expand root fs
echo "=========== Adding +16G to image file $IMGFILE..."
truncate --size=+16G $IMGFILE

# Expand partition #2 (root fs)
echo "=========== Expanding root fs partition #$PARTNUM..."
echo ", +16G" | sfdisk -N 2 $IMGFILE

# Find start OFFSETP2 of partition PARTNUM
while read DEV COL VAR START TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR" = "start=" ] && export OFFSETP2=$((${START//,/}*512))
done <<< $PARTTAB

# Attach the image from OFFSETP2 to loop0 device
echo "=========== Attaching partition #$PARTNUM to /dev/loop0 device..."
sudo losetup -o $OFFSETP2 /dev/loop0 $IMGFILE

# Check the root filesystem first
echo "=========== First, check the filesystem integrity..."
sudo e2fsck -f /dev/loop0

# Resize the root filesystem on loop0 device
echo "=========== Then, resize this filesystem to expand/use all available partition space..."
sudo resize2fs /dev/loop0

echo "=========== Mounting the root filesystem..."
# Mount the root filesystem
[ ! -d /mnt/loop0 ] && sudo mkdir /mnt/loop0
sudo mount /dev/loop0 /mnt/loop0

# We fetch bootstrap.sh from the Github repo...
[ ! -f bootstrap.sh ] && wget https://raw.githubusercontent.com/sonicprod/raspi-mame-appliance/refs/heads/main/PRE-PROCESS/bootstrap.sh

if [ ! -f bootstrap.sh ]; then
  echo "Error downloading bootstrap.sh from the Github repo!"
  exit
fi

echo "=========== Installing bootstrap.service unit file for Systemd..."
[ ! -f bootstrap.service ] && wget https://raw.githubusercontent.com/sonicprod/raspi-mame-appliance/refs/heads/main/PRE-PROCESS/bootstrap.service

sudo chmod 644 ./bootstrap.service
sudo mv bootstrap.service /mnt/loop0/etc/systemd/system/

# Enable unit by symlinking
sudo ln -sf /etc/systemd/system/bootstrap.service /mnt/loop0/etc/systemd/system/multi-user.target.wants/bootstrap.service

echo "=========== Copy of bootstrap.sh to root filesystem..."
# And we place it in the rootfs for the first execution
sudo cp bootstrap.sh /mnt/loop0/usr/lib/raspi-config/
sudo chmod +x /mnt/loop0/usr/lib/raspi-config/bootstrap.sh

echo "=========== Enabling persistent journald logging..."
# For debugging and review purpose
sudo sed -i "s/^#\{0,1\}Storage=.*$/Storage=persistent/g" /mnt/loop0/etc/systemd/journald.conf

echo "=========== Unmounting the root filesystem..."
# Unmount the root filesystem
sudo umount /dev/loop0

# Detach from the loop0 device
echo "=========== Detaching partition #$PARTNUM from /dev/loop0 device..."
sudo losetup -d /dev/loop0

# We re-read the new partition table
PARTTAB=$(sfdisk -d $IMGFILE)

# Find end offset of partition PARTNUM
while read DEV COL VAR1 START VAR2 SIZE TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR1" = "start=" ] && export OFFSETP3=$((${START//,/}+${SIZE//,/}))
done <<< $PARTTAB

# Grow the image file: add 100 MB to make space for f2fs data rw partition
echo "=========== Adding +100M to image file $IMGFILE..."
truncate --size=+100M $IMGFILE

# Create new partition with all available space, type Linux (83)
echo "=========== Creating/adding a new partition of type 83 (Linux) for f2fs data rw partition..."
echo "$OFFSETP3,,83;" | sfdisk --append $IMGFILE

# Attach the image from OFFSETP3 to loop0 device
echo "=========== Attaching the 3rd partition to /dev/loop0 device..."
sudo losetup -o $(($OFFSETP3*512)) /dev/loop0 $IMGFILE

echo "=========== Formatting the 3rd partition with F2FS filesystem..."
command -v mkfs.f2fs >/dev/null 2>&1 || sudo apt install f2fs-tools -y
sudo mkfs.f2fs -l data /dev/loop0

# Detach from the loop0 device
echo "=========== Detaching the 3rd partition from /dev/loop0 device..."
sudo losetup -d /dev/loop0

echo "=========== CUSTOMIZATIONS OPERATIONS ==========="

# Enable SSH server on first boot
echo "=========== Enabling SSH Server on first boot..."
# Mount first partition (boot)

# Bootfs partition is #1
PARTNUM=1

# Find start offset of partition PARTNUM
while read DEV COL VAR START TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR" = "start=" ] && export OFFSETP1=$((${START//,/}*512))
done <<< $PARTTAB

# Mount the boot partition
echo "=========== Mounting boot partition..."
[ ! -d /mnt/loop0 ] && sudo mkdir /mnt/loop0
sudo mount -o offset=$OFFSETP1 $IMGFILE /mnt/loop0

echo "=========== Enabling SSH with ssh dummy file..."
[ ! -f /mnt/loop0/ssh ] && sudo touch /mnt/loop0/ssh

echo "=========== Auto-creating pi user with default password (raspberry)..."
# The creation of the pi user will be done on first boot
[ ! -f /mnt/loop0/userconf.txt ] && echo "pi:$(echo raspberry | openssl passwd -6 -stdin)" | sudo tee /mnt/loop0/userconf.txt > /dev/null

echo "=========== Unmounting boot partition..."
sudo umount /mnt/loop0
sudo rmdir /mnt/loop0

# Add _Prepped suffix to image file
mv $IMGFILE ${IMGFILE%.img}_Prepped.img
IMGFILE=${IMGFILE%.img}_Prepped.img

echo "=========== DONE!"; echo

lsblk -f
echo
echo ---------------------------------------------------------------------
echo "     Would you like to write the image file to an SD Card?"
echo
echo "      You can now plug your SD Card, if not already done."
echo ---------------------------------------------------------------------
while true; do
    read -p "Please answer by yes or no : " yn
    case ${yn,,} in
        y | yes) break;;
        n | no)  exit;;
        *) echo "Please answer by yes or no.";;
    esac
done

while true; do
    echo; echo
    lsblk -f
    echo
    read -p "Please input the DISK device (just the name, without the /dev prefix) to write to: " DEVICE
    echo
    if [ -z $DEVICE ]; then
      echo "Aborting..."
      exit
    fi

    [ $(findmnt / -no source | grep /dev/$DEVICE) ] && echo "!!! WARNING !!! - The root / filesystem is mounted on this DISK (/dev/$DEVICE)!"

    echo
    echo "Are you sure to write the image file to /dev/$DEVICE disk device?"
    read -p "Please answer by yes or no : " yn
    case ${yn,,} in
        y | yes) break;;
        n | no)  ;;
        *) echo "Please answer by yes or no.";;
    esac
done

# Unmount all mounted partitions of $DEVICE
for PART in $(cat /proc/mounts | grep /dev/$DEVICE | awk '{print $1}' | tr '\n' ' ');
do
  echo Unmounting $PART...
  sudo umount $PART
done

echo; echo
echo "Writing $IMGFILE to SD Card (/dev/$DEVICE)..."
# Writing image to SD Card
sudo dd if=./$IMGFILE of=/dev/$DEVICE status=progress bs=1M
