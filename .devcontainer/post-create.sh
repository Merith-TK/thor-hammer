#!/bin/bash
# Thor Hammer - Post Creation Setup Script
# Installs cross-compilation tools and Android boot development dependencies

set -e

echo "🛠️  Installing cross-compilation and boot development tools..."

# Install cross-compilation toolchain and development tools
sudo pacman -S --noconfirm \
    git \
    github-cli \
    bc \
    bison \
    flex \
    ncurses \
    openssl \
    libelf \
    dtc \
    uboot-tools \
    dosfstools \
    e2fsprogs \
    parted \
    multipath-tools \
    qemu-user-static \
    qemu-system-aarch64 \
    qemu-img \
    util-linux \
    tar \
    rsync

# Install AUR helper packages for cross-compilation
echo "📥 Installing cross-compilation toolchain from AUR..."
yay -S --noconfirm --needed \
    aarch64-linux-gnu-gcc \
    aarch64-linux-gnu-binutils \
    aarch64-linux-gnu-glibc || echo "⚠️  Cross-compiler may need manual installation"


# Set up development environment
echo "⚙️  Configuring development environment..."

# Create useful aliases and environment setup
cat >> ~/.bashrc << 'EOF'

# Thor Hammer Development Environment
export THOR_HAMMER_ROOT="/workspaces/.thor-hammer"
export CROSS_COMPILE="aarch64-linux-gnu-"
export ARCH="arm64"
export PATH="$HOME/.local/bin:$PATH"

# Cross-compilation helpers
export KBUILD_BUILD_USER="thor-hammer"
export KBUILD_BUILD_HOST="devcontainer"

# Useful aliases
alias ls='ls --color=auto'
alias ll='ls -la --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias thor-cd='cd $THOR_HAMMER_ROOT'
alias thor-build='cd $THOR_HAMMER_ROOT && ./scripts/build.sh'
alias thor-logs='tail -f $THOR_HAMMER_ROOT/logs/*.log 2>/dev/null || echo "No logs found"'

# Function to check cross-compiler
check-crossgcc() {
    echo "🔍 Checking cross-compilation setup..."
    echo "Cross-compiler: ${CROSS_COMPILE}gcc"
    ${CROSS_COMPILE}gcc --version 2>/dev/null || echo "❌ Cross-compiler not found"
    echo "Target architecture: $ARCH"
    echo "Build user: $KBUILD_BUILD_USER"
    echo "Build host: $KBUILD_BUILD_HOST"
}

# Function to show Thor Hammer status
thor-status() {
    echo "🔨 Thor Hammer Development Environment Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 Workspace: $THOR_HAMMER_ROOT"
    echo "🎯 Target: $ARCH"
    echo "🛠️  Compiler: $CROSS_COMPILE"
    echo ""
    check-crossgcc
    echo ""
    echo "📋 Available commands:"
    echo "  thor-cd            - Go to workspace root"
    echo "  thor-build         - Run the main build script"
    echo "  thor-logs          - View development logs"
    echo "  check-crossgcc     - Verify cross-compiler setup"
}

# Show status on terminal start
if [ -t 1 ]; then
    thor-status
fi
EOF

# Create project directories
mkdir -p /workspaces/.thor-hammer/{logs,downloads,toolchain} 2>/dev/null || true

# Set up ccache for faster compilation
if command -v ccache >/dev/null 2>&1; then
    echo "🚀 Setting up ccache for faster builds..."
    ccache --set-config max_size=2G
    ccache --set-config compression=true
fi

# Create initial development log
mkdir -p /workspaces/.thor-hammer/logs
echo "$(date): Dev container post-creation setup completed" >> /workspaces/.thor-hammer/logs/devcontainer.log

echo "✅ Thor Hammer development environment ready!"
echo "🎯 Run 'thor-status' to see available commands"