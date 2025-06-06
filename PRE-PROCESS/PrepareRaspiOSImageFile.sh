#!/bin/bash

# Updated: 2025-06-06
# Author: Benoit Bégin
# 
# This script:
#   - Download the latest official image file of Raspberry Pi OS Lite (arm64)
#   - Expand the 2nd partition and the ext4 root filesystem with an additional 16 GB of space
#   - Add a 3rd partition (type 83, Linux) with a size of 200 MB
#   - Format the 3rd partition with f2fs filesystem
#   - Enable SSH Server on first boot
#   - Auto-creating pi user with default password (raspberry)
#   - Install bootstrap.service Systemd unit file and script (bootstrap.sh) so the process can start automatically at first boot
#   - Optionnaly write the prepped disk image to a physical SD Card

IMGFILE=$(find . -maxdepth 1 -type f -name '20*.img.xz' -printf '%P\n' -quit)
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

IMGFILE=$(find . -maxdepth 1 -type f -ctime -1 -name '20*.img.xz' -printf '%P\n' -quit)

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

# We detach from all previous attach, if any
sudo losetup -D

# Create loop devices for each detected partitions/filesystems
sudo kpartx -av $IMGFILE && echo "Attaching loop devices OK"

# Get the loop device used
LOOPDEV=$(losetup -na -O name)
# Remove the /dev/ prefix
LOOPDEV=${LOOPDEV#/dev/}

# Mount points creation
sudo mkdir -p /mnt/ImageP1 /mnt/ImageP2 /mnt/ImageP3

echo "=========== Mounting boot partition..."
sudo mount /dev/mapper/${LOOPDEV}p1 /mnt/ImageP1 || echo "ERROR Mounting partition #1 !"

echo "=========== CUSTOMIZATION OF BOOT PARTITION ==========="

echo "=========== Enabling SSH Server on first boot..."
[ ! -f /mnt/ImageP1/ssh ] && sudo touch /mnt/ImageP1/ssh  || echo "ERROR Writing ssh file to partition #1 !"

echo "=========== Auto-creating pi user with default password (raspberry)..."
# The creation of the pi user will be done on first boot
[ ! -f /mnt/ImageP1/userconf.txt ] && echo "pi:$(echo raspberry | openssl passwd -6 -stdin)" | sudo tee /mnt/ImageP1/userconf.txt > /dev/null

echo "=========== Unmounting boot partition..."
sudo umount /mnt/ImageP1 || echo "ERROR Unmounting partition #1 !"

# We free the image from the devices, we need to expand it for P2
sudo kpartx -dv $IMGFILE && echo "Detaching loop devices OK"

echo "=========== PARTITIONS OPERATIONS ==========="
# Get the current partition table
PARTTAB=$(sfdisk -d $IMGFILE)

# Grow the image file: add 16 GB to expand root fs
echo "=========== Adding +16G to image file $IMGFILE..."
truncate --size=+16G $IMGFILE

# Expand rootfs partition entry in partition table
echo "=========== Expanding rootfs partition entry..."
echo ", +16G" | sfdisk -N 2 $IMGFILE

# We re-attach loop devices (normally 2 devices would be created)
sudo kpartx -av $IMGFILE && echo "Attaching loop devices OK"

# Get the loop device used
LOOPDEV=$(losetup -na -O name)
# Remove the /dev/ prefix
LOOPDEV=${LOOPDEV#/dev/}

# Check the root filesystem first
echo "=========== First, check the filesystem integrity..."
sudo e2fsck -f /dev/mapper/${LOOPDEV}p2

# Resize the root filesystem on loop0 device
echo "=========== Then, resize this filesystem to expand/use all available partition space..."
sudo resize2fs /dev/mapper/${LOOPDEV}p2 && echo "Resize/expand rootfs OK"

# We free the image from the devices, we need to expand it (again) for P3
sudo kpartx -dv $IMGFILE && echo "Detaching loop devices OK"

# Grow the image file: add 200 MB to make space for f2fs data rw partition
echo "=========== Adding +200M to image file $IMGFILE..."
truncate --size=+200M $IMGFILE

# We re-read the new partition table
PARTTAB=$(sfdisk -d $IMGFILE)

# Find end offset of partition 2
while read DEV COL VAR1 START VAR2 SIZE TAIL; do
  [ "${DEV: -1}" = "2" ] && [ "$VAR1" = "start=" ] && export OFFSETP3=$((${START//,/}+${SIZE//,/}))
done <<< $PARTTAB

# Create new partition with all available space, type Linux (83)
echo "=========== Creating/adding a new partition of type 83 (Linux) for f2fs data rw partition..."
echo "            Offset=$OFFSETP3"
echo "$OFFSETP3,,83;" | sfdisk --append $IMGFILE

# We re-attach loop devices (normally 3 devices would be created)
sudo kpartx -av $IMGFILE && echo "Attaching loop devices OK"

# Get the loop device used
LOOPDEV=$(losetup -na -O name)
# Remove the /dev/ prefix
LOOPDEV=${LOOPDEV#/dev/}

echo "=========== Formatting the 3rd partition with F2FS filesystem..."
command -v mkfs.f2fs >/dev/null 2>&1 || sudo apt install f2fs-tools -y
sudo mkfs.f2fs -l data /dev/mapper/${LOOPDEV}p3 || echo "ERROR Formatting partition #3!"
echo "=========== END OF PARTITIONS OPERATIONS ==========="

echo "=========== CUSTOMIZATION OF ROOTFS ==========="
echo "=========== Mounting the root filesystem..."
# Mount the root filesystem
sudo mount /dev/mapper/${LOOPDEV}p2 /mnt/ImageP2 || echo "Mounting of rootfs FAILED"

# We fetch bootstrap.sh from the Github repo...
[ ! -f bootstrap.sh ] && wget -q https://raw.githubusercontent.com/sonicprod/raspi-mame-appliance/refs/heads/main/PRE-PROCESS/bootstrap.sh

if [ ! -f bootstrap.sh ]; then
  echo "Error downloading bootstrap.sh from the Github repo!"
  exit
fi

echo "=========== Installing bootstrap.service unit file for Systemd..."
[ ! -f bootstrap.service ] && wget -q https://raw.githubusercontent.com/sonicprod/raspi-mame-appliance/refs/heads/main/PRE-PROCESS/bootstrap.service

sudo chmod 644 ./bootstrap.service || echo "ERROR Ajusting exec permission to bootstrap.service"
sudo mv bootstrap.service /mnt/ImageP2/etc/systemd/system/

# Enable unit by symlinking
sudo ln -sf /etc/systemd/system/bootstrap.service /mnt/ImageP2/etc/systemd/system/multi-user.target.wants/bootstrap.service

echo "=========== Moving bootstrap.sh to root filesystem..."
# We place it in the rootfs for the first execution
sudo mv bootstrap.sh /mnt/ImageP2/usr/lib/raspi-config/ || echo "ERROR Moving bootstrap.sh to root partition!"
sudo chmod +x /mnt/ImageP2/usr/lib/raspi-config/bootstrap.sh || echo "ERROR Ajusting exec permission to bootstrap.sh!"

echo "=========== Enabling persistent journald logging..."
# For debugging and review purpose
sudo sed -i "s/^#\{0,1\}Storage=.*$/Storage=persistent/g" /mnt/ImageP2/etc/systemd/journald.conf

echo "=========== Unmounting the root filesystem..."
# Unmount the root filesystem
sudo umount /mnt/ImageP2 || echo "Error unmounting of rootfs!"

# Detaching loop devices
sudo kpartx -dv $IMGFILE && echo "Detaching loop devices OK"

# Mount points removing
sudo rm -R /mnt/ImageP1 /mnt/ImageP2 /mnt/ImageP3
# -----------------------------

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
sudo dd if=./$IMGFILE of=/dev/$DEVICE status=progress bs=1M && echo "Write OK" || echo "ERROR Writing image file to /dev/$DEVICE"
sync
echo; echo DONE
