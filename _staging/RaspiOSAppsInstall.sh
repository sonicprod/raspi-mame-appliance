#!/bin/bash

# Updated: 2025-06-03
# Author: Benoit Bégin
# 
# This script built and installs the applications and their dependencies
#
# This script:
#   - Build SDL2 (latest)
#   - Build MAME (latest)
#   - Build Hypseus-Singe (latest)


# Launch SDL2 custom build...
/home/pi/scripts/sdl2-latest.sh

# Launch MAME custom build...
/home/pi/scripts/mame-updater.sh latest

# We enable scanlines in MAME games
sed -i "s/effect .*$/effect                    scanlines/g" /home/pi/.mame/mame.ini

# Activation de 2 plugins (data et hiscore)...
tee /home/pi/.mame/plugin.ini << 'EOF'
#
# PLUGINS OPTIONS
#
cheat                     0
cheatfind                 0
console                   0
data                      1
dummy                     0
gdbstub                   0
hiscore                   1
layout                    0
portname                  0
timer                     0
EOF

# Ajustement du chemin des sauvegardes des pointages
tee /home/pi/.mame/hiscore.ini << 'EOF'
hi_path                   $HOME/.mame/hi
EOF

# Externalisation de dossiers additionnels au sein de ui.ini vers le profil :
sed -i 's/cabinets_directory.*$/cabinets_directory        $HOME\/.mame\/cabinets/g' /home/pi/.mame/ui.ini
sed -i 's/cpanels_directory.*$/cpanels_directory         $HOME\/.mame\/cpanels/g' /home/pi/.mame/ui.ini
sed -i 's/pcbs_directory.*$/pcbs_directory            $HOME\/.mame\/pcb/g' /home/pi/.mame/ui.ini
sed -i 's/flyers_directory.*$/flyers_directory          $HOME\/.mame\/flyers/g' /home/pi/.mame/ui.ini
sed -i 's/historypath.*$/historypath               $HOME\/.mame\/history/g' /home/pi/.mame/ui.ini
sed -i 's/titles_directory.*$/titles_directory          $HOME\/.mame\/titles/g' /home/pi/.mame/ui.ini
sed -i 's/marquees_directory.*$/marquees_directory        $HOME\/.mame\/marquees/g' /home/pi/.mame/ui.ini
sed -i 's/icons_directory.*$/icons_directory           $HOME\/.mame\/icons/g' /home/pi/.mame/ui.ini
sed -i 's/ui_path.*$/ui_path                   $HOME\/.mame\/ui/g' /home/pi/.mame/ui.ini

# Put MAME UI in Available ROMs mode
sed -i 's/last_used_filter.*$/last_used_filter          Available' /home/pi/.mame/ui.ini

# Test ROM to make sure everything is OK
# This ROM *will* be deleted and NOT included in the final image
wget $TestGamePrefixURL/${TestGame}.zip -P /home/pi/.mame/roms

# Build of Hypseus-Singe emulator (latest)...
/home/pi/scripts/hypseus-build.sh
