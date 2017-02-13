#!/bin/bash

.fwul/install_package.sh yaourt spflashtool-bin
pacman -Q spflashtool-bin && cp /usr/share/applications/spflashtool.desktop ~/Desktop/ && chmod +x ~/Desktop/spflashtool.desktop  && rm ~/Desktop/install-spflash.desktop

