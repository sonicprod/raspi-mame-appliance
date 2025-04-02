#!/bin/bash

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

# This function check the latest available version of MAME and display a notice if the current version is older.
function mame-check {
  CHECKURL=https://github.com/mamedev/mame/releases/latest
  HTMLTAG='<title>Release MAME'

  [ -x /home/pi/mame/mame ] && export MAMEVER=$(/home/pi/mame/mame -version | cut -d' ' -f1)
  if [ ! -z $MAMEVER ]; then
    LATESTMAMEVER=$(wget -q -O - $CHECKURL | grep "$HTMLTAG" | awk '{print $3}')

    if [ -z $LATESTMAMEVER ]; then echo $MAMEVER ERROR; exit; fi  # We make sure wget was successful

    if [ $(version $LATESTMAMEVER) -gt $(version $MAMEVER) ]; then
      echo $MAMEVER $LATESTMAMEVER
    else
      echo $MAMEVER Latest
    fi
  fi
  }

# This script check the latest available version of Hypseus-Singe and display a notice if the current version is older.
function hypseus-check {
  CHECKURL=https://github.com/DirtBagXon/hypseus-singe/releases/latest
  HTMLTAG='<title>Release hypseus-singe'
  HYPSEUSPATH=/home/pi/hypseus

  [ -x $HYPSEUSPATH/hypseus ] && export HYPSEUSVER=$($HYPSEUSPATH/hypseus -v | awk '/^\[version\]/{print $4}')
  if [ ! -z $HYPSEUSVER ]; then
    LATESTHYPSEUSVER=$(wget -q -O - $CHECKURL | grep "$HTMLTAG" | awk '{print $3}')

    if [ -z $LATESTHYPSEUSVER ]; then echo $HYPSEUSVER ERROR; exit; fi  # We make sure wget was successful

    LATESTHYPSEUSVER=${LATESTHYPSEUSVER##v}             # Strip the leading v
    HYPSEUSVER=$(echo $HYPSEUSVER | sed 's/^v*//; s/-RPi$//')    # Strip the leading v and trailing -RPi

    if [ $(version $LATESTHYPSEUSVER) -gt $(version $HYPSEUSVER) ]; then
      echo $HYPSEUSVER $LATESTHYPSEUSVER
    else
      echo $HYPSEUSVER Latest
    fi
  fi
  }

if [ -x $HOME/mame/mame ] || [ -x $HOME/hypseus/hypseus ]; then
  echo '+---------------+-----------+-----------+'
  echo '| EMULATOR      | CURRENT   | LATEST    |'
  echo '+---------------+-----------+-----------+'
  [ -x $HOME/mame/mame ]       && echo -n '| MAME          | '; mame-check    | awk '{ printf "%-9s | %-9s |\n", $1, $2}'
  [ -x $HOME/hypseus/hypseus ] && echo -n '| Hypseus-Singe | '; hypseus-check | awk '{ printf "%-9s | %-9s |\n", $1, $2}'
  echo '+---------------+-----------+-----------+'
fi
