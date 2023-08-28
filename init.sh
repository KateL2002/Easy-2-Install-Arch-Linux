#!/bin/bash
# init.sh
# This script is only for Install.

OS=`cat /etc/lsb-release | grep DISTRIB_ID | cut -d '=' -f2 | cut -d '"' -f2`
if [[ $OS != 'Arch' ]];then
    echo "[ERROR] This script is only for Arch linux!" >&2
    exit 1;
fi

if [ ! -f .iconfig ];then
    echo "[ERROR] Config file is not found!" >&2
    exit 1
fi

source .iconfig; sleep 1s
timedatectl set-timezone $TIMEZONE
timedatectl set-ntp true
echo "[$(date '+%F %T')] Preparing Install..."
hostnamectl hostname $HOST_NAME 2> /dev/null
if [ $? -ne 0 ];then
    echo "[ERROR] Invalid Hostname! Please try again!" >&2
    exit 1
fi

if [[ ! $USER_NAME && ! $ROOT_PASSWORD ]];then
    echo "[ERROR] Please set root password or create a user!" >&2
    exit 1
fi

if [ $ROOT_PASSWORD ];then
    echo -e '$ROOT_PASSWORD\n$ROOT_PASSWORD' > .rootpass
    useradd testroot; sleep 0.5s
    passwd testroot < .rootpass
    if [ $? -ne 0 ];then
        echo "[ERROR] Invalid Password! Please reset password for root!" >&2
        sleep 0.5s
        userdel testroot;
        rm -rf .rootpass
        exit 1
    fi
    sleep 0.5s
    rm -rf .rootpass
    userdel testroot
fi

if [ $USER_NAME ];then
    if [ ! $USER_PASS ];then
        echo "[ERROR] You don't have set a password for $USER_NAME!" >&2
        exit 1
    fi
    useradd $USER_NAME; sleep 0.5s
    echo -e '$USER_PASS\n$USER_PASS' > .userpass
    passwd $USER_NAME < .userpass
    if [ $? -ne 0 ];then
        echo "[ERROR] Invalid Password! Please reset password for $USER_NAME!" >&2
        sleep 0.5s
        userdel $USER_NAME
        exit 1
    fi
    userdel $USER_NAME
fi

if [ ! $INSTALL_DISK ];then
    echo "[ERROR] You have not set up install disk!" >&2
    exit 1
fi

disable_ctrl_c() {
    echo "[ERROR] Canceled installation!" >&2
    exit 1
}

enable_ctrl_c() {
    echo "[ERROR] Canceled installation!" >&2
    sleep 0.5s
    exit 1
}

swapfile() {
    if [ ! -f /mnt/swapfile ];then
        echo "[$(date '+%F %T')] Writing swap file, it may takes a few minutes..."
        TOTAL_MEM=$(lsmem -b | grep 'online' | cut -d ' ' -f2 | head -n1)
        TOTAL_MEM=$[TOTAL_MEM / 1024 / 1024]
        if [ $TOTAL_MEM -le 2048 ];then
            dd if=/dev/zero of=/mnt/swapfile bs=1M count=$[TOTAL_MEM*2] status=progress 2>&1
        elif [[ $TOTAL_MEM -gt 2048 && $TOTAL_MEM -le 8192 ]];then
            dd if=/dev/zero of=/mnt/swapfile bs=1M count=$TOTAL_MEM status=progress 2>&1
        else
            dd if=/dev/zero of=/mnt/swapfile bs=1M count=8192 status=progress 2>&1
        fi
        if [ $? -ne 0 ];then
            echo "[ERROR] Can not write swap file, the swap file will be deleted!" >&2
            rm -rf /mnt/swapfile
            exit 1
        fi
        echo "[$(date '+%F %T')] Mounting swap file..."
        chmod 600 /mnt/swapfile
        mkswap /mnt/swapfile
        swapon /mnt/swapfile
        if [ $? -ne 0 ];then
            echo "[ERROR] Can not mount swap file, the swap file will be deleted!" >&2
            swapoff /mnt/swapfile
            rm -rf /mnt/swapfile
            exit 1
        fi
    fi
}

Install_on_a_disk() {
    echo "[$(date '+%F %T')] Creating partition table..."
    if [ $(parted /dev/$INSTALL_DISK print | grep unknown | wc -l) -eq 1 ];then
        parted /dev/$INSTALL_DISK mklabel gpt
    fi
    sleep 1s
    echo "[$(date '+%F %T')] Creating partitions..."
    sleep 0.5s
    if [ $? -ne 0 ];then
        echo "[ERROR] An error occurred while partitioning." >&2
        exit 1
    fi
    parted /dev/$INSTALL_DISK unit MiB
    parted /dev/$INSTALL_DISK mkpart sysboot ext4 0% 512MiB 
    parted /dev/$INSTALL_DISK set 1 bios_grub on
    parted /dev/$INSTALL_DISK mkpart main ext4 512MiB 100%
    if [ $? -ne 0 ];then
        echo "[ERROR] An error occurred while creating partition." >&2
        exit 1
    fi
    partprobe 2> /dev/null
    PART1=$INSTALL_DISK'1'; PART2=$INSTALL_DISK'2'
    echo "[$(date '+%F %T')] Formatting partition..."
    sleep 1s
    mkfs.exfat /dev/$PART1 && mkfs.ext4 /dev/$PART2 
    if [ $? -ne 0 ];then
        echo "[ERROR] An error occurred while formatting partition." >&2
        exit 1
    fi
    mount /dev/$PART1 --mkdir /mnt/boot && mount /dev/$PART2 /mnt
    if [ $? -ne 0 ];then
        echo "[ERROR] An error occurred while mounting partition." >&2
        exit 1
    fi
    swapfile
    if [ $? -ne 0 ];then
        rm -rf /mnt/swapfile
        echo "[ERROR] Can not write swap file." >&2
        exit 1
    fi
}

trap disable_ctrl_c SIGINT;
echo "[$(date '+%F %T')] Checking hard disk..."
sleep 0.5s
case $INSTALL_DISK_MODE in
    'Custom')
        if [[ ! $(lsblk | grep "/mnt$") || ! $(lsblk | grep '/mnt/boot') ]];then
            echo "[ERROR] The partition is not mounted correctly!" >&2
            exit 1
        fi
        if [ ! $(lsblk | grep "SWAP") ];then
            swapfile
            if [ $? -ne 0 ];then
                rm -rf /mnt/swapfile
                echo "[ERROR] Can not write swap file." >&2
                exit 1
            fi
        fi
        ;;
    'Automatically')
        if [[ ! $(lsblk | grep "/mnt$") || ! $(lsblk | grep '/mnt/boot') ]];then
            if [[ $(lsblk | grep $INSTALL_DISK | wc -l) == 1 ]];then
                Install_on_a_disk
            else
                for i in [1..6]; do
                    echo "[$(date '+%F %T')] The hard disk will be erased after $[6-i] seconds."
                done
                echo "[$(date '+%F %T')] Erasing hard disk, please do not force kill the program."
                swapoff -a
                umount -af
                shred -n 1 -vz /dev/$INSTALL_DISK 2>&1
                Install_on_a_disk
            fi
        fi
        
        ;;
    *)
        echo "[ERROR] The installation hard disk mode is unknown." >&2
        exit 1
        ;;
esac

trap enable_ctrl_c SIGINT
if [ -f addPacks.list ];then 
	echo "[$(date '+%F %T')] Looking for additional packages..."
	for PACK in `cat addPacks.list`; do
		pacman -S $PACK --info > /dev/null 2>&1
		if [ $? -ne 0 ];then
            pacman -S $PACK --groups > /dev/null 2>&1
            if [ $? -ne 0 ];then
			    echo "[ERROR] The $PACK package or group can not be found! " >&2
			    exit 1
            fi
		fi
	done
fi

sleep 1s
pacman-key --init
echo "[$(date '+%F %T')] Installing Basic Packages..."
echo "[ERROR] Failed to install packages to new root." >&2
pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux-firmware nano man-pages man-db grub networkmanager zsh zsh-completions neofetch
if [ $? -ne 0 ];then
    echo "[ERROR] Install Failed while installing basic packages." >&2
    exit 1
fi

echo "[$(date '+%F %T')] Writing Fstab File..."
genfstab -U /mnt > /mnt/etc/fstab
echo "[$(date '+%F %T')] Coping files to new environment..."
chmod u+x ./install.sh
cp install.sh /mnt/root/
cp .iconfig /mnt/root/
cp /etc/zsh/* /mnt/etc/zsh/
if [ -f addPacks.list ];then
    cp addPacks.list /mnt/root
fi
if [ -f server.list ];then
    if [[ $INSTALL_MODE == 'Server' ]];then
        cp server.list /mnt/root
    fi
fi
echo "[$(date '+%F %T')] Entered the installation environment..."
sleep 0.5s
arch-chroot /mnt /root/install.sh
if [ $? -ne 0 ];then
    # echo "[ERROR] Install Failed, please check details from the error.log" >&2
    exit 1
fi
echo "[$(date '+%F %T')] Install Complete!"; sleep 1s
echo "Finish" >&2
