#!/bin/bash

# This script test every ROMs with a 5 minutes benchmark and display the percentage of speed of the emulation.
# If the 'purge' argument is specified, the script will delete the ROM files that are under 100% of average speed.

shopt -s nullglob

if (systemctl -q is-active mame-autostart.service) then
    echo "The system must be put in SERVICE Mode first."
    exit
fi

cd ~/.mame/roms
for r in *.zip
  do
    FULLNAME=$(/home/pi/mame/mame -listfull ${r%.zip} | awk "/${r%.zip}/ { print $2 }")
    if [ ! -z $FULLNAME ]; then
        echo -n Benchmarking $FULLNAME for 5 minutes...
        RESULT=$(/home/pi/mame/mame -bench 300 ${r%.zip} 2>/dev/null)
        if [ ! -z $RESULT ]; then
            PERCENT=$(echo $RESULT | awk '/Average speed:/ { print $3 }')
            PERCENT=${PERCENT//%/}         # Remove the percentage
            echo " Average speed of $PERCENT %"
            if [ ${PERCENT%.*} -lt 100 ] && [ ${1,,} = 'purge' ]; then
                rm ~/.mame/roms/$r
                echo "  The ROM file $r has been purged."
            fi
        fi
    fi
  done

echo Completed!
