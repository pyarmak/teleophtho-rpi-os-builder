#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

cd output
rm -rf *
cd ..

docker run -it --rm -v $(pwd):/workspace -v $(pwd)/cache/apt_cache:/var/tmp --privileged osbuilder /workspace/builder/build_sysroot.sh

echo "Adding generated sysroot to image."
# create the image and add root base filesystem
cd output
guestfish -a "rpi-raw.img"<<_EOF_
run
#import filesystem content
mount /dev/sda2 /
tar-in image_with_kernel_root.tar.gz / compress:gzip
#mkdir /boot
mount /dev/sda1 /boot
tar-in image_with_kernel_boot.tar.gz /boot compress:gzip
_EOF_
read -n 1 -s -r -p "Build completed. Press any key to continue"

