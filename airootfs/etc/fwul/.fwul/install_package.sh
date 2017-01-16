#!/bin/bash
###############################################################################################################
#
# Generic grahical installer which can be triggered by CLI
#
###############################################################################################################

YBIN=/usr/bin/yad

PMAN="$1"       # installer (e.g pacman or yaourt)
PKG="$2"        # package name to install

YAD="$YBIN --center --top --title FWUL-Installer --window-icon=preferences-desktop-default-applications"

[ -z "$PMAN" ]&& echo "missing package manager variable! ABORT" && read -p "PRESS ANY KEY TO QUIT" DUMMY && exit
[ -z "$PKG" ]&& echo "missing package name to install! ABORT" && read -p "PRESS ANY KEY TO QUIT" DUMMY && exit
[ ! -f "$YBIN" ]&& echo "missing yad dependency! ABORT" && read -p "PRESS ANY KEY TO QUIT" DUMMY && exit

# depending on the package manager we need to start it as root or not
if [ "$PMAN" == "pacman" ];then
    PMANEXEC="sudo pacman"
else
    PMANEXEC="$PMAN"
fi

$YAD --width 300 --height 100 --form --text "\nThis will start the installation of $PKG!\nRequires a working Internet connection ;-)"

# do the magic
if [ $? -eq 0 ];then
    [ -f "/tmp/install-$PKG-failed" ]&&rm -f /tmp/install-$PKG-failed
    PREPRG="/tmp/progress.tmp"
    # start a progress bar to give some user feedback
    tail -f $PREPRG | $YAD --width=300 --progress --percentage=10 --auto-close &
    # install the package
    xterm -e "$PMANEXEC --noconfirm -Sy"
    xterm -e "$PMANEXEC -S --noconfirm $PKG||>/tmp/install-$PKG-failed"
    echo 100 > $PREPRG
    # check if it was a success or not
    if [ -f "/tmp/install-$PKG-failed" ];then
        $YAD --width 300 --height 100 --form --text "\n\tERROR occured while installing $PKG."
    else
        $YAD --width 300 --height 100 --form --text "\n\t$PKG installed successfully."
    fi
fi

