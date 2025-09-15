#/bin/bash

# Updated: 2025-08-12
# Author: Benoit Bégin
# 
# This script configure base system-wide OS settings
#
# This script:
#   - Update the system's packages
#   - Add new aliases to /home/pi/.bash_aliases

# sudo dpkg-reconfigure keyboard-configuration
# sudo dpkg-reconfigure locales

# Timezone setup
sudo timedatectl set-timezone $TIMEZONE

# NTP server setup
sudo timedatectl set-ntp true
sudo sed -i "s/^#\{0,1\}NTP=.*$/NTP=$NTP/g" /etc/systemd/timesyncd.conf
sudo systemctl restart systemd-timesyncd.service

# Initial packages update...
sudo apt-get update && sudo apt-get upgrade -y
# Cleanup
sudo apt-get clean -y
sudo apt-get autoclean -y

# Hostname setup
sudo hostnamectl set-hostname $HOSTNAME
sudo sed -i '/^127\.0\.1\.1\s/s/raspberrypi$/ '"$HOSTNAME"'/' /etc/hosts
sudo service NetworkManager restart

# Add some new aliases for the system...
grep -a "alias frontend=" /home/pi/.bash_aliases || tee -a /home/pi/.bash_aliases << 'EOF'
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias cputemp='/usr/bin/vcgencmd measure_temp'
alias cpufreq="echo Clock Speed=$(($(/usr/bin/vcgencmd measure_clock arm | awk -F '=' '{print $2}')/1000000)) MHz"
alias frontend='upd(){ grep -q $1= ~/settings && sed -i "s/^$1=.*$/$2/g" $(readlink -f ~/settings) || echo $2 | tee -a ~/settings;}; _frontend(){ if [[ "${1,,}" =~ ^(mame|attract|advance)$ ]]; then [ ! -f ~/settings ] && touch ~/settings; upd FRONTEND FRONTEND="${1,,}" && echo "Frontend set to: "${1,,}" (reboot to apply)."; case "${1,,}" in mame) [ -z "$2" ] && upd AUTOROM AUTOROM= || (upd AUTOROM AUTOROM="${2,,}"; echo "Automatic ROM Launch set to: "${2,,}".") ;; attract) EMUL=~/.attract/emulators/"$2".cfg; if ([ ! -z "$2" ] && [ ! -z "$3" ] && [ -f $EMUL ]); then (upd AUTOROM "AUTOROM=\""$2" "${3,,}"\""; echo "Automatic ROM Launch set to: "${3,,}" (emulator "$2")."); else [ ! -z "$2" ] && echo "Invalid emulator or missing rom."; upd AUTOROM AUTOROM=; fi; ;; esac; else echo "Invalid or missing argument. Try: mame [rom], attract [emulator rom] or advance"; fi;}; _frontend'

# Alias to switch between Arcade Mode and Service Mode (and print the current mode, if no argument is specified)
alias mode='_m() { [ -z "$1" ] && (echo -n "The system is currently in "; systemctl -q is-active mame-autostart.service && echo -n ARCADE || echo -n SERVICE; echo " mode.") || if [[ "${1,,}" =~ ^(arcade|service)$ ]]; then case "${1,,}" in arcade) [ "$(type -t rw)" = 'alias' ] && rw; sudo systemctl enable mame-autostart.service; [ "$(type -t ro)" = 'alias' ] && ro ;; service) [ "$(type -t rw)" = 'alias' ] && rw; sudo systemctl disable mame-autostart.service; [ "$(type -t ro)" = 'alias' ] && ro ;; esac; else echo "Usage: mode [arcade | service]"; fi; }; _m'
EOF

# We copy the README.txt file to /home/pi
cp /home/pi/raspi-mame-appliance/_staging/home/pi/README.txt /home/pi

# Supprimer l’avertissement (disclaimer) ci-dessous au login
sudo rm -f /etc/motd

cd /home/pi/raspi-mame-appliance/scripts
mkdir -p /home/pi/scripts
cp *.sh /home/pi/scripts
chmod +x /home/pi/scripts/*.sh

# Notices display at login
grep -a "The system is currently in" /etc/bash.bashrc || sudo tee -a /etc/bash.bashrc << 'EOF'

echo '----------------------------------------------------------------------'
# Load environment settings...
if [ -f /home/pi/settings ]; then
  while IFS="= " read var value; do
    [ ! -z $var ] && [ "${var:0:1}" != "#" ] && export $var="$value"
  done < /home/pi/settings
fi
MAMEROM=$(ps h -C mame -o cmd | awk '{print $2}'); [ "${MAMEROM:0:1}" == "-" ] && MAMEROM=
echo "Current Frontend: $(case $FRONTEND in \
  attract) echo "Attract Mode$([ -x /usr/local/bin/attract ] && attract -v | awk '/Attract-Mode/ {print " " $2}')" ;; \
  advance) echo AdvanceMENU ;; \
  mame) ([ ! -z $MAMEROM ] && [ "$MAMEROM" == "$AUTOROM" ]) && echo 'None/AutoROM Mode' || echo 'MAME GUI' ;; \
  *) echo 'NOT SET' ;; esac)."
[ ! -z $MAMEROM ] && echo Currently emulated ROM: \
  $(/home/pi/mame/mame -listfull $MAMEROM | awk -F '"' '!/Description:$/ {print $2}').

[ -x $HOME/scripts/versions-check.sh ] && . $HOME/scripts/versions-check.sh

echo "The system is currently in $(systemctl -q is-active mame-autostart.service && echo ARCADE || echo SERVICE) mode."

EOF

sudo rm -f /etc/issue.d/IP.issue
# Add some info to the default issue message
[ ! -f /etc/issue.d/ServiceMode.issue ] && sudo tee /etc/issue.d/ServiceMode.issue << 'EOF'
S E R V I C E      M O D E

IP Address: \4

EOF

# We find the mountpoint of the boot partition
BOOTMNT=$(findmnt /dev/mmcblk0p1 -n -o target)

if [ $DisableWiFi == "True" ]; then
  grep -q "dtoverlay=disable-wifi" $BOOTMNT/config.txt || sudo tee -a $BOOTMNT/config.txt << 'EOF'
# Turns off WiFi (for those who use Ethernet only)
dtoverlay=disable-wifi

EOF
  # Désactiver WPA Supplicant et RFKill (liés au Wi-Fi)...
  sudo apt-get remove wpasupplicant rfkill -y
fi

if [ $DisableBluetooth == "True" ]; then
    grep -q "dtoverlay=disable-bt" $BOOTMNT/config.txt || sudo tee -a $BOOTMNT/config.txt << 'EOF'
# Turns off Bluetooth
dtoverlay=disable-bt

EOF
  # Retrait des paquets liés à Bluetooth...
  sudo apt-get remove bluez pi-bluetooth -y
fi

if [ $DisableIPv6 == "True" ]; then
  sudo nmcli device modify eth0 ipv6.method "disabled"
fi

# Désactivation de Avahi (mDNS)
sudo apt-get remove avahi-daemon -y

# Désactivation de ModemManager (utile pour connexions mobiles)
sudo apt-get remove modemmanager -y

# Désactivation du client NFS
sudo apt-get remove nfs-common -y

# Redémarrage du réseau, suite aux changements précédents
sudo systemctl restart NetworkManager

# Bascule du CPU Governor en mode Performance...
sudo apt-get install cpufrequtils -y
grep -q GOVERNOR= /etc/init.d/cpufrequtils && sudo sed -i "s/GOVERNOR=.*$/GOVERNOR=\"performance\"/g" /etc/init.d/cpufrequtils
sudo systemctl daemon-reload
sudo systemctl restart cpufrequtils.service

# Un peu de ménage en terminant
sudo apt-get autoremove -y
sudo rm /etc/systemd/system/multi-user.target.wants/avahi-daemon.service
sudo rm /etc/systemd/system/multi-user.target.wants/dphys-swapfile.service
sudo rm /etc/systemd/system/multi-user.target.wants/ModemManager.service
sudo rm /etc/systemd/system/multi-user.target.wants/nfs-client.target
sudo rm /etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
sudo rm /etc/systemd/system/bluetooth.target.wants/bluetooth.service
sudo rm /etc/systemd/system/dbus-fi.w1.wpa_supplicant1.service
sudo rm /etc/systemd/system/dbus-org.bluez.service
sudo rm /etc/systemd/system/dbus-org.freedesktop.Avahi.service
sudo rm /etc/systemd/system/dbus-org.freedesktop.ModemManager1.service

