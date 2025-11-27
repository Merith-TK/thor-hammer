#!/bin/bash
#
# Thor Hammer - Unified Build Script
#
# This script handles both kernel building and image creation in a single command.
# It combines the functionality of build-kernel.sh and build.sh.
#

set -e

# Get script directory for finding other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Configuration ---
ROOTFS_PATH=""
IMAGE_NAME="thor-hammer.img"
IMAGE_SIZE="4G"
SETUP_SCRIPT=""
WORKDIR="build"
ROOTFS_DIR="build/rootfs"
KERNEL_FILE="KERNEL"

# Kernel build configuration
KERNEL_SOURCE="/tmp/thor-kernel"
OUTPUT_DIR="/workspaces/.thor-hammer/assets"
DTB_NAME="qcs8550-ayn-thor"
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

# Build flags - all opt-in now
BUILD_KERNEL=false
BUILD_DTB=false
BUILD_ROOTFS=false
BUILD_IMAGE=false
CLEAN_KERNEL=false
OVERWRITE=false

# --- Functions ---

usage() {
    echo "Thor Hammer - Unified Build System"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Build Target Options (opt-in, specify what to build):"
    echo "  --kernel                  Build kernel"
    echo "  --dtb                     Build device tree blob"
    echo "  --rootfs                  Build prepared rootfs (extract + setup)"
    echo "  --image                   Build disk image from prepared rootfs"
    echo "  --all                     Build everything (kernel + dtb + rootfs + image)"
    echo ""
    echo "Build Options:"
    echo "  -r, --rootfs-tar <path>   Path or URL to the rootfs tarball (required for --rootfs)"
    echo "  -s, --setup-script <path> Path to the setup script (runs in chroot for --rootfs)"
    echo "  -n, --name <name>         Output image name (default: ${IMAGE_NAME})"
    echo ""
    echo "Build Modifiers:"
    echo "  --overwrite               Overwrite existing artifacts"
    echo "  --clean                   Clean build artifacts before building"
    echo ""
    echo "General Options:"
    echo "  -h, --help                Display this help message"
    echo ""
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
    
    # Check if kernel/DTB already exist (unless overwrite is set)
    if [ "$OVERWRITE" = false ]; then
        if [ "$BUILD_KERNEL" = true ] && [ -f "$OUTPUT_DIR/KERNEL" ]; then
            log "✅ Kernel already exists at $OUTPUT_DIR/KERNEL (use --overwrite to rebuild)"
            BUILD_KERNEL=false
        fi
        
        if [ "$BUILD_DTB" = true ] && [ -f "$OUTPUT_DIR/${DTB_NAME}.dtb" ]; then
            log "✅ DTB already exists at $OUTPUT_DIR/${DTB_NAME}.dtb (use --overwrite to rebuild)"
            BUILD_DTB=false
        fi
        
        # Exit early if nothing needs to be built
        if [ "$BUILD_KERNEL" = false ] && [ "$BUILD_DTB" = false ]; then
            log "🎉 All kernel artifacts already exist. Nothing to build!"
            return 0
        fi
    fi
    
    # Check if kernel source exists, clone if missing
    if [ ! -d "$KERNEL_SOURCE" ]; then
        log "📥 Kernel source not found, cloning from GitHub..."
        log "Repository: https://github.com/AYNTechnologies/linux.git"
        log "Destination: $KERNEL_SOURCE"
        
        if ! command -v git &> /dev/null; then
            error "git is not installed. Install it first: sudo pacman -S git"
        fi
        
        git clone --depth=1 https://github.com/AYNTechnologies/linux.git "$KERNEL_SOURCE"
        
        if [ $? -ne 0 ]; then
            error "Failed to clone kernel source"
        fi
        
        log "✅ Kernel source cloned successfully"
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

build_rootfs() {
    log "=== Rootfs Preparation Phase ==="
    
    # Check if prepared rootfs already exists
    if [ -d "${ROOTFS_DIR}" ] && [ "$OVERWRITE" != true ]; then
        log "✅ Prepared rootfs already exists at ${ROOTFS_DIR}"
        log "   Use --overwrite to rebuild it"
        return 0
    fi
    
    # Clean up existing prepared rootfs if overwrite requested
    if [ -d "${ROOTFS_DIR}" ] && [ "$OVERWRITE" = true ]; then
        log "Removing existing prepared rootfs..."
        # Just remove the directory - no need to manually unmount
        sudo rm -rf "${ROOTFS_DIR}"
    fi
    
    log "Preparing rootfs at ${ROOTFS_DIR}..."
    log "Rootfs: ${ROOTFS_PATH}"
    log "Setup Script: ${SETUP_SCRIPT}"
    
    # Create rootfs directory
    mkdir -p "${ROOTFS_DIR}"
    
    # Download rootfs if URL is provided
    download_rootfs
    
    # Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        error "This script requires root privileges for chroot operations."
    fi
    
    # Extract rootfs
    log "Extracting rootfs to ${ROOTFS_DIR}..."
    sudo tar -xpf "${ROOTFS_PATH}" -C "${ROOTFS_DIR}"
    
    # Generate fstab (for reference, will be copied to image later)
    log "Generating fstab..."
    sudo tee "${ROOTFS_DIR}/etc/fstab" > /dev/null << 'EOF'
# /etc/fstab: static file system information
#
# <file system>       <mount point>  <type>  <options>              <dump> <pass>
LABEL=THORROOT        /              ext4    defaults,noatime       0      1
LABEL=THORBOOT        /boot          vfat    defaults,noatime       0      2
EOF
    
    # Run setup script if provided using thor-chroot
    if [ -n "${SETUP_SCRIPT}" ]; then
        log "Running setup script in chroot via thor-chroot..."
        
        # Copy setup script into chroot
        sudo cp "${SETUP_SCRIPT}" "${ROOTFS_DIR}/setup.sh"
        sudo chmod +x "${ROOTFS_DIR}/setup.sh"
        
        # Run setup script using thor-chroot (handles ARM64 setup and mounting)
        "${SCRIPT_DIR}/thor-chroot.sh" -r "${ROOTFS_DIR}" /bin/bash /setup.sh
        
        log "Setup script finished."
        
        # Cleanup
        sudo rm "${ROOTFS_DIR}/setup.sh"
    fi
    
    log ""
    log "✅ Rootfs preparation completed successfully!"
    log "📁 Prepared rootfs location: ${ROOTFS_DIR}"
    log "💾 Rootfs size: $(sudo du -sh ${ROOTFS_DIR} | cut -f1)"
    log ""
    log "Next steps:"
    log "  1. Build image: thor-build --image"
    log "  2. Modify rootfs: thor-chroot"
    log ""
}

build_image() {
    log "=== Image Build Phase ==="
    
    # Check for required files
    DTB_FILE="assets/${DTB_NAME}.dtb"
    if [ ! -f "${DTB_FILE}" ]; then
        error "Device tree blob not found at ${DTB_FILE}. Build it first with --dtb"
    fi
    
    if [ ! -f "assets/KERNEL" ]; then
        error "Kernel not found at assets/KERNEL. Build it first with --kernel"
    fi
    
    # Check for prepared rootfs
    if [ ! -d "${ROOTFS_DIR}" ]; then
        error "Prepared rootfs not found at ${ROOTFS_DIR}. Build it first with --rootfs"
    fi
    
    log "Starting image build process..."
    log "Using prepared rootfs: ${ROOTFS_DIR}"
    log "Output Image: ${IMAGE_NAME}"

    # Purge and recreate working directory to avoid conflicts
    log "Purging build directory to ensure clean build..."
    # Unmount any leftover mounts from previous builds
    if [ -d "${WORKDIR}/rootfs" ]; then
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

    # Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        error "This script requires root privileges for disk partitioning and mounting."
    fi

    # Create a blank disk image
    log "Creating a blank disk image of size ${IMAGE_SIZE}..."
    truncate -s "${IMAGE_SIZE}" "${WORKDIR}/${IMAGE_NAME}"

    # Partition the image (GPT with EFI System and Linux partitions)
    log "Partitioning the disk image..."
    sudo parted "${WORKDIR}/${IMAGE_NAME}" --script \
        mklabel gpt \
        mkpart primary fat32 1MiB 513MiB \
        set 1 esp on \
        mkpart primary ext4 513MiB 100% \
        name 1 THORBOOT \
        name 2 THORROOT

    # Set up loop device and create device mapper entries
    log "Setting up loop device..."
    LOOP_DEV=$(sudo losetup --find --show --partscan "${WORKDIR}/${IMAGE_NAME}")
    log "Loop device: ${LOOP_DEV}"

    sudo kpartx -av "${LOOP_DEV}"
    sleep 2

    LOOP_NAME=$(basename "${LOOP_DEV}")
    PART1="/dev/mapper/${LOOP_NAME}p1"
    PART2="/dev/mapper/${LOOP_NAME}p2"

    # Format the partitions
    log "Formatting partitions..."
    sudo mkfs.vfat -F 32 -n THORBOOT "${PART1}"
    sudo mkfs.ext4 -L THORROOT "${PART2}"

    # Mount partitions
    MOUNT_DIR="${WORKDIR}/rootfs"
    mkdir -p "${MOUNT_DIR}"
    sudo mount "${PART2}" "${MOUNT_DIR}"
    sudo mkdir -p "${MOUNT_DIR}/boot"
    sudo mount "${PART1}" "${MOUNT_DIR}/boot"

    # Copy prepared rootfs to mounted image
    log "Copying prepared rootfs to image..."
    sudo rsync -aAXv "${ROOTFS_DIR}/" "${MOUNT_DIR}/" \
        --exclude='/boot/*' \
        --exclude='/dev/*' \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/tmp/*' \
        --exclude='/run/*' \
        --exclude='/mnt/*' \
        --exclude='/media/*' \
        --exclude='/lost+found'

    # Copy kernel and DTB to boot partition
    if [ -f "assets/KERNEL" ]; then
        log "Copying kernel to boot partition..."
        sudo cp "assets/KERNEL" "${MOUNT_DIR}/boot/"
    fi

    if [ -f "assets/${DTB_NAME}.dtb" ]; then
        log "Copying device tree blob to boot partition..."
        sudo cp "assets/${DTB_NAME}.dtb" "${MOUNT_DIR}/boot/"
    fi

    # Install custom GRUB config if available
    if [ -f "assets/custom-grub.cfg" ]; then
        log "Installing custom GRUB configuration..."
        # Replace {KERNELFILE} placeholder with actual kernel filename
        sudo cp "assets/custom-grub.cfg" "${MOUNT_DIR}/boot/grub/grub.cfg.tmp"
        sudo sed -i "s/{KERNELFILE}/${KERNEL_FILE}/g" "${MOUNT_DIR}/boot/grub/grub.cfg.tmp"
        sudo mv "${MOUNT_DIR}/boot/grub/grub.cfg.tmp" "${MOUNT_DIR}/boot/grub/grub.cfg"
        log "Custom GRUB config installed with kernel: ${KERNEL_FILE}"
    fi

    # Unmount and cleanup
    log "Cleaning up..."
    sudo umount "${MOUNT_DIR}/boot"
    sudo umount "${MOUNT_DIR}"

    sudo kpartx -d "${LOOP_DEV}"
    sudo losetup -d "${LOOP_DEV}"

    log ""
    log "✅ Image build completed successfully!"
    log "📍 Image location: ${WORKDIR}/${IMAGE_NAME}"
    log "💾 Image size: $(du -h ${WORKDIR}/${IMAGE_NAME} | cut -f1)"
    log ""
    log "Next steps:"
    log "  1. Test with: thor-vm ${WORKDIR}/${IMAGE_NAME} --gui"
    log "  2. Flash to device or copy to SD card"
    log ""
}

# --- Main Script ---

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        # Build targets
        --kernel) BUILD_KERNEL=true ;;
        --dtb) BUILD_DTB=true ;;
        --rootfs) BUILD_ROOTFS=true ;;
        --image) BUILD_IMAGE=true ;;
        --all) BUILD_KERNEL=true; BUILD_DTB=true; BUILD_ROOTFS=true; BUILD_IMAGE=true ;;
        
        # Image options
        --rootfs-tar) ROOTFS_PATH="$2"; shift ;;
        -s|--setup-script) SETUP_SCRIPT="$2"; shift ;;
        -n|--name) IMAGE_NAME="$2"; shift ;;
        
        # Build modifiers
        --overwrite) OVERWRITE=true ;;
        --clean) CLEAN_KERNEL=true ;;
        
        # General
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate arguments based on what we're building
if [ "$BUILD_ROOTFS" = true ] && [ -z "${ROOTFS_PATH}" ]; then
    error "Rootfs tarball path or URL is required for rootfs preparation. Use --rootfs-tar <path>"
fi

if [ "$BUILD_IMAGE" = true ] && [ "$BUILD_ROOTFS" = false ] && [ ! -d "${ROOTFS_DIR}" ]; then
    error "Image building requires prepared rootfs. Either build it first with --rootfs, or use --all"
fi

if [ "$BUILD_KERNEL" = false ] && [ "$BUILD_DTB" = false ] && [ "$BUILD_ROOTFS" = false ] && [ "$BUILD_IMAGE" = false ]; then
    error "Nothing to build! Specify at least one target: --kernel, --dtb, --rootfs, --image, or --all"
fi

# Execute build phases
log "Thor Hammer Build System"
log "========================"
log ""

if [ "$BUILD_KERNEL" = true ] || [ "$BUILD_DTB" = true ]; then
    build_kernel
fi

if [ "$BUILD_ROOTFS" = true ]; then
    build_rootfs
fi

if [ "$BUILD_IMAGE" = true ]; then
    build_image
fi

log ""
log "✅ All build phases completed successfully!"

if [ "$BUILD_IMAGE" = true ]; then
    build_image
fi

log ""
log "✅ All build phases completed successfully!"
