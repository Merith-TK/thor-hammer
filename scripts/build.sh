#!/bin/bash
#
# Thor Hammer - Main Build Script
#
# This script orchestrates the entire image building process, from creating
# a partitioned disk image to configuring the OS using a setup script inside
# a QEMU environment.
#

set -e

# --- Configuration ---
# ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_PATH="" # Or path to a local tarball
IMAGE_NAME="thor-hammer.img"
IMAGE_SIZE="4G"
SETUP_SCRIPT="scripts/setup-archlinux.sh"
WORKDIR="build"

# --- Functions ---

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -r, --rootfs <path|url>   Path or URL to the rootfs tarball (required)."
    echo "  -s, --setup-script <path> Path to the setup script (default: ${SETUP_SCRIPT})."
    echo "  -c, --config <path>       Path to the device config file (default: ${DEVICE_CONFIG})."
    echo "  -n, --name <name>         Output image name (default: ${IMAGE_NAME})."
    echo "  -h, --help                Display this help message."
    exit 1
}

# Function for logging
log() {
    echo "INFO: $1"
}

# Function to download rootfs from a URL
download_rootfs() {
    if [[ "${ROOTFS_PATH}" =~ ^https?:// ]]; then
        log "Downloading rootfs from ${ROOTFS_PATH}..."
        # Use wget or curl, whichever is available
        if command -v wget &> /dev/null; then
            wget -O "${WORKDIR}/rootfs.tar.gz" "${ROOTFS_PATH}"
        elif command -v curl &> /dev/null; then
            curl -L -o "${WORKDIR}/rootfs.tar.gz" "${ROOTFS_PATH}"
        else
            echo "Error: Neither wget nor curl is available to download the rootfs."
            exit 1
        fi
        ROOTFS_PATH="${WORKDIR}/rootfs.tar.gz"
        log "Rootfs downloaded to ${ROOTFS_PATH}"
    elif [ ! -f "${ROOTFS_PATH}" ]; then
        echo "Error: Rootfs file not found at ${ROOTFS_PATH}"
        exit 1
    fi
}

# --- Main Script ---

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--rootfs) ROOTFS_PATH="$2"; shift ;;
        -s|--setup-script) SETUP_SCRIPT="$2"; shift ;;
        -c|--config) DEVICE_CONFIG="$2"; shift ;;
        -n|--name) IMAGE_NAME="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate required arguments
if [ -z "${ROOTFS_PATH}" ]; then
    echo "Error: Rootfs path or URL is required."
    usage
fi

log "Starting Thor Hammer build process..."
log "Rootfs: ${ROOTFS_PATH}"
log "Setup Script: ${SETUP_SCRIPT}"
log "Device Config: ${DEVICE_CONFIG}"
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

# 1. Download rootfs if URL is provided
download_rootfs

# Check for root privileges for the next steps
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script requires root privileges for disk partitioning and mounting." >&2
  echo "Please run with sudo."
  exit 1
fi

# 2. Create disk image
log "Creating disk image ${IMAGE_NAME} with size ${IMAGE_SIZE}..."
qemu-img create -f raw "${WORKDIR}/${IMAGE_NAME}" "${IMAGE_SIZE}"

# 3. Create partitions (boot and root)
log "Partitioning the disk image..."
LOOP_DEVICE=$(sudo losetup -f --show "${WORKDIR}/${IMAGE_NAME}")
log "Image mapped to loop device ${LOOP_DEVICE}"

sudo parted -s "${LOOP_DEVICE}" mklabel gpt
sudo parted -s "${LOOP_DEVICE}" mkpart primary fat32 1MiB 513MiB || true
sudo parted -s "${LOOP_DEVICE}" set 1 esp on || true
sudo parted -s "${LOOP_DEVICE}" mkpart primary ext4 513MiB 100% || true

# Force kernel to re-read partition table
log "Informing kernel of partition changes..."
sudo partprobe "${LOOP_DEVICE}" 2>/dev/null || true
sleep 2

# 4. Create filesystems
log "Creating filesystems..."
# Use kpartx to map partitions
sudo kpartx -a "${LOOP_DEVICE}"
sleep 1
BOOT_PARTITION="/dev/mapper/$(basename ${LOOP_DEVICE})p1"
ROOT_PARTITION="/dev/mapper/$(basename ${LOOP_DEVICE})p2"

sudo mkfs.vfat -F32 -n THORBOOT "${BOOT_PARTITION}"
sudo mkfs.ext4 -L THORROOT "${ROOT_PARTITION}"

# 5. Mount root partition
log "Mounting root partition..."
MOUNT_DIR="${WORKDIR}/rootfs"
mkdir -p "${MOUNT_DIR}"
sudo mount "${ROOT_PARTITION}" "${MOUNT_DIR}"

# Mount boot partition
log "Mounting boot partition..."
sudo mkdir -p "${MOUNT_DIR}/boot"
sudo mount "${BOOT_PARTITION}" "${MOUNT_DIR}/boot"

# 6. Extract rootfs
log "Extracting rootfs to the root partition..."
sudo tar -xzf "${ROOTFS_PATH}" -C "${MOUNT_DIR}"

# 6.5. Generate fstab with LABELs
log "Generating /etc/fstab with partition labels..."

sudo tee "${MOUNT_DIR}/etc/fstab" > /dev/null << EOF
# /etc/fstab: static file system information
LABEL=THORROOT    /        ext4    defaults,noatime    0    1
LABEL=THORBOOT    /boot    vfat    defaults,noatime    0    2
EOF

log "fstab created with THORBOOT and THORROOT labels"

# 6.6. Copy custom kernel, DTB, and GRUB config
log "Installing custom kernel and boot files..."

# Check for custom kernel
if [ -f "assets/KERNEL" ]; then
    log "  -> Installing custom kernel..."
    sudo cp "assets/KERNEL" "${MOUNT_DIR}/boot/KERNEL"
    sudo chmod +x "${MOUNT_DIR}/boot/KERNEL"
else
    log "  -> No custom kernel found, will use distribution kernel"
fi

# Check for device tree blob
if [ -f "assets/qcs8550-ayn-thor.dtb" ]; then
    log "  -> Installing device tree blob..."
    sudo cp "assets/qcs8550-ayn-thor.dtb" "${MOUNT_DIR}/boot/qcs8550-ayn-thor.dtb"
else
    log "  -> No DTB found in assets directory"
fi

# 7. Run setup script in QEMU
log "Preparing to run setup script in QEMU..."

# Copy qemu-user-static to the rootfs to enable running ARM binaries
sudo cp /usr/bin/qemu-aarch64-static "${MOUNT_DIR}/usr/bin/"

# Set up network access in the chroot
log "Setting up network access..."
sudo rm -f "${MOUNT_DIR}/etc/resolv.conf"
sudo cp /etc/resolv.conf "${MOUNT_DIR}/etc/resolv.conf"

# Set up /proc, /sys, and /dev in the chroot
log "Binding /proc, /sys, /dev into chroot..."
sudo mount --bind /proc "${MOUNT_DIR}/proc"
sudo mount --bind /sys "${MOUNT_DIR}/sys"
sudo mount --bind /dev "${MOUNT_DIR}/dev"

# Create /etc/mtab symlink if it doesn't exist
log "Setting up /etc/mtab..."
if [ -L "${MOUNT_DIR}/etc/mtab" ]; then
    sudo rm -f "${MOUNT_DIR}/etc/mtab"
fi
sudo ln -sf /proc/self/mounts "${MOUNT_DIR}/etc/mtab"

# Copy the setup script to the rootfs
sudo cp "${SETUP_SCRIPT}" "${MOUNT_DIR}/setup.sh"
sudo chmod +x "${MOUNT_DIR}/setup.sh"

log "Chrooting into rootfs and running setup script..."
# Register binfmt for ARM64 if not already registered
if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    log "Registering ARM64 binfmt handler..."
    echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F' | sudo tee /proc/sys/fs/binfmt_misc/register > /dev/null || true
fi

# Chroot and run the setup script
sudo chroot "${MOUNT_DIR}" /bin/bash /setup.sh

log "Setup script finished."

# 7.5. Install custom GRUB config if available
if [ -f "assets/custom-grub.cfg" ]; then
    log "Installing custom GRUB configuration..."
    sudo cp "assets/custom-grub.cfg" "${MOUNT_DIR}/boot/grub/grub.cfg"
    log "Custom GRUB config installed"
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
sudo kpartx -d "${LOOP_DEVICE}"
sudo losetup -d "${LOOP_DEVICE}"
rmdir "${MOUNT_DIR}"

log "Build process completed successfully!"
log "Image available at: ${WORKDIR}/${IMAGE_NAME}"

exit 0
