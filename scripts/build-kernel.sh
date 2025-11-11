#!/bin/bash
# Thor Hammer - Kernel Build Script
# Builds the AYN Linux kernel for ARM64

set -e

KERNEL_SOURCE="/tmp/thor-kernel"
OUTPUT_DIR="/workspaces/.thor-hammer/assets"
DTB_NAME="qcs8550-ayn-thor"
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

# Parse command line arguments
BUILD_KERNEL=true
BUILD_DTB=true
CLEAN_BUILD=false
FORCE_REBUILD=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-kernel) BUILD_KERNEL=false ;;
        --skip-dtb) BUILD_DTB=false ;;
        --clean) CLEAN_BUILD=true ;;
        --rebuild) FORCE_REBUILD=true ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-kernel    Skip kernel build, only build DTB"
            echo "  --skip-dtb       Skip DTB build, only build kernel"
            echo "  --clean          Clean build artifacts before building"
            echo "  --rebuild        Force rebuild even if kernel/DTB already exist"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Check if kernel source exists
if [ ! -d "$KERNEL_SOURCE" ]; then
    echo "Error: Kernel source not found at $KERNEL_SOURCE"
    echo "Clone it first: git clone --depth=1 https://github.com/AYNTechnologies/linux.git /tmp/thor-kernel"
    exit 1
fi

# Check if kernel/DTB already exist
if [ "$FORCE_REBUILD" = false ]; then
    if [ "$BUILD_KERNEL" = true ] && [ -f "$OUTPUT_DIR/KERNEL" ]; then
        echo "✅ Kernel already exists at $OUTPUT_DIR/KERNEL"
        echo "   Use --rebuild to force rebuild"
        BUILD_KERNEL=false
    fi
    
    if [ "$BUILD_DTB" = true ] && [ -f "$OUTPUT_DIR/${DTB_NAME}.dtb" ]; then
        echo "✅ DTB already exists at $OUTPUT_DIR/${DTB_NAME}.dtb"
        echo "   Use --rebuild to force rebuild"
        BUILD_DTB=false
    fi
    
    # Exit early if nothing needs to be built
    if [ "$BUILD_KERNEL" = false ] && [ "$BUILD_DTB" = false ]; then
        echo ""
        echo "🎉 All artifacts already exist. Nothing to build!"
        exit 0
    fi
fi

echo "🔨 Building AYN Linux Kernel for ARM64..."
echo "Source: $KERNEL_SOURCE"
echo "Output: $OUTPUT_DIR"
echo ""

# Navigate to kernel source
cd "$KERNEL_SOURCE"

# Clean previous builds if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Cleaning previous build artifacts..."
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE clean
else
    echo "♻️  Using incremental build (use --clean to force clean build)..."
fi

# Configure kernel (only if .config doesn't exist or clean was requested)
if [ ! -f ".config" ] || [ "$CLEAN_BUILD" = true ]; then
    echo "⚙️  Configuring kernel with defconfig..."
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig
else
    echo "⚙️  Using existing kernel configuration..."
fi

# Build kernel image
if [ "$BUILD_KERNEL" = true ]; then
    echo "🏗️  Building kernel (this will take a while)..."
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) Image
    
    # Check if build succeeded
    if [ ! -f "arch/arm64/boot/Image" ]; then
        echo "❌ Kernel build failed!"
        exit 1
    fi
else
    echo "⏭️  Skipping kernel build..."
fi

# Build device tree blob
if [ "$BUILD_DTB" = true ]; then
    echo "🌳 Building device tree blob for ${DTB_NAME}..."
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) dtbs
    
    # Check if build succeeded
    if [ ! -f "arch/arm64/boot/dts/qcom/${DTB_NAME}.dtb" ]; then
        echo "❌ Device tree build failed!"
        exit 1
    fi
else
    echo "⏭️  Skipping DTB build..."
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy kernel and DTB to assets folder
echo "📦 Copying built artifacts to assets folder..."
if [ "$BUILD_KERNEL" = true ]; then
    sudo cp arch/arm64/boot/Image "$OUTPUT_DIR/KERNEL"
    sudo chmod +x "$OUTPUT_DIR/KERNEL"
fi

if [ "$BUILD_DTB" = true ]; then
    sudo cp "arch/arm64/boot/dts/qcom/${DTB_NAME}.dtb" "$OUTPUT_DIR/${DTB_NAME}.dtb"
fi

# Get kernel version
KERNEL_VERSION=$(make kernelrelease)

echo ""
echo "✅ Build completed successfully!"
echo "📄 Kernel version: $KERNEL_VERSION"
if [ "$BUILD_KERNEL" = true ]; then
    echo "📍 Kernel location: $OUTPUT_DIR/KERNEL"
    echo "� Kernel size: $(du -h $OUTPUT_DIR/KERNEL | cut -f1)"
fi
if [ "$BUILD_DTB" = true ]; then
    echo "� DTB location: $OUTPUT_DIR/${DTB_NAME}.dtb"
    echo "�💾 DTB size: $(du -h $OUTPUT_DIR/${DTB_NAME}.dtb | cut -f1)"
fi
echo ""
echo "Next steps:"
echo "  1. Update the image with the new kernel and DTB"
echo "  2. Test boot with: sudo ./scripts/start-qemu-console.sh"
