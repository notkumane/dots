#!/bin/bash

# Prompt the user to select a drive for partitioning
echo "Please select a drive to partition:"
lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac
read -p "Drive: " drive

# Partition the drive
parted -a opt -s "$drive" mklabel gpt \
      mkpart efi fat32 1MiB 512MiB \
      set 1 esp on \
      mkpart swap linux-swap 512MiB 8.5GiB \
      mkpart root ext4 8.5GiB 100%

# Format the partitions
mkfs.fat -F32 "${drive}1"
mkswap "${drive}2"
mkfs.ext4 "${drive}3"

# Create mount points and mount the partitions
mkdir -p /mnt/boot/efi
mount "${drive}3" /mnt
mount "${drive}1" /mnt/boot/efi

# Enable swap partition
swapon "${drive}2"

echo "Partitioning complete."

# Prompts for root password, notkeemane password and hostname
echo "Enter password for root user:"
read -s ROOT_PASSWD

echo "Enter password for notkeemane user:"
read -s USER_PASSWD

echo "Enter hostname:"
read HOSTNAME

# Installing Arch Linux
pacman -Sy --noconfirm pacman-contrib
echo "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

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

# set the keymap to fi
echo "Setting keymap to fi"
echo "KEYMAP=fi" > /etc/vconsole.conf
loadkeys fi

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Unmount partitions
umount -R /mnt

# Reboot
reboot
