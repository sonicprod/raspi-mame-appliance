=====================================
   RASPBERRY PI 4B MAME APPLIANCE

QUICK DESCRIPTION OF INCLUDED SCRIPTS
=====================================

------------------------
expand-data-partition.sh
------------------------
This script will expand /dev/mmcblk0p3 partition (data) to all the available space on the storage device. The system must be put in SERVICE Mode prior to run this script.

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


mame-launcher.sh
----------------
This script launch the MAME emulator and respawn it if quit unexpectedly.

This script is called by the Systemd service named mame-autostart.service (while in Arcade Mode).

While in Service Mode, you can execute this script to test MAME. Every argument specified on the command-line will be passed to the MAME executable (for example: -v for verbose mode).


mame-scraper.sh
---------------
This script download the missing artwork files (snapshots, titles screens, marquees,

Syntax: ./mame-scraper [ROMNAME]

  Where ROMNAME is the specific ROM name for wich the artwork files are needed.

Batch mode: If there is no ROM name specified, the script scan all the ROMs files and automatically download the corresponding artwork files.


mame-updater.sh
---------------
This script update MAME to the specified version.

Syntax: ./mame-updater.sh VER

  Where VER is the 4-digit version number of MAME to update (for example: 0228).


--------------------
mame-versioncheck.sh
--------------------
This script check the latest available version of MAME and display a notice if the current version is older.

This script is automatically called at every interactive login (console or SSH).
