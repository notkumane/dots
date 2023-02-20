#!/bin/bash

# Prompt for the root password
read -sp 'Enter the root password: ' ROOT_PASS
echo ""

# Prompt for the hostname
read -p 'Enter the hostname: ' HOST_NAME

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
pacstrap /mnt base base-devel intel-ucode linux-zen linux-zen-headers dkms networkmanager neovim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set the root password
echo "root:$ROOT_PASS" | chpasswd

# Uncomment en_US.UTF-8 in /etc/locale.gen and generate locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

# Set the LANG variable in /etc/locale.conf
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set the hostname
echo "$HOST_NAME" > /etc/hostname

# Update /etc/hosts file
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $HOST_NAME.localdomain    $HOST_NAME" >> /etc/hosts

# Enable NetworkManager service
systemctl enable NetworkManager

# Install and configure grub
pacman -S grub efibootmgr dosfstools os-prober mtools --noconfirm
mkdir /boot/efi
mount /dev/sda1 /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Create user
useradd -m -G wheel,audio,video,optical,storage notkeemane

# Set user password
read -sp 'Enter password for user notkeemane: ' USER_PASS
echo ""
echo "notkeemane:$USER_PASS" | chpasswd

# Allow user to use sudo without password
echo "notkeemane ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

EOF

# Ask the user whether to reboot or stay in chroot
read -p "Installation complete. Reboot now? (y/n) " REBOOT

# If user enters "y", reboot the system
if [[ "$REBOOT" =~ [Yy] ]]; then
    umount -R /mnt
    reboot
fi
