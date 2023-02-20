#!/bin/bash

# Prompt the user to select a drive for partitioning
echo "Please select a drive to partition:"
lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac
read -p "Drive: " drive

# Create the EFI partition
echo "Creating EFI partition..."
echo -e "n\np\n1\n\n+512M\nt\n1\n1\nw" | fdisk "$drive"
mkfs.fat -F32 "${drive}1"

# Create the Swap partition
echo "Creating Swap partition..."
echo -e "n\np\n2\n\n+8G\nt\n2\n82\nw" | fdisk "$drive"
mkswap "${drive}2"
swapon "${drive}2"

# Create the Root/Home partition
echo "Creating Root/Home partition..."
echo -e "n\np\n3\n\n\nw" | fdisk "$drive"
mkfs.ext4 "${drive}3"

# Mount the partitions
mount "${drive}3" /mnt
mkdir /mnt/boot
mount "${drive}1" /mnt/boot/efi

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
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable dkms
systemctl enable dkms.service

# Enable NTP
systemctl enable systemd-timesyncd.service
systemctl start systemd-timesyncd.service

# Unmount partitions
umount -R /mnt
reboot