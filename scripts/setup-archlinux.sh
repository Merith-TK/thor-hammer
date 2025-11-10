#!/bin/bash
# Thor Hammer - Arch Linux ARM Setup Script
# This script runs inside the chroot to configure the Arch Linux ARM system

set -e

echo "🏗️  Thor Hammer Arch Linux ARM Setup Starting..."

# Initialize pacman keyring (required for Arch Linux ARM)
echo "🔑 Initializing pacman keyring..."
pacman-key --init || echo "Keyring init failed, continuing..."
pacman-key --populate archlinuxarm || echo "ARM keyring population failed, continuing..."

# Update package database
echo "📦 Updating package database..."
pacman -Sy --noconfirm

# Install essential packages
echo "🛠️  Installing essential packages..."
pacman -S --noconfirm \
    base \
    base-devel \
    linux \
    linux-aarch64 \
    linux-firmware \
    grub \
    efibootmgr \
    networkmanager \
    openssh \
    sudo \
    nano \
    vim \
    wget \
    curl \
    git \
    htop \
    tree

# Enable NetworkManager
echo "🌐 Enabling NetworkManager..."
systemctl enable NetworkManager

# Enable SSH
echo "🔒 Enabling SSH service..."
systemctl enable sshd

# Create a user account
echo "👤 Creating user 'thor'..."
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash thor || echo "User already exists"

# Set up sudo for wheel group
echo "⚙️  Configuring sudo..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Set hostname
echo "🏷️  Setting hostname to 'thor-hammer'..."
echo "thor-hammer" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   thor-hammer.localdomain thor-hammer
EOF

# Set timezone to UTC (user can change later)
echo "🕐 Setting timezone to UTC..."
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Generate locale
echo "🌍 Generating en_US.UTF-8 locale..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set default passwords (CHANGE THESE!)
echo "🔐 Setting default passwords..."
echo "root:thor-hammer" | chpasswd
echo "thor:thor-hammer" | chpasswd

# Configure GRUB
echo "🚀 Configuring GRUB bootloader..."
# Fix kernel naming for GRUB detection (Arch ARM uses 'Image' instead of 'vmlinuz')
if [ -f /boot/Image ] && [ ! -f /boot/vmlinuz-linux ]; then
    echo "  -> Creating vmlinuz symlink for GRUB detection..."
    cp /boot/Image /boot/vmlinuz-linux
fi
# Install GRUB to the boot partition
grub-install --target=arm64-efi --efi-directory=/boot --bootloader-id=GRUB --removable --recheck || echo "GRUB install failed, will need manual setup"
# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg || echo "GRUB config failed, will need manual setup"

# Create a basic motd
cat > /etc/motd << 'EOF'
 _____ _               _   _                                     
|_   _| |__   ___  _ _| | | | __ _ _ __ ___  _ __ ___   ___ _ __ 
  | | | '_ \ / _ \| '_| |_| |/ _` | '_ ` _ \| '_ ` _ \ / _ \ '__|
  | | | | | | (_) | | |  _  | (_| | | | | | | | | | | |  __/ |   
  |_| |_| |_|\___/|_| |_| |_|\__,_|_| |_| |_|_| |_| |_|\___|_|   
                                                                 
  Arch Linux ARM - Thor Hammer Build
  
  Default login: thor / thor-hammer
  Root password: thor-hammer
  
  ⚠️  CHANGE DEFAULT PASSWORDS IMMEDIATELY! ⚠️
  
EOF

echo "✅ Arch Linux ARM setup completed!"
echo ""
echo "📋 Summary:"
echo "  - User 'thor' created (password: thor-hammer)"
echo "  - Root password: thor-hammer" 
echo "  - NetworkManager and SSH enabled"
echo "  - Essential packages installed"
echo "  - GRUB configured"
echo ""
echo "🔒 SECURITY NOTE: Change default passwords on first boot!"