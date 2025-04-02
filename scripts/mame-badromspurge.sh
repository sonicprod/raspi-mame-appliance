#!/bin/bash

# This script delete/purge bad or invalid ROMs files.

shopt -s nullglob

for r in $(/home/pi/mame/mame -verifyroms | grep 'is bad' | awk '{print $2 ".zip"}')
  do
    if [ -f /home/pi/.mame/roms/$r ]; then
      sudo rm /home/pi/.mame/roms/$r
      echo -n .
    fi
  done
echo Completed!
