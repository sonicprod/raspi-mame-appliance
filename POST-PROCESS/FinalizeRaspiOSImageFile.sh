#!/bin/bash

# - Mount the boot partition
# - Add the init=/usr/lib/raspi-config/Expand-Data-Partition.sh to $BOOTDIR/cmdline.txt
# - Mount the rootfs partition
# - Remove (rm) the bootstrap.service unit file and associated links (if applicable)
# - Cleanup command history, rm ~/.sudo_as_admin_successful ~/.lesshst
# - Fill the free space with zeros (/dev/zero) to make a more compact .img file, once compressed
# - Compress the image file with gzip
# - Print a message to inform that the SD card is ready to be published

# TO BE UPDATED - TO BE UPDATED - TO BE UPDATED - TO BE UPDATED - TO BE UPDATED -TO BE UPDATED -

if [ ! $1 ]; then
    echo Usage: $0 VER [zero]
    echo '  Where VER is the 4-digit version number of MAME to update (for example: 0224).'
    echo '  Where zero overwrite the free space with zeros to optimize compression.'
    exit
fi

# IMGNAME=rpi4b.raspios.mame-$1.appliance.img
IMGNAME=rpi4b.raspios.mame-$1.appliance.fe-edition.img
SCRIPTPATH=${0%/*}

if [ ! -f $IMGNAME ]; then
    echo $IMGNAME does not exist!
    exit
fi

if [ -f $IMGNAME.gz ]; then
    rm $IMGNAME.gz
fi

# Écrasement de l'espace libre de rootfs avec des zéros
if [ "$2" = "zero" ]; then
    $SCRIPTPATH/mount.part.rpi4b.raspios.mame.sh $1 rootfs zero
fi

echo -n "Compressing $IMGNAME..."
gzip -9 -k $IMGNAME
echo

ls -la $IMGNAME $IMGNAME.gz
