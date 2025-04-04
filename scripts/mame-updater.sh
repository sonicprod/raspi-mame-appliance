#!/bin/bash

# This script update MAME to the latest version or a specific version.

MAKEOPTS='TARGETOS=linux NO_X11=1 NOWERROR=1 NO_USE_XINPUT=1 NO_USE_XINPUT_WII_LIGHTGUN_HACK=1 NO_OPENGL=1 USE_QTDEBUG=0 DEBUG=0 REGENIE=1 NO_BGFX=1 FORCE_DRC_C_BACKEND=1 NO_USE_PORTAUDIO=1 SYMBOLS=0'
MAXTHREAD=4    # From MAME version 0.227 and up, we should use a max. of 3 threads to avoid an out of memory error.

secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
    }

fs_unlock() {   # Put root filesystem in read/write mode
    for o in $(findmnt -n -o OPTIONS / | sed 's/,/ /g'); do
        [ "${o,,}" = ro ] && sudo mount -o remount,rw /
    done
    }

fs_lock() {     # Put root filesystem in read-only mode
    for o in $(findmnt -n -o OPTIONS / | sed 's/,/ /g'); do
        [ "${o,,}" = rw ] && sudo mount -o remount,ro /
    done
    }

set_env() {     # Make an environment variable persistent
    local KEY=$(echo $1 | awk -F '=' '{print $1}')
    local VALUE=$(echo $1 | awk -F '=' '{print $2}')
    grep -q $KEY= /etc/environment && sudo sed -i "s/$KEY=.*$/$KEY=$VALUE/g" /etc/environment || echo "$KEY=$VALUE" | sudo tee -a /etc/environment
    }

get_history() {      # Grab the latest history.dat file
    local BASEURL=https://www.arcade-history.com
    local BASETAG='<a class="noir" rel="nofollow" href="../dats/'
    local REGEX='[^*]*(a class="noir" rel="nofollow" href="../dats/)(.*?)("><img src="images/design/download3.gif" height="40px" />)[^*]*'

    HISTORYFILE=$(wget -q -O - $BASEURL/index.php?page=download | grep "$BASETAG" | sed -r "s%$REGEX%\2%")
    wget -q $BASEURL/dats/$HISTORYFILE -P ~    # Download the file
    unzip -o ~/$HISTORYFILE history.dat -d ~/.mame
    if [ -L ~/.mame/history ]; then                # Symlink is present
        mv ~/.mame/history.dat ~/.mame/history
    fi
    rm ~/$HISTORYFILE                          # Cleanup
    }

mame-latest() {         # Get the latest version of MAME
  CHECKURL=https://github.com/mamedev/mame/releases/latest
  HTMLTAG='<title>Release MAME'

  LATESTMAMEVER=$(wget -q -O - $CHECKURL | grep "$HTMLTAG" | awk '{print $3}')

  if [ -z $LATESTMAMEVER ]; then echo ERROR; exit; fi  # We make sure wget was successful

  echo $LATESTMAMEVER
  }

if (systemctl -q is-active mame-autostart.service) then
    echo "The system must be put in SERVICE Mode first."
    exit
fi

if [ ! $1 ]; then
    echo Usage: $0 VER | Latest
    echo '  Where VER is the 4-digit version number of MAME to update (for example: 0224).'
    echo '  OR use the argument Latest to update to the latest available MAME version.'
else
    if [ $(free -g | awk '/^Mem:/{print $2}') -lt 3 ]; then
        echo You need 4 GB of RAM to compile MAME with multithread support.
        exit
    fi

    if [ "${1,,}" == "latest" ]; then
      MAMEVER=$(mame-latest)
      MAMEVER=${MAMEVER//./}    # Remove the dot
    else
      MAMEVER=$1
    fi
    MAMESRCPATH=/home/pi/mame${MAMEVER}
    SCRIPTPATH=${0%/*}

    echo Installing/uptading to MAME $MAMEVER...
    fs_unlock

    # Install MAME dependencies...
    sudo apt-get install fontconfig libfontconfig-dev libx11-dev libpulse-dev -y

    if [ ! -d $MAMESRCPATH ]; then
        cd ~
        if [ ! -f ~/mame${MAMEVER}.zip ]; then    # Not already downloaded
            wget https://github.com/mamedev/mame/archive/mame${MAMEVER}.zip
        fi

        if [ -f ~/mame${MAMEVER}.zip ]; then      # If download successful, uncompress ...
            unzip mame${MAMEVER}.zip
            mv mame-mame${MAMEVER} mame${MAMEVER}
            rm mame${MAMEVER}.zip
        fi
    fi

    if [ ! -x $MAMESRCPATH/mame ]; then         # We build only if not already built
        # Build of MAME

        # Dependencies
        # Swap requirement
        sudo apt-get install dphys-swapfile -y
        if [ "$(grep '^CONF_SWAPSIZE' /etc/dphys-swapfile | cut -d= -f2)" != "2048" ]; then
            sudo sed -i "s/^#\{0,1\}\s*CONF_SWAPSIZE=.*$/CONF_SWAPSIZE=2048/g" /etc/dphys-swapfile
        fi
        # The swap value should be 2048

        # Activate the swap...
        sudo systemctl stop dphys-swapfile.service
        sudo systemctl start dphys-swapfile.service
        # Build dependencies
        sudo apt-get install build-essential -y

        cd $MAMESRCPATH
        echo MAKE CMDLINE=make -j$MAXTHREAD $MAKEOPTS PLATFORM=arm64 PTR64=1
        BUILDSTART=$(date +%s)
        echo Build start time: $(date +"%T")
        echo -----------------------------------------------------------------------------------
        echo Please wait until the build is completed \(about 10 hours\)...
        echo -----------------------------------------------------------------------------------

        # Small speedup for Pi 4 (we use the binary built from a Pi 5, which is 4 times faster)
        if [ -x /home/pi/scripts/mame ]; then
          FOUNDMAMEVER=$(/home/pi/scripts/mame -version | cut -d' ' -f1)
          if [ $FOUNDMAMEVER == $MAMEVER ]; then    # Version of binary found match our build version
            mv /home/pi/scripts/mame $MAMESRCPATH
          fi
        fi
        
        [ ! -x $MAMESRCPATH/mame ] && make -j $MAXTHREAD $MAKEOPTS PLATFORM=arm64 PTR64=1

        echo Build time took: $(secs_to_human "$(($(date +%s) - ${BUILDSTART}))").

        if [ -x $MAMESRCPATH/mame ]; then
            echo -----------------------------------------------------------------------------------
            echo Build Success!
            echo -----------------------------------------------------------------------------------
            # Successful build!
            # We make sure the MAME environment variable is persistent...
            set_env SDL_VIDEODRIVER=kmsdrm
            set_env SDL_RENDER_DRIVER=opengles2
            set_env SDL_RENDER_VSYNC=1
            set_env SDL_GRAB_KEYBOARD=1
            set_env SDL_VIDEO_GLES2=1

            # Install MAME True-Type Liberation Sans font
            sudo apt-get install fonts-liberation

            # MAME binary symlink creation or update
            if [ -L ~/mame ]; then rm ~/mame; fi
            ln -s $MAMESRCPATH ~/mame

            if [ ! -L ~/.mame ] && [ ! -d ~/.mame ]; then   # MAME data path symlink creation
                [ -d /data/mame ] && ln -s /data/mame ~/.mame || mkdir ~/.mame
            fi

            if [ ! -f ~/.mame/mame.ini ]; then  # If mame.ini does not exist, let's create it
                cd ~/.mame
                $MAMESRCPATH/mame \
                  -hashpath '$HOME/mame/hash' \
                  -languagepath '$HOME/mame/language' \
                  -pluginspath '$HOME/mame/plugins' \
                  -artpath '$HOME/.mame/artwork' \
                  -ctrlrpath '$HOME/.mame/ctrlr' \
                  -inipath '$HOME/.mame/ini' \
                  -homepath '$HOME/.mame/lua' \
                  -rompath '$HOME/.mame/roms' \
                  -cfg_directory '$HOME/.mame/cfg' \
                  -diff_directory '$HOME/.mame/diff' \
                  -input_directory '$HOME/.mame/inp' \
                  -nvram_directory '$HOME/.mame/nvram' \
                  -snapshot_directory '$HOME/.mame/snap' \
                  -state_directory '$HOME/.mame/sta' \
                  -skip_gameinfo \
                  -video accel \
                  -videodriver kmsdrm \
                  -renderdriver opengles2 \
                  -audiodriver alsa \
                  -samplerate 22050 \
                  -createconfig
            fi

            if [ -z $FRONTEND ]; then
              if [ ! -f /home/pi/settings ]; then
                echo FRONTEND=mame>/home/pi/settings
              else
                grep -q FRONTEND= /home/pi/settings && sed -i "s/^FRONTEND=.*$/FRONTEND="${1,,}"/g" $(readlink /home/pi/settings) || (echo AUTOROM="${2,,}" | tee -a /home/pi/settings; echo | tee -a /home/pi/settings)
              fi
            fi

            if [ ! -L /home/pi/settings ] && [[ $(findmnt -n /data) ]]; then    # Symlink not found and /data is mounted...
              [ ! -f /data/.sys/env/settings ] && mkdir -p /data/.sys/env
              if [ ! -f /home/pi/settings ]; then
                touch /data/.sys/env/settings
                echo 'FRONTEND=mame'>/home/pi/settings
              else      # File settings already exist
                mv /home/pi/settings /data/.sys/env
              fi
              ln -s /data/.sys/env/settings /home/pi/settings
            fi

            # Get the latest history.dat file
            echo Applying latest history.dat...
            # get_history   # Broken, to be fixed

            # Freeing some space...
            for f in src build 3rdparty roms
            do
                rm -Rf $MAMESRCPATH/$f
            done

            # Removing dependencies
            echo Removing dependencies...
            # Removing swap...
            sudo systemctl stop dphys-swapfile.service
            sudo rm /var/swap
            sudo apt-get remove dphys-swapfile build-essential -y
            sudo apt-get autoremove -y
        else
            echo -----------------------------------------------------------------------------------
            echo Build FAILED.
            echo -----------------------------------------------------------------------------------
        fi
    fi
    fs_lock
fi
