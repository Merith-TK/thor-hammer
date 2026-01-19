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
echo "📦 Updating packages..."
pacman -Syu --noconfirm

# Enable color output in pacman
echo "🎨 Enabling color output in pacman..."
sed -i 's/^#Color/Color/' /etc/pacman.conf

# Install essential packages (required for boot and basic functionality)
echo "🛠️  Installing essential packages..."
pacman -S --noconfirm \
    base \
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

# Build and install Ayn Thor packages
echo "🔨 Building and installing Ayn Thor-specific packages..."
echo "  -> Cloning ayn-thor-arch repository..."

# Create a temporary working directory
mkdir -p /tmp/thor-build
cd /tmp/thor-build

# Clone the repository
git clone --depth 1 https://github.com/Kitsumi/ayn-thor-arch.git || {
    echo "❌ Failed to clone repository"
    exit 1
}

cd ayn-thor-arch/packages

# Function to build and install a package as a regular user
build_package() {
    local pkg_dir="$1"
    local pkg_name="$2"
    
    echo "  -> Building $pkg_name..."
    cd "$pkg_dir"
    
    # Create temporary user for building (makepkg doesn't allow root)
    if ! id builder &>/dev/null; then
        useradd -m -G wheel builder
        echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
    fi
    
    # Change ownership to builder user
    chown -R builder:builder /tmp/thor-build
    
    # Build the package as builder user
    su - builder -c "cd /tmp/thor-build/ayn-thor-arch/packages/$pkg_dir && makepkg -s --noconfirm" || {
        echo "❌ Failed to build $pkg_name"
        return 1
    }
    
    # Install the package
    pacman -U --noconfirm *.pkg.tar.* || {
        echo "❌ Failed to install $pkg_name"
        return 1
    }
    
    cd ..
    echo "  ✅ $pkg_name installed successfully"
}

# Build and install packages in order
build_package "linux-firmware-ayn-thor" "Thor firmware" && \
build_package "linux-ayn-thor" "Thor kernel" && \
build_package "grub-dtb" "GRUB with device tree support"

# Clean up
echo "  -> Cleaning up build artifacts..."
cd /
rm -rf /tmp/thor-build
userdel -r builder 2>/dev/null || true
rm -f /etc/sudoers.d/builder

echo "✅ Ayn Thor packages built and installed"

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

# Generate initramfs with Thor firmware
echo "🔧 Generating initramfs with Thor firmware..."
mkinitcpio -P || echo "⚠️  mkinitcpio generation had warnings"

# Configure GRUB
echo "🚀 Configuring GRUB bootloader..."
# GRUB is already installed via grub-dtb package above
# Install GRUB to the boot partition
grub-install --target=arm64-efi --efi-directory=/boot --bootloader-id=GRUB --removable --recheck || echo "⚠️  GRUB install had warnings"

# Generate GRUB configuration
echo "  -> Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg || echo "⚠️  GRUB config generation had warnings"
echo "  ✅ GRUB configured"

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
echo "  - Thor-specific kernel, firmware, and bootloader installed"
echo "  - GRUB configured with device tree support"
echo ""
echo "🔒 SECURITY NOTE: Change default passwords on first boot!"