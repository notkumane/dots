#!/bin/bash

# Function to prompt user for input and validate against a regular expression
function get_input {
    local prompt=$1
    local regex=$2
    local error_msg=$3
    read -rp "$prompt" input
    if ! [[ $input =~ $regex ]]; then
        echo "$error_msg"
        get_input "$prompt" "$regex" "$error_msg"
    fi
    echo "$input"
}

# List all available block devices and prompt the user to select one
echo "Available block devices:"
devices=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop")
echo "$devices"
device=$(get_input "Enter the device name to partition (e.g. /dev/sda): " "^/dev/.*$" "Invalid device name. Enter a valid device name (e.g. /dev/sda): ")
echo "Partitioning $device..."

# Create EFI partition
echo "Creating EFI partition..."
parted -s "$device" mklabel gpt
parted -s "$device" mkpart primary fat32 1MiB 1000MiB
parted -s "$device" set 1 esp on
mkfs.fat -F32 "${device}1"

# Ask user about swap partition
get_input "Do you want to create a swap partition? (y/n)" "^[yn]$" "Invalid input. Enter 'y' for yes or 'n' for no."
swap_answer=$input

if [[ $swap_answer == "y" ]]; then
  # Prompt for swap size in GB and calculate size in MiB
  swap_size_gb=$(get_input "Enter the size of the swap partition in GB (e.g. 2): " "^[0-9]+$" "Invalid input. Enter a positive integer.")
  swap_size_mib=$((swap_size_gb * 1024))
  
  # Create swap partition
  echo "Creating swap partition..."
  parted -s "$device" mkpart primary linux-swap 1000MiB "${swap_size_mib}MiB"
  mkswap "${device}2"
  swapon "${device}2"
fi

# Prompt for root partition size in GB and calculate size in MiB
root_size_gb=$(get_input "Enter the size of the root partition in GB (e.g. 20): " "^[0-9]+$" "Invalid input. Enter a positive integer.")
root_size_mib=$((root_size_gb * 2048))

# Create root partition
echo "Creating root partition..."
parted -s "$device" mkpart primary ext4 "${swap_size_mib:-0}MiB" "${root_size_mib}MiB"
mkfs.ext4 "${device}3"

# Allocate all remaining space to home partition
echo "Creating home partition..."
parted -s "$device" mkpart primary ext4 "${root_size_mib}MiB" 100%
mkfs.ext4 "${device}4"

# Mount the partitions
echo "Mounting partitions..."
mount "${device}3" /mnt
mkdir /mnt/boot
mount "${device}1" /mnt/boot
mkdir /mnt/home
mount "${device}4" /mnt/home

echo "Partitioning complete!"

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