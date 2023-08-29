#!/bin/bash
# setup.sh
# Update: 2023/08/29

OS=`cat /etc/lsb-release | grep DISTRIB_ID | cut -d '=' -f2 | cut -d '"' -f2`
if [[ $OS != 'Arch' ]];then
    echo -e "\033[1;31m[ERROR] This script is only for Arch linux!\033[0m"
    exit 1;
fi

if [[ -d /sys/firmware/efi ]];then
    IS_EFI=1
    EFIMOUNT=/boot/EFI    # EFI Mode
else
    IS_EFI=0
    EFIMOUNT=/boot    # BIOS Mode
fi

timezone() {
    dialog --clear
    TZ=`tzselect`
    echo $TZ > .icache/.timezone
}

keyboardLayout() {
    KBL=`cat .icache/.kbLayout`
    dialog --backtitle "Arch Linux Installation" --title "Keyboard Layout" --no-cancel --menu 'Select a layout: (Press Esc to skip) ' 35 60 30 $(localectl list-keymaps | sed 's/$/ keyboard/') 2> .icache/.kbLayout
    if [ $? -eq 255 ];then
        echo $KBL > .icache/.kbLayout
    fi
}

language() {
    LOCALE=`cat .icache/.locale`
    dialog --backtitle "Arch Linux Installation" --title "Language" --no-cancel --menu 'Select a install language: (Press Esc to skip)' 35 60 30 $(cat /etc/locale.gen | tail -n490 | cut -d '#' -f2 ) 2> .icache/.locale
    if [ $? -eq 255 ];then
        echo $LOCALE > .icache/.locale
    fi
}

mode() {
    MODE=`cat .icache/.getmode`
    dialog --backtitle "Arch Linux Installation" --title "Install Packs" --no-cancel --menu 'Select a install mode: (Press Esc to skip)' 10 50 20 \
        Desktop 'Desktop Environment Installation'\
        Mininal 'Minimal Installation'\
        Server 'Server Installation'\
        2> .icache/.getmode
    if [ $? -eq 255 ];then
        echo $MODE > .icache/.getmode
    else
        case `cat .icache/.getmode` in
            'Desktop')
                desktop $MODE
                ;;
            'Server')
                dialog --backtitle "Arch Linux Installation" --title "Server" --checklist "Please select package(s) for server: " 24 80 18 'openssh' 'SSH protocol implementation for remote login, command execution and file transfer' '1' \
                    'cockpit' 'Web-based service management tools' '2' \
                    'firewalld' 'Firewall daemon with D-Bus interface' '3' \
                    'mariadb' 'Fast SQL database server, derived from MySQL' '4' \
                    'postgresql' 'Sophisticated object-relational DBMS' '5' \
                    'sqlite' 'A C library that implements an SQL database engine' '6' \
                    'apache' 'A high performance Unix-based HTTP server' '7' \
                    'nginx' 'Lightweight HTTP server and IMAP/POP3 proxy server' '8' \
                    'vsftpd' 'Very Secure FTP daemon' '9' \
                    'postfix' 'Fast, easy to administer, secure mail server' '10' \
                    'bind' 'A complete, highly portable implementation of the DNS protocol' '11' \
                    'dhcp' 'A DHCP server, client, and relay agent' '12' \
                    'samba' 'SMB Fileserver and AD Domain server' '13' \
                    'openvpn' 'An easy-to-use, robust and highly configurable VPN (Virtual Private Network)' '14' \
                        2> .icache/server.list
                if [ $? -eq 0 ];then
                    cat > server.list < .icache/server.list
                    desktop $MODE
                else
                    echo $MODE > .icache/.getmode
                fi
                ;;
            *)
                ;;
        esac
    fi
}

desktop() {
    DESKTOP=`cat .icache/.getgui`
    dialog --backtitle "Arch Linux Installation" --title "Desktop Enivornment" --menu 'Select a desktop environment: (Press Esc to skip)' 18 50 20 \
        none 'Without Desktop' \
        budgie Budgie \
        cinnamon Cinnamon \
        dde Deepin \
        gnome GNOME \
        kde Plasma \
        lxde LXDE \
        lxqt LXQt \
        mate Mate \
        xfce4 Xfce \
        2> .icache/.getgui
    if [ $? -ne 0 ];then
        echo $1 > .icache/.getmode
        echo $DESKTOP > .icache/.getgui
    fi
}

custom_drive() {
    while true
    do
        if [ $? -eq 0 ];then
            dialog --backtitle "Arch Linux Installation" --title "Hard Drive" --no-cancel --menu "Select a option for $(cat .icache/.getnum):  " 14 45 10 \
                'Partition' 'Partition hard drive' \
                'Format' 'Format File System' \
                'Mount' 'Manage MountPoint' \
                'View' "List `cat .icache/.getnum` info" \
                'Swapfile' 'Create a swapfile' \
                'BootInstall' 'GRUB installation location' \
                'Back' 'Back to main menu' \
                2> .icache/.getmethod
            case `cat .icache/.getmethod` in
                'Partition')
                    cfdisk /dev/`cat .icache/.getnum`
                    partprobe 2> /dev/null
                    ;;
                'Format')
                    echo -n > .icache/.lsblk
                    for PART in $(lsblk -l --output=NAME | grep sda | tail -n +2)
                    do
                        echo -n "$PART " >> .icache/.lsblk
                        FSTYPE=$(lsblk -l --output=NAME,FSTYPE | grep $PART | cut -d ' ' -f3)
                        if [ ! $FSTYPE ];then 
                            echo "(empty)" >> .icache/.lsblk 
                        else  
                            echo $FSTYPE >> .icache/.lsblk
                        fi
                    done
                    dialog --backtitle "Arch Linux Installation" --title "Format Partition" --menu "Select a partition to format:  " 12 30 8 `cat .icache/.lsblk` 2> .icache/.getpart
                    if [ $? -eq 0 ];then
                        dialog --backtitle "Arch Linux Installation" --title "Format Partition" --menu "Select a filesystem for $(cat .icache/.getmethod):  " 15 50 8 'swap' 'Only For Swap Patition' 'fat32' 'Only For EFI Partition' 'exfat' 'Only For Boot Partition' 'ext4' 'Ext4 Filesystem' 'ext3' 'Ext3 filesystem' 'nfs' 'Network filesystem' 'jfs' 'JFS' 'xfs' 'XFS' 'Custom' 'Input a filesystem' 2> .icache/.getmethod
                        if [ $? -eq 0 ];then
                            case $(cat .icache/.getmethod) in
                                'swap')
                                    mkswap /dev/$(cat .icache/.getpart)
                                    swapon /dev/$(cat .icache/.getpart)
                                    ;;
                                'fat32')
                                    mkfs.fat -F 32 /dev/$(cat .icache/.getpart) 2> .error
                                    if [ $? -ne 0 ];then
                                        dialog --backtitle "Arch Linux Installation" --title "Format Failed" --textbox .error 8 60
                                    fi
                                    ;;
                                'Custom')
                                    dialog --backtitle "Arch Linux Installation" --title "Format Partition"  --inputbox 'Please input the filesystem: ' 9 30 2> .icache/.getmethod
                                    mkfs --type=`cat .icache/.getmethod` /dev/$(cat .icache/.getpart) 2> .error
                                    if [ $? -ne 0 ];then
                                        dialog --backtitle "Arch Linux Installation" --title "Format Failed" --textbox .error 8 60
                                    fi
                                    ;;
                                *)
                                    dialog --clear
                                    swapoff /dev/$(cat .icache/.getpart) 2> /dev/null
                                    mkfs --type=`cat .icache/.getmethod` /dev/$(cat .icache/.getpart) 2> .error
                                    if [ $? -ne 0 ];then
                                        dialog --backtitle "Arch Linux Installation" --title "Format Failed" --textbox .error 8 60
                                    fi
                                    ;;
                            esac
                        fi
                    fi
                    ;;
                'Mount')
                    echo -n > .icache/.lsblk
                    for PART in $(lsblk -l --output=NAME | grep sda | tail -n +2)
                    do
                        FSTYPE=$(lsblk -l --output=NAME,MOUNTPOINT | grep $PART | cut -d ' ' -f3)
                        if [ ! $FSTYPE ];then 
                            echo -n "$PART " >> .icache/.lsblk
                            echo "(empty)" >> .icache/.lsblk 
                        elif [[ $FSTYPE != '[SWAP]' ]];then        
                            echo -n "$PART " >> .icache/.lsblk
                            echo $FSTYPE >> .icache/.lsblk
                        fi
                    done
                    dialog --backtitle "Arch Linux Installation" --title "Mount Partition" --menu "Select a partition:  " 12 30 8 `cat .icache/.lsblk` 2> .icache/.getpart
                    if [ $? -eq 0 ];then
                        dialog --backtitle "Arch Linux Installation" --title "Mount Partition"  --menu "Select a mountpoint for $(cat .icache/.getpart):  " 12 60 50 '/' 'System installation [Important]' $EFIMOUNT 'Booting System [Important]' '/home' 'For User' '/var' 'For Server' 'umount' 'Unmount the Partition' 'custom' 'Custom a new mountpoint' 2> .icache/.getmethod
                        if [ $? -eq 0 ];then
                            if [[ $(cat .icache/.getmethod) == 'umount' ]];then
                                MOUNT=$(findmnt /dev/`cat .icache/.getpart` | grep -v TARGET | cut -d ' ' -f1)
                                for UMOUNTPOINT in $MOUNT; do
                                    umount $UMOUNTPOINT 2> /dev/null
                                done
                            elif [[ $(cat .icache/.getmethod) == 'custom' ]];then
                                dialog --backtitle "Arch Linux Installation" --title "Mount Partition"  --inputbox 'Please set a new partition: ' 9 30 2> .icache/.getmethod
                                if [ $? -eq 0 ];then
                                    MOUNT=$(findmnt /dev/`cat .icache/.getpart` | grep -v TARGET | cut -d ' ' -f1)
                                    for UMOUNTPOINT in $MOUNT; do
                                        umount $UMOUNTPOINT 2> /dev/null
                                    done
                                    mount --mkdir /dev/$(cat .icache/.getpart) /mnt/$(cat .icache/.getmethod) 2> .error
                                    if [ $? -ne 0 ];then
                                        dialog --backtitle "Arch Linux Installation" --title "Mount Failed" --textbox .error 8 60
                                        rm -rf .error 
                                    fi
                                fi
                            else
                                MOUNT=$(findmnt /dev/`cat .icache/.getpart` | grep -v TARGET | cut -d ' ' -f1)
                                for UMOUNTPOINT in $MOUNT; do
                                    umount $UMOUNTPOINT 2> /dev/null
                                done
                                mount --mkdir /dev/$(cat .icache/.getpart) /mnt/$(cat .icache/.getmethod) 2> .error
                                if [ $? -ne 0 ];then
                                    dialog --backtitle "Arch Linux Installation" --title "Mount Failed" --textbox .icache/.error 8 60
                                    rm -rf .error 
                                fi
                            fi
                        fi
                    fi
                    ;;
                'View')
                    lsblk /dev/`cat .icache/.getnum` --output=NAME,SIZE,FSTYPE,MOUNTPOINTS > .icache/.lsblk
                    dialog --backtitle "Arch Linux Installation" --title "View" --textbox .icache/.lsblk 18 52
                    ;;
                'Swapfile')
                    if [ $(lsblk /dev/`cat .icache/.getnum` | grep -i swap | wc -l) -eq 0 ];then
                        SWAPSIZE=`cat .icache/.swapfile`
                        dialog --backtitle "Arch Linux Installation" --title 'Swapfile Size' --rangebox 'Please select a size(MB) of swapfile: (Select 0MB will not creat swapfile) (Default value: 2048) ' 10 30 0 8192 $SWAP_SIZE 2> .icache/.swapfile
                        if [ $? -ne 0 ];then
                            echo $SWAPSIZE > .icache/.swapfile
                        fi
                    else
                        dialog --title "Failed" --msgbox 'You have mounted a swap partition, please unmount swap partition at first.' 8 60
                    fi
                    ;;
                'BootInstall')
                    HARD_DISK=`cat .icache/.getdisk`
                    dialog --backtitle "Arch Linux Installation" --title "BootInstall" --no-cancel --menu 'Select a hard drive to install for grub: ' 12 50 10 $(lsblk --exclude 7,11 --output=NAME,SIZE | grep -v NAME | grep -v ─) 2> .icache/.getdisk
                    if [ $? -ne 0 ];then
                        dialog --backtitle "Arch Linux Installation" --title "Caution" --yesno 'You must set up the hard drive while installing grub.' 8 60
                        if [ $? -ne 0 ];then
                            echo $HARD_DISK > .icache/.getdisk
                        fi
                    fi
                    ;;
                'Back')
                    break
                    ;;
            esac      
        fi
    done
}

drive() {
    DRIVE_MODE=`cat .icache/.getdiskmode`
    dialog --backtitle "Arch Linux Installation" --title "Hard Drive" --no-cancel --menu 'Select a option: ' 10 70 10 \
        'Automatically' 'For Virtual machine'\
        'Custom' 'Manage a hard disk'\
        'View' 'View all devices info' \
        2> .icache/.getdiskmode
    if [ $? -eq 255 ];then
        echo $DRIVE_MODE > .icache/.getdiskmode
    elif [[ $(cat .icache/.getdiskmode) == 'Automatically' ]];then
        dialog --backtitle "Arch Linux Installation" --title "Warning" --yesno 'This option will automatically install the system to the hard drive, which will empty all data in the hard drive! If you have partitioned and mounted your hard drive, please select "no".' 8 60
        if [ $? -eq 0 ];then
            HARD_DISK=`cat .icache/.getdisk`
            dialog --backtitle "Arch Linux Installation" --title "Install on a hard Drive" --no-cancel --menu 'Select a hard drive to automatic install: ' 12 50 10 $(lsblk --exclude 7,11 --output=NAME,SIZE | grep -v NAME | grep -v ─) 2> .icache/.getdisk
            if [ $? -ne 0 ];then
                dialog --backtitle "Arch Linux Installation" --title "Caution" --yesno 'Caution: This option will erase the entire drive and install it, are you sure to continue?' 8 60
                if [ $? -ne 0 ];then
                    echo $HARD_DISK > .icache/.getdisk
                fi
            fi
        else
            echo 'Custom' > .icache/.getdiskmode
        fi
    elif [[ $(cat .icache/.getdiskmode) == 'View' ]];then
        echo $DRIVE_MODE > .icache/.getdiskmode
        lsblk --output=NAME,SIZE,FSTYPE,MOUNTPOINTS --exclude 7 > .icache/.lsblk
        dialog --backtitle "Arch Linux Installation" --title "Devices Info" --textbox .icache/.lsblk 18 52
    else
        dialog --backtitle "Arch Linux Installation" --title "Hard Drive" --no-cancel --menu 'Select a hard drive: ' 12 50 10 $(lsblk --exclude 7,11 --output=NAME,SIZE | grep -v NAME | grep -v ─) 2> .icache/.getnum
        custom_drive .icache/.getnum
    fi
}

hostname() {
    HOST_NAME=`cat .icache/.hostname`
    dialog --backtitle "Arch Linux Installation" --title "Set Hostname" --inputbox 'Please set a hostname: (Press Esc to skip)' 9 30 $HOST_NAME 2> .icache/.hostname
    if [ $? -eq 255 ];then
        echo $HOST_NAME > .icache/.hostname
    else
        echo >> .icache/.hostname
    fi
}

rootPass() {
    ROOTPASS=`cat .icache/.rootpass`
    dialog --backtitle "Arch Linux Installation" --title "Root Password" --insecure --passwordbox 'Please set root password: (Press Esc to skip)' 9 36 2> .icache/.rootpass
    if [ $? -eq 255 ];then
        echo $ROOTPASS > .icache/.rootpass
    else
        echo >> .icache/.rootpass
    fi
}

user() {
    USER=`cat .icache/.username`
    dialog --backtitle "Arch Linux Installation" --title "Add User" --inputbox 'Please input the username: (Press Esc to skip)' 9 30 `cat .icache/.username` 2> .icache/.username
    if [ $? -eq 255 ];then
        echo $USER > .icache/.username
    elif [ $(wc -m .icache/.username | cut -d ' ' -f1) -le 2 ];then
        dialog --backtitle "Arch Linux Installation" --title "Add User" --msgbox 'Invalid username, please input again!' 6 30
        user
    else
        dialog --backtitle "Arch Linux Installation" --title "Add User" --insecure --no-cancel --passwordbox "Please set the password for $(cat .icache/.username):" 8 40 2> .icache/.userpass
        if [ $(wc -m .icache/.userpass | cut -d ' ' -f1) -lt 6 ];then
            dialog --backtitle "Arch Linux Installation" --title "Add User" --msgbox 'Invalid password, please input again!' 6 30
            user
        else
            echo >> .icache/.userpass
        fi
    fi   
}

additional() {
    dialog --backtitle "Arch Linux Installation" --title "Notes" --msgbox 'Please enter the name of the installed package, containing only one package per line.' 8 60
    dialog --backtitle "Arch Linux Installation" --title 'Additional Packages' --editbox addPacks.list 0 50 2> .icache/.addPacks.list
    if [ $? -eq 0 ];then
        cat .icache/.addPacks.list > addPacks.list
    fi
    rm -rf .icache/.addPacks.list
}

save_conf() {
    touch .iconfig
    cat > .iconfig << EOF
# Install Config
# TODO: Please supplement or modify the corresponding parameters according to the 
# following comments.

# [CPU MODEL]
CPU_MODEL=`cat .icache/.getcpu`

# [Hard Disk]
# Warning: This script only supports automatic partition allocation, if you need 
# to customize the allocation, please use cfdisk / fdisk / parted and other tools 
# to customize the partition.
INSTALL_DISK_MODE=`cat .icache/.getdiskmode`
INSTALL_DISK=`cat .icache/.getdisk`
SWAP_SIZE=`cat .icache/.swapfile`  # Default: 2048(MiB), 0(MiB) will not create a swap file

# Auto Partition Result
# e.g: if sda disk had 32GiB space, then....
# NAME  SIZE    MOUNTPOINT TYPE
# sda1  512M    Boot Partition
# sda2  31.4G   Linux FS (ext4 filesystem)

# Auto Create Swapfile Result
# MEMORY_SIZE(MiB)        SWAP_SIZE(MiB)
# <= 2048                 MEMORY_SIZE * 2
# 2048 < MEMORY <= 8192   MEMORY_SIZE
# > 8192                  = 8192             

# [Create User & Host]
HOST_NAME=`cat .icache/.hostname`
ROOT_PASSWORD=`cat .icache/.rootpass`
USER_NAME=`cat .icache/.username`
USER_PASS=`cat .icache/.userpass`

# [Timezone & Language]
TIMEZONE=`cat .icache/.timezone`
LANGUAGE=`cat .icache/.locale`
KEYMODE=`cat .icache/.kbLayout`

# [Install Mode]
INSTALL_MODE=`cat .icache/.getmode`     

# [Desktop Enviroment]
DESKTOP_ENV=`cat .icache/.getgui`

EOF
}

load_conf() {
    source .iconfig

    if [ ! $INSTALL_DISK ];then
        GRUB_DISK='(unset)'
    else
        GRUB_DISK=$INSTALL_DISK
    fi

    if [ ! $HOST_NAME ];then
        IS_SETHOST='(unset)'
    else
        IS_SETHOST=$HOST_NAME
    fi

    if [ ! $USER_NAME ];then
        IS_USER='(unset)'
    else
        IS_USER=$USER_NAME
    fi

    if [ ! $ROOT_PASSWORD ];then
        IS_SETROOT='(unset)'
    else
        IS_SETROOT='******'
    fi

    if [ ! `cat addPacks.list` ];then
        ADD_LIST='(null)'
    else
        ADD_LIST='(....)'
    fi
    
    echo $KEYMODE > .icache/.kbLayout
    echo $LANGUAGE > .icache/.locale
    echo $HOST_NAME > .icache/.hostname
    echo $INSTALL_MODE > .icache/.getmode
    echo $DESKTOP_ENV > .icache/.getgui
    echo $ROOT_PASSWORD > .icache/.rootpass
    echo $USER_NAME > .icache/.username
    echo $USER_PASS > .icache/.userpass
    echo $INSTALL_DISK_MODE > .icache/.getdiskmode
    echo $INSTALL_DISK > .icache/.getdisk
    echo $SWAP_SIZE > .icache/.swapfile
    echo $TIMEZONE > .icache/.timezone
}

# main
echo -n 'Checking network...'
curl ifconfig.io &> /dev/null
if [ $? -ne 0 ]; then
    echo 'ERROR'
    echo -e "\033[1;31m[ERROR] Network is not reacheable! \033[0m"
    exit 1;
fi
echo 'OK'
echo -n 'Updating packages databases...'
pacman -Sy &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "ERROR\n\033[1;31m[ERROR] Canceled! \033[0m"
    exit 1;
fi
echo 'OK'
echo -n "Loading Installation..."
dialog --version &> /dev/null
if [ $? -ne 0 ];then
    pacman -Sy --noconfirm dialog &> /dev/null
    if [ $? -ne 0 ]; then
        echo 'ERROR'
        echo -e "\033[1;31m[ERROR] Getting failed! \033[0m"
        exit 1;
    fi
fi
# Create a default config file when it is not exist.
mkdir -p .icache
# Get CPU
CPU=`lscpu | grep AMD | wc -l`
if [ $CPU -ne 0 ];then
    echo amd > .icache/.getcpu
fi
CPU=`lscpu | grep Intel | wc -l`
if [ $CPU -ne 0 ];then
    echo intel > .icache/.getcpu
fi

# Default Value
if [[ ! -f .iconfig ]];then
    echo defkeymap > .icache/.kbLayout
    echo $LANG > .icache/.locale
    echo arch > .icache/.hostname
    echo 'Mininal' > .icache/.getmode
    echo 'none' > .icache/.getgui
    touch .icache/.rootpass
    touch .icache/.username
    touch .icache/.userpass
    echo 'Custom' > .icache/.getdiskmode
    echo 2048 > .icache/.swapfile
    touch .icache/.getdisk
    touch addPacks.list
    timedatectl | grep zone | cut -d ':' -f2 | cut -d ' ' -f2 > .icache/.timezone
    save_conf
    load_conf
else
    load_conf
fi
sleep 1s

# Main Menu
while true
do
    if [ $IS_EFI -eq 1 ]; then
        dialog --backtitle "Arch Linux Installation" --title "Installation Menu" --no-cancel --menu 'Please select a option: ' 24 52 10 \
            Keyboard        $KEYMODE, \
            Language        $LANGUAGE, \
            'Drive(s)'      $INSTALL_DISK_MODE, \
            Timezone        $TIMEZONE,\
            Hostname        $IS_SETHOST,\
            Root_Passwd     $IS_SETROOT,\
            User            $IS_USER,\
            Installation_Mode   $INSTALL_MODE\
            Additional_Packs    $ADD_LIST,\
            --------     -------------------------\
            Start   'Start Install Arch Linux'\
            Exit    'Exit Installation'\
            2> .icache/.getMenuNum
    else
        dialog --backtitle "Arch Linux Installation" --title "Installation Menu" --no-cancel --menu 'Please select a option: ' 24 52 10 \
            Keyboard        $KEYMODE, \
            Language        $LANGUAGE, \
            'Drive(s)'      $INSTALL_DISK_MODE, \
            Grub_Install    $GRUB_DISK, \
            Timezone        $TIMEZONE,\
            Hostname        $IS_SETHOST,\
            Root_Passwd     $IS_SETROOT,\
            User            $IS_USER,\
            Installation_Mode   $INSTALL_MODE\
            Additional_Packs    $ADD_LIST,\
            --------     -------------------------\
            Start   'Start Install Arch Linux'\
            Exit    'Exit Installation'\
            2> .icache/.getMenuNum
    fi
    
    case $(cat .icache/.getMenuNum) in
        Keyboard)
            keyboardLayout
            save_conf
            load_conf
            ;;
        Language)
            language
            save_conf
            load_conf
            ;;
        'Drive(s)')
            drive
            save_conf
            load_conf
            ;;
        Grub_Install)
            HARD_DISK=`cat .icache/.getdisk`
            dialog --backtitle "Arch Linux Installation" --title "Grub Install" --no-cancel --menu 'Select a hard drive to install for grub: ' 12 50 10 $(lsblk --exclude 7,11 --output=NAME,SIZE | grep -v NAME | grep -v ─) 2> .icache/.getdisk
            if [ $? -ne 0 ];then
                dialog --backtitle "Arch Linux Installation" --title "Caution" --yesno 'You must set up the hard drive while installing grub.' 8 60
                if [ $? -ne 0 ];then
                    echo $HARD_DISK > .icache/.getdisk
                fi
            fi
            save_conf
            load_conf
            ;;
        Timezone)
            timezone
            save_conf
            load_conf
            ;;
        Hostname)
            hostname
            save_conf
            load_conf
            ;;
        Root_Passwd)
            rootPass
            save_conf
            load_conf
            ;;
        User)
            user
            save_conf
            load_conf
            ;;
        Installation_Mode)
            mode
            save_conf
            load_conf
            ;;
        Additional_Packs)
            additional
            save_conf
            load_conf
            ;;
        Start)
            # dialog --clear
            # dialog --backtitle "Arch Linux Installation" --title "Installation Info" --textbox .iconfig 40 80
            dialog --backtitle "Arch Linux Installation" --title "Start Install" --yesno 'Are you sure to start install Arch Linux? ' 8 60
            if [ $? == 0 ];then
                chmod u+x ./init.sh
                touch result.log
                ./init.sh 2> result.log | dialog --backtitle "Arch Linux Installation" --title "Installing..." --progressbox 'Installing System, it will takes a long times...' 40 120
                RESINFO="`tail -n1 result.log`"
                if [[ $RESINFO != 'Finish' ]];then
                    dialog --backtitle "Arch Linux Installation" --title "Install Failed!" --msgbox "$RESINFO" 6 60
                else
                    dialog --backtitle "Arch Linux Installation" --title "Install Success" --timeout 15 --yes-label 'Reboot' --no-label 'Exit' --yesno "Install complete, the system will automatically reboot after 15 seconds. Select 'Exit' will not reboot." 6 60
                    if [ $? -ne 1 ];then
                        dialog --clear
                        reboot
                        exit 0
                    fi
                fi
            fi
            # dialog --backtitle "Arch Linux Installation" --title "Installing..." --prgbox './init.sh 2> err.log'  40 100
            # exit 0
            ;;
        Exit)
            dialog --clear
            rm -rf .icache
            break
            ;;
    esac
done
