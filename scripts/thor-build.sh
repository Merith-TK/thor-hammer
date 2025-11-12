#!/bin/bash
#
# Thor Hammer - Unified Build Script
#
# This script handles both kernel building and image creation in a single command.
# It combines the functionality of build-kernel.sh and build.sh.
#

set -e

# --- Configuration ---
ROOTFS_PATH=""
IMAGE_NAME="thor-hammer.img"
IMAGE_SIZE="4G"
SETUP_SCRIPT=""
WORKDIR="build"
KERNEL_FILE="KERNEL"

# Kernel build configuration
KERNEL_SOURCE="/tmp/thor-kernel"
OUTPUT_DIR="/workspaces/.thor-hammer/assets"
DTB_NAME="qcs8550-ayn-thor"
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

# Build flags
USE_AYN_KERNEL=false
BUILD_KERNEL=true
BUILD_DTB=true
CLEAN_KERNEL=false
REBUILD_KERNEL=false
BUILD_IMAGE=true

# --- Functions ---

usage() {
    echo "Thor Hammer - Unified Build System"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Image Build Options:"
    echo "  -r, --rootfs <path|url>   Path or URL to the rootfs tarball"
    echo "  -s, --setup-script <path> Path to the setup script (default: ${SETUP_SCRIPT})"
    echo "  -n, --name <name>         Output image name (default: ${IMAGE_NAME})"
    echo "  --no-image                Skip image building (kernel only)"
    echo ""
    echo "Kernel Build Options:"
    echo "  --use-ayn-kernel          Build and use AYN Linux kernel"
    echo "  --rebuild-kernel          Force rebuild kernel even if it exists"
    echo "  --clean-kernel            Clean kernel build artifacts before building"
    echo "  --skip-kernel             Skip kernel build, only build DTB"
    echo "  --skip-dtb                Skip DTB build, only build kernel"
    echo ""
    echo "General Options:"
    echo "  -h, --help                Display this help message"
    echo ""
    echo "Examples:"
    echo "  # Build image only (use existing kernel)"
    echo "  sudo $0 -r /path/to/rootfs.tar.gz"
    echo ""
    echo "  # Build kernel and image"
    echo "  sudo $0 -r /path/to/rootfs.tar.gz --use-ayn-kernel"
    echo ""
    echo "  # Build kernel only (no image)"
    echo "  $0 --use-ayn-kernel --no-image"
    echo ""
    echo "  # Rebuild kernel from scratch"
    echo "  $0 --use-ayn-kernel --rebuild-kernel --clean-kernel --no-image"
    exit 1
}

log() {
    echo "INFO: $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

download_rootfs() {
    if [[ "${ROOTFS_PATH}" =~ ^https?:// ]]; then
        log "Downloading rootfs from ${ROOTFS_PATH}..."
        if command -v wget &> /dev/null; then
            wget -O "${WORKDIR}/rootfs.tar.gz" "${ROOTFS_PATH}"
        elif command -v curl &> /dev/null; then
            curl -L -o "${WORKDIR}/rootfs.tar.gz" "${ROOTFS_PATH}"
        else
            error "Neither wget nor curl is available to download the rootfs."
        fi
        ROOTFS_PATH="${WORKDIR}/rootfs.tar.gz"
        log "Rootfs downloaded to ${ROOTFS_PATH}"
    elif [ ! -f "${ROOTFS_PATH}" ]; then
        error "Rootfs file not found at ${ROOTFS_PATH}"
    fi
}

build_kernel() {
    log "=== Kernel Build Phase ==="
    
    # Check if kernel/DTB already exist
    if [ "$REBUILD_KERNEL" = false ]; then
        if [ "$BUILD_KERNEL" = true ] && [ -f "$OUTPUT_DIR/KERNEL" ]; then
            log "✅ Kernel already exists at $OUTPUT_DIR/KERNEL (use --rebuild-kernel to force)"
            BUILD_KERNEL=false
        fi
        
        if [ "$BUILD_DTB" = true ] && [ -f "$OUTPUT_DIR/${DTB_NAME}.dtb" ]; then
            log "✅ DTB already exists at $OUTPUT_DIR/${DTB_NAME}.dtb (use --rebuild-kernel to force)"
            BUILD_DTB=false
        fi
        
        # Exit early if nothing needs to be built
        if [ "$BUILD_KERNEL" = false ] && [ "$BUILD_DTB" = false ]; then
            log "🎉 All kernel artifacts already exist. Nothing to build!"
            return 0
        fi
    fi
    
    # Check if kernel source exists (only if we need to build something)
    if [ ! -d "$KERNEL_SOURCE" ]; then
        error "Kernel source not found at $KERNEL_SOURCE. Clone it first: git clone --depth=1 https://github.com/AYNTechnologies/linux.git /tmp/thor-kernel"
    fi

    log "🔨 Building AYN Linux Kernel for ARM64..."
    log "Source: $KERNEL_SOURCE"
    log "Output: $OUTPUT_DIR"

    # Navigate to kernel source
    cd "$KERNEL_SOURCE"

    # Clean previous builds if requested
    if [ "$CLEAN_KERNEL" = true ]; then
        log "🧹 Cleaning previous build artifacts..."
        make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE clean
    else
        log "♻️  Using incremental build (use --clean-kernel for clean build)"
    fi

    # Configure kernel (only if .config doesn't exist or clean was requested)
    if [ ! -f ".config" ] || [ "$CLEAN_KERNEL" = true ]; then
        log "⚙️  Configuring kernel with defconfig..."
        make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig
    else
        log "⚙️  Using existing kernel configuration..."
    fi

    # Build kernel image
    if [ "$BUILD_KERNEL" = true ]; then
        log "🏗️  Building kernel (this will take a while)..."
        make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) Image
        
        if [ ! -f "arch/arm64/boot/Image" ]; then
            error "Kernel build failed!"
        fi
    else
        log "⏭️  Skipping kernel build..."
    fi

    # Build device tree blob
    if [ "$BUILD_DTB" = true ]; then
        log "🌳 Building device tree blob for ${DTB_NAME}..."
        make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) dtbs
        
        if [ ! -f "arch/arm64/boot/dts/qcom/${DTB_NAME}.dtb" ]; then
            error "Device tree build failed!"
        fi
    else
        log "⏭️  Skipping DTB build..."
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Copy kernel and DTB to assets folder
    log "📦 Copying built artifacts to assets folder..."
    if [ "$BUILD_KERNEL" = true ]; then
        sudo cp arch/arm64/boot/Image "$OUTPUT_DIR/KERNEL"
        sudo chmod +x "$OUTPUT_DIR/KERNEL"
    fi

    if [ "$BUILD_DTB" = true ]; then
        sudo cp "arch/arm64/boot/dts/qcom/${DTB_NAME}.dtb" "$OUTPUT_DIR/${DTB_NAME}.dtb"
    fi

    # Get kernel version
    KERNEL_VERSION=$(make kernelrelease)

    log ""
    log "✅ Kernel build completed successfully!"
    log "📄 Kernel version: $KERNEL_VERSION"
    if [ "$BUILD_KERNEL" = true ]; then
        log "📍 Kernel location: $OUTPUT_DIR/KERNEL"
        log "💾 Kernel size: $(du -h $OUTPUT_DIR/KERNEL | cut -f1)"
    fi
    if [ "$BUILD_DTB" = true ]; then
        log "🌳 DTB location: $OUTPUT_DIR/${DTB_NAME}.dtb"
        log "💾 DTB size: $(du -h $OUTPUT_DIR/${DTB_NAME}.dtb | cut -f1)"
    fi
    log ""

    # Return to original directory
    cd - > /dev/null
}

build_image() {
    log "=== Image Build Phase ==="
    
    # Check for required files
    DTB_FILE="assets/${DTB_NAME}.dtb"
    if [ ! -f "${DTB_FILE}" ]; then
        error "Device tree blob not found at ${DTB_FILE}. Build it first with --use-ayn-kernel"
    fi
    
    if [ ! -f "assets/KERNEL" ]; then
        error "Kernel not found at assets/KERNEL. Build it first with --use-ayn-kernel"
    fi

    log "Starting image build process..."
    log "Rootfs: ${ROOTFS_PATH}"
    log "Setup Script: ${SETUP_SCRIPT}"
    log "Output Image: ${IMAGE_NAME}"

    # Purge and recreate working directory to avoid conflicts
    log "Purging build directory to ensure clean build..."
    # Unmount any leftover mounts from previous builds
    if [ -d "${WORKDIR}/rootfs" ]; then
        sudo umount "${WORKDIR}/rootfs/proc" 2>/dev/null || true
        sudo umount "${WORKDIR}/rootfs/sys" 2>/dev/null || true
        sudo umount "${WORKDIR}/rootfs/dev/pts" 2>/dev/null || true
        sudo umount "${WORKDIR}/rootfs/dev/shm" 2>/dev/null || true
        sudo umount "${WORKDIR}/rootfs/dev/mqueue" 2>/dev/null || true
        sudo umount "${WORKDIR}/rootfs/dev" 2>/dev/null || true
        sudo umount "${WORKDIR}/rootfs/boot" 2>/dev/null || true
        sudo umount "${WORKDIR}/rootfs" 2>/dev/null || true
    fi
    # Clean up any leftover loop devices and kpartx mappings
    if [ -f "${WORKDIR}/${IMAGE_NAME}" ]; then
        EXISTING_LOOP=$(sudo losetup -j "${WORKDIR}/${IMAGE_NAME}" | cut -d: -f1)
        if [ -n "$EXISTING_LOOP" ]; then
            log "Cleaning up existing loop device: ${EXISTING_LOOP}"
            sudo kpartx -d "${EXISTING_LOOP}" 2>/dev/null || true
            sudo losetup -d "${EXISTING_LOOP}" 2>/dev/null || true
        fi
    fi
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"

    # Download rootfs if URL is provided
    download_rootfs

    # Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        error "This script requires root privileges for disk partitioning and mounting."
    fi

    # 2. Create a blank disk image
    log "Creating a blank disk image of size ${IMAGE_SIZE}..."
    truncate -s "${IMAGE_SIZE}" "${WORKDIR}/${IMAGE_NAME}"

    # 3. Partition the image (GPT with EFI System and Linux partitions)
    log "Partitioning the disk image..."
    sudo parted "${WORKDIR}/${IMAGE_NAME}" --script \
        mklabel gpt \
        mkpart primary fat32 1MiB 513MiB \
        set 1 esp on \
        mkpart primary ext4 513MiB 100% \
        name 1 THORBOOT \
        name 2 THORROOT

    # 4. Set up loop device and create device mapper entries
    log "Setting up loop device..."
    LOOP_DEV=$(sudo losetup --find --show --partscan "${WORKDIR}/${IMAGE_NAME}")
    log "Loop device: ${LOOP_DEV}"

    sudo kpartx -av "${LOOP_DEV}"
    sleep 2

    LOOP_NAME=$(basename "${LOOP_DEV}")
    PART1="/dev/mapper/${LOOP_NAME}p1"
    PART2="/dev/mapper/${LOOP_NAME}p2"

    # 5. Format the partitions
    log "Formatting partitions..."
    sudo mkfs.vfat -F 32 -n THORBOOT "${PART1}"
    sudo mkfs.ext4 -L THORROOT "${PART2}"

    # 6. Mount and extract rootfs
    MOUNT_DIR="${WORKDIR}/rootfs"
    mkdir -p "${MOUNT_DIR}"
    sudo mount "${PART2}" "${MOUNT_DIR}"
    sudo mkdir -p "${MOUNT_DIR}/boot"
    sudo mount "${PART1}" "${MOUNT_DIR}/boot"

    log "Extracting rootfs to ${MOUNT_DIR}..."
    sudo tar -xpf "${ROOTFS_PATH}" -C "${MOUNT_DIR}"

    # Generate fstab
    log "Generating fstab with partition labels..."
    sudo tee "${MOUNT_DIR}/etc/fstab" > /dev/null << 'EOF'
# /etc/fstab: static file system information
#
# <file system>       <mount point>  <type>  <options>              <dump> <pass>
LABEL=THORROOT        /              ext4    defaults,noatime       0      1
LABEL=THORBOOT        /boot          vfat    defaults,noatime       0      2
EOF

    log "fstab generated successfully"

    # Copy kernel and DTB to boot partition
    if [ -f "assets/KERNEL" ]; then
        log "Copying kernel to boot partition..."
        sudo cp "assets/KERNEL" "${MOUNT_DIR}/boot/"
    fi

    if [ -f "assets/${DTB_NAME}.dtb" ]; then
        log "Copying device tree blob to boot partition..."
        sudo cp "assets/${DTB_NAME}.dtb" "${MOUNT_DIR}/boot/"
    fi

    # 7. Set up qemu-user-static for chroot
    log "Setting up qemu-user-static for chroot..."
    sudo cp /usr/bin/qemu-aarch64-static "${MOUNT_DIR}/usr/bin/"

    sudo mount --bind /proc "${MOUNT_DIR}/proc"
    sudo mount --bind /sys "${MOUNT_DIR}/sys"
    sudo mount --bind /dev "${MOUNT_DIR}/dev"

    # Copy setup script into the chroot
    if [ -n "${SETUP_SCRIPT}" ]; then
        log "Copying setup script into chroot environment..."
        sudo cp "${SETUP_SCRIPT}" "${MOUNT_DIR}/setup.sh"
        sudo chmod +x "${MOUNT_DIR}/setup.sh"

        # Chroot and run the setup script
        sudo chroot "${MOUNT_DIR}" /bin/bash /setup.sh

        log "Setup script finished."

    fi
    # 7.5. Install custom GRUB config if available
    if [ -f "assets/custom-grub.cfg" ]; then
        log "Installing custom GRUB configuration..."
        # Replace {KERNELFILE} placeholder with actual kernel filename
        sudo cp "assets/custom-grub.cfg" "${MOUNT_DIR}/boot/grub/grub.cfg.tmp"
        sudo sed -i "s/{KERNELFILE}/${KERNEL_FILE}/g" "${MOUNT_DIR}/boot/grub/grub.cfg.tmp"
        sudo mv "${MOUNT_DIR}/boot/grub/grub.cfg.tmp" "${MOUNT_DIR}/boot/grub/grub.cfg"
        log "Custom GRUB config installed with kernel: ${KERNEL_FILE}"
    fi

    # 8. Unmount and cleanup
    log "Cleaning up..."
    sudo rm "${MOUNT_DIR}/setup.sh"
    sudo rm "${MOUNT_DIR}/usr/bin/qemu-aarch64-static"
    sudo umount "${MOUNT_DIR}/proc" 2>/dev/null || true
    sudo umount "${MOUNT_DIR}/sys" 2>/dev/null || true
    sudo umount "${MOUNT_DIR}/dev" 2>/dev/null || true
    sudo umount "${MOUNT_DIR}/boot"
    sudo umount "${MOUNT_DIR}"

    sudo kpartx -d "${LOOP_DEV}"
    sudo losetup -d "${LOOP_DEV}"

    log "Build complete! Image is located at ${WORKDIR}/${IMAGE_NAME}"
    log ""
    log "Next steps:"
    log "  1. Test with: thor-vm ${WORKDIR}/${IMAGE_NAME}"
    log "  2. Flash to device or copy to SD card"
}

# --- Main Script ---

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        # Image options
        -r|--rootfs) ROOTFS_PATH="$2"; shift ;;
        -s|--setup-script) SETUP_SCRIPT="$2"; shift ;;
        -n|--name) IMAGE_NAME="$2"; shift ;;
        --no-image) BUILD_IMAGE=false ;;
        
        # Kernel options
        --use-ayn-kernel) USE_AYN_KERNEL=true ;;
        --rebuild-kernel) REBUILD_KERNEL=true ;;
        --clean-kernel) CLEAN_KERNEL=true ;;
        --skip-kernel) BUILD_KERNEL=false ;;
        --skip-dtb) BUILD_DTB=false ;;
        
        # General
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate arguments based on what we're building
if [ "$BUILD_IMAGE" = true ] && [ -z "${ROOTFS_PATH}" ]; then
    error "Rootfs path or URL is required for image building. Use -r or --rootfs"
fi

if [ "$USE_AYN_KERNEL" = false ] && [ "$BUILD_IMAGE" = false ]; then
    error "Nothing to do! Specify --use-ayn-kernel to build kernel, or provide -r to build image"
fi

# Execute build phases
log "Thor Hammer Build System"
log "========================"
log ""

if [ "$USE_AYN_KERNEL" = true ]; then
    build_kernel
fi

if [ "$BUILD_IMAGE" = true ]; then
    build_image
fi

log ""
log "✅ All build phases completed successfully!"
