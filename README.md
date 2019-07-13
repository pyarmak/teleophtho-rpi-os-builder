Using ideas from pi-gen and the Hypriot project, I have composed these scripts to enable the building of a working Raspberry Pi Image.

You can change settings such as the OS variant you want to build within the build_sysroot.sh file.

To modify what packages are installed edit the chroot-script.sh file.

By default the script will build a Buster image with SSH root access enabled.

Default Credentials:

Username: root
Password: raspberry

(Please set your own password within the build_sysroot.sh script)

Features
********

Nothing groundbreaking, but it uses the newly introducing caching feature within debootstrap and the excellent apt-cacher. Both apt and debootstrap are configured to store cached files on the host PC in osbuilder/cache. So subsequent builds don’t need to download already downloaded packages again which saves a lot of time when experimenting.

Clone The Repo
**************

You can get hold of the scripts by executing the following command on your host PC.

git clone https://bitbucket.org/bespoketechltd/rpi-os-builder.git

Host Requirements
*****************

I used Ubuntu 18.04 server running in VMware for my docker host. You will need to install and ensure docker is working before continuing.
In addition, the injection of the sysroot into the img file uses GuestFish. I couldn’t get it to work properly under docker (if someone can help with that I would be grateful) so this part of the process is handled outside of docker by the host OS, so in addition to a working docker setup you also need to install the following package…

apt-get install libguestfs-tools

Usage
*****

After cloning the repo, execute within the clone folder:

./build_docker_image.sh

Once the docker image is built, you can execute the Pi image build by simply running:

./build.sh

Once finished, all going well you should end up with an image in the output folder ready for writing to an SD card.
