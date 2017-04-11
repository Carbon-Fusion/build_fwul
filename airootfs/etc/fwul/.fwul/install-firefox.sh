#!/bin/bash

sudo pacman --noconfirm -Sy
pacman -Q firefox || ~/.fwul/install_package.sh pacman firefox
cp /usr/share/applications/firefox.desktop ~/Desktop/ && rm ~/Desktop/install-firefox.desktop && chmod +x ~/Desktop/firefox.desktop

