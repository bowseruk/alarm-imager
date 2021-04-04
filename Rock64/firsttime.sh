#!/bin/bash
pacman-key --init
pacman-key --populate archlinuxarm
rm /boot/boot.scr
pacman -Syu uboot-rock64 --noconfirm
