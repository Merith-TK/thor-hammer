//go:build mage
// +build mage

package main

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/magefile/mage/mg"
	"github.com/magefile/mage/sh"
)

// =============================================================================
// Main Build Target
// =============================================================================

// Build creates a complete bootable Thor Hammer image from scratch
func Build() error {
	log("🔨 Building complete Thor Hammer image...")
	mg.Deps(BuildRootfs)
	return BuildImage()
}

// =============================================================================
// Rootfs Building
// =============================================================================

// BuildRootfs downloads, extracts, and configures the rootfs
func BuildRootfs() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	log("📦 Building rootfs...")

	// Download if needed
	tarPath := rootfsTarball
	if tarPath == "" {
		tarPath = filepath.Join(WorkDir, "rootfs.tar.gz")
		if _, err := os.Stat(tarPath); os.IsNotExist(err) {
			if err := downloadFile(rootfsURL, tarPath); err != nil {
				return err
			}
		} else {
			log("Using cached rootfs: %s", tarPath)
		}
	}

	// Check if rootfs already exists and has content
	rootfsExists := false
	if info, err := os.Stat(RootfsDir); err == nil && info.IsDir() {
		entries, _ := os.ReadDir(RootfsDir)
		if len(entries) > 0 {
			log("Using existing rootfs: %s", RootfsDir)
			log("Run 'mage buildClean' to force fresh extraction")
			rootfsExists = true
		}
	}

	// Extract if needed
	if !rootfsExists {
		// Create rootfs dir
		os.MkdirAll(RootfsDir, 0755)

		// Extract
		log("Extracting rootfs...")
		if err := extractTarGz(tarPath, RootfsDir); err != nil {
			return err
		}
	}

	// Generate fstab
	log("Generating fstab...")
	fstab := `# /etc/fstab: static file system information
LABEL=THORROOT        /              ext4    defaults,noatime       0      1
LABEL=THORBOOT        /boot          vfat    defaults,noatime       0      2
`
	os.WriteFile(filepath.Join(RootfsDir, "etc/fstab"), []byte(fstab), 0644)

	// Run setup script if it exists
	if _, err := os.Stat(setupScript); err == nil {
		log("Running setup script in chroot...")
		if err := runInChroot(RootfsDir, setupScript); err != nil {
			return err
		}
	}

	success("Rootfs ready: %s", RootfsDir)
	return nil
}

// =============================================================================
// Image Building
// =============================================================================

// BuildImage creates the bootable disk image
func BuildImage() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	log("💿 Building disk image...")

	// Check prerequisites
	if _, err := os.Stat(RootfsDir); os.IsNotExist(err) {
		return fmt.Errorf("rootfs not found: %s\nRun: mage buildRootfs", RootfsDir)
	}

	// Clean up any old loops
	cleanupLoops(ImageFile)

	// Create blank image
	log("Creating %s image file...", ImageSize)
	if err := sh.Run("truncate", "-s", ImageSize, ImageFile); err != nil {
		return err
	}

	// Partition
	log("Partitioning image...")
	if err := sh.Run("parted", ImageFile, "--script",
		"mklabel", "gpt",
		"mkpart", "primary", "fat32", "1MiB", "513MiB",
		"set", "1", "esp", "on",
		"mkpart", "primary", "ext4", "513MiB", "100%",
		"name", "1", "THORBOOT",
		"name", "2", "THORROOT"); err != nil {
		return err
	}

	// Setup loop device
	log("Setting up loop device...")
	loopDev, err := sh.Output("losetup", "--find", "--show", "--partscan", ImageFile)
	if err != nil {
		return err
	}
	loopDev = strings.TrimSpace(loopDev)
	defer cleanupLoop(loopDev)

	sh.Run("kpartx", "-av", loopDev)
	sh.Run("sleep", "2")

	loopName := filepath.Base(loopDev)
	part1 := fmt.Sprintf("/dev/mapper/%sp1", loopName)
	part2 := fmt.Sprintf("/dev/mapper/%sp2", loopName)

	// Format partitions
	log("Formatting partitions...")
	sh.Run("mkfs.vfat", "-F", "32", "-n", "THORBOOT", part1)
	sh.Run("mkfs.ext4", "-L", "THORROOT", part2)

	// Mount
	mountDir := filepath.Join(WorkDir, "mnt")
	os.MkdirAll(mountDir, 0755)
	sh.Run("mount", part2, mountDir)
	defer sh.Run("umount", mountDir)

	bootDir := filepath.Join(mountDir, "boot")
	os.MkdirAll(bootDir, 0755)
	sh.Run("mount", part1, bootDir)
	defer sh.Run("umount", bootDir)

	// Copy rootfs (excluding boot content which comes from rootfs packages)
	log("Copying rootfs to image...")
	rsyncArgs := []string{"-aAXv", filepath.Join(RootfsDir, "/") + ".", mountDir + "/",
		"--exclude=/dev/*", "--exclude=/proc/*",
		"--exclude=/sys/*", "--exclude=/tmp/*", "--exclude=/run/*",
		"--exclude=/mnt/*", "--exclude=/media/*", "--exclude=/lost+found"}
	if err := sh.Run("rsync", rsyncArgs...); err != nil {
		return err
	}

	// Install custom GRUB config if available
	customGrub := filepath.Join(AssetsDir, "custom-grub.cfg")
	if _, err := os.Stat(customGrub); err == nil {
		grubDir := filepath.Join(bootDir, "grub")
		if _, err := os.Stat(grubDir); err == nil {
			log("Installing GRUB configuration...")
			sh.Run("cp", customGrub, filepath.Join(grubDir, "grub.cfg"))
		}
	}

	// Cleanup
	log("Cleaning up...")
	sh.Run("umount", bootDir)
	sh.Run("umount", mountDir)
	sh.Run("kpartx", "-d", loopDev)
	sh.Run("losetup", "-d", loopDev)

	success("Image built: %s", ImageFile)
	fileInfo, _ := os.Stat(ImageFile)
	log("Image size: %.1f GB", float64(fileInfo.Size())/1024/1024/1024)
	return nil
}

// =============================================================================
// Cleanup
// =============================================================================

// Clean removes build artifacts (image and mounts, preserves rootfs)
func Clean() error {
	log("🧹 Cleaning build artifacts...")
	sh.Run("umount", filepath.Join(WorkDir, "mnt", "boot"))
	sh.Run("umount", filepath.Join(WorkDir, "mnt"))
	cleanupLoops(ImageFile)
	os.Remove(ImageFile)
	os.RemoveAll(filepath.Join(WorkDir, "mnt"))
	success("Clean complete")
	return nil
}

// BuildClean removes rootfs and forces fresh extraction on next build
func BuildClean() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	log("🧹 Cleaning rootfs for fresh extraction...")
	os.RemoveAll(RootfsDir)
	success("Rootfs removed - next build will extract fresh")
	return nil
}

// =============================================================================
// Helper Functions
// =============================================================================

func extractTarGz(tarPath, destDir string) error {
	file, err := os.Open(tarPath)
	if err != nil {
		return err
	}
	defer file.Close()

	gz, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer gz.Close()

	tr := tar.NewReader(gz)

	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		target := filepath.Join(destDir, header.Name)

		switch header.Typeflag {
		case tar.TypeDir:
			os.MkdirAll(target, os.FileMode(header.Mode))
		case tar.TypeReg:
			os.MkdirAll(filepath.Dir(target), 0755)
			outFile, err := os.OpenFile(target, os.O_CREATE|os.O_RDWR, os.FileMode(header.Mode))
			if err != nil {
				return err
			}
			io.Copy(outFile, tr)
			outFile.Close()
		case tar.TypeSymlink:
			os.Symlink(header.Linkname, target)
		}
	}

	return nil
}

func runInChroot(rootfsDir, scriptOrCmd string) error {
	// Setup ARM64 emulation
	if !commandExists("qemu-aarch64-static") {
		return fmt.Errorf("qemu-aarch64-static not found")
	}

	qemuDest := filepath.Join(rootfsDir, "usr/bin/qemu-aarch64-static")
	sh.Run("cp", "/usr/bin/qemu-aarch64-static", qemuDest)
	defer os.Remove(qemuDest)

	// Bind mount if needed
	needUnbind := false
	cmd := exec.Command("mountpoint", "-q", rootfsDir)
	if cmd.Run() != nil {
		sh.Run("mount", "--bind", rootfsDir, rootfsDir)
		needUnbind = true
	}
	defer func() {
		if needUnbind {
			sh.Run("umount", rootfsDir)
		}
	}()

	// Determine if scriptOrCmd is a local script file to copy, or a command in the chroot
	var chrootCmd []string

	// If it's a relative path or in scripts/, it's a file to copy
	if !strings.HasPrefix(scriptOrCmd, "/") || strings.Contains(scriptOrCmd, "scripts/") {
		if info, err := os.Stat(scriptOrCmd); err == nil && !info.IsDir() {
			// It's a script file - copy and execute
			scriptName := filepath.Base(scriptOrCmd)
			destScript := filepath.Join(rootfsDir, scriptName)
			sh.Run("cp", scriptOrCmd, destScript)
			sh.Run("chmod", "+x", destScript)
			defer os.Remove(destScript)
			chrootCmd = []string{rootfsDir, "/bin/bash", "/" + scriptName}
		} else {
			// File doesn't exist
			return fmt.Errorf("script not found: %s", scriptOrCmd)
		}
	} else {
		// It's an absolute path (like /bin/bash) - execute directly in chroot
		// For interactive shells, add -i flag
		if scriptOrCmd == "/bin/bash" || scriptOrCmd == "/bin/sh" {
			chrootCmd = []string{rootfsDir, scriptOrCmd, "-i"}
		} else {
			chrootCmd = []string{rootfsDir, scriptOrCmd}
		}
	}

	cmd = exec.Command("arch-chroot", chrootCmd...)
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, "PS1=[\\u@\\h \\W]\\$ ")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
