#!/bin/bash
# Thor Hammer - Kernel Build Script
# Builds the AYN Linux kernel for ARM64

set -e

KERNEL_SOURCE="/tmp/thor-kernel"
OUTPUT_DIR="/workspaces/.thor-hammer/assets"
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

# Check if kernel source exists
if [ ! -d "$KERNEL_SOURCE" ]; then
    echo "Error: Kernel source not found at $KERNEL_SOURCE"
    echo "Clone it first: git clone --depth=1 https://github.com/AYNTechnologies/linux.git /tmp/thor-kernel"
    exit 1
fi

echo "🔨 Building AYN Linux Kernel for ARM64..."
echo "Source: $KERNEL_SOURCE"
echo "Output: $OUTPUT_DIR"
echo ""

# Navigate to kernel source
cd "$KERNEL_SOURCE"

# Clean previous builds
echo "🧹 Cleaning previous build artifacts..."
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE clean

# Configure kernel
echo "⚙️  Configuring kernel with defconfig..."
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig

# Build kernel image
echo "🏗️  Building kernel (this will take a while)..."
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) Image

# Check if build succeeded
if [ ! -f "arch/arm64/boot/Image" ]; then
    echo "❌ Kernel build failed!"
    exit 1
fi

# Copy kernel to assets
echo "📦 Copying kernel to assets..."
cp arch/arm64/boot/Image "$OUTPUT_DIR/THOR-KERNEL"
chmod +x "$OUTPUT_DIR/THOR-KERNEL"

# Get kernel version
KERNEL_VERSION=$(make kernelrelease)

echo ""
echo "✅ Kernel build completed successfully!"
echo "📄 Kernel version: $KERNEL_VERSION"
echo "📍 Kernel location: $OUTPUT_DIR/KERNEL"
echo "💾 Size: $(du -h $OUTPUT_DIR/KERNEL | cut -f1)"
echo ""
echo "Next steps:"
echo "  1. Update the image with the new kernel"
echo "  2. Test boot with: sudo ./scripts/start-qemu-console.sh"
