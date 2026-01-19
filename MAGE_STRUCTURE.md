# Thor Hammer Mage Structure

The Mage build system is organized into multiple files for easy navigation:

## File Organization

```
magefile.go      - Configuration, constants, shared helpers
mage_build.go    - Build operations (kernel, DTB, rootfs, image)
mage_vm.go       - Virtual machine operations
mage_image.go    - Image mount/unmount operations
mage_dev.go      - Development tools (chroot)
```

## Why Split Files?

- **Easy Navigation**: Jump directly to the file you need
- **Clear Separation**: Each file has a single responsibility
- **Better IDE Support**: Smaller files = faster autocomplete
- **Easier Maintenance**: Changes are isolated to specific files

## Available Targets

### Complete Build
- `mage build` - Build everything (rootfs + image)

### Individual Components
- `mage buildRootfs` - Download, extract, and configure rootfs (kernel/DTB installed via packages)
- `mage buildImage` - Create bootable disk image

### VM Operations
- `mage vm` - Boot in console mode
- `mage vmGui` - Boot with GUI

### Image Operations
- `mage mount` - Mount image for inspection
- `mage unmount` - Unmount image

### Development
- `mage chroot` - Enter rootfs chroot

### Cleanup
- `mage clean` - Remove build artifacts

## Environment Variables

Override defaults with environment variables:

```bash
ROOTFS_URL=https://example.com/rootfs.tar.gz mage buildRootfs
ROOTFS_TAR=/path/to/rootfs.tar.gz mage buildRootfs
SETUP_SCRIPT=/path/to/script.sh mage buildRootfs
MEMORY=4096 CPUS=4 mage vm
```

## Quick Start

```bash
# Build complete image (kernel/DTB handled by packages)
sudo mage build

# Test in VM
mage vm

# Mount for inspection
sudo mage mount
ls -la /tmp/thor-mount/boot
ls -la /tmp/thor-mount/root
sudo mage unmount
```

## File Details

### magefile.go (132 lines)
- Configuration constants (paths, sizes, defaults)
- Helper functions (logging, file operations, loop cleanup)
- Shared utilities used across all mage files

### mage_build.go (280 lines)
- `Build()` - Main orchestrator
- `BuildRootfs()` - Rootfs preparation
- `BuildImage()` - Disk image creation
- `Clean()` - Cleanup operations
- Helper functions for tar extraction and chroot operations

### mage_vm.go (72 lines)
- `VM()` - Console mode QEMU
- `VMGui()` - GUI mode QEMU
- VM startup logic with UEFI firmware detection

### mage_image.go (78 lines)
- `Mount()` - Mount disk image partitions
- `Unmount()` - Unmount and cleanup

### mage_dev.go (30 lines)
- `Chroot()` - Enter ARM64 chroot environment

## Adding New Targets

Want to add a new target? Add it to the appropriate file:

**VM operation?** → Add to `mage_vm.go`
**Build step?** → Add to `mage_build.go`  
**Dev tool?** → Add to `mage_dev.go`

Example:
```go
// In mage_vm.go
func VMDebug() error {
    // Add debugging flags to QEMU
    return startVM(false)
}
```

Then run: `mage vmDebug`
