#!/bin/bash

# List available drives
printf "Available drives:\n"
drives=( $(lsblk -dpn | grep -Ev "boot|rpmb|loop" | awk '{print $1}') )

# Check if any drives are available
if [ ${#drives[@]} -eq 0 ]; then
    printf "No drives found.\n"
    exit 1
fi

# Display the list of available drives
for i in "${!drives[@]}"; do
    printf "%d. %s\n" "$i" "${drives[$i]}"
done

# Prompt the user to select a drive for partitioning
read -rp "Enter the number of the drive to partition: " drive_num

# Verify that the selected drive number is valid
if ! [[ "$drive_num" =~ ^[0-9]+$ ]] || [ "$drive_num" -lt 0 ] || [ "$drive_num" -ge ${#drives[@]} ]; then
    printf "Invalid drive number.\n"
    exit 1
fi

# Get the name of the selected drive
drive="${drives[$drive_num]}"

# Confirm the selected drive with the user
read -rp "You have selected $drive for partitioning. Are you sure? (y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    printf "Partitioning cancelled.\n"
    exit 1
fi

# Verify that the selected drive exists
if ! [ -b "$drive" ]; then
    printf "Drive %s does not exist.\n" "$drive"
    exit 1
fi

# Wipe the drive with wipefs
printf "Wiping drive %s...\n" "$drive"
wipefs -a "$drive"

# Partition the drive with gdisk
printf "Partitioning drive %s...\n" "$drive"
printf "Creating partition 1 (EFI System Partition)...\n"
sgdisk -n 1:0:+512MiB -t 1:EF00 "$drive"
printf "Creating partition 2 (Linux Swap)...\n"
sgdisk -n 2:0:+8GiB -t 2:8200 "$drive"
printf "Creating partition 3 (Linux Filesystem)...\n"
sgdisk -n 3:0:0 -t 3:8300 "$drive"

# Format the partitions
printf "Formatting partitions...\n"
mkfs.fat -F32 "${drive}1"
mkswap "${drive}2"
swapon "${drive}2"
mkfs.ext4 "${drive}3"

# Mount the partitions
printf "Mounting partitions...\n"
mount --mkdir "${drive}3" /mnt
mount --mkdir "${drive}1" /mnt/boot

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

pacstrap /mnt base base-devel linux-zen linux-zen-headers intel-ucode networkmanager

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
mkdir -p /home/notkeemane/.zsh
cp -r .zsh /home/notkeemane/.zsh
mkdir -p /home/notkeemane/.config/i3
cp config /home/notkeemane/.config/i3
cp starship.toml picom.conf /home/notkeemane/.config

# Download ZSH plugin
cd /home/notkeemane/.zsh
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git

# Install packages with yay
yay -S --needed --noconfirm wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls \
mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error \
lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo \
sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama \
ncurses lib32-ncurses ocl-icd lib32-ocl-icd libxslt lib32-libxslt libva lib32-libva gtk3 \
lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader lutris steam

yay -S --noconfirm nvidia xorg-server xorg-xinit xorg-xset xorg-xrandr i3-gaps nitrogen xfce4-panel xfce4-notifyd autotiling brave-bin gnome-screenshot xfce4-terminal thunar xarchiver gvfs unrar picom xdg-utils xdg-user-dirs ristretto lxappearance zsh neovim exa htop xfce4-i3-workspaces-plugin-git starship gamemode

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
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

