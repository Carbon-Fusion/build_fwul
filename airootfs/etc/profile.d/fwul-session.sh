#!/bin/bash
###########################################################################################
#
# X and terminal session starter for FWUL
#
###########################################################################################

######
# Language & Locale
LANGFILE="REPLACEHOME/.dmrc"

# extract, fix and export $LANG
TEMPLANG=$(cat "$LANGFILE" | grep ^Language= | cut -d '=' -f 2 | sed 's/utf8/UTF8/')
[ ! -z "$TEMPLANG" ] && export LANG=$TEMPLANG

# convert $LANG to $LANGUAGE and export
SETLAYOUT="$(echo $LANG | cut -d '@' -f 1 | cut -d '.' -f 1 | cut -d '_' -f 1)"

setxkbmap -layout $SETLAYOUT

# set global locale
DMLANG=$(cat "$LANGFILE" | grep ^Language= | cut -d '=' -f 2)
echo "LANG=$DMLANG" > /tmp/locale.conf
# set fallback language
echo "LANGUAGE=en_US.utf8" >> /tmp/locale.conf
sudo mv /tmp/locale.conf /etc/locale.conf

# detect FWUL mode
cp /etc/fwul-release /tmp
hostnamectl status |grep -v ID |tr -d " " | tr ":" "=" |sed 's/^/fwul_/g' >> /tmp/fwul-release
grep fwulversion /tmp/fwul-release >> /dev/null && sudo mv /tmp/fwul-release /etc/fwul-release

