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

# add live user but ensure this happens when not there already
echo -e "\nuser setup:"
! id android && useradd -m -p "linux" -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /usr/bin/bash android
id android
passwd android <<EOSETPW
linux
linux
EOSETPW

cat >/etc/sudoers.d/build<<EOSUDOERS
ALL     ALL=(ALL) NOPASSWD: ALL
EOSUDOERS

# install yaourt
echo -e "\nyaourt:"
pacman-key --init
pacman-key --populate archlinux
pacman -Syu
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
su -c - android "yaourt --noconfirm -G teamviewer"
chown android -R /teamviewer
cd teamviewer
su -c - android "makepkg --noconfirm -sf"
pacman --noconfirm -U teamviewer*.pkg.tar.xz
cd ..

# enable lxdm
systemctl enable lxdm

systemctl enable pacman-init.service choose-mirror.service
#systemctl set-default multi-user.target
systemctl set-default graphical.target
