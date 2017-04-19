#!/bin/bash
###########################################################################################

args="$@"
yad --title="LG-LAF" --center --width=500 --height=100 --nobuttons --button=Abort:99 --button=Continue:1 --text "\n\n\tEnter Download Mode on your LG and connect it to this PC.\n\tThen click on continue.\n\n"
[ $? -eq 1 ] && xfce4-terminal --working-directory="~/programs/lglaf/" -e "/usr/bin/python2 lglaf.py $args"
