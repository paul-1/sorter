#!/bin/bash -e

#
#	Sorts out all built modules to module extensions, and a tarball for what goes in the base.
#
#	Before running, do a "make INSTALL_MOD_PATH=/tmp/somewhere/usr/local modules_install" and
#	any other preprocessing, like gzipping the modules and removing generated files in
#	lib/modules/KERNELVER.
#	Things will happen in the current directory.
#
#
#	Usage:		./sorter.sh KERNELVER PATH
#	Example:	./sorter.sh 2.6.33-tinycore /tmp/somewhere
#

packup() {

	cd $BASEPATH

	OLDDIR=$OLDPWD
	TARBALL=$1
	shift


	rm -rf /tmp/xtra
	> /tmp/list
	for i in $@; do
		find usr/local/lib/modules/$KERNEL/kernel/${i} -type f >> /tmp/list
	done

	tar -cvzf ${OLDDIR}/${TARBALL}.tgz -T /tmp/list
	for g in `cat /tmp/list`; do rm $g; done

	mkdir /tmp/xtra
	tar -C /tmp/xtra -xf ${OLDDIR}/${TARBALL}.tgz
	cd /tmp
	mksquashfs xtra ${TARBALL}.tcz
	md5sum ${TARBALL}.tcz > $OLDDIR/${TARBALL}.tcz.md5.txt
	zsyncmake -u ${TARBALL}.tcz ${TARBALL}.tcz

	mv ${TARBALL}.tcz* $OLDDIR

	find xtra -type f -exec modinfo '{}' \; >> ${OLDDIR}/${TARBALL}.moddeps
	grep depends ${OLDDIR}/${TARBALL}.moddeps | cut -d: -f2 | sed -e 's@^[ ]*@@' -e '/^$/d' -e 's@,@\n@g' |
		sort | uniq > /tmp/tmpdeps
	mv /tmp/tmpdeps ${OLDDIR}/${TARBALL}.moddeps

	cd xtra
	find -type f > ${OLDDIR}/${TARBALL}.tcz.list

	rm ${OLDDIR}/${TARBALL}.tgz

	cd $OLDDIR

}




# Main

[ $# -ne 2 ] && echo "Usage: $0 KERNELVER PATH" && exit 1

KERNEL=$1
BASEPATH=$2

echo Sorting $KERNEL modules from $BASEPATH

[ ! -e ${BASEPATH}/usr/local/lib/modules/${KERNEL} ] && echo Some param wrong && exit 1

# Packing up

packup kvm-$KERNEL arch/x86/kvm/*
packup filesystems-$KERNEL fs/[cehjmrux]*/* fs/nfsd/*
packup alsa-modules-$KERNEL sound
packup bluetooth-$KERNEL net/bluetooth drivers/bluetooth
packup irda-$KERNEL net/irda drivers/net/irda drivers/usb/serial/ir-usb*
packup net-bridging-$KERNEL net/bridge
packup net-sched-$KERNEL net/sched
packup ipv6-$KERNEL net/ipv6
packup netfilter-$KERNEL net/ipv4 net/netfilter
packup wireless-$KERNEL net/mac80211 net/wireless drivers/net/wireless
packup graphics-$KERNEL drivers/char/agp drivers/gpu drivers/usb/misc/sisusbvga
packup firewire-$KERNEL drivers/firewire
packup hwmon-$KERNEL drivers/hwmon
packup i2c-$KERNEL drivers/i2c
packup raid-dm-$KERNEL drivers/md lib/raid*
packup input-joystick-$KERNEL drivers/input/joy* drivers/input/gameport
packup input-tablet-touchscreen-$KERNEL drivers/input/tablet drivers/input/touchscreen
packup v4l-dvb-$KERNEL drivers/media drivers/usb/misc/isight*
packup mtd-$KERNEL drivers/mtd
packup usb-serial-$KERNEL drivers/usb/misc/uss* drivers/usb/serial
packup leds-$KERNEL drivers/leds
packup wimax-$KERNEL net/wimax drivers/net/wimax
packup pci-hotplug-$KERNEL drivers/pci/hotplug
packup thinkpad-acpi-$KERNEL drivers/platform/x86/thinkpad_acpi*
packup watchdog-$KERNEL drivers/watchdog
packup ax25-$KERNEL net/ax25 net/rose net/netrom drivers/net/hamradio
packup scsi-$KERNEL drivers/scsi drivers/message

# Meta-extension for original modules
EMPTYD=`mktemp -d`
mkdir -p ${EMPTYD}/lib
ls *.tcz > original-modules-$KERNEL.tcz.dep
mksquashfs $EMPTYD original-modules-$KERNEL.tcz
md5sum original-modules-$KERNEL.tcz > original-modules-$KERNEL.tcz.md5.txt
zsyncmake -u original-modules-$KERNEL.tcz original-modules-$KERNEL.tcz
rmdir $EMPTYD

# The rest goes to the base.

cd ${BASEPATH}/usr/local
ln -s /usr/local/lib/modules/${KERNEL}/kernel/ lib/modules/${KERNEL}/kernel.tclocal
mkdir usr/local/lib/modules/${KERNEL}/kernel/
find lib/modules ! -type d > /tmp/list
echo usr/local/lib/modules/${KERNEL}/kernel/ >> /tmp/list
tar cvzf ${OLDPWD}/base_modules.tgz -T /tmp/list

cd -

cp /tmp/list base_modules.tgz.list

echo -e "\n\n"'Done!'
