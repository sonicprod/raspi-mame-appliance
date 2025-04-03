#!/bin/bash

# This script will expand /dev/mmcblk0p3 partition (data) to all the available space on the storage device.

if (systemctl -q is-active mame-autostart.service) then
    echo "The system must be put in SERVICE Mode first."
    exit
fi

echo ---------------------------------------------
echo CURRENT size of /data: $(df -Th /data | awk '/\/data/{print $3}')
echo ---------------------------------------------
sudo umount /data
echo ', +' | sudo sfdisk -q -N 3 --force --no-reread --no-tell-kernel /dev/mmcblk0
sudo partprobe /dev/mmcblk0
sudo resize.f2fs /dev/mmcblk0p3
sudo mount -a
echo ---------------------------------------------
echo NEW size of /data: $(df -Th /data | awk '/\/data/{print $3}')
echo ---------------------------------------------
echo Expand operation completed.
