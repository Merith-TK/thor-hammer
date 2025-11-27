#!/bin/bash
#
# Thor Hammer - Mount Image Script
#
# This script mounts a Thor Hammer disk image for inspection and modification
#

set -e

IMAGE_PATH="${1:-build/thor-hammer.img}"
MOUNT_BASE="/tmp/thor-mount"

# Function for logging
log() {
    echo "INFO: $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    error "This script requires root privileges. Please run with sudo."
fi

# Check if image exists
if [ ! -f "${IMAGE_PATH}" ]; then
    error "Image file not found: ${IMAGE_PATH}"
fi

log "Mounting image: ${IMAGE_PATH}"

# Set up loop device
LOOP_DEVICE=$(losetup -f --show "${IMAGE_PATH}")
log "Image mapped to loop device: ${LOOP_DEVICE}"

# Map partitions
kpartx -a "${LOOP_DEVICE}"
sleep 1

# Get partition devices
BOOT_PARTITION="/dev/mapper/$(basename ${LOOP_DEVICE})p1"
ROOT_PARTITION="/dev/mapper/$(basename ${LOOP_DEVICE})p2"

log "Boot partition: ${BOOT_PARTITION}"
log "Root partition: ${ROOT_PARTITION}"

# Create mount points
BOOT_MOUNT="${MOUNT_BASE}/boot"
ROOT_MOUNT="${MOUNT_BASE}/root"

mkdir -p "${BOOT_MOUNT}"
mkdir -p "${ROOT_MOUNT}"

# Mount partitions
log "Mounting root partition..."
mount "${ROOT_PARTITION}" "${ROOT_MOUNT}"

log "Mounting boot partition..."
mount "${BOOT_PARTITION}" "${BOOT_MOUNT}"

log ""
log "✅ Image mounted successfully!"
log ""
log "Mount points:"
log "  Boot partition: ${BOOT_MOUNT}"
log "  Root partition: ${ROOT_MOUNT}"
log ""
log "To unmount, run: sudo ./scripts/unmount-image.sh"
log ""
log "You can now access the filesystem:"
log "  Boot files: ls -la ${BOOT_MOUNT}"
log "  Root files: ls -la ${ROOT_MOUNT}"
log "  GRUB config: cat ${BOOT_MOUNT}/grub/grub.cfg"
log ""
