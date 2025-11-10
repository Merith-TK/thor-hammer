#!/bin/bash
# Start QEMU in console mode (serial/nographic)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_FILE="${PROJECT_DIR}/build/thor-hammer.img"

# Check if image exists
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: Image not found at $IMAGE_FILE"
    echo "Run ./scripts/build.sh first to create the image"
    exit 1
fi

# Find UEFI firmware
BIOS_PATH=""
for path in "/usr/share/edk2/aarch64/QEMU_EFI.fd" \
            "/usr/share/AAVMF/AAVMF_CODE.fd" \
            "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"; do
    if [ -f "$path" ]; then
        BIOS_PATH="$path"
        break
    fi
done

if [ -z "$BIOS_PATH" ]; then
    echo "Error: UEFI firmware not found"
    echo "Install: qemu-efi-aarch64 or edk2-aarch64"
    exit 1
fi

echo "Starting QEMU (console mode)..."
echo "Image: $IMAGE_FILE"
echo "UEFI: $BIOS_PATH"
echo ""
echo "Login: thor / thor-hammer"
echo "Exit QEMU: Ctrl+A then X"
echo ""

# Run QEMU with sudo if needed
if [ -r "$IMAGE_FILE" ]; then
    qemu-system-aarch64 \
        -M virt \
        -cpu cortex-a72 \
        -m 2048 \
        -smp 2 \
        -drive file="$IMAGE_FILE",if=virtio,format=raw \
        -bios "$BIOS_PATH" \
        -nographic \
        -netdev user,id=net0 \
        -device virtio-net-pci,netdev=net0
else
    sudo qemu-system-aarch64 \
        -M virt \
        -cpu cortex-a72 \
        -m 2048 \
        -smp 2 \
        -drive file="$IMAGE_FILE",if=virtio,format=raw \
        -bios "$BIOS_PATH" \
        -nographic \
        -netdev user,id=net0 \
        -device virtio-net-pci,netdev=net0
fi
