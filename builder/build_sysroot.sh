#!/bin/bash
############################################################################################################
# common settings
ROOT_PASSWORD="raspberry"
OS_NAME="teleophtho-os"
OS_VERSION="v1"
RPI_HOSTNAME="teleophtho-streamer"
RPI_OS_VERSION="v1"
OS_VARIANT="buster"
############################################################################################################
BUILD_ARCH="armhf"
QEMU_ARCH="arm"
VARIANT="raspbian"
ROOTFS_DIR="/workspace/output/sysroot"
DEBOOTSTRAP_URL="http://raspbian.raspberrypi.org/raspbian/"
DEBOOTSTRAP_KEYRING_OPTION="--keyring=/etc/apt/trusted.gpg"
DEBOOTSTRAP_CMD="qemu-debootstrap"
############################################################################################################
set -ex
source builder/gpgcheck.sh

# this script should be run inside of a Docker container only
if [ ! -f /.dockerenv ]; then
  echo "ERROR: script works in Docker only!"
  exit 1
fi

# start apt cacher service
/usr/sbin/apt-cacher-ng

# for Raspbian we need an extra gpg key to be able to access the repository
mkdir -p /builder/files/tmp
wget -v -O "/builder/files/tmp/raspbian.public.key" http://raspbian.raspberrypi.org/raspbian.public.key
get_gpg A0DA38D0D76E8B5D638872819165938D90FDDD2E "/builder/files/tmp/raspbian.public.key"

# tell Linux how to start binaries that need emulation to use Qemu
update-binfmts --enable "qemu-${QEMU_ARCH}"

# debootstrap a minimal rootfs
${DEBOOTSTRAP_CMD} \
  ${DEBOOTSTRAP_KEYRING_OPTION} \
  --arch="${BUILD_ARCH}" \
  --cache-dir="/workspace/cache/debootstrap_cache" \
  "${OS_VARIANT}" \
  "${ROOTFS_DIR}" \
  "${DEBOOTSTRAP_URL}"

# modify/add image files directly
cp -R builder/files/* "$ROOTFS_DIR/"

#setup os name etc...
if [ "$OS_VARIANT" == "buster" ]; then

echo "$OS_NAME (Debian GNU/Linux 10) \n \l" > $ROOTFS_DIR/etc/issue
echo "$OS_NAME (Debian GNU/Linux 10)" > $ROOTFS_DIR/etc/issue.net

echo -e "$OS_NAME (Debian GNU/Linux 10)

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law." > $ROOTFS_DIR/etc/motd

else

echo "$OS_NAME (Debian GNU/Linux 9) \n \l" > $ROOTFS_DIR/etc/issue
echo "$OS_NAME (Debian GNU/Linux 9)" > $ROOTFS_DIR/etc/issue.net

echo -e "$OS_NAME (Debian GNU/Linux 9)

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law." > $ROOTFS_DIR/etc/motd

fi

# set up mount points for the pseudo filesystems
mkdir -p "$ROOTFS_DIR/proc" "$ROOTFS_DIR/sys" "$ROOTFS_DIR/dev/pts"
mount -o bind /dev "$ROOTFS_DIR/dev"
mount -o bind /dev/pts "$ROOTFS_DIR/dev/pts"
mount -t proc proc "$ROOTFS_DIR/proc"
mount -t sysfs none "$ROOTFS_DIR/sys"

# make our build directory the current root
# and install the Rasberry Pi firmware, kernel packages

chroot "$ROOTFS_DIR" \
       /usr/bin/env \
       OS_NAME="$OS_NAME" \
       RPI_HOSTNAME="$RPI_HOSTNAME" \
       RPI_OS_VERSION="$RPI_OS_VERSION" \
       BUILD_ARCH="$BUILD_ARCH" \
       VARIANT="$VARIANT" \
       OS_VARIANT="$OS_VARIANT" \
       ROOT_PASSWORD="$ROOT_PASSWORD" \
       /bin/bash < builder/chroot-script.sh

# unmount pseudo filesystems
umount -l "$ROOTFS_DIR/dev/pts"
umount -l "$ROOTFS_DIR/dev"
umount -l "$ROOTFS_DIR/proc"
umount -l "$ROOTFS_DIR/sys"

# ensure that there are no leftover artifacts in the pseudo filesystems
rm -rf "$ROOTFS_DIR/{dev,sys,proc}/*"

# time to create the img file

# get sysroot size.
cd output
SYSROOTSIZE=$(du --block-size=1M -s sysroot | awk '{print $1}');
cd ..

# set the amount of freespace to allow
FREESPACEBUFFER=1000

SD_CARD_SIZE=$(( SYSROOTSIZE + FREESPACEBUFFER ))
IMAGE_PATH="/workspace/output/rpi-raw.img"
BOOT_PARTITION_SIZE=300
BOOTFS_START=2048
BOOTFS_SIZE=$((BOOT_PARTITION_SIZE * 2048))
ROOTFS_START=$((BOOTFS_SIZE + BOOTFS_START))
SD_MINUS_DD=$((SD_CARD_SIZE * 1024 * 1024 - 256))
ROOTFS_SIZE=$((SD_MINUS_DD / 512 - ROOTFS_START))
echo "Building raw image"
dd if=/dev/zero of=${IMAGE_PATH} bs=1MiB count=${SD_CARD_SIZE} oflag=direct
DEVICE=$(losetup -f --show ${IMAGE_PATH})

echo "Image ${IMAGE_PATH} created and mounted as ${DEVICE}."

# create partions
sfdisk --force "${DEVICE}" <<PARTITION
unit: sectors
/dev/loop0p1 : start= ${BOOTFS_START}, size= ${BOOTFS_SIZE}, Id= c
/dev/loop0p2 : start= ${ROOTFS_START}, size= ${ROOTFS_SIZE}, Id=83
/dev/loop0p3 : start= 0, size= 0, Id= 0
/dev/loop0p4 : start= 0, size= 0, Id= 0
PARTITION

losetup -d "${DEVICE}"
DEVICE=$(kpartx -va ${IMAGE_PATH} | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1)
dmsetup --noudevsync mknodes
BOOTP="/dev/mapper/${DEVICE}p1"
ROOTP="/dev/mapper/${DEVICE}p2"
DEVICE="/dev/${DEVICE}"

# give some time to system to refresh
sleep 3

# create file systems
mkfs.vfat "${BOOTP}" -n "${OS_NAME}"
mkfs.ext4 "${ROOTP}" -L root -i 4096 # create 1 inode per 4kByte block (maximum ratio is 1 per 1kByte)

echo "### remove dev mapper devices for image partitions"
kpartx -vds ${IMAGE_PATH} || true

IMAGE_PARTUUID_PREFIX=$(dd if="/workspace/output/rpi-raw.img" skip=440 bs=1 count=4 2>/dev/null | xxd -e | cut -f 2 -d' ')
export IMAGE_PARTUUID_PREFIX

# create /etc/fstab
echo "
proc /proc proc defaults 0 0
PARTUUID=${IMAGE_PARTUUID_PREFIX}-01 /boot vfat defaults 0 0
PARTUUID=${IMAGE_PARTUUID_PREFIX}-02 / ext4 defaults,noatime 0 1
" > /workspace/output/sysroot/etc/fstab

# boot/cmdline.txt
echo "dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=PARTUUID=${IMAGE_PARTUUID_PREFIX}-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait" > /workspace/output/sysroot/boot/cmdline.txt

# create tar files of the sysroot
cd output
tar -czf image_with_kernel_boot.tar.gz -C sysroot/boot .
tar -czf image_with_kernel_root.tar.gz -C sysroot .






