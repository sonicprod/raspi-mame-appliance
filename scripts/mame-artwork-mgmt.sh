#!/bin/bash

# This script watch the ROMs folder and add/remove the corresponding artwork automatically.

inotifywait -m /home/pi/.mame/roms -e create -e moved_to -e delete -e moved_from |
  while read dir action file; do
    case ${action,,} in
      create | moved_to)
        if [ ${file##*.} = zip ]; then /home/pi/scripts/mame-scraper.sh ${file%.zip}; fi
        ;;
      delete | moved_from)
        if [ ${file##*.} = zip ]; then /home/pi/scripts/mame-delartwork.sh ${file%.zip}; fi
        ;;
    esac
  done
