#!/bin/bash
################################################################################################
# simple wrapper to install latest compatible TV version
################################################################################################
source /etc/fwul-release

PKEXEC_USR=$(id -un $PKEXEC_UID)

[ -d /tmp/tv ] && rm -rf /tmp/tv
mkdir /tmp/tv && cd /tmp/tv \
  && wget http://leech.binbash.it:8008/FWUL/.repo/tv_fwul-v${fwulversion}.tar -O tv_fwul-v${fwulversion}.tar \
  && tar xf tv_fwul-v${fwulversion}.tar \
  && pacman -U --noconfirm *.pkg.tar.xz \
  && cd /tmp/ && rm -rf /tmp/tv \
  && systemctl start teamviewerd \
  && cp /usr/share/applications/com.teamviewer.TeamViewer.desktop /home/$PKEXEC_USR/Desktop/ \
  && chmod +x /home/$PKEXEC_USR/Desktop/com.teamviewer.TeamViewer.desktop \
  && chown $PKEXEC_USR /home/$PKEXEC_USR/Desktop/com.teamviewer.TeamViewer.desktop \
  && rm /home/$PKEXEC_USR/Desktop/install-TV.desktop \
  && systemctl enable teamviewerd

