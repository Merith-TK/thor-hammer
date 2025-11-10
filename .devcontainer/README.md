# Thor Hammer Development Container

This directory contains the VS Code Dev Container configuration for the Thor Hammer project.

## What's Included

### Base Image
- **git.merith.xyz/oci/archlinux** - Your custom Arch Linux image with `yay` and development tools

### Development Tools
- **Cross-compilation toolchain** - aarch64-linux-gnu-gcc for ARM64 targets
- **U-Boot tools** - mkimage, dumpimage for boot script compilation
- **Device tree compiler** - dtc for device tree manipulation
- **Android tools** - fastboot, adb for device interaction
- **QEMU** - ARM64 emulation for testing
- **Python tools** - Serial communication and device flashing utilities

### VS Code Extensions
- **C/C++ Extension Pack** - IntelliSense, debugging, and code navigation
- **CMake Tools** - Build system support
- **Python** - Python development and debugging
- **Hex Editor** - Binary file inspection
- **YAML Support** - Configuration file editing
- **Markdown** - Documentation editing

### Environment Setup
The container automatically configures:
- Cross-compilation environment variables (`CROSS_COMPILE`, `ARCH`)
- Useful aliases (`thor-build`, `thor-rootfs`, etc.)
- Development paths and tools
- Persistent cache volumes for faster builds

## Usage

1. **Open in VS Code**: Use "Reopen in Container" when prompted
2. **Initial Setup**: The container will automatically install all development tools
3. **Start Development**: Use the `thor-status` command to see available tools
4. **Build Commands**: Use aliases like `thor-build` for common tasks

## Available Commands

Once in the container, you can use these commands:

```bash
thor-status       # Show development environment status
thor-cd          # Navigate to workspace root
thor-build       # Build U-Boot boot script
thor-rootfs      # Prepare Linux rootfs
thor-uboot       # Display U-Boot commands
thor-logs        # View development logs
check-crossgcc   # Verify cross-compiler setup
```

## Persistent Storage

The container uses Docker volumes for:
- **Build cache** (`~/.cache`) - Speeds up package installations
- **Compilation cache** (`~/.ccache`) - Accelerates kernel/U-Boot builds

## Container Resources

- **Memory**: 4GB recommended
- **CPU**: 2 cores minimum
- **Storage**: ~10GB for tools and cache

The container is optimized for Android device Linux boot development with all necessary cross-compilation tools and utilities pre-installed.