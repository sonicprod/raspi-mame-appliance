===================================================
          RASPBERRY PI 4/5 MAME APPLIANCE
===================================================

This image is maintained by:   Sonic Prod
Updated: 2025-09-15
Official How-To: https://gist.github.com/sonicprod/f5a7bb10fb9ed1cc5124766831e120c4
Pre-built image: http://forum.arcadecontrols.com/index.php/board,57.0.html


Features and functionalities:
-----------------------------
- Based on Raspberry Pi OS Lite (minimal Linux edition based on Debian);
- At startup, display of a custom splash screen (for example, the MAME logo in color);
- The MAME emulator starts automatically and displays the ROM selection screen;
- When you exit MAME, the system initiates a shutdown;
- During the shutdown, display of a personalized splash screen (for example, the MAME logo in b/w);
- When the stop operations are completed, the system powers off;
- To preserve the life of the SD card, the root filesystem is kept in read-only mode;
- ROMs Hiscores are persistent;
- A maintenance mode is proposed (called the Service Mode) to allow system updates and the management of ROMs and Snapshots (via a Samba file share).
- While in Service Mode:
  - As soon as you add new ROM files, the snapshots/titles (and others, if available) images will be scraped/downloaded automatically.
  - As soon as you remove/delete ROM files, the associated graphic files will be deleted.


======================================
         GETTING STARTED
======================================

DATA PARTITION
--------------------------------------

Before adding any ROMs, you need to expand the data partition (/data) to all the available free space on the SD card.

You need to excute the expand-data-partition.sh script with this command:

  ./expand-data-partition.sh

Once the expand operation is completed, you can start adding ROMs to the /data/roms folder (see below).


READ/WRITE MODE
--------------------------------------

To make any system change (configuration with raspi-config, update, etc.), you need to put the system in read/write mode. By default, to preserve the lifespan of the SD card, the system is kept in read-only mode. Every time you logout from an interactive shell session or if you reboot, the system is put back in read-only mode.

To switch the system to read/write mode:

  rw

The prompt suffix will change from (ro) to (rw). You can then make any persistent change to the root filesystem of Linux. If you logout or reboot, the system will automatically be back in read-only mode.

To manually switch the system back to read-only mode:

  ro

The prompt suffix will change from (rw) to (ro).


SYSTEM UPDATE
--------------------------------------

To update the packages on the system, just issue the following command (in read/write mode):

  update


SERVICE MODE, ARCADE MODE
--------------------------------------

The system operates in two (2) modes:
  - One mode is for ROMs management, system updates, maintenance, etc., refered to as Service mode.
  - The other mode is dedicated to arcade emulation, refered to as Arcade mode.

To toggle between modes, just use one of the corresponding commands:

  mode service
     -or-
  mode arcade

To take effect, you then need to reboot by issuing the following command:

  sudo reboot


OFFLINE TOGGLE TO SERVICE MODE
--------------------------------------

If, for any reason you need to toggle the system to Service mode, but are unable to do it online (while the Raspberry Pi is booted), you have two (2) ways:

Method #1:
 1. Shutdown/quit MAME to initiate a clean shutdown
 2. Remove the SD card from the Raspberry Pi
 3. Put the SD card in a card reader from a Linux host system (or Mac OS X)
 4. Remove/delete these 2 files from the partition named "rootfs" on the SD card:
      etc/systemd/system/multi-user.target.wants/mame-autostart.service
      etc/systemd/system/multi-user.target.wants/shutdown.service

 5. Unmount the SD card and put it back in your Raspberry Pi and apply power to it
 6. The system will boot in Service mode

Method #2:
 1. Shutdown/quit MAME to initiate a clean shutdown
 2. Remove the SD card from the Raspberry Pi
 3. Put the SD card in a card reader from a Linux host system (or Mac OS X)
 4. From the "boot" partition, put an empty file called "service"
 5. Unmount the SD card and put it back in your Raspberry Pi and apply power to it
 6. The system will boot in Service mode (note: it could take up to 2 reboots to take effect)


FRONTEND SELECTION
--------------------------------------

To select a frontend other than the MAME GUI, use the « frontend » command as below:

# To use Attract Mode:
frontend attract

# To use AdvanceMENU:
frontend advance

# To use the MAME GUI (default):
frontend mame

You have to reboot (sudo reboot) for the selection to take effect.


SINGLE ROM AUTO-LAUNCH MODE
--------------------------------------

To automatically launch a single ROM at boot (useful for dedicated cabinets, for example), use the following syntax with the « frontend » command:

  frontend mame ROMNAME

Where ROMNAME is the name (without any extension) of the ROM you want MAME to automatically launch.

# Examples:
frontend mame gunsmoke
frontend mame batsugun
frontend mame pacman


ROMS MANAGEMENT
--------------------------------------

To add (or remove) ROMs on the system, you should first be in Service mode. Then, simply access the Samba share on the Raspberry Pi.

For Windows systems, use: \\arcade\data
For Linux systems,   use: smb://arcade/data

Open the "roms" folder under the "mame" folder, then add or remove the ROMs of your choice.

As soon as you add a new ROM, the system will automatically download the corresponding artwork files (if Internet connectivity is available).
As soon as you remove/delete an existing ROM from the roms folder, the system will automatically delete the corresponding artwork files to make free space.


Enjoy!  :-)


=========================================
  QUICK DESCRIPTION OF INCLUDED SCRIPTS
=========================================

------------------------
expand-data-partition.sh
------------------------
This script will expand /dev/mmcblk0p3 partition (data) to all the available space on the storage device. The system must be put in SERVICE Mode prior to run this script.

If you are using the pre-built image, then you must run this script (while in Service Mode) before adding ROM files.

--------------------
mame-artwork-mgmt.sh
--------------------
This script watch the ROMs folder and add/remove the corresponding artwork automatically.

NOTE: This script is part of a Systemd service and is not intended to be executed in interactive mode.

--------------------
mame-badromspurge.sh
--------------------
This script check every ROMs files against known-good hash. If the ROM is bad or invalid, it is deleted. The decision is based on the output of -verifyroms MAME argument.

Syntax: ./mame-badromspurge.sh 

Just run the utility, it has no command-line arguments.

------------------
mame-delartwork.sh
------------------
This script delete unused Artwork files if the corresponding ROM .zip file does not exist.

Syntax: ./mame-delartwork.sh [ROMNAME]

  Where ROMNAME is the name of the corresponding zip file (without the extension).

Batch mode: If there is no ROM name specified, the script scan all the ROMs files and automatically delete the unused/unneeded artwork files.

----------------
mame-launcher.sh
----------------
This script launch the MAME emulator and respawn it if quit unexpectedly.

This script is called by the Systemd service named mame-autostart.service (while in Arcade Mode).

While in Service Mode, you can execute this script to test MAME. Every argument specified on the command-line will be passed to the MAME executable (for example: -v for verbose mode).

---------------
mame-scraper.sh
---------------
This script download the missing artwork files (snapshots, titles screens, marquees,

Syntax: ./mame-scraper [ROMNAME]

  Where ROMNAME is the specific ROM name for wich the artwork files are needed.

Batch mode: If there is no ROM name specified, the script scan all the ROMs files and automatically download the corresponding artwork files.

---------------
mame-updater.sh
---------------
This script update MAME to the specified version.

Syntax: ./mame-updater.sh VER | Latest

  Where VER is the 4-digit version number of MAME to update (for example: 0228).
  OR use the argument Latest to update to the latest available MAME version.


--------------------
versions-check.sh
--------------------
This script check the latest available version of MAME and display a notice if the current version is older.

This script is automatically called at every interactive login (console or SSH).


=================
  KNOWN ISSUES
=================

- The Configure Options / Video Options sub-menu from the main selection screen (GUI) is throwing a Segmentation fault. This is caused by the fact that we patched the source code with a dirty fix just to be able to successfully build. A MAME developper has to find a proper fix. A bug has been filed on mametesters.org (ID=07738).
