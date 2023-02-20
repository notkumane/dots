#!/bin/bash

echo "Setting up the disks..."

lsblk

echo -n "Enter the device to use as root (eg. /dev/sda): "
read ROOT_DEVICE

echo -n "Enter the swap size in GiB (eg. 2): "
read SWAP_SIZE

echo "Setting up the partitions..."

sgdisk --zap-all $ROOT_DEVICE
sgdisk --new=1:0:+512MiB --typecode=1:ef00 $ROOT_DEVICE
sgdisk --new=2:0:+${SWAP_SIZE}GiB --typecode=2:8200 $ROOT_DEVICE
sgdisk --new=3:0:0 --typecode=3:8300 $ROOT_DEVICE
mkfs.fat -F32 ${ROOT_DEVICE}1
mkswap ${ROOT_DEVICE}2
mkfs.ext4 ${ROOT_DEVICE}3
swapon ${ROOT_DEVICE}2
mount ${ROOT_DEVICE}3 /mnt
mkdir /mnt/boot
mount ${ROOT_DEVICE}1 /mnt/boot

echo "Installing the base system..."

pacstrap /mnt base linux linux-firmware neovim networkmanager
genfstab -U /mnt >> /mnt/etc/fstab

echo "Chrooting into the new system..."

echo "Enter the hostname:"
read HOSTNAME

arch-chroot /mnt /bin/bash <<EOF
echo $HOSTNAME > /etc/hostname
echo "127.0.0.1    localhost" > /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME" >> /etc/hosts

echo "Enter the root password:"
passwd

echo "Enter the notkeemane user password:"
useradd -m -G wheel -s /bin/bash notkeemane
passwd notkeemane

sed -i 's/^# %wheel ALL=(ALL) ALL$/%wheel ALL=(ALL) ALL/' /etc/sudoers
ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
hwclock --systohc
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
systemctl enable NetworkManager.service

echo "Installation complete. Reboot now? (y/n)"
read REBOOT

if [ "$REBOOT" == "y" ]; then
  reboot
else
  echo "Exiting chroot. You may now unmount the partitions and reboot."
fi
EOF
