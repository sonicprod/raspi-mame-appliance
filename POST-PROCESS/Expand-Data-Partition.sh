#!/bin/bash

# Updated: 2025-06-02
# Author: Benoit Bégin
# 
# This script will expand /dev/mmcblk0p3 partition (data) to all the available space on the storage device.
# Runtime Context: root

echo ---------------------------------------------
echo CURRENT size of /data: $(df -Th /data | awk '/\/data/{print $3}')
echo ---------------------------------------------
umount /data
echo ', +' | sfdisk -q -N 3 --force --no-reread --no-tell-kernel /dev/mmcblk0
partprobe /dev/mmcblk0
resize.f2fs /dev/mmcblk0p3
mount -a
echo ---------------------------------------------
echo NEW size of /data: $(df -Th /data | awk '/\/data/{print $3}')
echo ---------------------------------------------
echo Expand operation completed.

# We remove ourself to prevent any re-run
rm /etc/systemd/system//multi-user.target.wants/first-run.service
rm /etc/systemd/system/first-run.service
# Systemd daemon reload to update changes
sudo systemctl daemon-reload
sleep 3

rm /usr/lib/raspi-config/Expand-Data-Partition.sh
reboot
