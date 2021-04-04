#!/bin/bash
# A Script to Automate making a SD Image for ArchLinuxARM
# Choose the board from BananaPiPro, RPi3, RPi4 or Rock64
BOARD="Rock64"
# Put in the device location for the SD Card
SDCARD="/dev/sda"
# Arch Installer Directory
ARCH_DIR="/home/pi/Downloads/ArchLinux"
# Root directory and partition number (default of 1)
ROOT_DIR="${ARCH_DIR}/Working/root"
ROOT_PART=1
# Boot partition number (default of 0) and bs (default 1M) and count (default 0) for zeroing beginning of sd card
BOOT_PART=0
BOOT_ZERO_BS="1M"
BOOT_ZERO_COUNT=0
# Default BOOT for boot.scr to being null
BOOT=""

#Check for supported board
if ["$BOARD" -ne "BananaPiPro"] && ["$BOARD" -ne "RPi3"] && ["$BOARD" -ne "RPi4"] && ["$BOARD" -ne "Rock64"];
then
	echo "You have selected a non-supported board"
	exit 1
elif ["$BOARD" -eq "RPi3"] || ["$BOARD" -eq "RPi4"];
then
	BOARD_DIR="${ARCH_DIR}/RPi"
else
	BOARD_DIR="${ARCH_DIR}/${BOARD}"
fi

# Set the partition layout
SDCARDTABLE="${BOARD_DIR}/microsd.out"
# make folders
mkdir -p ${ROOT_DIR} ${BOOT_DIR} ${BOARD_DIR}

#BananaPiPro
if ["$BOARD" -eq "BananaPiPro"];
then
	IMAGE="${BOARD_DIR}/ArchLinuxARM-arm7-latest.tar.gz"
	wget -O ${IMAGE} -N http://os.archlinuxarm.org/os/ArchLinuxARM-arm7-latest.tar.gz
	BOOT="${BOARD_DIR}/boot.scr"
	wget -O ${BOOT} -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/boot.scr
	UBOOT="${BOARD_DIR}/u-boot-sunxi-with-spl.bin"
	wget -O ${UBOOT} -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/u-boot.itb	
	BOOT_ZERO_COUNT=8
#RPi3 and RPi4
elif ["$BOARD" -eq "RPi3"] || ["$BOARD"-eq "RPi4"];
then
	IMAGE="${BOARD_DIR}/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
	wget -O ${IMAGE} -N http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
	ROOT_PART=2
	BOOT_PART=1
#Rock64
elif ["$board" -eq "Rock64"];
then
	IMAGE="${BOARD_DIR}/ArchLinuxARM-aarch64-latest.tar.gz"
	wget -O ${IMAGE} -N http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
	BOOT="${BOARD_DIR}/boot.scr"
	wget -O ${BOOT} -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/boot.scr
	RKSD="${BOARD_DIR}/rksd_loader.img"
	wget -O ${RKSD} -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/rksd_loader.img
	UBOOT="${BOARD_DIR}/u-boot.itb"
	wget -O ${UBOOT} -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/u-boot.itb
	BOOT_ZERO_COUNT=32
fi
# Prepare sdcard
umount $SDCARD
# Zero start of SD Card
if [ ${BOOT_ZERO_COUNT} -gt 0];
then
	dd if=/dev/zero of=${SDCARD} bs=${BOOT_ZERO_BS} count=${BOOT_ZERO_COUNT}
fi
# Create the partition table
sfdisk -f $SDCARD < $SDCARDTABLE
# Create the boot directory if required
if [$BOOT_PART -gt 0];
then
	mkfs.vfat ${SDCARD}${BOOT_PART}
fi
# Add U-Boot
if ["$BOARD" -eq "BananaPiPro"];
then
	dd=${UBOOT} of=${SDCARD} bs=1024 seek=8
elif ["$board" -eq "Rock64"];
then
	dd=${RKSD} of=${SDCARD} seek=64 conv=notrunc
	dd=${UBOOT} of=${SDCARD} seek=16384 conv=notrunc
fi
# Create the root directory
if [ "$BOARD" -eq "BananaPiPro"];
then
	mkfs.ext4 -O ^metadata_csum,^64bit ${SDCARD}${ROOT_PART}
else
	mkfs.ext4 ${SDCARD}${ROOT_PART}
fi
mount ${SDCARD}${ROOT_PART} ${ROOT_DIR}
# If there is a seperate boot partition, mount it in /boot
if [$BOOT_PART -gt 0];
then
	mkdir -p ${ROOT_DIR}/boot
	mount ${SDCARD}${BOOT_PART} ${ROOT_DIR}/boot
fi
# Copy the image onto the sd card
bsdtar -xpf $IMAGE -C $ROOT_DIR
sync
# If boot.scr exists copy it onto the sd card
if [ -n "$boot"];
then
	mkdir -p ${ROOT_DIR}/boot
	cp ${BOOT} ${ROOT_DIR}/boot/boot.scr
	sync
fi
if [$BOOT_PART -gt 0];
# Unmount to end
then
	umount ${ROOT_DIR}/boot
fi
umount ${ROOT_DIR}

#Copy Startup Script
