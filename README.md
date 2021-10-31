# ALARM (ArchLinuxArm) Imager

I wrote this script as I install ALARM on a number of my SBCs and it was a pain to go through multiple devices manually using the wiki. I have automated the instructions and given three methods for creating an image:
1. A script that writes directly to the SD Card/USB Drive. Be careful you get the correct device (e.g. /dev/sda or /dev/mmcblk0.)
2. A script that creates an image that can be used to make the above. This is the default method for the script.
3. A docker image that runs the script.
Use what ever works best.

## Script

## Docker

## To Do
There is some functionality I want to add to the script. This includes:
* Adding a startup script with the recommended startup commands for each board
* Making the docker multi-arch

## Contribution
Feel free to send pull requests with any improvements. I only do this as a hobby, so changes may not be quick.


