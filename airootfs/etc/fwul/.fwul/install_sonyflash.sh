#!/bin/bash

sudo pacman --noconfirm -Sy
sudo yaourt --noconfirm -Sy
pacman -Q xperia-flashtool
if [ $? -ne 0 ];then
    pacman -Q git-lfs || ~/.fwul/install_package.sh yaourt git-lfs
    [ -d /tmp/arch_xperia-flashtool ]&& rm -rf /tmp/arch_xperia-flashtool
    cd /tmp && git clone https://github.com/steadfasterX/arch_xperia-flashtool.git && cd arch_xperia-flashtool && git lfs fetch
    wget http://www.flashtool.net/torrents/patches/linux/x10flasher.jar
    [ ! -f x10flasher.jar ]&& echo "ERROR downloading PATCH file" && exit 3
    pacman -Q libselinux || ~/.fwul/install_package.sh yaourt libselinux
    makepkg -si && cp x10flasher.jar /usr/lib/xperia-flashtool/ && echo full success 
fi

pacman -Q libselinux && pacman -Q xperia-flashtool && cp ~/.fwul/sonyflash.desktop ~/Desktop/ && chmod +x ~/Desktop/sonyflash.desktop && rm ~/Desktop/install-sonyflash.desktop

