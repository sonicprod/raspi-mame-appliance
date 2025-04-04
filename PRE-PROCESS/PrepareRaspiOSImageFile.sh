#/bin/bash

# Updated: 2025-04-04
# Author: Benoit Bégin
# 
# This script:
#   - Download the latest official image file of Raspberry Pi OS Lite (arm64)
#   - Expand the 2nd partition and the ext4 root filesystem with an additional 16 GB of space
#   - Add a 3rd partition (type 83, Linux) with a size of 100 MB
#   - Format the 3rd partition with f2fs filesystem
#   - Enable SSH Server on first boot
#   - Auto-creating pi user with default password (raspberry)
#   - Seed a branching script (bootstrap.sh) so the process can start automatically at first boot

IMGFILE=$(find . -maxdepth 1 -type f -name '20*.img.xz' -print)
IMGFILE=${IMGFILE#"./"}	# Remove the ./ prefix

if [ -n $IMGFILE ] && [ -f "$IMGFILE" ]; then
  echo "$IMGFILE already exist (already processed), aborting..."
  exit
fi

# Ask for sudo password at the beginning of the script so it can run uninterrupted
sudo echo -n

FETCHURL=https://downloads.raspberrypi.org/raspios_lite_arm64_latest
echo "=========== Downloading the latest RaspiOS Lite arm64..."
# Get the latest RaspiOS Lite for arm64
wget --trust-server-names $FETCHURL

IMGFILE=$(find . -maxdepth 1 -type f -ctime -1 -name '20*.img.xz' -print)
IMGFILE=${IMGFILE#"./"}	# Remove the ./ prefix

if [ ! -f "$IMGFILE" ]; then
  echo "$IMGFILE does not exist, aborting..."
  exit
fi

echo "=========== Extracting the compressed image file..."
# Decompress the archive
[ -f ${IMGFILE%.*} ] && rm ${IMGFILE%.*}
unxz $IMGFILE

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
wget https://github.com/sonicprod/raspi-mame-appliance/blob/9c7a686c745dbe86b9aca20291e15349cdd07ca4/PRE-PROCESS/bootstrap.sh

if [ ! -f bootstrap.sh ]; then
  echo "Error downloading bootstrap.sh from the Github repo!"
  exit
fi

# And we place it in the rootfs for the first execution
sudo mv bootstrap.sh /mnt/loop0/usr/lib/raspi-config/
sudo chmod +x /mnt/loop0/usr/lib/raspi-config/bootstrap.sh

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

# Seeding the bootstrap.sh initial script...
# 1. We remove this part at the end "init=/usr/lib/raspberrypi-sys-mods/firstboot"
sudo sed -ie 's/init=\/usr\/lib\/raspberrypi-sys-mods\/firstboot*//g' /mnt/loop0/cmdline.txt
# 2. We add to cmdline.txt: init=/usr/lib/raspi-config/bootstrap.sh
sudo sed -ie 's/^console=serial0,115200.*$/& init=\/usr\/lib\/raspi-config\/bootstrap.sh/g' /mnt/loop0/cmdline.txt

echo "=========== Unmounting boot partition..."
sudo umount /mnt/loop0
sudo rmdir /mnt/loop0

# Add _Prepped suffix to image file
mv $IMGFILE ${IMGFILE%.img}_Prepped.img

echo "=========== DONE!"
