#!/bin/bash

# Prompt for the root password
echo "Enter the root password:"
read -s ROOT_PASS

# Partition the disk
cfdisk /dev/sda

# Format the partitions
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.ext4 /dev/sda3
mkfs.ext4 /dev/sda4

# Mount the partitions
swapon /dev/sda2
mount /dev/sda3 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir /mnt/home
mount /dev/sda4 /mnt/home

# Install the base system
pacstrap /mnt base base-devel intel-ucode linux-zen linux-zen-headers dkms

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set the root password
echo "root:$ROOT_PASS" | chpasswd

# Install and configure grub
pacman -S grub efibootmgr dosfstools os-prober mtools --noconfirm
mkdir /boot/efi
mount /dev/sda1 /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Create user
useradd -m -G wheel,audio,video,optical,storage notkeemane

# Set user password
echo "Enter password for user notkeemane:"
read -s USER_PASS
echo "notkeemane:$USER_PASS" | chpasswd

# Allow user to use sudo without password
echo "notkeemane ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

EOF

# Unmount the partitions and reboot
umount -R /mnt
reboot
