#!/bin/bash

# This script put the root (/) and /boot or /boot/firmware filesystems in read-only mode.
# Based on: https://medium.com/swlh/make-your-raspberry-pi-file-system-read-only-raspbian-buster-c558694de79

BOOTDIR=$(findmnt /dev/mmcblk0p1 -n -o TARGET)
[ $BOOTDIR ] && BOOTDIR=${BOOTDIR//\//\\/} || exit
# Check /etc/fstab to see if this script has already been executed
awk "/\/ /{print $4}" /etc/fstab | grep -q ro, && awk "/$BOOTDIR/{print $4}" /etc/fstab | grep -q ro, && echo 'This script has already been executed and your system is already in read-only mode.' && exit

echo ---------------------------------------------------------------------
echo This script will convert this system in read-only mode.
echo
echo The system will be automatically rebooted, once the script complete.
echo ---------------------------------------------------------------------
while true; do
    read -p "Do you wish to continue? " yn
    case ${yn,,} in
        y | yes) break;;
        n | no)  exit;;
        *) echo "Please answer yes or no.";;
    esac
done

# START
echo ---------------------------------------------------------------------
echo Applying the required changes to the system...
echo ---------------------------------------------------------------------

# Remove swap and other stuff
sudo apt-get remove --purge triggerhappy logrotate dphys-swapfile -y
sudo apt-get autoremove --purge -y

# Disable swap and filesystem check and set it to read-only
sudo sed -ie 's/^console=serial0,115200.*$/& fsck.mode=skip noswap ro/g' $BOOTDIR/cmdline.txt

# Replace your log manager
sudo apt-get install busybox-syslogd -y
sudo apt-get remove --purge rsyslog -y
# From now on, use sudo logread to check your system logs.

# /etc/fstab: Add read-only mode to /boot or /boot/firmware filesystems
sudo sed -i "/$BOOTDIR/{/ro/!s/\S\S*/&,ro/4}" /etc/fstab

# /etc/fstab: Add read-only mode to / root filesystem
sudo sed -i '/\S\s\s*\/\s\s*/{/\(ro,\|,ro\)/!s/\S\S*/&,ro/4}' /etc/fstab

# We append the temporary file systems to fstab
sudo tee -a /etc/fstab << 'EOF'
tmpfs     /tmp                       tmpfs   nosuid,nodev              0       0
tmpfs     /var/log                   tmpfs   nosuid,nodev              0       0
tmpfs     /var/tmp                   tmpfs   nosuid,nodev              0       0
tmpfs     /var/spool                 tmpfs   nosuid,nodev              0       0
# Samba
tmpfs     /var/lib/samba             tmpfs   nosuid,mode=0755,nodev    0       0
tmpfs     /var/lib/samba/private     tmpfs   nosuid,mode=0755,nodev    0       0
tmpfs     /var/log/samba             tmpfs   nosuid,mode=0755,nodev    0       0
tmpfs     /var/cache/samba           tmpfs   nodev,nosuid              0       0
tmpfs     /var/spool/samba           tmpfs   nodev,nosuid              0       0
tmpfs     /var/run/samba             tmpfs   nodev,nosuid              0       0
EOF

# Move some system files to temp filesystem
sudo rm -rf /var/lib/dhcp /var/lib/dhcpcd5 /var/spool /etc/resolv.conf
sudo ln -s /tmp /var/lib/dhcp
sudo ln -s /tmp /var/lib/dhcpcd5
sudo touch /tmp/dhcpcd.resolv.conf
sudo ln -s /tmp/dhcpcd.resolv.conf /etc/resolv.conf

# Update the systemd random seed
[ -f /var/lib/systemd/random-seed ] && sudo rm /var/lib/systemd/random-seed
[ ! -L /var/lib/systemd/random-seed ] && sudo ln -s /tmp/random-seed /var/lib/systemd/random-seed

# Systemd drop-in to ajust systemd-random-seed.service
if [ ! -f /etc/systemd/system/systemd-random-seed.service.d/readonlyfs-fixup.conf ]; then
  [ ! -d /etc/systemd/system/systemd-random-seed.service.d ] && sudo mkdir /etc/systemd/system/systemd-random-seed.service.d
  echo '[Service]' | sudo tee -a /etc/systemd/system/systemd-random-seed.service.d/readonlyfs-fixup.conf
  echo 'ExecStartPre=/bin/echo "" >/tmp/random-seed' | sudo tee -a /etc/systemd/system/systemd-random-seed.service.d/readonlyfs-fixup.conf
fi

# Shell commands to switch between RO and RW modes
grep -q "alias ro=" /etc/bash.bashrc || sudo tee -a /etc/bash.bashrc << 'EOF'
set_bash_prompt() {
    fs_mode=$(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p")
    PS1='\[\033[01;32m\]\u@\h${fs_mode:+($fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    }

alias ro="sudo mount -o remount,ro / ; sudo mount -o remount,ro $BOOTDIR"
alias rw="sudo mount -o remount,rw / ; sudo mount -o remount,rw $BOOTDIR"

PROMPT_COMMAND=set_bash_prompt

EOF

# To make sure the file system goes back to read-only once you log out
grep -q "sudo mount -o remount,ro /"     /etc/bash.bash_logout || echo 'sudo mount -o remount,ro /' | sudo tee -a /etc/bash.bash_logout
grep -q "sudo mount -o remount,ro $BOOTDIR" /etc/bash.bash_logout || echo 'sudo mount -o remount,ro $BOOTDIR' | sudo tee -a /etc/bash.bash_logout

# Alias ajustments
sed -ie "s/^alias arcademode=.*$/alias arcademode=\'rw; sudo systemctl enable mame-autostart.service; ro\'/g" ~/.bash_aliases
sed -ie "s/^alias servicemode=.*$/alias servicemode=\'rw; sudo systemctl disable mame-autostart.service; ro\'/g" ~/.bash_aliases

# Swap file removal
[ -f /var/swap ] && sudo rm /var/swap

# Purge of mount points content that switch to tmpfs
sudo systemctl stop smbd.service nmbd.service systemd-timesyncd.service
sudo rm -R /var/lib/samba/*
sudo rm -R /var/cache/samba/*
sudo rm -R /tmp/*
sudo rm -R /var/lib/systemd/timesync/*
sudo rm -R /var/log/*

# Systemd drop-ins for read-only mode ajustments
for i in raspberrypi-net-mods.service \
         systemd-rfkill \
         sshswitch.service \
         rpi-eeprom-update.service
do
  if [ ! $(systemctl -q is-enabled $i) ]; then
    [ ! -d /etc/systemd/system/$i.d ] && sudo mkdir /etc/systemd/system/$i.d
    if [ -f /etc/systemd/system/$i.d/readonlyfs-fixup.conf ]; then
      grep -q [Service] /etc/systemd/system/$i.d/readonlyfs-fixup.conf || echo '[Service]' | sudo tee -a /etc/systemd/system/$i.d/readonlyfs-fixup.conf
    else
      echo '[Service]' | sudo tee -a /etc/systemd/system/$i.d/readonlyfs-fixup.conf
    fi
    echo "ExecStartPre=/bin/sh  -c \"mount -o remount,rw $BOOTDIR; mount -o remount,rw /\"" | sudo tee -a /etc/systemd/system/$i.d/readonlyfs-fixup.conf
    echo "ExecStartPost=/bin/sh -c \"mount -o remount,ro $BOOTDIR; mount -o remount,ro /\"" | sudo tee -a /etc/systemd/system/$i.d/readonlyfs-fixup.conf
  fi
done

# Systemd drop-in for ajustment for systemd-timesyncd.service
sudo tee -a /etc/fstab << 'EOF'
# Timesyncd
tmpfs     /var/lib/private           tmpfs   nosuid,mode=0755,nodev    0       0
tmpfs     /var/lib/systemd/timesync  tmpfs   nosuid,mode=0755,nodev    0       0

EOF

[ ! -d /etc/systemd/system/systemd-timesyncd.service.d ] && sudo mkdir /etc/systemd/system/systemd-timesyncd.service.d
if [ -f /etc/systemd/system/systemd-timesyncd.service.d/readonlyfs-fixup.conf ]; then
  grep -q [Service] /etc/systemd/system/systemd-timesyncd.service.d/readonlyfs-fixup.conf || echo '[Service]' | sudo tee -a /etc/systemd/system/systemd-timesyncd.service.d/readonlyfs-fixup.conf
else
  echo '[Service]' | sudo tee -a /etc/systemd/system/systemd-timesyncd.service.d/readonlyfs-fixup.conf
fi
echo 'PrivateTmp=no' | sudo tee -a /etc/systemd/system/systemd-timesyncd.service.d/readonlyfs-fixup.conf
echo 'RestartSec=5' | sudo tee -a /etc/systemd/system/systemd-timesyncd.service.d/readonlyfs-fixup.conf

# Disable auto-update daemons
sudo systemctl stop    systemd-tmpfiles-clean.timer apt-daily.timer apt-daily-upgrade.timer man-db.timer systemd-tmpfiles-clean.service apt-daily-upgrade.service
sudo systemctl disable systemd-tmpfiles-clean.timer apt-daily.timer apt-daily-upgrade.timer man-db.timer systemd-tmpfiles-clean.service apt-daily-upgrade.service
sudo systemctl mask    systemd-tmpfiles-clean.timer systemd-tmpfiles-clean.service apt-daily-upgrade.service

# Systemd daemon reload to update changes
sudo systemctl daemon-reload

echo ---------------------------------------------------------------------
echo Completed.
echo The system will reboot NOW.
echo ---------------------------------------------------------------------

sudo reboot
