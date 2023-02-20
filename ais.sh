#!/bin/bash

# Prompts for root password, notkeemane password and hostname
echo "Enter password for root user:"
read -s ROOT_PASSWD

echo "Enter password for notkeemane user:"
read -s USER_PASSWD

echo "Enter hostname:"
read HOSTNAME
set -e

# Prompt the user to select a drive for partitioning
printf "Please select a drive to partition:\n"
lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac
read -rp "Drive: " drive

# Partition the drive
wipefs --all "${drive}"
parted -a opt -s "$drive" mklabel gpt
existing_partitions=$(parted "$drive" print | awk '/^ / {print $1}')
if [[ -z "$existing_partitions" ]]; then
  # No existing partitions, create all partitions from the beginning
  parted -a opt -s "$drive" mkpart efi fat32 1MiB 512MiB \
        set 1 esp on \
        mkpart swap linux-swap 512MiB 8.5GiB \
        mkpart root ext4 8.5GiB 100%
else
  # Existing partitions, find the last partition and create new partitions after it
  last_partition=$(echo "$existing_partitions" | tail -n 1)
  last_partition_end=$(parted "$drive" unit MiB print free | awk "/$last_partition/ {print \$3}")
  parted -a opt -s "$drive" mkpart efi fat32 1MiB "$((last_partition_end + 1))MiB" \
        set 2 esp on \
        mkpart swap linux-swap "$((last_partition_end + 1))MiB" "$((last_partition_end + 8.5))MiB" \
        mkpart root ext4 "$((last_partition_end + 8.5))MiB" 100%
fi

# Format the partitions
mkfs.fat -F32 "${drive}1"
mkswap "${drive}2"
swapon "${drive}2"
mkfs.ext4 "${drive}3"

# Create mount points for root and efi partitions
mount --mkdir "${drive}3" /mnt
mount --mkdir "${drive}1" /mnt/boot

# Enable multilib repository in pacman.conf
sed -i '/\[multilib\]/{n;s/^#//;};/\[community\]/{n;n;s/^#//;}' /etc/pacman.conf

# Find the line with "Include" for the default repositories
repo_line=$(grep -n '/etc/pacman.d/mirrorlist' /etc/pacman.conf | cut -d ':' -f 1)

# Enable multilib repository in the default repository list
sed -i "${repo_line}s/^#//" /etc/pacman.conf

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

pacstrap /mnt base base-devel linux-zen linux-zen-headers intel-ucode networkmanager neovim dkms

# Generating the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Chrooting into the new system
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

# Install and configure packages
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
git clone https://aur.archlinux.org/brave-bin.git && cd brave-bin && makepkg -si && cd .. && rm -rf brave-bin
pacman -S --noconfirm xorg plasma-desktop dolphin konsole kscreen sddm pulseaudio plasma-nm plasma-pa kdeplasma-addons kde-gtk-config 
systemctl enable sddm

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# set the keymap to fi
echo 'Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "fi"
EndSection' | tee /etc/X11/xorg.conf.d/00-keyboard.conf

EOF

# Unmount partitions
umount -R /mnt

# Reboot
reboot
