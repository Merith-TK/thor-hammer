# DevContainer Updates for Mage Support

## Changes Made

### 1. Updated `.devcontainer/devcontainer.json`
Added Go bin directory to the container's PATH environment variable:

```jsonc
"containerEnv": {
  // ... other vars ...
  "PATH": "${containerEnv:HOME}/go/bin:${containerEnv:PATH}"
},
```

**Effect**: Makes `mage` command available globally without needing full path.

### 2. Updated `.devcontainer/post-create.sh`
Added automatic Mage installation and setup:

#### Path Configuration
```bash
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
```

#### New Mage Aliases
```bash
alias mage-list='mage -l'
alias mage-vm='mage vm:start'
alias mage-build='mage build:kernelAll'
```

#### Automatic Installation
```bash
# Install Mage build tool
if command -v go >/dev/null 2>&1; then
    go install github.com/magefile/mage@latest
fi

# Initialize Go modules
if [ -f "/workspaces/.thor-hammer/go.mod" ]; then
    cd /workspaces/.thor-hammer
    go mod download
fi
```

#### Enhanced thor-status
Now shows Mage commands in the status output.

## Benefits

✅ **No manual setup** - Mage is automatically installed on container creation
✅ **Always in PATH** - Can run `mage` from any directory
✅ **Persistent across restarts** - Configuration is baked into container
✅ **Convenient aliases** - Quick shortcuts for common Mage tasks
✅ **Documentation** - thor-status shows Mage commands

## Testing

### Verify Mage is Available
```bash
which mage
# Output: /home/user/go/bin/mage

mage -version
# Output: Mage Build Tool ...
```

### List Available Targets
```bash
mage -l
# Shows all 11 available targets
```

### Try a Simple Command
```bash
mage vm:start  # (instead of ~/go/bin/mage vm:start)
```

## Current Session

For the current terminal session (already applied):
```bash
export PATH="$HOME/go/bin:$PATH"
source ~/.bashrc
```

## Next Container Launch

On next devcontainer rebuild/creation:
1. Container will have Go bin in PATH from the start
2. Mage will be auto-installed during post-create
3. Go modules will be auto-downloaded
4. All aliases will be available immediately

## Rebuild Container

To apply changes to an existing container:

**Method 1: Rebuild Container** (Recommended)
1. Open Command Palette (Ctrl+Shift+P)
2. Select: "Dev Containers: Rebuild Container"
3. Wait for rebuild to complete

**Method 2: Manual Reload**
```bash
source ~/.bashrc
# Mage should now work directly
```

## Verification

After container rebuild, you should see in `thor-status`:
```
🔧 Mage build tool:
  mage -l            - List all Mage targets
  mage vm:start      - Boot VM (console mode)
  mage vm:gui        - Boot VM (GUI mode)
  mage build:kernelAll - Build kernel and DTB
  mage image:mount   - Mount image for inspection
```

## Quick Reference

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `~/go/bin/mage -l` | `mage -l` | Now in PATH |
| `~/go/bin/mage vm:start` | `mage vm:start` | Direct access |
| N/A | `mage-list` | Convenient alias |
| N/A | `mage-vm` | Quick VM start |
| N/A | `mage-build` | Quick build |

## Files Modified

- ✅ `.devcontainer/devcontainer.json` - Added PATH configuration
- ✅ `.devcontainer/post-create.sh` - Added Mage installation and aliases
- ✅ Current session - Applied PATH update immediately

## Troubleshooting

### Mage not found after rebuild
```bash
# Check if Go is installed
go version

# Manually install Mage
go install github.com/magefile/mage@latest

# Verify PATH
echo $PATH | grep go/bin
```

### Container doesn't have Go bin in PATH
```bash
# Check container environment
env | grep PATH

# Rebuild container to apply devcontainer.json changes
```
