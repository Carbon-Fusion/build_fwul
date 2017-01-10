#!/bin/bash
SETLAYOUT=$(locale |grep LANG=|cut -d "=" -f 2 |cut -d "_" -f 1)
SETLANG=$(locale |grep LANG=)

setxkbmap -layout $SETLAYOUT
echo "$SETLANG" > /etc/locale.conf

