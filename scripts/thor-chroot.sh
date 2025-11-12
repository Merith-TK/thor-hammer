#!/bin/bash
#
# Thor Hammer - Chroot Helper
#
# Simplified wrapper to enter a chroot environment in a Thor Hammer image
#

set -e

DEFAULT_IMAGE="build/thor-hammer.img"
IMAGE_PATH="${1:-$DEFAULT_IMAGE}"
MOUNT_BASE="/tmp/thor-mount"
ROOT_MOUNT="${MOUNT_BASE}/root"

usage() {
    echo "Thor Hammer - Chroot Helper"
    echo ""
    echo "Usage: thor-chroot [image]"
    echo ""
    echo "Arguments:"
    echo "  image    Path to disk image (default: ${DEFAULT_IMAGE})"
    echo ""
    echo "Examples:"
    echo "  thor-chroot                      # Use default image"
    echo "  thor-chroot my-custom.img        # Use custom image"
    echo "  thor-chroot /path/to/image.img   # Use specific path"
    exit 1
}

log() {
    echo "INFO: $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

cleanup() {
    log "Cleaning up..."
    
    # Remove qemu-aarch64-static
    rm -f "${ROOT_MOUNT}/usr/bin/qemu-aarch64-static" 2>/dev/null || true
    
    # Unmount bind mounts
    umount "${ROOT_MOUNT}/proc" 2>/dev/null || true
    umount "${ROOT_MOUNT}/sys" 2>/dev/null || true
    umount "${ROOT_MOUNT}/dev" 2>/dev/null || true
    
    # Unmount boot partition
    umount "${ROOT_MOUNT}/boot" 2>/dev/null || true
    
    # Unmount root partition
    umount "${ROOT_MOUNT}" 2>/dev/null || true
    
    # Remove partition mappings
    if [ -n "${LOOP_DEVICE}" ]; then
        kpartx -d "${LOOP_DEVICE}" 2>/dev/null || true
        losetup -d "${LOOP_DEVICE}" 2>/dev/null || true
    fi
    
    # Remove mount points
    rmdir "${ROOT_MOUNT}/boot" 2>/dev/null || true
    rmdir "${ROOT_MOUNT}" 2>/dev/null || true
    rmdir "${MOUNT_BASE}" 2>/dev/null || true
    
    log "✅ Cleanup complete!"
}

# Trap cleanup on exit
trap cleanup EXIT

# Parse arguments
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    error "This script requires root privileges. Run with: sudo thor-chroot"
fi

# Check if image exists
if [ ! -f "${IMAGE_PATH}" ]; then
    error "Image file not found: ${IMAGE_PATH}"
fi

log "Thor Hammer - Chroot Helper"
log "Image: ${IMAGE_PATH}"
log ""

# Set up loop device
LOOP_DEVICE=$(losetup -f --show "${IMAGE_PATH}")
log "Image mapped to loop device: ${LOOP_DEVICE}"

# Map partitions
kpartx -a "${LOOP_DEVICE}"
sleep 1

# Get partition devices
BOOT_PARTITION="/dev/mapper/$(basename ${LOOP_DEVICE})p1"
ROOT_PARTITION="/dev/mapper/$(basename ${LOOP_DEVICE})p2"

# Create mount points
mkdir -p "${ROOT_MOUNT}"
mkdir -p "${ROOT_MOUNT}/boot"

# Mount partitions
log "Mounting partitions..."
mount "${ROOT_PARTITION}" "${ROOT_MOUNT}"
mount "${BOOT_PARTITION}" "${ROOT_MOUNT}/boot"

# Set up chroot environment
log "Setting up chroot environment..."

# Copy qemu-aarch64-static for ARM64 emulation
cp /usr/bin/qemu-aarch64-static "${ROOT_MOUNT}/usr/bin/" 2>/dev/null || true

# Set up resolv.conf for network access
rm -f "${ROOT_MOUNT}/etc/resolv.conf"
cp /etc/resolv.conf "${ROOT_MOUNT}/etc/resolv.conf"

# Set up /etc/mtab
if [ -L "${ROOT_MOUNT}/etc/mtab" ]; then
    rm -f "${ROOT_MOUNT}/etc/mtab"
fi
ln -sf /proc/self/mounts "${ROOT_MOUNT}/etc/mtab"

# Bind mount necessary filesystems
mount --bind /proc "${ROOT_MOUNT}/proc"
mount --bind /sys "${ROOT_MOUNT}/sys"
mount --bind /dev "${ROOT_MOUNT}/dev"

# Register binfmt for ARM64 if not already registered
if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    log "Registering ARM64 binfmt handler..."
    echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F' | tee /proc/sys/fs/binfmt_misc/register > /dev/null 2>&1 || true
fi

log ""
log "✅ Chroot environment ready!"
log ""
log "Entering chroot shell..."
log "Type 'exit' to leave the chroot and unmount."
log ""

# Enter chroot
chroot "${ROOT_MOUNT}" /bin/bash

# Cleanup happens automatically via trap
