#!/bin/bash
#######################################################################################################

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

usermod -s /usr/bin/zsh root
cp -aT /etc/skel/ /root/
chmod 700 /root

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

# some vars
TMPSUDOERS=/etc/sudoers.d/build
LOGINUSR=android
LOGINPW=linux

# add live user but ensure this happens when not there already
echo -e "\nuser setup:"
! id $LOGINUSR && useradd -m -p "" -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /usr/bin/zsh $LOGINUSR
id $LOGINUSR
passwd $LOGINUSR <<EOSETPW
$LOGINPW
$LOGINPW
EOSETPW

# temp perms for archiso
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

# install teamviewer
echo -e "\nteamviewer:"
su -c - android "yaourt -S --noconfirm teamviewer"

# install display manager
echo -e "\nDM:"
su -c - android "yaourt -S --noconfirm mdm-display-manager"
systemctl enable mdm

systemctl enable pacman-init.service choose-mirror.service
systemctl set-default graphical.target

# cleanup
rm -vf $TMPSUDOERS

