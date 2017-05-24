#!/bin/bash

sudo pacman --noconfirm -Sy
sudo yaourt --noconfirm -Sy
pacman -Q xperia-flashtool
if [ $? -ne 0 ];then
    [ -d /tmp/arch_xperia-flashtool ]&& rm -rf /tmp/arch_xperia-flashtool
    cd /tmp && git clone https://github.com/steadfasterX/arch_xperia-flashtool.git && cd arch_xperia-flashtool
    
    # this one is fun: we source the config from git and create the download URL + filename dynamically
    # this way we do not need to build a new FWUL version when a new sony flashtool version will be released!
    source PKGBUILD
    wget "$downloadurl" -O flashtool-${pkgver}-linux.tar.7z
    wget http://www.flashtool.net/torrents/patches/linux/x10flasher.jar
    [ ! -f x10flasher.jar ]&& echo "ERROR downloading PATCH file" && exit 3
    pacman -Q libselinux || ~/.fwul/install_package.sh yaourt libselinux
    makepkg -si
    #pacman -Q xperia-flashtool || ~/.fwul/install_package.sh yaourt xperia-flashtool
    sudo cp x10flasher.jar /usr/lib/xperia-flashtool/
fi

pacman -Q libselinux && pacman -Q xperia-flashtool && cp ~/.fwul/sonyflash.desktop ~/Desktop/ && chmod +x ~/Desktop/sonyflash.desktop && rm ~/Desktop/install-sonyflash.desktop

