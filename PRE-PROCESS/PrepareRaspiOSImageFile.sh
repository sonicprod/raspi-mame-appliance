#/bin/bash

# Updated: 2025-02-25
# Author: Benoit Bégin
# 
# This script:
#   - Download the latest official image file of Raspberry Pi OS Lite (arm64)
#   - Expand the 2nd partition and the ext4 root filesystem with an additional 16 GB of space
#   - Add a 3rd partition (type 83, Linux) with a size of 100 MB
#   - Enable SSH Server on first boot

FETCHURL=https://downloads.raspberrypi.org/raspios_lite_arm64_latest
IMGFILE=raspios-lite-arm64-latest.img

# Ask for sudo password at the beginning of the script so it can run uninterrupted
sudo echo -n

echo "=========== Downloading the latest RaspiOS Lite arm64..."
# Get the latest RaspiOS Lite for arm64
wget $FETCHURL -O ${IMGFILE}.xz

echo "=========== Extracting the compressed image file..."
# Decompress the archive
unxz ${IMGFILE}.xz

echo "=========== PARTITIONS OPERATIONS ==========="
# Get the current partition table
PARTTBL=$(sfdisk -d $IMGFILE)

# Rootfs partition is #2
PARTNUM=2

# Grow the image file: add 16 GB to expand root fs
echo "=========== Adding +16G to image file $IMGFILE..."
truncate --size=+16G $IMGFILE

# Expand partition #2 (root fs)
echo "=========== Expanding root fs partition #$PARTNUM..."
echo ", +16G" | sfdisk -N 2 $IMGFILE

# Find start offset of partition PARTNUM
while read DEV COL VAR START TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR" = "start=" ] && export OFFSET=$((${START//,/}*512))
done <<< $PARTTBL

# Attach the image from offset to loop0 device
echo "=========== Attaching partition #$PARTNUM to /dev/loop0 device..."
sudo losetup -o $OFFSET /dev/loop0 $IMGFILE

# Check the root filesystem first
echo "=========== First, check the filesystem integrity..."
sudo e2fsck -f /dev/loop0

# Resize the root filesystem on loop0 device
echo "=========== Then, resize this filesystem to expand/use all available partition space..."
sudo resize2fs /dev/loop0

# Detach from the loop0 device
echo "=========== Detaching partition #$PARTNUM from /dev/loop0 device..."
sudo losetup -d /dev/loop0

# We re-read the new partition table
PARTTBL=$(sfdisk -d $IMGFILE)

# Find end offset of partition PARTNUM
while read DEV COL VAR1 START VAR2 SIZE TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR1" = "start=" ] && export ROOTEND=$((${START//,/}+${SIZE//,/}))
done <<< $PARTTBL

# Grow the image file: add 100 MB to make space for f2fs data rw partition
echo "=========== Adding +100M to image file $IMGFILE..."
truncate --size=+100M $IMGFILE

# Create new partition with all available space, type Linux (83)
echo "=========== Creating/adding a new partition of type 83 (Linux) for f2fs data rw partition..."
echo "$ROOTEND,,83;" | sfdisk --append $IMGFILE

echo "=========== CUSTOMIZATIONS OPERATIONS ==========="

# Enable SSH server on first boot
echo "=========== Enabling SSH Server on first boot..."
# Mount first partition (boot)

# Bootfs partition is #1
PARTNUM=1
# Find start offset of partition PARTNUM
while read DEV COL VAR START TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR" = "start=" ] && export OFFSET=$((${START//,/}*512))
done <<< $PARTTBL

# Attach the image from offset to loop0 device
echo "=========== Attaching partition #$PARTNUM to /dev/loop0 device..."
sudo losetup -o $OFFSET /dev/loop0 $IMGFILE

# Mount the boot partition
echo "=========== Mounting boot partition..."
[ ! -d /mnt/loop0 ] && sudo mkdir /mnt/loop0
sudo mount /dev/loop0 /mnt/loop0

echo "=========== Enabling SSH with ssh dummy file..."
[ ! -f /mnt/loop0/ssh ] && sudo touch /mnt/loop0/ssh

echo "=========== Unmounting boot partition..."
sudo umount /dev/loop0
sudo rmdir /mnt/loop0

# Detach from the loop0 device
echo "=========== Detaching partition #$PARTNUM from /dev/loop0 device..."
sudo losetup -d /dev/loop0

# From /mnt/loop0/cmdline.txt 
#  console=serial0,115200 console=tty1 root=PARTUUID=8a438930-02 rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspberrypi-sys-mods/firstboot
# We need to remove this part at the end "init=/usr/lib/raspberrypi-sys-mods/firstboot"

echo "=========== DONE!"
