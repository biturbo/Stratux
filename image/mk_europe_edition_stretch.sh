#!/bin/bash

# To run this, make sure that this is installed:
# sudo apt install --yes qemu-user-static gparted qemu-system-arm
# Run this script as root.
# Run with argument "dev" to not clone the stratux repository from remote, but instead copy this current local checkout onto the image

TMPDIR="$HOME/stratux-tmp"

# cd to script directory
cd "$(dirname "$0")"
SRCDIR="$(realpath $(pwd)/..)"
mkdir -p $TMPDIR
cd $TMPDIR

cd ../..

cd root
wget https://dl.google.com/go/go1.12.4.linux-armv6l.tar.gz
tar xzf go1.12.4.linux-armv6l.tar.gz
rm go1.12.4.linux-armv6l.tar.gz

if [ "$1" == "dev" ]; then
    cp -r $SRCDIR .
else
    git clone --recursive https://github.com/biturbo/stratux.git
fi
cd ../..

# Now download a specific kernel to run raspbian images in qemu and boot it..
chroot mnt qemu-arm-static /bin/bash -c /root/stratux/image/mk_europe_edition_device_setup_stretch.sh
mkdir out


# Copy the selfupdate file out of there..
cp mnt/root/stratux/work/*.sh out
rm -r mnt/root/stratux/work

echo "Final image has been placed into $TMPDIR/out. Please install and test the image."
