#!/bin/bash

# Set up clock
timedatectl set-ntp true

# Partitioning the disk
cfdisk

# Formatting the partitions
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

# Mounting the partitions
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

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

pacstrap /mnt base linux-zen linux-zen-headers intel-ucode networkmanager neovim dkms

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

# set the keymap to fi
echo "Setting keymap to fi"
echo "KEYMAP=fi" > /etc/vconsole.conf
loadkeys fi

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable dkms
systemctl enable dkms.service

EOF

# Unmount all partitions and reboot
umount -R /mnt
reboot_prompt() {
  while true; do
    read -p "Do you want to reboot now? [y/n]: " reboot_choice
    case "$reboot_choice" in
      [Yy]* ) reboot; break;;
      [Nn]* ) exit;;
      * ) echo "Please answer 'y' or 'n'.";;
    esac
  done
}

reboot_prompt
