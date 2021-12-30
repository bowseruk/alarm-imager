#!/bin/bash
## This script was created by Adam Bolsover to automate the creation of an Arch Linux Arm (ALARM) image to various single board computers.
# I have only added boards that I own and can test (and a few with very similar specs), others can be added but would need testing.
# The latest version can be found at github in my repository: bowseruk/alarm-imager - https://github.com/bowseruk/alarm-imager

## Configuration Variables
# Choose to make an image (Image) or write direct directly to the sd card or usb drive (drive path e.g. /dev/mmcblk0)
MODE="Image"
# Working path for the script
WORKING_PATH="/data/alarm-imager"
INCLUDES_PATH="${WORKING_PATH}/Includes"
IMAGE_PATH="${WORKING_PATH}/Images"
# Mount points for the script
ROOT_PATH="/mnt/root"
BOOT_PATH="/mnt/root/boot"
# Temporary location for image while it is created
TEMP_IMAGE_PATH="/tmp/alarm-imager"
TEMP_BUILD_PATH="/tmp/git"
# The board being used:
# All - Create all possible images for all boards and all architectures, but will move mode to Image
# Banana pi = Banana_Pi - arch = armv7 - arch flag will be ignored
# Banana pi pro = Banana_Pro - arch = armv7 - arch flag will be ignored
# Raspberry pi 2 = Raspberry_Pi_2 - arch = armv7 - arch flag will be ignored
# Raspberry pi 3 = Raspberry_Pi_3 - arch = armv7 or arm64
# Raspberry pi 4 = Raspberry_Pi_4 - arch = armv7 or arm64
# Rock 64 = Rock64 - arch = arm64 - arch flag will be ignored
BOARD="RASPBERRY_PI_4"
ARCH="arm64"
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
    Banana pi = Banana_Pi - arch = armv7 - arch flag will be ignored
    Banana pi pro = Banana_Pro - arch = armv7  - arch flag will be ignored
    Raspberry pi 3 = Raspberry_Pi_3 - arch = armv7 or arm64
    Raspberry pi 4 = Raspberry_Pi_4 - arch = armv7 or arm64
    Rock 64 = Rock64 - arch = arm64  - arch flag will be ignored
    Default = Raspberry_Pi_4
    All = create all possible images with all Arch combinations. This will ignore Mode and only work in Image mode.
-a: Architecture to use. See above for available options. Default = ARM64
-s: Custom image size in MB for image mode. Default = 8000 (MB)
-n: Remove all items used to create the image. This will also delete any previously cached data.
-h: Help for the script

EOF
    clean_up
    exit
}
# Pass a command as sudo if required
make_sudo() {
    if [ ! -z $SUDO ]; then
        sudo "$@"
    else
        "$@"
    fi
}
# make a directory using sudo if required and check it exists
make_directory() {
    for dir in "$@"
    do
        # Check the directory is writable and use sudo if not
        if [ ! -w "$(dirname "$dir")" ]; then
            make_sudo mkdir -p "$dir"
        else
            mkdir -p "$dir"
        fi
        # Check the path has been written and exit the script if there is an error.
        if [ ! -d "$dir" ]; then
            echo "The path $dir has not been written. The script will exit"
            clean_up
            exit
        fi
    done
}
remove_directory() {
    for dir in "$@"
    do
        # Use sudo if required
        make_sudo rm -r "$dir"
        # Check the path has been written and exit the script if there is an error.
        if [ -d "$dir" ]; then
            echo "The path $dir has not been removed. The script will exit"
            clean_up
            exit
        fi
    done
}
# Check that the dependency is installed
assert_tool() {
    for tool in "$@"
    do
            if [ "x$(which $tool)" = "x" ]; then
		    echo "Missing required dependency: $tool" >&2
            exit 1
	    fi
    done
}
# Check image destination
check_image() {
    if [ ${MODE} = "Image" ]; then
        echo "Making an image"
        make_directory "${TEMP_IMAGE_PATH}"
        IMAGE_LOCATION="${TEMP_IMAGE_PATH}/ALARM-${BOARD}-${ARCH}.img"
        dd if=/dev/zero of="${IMAGE_LOCATION}" iflag=fullblock bs=1M count="${ROOT_SIZE}" && sync
        echo "${IMAGE_LOCATION}"
        if [ ! -z $SUDO ]; then
            TARGET=$(sudo losetup --show -f "${IMAGE_LOCATION}")
        else
            TARGET=$(losetup --show -f "${IMAGE_LOCATION}")
        fi
        echo "$TARGET"
        return
    fi
    if [ ! -f "${MODE}" ]; then
        echo "Device does not exist"
        clean_up
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
        make_sudo dd if=/dev/zero of=${TARGET} bs=1M count=${ZERO_LENGTH}
    fi
    # Label the drive
    make_sudo parted -s ${TARGET} mklabel msdos
    if [ ! -z $BOOT_SIZE ]; then
        echo "Creating a boot partition"
        BOOT_PART="${TARGET}p1"
        ROOT_PART="${TARGET}p2"
        make_sudo parted -s "${TARGET}" unit MB mkpart primary fat32 $BOOT_OFFSET $((BOOT_SIZE+BOOT_OFFSET))
        make_sudo parted -s "${TARGET}" set 1 boot on   
        make_sudo mkfs.vfat "${BOOT_PART}"
    else
        ROOT_PART="${TARGET}p1"
    fi
    echo "Creating a root partition"
    make_sudo parted -s "${TARGET}" unit "${ROOT_UNIT}" mkpart primary $ROOT_OFFSET 100%
    if [ ! -z "$ROOT_FORMAT_OPTIONS" ]; then
        echo "Formatting root partition with options"
        make_sudo mkfs.ext4 $ROOT_FORMAT_OPTIONS "${ROOT_PART}"
    else
        echo "Formatting root partition without options"
        make_sudo mkfs.ext4 "${ROOT_PART}"
    fi
}
# Mounts the root and if necessary boot partitions for modification
mount_image() {
    make_directory "${ROOT_PATH}"
    make_sudo mount "${ROOT_PART}" "${ROOT_PATH}"
    if [ ! -z "${BOOT_PART}" ]; then
        make_directory "${BOOT_PATH}"
        make_sudo mount "${BOOT_PART}" "${BOOT_PATH}"
    fi
}
# Install contents to root path
install_root() {
    make_directory "${INCLUDES_PATH}"
    wget -c -N ${URL} -O "${INCLUDES_PATH}/${IMAGE}"
    make_sudo bsdtar -xpf "${INCLUDES_PATH}/${IMAGE}" -C "${ROOT_PATH}"
    if [ -d "${INCLUDES_PATH}/${BOARD}/boot" ]; then
        make_sudo cp -r "${INCLUDES_PATH}/${BOARD}/boot/." "${BOOT_PATH}/"
    fi
}
# Process to unmount the image
umount_image() {
    # unmount the boot partition if it exists, then the root partition

    ## TODO - add partition mount detection

    if [ ! -z ${BOOT_PART} ]; then
        make_sudo umount "${BOOT_PATH}"
    fi
    make_sudo umount "${ROOT_PATH}"
    remove_directory ${ROOT_PATH}
}
remove_loopback_device() {
    if [ ${MODE} = "Image" ]; then
        make_sudo losetup -d $TARGET
    fi
}
# Cleanup after script runs (or exits early)
clean_up() {
    if [ -d ${ROOT_PATH} ]; then
        umount_image
    fi
    remove_loopback_device
    if [ ${MODE} = "Image" ]; then
        make_directory "${IMAGE_PATH}"
        mv "${IMAGE_LOCATION}" "${IMAGE_PATH}/"
        remove_directory ${TEMP_IMAGE_PATH}
    fi
    if [ ! -z $NO_CACHE ]; then
        remove_directory "${INCLUDES_PATH}"
    fi
}
# Go through the process of creating the image. Cleanup has to be run seperatley as sometimes the image has to manipulated before cleanup but after unmounting
process_image() {
    make_directory "${WORKING_PATH}"
    cd "${WORKING_PATH}"
    if [ ! -z "$ROOT_OFFSET_MB" ]; then
        echo "Compensating for offset of root"
        ROOT_SIZE=$((IMAGE_SIZE - ROOT_OFFSET_MB))
    else
        echo "Not Compensating for offset of root"
        ROOT_SIZE=$IMAGE_SIZE
    fi
    check_image
    format_image
    mount_image
    install_root
    umount_image
}
# Use this to select the banana family of SBCs. Add an option of pi for Banana pi and pro for Banana pro.
banana_selected(){
    ## Board family variables
    ARCH="armv7"
    IMAGE="ArchLinuxARM-armv7-latest.tar.gz"
    ROOT_FORMAT_OPTIONS="-O ^metadata_csum,^64bit"
    ZERO_LENGTH=8
    ROOT_OFFSET=8192
    ROOT_UNIT="kB"
    ROOT_OFFSET_MB=${ROOT_OFFSET}/1000
    ## Board unique variables
    if [ $1 = "pi" ]; then
        SUFFIX="pi"
        BOARD="Banana_Pi"
        DEFCONFIG="Bananapi_defconfig"
    elif [ $1 = "pro" ]; then
        SUFFIX="pro"
        BOARD="Banana_Pro"
        DEFCONFIG="Bananapro_defconfig"
    else
        clean_up
        exit
    fi
    echo "Banana $SUFFIX board selected"        
    URL="http://os.archlinuxarm.org/os/${IMAGE}"
    ## Pre-imaging downloads
    # Check extra dependencies
    assert_tool git mkimage bison flex swig dtc python3 pip3 openssl
    # Create the folders that are needed
    make_directory "${INCLUDES_PATH}/${BOARD}/boot" "${INCLUDES_PATH}/${BOARD}/dd"
    wget -c -N "https://raw.githubusercontent.com/bowseruk/alarm-imager/main/${BOARD}/boot/boot.cmd" -O "${INCLUDES_PATH}/${BOARD}/boot/boot.cmd"
    make_sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "BananaPI boot script" -d "${INCLUDES_PATH}/${BOARD}/boot/boot.cmd" "${INCLUDES_PATH}/${BOARD}/boot/boot.scr"
    ## U Boot Build Script
    if [ ! -f "${INCLUDES_PATH}/${BOARD}/dd/u-boot-sunxi-with-spl.bin" ]; then
        BUILD_ARCH=$(uname -m)
        echo "${BUILD_ARCH}"
        U_BOOT_BUILD_PATH="${TEMP_BUILD_PATH}/${BOARD}"
        make_directory "${U_BOOT_BUILD_PATH}"
        cd "${U_BOOT_BUILD_PATH}"
        if [ ! -w "${U_BOOT_BUILD_PATH}" ]; then
            make_sudo git clone git://git.denx.de/u-boot.git
        else
            git clone git://git.denx.de/u-boot.git
        fi
        cd u-boot
        if [ ${BUILD_ARCH} = "armv7l" ]; then
            make_sudo make -j4 "${DEFCONFIG}"
            make_sudo make -j4
        else
            make_sudo make -j4 ARCH=arm CROSS_COMPILE=arm-none-eabi- "${DEFCONFIG}"
            make_sudo make -j4 ARCH=arm CROSS_COMPILE=arm-none-eabi-
        fi
        cp "/tmp/git/${BOARD}/u-boot/u-boot-sunxi-with-spl.bin" "${INCLUDES_PATH}/${BOARD}/dd/u-boot-sunxi-with-spl.bin"
        remove_directory "/tmp/git/${BOARD}/u-boot"
        cd "${WORKING_PATH}"
    fi
    ## Create the image
    process_image
    make_sudo dd if="${INCLUDES_PATH}/${BOARD}/dd/u-boot-sunxi-with-spl.bin" of="${TARGET}" bs=1024 seek=8
    clean_up
}
# Use this to select the Raspberry family of SBCs. Add an option of 2 for Raspberry Pi 2b, 3 for Raspberry Pi 3b(+) and 4 for Raspberry Pi 4b.
raspberry_selected(){
    ## Board family variables
    BOOT_OFFSET=1
    BOOT_SIZE=200
    ROOT_OFFSET=$((BOOT_SIZE+BOOT_OFFSET))
    ROOT_UNIT="MB"
    ROOT_OFFSET_MB=$ROOT_OFFSET
    ## Board unique variables
    if [ "$1" = 2 ]; then
        SUFFIX=2
        BOARD="Raspberry_Pi_2"
        IMAGE="ArchLinuxARM-rpi-2-latest.tar.gz"
        ARCH="armv7"
    elif [ "$1" = 3 ]; then
        SUFFIX=3
        BOARD="Raspberry_Pi_3"
        if [ "$2" = "armv7" ]; then
            IMAGE="ArchLinuxARM-rpi-2-latest.tar.gz"
            ARCH="armv7"
        else
            IMAGE="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
            ARCH="arm64"
        fi
    elif [ "$1" = 4 ]; then
    SUFFIX=4
        BOARD="Raspberry_Pi_4"
        if [ "$2" = "armv7" ]; then
            IMAGE="ArchLinuxARM-rpi-4-latest.tar.gz"
            ARCH="armv7"
        else
            IMAGE="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
            ARCH="arm64"
        fi
    else
        clean_up
        exit
    fi
    echo "Raspberry Pi $SUFFIX board selected"   
    URL="http://os.archlinuxarm.org/os/${IMAGE}"
    ## Create the image
    process_image
    clean_up
}
# Use this to select the Roock64 SBCs.
rock64_selected() {
    ## Board family variables
    ZERO_LENGTH=32
    ROOT_OFFSET=32768
    ROOT_UNIT="kB"
    ROOT_OFFSET_MB=${ROOT_OFFSET}/1000
    ## Board unique variables
    BOARD="Rock64"
    ARCH="arm64"
    IMAGE="ArchLinuxARM-aarch64-latest.tar.gz"
    echo "Rock 64 board selected"
    URL="http://os.archlinuxarm.org/os/${IMAGE}"
    ## Pre-imaging downloads
    # Create the folders that are needed
    make_directory "${INCLUDES_PATH}/${BOARD}/boot" "${INCLUDES_PATH}/${BOARD}/dd"   
    # Download the boot.scr script for U-Boot and place it in the /boot directory:
    wget -c -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/boot.scr -O "${INCLUDES_PATH}/${BOARD}/boot/boot.scr"
    # Download and the bootloader:
    wget -c -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/rksd_loader.img -O "${INCLUDES_PATH}/${BOARD}/dd/rksd_loader.img"
    wget -c -N http://os.archlinuxarm.org/os/rockchip/boot/rock64/u-boot.itb -O "${INCLUDES_PATH}/${BOARD}/dd/u-boot.itb"
    ## Create the image
    process_image
    make_sudo dd if="${INCLUDES_PATH}/${BOARD}/dd/rksd_loader.img" of=$TARGET seek=64 conv=notrunc
    make_sudo dd if="${INCLUDES_PATH}/${BOARD}/dd/u-boot.itb" of=${TARGET} seek=16384 conv=notrunc
    clean_up
}
# Use this to select imaging all SBCs
select_all_images(){
    MODE="Image"
    banana_selected "pi"
    banana_selected "pro"
    raspberry_selected 2
    raspberry_selected 3 armv7
    raspberry_selected 3 arm64
    raspberry_selected 4 armv7
    raspberry_selected 4 arm64
    rock64_selected
}
# Check the board choosen
select_board() {
    case $BOARD in
        [Aa][Ll][Ll] | [Aa] )
            # All
            select_all_images
            ;;
        [Bb][Aa][Nn][Aa][Nn][Aa]_[Pp][Ii] | [Bb]_[Pp][Ii] )
            # Banana Pi
            banana_selected "pi"
            ;;
        [Bb][Aa][Nn][Aa][Nn][Aa]_[Pp][Ii]_[Pp][Rr][Oo] | [Bb][Aa][Nn][Aa][Nn][Aa]_[Pp][Rr][Oo] | [Bb]_[Pp][Rr][Oo] )
            # Banana Pro
            banana_selected "pro"
            ;;
        [Rr][Aa][Ss][Pp][Bb][Ee][Rr][Rr][Yy]_[Pp][Ii]_2 | [Rr][Pp][Ii]2 | [Rr]_[Pp][Ii]2 )
            # Raspberry Pi 2
            raspberry_selected 2
            ;;
        [Rr][Aa][Ss][Pp][Bb][Ee][Rr][Rr][Yy]_[Pp][Ii]_3 | [Rr][Pp][Ii]3 | [Rr]_[Pp][Ii]3 )
            # Raspberry Pi 3
            raspberry_selected 3 ${ARCH}
            ;;
        [Rr][Aa][Ss][Pp][Bb][Ee][Rr][Rr][Yy]_[Pp][Ii]_4 | [Rr][Pp][Ii]4 | [Rr]_[Pp][Ii]4 )
            # Raspberry Pi 4
            raspberry_selected 4 ${ARCH}
            ;;
        [Rr][Oo][Cc][Kk]64 | [Rr]64 )
            # Rock64
            rock64_selected
            ;;
        *)
            # Default
            usage
            clean_up
            exit
            ;;
    esac
}
## Script
# Check base dependencies
assert_tool losetup dd mkdir rm rmdir cp mv parted mkfs.vfat mkfs.ext4 wget bsdtar mount umount
# Check for flags - see usage for descriptions
if ! [ $(id -u) = 0 ]; then
    echo "This script is designed to be run the root user. Attempting to use sudo instead."
    SUDO=true
fi
while getopts "m:d:b:a:s:nh" opt; do
    case $opt in
        m )
        MODE=$OPTARG
        ;;
        d )
        WORKING_PATH=$OPTARG
        INCLUDES_PATH="${WORKING_PATH}/Includes"
        IMAGE_PATH="${WORKING_PATH}/Images"
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
            clean_up
            exit
        fi
        IMAGE_SIZE=$OPTARG
        ;;
        n )
            echo "No cache selected. All files except the image will be removed on completetion"
            $NO_CACHE=true
        ;;
        h )
        usage
        ;;
    esac
done
# Run the select board script
select_board
