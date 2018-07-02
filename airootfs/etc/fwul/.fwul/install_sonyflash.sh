#!/bin/bash

sudo pacman --noconfirm -Sy
sudo yaourt --noconfirm -Sy
pacman -Q xperia-flashtool
if [ $? -ne 0 ];then
    #sudo $HOME/.fwul/install_package.sh yaourt xperia-flashtool

    # upstream outdated! issue #70 workaround
    cd /tmp/
    wget http://leech.binbash.it:8008/misc/xperia-flashtool-interim.pkg.tar.xz -O xperia-flashtool-interim.pkg.tar.xz
    pacman -Q libselinux || sudo $HOME/.fwul/install_package.sh yaourt libselinux
    sudo pacman -S --noconfirm xperia-flashtool-interim.pkg.tar.xz 
    rm xperia-flashtool-interim.pkg.tar.xz
    # upstream outdated! issue #70 workaround
fi

pacman -Q libselinux && pacman -Q xperia-flashtool && cp ~/.fwul/sonyflash.desktop ~/Desktop/ && chmod +x ~/Desktop/sonyflash.desktop && rm ~/Desktop/install-sonyflash.desktop

