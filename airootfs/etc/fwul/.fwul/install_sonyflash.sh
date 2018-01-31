#!/bin/bash

sudo pacman --noconfirm -Sy
sudo yaourt --noconfirm -Sy
pacman -Q xperia-flashtool
if [ $? -ne 0 ];then
    sudo $HOME/.fwul/install_package.sh yaourt xperia-flashtool
fi

pacman -Q libselinux && pacman -Q xperia-flashtool && cp ~/.fwul/sonyflash.desktop ~/Desktop/ && chmod +x ~/Desktop/sonyflash.desktop && rm ~/Desktop/install-sonyflash.desktop

