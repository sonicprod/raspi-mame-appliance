#!/bin/bash

# This script list the name of the current MAME ROMs.

cd /home/pi/.mame/roms

for f in *.zip; do
  echo -e "[${f%.*}]\t$(/home/pi/mame/mame -listfull ${f%.*} | awk -F '"' '!/Description:$/ {print $2}')"
done
