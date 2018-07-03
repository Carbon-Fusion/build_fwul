#!/bin/bash
################################################################################################
# simple wrapper to install latest compatible TV version
################################################################################################
source /etc/fwul-release

[ -d /tmp/tv ] && rm -rf /tmp/tv
mkdir /tmp/tv && cd /tmp/tv \
  && wget http://leech.binbash.it:8008/FWUL/.repo/tv_fwul-v${fwulversion}.tar -O tv_fwul-v${fwulversion}.tar \
  && tar xf tv_fwul-v${fwulversion}.tar \
  && sudo pacman -U --noconfirm *.pkg.tar.xz \
  && sudo systemctl start teamviewerd \
  && cp /usr/share/applications/com.teamviewer.TeamViewer.desktop ~/Desktop/ \
  && chmod +x ~/Desktop/com.teamviewer.TeamViewer.desktop \
  && rm ~/Desktop/install-TV.desktop \
  && sudo systemctl enable teamviewerd

