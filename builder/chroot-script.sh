#!/bin/bash
set -ex

apt-key add - < /raspberrypi.gpg.key
rm /raspberrypi.gpg.key

set -ex

#setup sources

if [ "$OS_VARIANT" == "stretch" ]; then
echo 'deb http://localhost:3142/mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi' > /etc/apt/sources.list
echo 'deb-src http://localhost:3142/mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi' >> /etc/apt/sources.list
echo 'deb http://localhost:3142/archive.raspberrypi.org/debian/ stretch main ui' > /etc/apt/sources.list.d/raspi.list
echo 'deb-src http://localhost:3142/archive.raspberrypi.org/debian/ stretch main ui' >> /etc/apt/sources.list.d/raspi.list
else
echo 'deb http://localhost:3142/mirrordirector.raspbian.org/raspbian/ buster main contrib non-free rpi' > /etc/apt/sources.list
echo 'deb-src http://localhost:3142/mirrordirector.raspbian.org/raspbian/ buster main contrib non-free rpi' >> /etc/apt/sources.list
echo 'deb http://localhost:3142/archive.raspberrypi.org/debian/ buster main ui' > /etc/apt/sources.list.d/raspi.list
echo 'deb-src http://localhost:3142/archive.raspberrypi.org/debian/ buster main ui' >> /etc/apt/sources.list.d/raspi.list
fi

# upgrade to latest Debian package versions
apt-get update
apt-get upgrade -y

#install base packages (taken from pi-gen for stretch lite)
apt-get install -y locales netbase 

### configure network ###

# set ethernet interface eth0 to dhcp
tee /etc/network/interfaces.d/eth0 << EOF
allow-hotplug eth0
iface eth0 inet dhcp
EOF

# configure and enable resolved
ln -sfv /run/systemd/resolve/resolv.conf /etc/resolv.conf
DEST=$(readlink -m /etc/resolv.conf)
mkdir -p "$(dirname "$DEST")"
touch /etc/resolv.conf
systemctl enable systemd-resolved

# set up /etc/resolv.conf
DEST=$(readlink -m /etc/resolv.conf)
export DEST
mkdir -p "$(dirname "${DEST}")"
echo "nameserver 8.8.8.8" > "${DEST}"

# enable ntp with timesyncd
sed -i 's|#Servers=|Servers=|g' /etc/systemd/timesyncd.conf
systemctl enable systemd-timesyncd

# set default locales to 'en_GB.UTF-8'
echo 'en_GB.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen

echo 'locales locales/default_environment_locale select en_GB.UTF-8' | debconf-set-selections
dpkg-reconfigure -f noninteractive locales


### RPIOS default settings ###

# set hostname
echo "$RPI_HOSTNAME" > /etc/hostname

# set RPIOS version infos
echo "RPI_OS=\"RPIOS/${BUILD_ARCH}\"" >> /etc/os-release
echo "RPI_OS_VERSION=\"${RPI_OS_VERSION}\"" >> /etc/os-release

# install kernel- and firmware-packages
apt-get install -y \
--no-install-recommends \
raspberrypi-bootloader \
libraspberrypi0 \
libraspberrypi-bin \
raspi-config \
openssh-server

# install WiFi firmware packages 
apt-get install -y \
--no-install-recommends \
firmware-atheros \
firmware-brcm80211 \
firmware-libertas \
firmware-misc-nonfree \
firmware-realtek

# install kernel
apt-get install -y \
--no-install-recommends \
raspberrypi-kernel

# /etc/modules
echo "snd_bcm2835
" >> /etc/modules

# as the Pi does not have a hardware clock we need a fake one
apt-get install -y \
  --no-install-recommends \
  fake-hwclock

# install packages for managing wireless interfaces
apt-get install -y \
  --no-install-recommends \
  wpasupplicant \
  wireless-tools \
  crda \
  raspberrypi-net-mods

# add firmware and packages for managing bluetooth devices
apt-get install -y \
  --no-install-recommends \
  pi-bluetooth

# Fix duplicate IP address for eth0, remove file from os-rootfs
rm -f /etc/network/interfaces.d/eth0

# fix eth0 interface name
ln -s /dev/null /etc/systemd/network/99-default.link

# cleanup APT cache and lists
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#set root password
echo "root:${ROOT_PASSWORD}" >/password
chpasswd </password
rm /password

#setup sources

if [ "$OS_VARIANT" == "stretch" ]; then
echo 'deb http://mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi' > /etc/apt/sources.list
echo 'deb-src http://mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi' >> /etc/apt/sources.list
echo 'deb http://archive.raspberrypi.org/debian/ stretch main ui' > /etc/apt/sources.list.d/raspi.list
echo 'deb-src http://archive.raspberrypi.org/debian/ stretch main ui' >> /etc/apt/sources.list.d/raspi.list
else
echo 'deb http://mirrordirector.raspbian.org/raspbian/ buster main contrib non-free rpi' > /etc/apt/sources.list
echo 'deb-src http://mirrordirector.raspbian.org/raspbian/ buster main contrib non-free rpi' >> /etc/apt/sources.list
echo 'deb http://archive.raspberrypi.org/debian/ buster main ui' > /etc/apt/sources.list.d/raspi.list
echo 'deb-src http://archive.raspberrypi.org/debian/ buster main ui' >> /etc/apt/sources.list.d/raspi.list
fi

#switch on ssh
touch /boot/ssh
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

