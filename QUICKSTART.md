# Thor Hammer - Quick Reference Guide

This guide provides quick commands for building and managing Thor Hammer images.

## Main Commands

### `thor-build` - Build System
Unified build command that handles both kernel compilation and image creation.

```bash
# Build image only (using existing kernel)
sudo thor-build -r /path/to/rootfs.tar.gz

# Build kernel and image together
sudo thor-build -r /path/to/rootfs.tar.gz --use-ayn-kernel

# Build kernel only (no image)
thor-build --use-ayn-kernel --no-image

# Force rebuild kernel from scratch
thor-build --use-ayn-kernel --rebuild-kernel --clean-kernel --no-image

# Build with custom image name
sudo thor-build -r rootfs.tar.gz --use-ayn-kernel -n my-custom.img
```

**Common Options:**
- `-r, --rootfs <path|url>` - Path or URL to rootfs tarball (required for image)
- `-n, --name <name>` - Output image name (default: thor-hammer.img)
- `--use-ayn-kernel` - Build AYN Linux kernel
- `--rebuild-kernel` - Force kernel rebuild
- `--clean-kernel` - Clean build artifacts first
- `--no-image` - Skip image creation (kernel only)

### `thor-chroot` - Enter Chroot
Mount and enter a chroot environment in a Thor Hammer image.

```bash
# Use default image (build/thor-hammer.img)
sudo thor-chroot

# Use custom image
sudo thor-chroot my-custom.img
sudo thor-chroot /path/to/image.img
```

**Features:**
- Automatic partition mounting (boot + root)
- ARM64 emulation via qemu-user-static
- Network access (DNS resolution)
- Automatic cleanup on exit

**Controls:**
- `exit` - Leave chroot and cleanup

### `thor-vm` - Boot in QEMU
Start a Thor Hammer image in QEMU for testing.

```bash
# Console mode (default)
thor-vm

# GUI mode with GTK window
thor-vm --gui

# Custom image
thor-vm my-custom.img

# More resources
thor-vm --memory 4096 --cpus 4

# Custom image with GUI
thor-vm --gui my-custom.img
```

**Options:**
- `-g, --gui` - Start with GUI window
- `-m, --memory MB` - RAM size in MB (default: 2048)
- `-c, --cpus N` - Number of CPUs (default: 2)

**Controls:**
- Console mode: `Ctrl+A` then `X` to exit
- GUI mode: Close window or `Alt+Q`

## Workflow Examples

### Complete Build from Scratch
```bash
# 1. Build kernel and create image
sudo thor-build -r http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz --use-ayn-kernel

# 2. Test in QEMU
thor-vm

# 3. Make changes if needed
sudo thor-chroot
# ... make changes ...
exit

# 4. Test again
thor-vm
```

### Update Existing Image
```bash
# Enter chroot
sudo thor-chroot

# Install/update packages
pacman -Syu
pacman -S neovim htop

# Configure system
systemctl enable some-service

# Exit
exit

# Test changes
thor-vm --gui
```

### Rebuild Just the Kernel
```bash
# Rebuild kernel with clean build
thor-build --use-ayn-kernel --rebuild-kernel --clean-kernel --no-image

# Rebuild image with new kernel
sudo thor-build -r /path/to/rootfs.tar.gz
```

### Build for Different Distributions
```bash
# Arch Linux ARM
sudo thor-build -r http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz --use-ayn-kernel

# Alpine Linux (when supported)
sudo thor-build -r /path/to/alpine-arm64.tar.gz --use-ayn-kernel -s scripts/setup-alpine.sh

# Debian (when supported)
sudo thor-build -r /path/to/debian-arm64.tar.gz --use-ayn-kernel -s scripts/setup-debian.sh
```

## Directory Structure

```
/workspaces/.thor-hammer/
├── scripts/
│   ├── thor-build.sh        # Main build script
│   ├── thor-chroot.sh       # Chroot helper
│   ├── thor-vm.sh           # QEMU helper
│   ├── setup-archlinux.sh   # Arch Linux setup script
│   ├── mount-image.sh       # Manual mounting utility
│   └── unmount-image.sh     # Manual unmounting utility
├── assets/                  # Kernel, DTB, configs
│   ├── KERNEL               # Built kernel image
│   ├── qcs8550-ayn-thor.dtb
│   └── custom-grub.cfg
├── build/                   # Build artifacts
│   └── thor-hammer.img      # Output disk image
└── logs/                    # Build logs
```

## Kernel Details

**Source:** https://github.com/AYNTechnologies/linux.git  
**Location:** `/tmp/thor-kernel`  
**Output:** `assets/KERNEL` and `assets/qcs8550-ayn-thor.dtb`

**Incremental Builds:**
- By default, kernel builds are incremental (faster)
- Use `--clean-kernel` for full clean build
- Use `--rebuild-kernel` to force rebuild even if artifacts exist

## Image Details

**Default Size:** 4GB  
**Partitions:**
- `THORBOOT` (512MB, FAT32) - Boot partition with GRUB, kernel, DTB
- `THORROOT` (3.5GB, ext4) - Root filesystem

**Bootloader:** GRUB (arm64-efi)  
**Boot Method:** RockNIX-style with `boot=LABEL=THORBOOT disk=LABEL=THORROOT`

## Troubleshooting

### "Loop device already in use"
```bash
# Clean up loop devices
sudo scripts/unmount-image.sh
```

### "Kernel source not found"
```bash
# Clone kernel source
git clone --depth=1 https://github.com/AYNTechnologies/linux.git /tmp/thor-kernel
```

### "Cross-compiler not found"
```bash
# Install cross-compiler
yay -S aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils
```

### "Permission denied" when running commands
Most commands need sudo for mounting and partitioning:
```bash
sudo thor-build ...
sudo thor-chroot ...
# thor-vm usually doesn't need sudo
```

## Tips

- **Aliases are available:** After container restart, just type `thor-build`, `thor-chroot`, or `thor-vm`
- **Kernel builds are cached:** Subsequent builds only take seconds if kernel unchanged
- **Use --help:** All commands support `--help` flag for detailed options
- **Check logs:** Use `thor-logs` alias to monitor build logs
- **Test before flashing:** Always test in QEMU with `thor-vm` before flashing to device

## Next Steps

1. **Build your first image:** `sudo thor-build -r <rootfs> --use-ayn-kernel`
2. **Test in QEMU:** `thor-vm`
3. **Customize:** `sudo thor-chroot` and make changes
4. **Flash to device:** Use `dd` or imaging tool to write `build/thor-hammer.img` to SD card
