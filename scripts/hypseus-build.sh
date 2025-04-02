#!/bin/bash

# This script build and install the latest version of the laserdisc emulator Hypseus-Singe.

function hypseus-latest {
  CHECKURL=https://github.com/DirtBagXon/hypseus-singe/releases/latest
  HTMLTAG='<title>Release hypseus-singe'

  LATESTHYPSEUSVER=$(wget -q -O - $CHECKURL | grep "$HTMLTAG" | awk '{print $3}')

  if [ -z $LATESTHYPSEUSVER ]; then echo ERROR; exit; fi    # We make sure wget was successful

  LATESTHYPSEUSVER=${LATESTHYPSEUSVER##v}             # Strip the leading v
  echo $LATESTHYPSEUSVER
  }

if [ "${1,,}" != "nodep" ]; then
  echo Installing dependencies...
  # Hypseus-Singe dependencies...
  # SDL2_image
  cd ~
  wget https://libsdl.org/projects/SDL_image/release/SDL2_image-2.0.5.zip
  unzip -q SDL2_image-2.0.5.zip
  cd SDL2_image-2.0.5
  ./configure
  make -j $(nproc)
  sudo make install
  sudo ldconfig -v
  cd ../
  rm SDL2_image-2.0.5.zip
  rm -R SDL2_image-2.0.5

  sudo apt-get install libmpeg2-4-dev libvorbis-dev libogg-dev zlib1g-dev libzip-dev -y
fi

VERSION=$(hypseus-latest)
if [ ! -d ~/hypseus-singe-${VERSION}-RPi ]; then
  echo Downloading Hypseus-Singe $VERSION...
  cd ~
  wget https://github.com/DirtBagXon/hypseus-singe/archive/refs/tags/v${VERSION}-RPi.zip
  unzip -q v${VERSION}-RPi.zip
fi

if [ ! -x ~/hypseus-singe-${VERSION}-RPi/hypseus ]; then
  # Dependency to build
  sudo apt-get install cmake build-essential -y

  echo Building Hypseus-Singe $VERSION...
  cd ~/hypseus-singe-${VERSION}-RPi/
  mkdir build
  cd build
  cmake ../src
  make -j4
fi

if [ -x ./hypseus ]; then
  echo Hypseus-Singe $VERSION build succeeded.
  [ ! -d ~/hypseus ] && mkdir ~/hypseus
  cd ~/hypseus-singe-${VERSION}-RPi/build
  mv hypseus ~/hypseus
  [ ! -d /data/hypseus/framefile ] && mkdir /data/hypseus/framefile
  [ ! -d /data/hypseus/ram ] && mkdir /data/hypseus/ram
  cd ../
  [ ! -d ~/hypseus/sound ] && mv doc fonts pics scripts sound ~/hypseus
  [ ! -d ~/hypseus/roms ] && mv mv roms/ screenshots/ ~/.hypseus
  cd ~/hypseus
  [ ! -L ~/hypseus/ram ] && ln -s /data/hypseus/ram ram
  [ ! -L ~/hypseus/singe ] && ln -s /data/hypseus/framefile singe
  [ ! -L ~/hypseus/roms ]  && ln -s /data/hypseus/roms roms
  cd
  [ -d ~/hypseus-singe-${VERSION}-RPi ] && rm -R ~/hypseus-singe-${VERSION}-RPi
  [ -f ~/v${VERSION}-RPi.zip ] && rm ~/v${VERSION}-RPi.zip
  sudo apt-get remove cmake -y
  # Cleanup
  sudo rm -R build sfml-pi-R3
else
  echo Hypseus-Singe $VERSION build failed.
fi
