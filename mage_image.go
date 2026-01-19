//go:build mage
// +build mage

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/magefile/mage/sh"
)

// =============================================================================
// Image Operations (Mount/Unmount)
// =============================================================================

// Mount mounts the disk image for inspection/modification
func Mount() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	if _, err := os.Stat(ImageFile); os.IsNotExist(err) {
		return fmt.Errorf("image not found: %s", ImageFile)
	}

	log("Mounting image...")
	loopDev, err := sh.Output("losetup", "-f", "--show", ImageFile)
	if err != nil {
		return err
	}
	loopDev = strings.TrimSpace(loopDev)

	sh.Run("kpartx", "-a", loopDev)
	sh.Run("sleep", "1")

	loopName := filepath.Base(loopDev)
	part1 := fmt.Sprintf("/dev/mapper/%sp1", loopName)
	part2 := fmt.Sprintf("/dev/mapper/%sp2", loopName)

	bootMount := filepath.Join(MountBase, "boot")
	rootMount := filepath.Join(MountBase, "root")
	os.MkdirAll(bootMount, 0755)
	os.MkdirAll(rootMount, 0755)

	sh.Run("mount", part2, rootMount)
	sh.Run("mount", part1, bootMount)

	success("Image mounted!")
	fmt.Printf("\n📁 Mount points:\n")
	fmt.Printf("Boot: %s\n", bootMount)
	fmt.Printf("Root: %s\n", rootMount)
	fmt.Printf("\n💡 Unmount: mage unmount\n\n")
	return nil
}

// Unmount unmounts the disk image
func Unmount() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	log("Unmounting image...")
	sh.Run("umount", filepath.Join(MountBase, "boot"))
	sh.Run("umount", filepath.Join(MountBase, "root"))

	loops, _ := filepath.Glob("/dev/loop*")
	for _, loop := range loops {
		sh.Run("kpartx", "-d", loop)
	}
	sh.Run("losetup", "-D")

	os.RemoveAll(MountBase)
	success("Image unmounted")
	return nil
}
