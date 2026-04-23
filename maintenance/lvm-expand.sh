#!/usr/bin/env bash

# ==============================================================================
# NAME: LVM Storage Expander
# DESCRIPTION: Automatically extends a Logical Volume to use 100% of free space.
# REPOSITORY: vncsmntr/linux-ops
# ==============================================================================

set -euo pipefail

# --- UI Functions ---
info() { echo -e "\e[34mℹ️  $1\e[0m"; }
success() { echo -e "\e[32m✅ $1\e[0m"; }
warn() { echo -e "\e[33m⚠️  $1\e[0m"; }
error() { echo -e "\e[31m🚨 $1\e[0m"; exit 1; }

# Root Check
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)."
fi

echo "==================================================="
echo "           LVM STORAGE EXPANDER"
echo "==================================================="

# Configuration (Defaults for Ubuntu/Debian common setups)
VG_NAME="ubuntu-vg"
LV_NAME="ubuntu-lv"
LV_PATH="/dev/$VG_NAME/$LV_NAME"

# 1. Verification
if [ ! -L "$LV_PATH" ]; then
    error "Logical Volume $LV_PATH not found. Run 'lvs' to check your Volume Group name."
fi

# 2. Extension
info "Attempting to extend $LV_PATH to use all free space..."
if lvextend -l +100%FREE "$LV_PATH" -y; then
    
    # 3. Filesystem Resize
    FSTYPE=$(lsblk -no FSTYPE "$LV_PATH")
    info "Detected Filesystem: $FSTYPE"

    case "$FSTYPE" in
        ext4)
            resize2fs "$LV_PATH"
            success "EXT4 Filesystem resized successfully."
            ;;
        xfs)
            xfs_growfs "$LV_PATH"
            success "XFS Filesystem resized successfully."
            ;;
        *)
            warn "Filesystem type $FSTYPE not supported for automated resize."
            ;;
    esac
else
    warn "No free space available in Volume Group or extension failed."
fi

echo "==================================================="
success "DISK MANAGEMENT TASK COMPLETED!"