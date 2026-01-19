#!/bin/bash
# Thor Hammer - Container Creation Script
# Runs when the dev container is first created

set -e

echo "🔨 Thor Hammer - Setting up development container..."

# Update container packages
echo "🔄 Updating packages..."
sudo pacman -Syu --noconfirm

# Install essential development tools
echo "📦 Installing development tools..."
sudo pacman -S --noconfirm \
    base-devel \
    wget \
    curl \
    rsync \
    unzip \
    vim \
    nano \
    htop \
    tree \
    jq \
    go

echo "✅ Container creation setup completed!"