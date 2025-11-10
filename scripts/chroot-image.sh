#!/bin/bash
#
# Thor Hammer - Chroot Into Image Script
#
# This script mounts the image and chroots into it with QEMU user-mode emulation
# allowing you to make changes and run commands as if you were booted into the system
#

set -e

IMAGE_PATH="${1:-build/thor-hammer.img}"
MOUNT_BASE="/tmp/thor-mount"
ROOT_MOUNT="${MOUNT_BASE}/root"

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

log "Setting up chroot environment for: ${IMAGE_PATH}"

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
log "Mounting root partition..."
mount "${ROOT_PARTITION}" "${ROOT_MOUNT}"

log "Mounting boot partition..."
mount "${BOOT_PARTITION}" "${ROOT_MOUNT}/boot"

# Set up chroot environment
log "Setting up chroot environment..."

# Copy qemu-aarch64-static
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
log "Binding /proc, /sys, /dev..."
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

# Cleanup after exiting chroot
log ""
log "Exited chroot. Cleaning up..."

# Remove qemu-aarch64-static
rm -f "${ROOT_MOUNT}/usr/bin/qemu-aarch64-static"

# Unmount bind mounts
umount "${ROOT_MOUNT}/proc" 2>/dev/null || true
umount "${ROOT_MOUNT}/sys" 2>/dev/null || true
umount "${ROOT_MOUNT}/dev" 2>/dev/null || true

# Unmount boot partition
umount "${ROOT_MOUNT}/boot"

# Unmount root partition
umount "${ROOT_MOUNT}"

# Remove partition mappings
kpartx -d "${LOOP_DEVICE}"

# Detach loop device
losetup -d "${LOOP_DEVICE}"

# Remove mount points
rmdir "${ROOT_MOUNT}/boot" 2>/dev/null || true
rmdir "${ROOT_MOUNT}" 2>/dev/null || true
rmdir "${MOUNT_BASE}" 2>/dev/null || true

log "✅ Cleanup complete!"
