#!/bin/bash

# This script launch the selected application (front-end or MAME emulator) and respawn it if quit unexpectedly.

if [ ! -z $FRONTEND ]; then
  while
    case ${FRONTEND,,} in
      attract)  # Attract Mode
        if [ ! -z "$AUTOROM" ] && [ $(wc -w <<< "$AUTOROM") == 2 ]; then
          read -r EMULNAME ROMNAME <<< "${AUTOROM//\"/}"
          CFGFILE=/home/pi/.attract/emulators/$EMULNAME.cfg
          if [ -f $CFGFILE ]; then
            while read VAR VALUE; do
              [ ! -z $VAR ] && [ "${VAR:0:1}" != '#' ] && export $VAR="$VALUE"
            done < $CFGFILE
            ARGS=${args//\[name\]/$ROMNAME}
            ARGS=${ARGS//\$HOME/$HOME}
            EXEC=${executable//\$HOME/$HOME}
            if [ "${EXEC##*/}" = hypseus ]; then	# Hypseus-Singe
              FRAMEFILE=$(sed 's/^.*\s-framefile\s\(\S*\)\s.*$/\1/' <<< $ARGS)
            fi
          fi
          if [ ! -z $FRAMEFILE ] && [ -f $FRAMEFILE ] && [ ! -z $EXEC ] && [ -x $EXEC ]; then	# Automatic ROM Launch mode
            $EXEC $ARGS -nolog >/dev/null 2>/dev/null
          else
            stty -echo
            /usr/local/bin/attract --loglevel silent >/dev/null 2>&1
          fi
        else
          stty -echo
          /usr/local/bin/attract --loglevel silent >/dev/null 2>&1
        fi
        ;;
      advance)  # AdvanceMENU
        /home/pi/frontend/advance/advmenu
        ;;
      mame)     # MAME GUI or Automatic ROM Launch mode if AUTOROM is set
        /home/pi/mame/mame $([ ! -z $AUTOROM ] && [ -f /home/pi/.mame/roms/$AUTOROM.zip ] && echo $AUTOROM) >/dev/null 2>/dev/null
        ;;
    esac
    (( $? != 0 ))
  do
    :
  done
else
    echo $0 - FRONTEND variable is not defined!
    read -n1 -srp "Press any key to continue..."
    echo
fi
