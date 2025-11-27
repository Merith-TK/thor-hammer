#!/bin/bash
#
# Thor Hammer - Unmount Image Script
#
# This script unmounts a previously mounted Thor Hammer disk image
#

set -e

MOUNT_BASE="/tmp/thor-mount"

# Function for logging
log() {
    echo "INFO: $1"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script requires root privileges. Please run with sudo." >&2
    exit 1
fi

log "Unmounting Thor Hammer image..."

# Unmount boot partition
if mountpoint -q "${MOUNT_BASE}/boot" 2>/dev/null; then
    log "Unmounting boot partition..."
    umount "${MOUNT_BASE}/boot"
    rmdir "${MOUNT_BASE}/boot" 2>/dev/null || true
fi

# Unmount root partition
if mountpoint -q "${MOUNT_BASE}/root" 2>/dev/null; then
    log "Unmounting root partition..."
    umount "${MOUNT_BASE}/root"
    rmdir "${MOUNT_BASE}/root" 2>/dev/null || true
fi

# Remove mount base directory
rmdir "${MOUNT_BASE}" 2>/dev/null || true

# Remove partition mappings
log "Removing partition mappings..."
for loop in /dev/loop*; do
    if [ -b "$loop" ]; then
        kpartx -d "$loop" 2>/dev/null || true
    fi
done

# Detach all loop devices
log "Detaching loop devices..."
losetup -D 2>/dev/null || true

log "✅ Image unmounted successfully!"
