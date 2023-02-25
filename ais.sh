#!/bin/bash

# Print a list of available drives by running lsblk, filter out drives that are not suitable for partitioning,
# and put the remaining drives into an array called $drives
printf "Available drives:\n"
drives=($(lsblk -dpn | grep -Ev "boot|rpmb|loop" | awk '{print $1}'))

# If there are no suitable drives found, print a message and exit with an error status
if [ ${#drives[@]} -eq 0 ]; then
    printf "No drives found.\n"
    exit 1
fi

# Loop through the array of drives and print out a numbered list of available drives to the user
for i in "${!drives[@]}"; do
    printf "%d.%s\n" "$i" "${drives[$i]}"
done

# Ask the user to select a drive to partition by entering the number corresponding to the drive in the list
read -rp "Enter the number of the drive to partition: " drive_num

# Check if the user input is a valid integer and within the range of available drives, otherwise exit with an error status
if ! [[ "$drive_num" =~ ^[0-9]+$ ]] || [ "$drive_num" -lt 0 ] || [ "$drive_num" -ge ${#drives[@]} ]; then
    printf "Invalid drive number.\n"
    exit 1
fi

# Set the selected drive to the variable $drive and ask for user confirmation before proceeding with partitioning
drive="${drives[$drive_num]}"
read -rp "You have selected $drive for partitioning. Are you sure? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    printf "Partitioning cancelled.\n"
    exit 1
fi

# Check if the selected drive exists, otherwise exit with an error status
if ! [ -b "$drive" ]; then
    printf "Drive %s does not exist.\n" "$drive"
    exit 1
fi

# Remove any existing file system signatures from the drive
wipefs -a "$drive"

# Create a new GPT partition table on the drive
sgdisk -g "$drive"

# Create a new EFI system partition (512 MiB)
sgdisk -n 1:0:+512MiB -t 1:EF00 "$drive"

# Create a new swap partition (8 GiB)
sgdisk -n 2:0:+8GiB -t 2:8200 "$drive"

# Create a new Btrfs partition using the rest of the drive
sgdisk -n 3:0:0 -t 3:8300 "$drive"

# Format the EFI system partition as FAT32
mkfs.fat -F32 "${drive}1"

# Format the swap partition
mkswap "${drive}2"

# Enable the swap partition
swapon "${drive}2"

# Format the Btrfs partition with subvolumes
mkfs.btrfs -f "${drive}3"

# Create a mount point for the Btrfs partition and mount it
mount --mkdir "${drive}3" /mnt

# Create subvolumes for the root, home, var, snapshots, and boot directories
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@boot

# Unmount the Btrfs partition
umount /mnt

# Mount the Btrfs partition with the root subvolume
mount -o subvol=@root "${drive}3" /mnt

# Create mount points for the home, var, snapshots, and boot subvolumes
mkdir /mnt/{home,var,.snapshots,boot}

# Mount the subvolumes
mount -o subvol=@home "${drive}3" /mnt/home
mount -o subvol=@var "${drive}3" /mnt/var
mount -o subvol=@snapshots "${drive}3" /mnt/.snapshots
mount -o subvol=@boot "${drive}3" /mnt/boot

# Create a mount point for the EFI system partition and mount it
mount --mkdir "${drive}1" /mnt/boot/efi

# Prompt the user to enter their username and store the value in the USERNAME variable
read -e -p "Please enter your username: " USERNAME

# Prompt the user to enter their password for the entered username and store the value in the USER_PASSWD variable
read -s -e -p "Please enter the password for $USERNAME user: " USER_PASSWD

# Prompt the user to enter the hostname and store the value in the HOSTNAME variable
read -e -p "Please enter the hostname: " HOSTNAME

# Prompt the user to enter the password for the root user and store the value in the ROOT_PASSWD variable
read -s -e -p "Please enter the password for root user: " ROOT_PASSWD

# Enable parallel downloads
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# Install essential packages for a basic Arch Linux system, including the Zen kernel, DKMS, Intel microcode, NetworkManager, and firmware packages
pacstrap /mnt base base-devel linux-zen linux-zen-headers dkms intel-ucode networkmanager linux-firmware

# Generate an fstab file and append it to the /mnt/etc/fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Arch-chroot into the base system
arch-chroot /mnt /bin/bash <<EOF

# Set timezone to Helsinki
ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime

# Update hardware clock to system time
hwclock --systohc

# Uncomment en_US.UTF-8 UTF-8 in locale.gen and generate locales
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

# Set LANG environment variable to en_US.UTF-8
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname and update hosts file
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1    localhost" > /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME" >> /etc/hosts

# Enable NetworkManager service
systemctl enable NetworkManager

# Set root password
echo "root:$ROOT_PASSWD" | chpasswd

# Create user and set password
useradd -m -G wheel,audio,video,optical,storage $USERNAME
echo "$USERNAME:$USER_PASSWD" | chpasswd

# Allow user to run commands with sudo without a password prompt
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install Git
pacman -S --needed --noconfirm git

# Clone yay from AUR and install it
cd /tmp
sudo -u $USERNAME git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $USERNAME makepkg -si --noconfirm

# Clone dotfiles from GitHub
cd /tmp
git clone https://github.com/notkumane/dots
cd dots

# Copy dotfiles to user's home directory
cp .xinitrc .xprofile .zshenv /home/$USERNAME
cp -r .zsh /home/$USERNAME
mkdir -p /home/$USERNAME/.config/i3
cp config /home/$USERNAME/.config/i3
cp starship.toml /home/$USERNAME/.config

# Basic picom.conf
echo -e "backend = \"glx\";\nvsync = true;\nfade-in-step = 0.03;" > /home/$USERNAME/.config/picom.conf

# Install zsh-syntax-highlighting and update zshrc to use it
cd /home/$USERNAME/.zsh
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
echo "source /home/$USERNAME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> /home/$USERNAME/.zsh/.zshrc

# Enable the [multilib] repository in pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy

# Install packages
yay -S --noconfirm giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls \
mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error \
lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo \
sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama \
ncurses lib32-ncurses ocl-icd lib32-ocl-icd libxslt lib32-libxslt libva lib32-libva gtk3 \
lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader

yay -S --noconfirm gamemode steam lutris

yay -S --noconfirm nvidia xorg-server xorg-xinit xorg-xset xorg-xrandr

yay -S --noconfirm i3-gaps nitrogen xfce4-panel xfce4-notifyd gnome-screenshot xfce4-terminal thunar \
xarchiver gvfs unrar picom xdg-utils xdg-user-dirs ristretto lxappearance xfce4-i3-workspaces-plugin-git \
autotiling brave-bin xfce4-whiskermenu-plugin-git zsh neovim exa htop starship ttf-firacode-nerd

# Install bootloader
yay -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Set Keymaps
echo 'Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "fi"
EndSection' | tee /etc/X11/xorg.conf.d/00-keyboard.conf
echo "KEYMAP=fi" >> /etc/vconsole.conf

# Change default shell to zsh
chsh -s $(which zsh) $USERNAME

EOF
echo "Installation complete. Do you want to stay in the chroot environment? (y/n)"
read stay_in_chroot

if [[ "$stay_in_chroot" =~ [yY](es)* ]]; then
    echo "You are still in the chroot environment. To exit, type 'exit'."
else
    echo "Exiting chroot..."
    exit
fi

echo "Do you want to reboot now? (y/n)"
read reboot_confirmation

if [[ "$reboot_confirmation" =~ [yY](es)* ]]; then
    echo "Unmounting partitions and rebooting..."
    umount -R /mnt
    reboot
else
    echo "You chose not to reboot. Remember to reboot before using your new system."
fi

