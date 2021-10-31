#!/bin/bash
## This script was created by Adam Bolsover to automate the creation of an Arch Linux Arm (ALARM) image to various single board computers.
# I have only added boards that I own and can test, others can be added but would need testing.
# The latest version can be found at github in my repository: bowseruk/ArchLinuxArm-Image-Create - https://github.com/bowseruk/ArchLinuxArm-Image-Create

## Configuration Variables
# Choose to make an image (Image) or write direct directly to the sd card or usb drive (drive path e.g. /dev/mmcblk0)
MODE="Image"
# Working path for the script
WORKING_PATH="/tmp/alarm-imager"
# The board being used:
# Banana pi = BANANA_PI - arch = ARM - arch flag will be ignored
# Banana pi pro = BANANA_PRO - arch = ARM - arch flag will be ignored
# Raspberry pi 3 = RASPBERRY_PI_3 - arch = ARM  (armv7) or ARM64
# Raspberry pi 4 = RASPBERRY_PI_4 - arch = ARM  (armv7) or ARM64
# Rock 64 = ROCK64 - arch = ARM64  - arch flag will be ignored
BOARD="RASPBERRY_PI_4"
ARCH="ARM64"
# Size of the image made, ignored for direct to SD Card which uses all available space.
IMAGE_SIZE=8000

## Functions
usage() {
    cat << EOF
usage: ArchLinuxArm-Imager.sh -m [Image] -d [Working Directory] -b [board] -a [Architecture] -s [Image Size] -h [Help]

where:

-m: Type Image for an image file, or the drive (/dev/mmcblk0, /dev/sda, etc) to image it directly. Default = Image
-d: Type a custom working directory for the drive. Deafult = /tmp/alarm-imager
-b: The board to make an image of. The supported boards are:
    Banana pi = BANANA_PI - arch = arm - arch flag will be ignored
    Banana pi pro = BANANA_PRO - arch = arm  - arch flag will be ignored
    Raspberry pi 3 = RASPBERRY_PI_3 - arch = arm  (armv7) or arm64
    Raspberry pi 4 = RASPBERRY_PI_4 - arch = arm  (armv7) or arm64
    Rock 64 = ROCK64 - arch = arm64  - arch flag will be ignored
    Default = RASPBERRY_PI_4
-a: Architecture to use. See above for available options. Default = ARM64
-s: Custom image size in MB for image mode. Default = 8000 (MB)
-h: Help for the script

EOF
exit
}
# Check that the dependency is installed
assert_tool() {
    if [ "x$(which $1)" = "x" ]; then
		echo "Missing required dependency: $1" >&2
		exit 1
	fi
}
# Check image destination
check_image() {
    if [ ${MODE} = "Image" ]; then
        echo "Making an image"
        mkdir -p /tmp/alarm-images
        IMAGE_LOCATION="/tmp/alarm-images/ALARM-${BOARD}-${ARCH}.img"
        dd if=/dev/zero of="${IMAGE_LOCATION}" iflag=fullblock bs=1M count="${IMAGE_SIZE}" && sync
        echo "${IMAGE_LOCATION}"
        TARGET=$(losetup --show -f "${IMAGE_LOCATION}")
        echo "$TARGET"
        return
    fi
    if [ ! -f "${MODE}" ]; then
        echo "Device does not exist"
        exit 1
    fi
    TARGET="${MODE}"
    echo "Imaging ${MODE}"
    return
}
format_image() {
    # If there is a boot partition then partition that first and assign the partitions, else one partition
    if [ ! -z $ZERO_LENGTH ]; then
        echo "Zeroing start of drive"
        dd if=/dev/zero of=${TARGET} bs=1M count=${ZERO_LENGTH}
    fi
    # Label the drive
    parted -s ${TARGET} mklabel msdos
    if [ ! -z $BOOT_SIZE ]; then
        echo "Creating a boot partition"
        parted -s "${TARGET}" unit MB mkpart primary fat32 $BOOT_OFFSET $((BOOT_SIZE+BOOT_OFFSET))
        parted -s "${TARGET}" set 1 boot on
        BOOT_PART="${TARGET}p1"
        ROOT_PART="${TARGET}p2"
        mkfs.vfat "${BOOT_PART}"
    else
        ROOT_PART="${TARGET}p1"
    fi
    echo "Creating a root partition"
    parted -s "${TARGET}" unit "${ROOT_UNIT}" mkpart primary $ROOT_OFFSET 100%
    if [ ! -z "$ROOT_FORMAT_OPTIONS" ]; then
        echo "Formatting root partition with options"
        mkfs.ext4 $ROOT_FORMAT_OPTIONS "${ROOT_PART}"
    else
        echo "Formatting root partition without options"
        mkfs.ext4 "${ROOT_PART}"
    fi
}
#
mount_image() {
    mkdir -p "${ROOT_PATH}"
    mount "${ROOT_PART}" "${ROOT_PATH}"
    if [ ! -z "${BOOT_PART}" ]; then
        mkdir -p "${BOOT_PATH}"
        mount "${BOOT_PART}" "${BOOT_PATH}"
    fi
}
# This script prepares a Banana Pi image
banana_pi() {
    # Create the folders that are needed
    mkdir -p "${WORKING_PATH}/${BOARD}/boot" "${WORKING_PATH}/${BOARD}/dd"
    #Create the files need to make the device bootable
    wget -c -N "https://raw.githubusercontent.com/bowseruk/ALARM-Imager/main/${BOARD}/boot/boot.cmd" -O "${WORKING_PATH}/${BOARD}/boot/boot.cmd"
    mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "BananaPI boot script" -d "${WORKING_PATH}/${BOARD}/boot/boot.cmd" "${WORKING_PATH}/${BOARD}/boot/boot.scr"
    ## TODO - uboot script
    if [ ! -f "${WORKING_PATH}/${BOARD}/dd/u-boot-sunxi-with-spl.bin" ]; then
        BUILD_ARCH=$(uname -m)
        echo "${BUILD_ARCH}"
        mkdir -p "/tmp/git/${BOARD}"
        cd "/tmp/git/${BOARD}"
        git clone git://git.denx.de/u-boot.git
        cd u-boot
        if [ ${BUILD_ARCH} = "armv7l" ]; then
            make -j4 "${DEFCONFIG}"
            make -j4
        else
            make -j4 ARCH=arm CROSS_COMPILE=arm-none-eabi- "${DEFCONFIG}"
            make -j4 ARCH=arm CROSS_COMPILE=arm-none-eabi-
        fi
        cp "/tmp/git/${BOARD}/u-boot/u-boot-sunxi-with-spl.bin" "${WORKING_PATH}/${BOARD}/dd/u-boot-sunxi-with-spl.bin"
        rm -r "/tmp/git/${BOARD}/u-boot"
        cd "${WORKING_PATH}"
    fi
}
# This script prepares a Rock64 image
rock64() {
    # Create the folders that are needed
    mkdir -p "${WORKING_PATH}/${BOARD}/boot" "${WORKING_PATH}/${BOARD}/dd"   
    # Download the boot.scr script for U-Boot and place it in the /boot directory:
    wget -c -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/boot.scr -O "${WORKING_PATH}/${BOARD}/boot/boot.scr"
    # Download and the bootloader:
    wget -c -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/rksd_loader.img -O "${WORKING_PATH}/${BOARD}/dd/rksd_loader.img"
    wget -c -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/u-boot.itb -O "${WORKING_PATH}/${BOARD}/dd/u-boot.itb"
}
# Install contents to root path
install_root() {
    mkdir -p "${WORKING_PATH}/Includes"
    wget -c -N ${URL} -O "${WORKING_PATH}/Includes/${IMAGE}"
    bsdtar -xpf "${WORKING_PATH}/Includes/${IMAGE}" -C "${ROOT_PATH}"
    if [ -d "${WORKING_PATH}/${BOARD}/boot" ]; then
        cp -r "${WORKING_PATH}/${BOARD}/boot/." "${BOOT_PATH}/"
    fi
}
# Process to unmount the image
umount_image() {
    # unmount the boot partition if it exists, then the root partition
    if [ ! -z ${BOOT_PART} ]; then
        umount "${BOOT_PATH}"
    fi
    umount "${ROOT_PATH}"
}
# Check the board choosen
select_board() {
    case $BOARD in
        [Bb][Aa][Nn][Aa][Nn][Aa]_[Pp][Ii] | [Bb]_[Pp][Ii] )
            echo "Banana pi board selected"
            ## Board variables
            BOARD="BANANA_PI"
            IMAGE="ArchLinuxARM-armv7-latest.tar.gz"
            URL="http://os.archlinuxarm.org/os/${IMAGE}"
            DEFCONFIG="Bananapi_defconfig"
            ARCH="ARM"
            ZERO_LENGTH=8
            ROOT_OFFSET=8192
            ROOT_FORMAT_OPTIONS="-O ^metadata_csum,^64bit"
            ROOT_UNIT="kB"
            ## Process to create an Image
            check_image
            format_image
            mount_image
            banana_pi
            install_root
            umount_image
            dd if="${WORKING_PATH}/${BOARD}/dd/u-boot-sunxi-with-spl.bin" of="${TARGET}" bs=1024 seek=8
            ;;
        [Bb][Aa][Nn][Aa][Nn][Aa]_[Pp][Ii]_[Pp][Rr][Oo] | [Bb][Aa][Nn][Aa][Nn][Aa]_[Pp][Rr][Oo] | [Bb]_[Pp][Rr][Oo] )
            echo "Banana Pro board selected"
            ## Board variables
            BOARD="BANANA_PRO"
            IMAGE="ArchLinuxARM-armv7-latest.tar.gz"
            URL="http://os.archlinuxarm.org/os/${IMAGE}"
            DEFCONFIG="Bananapro_defconfig"
            ARCH="ARM"
            ZERO_LENGTH=8
            ROOT_OFFSET=8192
            ROOT_FORMAT_OPTIONS="-O ^metadata_csum,^64bit"
            ROOT_UNIT="kB"
            ## Process to create an image
            check_image
            format_image
            mount_image
            banana_pi
            install_root
            umount_image
            dd if="${WORKING_PATH}/${BOARD}/dd/u-boot-sunxi-with-spl.bin" of="${TARGET}" bs=1024 seek=8
            ;;
        [Rr][Aa][Ss][Pp][Bb][Ee][Rr][Rr][Yy]_[Pp][Ii]_3 | [Rr][Pp][Ii]3 | [Rr]_[Pp][Ii]3 )
            echo "Raspberry pi 3 board selected"
            ## Board variables
            BOARD="RASPBERRY_PI_3"
            # Set the size of the boot parition
            BOOT_OFFSET=1
            BOOT_SIZE=200
            ROOT_OFFSET=$((BOOT_SIZE+BOOT_OFFSET))
            ROOT_UNIT="MB"
            ## Process to create an image
            # Check the arch to use - default to arm64
            if [ "${ARCH}" = "ARM" ]; then
                IMAGE="ArchLinuxARM-rpi-2-latest.tar.gz"
            else
                IMAGE="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
                ARCH="ARM64"  
            fi
            URL="http://os.archlinuxarm.org/os/${IMAGE}"
            check_image
            format_image
            mount_image
            install_root
            umount_image
            ;;
        [Rr][Aa][Ss][Pp][Bb][Ee][Rr][Rr][Yy]_[Pp][Ii]_4 | [Rr][Pp][Ii]4 | [Rr]_[Pp][Ii]4 )
            echo "Raspberry pi 4 board selected"
            ## Board variables
            BOARD="RASPBERRY_PI_4"
            # Set the size of the boot partition
            BOOT_OFFSET=1
            BOOT_SIZE=200
            ROOT_OFFSET=$((BOOT_SIZE+BOOT_OFFSET))
            ROOT_UNIT="MB"
            ## Process to create an image
            # Check the arch to use - default to arm64
            if [ "${ARCH}" = "arm" ]; then
                IMAGE="ArchLinuxARM-rpi-4-latest.tar.gz"
            else
                IMAGE="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
                ARCH="ARM64"
            fi
            URL="http://os.archlinuxarm.org/os/${IMAGE}"
            check_image
            format_image
            mount_image
            install_root
            umount_image
            ;;
        [Rr][Oo][Cc][Kk]64 | [Rr]64 )
            echo "Rock 64 board selected"
            ## Board variables
            BOARD="ROCK64"
            IMAGE="ArchLinuxARM-aarch64-latest.tar.gz"
            URL="http://os.archlinuxarm.org/os/${IMAGE}"
            ARCH="ARM64"
            ZERO_LENGTH=32
            ROOT_OFFSET=32768
            ROOT_UNIT="kB"
            ## Process to create an image
            check_image
            format_image
            mount_image
            rock64
            install_root
            umount_image
            dd if="${WORKING_PATH}/${BOARD}/dd/rksd_loader.img" of=$TARGET seek=64 conv=notrunc
            dd if="${WORKING_PATH}/${BOARD}/dd/u-boot.itb" of=${TARGET} seek=16384 conv=notrunc
            ;;
        *)
            usage
            exit
            ;;
    esac
}

# Initialize the pacman keyring and populate the Arch Linux ARM package signing keys:
# pacman-key --init
# pacman-key --populate archlinuxarm
# Install the U-Boot package
# Remove the boot.scr file manually downloaded previously:
# rm /boot/boot.scr
# Install the U-Boot package:
# pacman -Sy uboot-rock64
# When prompted, press y and hit enter to write the latest bootloader to the micro SD card


## Script
# Check for flags - see usage for descriptions
if ! [ $(id -u) = 0 ]; then
   echo "This script is designed to be run the root user. Use the sudo version instead."
   exit 1
fi
while getopts "m:d:b:a:s:h" opt; do
    case $opt in
        m )
        MODE=$OPTARG
        ;;
        d )
        WORKING_PATH=$OPTARG
        ;;
        b )
        BOARD=$OPTARG
        ;;
        a )
        ARCH=$OPTARG
        ;;
        s )
        if [ $OPTARG -lt 8000 ]; then
            echo "The image size is below 8000 MB, the minimum supported by Arch Linux Arm"
            exit
        fi
        IMAGE_SIZE=$OPTARG
        ;;
        h )
        usage
        ;;
    esac
done
# Create the root path and check it exists
ROOT_PATH="/mnt/root"
BOOT_PATH="/mnt/root/boot"
mkdir -p ${ROOT_PATH}
if [ ! -d ${ROOT_PATH} ]; then
    echo "Issue with specified working directory"
    exit
fi
# Run the select board script
cd ${WORKING_PATH}
select_board
if [ ${MODE} = "Image" ]; then
    losetup -d $TARGET
    mkdir -p "${WORKING_PATH}/Images"
    mv "${IMAGE_LOCATION}" "${WORKING_PATH}/Images/"
fi
rm -r ${ROOT_PATH}
