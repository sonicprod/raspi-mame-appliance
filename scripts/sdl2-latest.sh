#!/bin/bash

# This script build the latest SDL2 version without X11 dependency.

SDLVERSION=2.32.4
TTFVERSION=2.24.0
MIXERVERSION=2.8.1

if [ "$(command -v sdl2-config)" ] && [ "$(sdl2-config --version)" == "$SDLVERSION" ]; then
  echo "SDL2 is already at the latest version ($SDLVERSION)."
  exit
else
  if [ "${1,,}" != "nodep" ]; then
    echo Installing SDL2 dependencies...
    sudo apt-get install libfreetype6-dev libdrm-dev libgbm-dev libudev-dev libdbus-1-dev libasound2-dev liblzma-dev libjpeg-dev libtiff-dev libwebp-dev -y
    echo OpenGL ES 2 dependencies...
    sudo apt-get install libgles2-mesa-dev -y
  fi
  echo Build dependencies...
  sudo apt-get install build-essential -y
  cd ~
  echo Buiding SDL2 $SDLVERSION...
  # Based from "Compile SDL2 from source"
  # https://github.com/midwan/amiberry/wiki/Compile-SDL2-from-source
  wget https://libsdl.org/release/SDL2-${SDLVERSION}.zip
  unzip SDL2-${SDLVERSION}.zip
  rm SDL2-${SDLVERSION}.zip
  cd SDL2-${SDLVERSION}
  ./configure --disable-video-opengl --disable-video-opengles1 --disable-video-x11 --disable-pulseaudio --disable-esd --disable-video-wayland --disable-video-rpi --disable-video-vulkan --enable-video-kmsdrm --enable-video-opengles2 --enable-alsa --disable-joystick-virtual --enable-arm-neon --enable-arm-simd

  make -j $(nproc)
  sudo make install

  # SDL2_ttf
  wget https://libsdl.org/projects/SDL_ttf/release/SDL2_ttf-${TTFVERSION}.zip
  unzip SDL2_ttf-${TTFVERSION}.zip
  rm SDL2_ttf-${TTFVERSION}.zip
  cd SDL2_ttf-${TTFVERSION}
  ./configure
  make -j $(nproc)
  sudo make install
  sudo ldconfig -v

  # SDL2_mixer
  wget https://libsdl.org/projects/SDL_mixer/release/SDL2_mixer-${MIXERVERSION}.zip
  unzip SDL2_mixer-${MIXERVERSION}.zip
  rm SDL2_mixer-${MIXERVERSION}.zip
  cd SDL2_mixer-${MIXERVERSION}
  ./configure
  make -j $(nproc)
  sudo make install
  sudo ldconfig -v

  cd ~
  sudo rm -R SDL2-${SDLVERSION}
  sudo rm -R SDL2_ttf-${TTFVERSION}
  sudo rm -R SDL2_mixer-${MIXERVERSION}
  sudo apt-get remove build-essential -y
fi

sudo ldconfig

