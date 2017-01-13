#!/bin/bash
#######################################################################################################

set -e -u

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
cp -aT /etc/fwul/ /home/android/
chmod 700 /home/android

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
pacman -Q package-query || RET=$?
if [ $RET -ne 0 ];then
    echo -e "\nyaourt:"
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz
    tar -xvzf package-query.tar.gz
    chown android -R /package-query
    cd package-query
    su -c - android "makepkg --noconfirm -sf"
    pacman --noconfirm -U package-query*.pkg.tar.xz
    cd ..
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz
    tar -xvzf yaourt.tar.gz
    chown android -R yaourt
    cd yaourt
    su -c - android "makepkg --noconfirm -sf"
    pacman --noconfirm -U yaourt*.pkg.tar.xz
    cd ..
fi

# install Oracle JRE (because JOdin will not run with OpenJDK)
yaourt -Q jre || su -c - android "yaourt -S --noconfirm jre"

# install JOdin3
if [ ! -d /home/$LOGINUSR/programs/JOdin ];then
    mkdir /home/$LOGINUSR/programs/JOdin
    cat >/home/$LOGINUSR/programs/JOdin/starter.sh <<EOEXECOD
#!/bin/bash
JAVA_HOME=/usr/lib/jvm/java-8-jre /home/$LOGINUSR/programs/JOdin/JOdin3CASUAL
EOEXECOD
    chmod +x /home/$LOGINUSR/programs/JOdin/starter.sh
    wget "https://forum.xda-developers.com/devdb/project/dl/?id=20803&task=get"
    mv index*get JOdin.tgz && tar -xvzf JOdin.tgz* -C /home/android/programs/JOdin/ && rm -rf JOdin.tgz /home/android/programs/JOdin/runtime
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

# install yad
echo -e "\nyad:"
yaourt -Q yad || su -c - android "yaourt -S --noconfirm yad"

# install teamviewer
#echo -e "\nteamviewer:"
#yaourt -Q teamviewer || su -c - android "yaourt -S --noconfirm teamviewer"
cat >/home/$LOGINUSR/Desktop/install-TV.desktop <<EOODIN
[Desktop Entry]
Version=1.0
Type=Application
Comment=Teamviewer installer
Terminal=false
Name=TeamViewer Installer
Exec=/home/$LOGINUSR/.fwul/install_package.sh yaourt teamviewer
Icon=preferences-desktop-default-applications
EOODIN
chmod +x /home/$LOGINUSR/Desktop/install-TV.desktop

# install display manager
echo -e "\nDM:"
yaourt -Q mdm-display-manager || su -c - android "yaourt -S --noconfirm mdm-display-manager"
systemctl enable mdm

# configure display manager
cp -v /home/$LOGINUSR/.fwul/mdm.conf /etc/mdm/custom.conf

# DEBUGGING
pacman -Q openssh || pacman -S --noconfirm openssh
systemctl enable sshd


# enable services
systemctl enable pacman-init.service choose-mirror.service
systemctl set-default graphical.target
systemctl enable systemd-networkd
systemctl enable NetworkManager

# theming stuff
yaourt -Q windows10-icons || su -c - android "yaourt -S --noconfirm windows10-icons"
#yaourt -Q gtk-theme-windows10-dark || su -c - android "yaourt -S --noconfirm gtk-theme-windows10-dark"
yaourt -Q || su -c - android "yaourt -S --noconfirm mdmodern-mdm-theme-git"

# ensure proper perms
chown -R android /home/android/

# cleanup
echo -e "\nCleanup - locale:"
for localeinuse in $(find /usr/share/locale/ -maxdepth 1 -type d |cut -d "/" -f5 );do 
    grep -q $localeinuse /etc/locale.gen || rm -rfv /usr/share/locale/$localeinuse
done
echo -e "\nCleanup - pacman:"
IGNPKG="cryptsetup lvm2 man-db man-pages mdadm nano netctl openresolv pcmciautils reiserfsprogs s-nail vi xfsprogs zsh memtest86+ caribou gnome-backgrounds gnome-themes-standard nemo"
for igpkg in $IGNPKG;do
    pacman -Q $igpkg && pacman --noconfirm -Rns -dd $igpkg
done

echo -e "\nCleanup - pacman orphans:"
PMERR=$(pacman --noconfirm -Rns $(pacman -Qtdq) || echo no pacman orphans)
echo -e "\nCleanup - yaourt orphans:"
YERR=$(su -c - android "yaourt -Qtd --noconfirm" || echo no yaourt orphans)

echo -e "\nCleanup - manpages:"
rm -rvf /usr/share/man/*

echo -e "\nCleanup - docs:"
rm -rvf /usr/share/doc/*

echo -e "\nCleanup - misc:"
rm -rvf /*.tgz /*.tar.gz /yaourt/ /package-query/

# persistent perms for fwul
cat > $RSUDOERS <<EOSUDOERS
%wheel     ALL=(ALL) ALL
%wheel     ALL=(ALL) NOPASSWD: /bin/mount -o remount\,size=* /run/archiso/cowspace
EOSUDOERS

# set root password
passwd root <<EOSETPWROOTPW
$RPW
$RPW
EOSETPWROOTPW
#########################################################################################
# this has always to be the very last thing!
rm -vf $TMPSUDOERS
