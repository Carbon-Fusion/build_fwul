#!/bin/bash

sudo pacman --noconfirm -Sy
pacman -Q chromium || sudo $HOME/.fwul/install_package.sh pacman chromium
pacman -Q chromium && cp /usr/share/applications/chromium.desktop ~/Desktop/ && rm ~/Desktop/install-chromium.desktop && chmod +x ~/Desktop/chromium.desktop
