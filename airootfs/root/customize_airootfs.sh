#!/bin/bash
#######################################################################################################

set -e -u

# debug means e.g. SSH server will be added and enabled
# 1 means debug on, 0 off.
DEBUG=0

locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

usermod -s /bin/bash root
cp -aT /etc/skel/ /root/
chmod 700 /root

sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

# some vars
TMPSUDOERS=/etc/sudoers.d/build
RSUDOERS=/etc/sudoers.d/fwul
LOGINUSR=android
LOGINPW=linux
RPW=$LOGINPW

# set fake release info (get overwritten later)
echo "fwulversion=0.0" > /etc/fwul-release
echo "fwulbuild=0" >> /etc/fwul-release
echo "patchlevel=0" >> /etc/fwul-release

# current java version provided with FWUL (to save disk space compressed and not installed)
CURJAVA="jre-8u131-1-${arch}.pkg.tar.xz"
INSTJAVA="sudo pacman -U --noconfirm /home/$LOGINUSR/.fwul/jre-8u131-1-${arch}.pkg.tar.xz"

# add live user but ensure this happens when not there already
echo -e "\nuser setup:"
! id $LOGINUSR && useradd -m -p "" -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /bin/bash $LOGINUSR
id $LOGINUSR
passwd $LOGINUSR <<EOSETPW
$LOGINPW
$LOGINPW
EOSETPW

# prepare user home
cp -avT /etc/fwul/ /home/$LOGINUSR/
[ ! -d /home/$LOGINUSR/Desktop ] && mkdir /home/$LOGINUSR/Desktop
chmod 700 /home/$LOGINUSR

# temp perms for archiso
[ -f $RSUDOERS ]&& rm -vf $RSUDOERS      # ensures an update build will not fail
cat > $TMPSUDOERS <<EOSUDOERS
ALL     ALL=(ALL) NOPASSWD: ALL
EOSUDOERS

if [ $arch == "x86_64" ];then
    # init pacman + multilib
    # O M G ! This is so crappy bullshit! when build.sh see's 
    # the returncode 1 it just stops?!! so I use that funny workaround..
    RET=$(egrep -q '^\[multilib' /etc/pacman.conf||echo missing)
    if [ "$RET" == "missing" ];then
        echo "adding multilib to conf"
        cat >>/etc/pacman.conf<<EOPACMAN
[multilib]
SigLevel = PackageRequired
Include = /etc/pacman.d/mirrorlist
EOPACMAN
    else
        echo skipping multilib because it is configured already
    fi
else
    echo "SKIPPING multilib because of $arch"
fi

# adding antergos and arch32 mirrors
#RET=$(egrep -q '^\[antergos' /etc/pacman.conf||echo missing)
#if [ "$RET" == "missing" ];then
#    echo "adding custom mirrors to conf"
#    cat >>/etc/pacman.conf<<EOPACMAN
#[antergos]
#Include = /etc/pacman.d/fwul-mirrorlist
#EOPACMAN
#else
#    echo skipping antergos mirror because it is configured already
#fi

# initialize the needed keyrings (again)
haveged -w 1024
pacman-key --init
pacman-key --populate archlinux manjaro
pacman-key --refresh-keys
pacman -Syyu --noconfirm
# workaround until systemd is =>233
#pacman -Syu --noconfirm --ignore netctl

# install yaourt the hard way..
#RET=0
#pacman -Q package-query || RET=$?
#if [ $RET -ne 0 ];then
#    echo -e "\nyaourt:"
#    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz
#    tar -xvzf package-query.tar.gz
#    chown $LOGINUSR -R /package-query
#    cd package-query
#    su -c - $LOGINUSR "makepkg --noconfirm -sf"
#    pacman --noconfirm -U package-query*.pkg.tar.xz
#    cd ..
#    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz
#    tar -xvzf yaourt.tar.gz
#    chown $LOGINUSR -R yaourt
#    cd yaourt
#    su -c - $LOGINUSR "makepkg --noconfirm -sf"
#    pacman --noconfirm -U yaourt*.pkg.tar.xz
#    cd ..
#fi

# install yad
echo -e "\nyad:"
yaourt -Q yad || su -c - $LOGINUSR "yaourt -S --noconfirm yad"

# GUI based package manager
cp /usr/share/applications/pamac-manager.desktop /home/$LOGINUSR/Desktop/
sed -i 's/Icon=.*/Icon=gnome-software/g' /home/$LOGINUSR/Desktop/pamac-manager.desktop

# disable tray to avoid bothering users for updating
[ -f /etc/xdg/autostart/pamac-tray.desktop ] && rm /etc/xdg/autostart/pamac-tray.desktop

# minimal web browser
#yaourt -Q otter-browser || su -c - $LOGINUSR "yaourt -S --noconfirm otter-browser"
#yaourt -Q liri-browser-git || su -c - $LOGINUSR "yaourt -S --noconfirm liri-browser-git"
#yaourt -Q min || su -c - $LOGINUSR "yaourt -S --noconfirm min"

# prepare Samsung tool dir
[ ! -d /home/$LOGINUSR/Desktop/Samsung ] && mkdir /home/$LOGINUSR/Desktop/Samsung

# install udev-rules
[ ! -d /home/$LOGINUSR/.android ] && mkdir /home/$LOGINUSR/.android
[ ! -f /home/$LOGINUSR/.android/adb_usb.ini ] && wget https://raw.githubusercontent.com/M0Rf30/android-udev-rules/master/adb_usb.ini -O /home/$LOGINUSR/.android/adb_usb.ini

# always update the udev rules to be top current
wget https://raw.githubusercontent.com/M0Rf30/android-udev-rules/master/51-android.rules -O /etc/udev/rules.d/51-android.rules

# install & add Heimdall
echo -e "\nheimdall:"
yaourt -Q heimdall-git || su -c - $LOGINUSR "yaourt -S --noconfirm heimdall-git"
cp /usr/share/applications/heimdall.desktop /home/$LOGINUSR/Desktop/Samsung/
# fix missing heimdall icon
sed -i 's/Icon=.*/Icon=heimdall-frontend/g' /home/$LOGINUSR/Desktop/Samsung/heimdall.desktop

# install welcome screen
echo -e "\nwelcome-screen:"
if [ ! -d /home/$LOGINUSR/programs/welcome ];then
    git clone https://github.com/Carbon-Fusion/fwul_welcome.git /home/$LOGINUSR/programs/welcome
    # install the regular welcome screen
    if [ ! -f /home/$LOGINUSR/.config/autostart/welcome.desktop ];then
        [ ! -d /home/$LOGINUSR/.config/autostart ] && mkdir -p /home/$LOGINUSR/.config/autostart && chown -R $LOGINUSR /home/$LOGINUSR/.config/autostart
        cat > /home/$LOGINUSR/.config/autostart/welcome.desktop<<EOWAS
[Desktop Entry]
Version=1.0
Type=Application
Comment=FWUL Welcome Screen
Terminal=false
Name=Welcome
Exec=/home/$LOGINUSR/programs/welcome/welcome.sh
Icon=/home/$LOGINUSR/programs/welcome/icons/welcome.png
EOWAS
    fi
    # install the force welcome screen (when user manually want to start it)
    if [ ! -f /home/$LOGINUSR/Desktop/welcome.desktop ];then
        cat > /home/$LOGINUSR/Desktop/welcome.desktop <<EOWASF
[Desktop Entry]
Version=1.0
Type=Application
Comment=FWUL Welcome Screen
Terminal=false
Name=Welcome
Exec=/home/$LOGINUSR/programs/welcome/welcome-force.sh
Icon=/home/$LOGINUSR/programs/welcome/icons/welcome.png
EOWASF
    fi
    chmod +x /home/$LOGINUSR/.config/autostart/welcome.desktop /home/$LOGINUSR/Desktop/welcome.desktop
fi

# install JOdin3
if [ $arch == "x86_64" ];then
    if [ ! -d /home/$LOGINUSR/programs/JOdin ];then
        mkdir /home/$LOGINUSR/programs/JOdin
        cat >/home/$LOGINUSR/programs/JOdin/starter.sh <<EOEXECOD
#!/bin/bash
yaourt -Q jre || xterm -e "$INSTJAVA"
JAVA_HOME=/usr/lib/jvm/java-8-jre /home/$LOGINUSR/programs/JOdin/JOdin3CASUAL
EOEXECOD
        chmod +x /home/$LOGINUSR/programs/JOdin/starter.sh
        wget "https://forum.xda-developers.com/devdb/project/dl/?id=20803&task=get" -O JOdin.tgz
        tar -xzf JOdin.tgz -C /home/$LOGINUSR/programs/JOdin/ && rm -rf JOdin.tgz /home/$LOGINUSR/programs/JOdin/runtime
        cat >/home/$LOGINUSR/Desktop/Samsung/JOdin.desktop <<EOODIN
[Desktop Entry]
Version=1.0
Type=Application
Comment=Odin for Linux
Terminal=false
Name=JOdin3
Exec=/home/$LOGINUSR/programs/JOdin/starter.sh
Icon=/home/$LOGINUSR/.fwul/odin-logo.jpg
EOODIN
        chmod +x /home/$LOGINUSR/Desktop/Samsung/JOdin.desktop
    fi
else
    echo "SKIPPING JODIN INSTALL: Arch $arch detected!"
fi

# chromium installer
cat >/home/$LOGINUSR/Desktop/install-chromium.desktop <<EOsflashinst
[Desktop Entry]
Version=1.0
Type=Application
Comment=Chromium Browser Installer
Terminal=false
Name=Chromium installer
Exec=/home/$LOGINUSR/.fwul/install_chromium.sh
Icon=aptoncd
EOsflashinst
chmod +x /home/$LOGINUSR/Desktop/install-chromium.desktop

cat >/home/$LOGINUSR/.fwul/sonyflash.desktop <<EOsflash
[Desktop Entry]
Version=1.0
Type=Application
Comment=Sony FlashTool
Terminal=false
Name=Sony Flashtool
Exec=xperia-flashtool
Icon=/home/$LOGINUSR/.fwul/flashtool-icon.png
EOsflash

# teamviewer installer
echo -e "\nteamviewer:"
cat >/home/$LOGINUSR/Desktop/install-TV.desktop <<EOODIN
[Desktop Entry]
Version=1.0
Type=Application
Comment=Teamviewer installer
Terminal=false
Name=TeamViewer Installer
Exec=/home/$LOGINUSR/.fwul/install_tv.sh
Icon=aptoncd
EOODIN
chmod +x /home/$LOGINUSR/Desktop/install-TV.desktop

# even when there is an old/outdated version of spflashtool on an old website it is not possible to 
# get it working on 32bit
# http://spflashtool.org/download/SP_Flash_Tool_Linux_32Bit_v5.1520.00.100.zip <--- THIS CONTAINS 64bit BINARIES!!!
if [ $arch == "x86_64" ];then
    # SP Flash Tools installer
    echo -e "\nSP Flash Tools:"
    cat >/home/$LOGINUSR/Desktop/install-spflash.desktop <<EOSPF
[Desktop Entry]
Version=1.0
Type=Application
Comment=SP FlashTools installer
Terminal=false
Name=SP FlashTools Installer
Exec=/home/$LOGINUSR/.fwul/install_spflash.sh
Icon=aptoncd
EOSPF
    chmod +x /home/$LOGINUSR/Desktop/install-spflash.desktop
fi

# Sony Flash Tools installer
echo -e "\nSony Flash Tools:"
cat >/home/$LOGINUSR/Desktop/install-sonyflash.desktop <<EOSFT
[Desktop Entry]
Version=1.0
Type=Application
Comment=Sony FlashTools installer
Terminal=true
Name=Sony FlashTools Installer
Exec=/home/$LOGINUSR/.fwul/install_sonyflash.sh
Icon=aptoncd
EOSFT
chmod +x /home/$LOGINUSR/Desktop/install-sonyflash.desktop

# prepare LG tools
[ ! -d /home/$LOGINUSR/Desktop/LG ] && mkdir /home/$LOGINUSR/Desktop/LG/

[ ! -d /home/$LOGINUSR/programs/lglafng ] && git clone https://github.com/steadfasterX/lglaf.git /home/$LOGINUSR/programs/lglafng

# LG LAF shortcut with auth
echo -e "\nLG LAF shortcut with auth:"
cat >/home/$LOGINUSR/Desktop/LG/open-lglafauthshell.desktop <<EOSFT
[Desktop Entry]
Version=1.0
Type=Application
Comment=LG LAF shell with authentication challenge (for newer devices)
Terminal=false
Name=LG LAF (auth)
Exec=/home/$LOGINUSR/.fwul/lglaf.sh --unlock
Icon=terminal
EOSFT
chmod +x /home/$LOGINUSR/Desktop/LG/open-lglafauthshell.desktop

# LGLaf shortcut no auth
echo -e "\nLG LAF shortcut without auth:"
cat >/home/$LOGINUSR/Desktop/LG/open-lglafshell.desktop <<EOSFT
[Desktop Entry]
Version=1.0
Type=Application
Comment=LG LAF shell without authentication challenge (for older devices)
Terminal=false
Name=LG LAF (no auth)
Exec=/home/$LOGINUSR/.fwul/lglaf.sh
Icon=terminal
EOSFT
chmod +x /home/$LOGINUSR/Desktop/LG/open-lglafshell.desktop

# LGLAF NG 
echo -e "\nLG LAF NG shortcut:"
cat >/home/$LOGINUSR/Desktop/LG/open-lglafng.desktop <<EOLAFNG
[Desktop Entry]
Version=1.0
Type=Application
Comment=LG LAF shell NG
Terminal=true
Name=LG LAF - NG
Exec=xfce4-terminal --working-directory=/home/android/programs/lglafng
Icon=terminal
EOLAFNG

# install display manager
echo -e "\nDM:"
#yaourt -Q webkitgtk2 || su -c - $LOGINUSR "yaourt -S --noconfirm webkitgtk2"
#yaourt -Q mdm-display-manager || su -c - $LOGINUSR "yaourt -S --noconfirm mdm-display-manager"
systemctl enable lightdm

# configure login/display manager
#cp -v /home/$LOGINUSR/.fwul/mdm.conf /etc/mdm/custom.conf
cp -v /home/$LOGINUSR/.fwul/lightdm-gtk-greeter.conf /etc/lightdm/
# copy background + icon for greeter
cp -v /home/$LOGINUSR/.fwul/fwul_login.png /usr/share/pixmaps/greeter_background.png
cp -v  /home/$LOGINUSR/.fwul/greeter_icon.png /usr/share/pixmaps/

# Special things needed for easier DEBUGGING
if [ "$DEBUG" -eq 1 ];then
    pacman -Q openssh || pacman -S --noconfirm openssh
    systemctl enable sshd
    pacman -Q spice-vdagent || pacman -S --noconfirm spice-vdagent
    systemctl enable spice-vdagentd
fi

# add simple ADB 
# (https://forum.xda-developers.com/android/software/revive-simple-adb-tool-t3417155, https://github.com/mhashim6/Simple-ADB)
cat >/home/$LOGINUSR/Desktop/ADB.desktop <<EOSADB
[Desktop Entry]
Version=1.0
Type=Application
Comment=adb and fastboot GUI
Terminal=false
Name=Simple-ADB
Exec=/home/$LOGINUSR/programs/sadb/starter.sh
Icon=/home/$LOGINUSR/programs/sadb/sadb.jpg
EOSADB

cat >/home/$LOGINUSR/programs/sadb/starter.sh <<EOEXECADB
#!/bin/bash
yaourt -Q jre || xterm -e "$INSTJAVA"
java -jar /home/$LOGINUSR/programs/sadb/S-ADB.jar
EOEXECADB
chmod +x /home/$LOGINUSR/programs/sadb/starter.sh

# fix perms
# https://github.com/Carbon-Fusion/build_fwul/issues/58
chown -v root.root /usr
chmod -v 755 /usr
chown -v root.root /usr/share
chmod -v 755 /usr/share

# install FWUL LivePatcher
#https://github.com/Carbon-Fusion/build_fwul/issues/57
git clone https://github.com/steadfasterX/arch_fwulpatch-pkg.git /tmp/fwulpatch \
    && cd /tmp/fwulpatch \
    && chown $LOGINUSR /tmp/fwulpatch \
    && su -c - $LOGINUSR "makepkg -s" \
    && pacman --noconfirm -U fwulpatch-*.pkg.tar.xz
cd / 

# make all desktop files usable
chmod +x /home/$LOGINUSR/Desktop/*.desktop /home/$LOGINUSR/Desktop/*/*.desktop
chown -R $LOGINUSR /home/$LOGINUSR/Desktop/

# enable services
systemctl enable pacman-init.service choose-mirror.service
systemctl set-default graphical.target
systemctl enable systemd-networkd
systemctl enable NetworkManager
systemctl enable init-mirror

# prepare theming stuff
echo -e "\nThemes:"
[ -d /usr/share/mdm/themes/Arc-Wise/ ] || tar -xvzf /home/$LOGINUSR/.fwul/tmp/login-theme.tgz -C /
# windows 10 icons URL in AUR are broken..
#yaourt -Q windows10-icons || su -c - $LOGINUSR "yaourt -S --noconfirm windows10-icons"
#yaourt -Q windows10-icons || su -c - $LOGINUSR "yaourt --noconfirm -Pi ~/.fwul/tmp/win10icons/"
#rm /home/$LOGINUSR/.fwul/tmp/win10icons/*.xz
# install numix circle instead (minimal)
yaourt -Q numix-circle-icon-theme-git || su -c - $LOGINUSR "yaourt -S --noconfirm numix-circle-icon-theme-git"
rm -Rf /usr/share/icons/Numix-Circle-Light/
yaourt -Q gtk-theme-windows10-dark || su -c - $LOGINUSR "yaourt -S --noconfirm gtk-theme-windows10-dark"

# the hell of qtwebkit (required for SP flashtool ONLY)
# Even as a fallback this takes HOURS!
# as building for 32bit was not possible I use the precompiled i686 package from:
# https://sourceforge.net/projects/bluestarlinux/files/repo/i686/
TGZWK=/home/$LOGINUSR/.fwul/tmp/qtwebkit-*-${arch}.pkg.tar.xz
pacman -Q qtwebkit || pacman --noconfirm -U $TGZWK

# Create a MD5 for a given file or set to 0 if file is missing
F_DOMD5(){
    MFILE="$1"
    [ -z "$MFILE" ]&& echo "MISSING ARG FOR $FUNCNAME!" && exit 3
    if [ -f "$MFILE" ];then
        md5sum $MFILE | cut -d " " -f 1
    else
        echo 0
    fi
}

# wait until a file gets written or modified
F_FILEWAIT(){
    MD5C=$1
    FILE="$2"

    [ -z "$FILE" -o -z "$MD5C" ] && echo "MISSING ARG FOR $FUNCNAME!" && exit 3
    while true; do
        MD5NOW=$(F_DOMD5 "$FILE")
        if [ "$MD5C" != "$MD5NOW" ];then
            break
        else
            echo -e "\t.. waiting that the changes gets written for $FILE.."
            sleep 1s
        fi
    done
}

# ensure proper perms (have to be done BEFORE using any su LOGINUSER cmd which writes to home dir!)
chown -R ${LOGINUSR}.users /home/$LOGINUSR/

# activate wallpaper, icons & theme
echo -e "\nActivate theme etc:"
FWULDESKTOP="/home/$LOGINUSR/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
FWULXFWM4="/home/$LOGINUSR/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
FWULXSETS="/home/$LOGINUSR/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"

if [ ! -f "$FWULDESKTOP" ];then
    echo -e "\t... setting desktop wallpaper"
    MD5BEF=$(F_DOMD5 "$FWULDESKTOP")
    su -c - $LOGINUSR "dbus-launch xfconf-query --create -t string -c xfce4-desktop -s /home/$LOGINUSR/.fwul/wallpaper_fwul.png -p /backdrop/screen0/monitor0/workspace0/last-image"
    F_FILEWAIT $MD5BEF "$FWULDESKTOP"
    # stretch wallpaper
    MD5BEF=$(F_DOMD5 "$FWULDESKTOP")
    su -c - $LOGINUSR "dbus-launch xfconf-query --create -t int -c xfce4-desktop -s 3 -p /backdrop/screen0/monitor0/workspace0/image-style"
    F_FILEWAIT $MD5BEF "$FWULDESKTOP"
fi
if [ ! -f "$FWULXFWM4" ];then
    echo -e "\t... setting themes and icons 1"
    MD5BEF=$(F_DOMD5 "$FWULXFWM4")
    su -c - $LOGINUSR "dbus-launch xfconf-query --create -t string -c xfwm4 -p /general/theme -s Windows10Dark"
    F_FILEWAIT $MD5BEF "$FWULXFWM4"
fi
if [ ! -f "$FWULXSETS" ];then
    echo -e "\t... setting themes and icons 2"
    MD5BEF=$(F_DOMD5 "$FWULXSETS")
    su -c - $LOGINUSR "dbus-launch xfconf-query --create -t string -c xsettings -p /Net/ThemeName -s Windows10Dark"
    F_FILEWAIT $MD5BEF "$FWULXSETS"
    MD5BEF=$(F_DOMD5 "$FWULXSETS")
    su -c - $LOGINUSR "dbus-launch xfconf-query --create -t string -c xsettings -p /Net/IconThemeName -s Numix-Circle"
    F_FILEWAIT $MD5BEF "$FWULXSETS"
fi

# set aliases
echo -e '\n# FWUL aliases\nalias fastboot="sudo fastboot"\n' >> /home/$LOGINUSR/.bashrc

# hotfix until upstream fixed
# https://github.com/Carbon-Fusion/build_fwul/issues/56
bash /opt/fwul/patches/2-2-1_issue56.sh
cat /var/log/fwul/2-2-1_issue56.log

###############################################################################################################
#
# cleanup
#
###############################################################################################################
echo -e "\nCleanup - locale:"
for localeinuse in $(find /usr/share/locale/ -maxdepth 1 -type d |cut -d "/" -f5 );do 
    grep -q $localeinuse /etc/locale.gen || rm -rfv /usr/share/locale/$localeinuse
done
echo -e "\nCleanup - pacman:"
IGNPKG="adwaita-icon-theme lvm2 man-db man-pages mdadm nano netctl openresolv pcmciautils reiserfsprogs s-nail vi xfsprogs zsh memtest86+ caribou gnome-backgrounds gnome-themes-standard nemo telepathy-glib zeitgeist gnome-icon-theme webkit2gtk progsreiserfs testdisk"
for igpkg in $IGNPKG;do
    pacman -Q $igpkg && pacman --noconfirm -Rns -dd $igpkg
done

echo -e "\nCleanup - pacman orphans:"
PMERR=$(pacman --noconfirm -Rns $(pacman -Qtdq) || echo no pacman orphans)
echo -e "\nCleanup - yaourt orphans:"
YERR=$(su -c - $LOGINUSR "yaourt -Qtd --noconfirm" || echo no yaourt orphans)

echo -e "\nCleanup - manpages:"
rm -rvf /usr/share/man/*

echo -e "\nCleanup - docs:"
rm -rvf /usr/share/doc/* /usr/share/gtk-doc/html/*

echo -e "\nCleanup - misc:"
rm -rvf /*.tgz /*.tar.gz /yaourt/ /package-query/ /home/$LOGINUSR/.fwul/tmp/*

echo -e "\nCleanup - arch dependent:"
if [ $arch == "i686" ];then
    rm "/home/$LOGINUSR/.fwul/jre-8u131-1-x86_64.pkg.tar.xz"
else
    rm "/home/$LOGINUSR/.fwul/jre-8u131-1-i686.pkg.tar.xz"
fi

echo -e "\nCleanup - archiso:"
rm -rvf /etc/fwul

# persistent perms for fwul
cat > $RSUDOERS <<EOSUDOERS
%wheel     ALL=(ALL) ALL

# special rules for session & language
%wheel     ALL=(ALL) NOPASSWD: /bin/mount -o remount\,size=* /run/archiso/cowspace
%wheel     ALL=(ALL) NOPASSWD: /bin/umount -l /tmp
%wheel     ALL=(ALL) NOPASSWD: /bin/mv /var/tmp/* /tmp/
%wheel     ALL=(ALL) NOPASSWD: /bin/mv /tmp/locale.conf /etc/locale.conf

# let the user sync the databases without asking for pw
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/yaourt --noconfirm -Sy
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --noconfirm -Sy

# let the user install deps and compiled packages by yaourt without asking for pw
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -S --asdeps --needed --noconfirm *
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -U --asdeps --noconfirm *
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -U --noconfirm /tmp/yaourt-tmp-$LOGINUSR/PKGDEST*/*.pkg.tar.xz
%wheel     ALL=(ALL) NOPASSWD: /bin/cp -vf /tmp/yaourt-tmp-$LOGINUSR/PKGDEST*/*.pkg.tar.xz /var/cache/pacman/*

# when using fwul package installer no pw 
%wheel     ALL=(ALL) NOPASSWD: /home/$LOGINUSR/.fwul/install_package.sh *

# query file sizes without any prompt
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --print-format %s -S *

# special rules for TeamViewer
%wheel     ALL=(ALL) NOPASSWD: /bin/systemctl start teamviewerd
%wheel     ALL=(ALL) NOPASSWD: /bin/systemctl enable teamviewerd

# special rule for Sony Flashtool
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/yaourt --noconfirm -S xperia-flashtool
%wheel     ALL=(ALL) NOPASSWD: /bin/cp x10flasher.jar /usr/lib/xperia-flashtool/
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --noconfirm -U /tmp/arch_xperia-flashtool/xperia-flashtool*.pkg.tar.xz

# special rule for SP Flashtool
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/yaourt --noconfirm -S spflashtool-bin

# special rule for JAVA
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman -U --noconfirm /home/$LOGINUSR/.fwul/$CURJAVA

# special rule for fastboot
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/fastboot *
EOSUDOERS

# set root password
passwd root <<EOSETPWROOTPW
$RPW
$RPW
EOSETPWROOTPW

# set real release info
echo "fwulversion=$iso_version" > /etc/fwul-release
echo "fwulbuild=$(date +%s)" >> /etc/fwul-release
echo "patchlevel=0" >> /etc/fwul-release

# fix perms (again)
# https://github.com/Carbon-Fusion/build_fwul/issues/58
chown -v root.root /usr
chmod -v 755 /usr
chown -v root.root /usr/share
chmod -v 755 /usr/share

########################################################################################
# TEST AREA - TEST AREA - TEST AREA 

echo -e "\nTESTING FWUL BUILD!"

# arch independent requirements
REQFILES="/home/$LOGINUSR/.fwul/wallpaper_fwul.png 
$FWULDESKTOP
$FWULXFWM4
$FWULXSETS
$RSUDOERS
/usr/share/mdm/themes/Arc-Wise/MdmGreeterTheme.desktop
/home/$LOGINUSR/Desktop/ADB.desktop
/home/$LOGINUSR/programs/sadb/starter.sh
/home/$LOGINUSR/programs/sadb/S-ADB.jar
/home/$LOGINUSR/Desktop/Samsung/heimdall.desktop
/home/$LOGINUSR/Desktop/install-TV.desktop
/usr/bin/adb
/usr/bin/fastboot
/usr/bin/heimdall
/usr/bin/yaourt
/home/$LOGINUSR/.fwul/odin-logo.jpg
/home/$LOGINUSR/.fwul/install_spflash.sh
/home/$LOGINUSR/.fwul/install_sonyflash.sh
/home/$LOGINUSR/Desktop/install-sonyflash.desktop
/usr/share/icons/Numix-Circle/index.theme
/home/$LOGINUSR/.android/adb_usb.ini
/etc/udev/rules.d/51-android.rules
/home/$LOGINUSR/programs/welcome/welcome.sh
/home/$LOGINUSR/programs/welcome/icons/welcome.png
/home/$LOGINUSR/.config/autostart/welcome.desktop
/etc/profile.d/fwul-session.sh
/etc/systemd/system/init-mirror.service
/etc/systemd/scripts/init-fwul
/home/$LOGINUSR/Desktop/welcome.desktop
/etc/fwul-release
/usr/local/bin/livepatcher.sh
/usr/local/bin/liveupdater.sh
/var/lib/fwul/generic.vars
/var/lib/fwul/generic.func
/home/$LOGINUSR/.config/xfce4/desktop/icons.screen0.rc
/home/$LOGINUSR/.fwul/$CURJAVA"

# 32bit requirements (extend with 32bit ONLY.
# If the test is the same for both arch use REQFILES instead)
REQFILES_i686="$REQFILES"

# 64bit requirements (extend with 64bit ONLY. 
# If the test is the same for both arch use REQFILES instead)
REQFILES_x86_64="$REQFILES
/home/$LOGINUSR/Desktop/install-spflash.desktop
/home/$LOGINUSR/Desktop/Samsung/JOdin.desktop
/home/$LOGINUSR/programs/JOdin/starter.sh
/home/$LOGINUSR/programs/JOdin/JOdin3CASUAL"


CURREQ="REQFILES_${arch}"

for req in $(echo -e "${!CURREQ}"|tr "\n" " ");do
    if [ -f "$req" ];then
        echo -e "\t... testing ($arch): $req --> OK"
    else
        echo -e "\t******************************************************************************"
        echo -e "\tERROR: testing ($arch) $req --> FAILED!!"
        echo -e "\t******************************************************************************"
        exit 3
    fi
done

# add a warning when debugging is enabled
if [ "$DEBUG" -eq 1 ];then
        echo -e "\t******************************************************************************"
        echo -e "\tWARNING: DEBUG MODE ENABLED !!!"
        echo -e "\t******************************************************************************"
fi

# TEST AREA - END
########################################################################################

# list the biggest packages installed
pacman --noconfirm -S expac
expac -H M -s "%-30n %m" | sort -rhk 2 | head -n 40
pacman --noconfirm -Rns expac

# create a XDA copy template for the important FWUL package versions
echo -ne '[*]Versions of the main FWUL components:\n[INDENT]ADB and fastboot: '
pacman -Q android-tools | sed 's/ / -> [B]version: /g;s/$/[\/B]/g'
echo -e 'simple-adb GUI -> [B]version: update4[\/B]'
CHLOG="heimdall-git xfwm4 lightdm xorg-server virtualbox-guest-utils firefox hexchat"
for i in $CHLOG;do
        pacman -Q $i | sed 's/ / -> [B]version: /g;s/$/[\/B]/g'
done
echo -e '[/INDENT]'

#########################################################################################
# this has always to be the very last thing!
rm -vf $TMPSUDOERS
