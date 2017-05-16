#!/bin/bash

set -e -u

iso_name=FWUL_
iso_label="FWUL"
install_dir=arch
work_dir=../fwul-work
out_dir=../fwul-out
gpg_key=
PUBLISHER="Carbon-Fusion <https://github.com/Carbon-Fusion>"
persistent=no
SILENT=no

# default arch to build for
ARCH='i686 x86_64'

# the default value for available space in MB on a persistent target (e.g. the full space u want to use on a USB stick)
# can be overwritten by -U
USBSIZEMB=4000

arch=$(uname -m)
export arch=$arch
export iso_version="$(date +%Y-%m-%d_%H-%M)"

verbose=""
script_path=$(readlink -f ${0%/*})

_usage ()
{
    echo "usage ${0} [options]"
    echo
    echo "Cleaning options:"
    echo 
    echo "    -C                 Enforce a rebuild by cleaning lock files"
    echo "                       (will keep ISO base)"
    echo "    -F                 Enforce a FULL(!) clean (implies -C)"
    echo "                       (will delete the whole ISO base)"
    echo "    -c                 Enforce a re-run of customize script ONLY"
    echo "                       (this is just useful for debugging purposes"
    echo "                       of airootfs/root/customize_airootfs.sh"
    echo "                       because it will NOT re-create the ISO)"
    echo 
    echo "******************************************************************"
    echo 
    echo " Persistent mode options:"
    echo 
    echo "    -P                 Creates a persistent ISO with a defined USB disk space"
    echo "                        Default (if -U is not specified): $USBSIZEMB"
    echo "    -U <USBSIZE-in-MB> Overwriting the default disk space in MB"
    echo "                        -P have to be specified as well!"
    echo 
    echo "******************************************************************"
    echo 
    echo " General options:"
    echo
    echo "    -A '<arch1 arch2>' Set architecture(s) to build for"
    echo "                        Default: '${ARCH}'"
    echo "    -S                 Set silent mode without any questions"
    echo "    -N <iso_name>      Set an iso filename (prefix)"
    echo "                        Default: ${iso_name}"
    echo "    -V <iso_version>   Set an iso version (in filename)"
    echo "                        Default: ${iso_version}"
    echo "    -L <iso_label>     Set an iso label (disk label)"
    echo "                        Default: ${iso_label}"
    echo "    -D <install_dir>   Set an install_dir (directory inside iso)"
    echo "                        Default: ${install_dir}"
    echo "    -w <work_dir>      Set the working directory"
    echo "                        Default: ${work_dir}"
    echo "    -o <out_dir>       Set the output directory"
    echo "                        Default: ${out_dir}"
    echo "    -v                 Enable verbose output"
    echo "    -h                 This help message"
    exit ${1}
}

# Helper function to run make_*() only one time per architecture.
run_once() {
    if [[ ! -e ${work_dir}/build.${1}_${arch} ]]; then
        echo "Starting task $1 ($arch):"
        $1
        touch ${work_dir}/build.${1}_${arch}
        echo "Task $1 ($arch) finished successfully"
    else 
        echo "Skipping $1 ($arch) as already done"
    fi
}

# Setup custom pacman.conf with current cache directories.
make_pacman_conf() {
    local _cache_dirs
    _cache_dirs=($(pacman -v 2>&1 | grep '^Cache Dirs:' | sed 's/Cache Dirs:\s*//g'))
    sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n ${_cache_dirs[@]})|g" ${script_path}/pacman.conf > ${work_dir}/pacman.conf
}

# Base installation, plus needed packages (airootfs)
make_basefs() {
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" init
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "haveged intel-ucode nbd" install
}

# Additional packages (airootfs)
make_packages() {
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "$(grep -h -v ^# ${script_path}/packages.{both,${arch}})" install
}

# Needed packages for x86_64 EFI boot
make_packages_efi() {
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "efitools" install
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {
    local _hook
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/install
    for _hook in archiso archiso_shutdown archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_loop_mnt; do
        cp /usr/lib/initcpio/hooks/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
        cp /usr/lib/initcpio/install/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/install
    done
    sed -i "s|/usr/lib/initcpio/|/etc/initcpio/|g" ${work_dir}/${arch}/airootfs/etc/initcpio/install/archiso_shutdown
    cp /usr/lib/initcpio/install/archiso_kms ${work_dir}/${arch}/airootfs/etc/initcpio/install
    cp /usr/lib/initcpio/archiso_shutdown ${work_dir}/${arch}/airootfs/etc/initcpio
    cp ${script_path}/mkinitcpio.conf ${work_dir}/${arch}/airootfs/etc/mkinitcpio-archiso.conf
    gnupg_fd=
    if [[ ${gpg_key} ]]; then
      gpg --export ${gpg_key} >${work_dir}/gpgkey
      exec 17<>${work_dir}/gpgkey
    fi
    ARCHISO_GNUPG_FD=${gpg_key:+17} setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r 'mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img' run
    if [[ ${gpg_key} ]]; then
      exec 17<&-
    fi
}

# Customize installation (airootfs)
make_customize_airootfs() {
    cp -af ${script_path}/airootfs ${work_dir}/${arch}

    curl -o ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist 'https://www.archlinux.org/mirrorlist/?country=all&protocol=http&use_mirror_status=on'

    lynx -dump -nolist 'https://wiki.archlinux.org/index.php/Installation_Guide?action=render' >> ${work_dir}/${arch}/airootfs/root/install.txt

    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r '/root/customize_airootfs.sh' run
    rm ${work_dir}/${arch}/airootfs/root/customize_airootfs.sh
}

# Prepare kernel/initramfs ${install_dir}/boot/
make_boot() {
    mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
    cp ${work_dir}/${arch}/airootfs/boot/archiso.img ${work_dir}/iso/${install_dir}/boot/${arch}/archiso.img
    cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz
}

# Add other aditional/extra files to ${install_dir}/boot/
make_boot_extra() {
    cp ${work_dir}/${arch}/airootfs/boot/intel-ucode.img ${work_dir}/iso/${install_dir}/boot/intel_ucode.img
    cp ${work_dir}/${arch}/airootfs/usr/share/licenses/intel-ucode/LICENSE ${work_dir}/iso/${install_dir}/boot/intel_ucode.LICENSE
}

# Prepare /${install_dir}/boot/syslinux
make_syslinux() {
    mkdir -p ${work_dir}/iso/${install_dir}/boot/syslinux
    for _cfg in ${script_path}/syslinux/*.cfg; do
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" ${_cfg} > ${work_dir}/iso/${install_dir}/boot/syslinux/${_cfg##*/}
    done
    cp ${script_path}/syslinux/splash.png ${work_dir}/iso/${install_dir}/boot/syslinux
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/*.c32 ${work_dir}/iso/${install_dir}/boot/syslinux
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/lpxelinux.0 ${work_dir}/iso/${install_dir}/boot/syslinux
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/memdisk ${work_dir}/iso/${install_dir}/boot/syslinux
    mkdir -p ${work_dir}/iso/${install_dir}/boot/syslinux/hdt
    gzip -c -9 ${work_dir}/${arch}/airootfs/usr/share/hwdata/pci.ids > ${work_dir}/iso/${install_dir}/boot/syslinux/hdt/pciids.gz
    gzip -c -9 ${work_dir}/${arch}/airootfs/usr/lib/modules/*-ARCH/modules.alias > ${work_dir}/iso/${install_dir}/boot/syslinux/hdt/modalias.gz
}

# Prepare /isolinux
make_isolinux() {
    mkdir -p ${work_dir}/iso/isolinux
    sed "s|%INSTALL_DIR%|${install_dir}|g" ${script_path}/isolinux/isolinux.cfg > ${work_dir}/iso/isolinux/isolinux.cfg
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/isolinux.bin ${work_dir}/iso/isolinux/
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/isohdpfx.bin ${work_dir}/iso/isolinux/
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/ldlinux.c32 ${work_dir}/iso/isolinux/
}

# Prepare /EFI
make_efi() {
    mkdir -p ${work_dir}/iso/EFI/boot
    cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/PreLoader.efi ${work_dir}/iso/EFI/boot/bootx64.efi
    cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/HashTool.efi ${work_dir}/iso/EFI/boot/

    cp ${work_dir}/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${work_dir}/iso/EFI/boot/loader.efi

    mkdir -p ${work_dir}/iso/loader/entries
    cp ${script_path}/efiboot/loader/loader.conf ${work_dir}/iso/loader/
    for econf in $(find ${script_path}/efiboot/loader/entries/ -name "*-usb.conf");do
        econfalone=${econf##*/}
        echo "econfalone: $econfalone"
        rneconf="${econfalone/-usb.conf/.conf}"
        echo "rneconf: $rneconf"
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" $econf > ${work_dir}/iso/loader/entries/$rneconf
    done

    # EFI Shell 2.0 for UEFI 2.3+
    curl -o ${work_dir}/iso/EFI/shellx64_v2.efi https://raw.githubusercontent.com/tianocore/edk2/master/ShellBinPkg/UefiShell/X64/Shell.efi
    # EFI Shell 1.0 for non UEFI 2.3+
    curl -o ${work_dir}/iso/EFI/shellx64_v1.efi https://raw.githubusercontent.com/tianocore/edk2/master/EdkShellBinPkg/FullShell/X64/Shell_Full.efi
}

# Prepare efiboot.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
    mkdir -p ${work_dir}/iso/EFI/archiso
    truncate -s 64M ${work_dir}/iso/EFI/archiso/efiboot.img
    mkfs.fat -n ARCHISO_EFI ${work_dir}/iso/EFI/archiso/efiboot.img

    mkdir -p ${work_dir}/efiboot
    mount ${work_dir}/iso/EFI/archiso/efiboot.img ${work_dir}/efiboot

    mkdir -p ${work_dir}/efiboot/EFI/archiso
    cp ${work_dir}/iso/${install_dir}/boot/x86_64/vmlinuz ${work_dir}/efiboot/EFI/archiso/vmlinuz.efi
    cp ${work_dir}/iso/${install_dir}/boot/x86_64/archiso.img ${work_dir}/efiboot/EFI/archiso/archiso.img

    cp ${work_dir}/iso/${install_dir}/boot/intel_ucode.img ${work_dir}/efiboot/EFI/archiso/intel_ucode.img

    mkdir -p ${work_dir}/efiboot/EFI/boot
    cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/PreLoader.efi ${work_dir}/efiboot/EFI/boot/bootx64.efi
    cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/HashTool.efi ${work_dir}/efiboot/EFI/boot/

    cp ${work_dir}/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${work_dir}/efiboot/EFI/boot/loader.efi

    mkdir -p ${work_dir}/efiboot/loader/entries
    cp ${script_path}/efiboot/loader/loader.conf ${work_dir}/efiboot/loader/
    cp ${script_path}/efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${work_dir}/efiboot/loader/entries/
    cp ${script_path}/efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${work_dir}/efiboot/loader/entries/

    for econf in $(find ${script_path}/efiboot/loader/entries/ -name "*-cd.conf");do
        econfalone=${econf##*/}
        echo "econfalone: $econfalone"
        rneconf="${econfalone/-cd.conf/.conf}"
        echo "rneconf: $rneconf"
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            $econf > ${work_dir}/efiboot/loader/entries/$rneconf
    done

    cp ${work_dir}/iso/EFI/shellx64_v2.efi ${work_dir}/efiboot/EFI/
    cp ${work_dir}/iso/EFI/shellx64_v1.efi ${work_dir}/efiboot/EFI/

    umount -d ${work_dir}/efiboot
}

# Build airootfs filesystem image
make_prepare() {
    cp -a -l -f ${work_dir}/${arch}/airootfs ${work_dir}
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" pkglist
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" ${gpg_key:+-g ${gpg_key}} prepare
    rm -rf ${work_dir}/airootfs
    # rm -rf ${work_dir}/${arch}/airootfs (if low space, this helps)
}

# Enable persistent mode
persistent_iso() {
    # define a label for the persistent partition (if changed here - change it in BIOS and UEFI boot confs as well!)
    PERSLABEL=fwulforever 

    # ensure we get not too big by substracting 8% of the given usb size
    USBBORDER=$((USBSIZEMB/100*8))
    echo -e "\tUSBBORDER: $USBBORDER"    
    USBSIZE=$((USBSIZEMB - USBBORDER))
    echo -e "\tUSBSIZE: $USBSIZE"    

    # partition will be #3 usually
    ISOPARTN=3
    echo -e "\nPreparing persistent setup:\n"

    # part1: blow the ISO up
    # get the size of the FWUL ISO
    ISOFSIZEK=$(du -s ${out_dir}/${iso_name}${iso_version}_${arch}.iso | sed 's#\s.*##g')
    echo -e "\tISOFSIZEK:\t$ISOFSIZEK"
    # calculation of the space to use (bash will auto-round! could be not what we want though..)
    ISOFSIZEMB=$((ISOFSIZEK / 1024))
    echo -e "\tISOFSIZEMB:\t$ISOFSIZEMB"
    [ "$USBSIZE" -lt "$ISOFSIZEMB" ] && echo -e "\n\nERROR: USBSIZEMB-$USBBORDER=$USBSIZEMB has to be equal or higher than the ISO size: $ISOFSIZEMB!" && exit 3
    REMAINSIZE=$((USBSIZE - ISOFSIZEMB))
    echo -e "\tREMAINSIZE:\t$REMAINSIZE"
    ISOSIZEG=$((REMAINSIZE / 1024))
    echo -e "\tISOSIZEG:\t$ISOSIZEG"
    PERSISTSIZE=$((REMAINSIZE * 1024 * 2))
    echo -e "\tPERSISTSIZE:\t$PERSISTSIZE"
    # extend the ISO with the calculated amount
    dd status=progress if=/dev/zero bs=512 count=$PERSISTSIZE >> ${out_dir}/${iso_name}${iso_version}_${arch}.iso
    
    # part2: partitioning
    echo -e "\nCreating persistent partition:\n"
    # the following will magically create a partition with all space of the previous blowed up space
    echo -e "n\np\n$ISOPARTN\n \n \nw" | fdisk ${out_dir}/${iso_name}${iso_version}_${arch}.iso

    # part3: format it
    echo -e "\nFormatting persistent partition:\n"
    # get start of the persistent partition
    LOOFF=$(fdisk -l ${out_dir}/${iso_name}${iso_version}_${arch}.iso -o Device,Start|grep iso${ISOPARTN} |cut -d " " -f2)
    echo -e "\tLOOFF:\t\t$LOOFF"
    LOOFFSET=$((LOOFF * 512))
    echo -e "\tLOOFFSET:\t$LOOFFSET"
    # get end of the persistent partition
    LOSZ=$(fdisk -l ${out_dir}/${iso_name}${iso_version}_${arch}.iso -o Device,End|grep iso${ISOPARTN} |cut -d " " -f2)
    echo -e "\tLOSZ:\t\t$LOSZ"
    LOSZLIMIT=$((LOSZ * 512))
    echo -e "\tLOSZLIMIT:\t$LOSZLIMIT"
    # prepare loop device
    LOOPDEV="$(losetup -f)"
    losetup -o $LOOFFSET --sizelimit $LOSZLIMIT $LOOPDEV ${out_dir}/${iso_name}${iso_version}_${arch}.iso
    # format it (label is important for the Arch boot later!)
    mkfs -t ext4 -L $PERSLABEL $LOOPDEV
    losetup -d $LOOPDEV

    # part4: compress & cleanup
    CURDIR=$(pwd)
    cd ${out_dir} && zip ${iso_name}${iso_version}_${arch}.zip ${iso_name}${iso_version}_${arch}.iso && rm ${iso_name}${iso_version}_${arch}.iso
    cd "$CURDIR"
}

# Build ISO
make_iso() {
    export out_dir="${baseoutdir}/${arch}"
    echo "mkarchiso ${verbose} -P $PUBLISHER -w ${work_dir} -D ${install_dir} -L ${iso_label} -o "${out_dir}" iso ${iso_name}${iso_version}_${arch}.iso"
    mkarchiso ${verbose} -P "$PUBLISHER" -w "${work_dir}" -D "${install_dir}" -L "${iso_label}" -o "${out_dir}" iso "${iso_name}${iso_version}_${arch}.iso"
    if [ "x$persistent" == "xyes" ];then
        persistent_iso
    fi
}

# clean lock files
F_CLEANLOCKS() {
	echo -e "\n\nCLEANING UP LOCKS! THIS WILL ENFORCE AN ISO REBUILD (but leaving the ISO base intact):\n\n"
        for arch in i686 x86_64;do
	    rm -fv ${work_dir}/$arch/build.make_*
        done
	echo finished..
}

F_FULLCLEAN(){
	echo -e "\n\nCLEANING UP WHOLE ISO BUILD BASE! ENFORCES A FULL(!) ISO REBUILD:\n\n"
        if [ "x$SILENT" != "xyes" ];then
            read -p "are you sure????? (CTRL+C to abort)" DUMMY
        fi
	rm -Rf ${work_dir}
	echo finished..
}

F_CUSTCLEAN(){
    echo -e "\nEnforcing re-run of customize script. This will NOT re-create the ISO!\n\n"
    for arch in i686 x86_64;do
        rm -vf ${work_dir}/$arch/build.make_customize_airootfs*
    done
    echo finished..
}

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    _usage 1
fi

if [[ ${arch} != x86_64 ]]; then
    echo "This script needs to be run on x86_64"
    _usage 1
fi

CLEANALL=0
CLEANCUST=0
CLEANLOCK=0

while getopts 'N:V:L:D:w:o:g:vhCFcPU:SA:' arg; do
    case "${arg}" in
        S) SILENT=yes;;
        P) persistent=yes ;;
        U) USBSIZEMB="$OPTARG";;
        C) CLEANLOCK=1 ;;
        F) CLEANALL=1 ;;
        c) CLEANCUST=1 ;;
        N) iso_name="${OPTARG}" ;;
        V) export iso_version="${OPTARG}" ;;
        L) iso_label="${OPTARG}" ;;
        D) install_dir="${OPTARG}" ;;
        w) work_dir="${OPTARG}" ;;
        o) out_dir="${OPTARG}" ;;
        g) gpg_key="${OPTARG}" ;;
        v) verbose="-v" ;;
        h) _usage 0 ;;
        A) ARCH="${OPTARG}" ;;
        *)
           echo "Invalid argument '${arg}'"
           _usage 1
           ;;
    esac
done

[ "$CLEANALL" -eq 1 ]&& F_FULLCLEAN
[ "$CLEANCUST" -eq 1 ]&& F_CUSTCLEAN
[ "$CLEANLOCK" -eq 1 ]&& F_CLEANLOCKS

basedir=$work_dir
baseoutdir=$out_dir

for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    mkdir -p $work_dir
    run_once make_pacman_conf
done

# Do all stuff for each airootfs
for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    run_once make_basefs
    run_once make_packages
done

for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    run_once make_packages_efi
done

for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    run_once make_setup_mkinitcpio
    run_once make_customize_airootfs
done

for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    run_once make_boot
done

# Do all stuff for "iso"
for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    run_once make_boot_extra
    run_once make_syslinux
    run_once make_isolinux
done

for arch in $ARCH;do
    # UEFI support when 64bit only
    if [ $arch == "x86_64" ];then
        export work_dir="${basedir}/${arch}"
        run_once make_efi
        run_once make_efiboot
    fi
done

for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    run_once make_prepare
done

for arch in $ARCH; do
    export work_dir="${basedir}/${arch}"
    run_once make_iso
done

echo -e "\n\nALL FINISHED SUCCESSFULLY"
