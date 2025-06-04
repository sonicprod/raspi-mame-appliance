#!/bin/bash

# Updated: 2025-06-03
# Author: Benoit Bégin
# 
# This script installs the necessary daemons for the system to act as a MAME appliance
#
# This script create the following systemd services (daemons):
#   - mame-autostart.service
#   - mame-artwork-mgmt.service
#   - mame-bootsplash.service
#   - mame-shutdownsplash.service
#   - shutdown.service

# Installation des dépendances
# mame-artwork-mgmt.service: inotify-tools
sudo apt-get install inotify-tools -y

# Installation des services
cd /home/pi/raspi-mame-appliance/_staging/etc/systemd/system
sudo cp mame-autostart.service \
        mame-bootsplash.service \
        mame-shutdownsplash.service \
        mame-artwork-mgmt.service \
        shutdown.service /etc/systemd/system

# Réactivation du curseur dans la console lorsque le getty@tty1 est activé (Service Mode)...
echo "setterm --cursor on" | tee -a /home/pi/.bashrc

# Suppression des messages au démarrage...
BOOTDIR=$(findmnt /dev/mmcblk0p1 -n -o TARGET)
sudo sed -i "s/^console=tty1/console=tty3/g" $BOOTDIR/cmdline.txt
sudo sed -i "s/^console=.*$/& logo.nologo vt.global_cursor_default=0 quiet fsck.mode=skip/g" $BOOTDIR/cmdline.txt

# Affichage de l’écran de démarrage (Custom Boot Splash)
sudo apt-get install fim -y

# Création du dossier des images de splash
mkdir /home/pi/splash
cp /home/pi/raspi-mame-appliance/splash/*.jpg /home/pi/splash

# Systemd daemon reload to update changes
sudo systemctl daemon-reload
sleep 3

# Partage de /data via Samba
# Installation du serveur Samba et des binaires associés :
sudo apt-get install samba samba-common-bin -y
sudo patch /etc/samba/smb.conf < /home/pi/raspi-mame-appliance/_staging/etc/samba/smb.conf.patch && echo "Patching smb.conf OK"
sudo systemctl restart smbd.service

# Désactivation de ces 2 services pour forcer le Service Mode à ce stade
sudo systemctl disable mame-autostart.service
sudo systemctl disable shutdown.service
# Activation des services
sudo systemctl enable mame-bootsplash.service
sudo systemctl enable mame-shutdownsplash.service
sudo systemctl enable mame-autostart.service
sudo systemctl enable mame-artwork-mgmt.service

