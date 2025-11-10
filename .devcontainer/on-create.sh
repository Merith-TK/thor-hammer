#!/bin/bash
# Thor Hammer - Container Creation Script
# Runs when the dev container is first created

set -e

echo "🔨 Thor Hammer - Setting up development container..."

# Update package database
sudo pacman -Sy

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
    jq

echo "✅ Container creation setup completed!"