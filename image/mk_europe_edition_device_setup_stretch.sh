#!/bin/bash

# DO NOT CALL ME DIRECTLY!
# This script is called by mk_europe_edition.sh via qemu
apt-get install -y wiringpi

cd /root/stratux

# Make sure that the upgrade doesn't restart services in the chroot..
mkdir /root/fake
ln -s /bin/true /root/fake/initctl
ln -s /bin/true /root/fake/invoke-rc.d
ln -s /bin/true /root/fake/restart
ln -s /bin/true /root/fake/start
ln -s /bin/true /root/fake/stop
ln -s /bin/true /root/fake/start-stop-daemon
ln -s /bin/true /root/fake/service
ln -s /bin/true /root/fake/deb-systemd-helper

# Fake a proc FS for raspberrypi-sys-mods_20170519_armhf... Extend me as needed
mkdir -p /proc/sys/vm/

apt update
PATH=/root/fake:$PATH apt dist-upgrade --yes
PATH=/root/fake:$PATH apt install --yes libjpeg8-dev libconfig9 rpi-update hostapd isc-dhcp-server tcpdump git cmake \
    libusb-1.0-0.dev build-essential mercurial build-essential autoconf fftw3 fftw3-dev libtool i2c-tools python-smbus \
    python-pip python-dev python-pil python-daemon screen #libsdl1.2-dev
apt-get clean
echo y | rpi-update

systemctl enable isc-dhcp-server
systemctl enable ssh
systemctl disable ntp
systemctl disable dhcpcd
systemctl disable hciuart

rm -r /proc/*
rm -r /root/fake

# Prepare wiringpi for fancontrol and some more tools
cd /root && git clone https://github.com/WiringPi/WiringPi.git && cd WiringPi/wiringPi && make && make install



ldconfig


cd /root/stratux
cp image/bashrc.txt /root/.bashrc
source /root/.bashrc

# Prepare librtlsdr
rm -rf /root/librtlsdr
git clone https://github.com/jpoirier/librtlsdr /root/librtlsdr
mkdir -p /root/librtlsdr/build
cd /root/librtlsdr/build && cmake .. && make && make install && ldconfig
chroot mnt/ 'cd /root/librtlsdr/build && cmake ../ && make && make install && ldconfig'

# Compile stratux
cd /root/stratux

# For some reason, qemu build fails unless we use a single compilation thread. Compilation takes quite long...
export GOMAXPROCS=1
#go get -u github.com/kidoman/embd/embd
make clean
# Sometimes go build fails for some reason.. we will just try three times and hope for the best
make
make
make
make install


##### Some device setup - copy files from image directory ####
cd /root/stratux/image
#motd
cp -f motd /etc/motd

#dhcpd config
cp -f dhcpd.conf /etc/dhcp/dhcpd.conf

#hostapd config
cp -f hostapd.conf /etc/hostapd/hostapd.conf
cp -f hostapd-edimax.conf /etc/hostapd/hostapd-edimax.conf
#hostapd manager script
cp -f hostapd_manager.sh /usr/sbin/hostapd_manager.sh
chmod 755 /usr/sbin/hostapd_manager.sh
#hostapd
cp -f hostapd-edimax /usr/sbin/hostapd-edimax
chmod 755 /usr/sbin/hostapd-edimax
#remove hostapd startup scripts
rm -f /etc/rc*.d/*hostapd /etc/network/if-pre-up.d/hostapd /etc/network/if-post-down.d/hostapd /etc/init.d/hostapd /etc/default/hostapd
#interface config
cp -f interfaces /etc/network/interfaces
#custom hostapd start script
cp stratux-wifi.sh /usr/sbin/
chmod 755 /usr/sbin/stratux-wifi.sh

#SDR Serial Script
cp -f sdr-tool.sh /usr/sbin/sdr-tool.sh
chmod 755 /usr/sbin/sdr-tool.sh

#ping udev
cp -f 99-uavionix.rules /etc/udev/rules.d

#logrotate conf
cp -f logrotate.conf /etc/logrotate.conf

#fan/temp control script
#remove old script
rm -rf /usr/bin/fancontrol.py /usr/bin/fancontrol
#install new program
cp ../fancontrol /usr/bin
chmod 755 /usr/bin/fancontrol
/usr/bin/fancontrol remove
/usr/bin/fancontrol install

#isc-dhcp-server config
cp -f isc-dhcp-server /etc/default/isc-dhcp-server

#sshd config
cp -f sshd_config /etc/ssh/sshd_config

#udev config
cp -f 10-stratux.rules /etc/udev/rules.d

#stratux files
cp -f ../libdump978.so /usr/lib/libdump978.so

#debug aliases
cp -f stxAliases.txt /root/.stxAliases

#rtl-sdr setup
cp -f rtl-sdr-blacklist.conf /etc/modprobe.d/

#system tweaks
cp -f modules.txt /etc/modules

#boot settings
cp -f config.txt /boot/

cp /root/stratux/test/screen/screen.py /usr/bin/stratux-screen.py
mkdir -p /etc/stratux-screen/
cp -f /root/stratux/test/screen/stratux-logo-64x64.bmp /etc/stratux-screen/stratux-logo-64x64.bmp
cp -f /root/stratux/test/screen/CnC_Red_Alert.ttf /etc/stratux-screen/CnC_Red_Alert.ttf

#startup scripts
cp -f ../__lib__systemd__system__stratux.service /lib/systemd/system/stratux.service
cp -f ../__root__stratux-pre-start.sh /root/stratux-pre-start.sh
cp -f rc.local /etc/rc.local

#kalibrate-rtl
cd /root
rm -rf kalibrate-rtl
git clone https://github.com/steve-m/kalibrate-rtl
cd kalibrate-rtl
./bootstrap
./configure
make
make install

# TODO: do we need this?
#cd /root
#git clone https://github.com/rm-hull/ssd1306
#cd ssd1306
# Force an older version of ssd1306, since recent changes have caused a lot of compatibility issues.
#git reset --hard 232fc801b0b8bd551290e26a13122c42d628fd39
#python setup.py install


#disable serial console
sed -i /boot/cmdline.txt -e "s/console=ttyAMA0,[0-9]\+ //"

#Set the keyboard layout to US.
sed -i /etc/default/keyboard -e "/^XKBLAYOUT/s/\".*\"/\"us\"/"




# Now also prepare the update file..
cd /root/stratux/selfupdate
./makeupdate.sh
