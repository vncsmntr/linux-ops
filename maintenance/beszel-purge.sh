#!/usr/bin/env bash

# ==============================================================================
# NAME: Beszel Agent System Purge
# DESCRIPTION: Universal removal of Beszel Agent (Ubuntu, Debian, RHEL, AlmaLinux)
# REPOSITORY: vncsmntr/linux-ops
# ==============================================================================

set -euo pipefail

# --- Configuration ---
SERVICE_NAME="beszel-agent"
USER_NAME="beszel"
BIN_PATHS=(
    "/usr/local/bin/beszel-agent"
    "/usr/bin/beszel-agent"
    "$HOME/beszel-agent"
)
CONFIG_PATHS=(
    "/etc/beszel"
    "$HOME/.config/beszel"
    "$HOME/.beszel"
    "/var/lib/beszel"
    "/var/log/beszel"
)

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
echo "       BESZEL AGENT SYSTEM PURGE TOOL"
echo "==================================================="

# 1. Docker Check
if command -v docker >/dev/null 2>&1; then
    if docker ps -a --format '{{.Names}}' | grep -q "beszel-agent"; then
        warn "Docker container 'beszel-agent' detected. Remember to: docker rm -f beszel-agent"
    fi
fi

# 2. Systemd Service Cleanup
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        info "Stopping service..."
        systemctl stop "$SERVICE_NAME" || true
    fi

    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        info "Removing systemd units..."
        systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        rm -f "/usr/lib/systemd/system/$SERVICE_NAME.service"
        systemctl daemon-reload
        systemctl reset-failed
    fi
fi

# 3. Process Kill
if pgrep -f "beszel-agent" > /dev/null; then
    info "Terminating active processes..."
    pkill -9 -f "beszel-agent"
fi

# 4. Binary Wipe
for path in "${BIN_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        rm -f "$path"
        info "Removed binary: $path"
    fi
done

# 5. Data/Config Wipe
for path in "${CONFIG_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        rm -rf "$path"
        info "Purged directory: $path"
    fi
done

# 6. User/Group Cleanup
if id "$USER_NAME" >/dev/null 2>&1; then
    info "Removing user/group: $USER_NAME"
    userdel -r "$USER_NAME" 2>/dev/null || groupdel "$USER_NAME" 2>/dev/null || true
fi

echo "==================================================="
success "PURGE COMPLETED SUCCESSFULLY!"
info "The system is now clean of Beszel Agent traces."