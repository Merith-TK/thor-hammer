#!/bin/bash
# Quick comparison between bash and mage implementations

echo "Thor Hammer - Bash vs Mage Comparison"
echo "======================================"
echo ""

echo "📊 Script Migration Status:"
echo ""
printf "%-30s %-30s %-20s\n" "Original Bash Script" "Mage Target" "Status"
printf "%-30s %-30s %-20s\n" "--------------------" "-----------" "------"
printf "%-30s %-30s %-20s\n" "thor-vm.sh" "mage vm:start/gui/custom" "✅ Replaced"
printf "%-30s %-30s %-20s\n" "mount-image.sh" "mage image:mount" "✅ Replaced"
printf "%-30s %-30s %-20s\n" "unmount-image.sh" "mage image:unmount" "✅ Replaced"
printf "%-30s %-30s %-20s\n" "thor-chroot.sh" "mage dev:chroot" "✅ Replaced"
printf "%-30s %-30s %-20s\n" "thor-build.sh (kernel)" "mage build:kernel/dtb" "✅ Replaced"
printf "%-30s %-30s %-20s\n" "thor-build.sh (image)" "Coming soon" "🚧 In Progress"
printf "%-30s %-30s %-20s\n" "setup-archlinux.sh" "N/A" "⏭️ Keep as Bash"
echo ""

echo "✨ Mage Benefits:"
echo "  • Type-safe Go code vs error-prone bash"
echo "  • Better IDE support (autocomplete, refactoring)"
echo "  • Easier to test and maintain"
echo "  • Cross-platform (works on Windows/Mac/Linux)"
echo "  • Faster execution for file operations"
echo "  • Clear dependency management"
echo "  • Built-in parallelization support"
echo ""

echo "📦 Code Comparison:"
bash_lines=$(wc -l scripts/legacy-bash/*.sh 2>/dev/null | tail -1 | awk '{print $1}')
if [ -z "$bash_lines" ]; then bash_lines="~370"; fi
mage_lines=$(wc -l magefile.go 2>/dev/null | awk '{print $1}')
if [ -z "$mage_lines" ]; then mage_lines="~594"; fi
echo "  Replaced bash scripts: $bash_lines lines (4 files)"
echo "  Mage implementation:   $mage_lines lines (1 file)"
echo "  Reduction:            More maintainable + type-safe"
echo ""

echo "📂 File Organization:"
echo "  Active scripts:  scripts/"
echo "  Legacy scripts:  scripts/legacy-bash/ (reference only)"
echo "  Mage build:      magefile.go"
echo ""

echo "🚀 To get started with Mage:"
echo "  1. Install: go install github.com/magefile/mage@latest"
echo "  2. List targets: mage -l"
echo "  3. Run target: mage vm:start"
echo "  4. Read full docs: cat MAGE_USAGE.md"
echo ""
