#/bin/bash

# This script take as an input the raw image file of Raspberry Pi OS Lite and:
#   - Expand the 2nd partition and the ext4 root filesystem with an additional 16 GB of space
#   - Add a 3rd partition (type 83, Linux) with a size of 100 MB

IMGFILE=2024-11-19-raspios-bookworm-arm64-lite.img
DUMP=$(sfdisk -d $IMGFILE)
PARTNUM=2

# Grow the image file: add 16 GB to expand root fs
truncate --size=+16G $IMGFILE

# Expand partition #2 (root fs)
echo ", +16G" | sfdisk -N 2 $IMGFILE

# Find start offset of partition PARTNUM
while read DEV COL VAR START TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR" = "start=" ] && export OFFSET=$((${START//,/}*512))
done <<< $DUMP

# Attach the image from offset to loop0 device
sudo losetup -o $OFFSET /dev/loop0 $IMGFILE

# Check the root filesystem first
sudo e2fsck -f /dev/loop0

# Resize the root filesystem on loop0 device
sudo resize2fs /dev/loop0

# Detach from the loop0 device
sudo losetup -d /dev/loop0

# Back to image disk mode, we print the new partition table
sudo fdisk -l $IMGFILE

# We re-read the new partition table
DUMP=$(sfdisk -d $IMGFILE)

# Find end offset of partition PARTNUM
while read DEV COL VAR1 START VAR2 SIZE TAIL; do
  [ "${DEV: -1}" = "$PARTNUM" ] && [ "$VAR1" = "start=" ] && export ROOTEND=$((${START//,/}+${SIZE//,/}))
done <<< $DUMP

# Grow the image file: add 100 MB to make space for f2fs data rw partition
truncate --size=+100M $IMGFILE

# Create new partition with all available space, type Linux (83)
echo "$ROOTEND,,83;" | sfdisk --append $IMGFILE
