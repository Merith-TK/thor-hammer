# Thor Hammer - Assets Directory

This directory contains kernel and device tree files used for booting the AYN Thor device.

## Files

### KERNEL
- **Source**: [AYN Technologies Linux Kernel](https://github.com/AYNTechnologies/linux.git)
- **Architecture**: ARM64 (aarch64)
- **Format**: Raw kernel Image (ELF64 aarch64)
- **Build Tool**: `scripts/build-kernel.sh`
- **Cross Compiler**: aarch64-linux-gnu-gcc

This is a custom Linux kernel maintained by AYN Technologies specifically for their handheld devices (Thor, Odin2, etc.). It includes device-specific drivers and patches required for proper hardware support.

### qcs8550-ayn-thor.dtb
- **Source**: [AYN Technologies Linux Kernel](https://github.com/AYNTechnologies/linux.git)
- **Device Tree Source**: `arch/arm64/boot/dts/qcom/qcs8550-ayn-thor.dts`
- **SoC**: Qualcomm QCS8550
- **Target Device**: AYN Thor handheld gaming device
- **Build Tool**: `scripts/build-kernel.sh`
- **Cross Compiler**: aarch64-linux-gnu-gcc (dtc)

The Device Tree Blob (DTB) describes the hardware layout of the AYN Thor device to the Linux kernel, including:
- CPU and memory configuration
- Peripheral device mappings
- GPIO pin assignments
- Display and input device definitions

## Building

To build or rebuild these files:

```bash
# Build both kernel and DTB (if they don't exist)
bash scripts/build-kernel.sh

# Force rebuild both
bash scripts/build-kernel.sh --rebuild

# Build only kernel
bash scripts/build-kernel.sh --rebuild --skip-dtb

# Build only DTB
bash scripts/build-kernel.sh --rebuild --skip-kernel
```

## Usage

These files are automatically included in the disk image when building with:

```bash
sudo bash scripts/build.sh -r /path/to/rootfs.tar.gz --use-ayn-kernel
```

The kernel and DTB are copied to the boot partition and referenced in the GRUB configuration.

## License

The AYN Linux kernel is licensed under GPLv2. See the [kernel repository](https://github.com/AYNTechnologies/linux.git) for full license details.

## Notes

- These files are compiled specifically for ARM64 architecture
- They require UEFI firmware and GRUB bootloader to boot
- The kernel includes proprietary firmware blobs for Qualcomm hardware
- These files are NOT committed to git and are generated during the build process
