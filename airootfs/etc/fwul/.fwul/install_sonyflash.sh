#!/bin/bash

.fwul/install_package.sh yaourt xperia-flashtool \
    && sudo mv ~/.fwul/x10flasher.jar /usr/lib/xperia-flashtool/ \
    && cp ~/.fwul/sonyflash.desktop ~/Desktop/ \
    && chmod +x ~/Desktop/sonyflash.desktop \
    && rm ~/Desktop/install-sonyflash.desktop

