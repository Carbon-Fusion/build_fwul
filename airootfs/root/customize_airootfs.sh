#!/bin/bash
#######################################################################################################

set -e -u

# debug means e.g. SSH server will be added and enabled
# 1 means debug on, 0 off.
DEBUG=1

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

# add live user but ensure this happens when not there already
echo -e "\nuser setup:"
! id $LOGINUSR && useradd -m -p "" -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /bin/bash $LOGINUSR
id $LOGINUSR
passwd $LOGINUSR <<EOSETPW
$LOGINPW
$LOGINPW
EOSETPW

# prepare user home
cp -aT /etc/fwul/ /home/$LOGINUSR/
chmod 700 /home/$LOGINUSR

# temp perms for archiso
[ -f $RSUDOERS ]&& rm -vf $RSUDOERS      # ensures an update build will not fail
cat > $TMPSUDOERS <<EOSUDOERS
ALL     ALL=(ALL) NOPASSWD: ALL
EOSUDOERS

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
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

# install yaourt the hard way..
RET=0
pacman -Q package-query || RET=$?
if [ $RET -ne 0 ];then
    echo -e "\nyaourt:"
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz
    tar -xvzf package-query.tar.gz
    chown $LOGINUSR -R /package-query
    cd package-query
    su -c - $LOGINUSR "makepkg --noconfirm -sf"
    pacman --noconfirm -U package-query*.pkg.tar.xz
    cd ..
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz
    tar -xvzf yaourt.tar.gz
    chown $LOGINUSR -R yaourt
    cd yaourt
    su -c - $LOGINUSR "makepkg --noconfirm -sf"
    pacman --noconfirm -U yaourt*.pkg.tar.xz
    cd ..
fi

# install Oracle JRE (because JOdin will not run with OpenJDK)
yaourt -Q jre || su -c - $LOGINUSR "yaourt -S --noconfirm jre"

# install yad
echo -e "\nyad:"
yaourt -Q yad || su -c - $LOGINUSR "yaourt -S --noconfirm yad"

# install JOdin3
if [ ! -d /home/$LOGINUSR/programs/JOdin ];then
    mkdir /home/$LOGINUSR/programs/JOdin
    cat >/home/$LOGINUSR/programs/JOdin/starter.sh <<EOEXECOD
#!/bin/bash
JAVA_HOME=/usr/lib/jvm/java-8-jre /home/$LOGINUSR/programs/JOdin/JOdin3CASUAL
EOEXECOD
    chmod +x /home/$LOGINUSR/programs/JOdin/starter.sh
    wget "https://forum.xda-developers.com/devdb/project/dl/?id=20803&task=get"
    mv index*get JOdin.tgz && tar -xvzf JOdin.tgz* -C /home/$LOGINUSR/programs/JOdin/ && rm -rf JOdin.tgz /home/$LOGINUSR/programs/JOdin/runtime
    cat >/home/$LOGINUSR/Desktop/JOdin.desktop <<EOODIN
[Desktop Entry]
Version=1.0
Type=Application
Comment=Odin for Linux
Terminal=false
Name=JOdin3
Exec=/home/$LOGINUSR/programs/JOdin/starter.sh
Icon=/home/$LOGINUSR/.fwul/odin-logo.jpg
EOODIN
chmod +x /home/$LOGINUSR/Desktop/JOdin.desktop
fi

# sony flashtools installer
cat >/home/$LOGINUSR/Desktop/install-sonyflash.desktop <<EOsflashinst
[Desktop Entry]
Version=1.0
Type=Application
Comment=Sony FlashTool Installer
Terminal=false
Name=Sony Flashtool Installer
Exec=/home/$LOGINUSR/.fwul/install_sonyflash.sh
Icon=aptoncd
EOsflashinst
chmod +x /home/$LOGINUSR/Desktop/install-sonyflash.desktop

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

# Sony Flash Tools installer
echo -e "\nSony Flash Tools:"
cat >/home/$LOGINUSR/Desktop/install-sonyflash.desktop <<EOSFT
[Desktop Entry]
Version=1.0
Type=Application
Comment=Sony FlashTools installer
Terminal=false
Name=Sony FlashTools Installer
Exec=/home/$LOGINUSR/.fwul/install_sonyflash.sh
Icon=aptoncd
EOSFT
chmod +x /home/$LOGINUSR/Desktop/install-sonyflash.desktop

# install display manager
echo -e "\nDM:"
yaourt -Q mdm-display-manager || su -c - $LOGINUSR "yaourt -S --noconfirm mdm-display-manager"
systemctl enable mdm

# configure display manager
cp -v /home/$LOGINUSR/.fwul/mdm.conf /etc/mdm/custom.conf

# Special things needed for easier DEBUGGING
if [ "$DEBUG" -eq 1 ];then
    pacman -Q openssh || pacman -S --noconfirm openssh
    systemctl enable sshd
    pacman -Q spice-vdagent || pacman -S --noconfirm spice-vdagent
    systemctl enable spice-vdagentd
fi

# add Heimdall
cp /usr/share/applications/heimdall.desktop /home/$LOGINUSR/Desktop/

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
java -jar /home/$LOGINUSR/programs/sadb/S-ADB.jar
EOEXECADB
chmod +x /home/$LOGINUSR/programs/sadb/starter.sh

# make all desktop files usable
chmod +x /home/$LOGINUSR/Desktop/*.desktop
chown -R $LOGINUSR /home/$LOGINUSR/Desktop/

# enable services
systemctl enable pacman-init.service choose-mirror.service
systemctl set-default graphical.target
systemctl enable systemd-networkd
systemctl enable NetworkManager

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

# adding qtwebkit as it takes VERY i mean VERY ! long to compile..
TGZWK=/home/$LOGINUSR/.fwul/tmp/qtwebkit-*.pkg.tar.xz
pacman --noconfirm -U $TGZWK && rm $TGZWK

# Even as a fallback this takes hours!
# yaourt -Q qtwebkit || su -c - $LOGINUSR "yaourt -S --noconfirm qtwebkit"

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

# ensure proper perms
chown -R $LOGINUSR /home/$LOGINUSR/

# cleanup
echo -e "\nCleanup - locale:"
for localeinuse in $(find /usr/share/locale/ -maxdepth 1 -type d |cut -d "/" -f5 );do 
    grep -q $localeinuse /etc/locale.gen || rm -rfv /usr/share/locale/$localeinuse
done
echo -e "\nCleanup - pacman:"
IGNPKG="adwaita-icon-theme cryptsetup lvm2 man-db man-pages mdadm nano netctl openresolv pcmciautils reiserfsprogs s-nail vi xfsprogs zsh memtest86+ caribou gnome-backgrounds gnome-themes-standard nemo"
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

echo -e "\nCleanup - archiso:"
rm -rvf /etc/fwul

# persistent perms for fwul
cat > $RSUDOERS <<EOSUDOERS
%wheel     ALL=(ALL) ALL
%wheel     ALL=(ALL) NOPASSWD: /bin/mount -o remount\,size=* /run/archiso/cowspace

# let the user sync the databases without asking for pw
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/yaourt --noconfirm -Sy
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --noconfirm -Sy

# special rules for TeamViewer
%wheel     ALL=(ALL) NOPASSWD: /bin/systemctl start teamviewerd
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -S --asdeps --needed --noconfirm multilib/lib32-libjpeg6-turbo multilib/lib32-libxinerama multilib/lib32-libxrender multilib/lib32-fontconfig multilib/lib32-libsm multilib/lib32-libxtst multilib/lib32-libpng12
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -U --noconfirm /tmp/yaourt-tmp-$LOGINUSR/PKGDEST*/teamviewer*.pkg.tar.xz

# special rule for Sony Flashtool
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/yaourt --noconfirm -S xperia-flashtool
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -U --asdeps --noconfirm /tmp/yaourt-tmp-$LOGINUSR/PKGDEST*/libse*.pkg.tar.xz
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -U --noconfirm /tmp/yaourt-tmp-$LOGINUSR/PKGDEST*/xperia-flashtool-*.pkg.tar.xz
%wheel     ALL=(ALL) NOPASSWD: /bin/cp /home/$LOGINUSR/.fwul/x10flasher.jar /usr/lib/xperia-flashtool/

# special rule for SP Flashtool
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/yaourt --noconfirm -S spflashtool-bin
%wheel     ALL=(ALL) NOPASSWD: /usr/bin/pacman --color auto -U --noconfirm /tmp/yaourt-tmp-$LOGINUSR/PKGDEST*/spflashtool-bin-*.pkg.tar.xz
EOSUDOERS

# set root password
passwd root <<EOSETPWROOTPW
$RPW
$RPW
EOSETPWROOTPW

########################################################################################
# TEST AREA - TEST AREA - TEST AREA 

echo -e "\nTESTING FWUL BUILD!"
REQFILES="/home/$LOGINUSR/.fwul/wallpaper_fwul.png 
$FWULDESKTOP
$FWULXFWM4
$FWULXSETS
$RSUDOERS
/usr/share/mdm/themes/Arc-Wise/MdmGreeterTheme.desktop
/home/$LOGINUSR/Desktop/ADB.desktop
/home/$LOGINUSR/programs/sadb/starter.sh
/home/$LOGINUSR/programs/sadb/S-ADB.jar
/home/$LOGINUSR/Desktop/heimdall.desktop
/home/$LOGINUSR/Desktop/install-TV.desktop
/usr/bin/adb
/usr/bin/fastboot
/usr/bin/yaourt
/home/$LOGINUSR/Desktop/JOdin.desktop
/home/$LOGINUSR/.fwul/odin-logo.jpg
/home/$LOGINUSR/programs/JOdin/starter.sh
/home/$LOGINUSR/programs/JOdin/JOdin3CASUAL
/home/$LOGINUSR/.fwul/install_spflash.sh
/home/$LOGINUSR/Desktop/install-spflash.desktop
/home/$LOGINUSR/.fwul/install_sonyflash.sh
/home/$LOGINUSR/Desktop/install-sonyflash.desktop
/usr/share/icons/Numix-Circle/index.theme
/usr/lib/jvm/java-8-jre/jre/bin/java"

for req in $(echo -e "$REQFILES"|tr "\n" " ");do
    if [ -f "$req" ];then 
        echo -e "\t... testing: $req --> OK"
    else
        echo -e "\t******************************************************************************"
        echo -e "\tERROR: testing $req --> FAILED!!"
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
expac -H M -s "%-30n %m" | sort -rhk 2 | head -n 30
pacman --noconfirm -Rns expac

#########################################################################################
# this has always to be the very last thing!
rm -vf $TMPSUDOERS
