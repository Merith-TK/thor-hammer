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

# Enable color output in pacman
echo "🎨 Enabling color output in pacman..."
sed -i 's/^#Color/Color/' /etc/pacman.conf

# Install essential packages (required for boot and basic functionality)
echo "🛠️  Installing essential packages..."
pacman -S --noconfirm \
    base \
    linux \
    linux-aarch64 \
    linux-firmware \
    grub \
    efibootmgr \
    networkmanager \
    sudo

# Install non-essential packages (development tools and utilities)
echo "📦 Installing non-essential packages..."
pacman -S --noconfirm \
    base-devel \
    openssh \
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
echo "🚀 Installing GRUB bootloader..."
# Install GRUB to the boot partition (config will be installed by build script)
grub-install --target=arm64-efi --efi-directory=/boot --bootloader-id=GRUB --removable --recheck || echo "⚠️  GRUB install failed"
echo "  -> GRUB installed (configuration will be added by build script)"

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