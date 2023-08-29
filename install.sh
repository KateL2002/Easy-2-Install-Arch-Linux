#!/bin/bash
# Install Arch Linux
# Update: 2023/08/29

hostnamectl &> /dev/null
if [ $? -eq 0 ];then
    echo -e "[ERROR] You are not in the installation environment. Please run \033[1;37minit.sh\033[0m first."
    exit 1
fi
echo "[$(date '+%F %T')] Imported files"
source /root/.iconfig

echo "[$(date '+%F %T')] Configuring..."
sleep 0.1s

# Set enabled for NetworkManager Service
systemctl enable NetworkManager
echo "[$(date '+%F %T')] Configuring localhost"
echo $HOST_NAME > /etc/hostname

sleep 0.5s
echo "[$(date '+%F %T')] Configuring language"
echo "LANG=$LANGUAGE" > /etc/locale.conf
sed -i "/$LANGUAGE/s/^#//" /etc/locale.gen
locale-gen >&2

sleep 0.5s
if [ $USER_NAME ];then
    echo "[$(date '+%F %T')] Configuring User"
    useradd -m $USER_NAME -s /bin/zsh
    echo -e "$USER_PASS\n$USER_PASS" > .userpass
    passwd $USER_NAME < .userpass
    if [ $? -ne 0 ];then
        userdel -r $USER_NAME
        rm -rf .userpass
        echo "[ERROR] Can not set user password!" >&2
        exit 1
    fi
    sed -i "83i$USER_NAME ALL=(ALL:ALL) ALL" /etc/sudoers
    rm -rf .userpass
fi

if [ $ROOT_PASSWORD ];then
    echo "[$(date '+%F %T')] Configuring Root"
    echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" > .rootpass
    passwd root < .rootpass
    if [ $? -ne 0 ];then
        rm -rf .rootpass 
        echo "[ERROR] Can not set root password!" >&2
        exit 1
    fi
    chsh -s /bin/zsh
fi

sleep 0.5s
echo "[$(date '+%F %T')] Configuring timezone"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "[$(date '+%F %T')] Syncing Packages..."
pacman -Sy &> /dev/null

Install_fonts() {
    echo "[$(date '+%F %T')] Installing required fonts..."
    pacman -S --noconfirm cantarell-fonts noto-fonts ttf-liberation ttf-dejavu ttf-hack ttf-jetbrains-mono \
            adobe-source-code-pro-fonts ttf-opensans noto-fonts-cjk adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts \
            noto-fonts-emoji
}


if [[ $INSTALL_MODE == 'Server' || $INSTALL_MODE == 'Desktop' ]];then
    echo "[$(date '+%F %T')] Start Install Desktop environment..."
    case $DESKTOP_ENV in
        none)
            echo "[WARNING] Desktop environment will not be installed! "
            ;;
        gnome)
            echo "[$(date '+%F %T')] Installing Gnome..."
            pacman -S --noconfirm gnome gnome-extra gnome-shell gdm firefox
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall Gnome..."
                pacman -S --noconfirm gnome gnome-extra gnome-shell gdm firefox
            done
            systemctl enable gdm
            Install_fonts
            ;;
        kde)
            echo "[$(date '+%F %T')] Installing Plasma (KDE)..."
            pacman -S --noconfirm plasma plasma-wayland-session sddm-kcm konsole dolphin firefox 
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall Plasma (KDE)..."
                pacman -S --noconfirm plasma plasma-wayland-session sddm-kcm konsole dolphin firefox 
            done
            systemctl enable sddm
            Install_fonts
            ;;
        cinnamon)
            echo "[$(date '+%F %T')] Installing Cinnamon..."
            pacman -S --noconfirm cinnamon cinnamon-translations xed xreader metacity gnome-terminal gnome-themes-extra system-config-printer gnome-keyring blueberry touchegg lightdm lightdm-slick-greeter arc-gtk-theme papirus-icon-theme firefox
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall Cinnamon..."
                pacman -S --noconfirm cinnamon cinnamon-translations xed xreader metacity gnome-terminal gnome-themes-extra system-config-printer gnome-keyring blueberry touchegg lightdm lightdm-slick-greeter arc-gtk-theme papirus-icon-theme firefox
            done
            sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
            cat > /etc/lightdm/slick-greeter.conf << EOF
[Greeter]
background=/usr/share/backgrounds/gnome/adwaita-d.webp
EOF
            systemctl enable lightdm
            systemctl enable touchegg
            Install_fonts
            ;;
        xfce4)
            echo "[$(date '+%F %T')] Installing Xfce4..."
            pacman -S --noconfirm xfce4 xfce4-goodies xfce4-pulseaudio-plugin libcanberra pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-jack sound-theme-freedesktop xfce4-pulseaudio-plugin xfce4-session xscreensaver lightdm lightdm-gtk-greeter firefox
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall Xfce4..."
                pacman -S --noconfirm xfce4 xfce4-goodies xfce4-pulseaudio-plugin libcanberra pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-jack sound-theme-freedesktop xfce4-pulseaudio-plugin xfce4-session xscreensaver lightdm lightdm-gtk-greeter firefox
            done
            sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
            sed -i "s/#background=/background=\/usr\/share\/backgrounds\/xfce\/xfce-blue.jpg/" /etc/lightdm/lightdm-gtk-greeter.conf
            systemctl enable lightdm
            Install_fonts
            ;;
        mate)
            echo "[$(date '+%F %T')] Installing Mate..."
            pacman -S --noconfirm mate mate-extra mate-applet-dock mate-media blueman network-manager-applet mate-power-manager system-config-printer lightdm lightdm-slick-greeter firefox
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall Mate..."
                pacman -S --noconfirm mate mate-extra mate-applet-dock mate-media blueman network-manager-applet mate-power-manager system-config-printer lightdm lightdm-slick-greeter firefox
            done
            sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
            cat > /etc/lightdm/slick-greeter.conf << EOF
[Greeter]
background=/usr/share/backgrounds/mate/nature/Blinds.jpg
EOF
            systemctl enable lightdm
            Install_fonts
            ;;
        dde)
            echo "[$(date '+%F %T')] Installing Deepin (DDE)..."
            pacman -S --noconfirm deepin deepin-extra firefox lightdm
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall Deepin..."
                pacman -S --noconfirm deepin deepin-extra firefox lightdm
            done
            sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-deepin-greeter/' /etc/lightdm/lightdm.conf
            systemctl enable lightdm
            Install_fonts
            ;;
        budgie)
            echo "[$(date '+%F %T')] Installing Budgie..."
            pacman -S --noconfirm budgie nemo cinnamon-translations lightdm lightdm-slick-greeter arc-gtk-theme papirus-icon-theme network-manager-applet firefox 
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall Budgie..."
                pacman -S --noconfirm budgie nemo cinnamon-translations lightdm lightdm-slick-greeter arc-gtk-theme papirus-icon-theme network-manager-applet firefox 
            done
            sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
            cat > /etc/lightdm/slick-greeter.conf << EOF
[Greeter]
background=/usr/share/backgrounds/budgie/default.jpg
EOF
            systemctl enable lightdm
            Install_fonts
            ;;
        lxde)
            echo "[$(date '+%F %T')] Installing LXDE..."
            pacman -S --noconfirm lxde firefox
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall LXDE..."
                pacman -S --noconfirm lxde firefox
            done
            systemctl enable lxdm
            Install_fonts
            ;;
        lxqt)
            echo "[$(date '+%F %T')] Installing LXQT..."
            pacman -S --noconfirm xorg-server lxqt xscreensaver libstatgrab libsysstat breeze-icons oxygen-icons sddm firefox
            while [[ $? -ne 0 ]]; do
                echo "[$(date '+%F %T')] Installation failed, attempting to reinstall LXQT..."
                pacman -S --noconfirm xorg-server lxqt xscreensaver libstatgrab libsysstat breeze-icons oxygen-icons sddm firefox
            done
            systemctl enable sddm
            Install_fonts
            ;;
    esac
fi

setSSHConfig() {
    # Set SSH Config
    which ssh &> /dev/null
    if [ $? -eq 0 ];then
        sed -i "s/#PermitRootLogin /PermitRootLogin yes \#/" /etc/ssh/sshd_config
        systemctl enable sshd
    fi
}

if [ -f /root/server.list ];then
    echo "[$(date '+%F %T')] Preparing to install server package(s)"; sleep 1s
    for PACK in `cat /root/server.list`; do
        echo "[$(date '+%F %T')] Installing $PACK..."
        pacman -S $PACK --noconfirm
    done
    setSSHConfig
fi

if [ -f /root/addPacks.list ];then
    echo "[$(date '+%F %T')] Preparing to install additional package(s)..."; sleep 1s
    for PACK in `cat /root/addPacks.list`; do
        echo "[$(date '+%F %T')] Installing $PACK..."
        pacman -S $PACK --noconfirm
    done
    setSSHConfig
fi

echo "[$(date '+%F %T')] Installing grub..."
if [[ $(cat /root/.is_efi) == '1' ]]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/EFI/ --bootloader-id=GRUB
    if [ $? -ne 0 ];then
        echo "[$(date '+%F %T')] ERROR: Grub is not installed! Please install grub at first."
        sleep 2s
        exit 1
    fi
else
    grub-install --target=i386-pc /dev/$INSTALL_DISK
    if [ $? -ne 0 ];then
        echo "[$(date '+%F %T')] ERROR: Grub is not installed! Please install grub at first."
        sleep 2s
        exit 1
    fi
fi

echo "[$(date '+%F %T')] making boot config for grub..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "[$(date '+%F %T')] Cleaning Installation Environment."
rm -rf /root/.iconfig /root/install.sh /root/addPacks.list /root/server.list 

echo "[$(date '+%F %T')] Exit Installation Environment."
exit    