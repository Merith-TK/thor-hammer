//go:build mage
// +build mage

package main

import (
	"fmt"
	"os"
	"os/exec"
)

// =============================================================================
// VM Operations
// =============================================================================

// VM boots the Thor Hammer image in QEMU (console mode)
func VM() error {
	return startVM(false)
}

// VMGui boots the Thor Hammer image in QEMU (GUI mode)
func VMGui() error {
	return startVM(true)
}

func startVM(gui bool) error {
	if _, err := os.Stat(ImageFile); os.IsNotExist(err) {
		return fmt.Errorf("image not found: %s\nRun: mage build", ImageFile)
	}

	biosPath := findUEFI()
	if biosPath == "" {
		return fmt.Errorf("UEFI firmware not found, install: qemu-efi-aarch64")
	}

	memory := getEnv("MEMORY", DefaultMemory)
	cpus := getEnv("CPUS", DefaultCPUs)

	args := []string{
		"-M", "virt", "-cpu", "cortex-a72",
		"-m", memory,
		"-smp", cpus,
		"-drive", fmt.Sprintf("file=%s,if=virtio,format=raw", ImageFile),
		"-bios", biosPath,
		"-netdev", "user,id=net0",
		"-device", "virtio-net-pci,netdev=net0",
	}

	if gui {
		args = append(args, "-device", "virtio-gpu-pci",
			"-device", "virtio-keyboard-pci", "-device", "virtio-mouse-pci",
			"-display", "sdl,gl=off", "-vga", "none")
	} else {
		args = append(args, "-nographic")
	}

	fmt.Printf("\n🚀 Starting Thor Hammer VM\n")
	fmt.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	fmt.Printf("Image:  %s\n", ImageFile)
	fmt.Printf("Memory: %s MB\n", memory)
	fmt.Printf("CPUs:   %s\n", cpus)
	fmt.Printf("Mode:   %s\n", map[bool]string{true: "GUI", false: "Console"}[gui])
	fmt.Printf("\nLogin:  thor / thor-hammer\n")
	if !gui {
		fmt.Printf("Exit:   Ctrl+A then X\n")
	}
	fmt.Println()

	cmd := exec.Command("qemu-system-aarch64", args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}
