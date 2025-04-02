#!/bin/bash

# This script delete unused Artwork files if the corresponding ROM .zip file does not exist.

shopt -s nullglob

if [ $1 ]; then
  if [ ! -f /home/pi/.mame/roms/$1.zip ]; then
    for t in snap titles marquees cpanels cabinets icons
      do
          if [ -f /home/pi/.mame/$t/$1.png ]; then
            sudo rm /home/pi/.mame/$t/$1.png
          fi
      done
  fi
else	# Batch mode
  if [ -t 0 ]; then echo -ne "\e[2K\rProcessing $1..."; fi
  for t in snap titles marquees cpanels cabinets icons
    do
      cd /home/pi/.mame/$t
      for f in *.{png,ico}
        do
          if [ ! -f /home/pi/.mame/roms/${f%.*}.zip ]; then
            sudo rm /home/pi/.mame/$t/$f
            echo -n .
          fi
        done
    done
  if [ -t 0 ]; then echo -e '\e[2K\rCompleted!'; fi
fi
