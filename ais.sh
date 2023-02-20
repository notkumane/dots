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
pacstrap /mnt base base-devel intel-ucode linux-zen linux-zen-headers dkms neovim networkmanager

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set the root password
echo "root:$ROOT_PASS" | chpasswd

# Enable parallel downloads in pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# Uncomment en_US.UTF-8 UTF-8 in /etc/locale.gen
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

# Generate the locale
locale-gen

# Set the LANG variable in /etc/locale.conf
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Install and configure grub
pacman -S grub efibootmgr dosfstools os-prober mtools --noconfirm
mkdir /boot/efi
mount /dev/sda1 /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# Set the hostname
echo "Enter the hostname:"
read HOSTNAME
echo "$HOSTNAME" > /etc/hostname

# Set up hosts file
echo "127.0.0.1	localhost" >> /etc/hosts
echo "::1		localhost" >> /etc/hosts
echo "127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME" >> /etc/hosts

# Create user
useradd -m -G wheel,audio,video,optical,storage notkeemane

# Set user password
echo "Enter password for user notkeemane:"
read -s USER_PASS
echo "notkeemane:$USER_PASS" | chpasswd

# Allow user to use sudo without password
echo "notkeemane ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Enable NetworkManager service
systemctl enable NetworkManager.service

EOF

# Prompt for reboot
read -p "Installation complete. Reboot now? [y/n]: " REBOOT
if [ "$REBOOT" = "y" ]; then
  reboot
else
  echo "You can now exit chroot and reboot later to boot into the new system."
fi
