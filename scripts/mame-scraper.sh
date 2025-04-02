#!/bin/bash

# This script download the missing artwork files (snapshots, titles screens, marquees,
# control panels and cabinet pictures) based on the content of the ROMs path (ROM files).

# Usage: when a romname is passed (without the .zip extension), only the artwork for this
#        rom is downloaded.

URLPREFIX1=http://mamedb.blu-ferret.co.uk
URLPREFIX2=http://adb.arcadeitalia.net/media/mame.current

get_artworks() {
    # $1 is romname (without .zip)
    if [ ! $1 ]; then
        exit
    fi
    if [ -t 0 ]; then  echo -ne "\e[2K\rProcessing $1..."; fi
    for t in snap titles marquees cpanels cabinets flyers
      do
        if [ ! -f /home/pi/.mame/$t/$1.png ]; then
          wget -q $URLPREFIX1/$t/$1.png -P /home/pi/.mame/$t
          if [ $? = 0 ]; then	# Download OK
              echo -n .
          else		# Download failed, let's try with the 2nd URL...
              case $t in
                  snap)
                      wget -q $URLPREFIX2/ingames/$1.png -P /home/pi/.mame/$t && echo -n .
                      ;;
                  *)
                      wget -q $URLPREFIX2/$t/$1.png -P /home/pi/.mame/$t && echo -n .
                      ;;
              esac
          fi
        fi
      done
    }

shopt -s nullglob
cd /home/pi/.mame/roms

if [ $1 ]; then
    f=$1.zip
    if [ -f $f ]; then
        get_artworks ${f%.zip}
    fi
else
    for f in *.zip
        do
            get_artworks ${f%.zip}
        done
fi
if [ -t 0 ]; then echo -e '\e[2K\rCompleted!'; fi
