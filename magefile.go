//go:build mage
// +build mage

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/magefile/mage/mg"
	"github.com/magefile/mage/sh"
)

// Configuration constants
const (
	DefaultImage     = "build/thor-hammer.img"
	DefaultRootfsDir = "build/rootfs"
	KernelSource     = "/tmp/thor-kernel"
	OutputDir        = "/workspaces/.thor-hammer/assets"
	DTBName          = "qcs8550-ayn-thor"
	DefaultMemory    = "2048"
	DefaultCPUs      = "2"
	MountBase        = "/tmp/thor-mount"
)

var (
	// Kernel build configuration
	kernelArch         = "arm64"
	kernelCrossCompile = "aarch64-linux-gnu-"
)

// Build namespace contains all build-related targets
type Build mg.Namespace

// VM namespace contains virtual machine operations
type VM mg.Namespace

// Image namespace contains image manipulation operations
type Image mg.Namespace

// Dev namespace contains development operations
type Dev mg.Namespace

// Ensure we're running as root for operations that need it
func ensureRoot() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("this operation requires root privileges. Please run with sudo")
	}
	return nil
}

// Check if a command exists in PATH
func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

// Logger helpers
func logInfo(format string, args ...interface{}) {
	fmt.Printf("INFO: "+format+"\n", args...)
}

func logSuccess(format string, args ...interface{}) {
	fmt.Printf("✅ "+format+"\n", args...)
}

func logError(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
}

func logWarning(format string, args ...interface{}) {
	fmt.Printf("⚠️  "+format+"\n", args...)
}

// =============================================================================
// VM Operations
// =============================================================================

// Start boots the Thor Hammer image in QEMU (console mode)
func (VM) Start() error {
	return vmStart(false, DefaultImage, DefaultMemory, DefaultCPUs)
}

// GUI boots the Thor Hammer image in QEMU with GUI
func (VM) GUI() error {
	return vmStart(true, DefaultImage, DefaultMemory, DefaultCPUs)
}

// Custom allows custom VM configuration
// Usage: mage vm:custom [image] [memory] [cpus] [gui]
func (VM) Custom() error {
	// Parse command line args (simplified for demo)
	imagePath := getEnvOrDefault("IMAGE", DefaultImage)
	memory := getEnvOrDefault("MEMORY", DefaultMemory)
	cpus := getEnvOrDefault("CPUS", DefaultCPUs)
	gui := getEnvOrDefault("GUI", "false") == "true"

	return vmStart(gui, imagePath, memory, cpus)
}

func vmStart(gui bool, imagePath, memory, cpus string) error {
	logInfo("Thor Hammer - VM Helper")
	logInfo("======================")
	fmt.Println()

	// Check if image exists
	if _, err := os.Stat(imagePath); os.IsNotExist(err) {
		return fmt.Errorf("image file not found: %s", imagePath)
	}

	// Find UEFI firmware
	biosPath := findUEFIFirmware()
	if biosPath == "" {
		return fmt.Errorf("UEFI firmware not found. Install: qemu-efi-aarch64 or edk2-aarch64")
	}

	// Build QEMU command
	args := []string{
		"-M", "virt",
		"-cpu", "cortex-a72",
		"-m", memory,
		"-smp", cpus,
		"-drive", fmt.Sprintf("file=%s,if=virtio,format=raw", imagePath),
		"-bios", biosPath,
		"-netdev", "user,id=net0",
		"-device", "virtio-net-pci,netdev=net0",
	}

	// Add display options
	if gui {
		args = append(args,
			"-device", "virtio-gpu-pci",
			"-device", "virtio-keyboard-pci",
			"-device", "virtio-mouse-pci",
			"-display", "sdl,gl=off",
			"-vga", "none",
		)
	} else {
		args = append(args, "-nographic")
	}

	// Print info
	logInfo("Image:  %s", imagePath)
	logInfo("UEFI:   %s", biosPath)
	logInfo("Memory: %sMB", memory)
	logInfo("CPUs:   %s", cpus)
	logInfo("Mode:   %s", map[bool]string{true: "GUI", false: "Console"}[gui])
	fmt.Println()
	logInfo("Login: thor / thor-hammer")
	if !gui {
		logInfo("Exit:  Ctrl+A then X")
	}
	fmt.Println()

	// Run QEMU
	cmd := exec.Command("qemu-system-aarch64", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

func findUEFIFirmware() string {
	paths := []string{
		"/usr/share/edk2/aarch64/QEMU_EFI.fd",
		"/usr/share/AAVMF/AAVMF_CODE.fd",
		"/usr/share/qemu-efi-aarch64/QEMU_EFI.fd",
	}

	for _, path := range paths {
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	return ""
}

// =============================================================================
// Image Operations
// =============================================================================

// Mount mounts a Thor Hammer disk image for inspection
func (Image) Mount() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	imagePath := getEnvOrDefault("IMAGE", DefaultImage)
	return mountImage(imagePath)
}

// Unmount unmounts a previously mounted Thor Hammer disk image
func (Image) Unmount() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	return unmountImage()
}

func mountImage(imagePath string) error {
	logInfo("Mounting image: %s", imagePath)

	// Check if image exists
	if _, err := os.Stat(imagePath); os.IsNotExist(err) {
		return fmt.Errorf("image file not found: %s", imagePath)
	}

	// Set up loop device
	output, err := sh.Output("losetup", "-f", "--show", imagePath)
	if err != nil {
		return fmt.Errorf("failed to create loop device: %w", err)
	}
	loopDevice := strings.TrimSpace(output)
	logInfo("Image mapped to loop device: %s", loopDevice)

	// Map partitions
	if err := sh.Run("kpartx", "-a", loopDevice); err != nil {
		return fmt.Errorf("failed to map partitions: %w", err)
	}
	sh.Run("sleep", "1")

	// Get partition devices
	loopName := filepath.Base(loopDevice)
	bootPartition := fmt.Sprintf("/dev/mapper/%sp1", loopName)
	rootPartition := fmt.Sprintf("/dev/mapper/%sp2", loopName)

	logInfo("Boot partition: %s", bootPartition)
	logInfo("Root partition: %s", rootPartition)

	// Create mount points
	bootMount := filepath.Join(MountBase, "boot")
	rootMount := filepath.Join(MountBase, "root")

	if err := os.MkdirAll(bootMount, 0755); err != nil {
		return fmt.Errorf("failed to create boot mount point: %w", err)
	}
	if err := os.MkdirAll(rootMount, 0755); err != nil {
		return fmt.Errorf("failed to create root mount point: %w", err)
	}

	// Mount partitions
	logInfo("Mounting root partition...")
	if err := sh.Run("mount", rootPartition, rootMount); err != nil {
		return fmt.Errorf("failed to mount root partition: %w", err)
	}

	logInfo("Mounting boot partition...")
	if err := sh.Run("mount", bootPartition, bootMount); err != nil {
		sh.Run("umount", rootMount) // Cleanup
		return fmt.Errorf("failed to mount boot partition: %w", err)
	}

	fmt.Println()
	logSuccess("Image mounted successfully!")
	fmt.Println()
	logInfo("Mount points:")
	logInfo("  Boot partition: %s", bootMount)
	logInfo("  Root partition: %s", rootMount)
	fmt.Println()
	logInfo("To unmount, run: mage image:unmount")
	fmt.Println()
	logInfo("You can now access the filesystem:")
	logInfo("  Boot files: ls -la %s", bootMount)
	logInfo("  Root files: ls -la %s", rootMount)
	logInfo("  GRUB config: cat %s/grub/grub.cfg", bootMount)
	fmt.Println()

	return nil
}

func unmountImage() error {
	logInfo("Unmounting Thor Hammer image...")

	bootMount := filepath.Join(MountBase, "boot")
	rootMount := filepath.Join(MountBase, "root")

	// Unmount boot partition
	if isMounted(bootMount) {
		logInfo("Unmounting boot partition...")
		if err := sh.Run("umount", bootMount); err != nil {
			logWarning("Failed to unmount boot partition: %v", err)
		}
		os.Remove(bootMount)
	}

	// Unmount root partition
	if isMounted(rootMount) {
		logInfo("Unmounting root partition...")
		if err := sh.Run("umount", rootMount); err != nil {
			logWarning("Failed to unmount root partition: %v", err)
		}
		os.Remove(rootMount)
	}

	// Remove mount base directory
	os.Remove(MountBase)

	// Remove partition mappings
	logInfo("Removing partition mappings...")
	loops, _ := filepath.Glob("/dev/loop*")
	for _, loop := range loops {
		sh.Run("kpartx", "-d", loop)
	}

	// Detach all loop devices
	logInfo("Detaching loop devices...")
	sh.Run("losetup", "-D")

	logSuccess("Image unmounted successfully!")
	return nil
}

func isMounted(path string) bool {
	cmd := exec.Command("mountpoint", "-q", path)
	return cmd.Run() == nil
}

// =============================================================================
// Build Operations
// =============================================================================

// Kernel builds the kernel image
func (Build) Kernel() error {
	return buildKernel(true, false)
}

// Dtb builds the device tree blob
func (Build) Dtb() error {
	return buildKernel(false, true)
}

// KernelAll builds both kernel and DTB
func (Build) KernelAll() error {
	return buildKernel(true, true)
}

func buildKernel(buildKernel, buildDTB bool) error {
	logInfo("=== Kernel Build Phase ===")

	// Check if kernel source exists
	if _, err := os.Stat(KernelSource); os.IsNotExist(err) {
		logInfo("📥 Kernel source not found, cloning from GitHub...")
		if !commandExists("git") {
			return fmt.Errorf("git is not installed")
		}

		if err := sh.Run("git", "clone", "--depth=1",
			"https://github.com/AYNTechnologies/linux.git",
			KernelSource); err != nil {
			return fmt.Errorf("failed to clone kernel source: %w", err)
		}
		logSuccess("Kernel source cloned successfully")
	}

	logInfo("🔨 Building AYN Linux Kernel for ARM64...")
	logInfo("Source: %s", KernelSource)
	logInfo("Output: %s", OutputDir)

	// Create output directory
	if err := os.MkdirAll(OutputDir, 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Change to kernel source directory
	originalDir, _ := os.Getwd()
	defer os.Chdir(originalDir)
	os.Chdir(KernelSource)

	env := map[string]string{
		"ARCH":          kernelArch,
		"CROSS_COMPILE": kernelCrossCompile,
	}

	// Configure kernel if needed
	if _, err := os.Stat(".config"); os.IsNotExist(err) {
		logInfo("⚙️  Configuring kernel with defconfig...")
		if err := sh.RunWith(env, "make", "defconfig"); err != nil {
			return fmt.Errorf("kernel configuration failed: %w", err)
		}
	} else {
		logInfo("⚙️  Using existing kernel configuration...")
	}

	// Build kernel image
	if buildKernel {
		logInfo("🏗️  Building kernel (this will take a while)...")
		if err := sh.RunWith(env, "make", fmt.Sprintf("-j%d", runtime.NumCPU()), "Image"); err != nil {
			return fmt.Errorf("kernel build failed: %w", err)
		}

		// Copy kernel to output
		kernelPath := "arch/arm64/boot/Image"
		if _, err := os.Stat(kernelPath); os.IsNotExist(err) {
			return fmt.Errorf("kernel build failed - Image not found")
		}

		logInfo("📦 Copying kernel to assets folder...")
		destPath := filepath.Join(OutputDir, "KERNEL")
		if err := sh.Run("cp", kernelPath, destPath); err != nil {
			return fmt.Errorf("failed to copy kernel: %w", err)
		}
		if err := sh.Run("chmod", "+x", destPath); err != nil {
			return fmt.Errorf("failed to set kernel permissions: %w", err)
		}
	}

	// Build device tree blob
	if buildDTB {
		logInfo("🌳 Building device tree blob for %s...", DTBName)
		if err := sh.RunWith(env, "make", fmt.Sprintf("-j%d", runtime.NumCPU()), "dtbs"); err != nil {
			return fmt.Errorf("device tree build failed: %w", err)
		}

		// Copy DTB to output
		dtbPath := fmt.Sprintf("arch/arm64/boot/dts/qcom/%s.dtb", DTBName)
		if _, err := os.Stat(dtbPath); os.IsNotExist(err) {
			return fmt.Errorf("device tree build failed - DTB not found")
		}

		logInfo("📦 Copying DTB to assets folder...")
		destPath := filepath.Join(OutputDir, fmt.Sprintf("%s.dtb", DTBName))
		if err := sh.Run("cp", dtbPath, destPath); err != nil {
			return fmt.Errorf("failed to copy DTB: %w", err)
		}
	}

	// Get kernel version
	output, _ := sh.OutputWith(env, "make", "kernelrelease")
	kernelVersion := strings.TrimSpace(output)

	fmt.Println()
	logSuccess("Kernel build completed successfully!")
	logInfo("📄 Kernel version: %s", kernelVersion)
	if buildKernel {
		logInfo("📍 Kernel location: %s/KERNEL", OutputDir)
	}
	if buildDTB {
		logInfo("🌳 DTB location: %s/%s.dtb", OutputDir, DTBName)
	}
	fmt.Println()

	return nil
}

// =============================================================================
// Dev Operations
// =============================================================================

// Chroot enters an interactive chroot in the rootfs
func (Dev) Chroot() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	rootfsDir := getEnvOrDefault("ROOTFS", DefaultRootfsDir)
	return chrootInto(rootfsDir, []string{"/bin/bash"})
}

func chrootInto(rootfsDir string, command []string) error {
	logInfo("Thor Hammer - Chroot Helper")
	logInfo("Target: %s", rootfsDir)
	fmt.Println()

	// Verify directory exists
	if _, err := os.Stat(rootfsDir); os.IsNotExist(err) {
		return fmt.Errorf("rootfs directory not found: %s", rootfsDir)
	}

	// Check for arch-chroot
	if !commandExists("arch-chroot") {
		return fmt.Errorf("arch-chroot not found. Install arch-install-scripts package")
	}

	// Make it a mountpoint if needed
	needUnbind := false
	if !isMounted(rootfsDir) {
		logInfo("Making directory a mountpoint...")
		if err := sh.Run("mount", "--bind", rootfsDir, rootfsDir); err != nil {
			return fmt.Errorf("failed to bind mount: %w", err)
		}
		needUnbind = true
	}

	// Cleanup function
	defer func() {
		if needUnbind {
			logInfo("Cleaning up...")
			sh.Run("umount", rootfsDir)
		}
	}()

	// Set up ARM64 support
	logInfo("Setting up ARM64 emulation...")

	// Copy qemu-aarch64-static
	if !commandExists("qemu-aarch64-static") {
		return fmt.Errorf("qemu-aarch64-static not found. Install qemu-user-static")
	}

	qemuDest := filepath.Join(rootfsDir, "usr/bin/qemu-aarch64-static")
	if err := sh.Run("cp", "/usr/bin/qemu-aarch64-static", qemuDest); err != nil {
		return fmt.Errorf("failed to copy qemu-aarch64-static: %w", err)
	}
	defer os.Remove(qemuDest)

	// Register binfmt if needed
	binfmtPath := "/proc/sys/fs/binfmt_misc/qemu-aarch64"
	if _, err := os.Stat(binfmtPath); os.IsNotExist(err) {
		logInfo("Registering ARM64 binfmt handler...")
		binfmtString := ":qemu-aarch64:M::\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xb7\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:/usr/bin/qemu-aarch64-static:F"
		sh.Run("bash", "-c", fmt.Sprintf("echo '%s' > /proc/sys/fs/binfmt_misc/register", binfmtString))
	}

	fmt.Println()
	logSuccess("Chroot environment ready!")
	fmt.Println()

	if len(command) == 1 && command[0] == "/bin/bash" {
		logInfo("Entering interactive chroot shell...")
		logInfo("Type 'exit' to leave the chroot.")
	} else {
		logInfo("Running command in chroot: %s", strings.Join(command, " "))
	}
	fmt.Println()

	// Run arch-chroot
	args := append([]string{rootfsDir}, command...)
	cmd := exec.Command("arch-chroot", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// =============================================================================
// Clean Operations
// =============================================================================

// Clean removes build artifacts
func Clean() error {
	logInfo("Cleaning build artifacts...")

	dirs := []string{
		"build/rootfs",
		"build",
	}

	for _, dir := range dirs {
		if _, err := os.Stat(dir); err == nil {
			logInfo("Removing %s...", dir)
			if err := os.RemoveAll(dir); err != nil {
				logWarning("Failed to remove %s: %v", dir, err)
			}
		}
	}

	logSuccess("Clean complete!")
	return nil
}

// CleanAll removes all build artifacts including kernel source
func CleanAll() error {
	if err := Clean(); err != nil {
		return err
	}

	if _, err := os.Stat(KernelSource); err == nil {
		logInfo("Removing kernel source...")
		if err := os.RemoveAll(KernelSource); err != nil {
			logWarning("Failed to remove kernel source: %v", err)
		}
	}

	logSuccess("Deep clean complete!")
	return nil
}

// =============================================================================
// Utility Functions
// =============================================================================

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
