//go:build mage
// +build mage

package main

import (
	"fmt"
	"os"
)

// =============================================================================
// Development Operations
// =============================================================================

// Chroot enters an interactive chroot in the rootfs
func Chroot() error {
	if err := ensureRoot(); err != nil {
		return err
	}

	if _, err := os.Stat(RootfsDir); os.IsNotExist(err) {
		return fmt.Errorf("rootfs not found: %s\nRun: mage buildRootfs", RootfsDir)
	}

	log("Entering chroot environment...")
	fmt.Printf("Target: %s\n", RootfsDir)
	fmt.Printf("Type 'exit' to leave the chroot\n\n")

	return runInChroot(RootfsDir, "/bin/bash")
}
