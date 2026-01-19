# Thor Hammer 🔨

Builds bootable ARM64 disk images from rootfs tarballs. Built for the AYN Thor but works with any ARM64 device.

## What It Does

Takes a rootfs tarball (Arch Linux ARM, Alpine, Debian, etc.) and creates a bootable disk image with:
- GPT partitioning (512MB boot + 3.5GB root)
- Thor-optimized kernel and firmware (from Kitsumi/ayn-thor-arch)
- GRUB bootloader with device tree support
- Your chosen OS installed and configured

## Requirements

- VS Code with Dev Containers extension (or Docker)
- 4GB+ free disk space

## Usage

### Build an Image

```bash
# Open project in VS Code Dev Container

# Build Arch Linux ARM image
sudo thor-build -r assets/ArchLinuxARM-aarch64-latest.tar.gz

# Or use the direct path
sudo ./scripts/thor-build.sh -r assets/ArchLinuxARM-aarch64-latest.tar.gz

# Output: build/thor-hammer.img
```

### Flash to SD Card

```bash
sudo dd if=build/thor-hammer.img of=/dev/sdX bs=4M status=progress
```

**Default login:** `thor` / `thor-hammer` (change immediately!)

### Build Options

```bash
# Main build command
thor-build -r <rootfs> [options]

# Common options:
#   -r, --rootfs <path>      Path to rootfs tarball (required)
#   -n, --name <name>        Output image name

# See all options
thor-build --help
```

## Useful Commands

```bash
# Test image in QEMU
thor-vm                    # Console mode (Ctrl+A then X to exit)
thor-vm --gui              # GUI mode

# Chroot into image (modify without booting)
sudo thor-chroot

# Mount image to inspect files
sudo ./scripts/mount-image.sh
# Files at: /tmp/thor-mount/boot/ and /tmp/thor-mount/root/
sudo ./scripts/unmount-image.sh
```

For detailed usage, see [QUICKSTART.md](QUICKSTART.md)

## Supported Distros

- ✅ Arch Linux ARM (working)
- 🚧 Alpine, Debian (in progress)

## Notes

- Boot partition is FAT32 with GRUB and kernel files
- Root partition is ext4 with full OS
- Images are built using QEMU user-mode emulation
- Setup scripts run inside chroot to configure the system
- Thor-specific packages (kernel, firmware, GRUB) are automatically built from [Kitsumi/ayn-thor-arch](https://github.com/Kitsumi/ayn-thor-arch) during setup
