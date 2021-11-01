# ALARM (ArchLinuxArm) Imager

I wrote this script as I install ALARM on a number of my SBCs and it was a pain to go through multiple devices manually using the [Arch Linux Arm website](https://archlinuxarm.org/) instructions for the board. So far I have implemented the following SBCs:
* [Banana Pi](https://wiki.archlinux.org/title/Banana_Pi) - The script recognises this board as BANANA_PI. As this is not officially supported by ALARM and I had the most deviations from the guide to get working, this is the most likely to break again.
* [Banana Pro](https://wiki.archlinux.org/title/Banana_Pro) - The script recognises this board as BANANA_PRO. Same as the banana pi in terms of issues.
* [Raspberry Pi model 3B/3B+](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-3) - The script recognises this board as RASPBERRY_PI_3. The script goes as described on the website, except the boot partition is mounted in the root partition to avoid the copy stage.
* [Raspberry Pi model 4](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4) - The script recognises this board as RASPBERRY_PI_4. The script goes as described on the website, except the boot partition is mounted in the root partition to avoid the copy stage.
* [Rock 64](https://archlinuxarm.org/platforms/armv8/rockchip/rock64) - The script recognises this board as ROCK64. The script goes as described on the website.

The automation has three methods of use for creating an image:
1. A script that writes directly to the SD Card/USB Drive. Be careful you get the correct device (e.g. /dev/sda or /dev/mmcblk0.)
2. A script that creates an image that can be used to make the above. This is the default method for the script.
3. A docker image that runs the script. This can be built with the dockerfile or used directly from [Docker Hub](https://hub.docker.com/r/bowseruk/alarm-imager).
They all execute the same process, so use your favourite method.

If you make an image, you can then write it with your favourite imager. Using WSL2 it is possible to build an image from Windows and image it using Rufus or Balena, etc.

## Getting Started

The first decision you need to make is how to use the script. I prefer the use of docker, as there is less consideration for dependencies. The use of both the script and docker is described below. I have used the docker successfully with a WSL2 image of Ubuntu as the docker host.

### Script
If you want to use the script directly you should first decide if you are going to make an image, or prepare the media (such as sd card) directly. If you are going to image the SD Card directly find the name of the device. I use the following command on Ubuntu and Arch:
    
    lsblk
    
This should show you the list of block devices connected including the device you want. Typically it will be a '/dev/sdX' or '/dev/mmcblkX', but becareful not to specify the wrong drive.

You can either edit the default variables at the top of the script, or you can use flags to set them. The command with flags looks like:

    ArchLinuxArm-Imager.sh -m [Image] -d [Working Directory] -b [board] -a [Architecture] -s [Image Size] -h [Help]

The '-m' flag sets if an image (input Image) or a drive is to used. If it is a drive put the /dev path such as '/dev/mmcblk0', '/dev/sda', 'etc'.
The '-d' flag sets if a custom working directory for the script is used. The default location is '/tmp/alarm-image'.
The '-b' flag sets the board to build for. The current list of options for this is:
* Banana pi = BANANA_PI - arch = arm - arch flag will be ignored
* Banana pi pro = BANANA_PRO - arch = arm  - arch flag will be ignored
* Raspberry pi 3 = RASPBERRY_PI_3 - arch = arm  (armv7) or arm64
* Raspberry pi 4 = RASPBERRY_PI_4 - arch = arm  (armv7) or arm64
* Rock 64 = ROCK64 - arch = arm64  - arch flag will be ignored
The Raspberry Pi 4 board is the default board the script will make an image for.
The '-a' flag sets the architecture to build for. This will default to ARM64 when there is a choice between ARM (armv7) and ARM64.
The '-s' flag is used to make a custom sized image. The units are MB and the default is 8000. 8000 MB is the minimum size recommended for ALARM images, so the smallest that can be selected.
The '-h' flag will list how to use the script and will not proceed to make an image if used.

If the media was manupulated directly, it will be unmounted and ready to use. Otherwise the image will be saved in the Images directory of the working directory in the format ALARM-BOARD-ARCH e.g. ALARM-BANANA_PI-ARM.img. Most of the files used will be saved in the working directory to save time if a new image is made. You can delete these if this is not wanted.

### Docker

The docker image can be built from the dockerfile or downloaded directly from github.

To build the image first download the repo, and run the following command from the directory:
    
    docker build . -t bowseruk/alarm-imager:latest
    
Or to pull it from Docker Hub:

    docker pull bowseruk/alarm-imager

Then run the docker run command

    docker run -e BOARD=board -e ARCH=architecture -e IMAGE_SIZE=desired_size  -v "/your/directory":/data/alarm-imager --privileged alarm-imager:latest

In this command the environment variables can be set:

Variable | Description
---------|-------------
BOARD | This sets the '-b' flag and chooses the board to build for. The current list of options for this is:<br>* Banana pi = BANANA_PI - arch = arm - arch flag will be ignored <br>* Banana pi pro = BANANA_PRO - arch = arm  - arch flag will be ignored<br>* Raspberry pi 3 = RASPBERRY_PI_3 - arch = arm  (armv7) or arm64<br>* Raspberry pi 4 = RASPBERRY_PI_4 - arch = arm  (armv7) or arm64<br>* Rock 64 = ROCK64 - arch = arm64  - arch flag will be ignored<br>The Raspberry Pi 4 board is the default board the script will make an image for.
ARCH | This sets the -a flag which chooses the architecture to build for when there is a choice. This will default to ARM64 when there is a choice between ARM (armv7) and ARM64. An invalid choice will revert to the default.
IMAGE_SIZE | This sets te '-s' flag which is used to make a custom sized image. The units are MB and the default is 8000. 8000 MB is the minimum size recommended for ALARM images, so the smallest that can be selected.

The /data/alarm-image directory is the working directory, and is where the image will be saved.

A sensible docker run command for Rock 64 Board might look like:

    docker run -e BOARD=ROCK64 -v "/home/user/alarm-imager":/data/alarm-imager --privileged alarm-imager:latest
    
And for a armv7 build on a raspberry pi 3 would look like:

    docker run -e BOARD=RASPBERRY_PI_3 -e ARCH=ARM -v "/home/user/alarm-imager":/data/alarm-imager --privileged alarm-imager:latest

The image will be saved in the Images directory of the working directory in the format ALARM-BOARD-ARCH e.g. ALARM-BANANA_PI-ARM.img. Most of the files used will be saved in the working directory to save time if a new image is made. You can delete these if this is not wanted.

## To Do
There is some functionality I want to add to the script. This includes:
* Adding a startup script with the recommended startup commands for each board.
* Add a dependancy checker per board for the script.
* Include a working script to resize boards to the full SD Card on first boot.
* Add option to delete everything except the image.
* An interactive version of the script
* An option to select multiple images for creation.

## Contribution
Feel free to send pull requests with any improvements. I only do this as a hobby, so changes may not be quick.


