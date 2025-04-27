#/bin/bash

# Updated: 2025-04-27
# Author: Benoit Bégin
#
# This script:
#  - Create and format the /data r/w partition with F2FS filesystem
#  - Move some files to this newly created partition
#  - Make some symlinks to the newly created partition

# La partition /data sera en lecture/écriture et utilisera
# le système de fichiers F2FS (Flash-Friendly File System)
# https://en.wikipedia.org/wiki/F2FS


# Création du point de montage /data
[ ! -d /data ] && sudo mkdir /data

# Check if /data can be successfully mounted...
if ( ! sudo mount -t f2fs -o rw /dev/mmcblk0p3 /data ); then
  if [ "$(getconf PAGESIZE)" == "4096" ]; then
    # Raspberry Pi 4/4b avec pagesize de 4 Kb...
    # Installer les binaires pour le système de fichiers F2FS :
    sudo apt-get install f2fs-tools -y

    # Formatage de la partition (déjà existante) avec le système de fichiers F2FS...
    sudo mkfs.f2fs -f -l data /dev/mmcblk0p3 && echo  === Format is OK ||  === Format FAILED
  elif [ "$(getconf PAGESIZE)" == "16384" ]; then
    echo "======== Raspberry Pi 5 with 16k pages..."
    # Raspberry Pi 5 avec pagesize de 16 Kb...
    # We remove the stable branch f2fs-tools, if present
    sudo apt-get remove f2fs-tools -y
    # Install the g-dev-test branch of f2fs-tools
    wget https://github.com/jaegeuk/f2fs-tools/archive/refs/heads/g-dev-test.zip || echo "=== Download of f2fs-tools g-dev-test FAILED"
    unzip g-dev-test.zip
    cd f2fs-tools-g-dev-test
    # Install build dependencies
    sudo apt-get install automake libtool -y
    ./autogen.sh && ./configure && make
    sudo make install
    sudo ldconfig
    cd ..
    sudo rm -Rf f2fs-tools-g-dev-test/
    rm -f g-dev-test.zip

    # Formatting the partition with F2FS with a 16k blocksize (-b parameter)
    sudo mkfs.f2fs -f -b 16384 -l data /dev/mmcblk0p3 && echo "=== Format is OK" || echo "=== Format FAILED"

    # For mount support, we need kernel 6.12 and up...
    # A reboot will be needed to use the new kernel...
    echo y | sudo RPI_REBOOT=1 rpi-update rpi-6.12.y
  fi
fi

if [ "$(findmnt /data -n -o TARGET,SOURCE,FSTYPE)" != "/data  /dev/mmcblk0p3 f2fs" ]; then
  echo "ERROR: /data *has* to be mounted at this point!"
  exit
fi

############### FSTAB
echo "=== Mount is OK ==="
# Ajout du montage automatique dans /etc/fstab (si pas déjà présent)...
grep -q "/dev/mmcblk0p3        /data           f2fs" /etc/fstab || \
 sudo sed -ie '\/\s ext4.*/a\/dev/mmcblk0p3        /data           f2fs    defaults,noatime    0    2' /etc/fstab
#################

# ******* À partir de ce point, /data *est* monté, mais pas nécessairement dans /etc/fstab *******

# On vérifie si le script n'a pas déjà été exécuté
if [ -f /data/mame/ini/mame.ini ]; then
  echo "This script has already been executed. It must be executed only once."
  exit
fi

# Création des sous-dossiers, ajustement des permissions, du propriétaire (*owner*) et du groupe
cd /data
sudo mkdir -p mame hypseus attract advance
cd ~/mame
sudo mkdir -p artwork cabinets cfg cpanels ctrlr diff flyers hi history icons ini inp lua marquees memcard pcb nvram roms snap sta titles ui
sudo chown -R pi:pi /data
sudo chmod -R 3774 /data

# Déplacement des données vers la partition persistante /data
# Déplacement des fichiers de configuration de MAME (ui.ini, mame.ini, plugin.ini et hiscore.ini) vers /data/mame/ini (rw)

cd ~/.mame
mv mame.ini ui.ini plugin.ini hiscore.ini /data/mame/ini

# Si applicable, déplacer les autres éléments vers /data (rw)
mv ~/.mame/history.xml /data/mame/history
mv ~/mame/roms/*       /data/mame/roms/
mv ~/mame/snap/*       /data/mame/snap/
mv ~/mame/artwork/*    /data/mame/artwork/
mv ~/mame/ctrlr/*      /data/mame/ctrlr/

mv ~/.advance/*        /data/advance/
mv ~/.attract/*        /data/attract/
mv ~/.hypseus/*        /data/hypseus/

# Création des symlinks…

# Pour permettre à MAME de trouver son fichier de configuration mame.ini, un symlink est nécessaire...
ln -s ./ini/mame.ini /data/mame/mame.ini

# Redirection des dossiers vers /data afin de permettre la persistence des réglages et données des jeux
# ainsi qu'une gestion facilitée des ROMs et du matériel graphique associé...

cd ~/mame
rm -Rf roms ctrlr snap nvram history artwork
cd ~; rmdir .mame .hypseus .advance .attract

ln -s /data/mame    ~/.mame
ln -s /data/attract ~/.attract
ln -s /data/advance ~/.advance
ln -s /data/hypseus ~/.hypseus

# Folder to save High Scores (MAME 0.237 and up)
[ -f /data/mame/lua/hiscore/plugin.cfg ] && mv /data/mame/lua/hiscore/plugin.cfg /data/mame/hi
rmdir /data/mame/lua/hiscore
ln -s /data/mame/hi /data/mame/lua/hiscore

# Folder to save audio settings (volume)
sudo mkdir -p /data/.sys/alsa
sudo chown -R root:pi /data/.sys

# Folder to save system environnement variables
mkdir -p /data/.sys/env
# File ~/settings already exist, we move it to persistent /data and link it...
mv /home/pi/settings /data/.sys/env && ln -s /data/.sys/env/settings /home/pi/settings

# We grant rw to owner pi and pi group
sudo chown -R pi:pi /data/.sys/env
sudo chmod -R 664 /data/.sys/env/*

# We grant Read+Execute (for directory traversal) to Group+Other
sudo chmod -R 755 /data/.sys

sudo mv /var/lib/alsa/asound.state /data/.sys/alsa

# We revoke the Execute for Group+Other to the files under alsa
sudo chmod -R 744 /data/.sys/alsa/*

sudo rmdir /var/lib/alsa
sudo ln -s /data/.sys/alsa /var/lib/alsa

