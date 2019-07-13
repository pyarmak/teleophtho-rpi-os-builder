FROM i386/debian:buster

# Install build dependencies

RUN apt-get update && apt-get install -y \
    binfmt-support \
    gpg \
    qemu \
    qemu-user-static \
    wget \
    gpg-agent \
    debootstrap \
    dmsetup \
    kpartx \
    dosfstools \
    vim-common \
    --no-install-recommends 

RUN DEBIAN_FRONTEND=noninteractive apt-get -y install apt-cacher-ng 
RUN rm -rf /var/lib/apt/lists/*

# Create working directory

WORKDIR /workspace


