#!/bin/bash

# Prompt the user to select the device to partition
echo "Please select the device to partition:"
lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac
read -rp "Device: " device

echo "Partitioning $device..."

# Create EFI partition
echo "Creating EFI partition..."
parted -s "$device" mklabel gpt
parted -s "$device" mkpart primary fat32 1MiB 1GiB
parted -s "$device" set 1 esp on

# Ask user about swap partition
echo "Do you want to create a swap partition? (y/n)"
read -r swap_answer

if [[ $swap_answer == "y" ]]; then
  # Create swap partition
  echo "Enter the size of the swap partition (e.g. 2G)"
  read -r swap_size
  echo "Creating swap partition..."
  parted -s "$device" mkpart primary linux-swap 1GiB $swap_size
  mkswap "${device}2"
  swapon "${device}2"
fi

# Create root partition
echo "Creating root partition..."
parted -s "$device" mkpart primary ext4 $((1 + ${swap_size:-0}))GiB 11GiB
mkfs.ext4 "${device}3"

# Allocate all remaining space to home partition
echo "Creating home partition..."
parted -s "$device" mkpart primary ext4 11GiB 100%
mkfs.ext4 "${device}4"

# Mount the partitions
echo "Mounting partitions..."
mount "${device}3" /mnt
mkdir /mnt/boot
mount "${device}1" /mnt/boot
mkdir /mnt/home
mount "${device}4" /mnt/home

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

# Enable NTP
systemctl enable systemd-timesyncd.service
systemctl start systemd-timesyncd.service

# Unmount partitions
umount -R /mnt
reboot