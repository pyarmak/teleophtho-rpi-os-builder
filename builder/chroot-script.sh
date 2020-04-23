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

#setup gstreamer
# upgrade to latest Debian package versions
apt-get update
apt-get upgrade -y
# Get the required libraries
# libdirac-dev is not availble
apt-get install -y build-essential autotools-dev automake autoconf \
                    libtool autopoint libxml2-dev zlib1g-dev libglib2.0-dev \
                    pkg-config bison flex python3 git gtk-doc-tools libasound2-dev \
                    libgudev-1.0-dev libxt-dev libvorbis-dev libcdparanoia-dev \
                    libpango1.0-dev libtheora-dev libvisual-0.4-dev iso-codes \
                    libgtk-3-dev libraw1394-dev libiec61883-dev libavc1394-dev \
                    libv4l-dev libcairo2-dev libcaca-dev libspeex-dev libpng-dev \
                    libshout3-dev libjpeg-dev libaa1-dev libflac-dev libdv4-dev \
                    libtag1-dev libwavpack-dev libpulse-dev libsoup2.4-dev libbz2-dev \
                    libcdaudio-dev libdc1394-22-dev ladspa-sdk libass-dev \
                    libcurl4-gnutls-dev libdca-dev libdvdnav-dev \
                    libexempi-dev libexif-dev libfaad-dev libgme-dev libgsm1-dev \
                    libiptcdata0-dev libkate-dev libmimic-dev libmms-dev \
                    libmodplug-dev libmpcdec-dev libofa0-dev libopus-dev \
                    librsvg2-dev librtmp-dev libschroedinger-dev libslv2-dev \
                    libsndfile1-dev libsoundtouch-dev libspandsp-dev libx11-dev \
                    libxvidcore-dev libzbar-dev libzvbi-dev liba52-0.7.4-dev \
                    libcdio-dev libdvdread-dev libmad0-dev libmp3lame-dev \
                    libmpeg2-4-dev libopencore-amrnb-dev libopencore-amrwb-dev \
                    libsidplay1-dev libtwolame-dev libx264-dev libusb-1.0 \
                    python-gi-dev yasm python3-dev libgirepository1.0-dev \
                    libsrtp-dev liborc-dev python3-pip ninja-build
                    
# ln -s /opt/vc/lib/libbrcmEGL.so /opt/vc/lib/libEGL.so
# ln -s /opt/vc/lib/libbrcmGLESv2.so /opt/vc/lib/libGLESv2.so

mkdir -p /opt/gst-build && cd /opt/gst-build

#get repos if they are not there yet
[ ! -d gstreamer ] && git clone git://anongit.freedesktop.org/git/gstreamer/gstreamer
[ ! -d gst-plugins-base ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-base
[ ! -d gst-plugins-good ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-good
[ ! -d gst-plugins-bad ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-bad
[ ! -d gst-libav ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-libav
[ ! -d gst-plugins-ugly ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-ugly
[ ! -d gst-omx ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-omx
[ ! -d libnice ] && git clone https://gitlab.freedesktop.org/libnice/libnice

export LD_LIBRARY_PATH=/usr/local/lib/

#libnice for webrtc
cd libnice
./autogen.sh
./configure --enable-compile-warnings=no
make -j4 
sudo make install
cd ..

cd gstreamer
git checkout $BRANCH
./autogen.sh --disable-gtk-doc
make -j4
sudo make install
cd ..

cd gst-plugins-base
git checkout $BRANCH
./autogen.sh --disable-gtk-doc --disable-examples
make -j4
sudo make install
cd ..

cd gst-libav
git checkout $BRANCH
./autogen.sh --disable-gtk-doc --enable-orc
make -j4
sudo make install
cd ..

cd gst-plugins-good
git checkout $BRANCH
./autogen.sh --disable-gtk-doc
make -j4
sudo make install
cd ..

cd gst-plugins-ugly
git checkout $BRANCH
./autogen.sh --disable-gtk-doc
make -j4
sudo make install
cd ..

cd gst-plugins-bad
git checkout $BRANCH
./autogen.sh --disable-gtk-doc
export CFLAGS='-I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux/'
export LDFLAGS='-L/opt/vc/lib'
./configure CFLAGS='-I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux/' LDFLAGS='-L/opt/vc/lib' \
--disable-gtk-doc --disable-opengl --enable-gles2 --enable-egl --disable-glx \
--disable-x11 --disable-wayland --enable-dispmanx \
--with-gles2-module-name=/opt/vc/lib/libGLESv2.so \
--with-egl-module-name=/opt/vc/lib/libEGL.so
make CFLAGS+='-Wno-error -Wno-redundant-decls' LDFLAGS+='-L/opt/vc/lib' -j4
sudo make install
cd ..

# omx support
cd gst-omx
git checkout $BRANCH
export LDFLAGS='-L/opt/vc/lib' \
CFLAGS='-I/opt/vc/include -I/opt/vc/include/IL -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/IL' \
CPPFLAGS='-I/opt/vc/include -I/opt/vc/include/IL -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/IL'\
PKG_CONFIG_PATH='/opt/vc/lib/pkgconfig'
./autogen.sh --disable-gtk-doc --with-omx-target=rpi
make CFLAGS+='-Wno-error -Wno-redundant-decls' LDFLAGS+='-L/opt/vc/lib' -j4
sudo make install
cd ..

#finish up
sudo ln -s /usr/local/include/gstreamer-1.0 /usr/include
sudo ldconfig

#print version
gst-inspect-1.0 --gst-version

#build qt
mkdir /opt/qt-build && cd /opt/qt-build && wget http://download.qt.io/official_releases/qt/5.12/5.12.7/single/qt-everywhere-src-5.12.7.tar.xz
tar xf qt-everywhere-src-5.12.7.tar.xz

git clone https://github.com/oniongarlic/qt-raspberrypi-configuration.git
cd qt-raspberrypi-configuration && make install DESTDIR=../qt-everywhere-src-5.12.7 && cd ../

apt-get install build-essential libfontconfig1-dev libdbus-1-dev libfreetype6-dev libicu-dev libinput-dev libxkbcommon-dev libsqlite3-dev libssl-dev libpng-dev libjpeg-dev libglib2.0-dev libraspberrypi-dev

mkdir build && cd build

PKG_CONFIG_LIBDIR=/opt/vc/lib/pkgconfig:/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/share/pkgconfig \
../qt-everywhere-src-5.12.7/configure -platform linux-rpi3-g++ \
-v \
-opengl es2 -eglfs \
-no-gtk \
-opensource -confirm-license -release \
-reduce-exports \
-force-pkg-config \
-nomake examples -no-compile-examples \
-skip qtwayland \
-skip qtwebengine \
-skip qtlocation \
-qt-pcre \
-no-pch \
-ssl \
-evdev \
-gstreamer \
-system-freetype \
-fontconfig \
-glib \
-prefix /opt/Qt5.12 \
-qpa eglfs

make -j 8

make install