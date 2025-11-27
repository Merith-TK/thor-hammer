#!/bin/bash
#
# Thor Hammer - VM Helper
#
# Simplified wrapper to boot Thor Hammer images in QEMU
#

set -e

DEFAULT_IMAGE="build/thor-hammer.img"
IMAGE_FILE=""
MEMORY="2048"
CPUS="2"
GUI_MODE=false

usage() {
    echo "Thor Hammer - VM Helper"
    echo ""
    echo "Usage: thor-vm [options] [image]"
    echo ""
    echo "Arguments:"
    echo "  image            Path to disk image (default: ${DEFAULT_IMAGE})"
    echo ""
    echo "Options:"
    echo "  -g, --gui        Start with GUI (GTK window)"
    echo "  -m, --memory MB  RAM size in MB (default: ${MEMORY})"
    echo "  -c, --cpus N     Number of CPUs (default: ${CPUS})"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Examples:"
    echo "  thor-vm                           # Boot default image in console mode"
    echo "  thor-vm --gui                     # Boot with GUI"
    echo "  thor-vm my-image.img              # Boot custom image"
    echo "  thor-vm --memory 4096 --cpus 4    # More resources"
    echo ""
    echo "Console Mode Controls:"
    echo "  Exit QEMU: Ctrl+A then X"
    echo ""
    echo "GUI Mode Controls:"
    echo "  Exit QEMU: Close window or Alt+Q"
    exit 1
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

# Parse arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--gui)
            GUI_MODE=true
            shift
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -c|--cpus)
            CPUS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

# Get image path from positional args or use default
if [ -n "$1" ]; then
    IMAGE_FILE="$1"
else
    IMAGE_FILE="$DEFAULT_IMAGE"
fi

# Check if image exists
if [ ! -f "$IMAGE_FILE" ]; then
    error "Image file not found: ${IMAGE_FILE}"
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
    error "UEFI firmware not found. Install: qemu-efi-aarch64 or edk2-aarch64"
fi

# Build QEMU command
QEMU_CMD=(
    qemu-system-aarch64
    -M virt
    -cpu cortex-a72
    -m "$MEMORY"
    -smp "$CPUS"
    -drive "file=$IMAGE_FILE,if=virtio,format=raw"
    -bios "$BIOS_PATH"
    -netdev user,id=net0
    -device virtio-net-pci,netdev=net0
)

# Add display options
if [ "$GUI_MODE" = true ]; then
    QEMU_CMD+=(-device virtio-gpu-pci -device virtio-keyboard-pci -device virtio-mouse-pci -display sdl,gl=off -vga none)
else
    QEMU_CMD+=(-nographic)
fi

# Print info
echo "Thor Hammer - VM Helper"
echo "======================="
echo ""
echo "Image:  $IMAGE_FILE"
echo "UEFI:   $BIOS_PATH"
echo "Memory: ${MEMORY}MB"
echo "CPUs:   $CPUS"
echo "Mode:   $([ "$GUI_MODE" = true ] && echo "GUI" || echo "Console")"
echo ""
echo "Login: thor / thor-hammer"
if [ "$GUI_MODE" = false ]; then
    echo "Exit:  Ctrl+A then X"
fi
echo ""

# Run QEMU (use sudo if image is not readable)
if [ -r "$IMAGE_FILE" ]; then
    exec "${QEMU_CMD[@]}"
else
    exec sudo "${QEMU_CMD[@]}"
fi
