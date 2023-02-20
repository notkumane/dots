#!/bin/bash

# Ask user for disk device to partition
echo "Available disks:"
lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop"
read -p "Enter disk to partition: " disk

# Ensure disk is set as GPT
parted -s "$disk" mklabel gpt

# Create EFI partition
parted -s "$disk" mkpart primary fat32 1MiB 513MiB
parted -s "$disk" set 1 esp on

# Show available space on disk
echo "Available space on $disk:"
lsblk -plnx size -o name,size $disk

# Prompt user for partition sizes
read -p "Enter swap partition size (in GB): " swap_size
swap_end=$((513+swap_size*1024))
parted -s "$disk" mkpart primary linux-swap 513MiB ${swap_end}MiB

# Update available space on disk
echo "Estimated space left on $disk after swap partition:"
lsblk -plnx size -o name,size $disk | tail -n 1

read -p "Enter root partition size (in GB): " root_size
root_end=$((swap_end+root_size*1024))
parted -s "$disk" mkpart primary ext4 ${swap_end}MiB ${root_end}MiB

# Update available space on disk
echo "Estimated space left on $disk after root partition:"
lsblk -plnx size -o name,size $disk | tail -n 1

read -p "Enter home partition size (in GB): " home_size
home_end=$((root_end+home_size*1024))
parted -s "$disk" mkpart primary ext4 ${root_end}MiB ${home_end}MiB

# Verify partition sizes do not exceed disk size
disk_size=$(lsblk -bdno SIZE $disk)
if [ $((home_end*1024)) -gt $disk_size ]; then
  echo "Error: partition sizes exceed disk size"
  exit 1
fi

# Formatting the partitions
mkswap "${disk}2"
mkfs.ext4 "${disk}3"
mkfs.ext4 "${disk}4"
mkfs.fat -F32 "${disk}1"

# Mounting the partitions
mount "${disk}3" /mnt
mkdir /mnt/home
mount "${disk}4" /mnt/home
swapon "${disk}2"

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