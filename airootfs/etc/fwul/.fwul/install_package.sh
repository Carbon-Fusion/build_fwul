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
    PMANEXEC="pacman"
else
    PMANEXEC="sudo -u $SUDO_USER $PMAN"
fi

# check for space requirements and warn!
F_CHKSPACE(){
    TARGET="$1"
    for dep in $($PMANEXEC --print-format %s -S $TARGET);do
        TARGETSIZE=$((TARGETSIZE + $dep))
    done

    TARGETSPACE=$((TARGETSIZE/1024/1024))
    AVAILSPACEK=$(df -k --output=avail / |tr -d " " |egrep "[0-9]")
    AVAILSPACE=$((AVAILSPACEK/1024))

    # some packages in AUR do not report their installed size (shame on them!)
    # this has to be checked and warned
    if [ $TARGETSPACE -eq 0 ];then
        $YAD --image=dialog-warning --width 800 --fixed --height 180 --button=Abort:99 --button="Continue installation":0 --form --text "\n\tOops cannot determine installation size (some packages simply does not report them before installing)!\n\n\tYour available disk space: <b>$AVAILSPACE MB</b>!\n\tIf you encounter problems it is maybe related!"
        [ $? -eq 99 ] && echo 99 && exit
    fi

    # compare it
    if [ "$TARGETSPACE" -ge "$AVAILSPACE" ];then
        echo "$TARGETSPACE"
    else
        echo 0
    fi
}

$YAD --image=aptoncd --text-align=center --width 380 --height 50 --form --text "Continuing will start the installation of:\n\n<span color=\"green\">$PKG</span>\n<i>(this requires a working Internet connection)</i>\n\n<span color=\"red\">Watch the console window:</span>\nYou may have to type in the <u>password</u> of the user <b>$USER</b> to confirm the installation!\n\nYou may see a warning like:\n<i><span color=\"red\">Unsupported package: Potentially dangerous</span></i>\n\nThat is expected and you have to continue to complete the installation."

# do the magic
if [ $? -eq 0 ];then
    [ -f "/tmp/install-$PKG-success" ]&&rm -f /tmp/install-$PKG-failed
    PREPRG="/tmp/progress.tmp"
    # start a progress bar to give some user feedback
    tail -f $PREPRG | $YAD --width=300 --progress --percentage=10 --auto-close &
    # install the package
    xterm -e "$PMAN --noconfirm -Sy"
    PRECHK=$(F_CHKSPACE "$PKG")
    if [ "$PRECHK" -eq 0 ];then
        xterm -e "$PMANEXEC -S --noconfirm $PKG && >/tmp/install-$PKG-success"
    else
        [ "$PRECHK" -eq 99 ] && exit 3
        $YAD --image=error --width 800 --fixed --height 180 --button=Abort --form --text "\n\tERROR not enough disk space!\n\n\tInstalling $PKG requires at least: <b>$PRECHK MB</b>!\n\tYou either need more RAM or use an USB device and boot FWUL in persistent mode!"
        exit 9
    fi

    echo 100 > $PREPRG
    # check if it was a success or not
    if [ -f "/tmp/install-$PKG-success" ];then
        $YAD --width 300 --height 100 --form --text "\n\t$PKG installed successfully."
    else
        $YAD --image=error --width 600 --height 100 --form --text "\n\tERROR occured while installing:\n\t$PKG."
    fi
fi

