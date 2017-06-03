#!/bin/bash

.fwul/install_package.sh yaourt teamviewer && sudo systemctl start teamviewerd && cp /usr/share/applications/com.teamviewer.TeamViewer.desktop ~/Desktop/ && chmod +x ~/Desktop/com.teamviewer.TeamViewer.desktop && rm ~/Desktop/install-TV.desktop
