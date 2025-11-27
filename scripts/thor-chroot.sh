#!/bin/bash
#
# Thor Hammer - Chroot Helper
#
# Wrapper around arch-chroot that adds ARM64 support via qemu-user-static
# for prepared rootfs directories.
#

set -e

DEFAULT_ROOTFS="build/rootfs"

usage() {
    echo "Thor Hammer - Chroot Helper"
    echo ""
    echo "Usage: thor-chroot [-r directory] [command] [arguments...]"
    echo ""
    echo "Arguments:"
    echo "  -r directory    Path to prepared rootfs directory (optional)"
    echo "                  Default: ${DEFAULT_ROOTFS}"
    echo "  command         Command to run in chroot (optional)"
    echo "                  Default: /bin/bash (interactive shell)"
    echo ""
    echo "Examples:"
    echo "  thor-chroot                          # Interactive shell in default rootfs"
    echo "  thor-chroot -r /path/to/rootfs       # Interactive shell in specific rootfs"
    echo "  thor-chroot echo hello               # Run command in default rootfs"
    echo "  thor-chroot -r ./rootfs pacman -Syu  # Update packages in specific rootfs"
    echo ""
    echo "Note: Uses arch-chroot from arch-install-scripts with ARM64 support via qemu-user-static"
    echo "      For disk images, use thor-vm instead."
    exit 1
}

log() {
    echo "INFO: $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

# Parse arguments first
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    error "This script requires root privileges. Run with: sudo thor-chroot"
fi

# Check if arch-chroot is available
if ! command -v arch-chroot &>/dev/null; then
    error "arch-chroot not found. Install arch-install-scripts package."
fi

# Parse arguments: -r for rootfs directory, rest is command
ROOTFS_DIR="${DEFAULT_ROOTFS}"
CHROOT_CMD=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -r)
            ROOTFS_DIR="$2"
            shift 2
            ;;
        *)
            # Everything else is the command
            CHROOT_CMD=("$@")
            break
            ;;
    esac
done

# If no command specified, default to interactive bash
if [ ${#CHROOT_CMD[@]} -eq 0 ]; then
    CHROOT_CMD=(/bin/bash)
fi

# Verify target is a directory
if [ ! -d "${ROOTFS_DIR}" ]; then
    error "Rootfs directory not found: ${ROOTFS_DIR}"
fi

cleanup() {
    log "Cleaning up..."
    
    # Remove qemu-aarch64-static if we added it
    if [ -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static" ]; then
        rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static" 2>/dev/null || true
    fi
    
    # Unbind mount if we created it
    if [ "${NEED_UNBIND}" = true ]; then
        umount "${ROOTFS_DIR}" 2>/dev/null || true
    fi
    
    log "✅ Cleanup complete!"
}

# Trap cleanup on exit
trap cleanup EXIT

log "Thor Hammer - Chroot Helper (using arch-chroot)"
log "Target: ${ROOTFS_DIR}"
log ""

# For directories, we need to make it a mountpoint for arch-chroot
# If it's not already mounted, bind mount it to itself
if ! mountpoint -q "${ROOTFS_DIR}"; then
    log "Making directory a mountpoint..."
    mount --bind "${ROOTFS_DIR}" "${ROOTFS_DIR}"
    NEED_UNBIND=true
fi

# Set up ARM64 support
log "Setting up ARM64 emulation..."

# Copy qemu-aarch64-static for ARM64 emulation
if [ ! -f /usr/bin/qemu-aarch64-static ]; then
    error "qemu-aarch64-static not found. Install qemu-user-static or qemu-user-static-binfmt."
fi

cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/"

# Register binfmt for ARM64 if not already registered
if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    log "Registering ARM64 binfmt handler..."
    echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F' | tee /proc/sys/fs/binfmt_misc/register > /dev/null 2>&1 || true
fi

log ""
log "✅ Chroot environment ready!"
log ""

# Show different message for interactive vs command mode
if [ "${CHROOT_CMD[0]}" = "/bin/bash" ] && [ ${#CHROOT_CMD[@]} -eq 1 ]; then
    log "Entering interactive chroot shell..."
    log "Type 'exit' to leave the chroot."
else
    log "Running command in chroot: ${CHROOT_CMD[*]}"
fi

log ""

# Use arch-chroot to run the command (it handles all the mounting)
arch-chroot "${ROOTFS_DIR}" "${CHROOT_CMD[@]}"

# Cleanup happens automatically via trap
# Note: arch-chroot will handle unmounting /proc, /sys, /dev, etc.