#!/bin/bash

printf "Available drives:\n"
drives=($(lsblk -dpn | grep -Ev "boot|rpmb|loop" | awk '{print $1}'))
if [ ${#drives[@]} -eq 0 ]; then
printf "No drives found.\n"
exit 1
fi
for i in "${!drives[@]}"; do
printf "%d.%s\n" "$i" "${drives[$i]}"
done
read -rp "Enter the number of the drive to partition: " drive_num
if ! [[ "$drive_num" =~ ^[0-9]+$ ]] || [ "$drive_num" -lt 0 ] || [ "$drive_num" -ge ${#drives[@]} ]; then
printf "Invalid drive number.\n"
exit 1
fi
drive="${drives[$drive_num]}"
read -rp "You have selected $drive for partitioning. Are you sure? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
printf "Partitioning cancelled.\n"
exit 1
fi
if ! [ -b "$drive" ]; then
printf "Drive %s does not exist.\n" "$drive"
exit 1
fi
wipefs -a "$drive"
sgdisk -g "$drive"
sgdisk -n 1:0:+512MiB -t 1:EF00 "$drive"
sgdisk -n 2:0:+8GiB -t 2:8200 "$drive"
sgdisk -n 3:0:0 -t 3:8300 "$drive"
mkfs.fat -F32 "${drive}1"
mkswap "${drive}2"
swapon "${drive}2"
mkfs.btrfs -f "${drive}3"
mount --mkdir "${drive}3" /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@boot
umount /mnt
mount -o subvol=@root "${drive}3" /mnt
mkdir /mnt/{home,var,.snapshots,boot}
mount -o subvol=@home "${drive}3" /mnt/home
mount -o subvol=@var "${drive}3" /mnt/var
mount "${drive}1" /mnt/boot

# Prompts for root password, notkeemane password and hostname
echo "Enter password for root user:"
read -s ROOT_PASSWD

echo "Enter password for notkeemane user:"
read -s USER_PASSWD

echo "Enter hostname:"
read HOSTNAME

pacman -Sy --noconfirm pacman-contrib
echo "Server = http://mirror.neuf.no/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
echo "Server = https://ftp.acc.umu.se/mirror/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://ftp.lysator.liu.se/pub/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://mirror.sjtu.edu.cn/arch/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://ftp.sunet.se/mirror/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://mirror.23media.com/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://ftp.portlane.com/pub/os/linux/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://ftp.gwdg.de/pub/linux/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://ftp.funet.fi/pub/mirrors/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://mirrors.lavatech.top/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist

# Enable parallel downloads
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

pacstrap /mnt base base-devel linux-zen linux-zen-headers dkms intel-ucode networkmanager linux-firmware

# Generating the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF

# Set the time zone and hardware clock
ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
hwclock --systohc

# Set up the locale
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname and hosts
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1    localhost" > /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME" >> /etc/hosts

# Enable NetworkManager
systemctl enable NetworkManager

# Set root password and create notkeemane user
echo "root:$ROOT_PASSWD" | chpasswd
useradd -m -s /bin/bash notkeemane
echo "notkeemane:$USER_PASSWD" | chpasswd

# Set up sudo for notkeemane
echo "notkeemane ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install Git
pacman -S --needed --noconfirm git

# Build and install yay
cd /tmp
sudo -u notkeemane git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u notkeemane makepkg -si --noconfirm

# Download configs
cd /tmp
git clone https://github.com/notkumane/dots
cd dots
cp .xinitrc .xprofile .zshenv /home/notkeemane
cp -r .zsh /home/notkeemane
mkdir -p /home/notkeemane/.config/i3
cp config /home/notkeemane/.config/i3
cp starship.toml picom.conf /home/notkeemane/.config

# Download ZSH plugin
cd /home/notkeemane/.zsh
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git

# Enable multilib and sync databases
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sudo pacman -Sy

# Install Wine dependencies
yay -S --needed --noconfirm giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls \
mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error \
lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo \
sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama \
ncurses lib32-ncurses ocl-icd lib32-ocl-icd libxslt lib32-libxslt libva lib32-libva gtk3 \
lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader lutris steam

# Install Nvidia drivers and other Xorg-related packages
yay -S --needed --noconfirm nvidia xorg-server xorg-xinit xorg-xset xorg-xrandr

# Install i3-gaps and other window manager-related packages
yay -S --needed --noconfirm i3-gaps nitrogen xfce4-panel xfce4-notifyd autotiling \
brave-bin gnome-screenshot xfce4-terminal thunar xarchiver gvfs unrar picom xdg-utils \
xdg-user-dirs ristretto lxappearance zsh neovim exa htop xfce4-i3-workspaces-plugin-git starship gamemode ttf-firacode-nerd

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/mnt/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Set the keymap to fi
echo 'Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "fi"
EndSection' | tee /etc/X11/xorg.conf.d/00-keyboard.conf

# Set the keymap to "fi" in vconsole.conf
echo "KEYMAP=fi" >> /etc/vconsole.conf

chsh -s $(which zsh) notkeemane
EOF

# Unmount partitions
umount -R /mnt

# Reboot
reboot

