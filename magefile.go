//go:build mage
// +build mage

package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/magefile/mage/sh"
)

// =============================================================================
// Configuration Constants
// =============================================================================

const (
	// Paths
	WorkDir   = "build"
	RootfsDir = "build/rootfs"
	ImageFile = "build/thor-hammer.img"
	AssetsDir = "assets"

	// Build configuration
	ImageSize = "4G"

	// VM defaults
	DefaultMemory = "2048"
	DefaultCPUs   = "2"
	MountBase     = "/tmp/thor-mount"

	// Default rootfs URL
	DefaultRootfsURL = "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
)

var (
	// Allow override via environment
	rootfsTarball = getEnv("ROOTFS_TAR", "")
	rootfsURL     = getEnv("ROOTFS_URL", DefaultRootfsURL)
	setupScript   = getEnv("SETUP_SCRIPT", "scripts/setup-archlinux.sh")
)

// =============================================================================
// Helper Functions
// =============================================================================

func ensureRoot() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("requires root: run with sudo")
	}
	return nil
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func log(format string, args ...interface{}) {
	fmt.Printf("• "+format+"\n", args...)
}

func success(format string, args ...interface{}) {
	fmt.Printf("✅ "+format+"\n", args...)
}

func downloadFile(url, dest string) error {
	log("Downloading from %s...", url)
	os.MkdirAll(filepath.Dir(dest), 0755)

	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func cleanupLoops(imagePath string) {
	output, _ := sh.Output("losetup", "-j", imagePath)
	if output != "" {
		parts := strings.Split(strings.TrimSpace(output), ":")
		if len(parts) > 0 {
			loopDev := strings.TrimSpace(parts[0])
			sh.Run("kpartx", "-d", loopDev)
			sh.Run("losetup", "-d", loopDev)
		}
	}
}

func cleanupLoop(loopDev string) {
	sh.Run("kpartx", "-d", loopDev)
	sh.Run("losetup", "-d", loopDev)
}

func findUEFI() string {
	paths := []string{
		"/usr/share/edk2/aarch64/QEMU_EFI.fd",
		"/usr/share/AAVMF/AAVMF_CODE.fd",
		"/usr/share/qemu-efi-aarch64/QEMU_EFI.fd",
	}
	for _, p := range paths {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}
