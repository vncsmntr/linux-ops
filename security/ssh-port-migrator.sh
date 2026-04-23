#!/usr/bin/env bash

# ==============================================================================
# NAME: SSH Port Migrator
# DESCRIPTION: Changes default SSH port, handles SELinux, FirewallD/UFW, and config.
# REPOSITORY: vncsmntr/linux-ops
# ==============================================================================

# Set -e: Exit on error, -u: Exit on unset variables
set -euo pipefail

# --- UI Functions ---
info() { echo -e "\e[34mℹ️  $1\e[0m"; }
success() { echo -e "\e[32m✅ $1\e[0m"; }
warn() { echo -e "\e[33m⚠️  $1\e[0m"; }
error() { echo -e "\e[31m🚨 $1\e[0m"; exit 1; }

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)."
fi

echo "==================================================="
echo "       SSH PORT MIGRATION TOOL"
echo "==================================================="

# 1. Input and Validation
read -p "Enter the new SSH port (e.g., 2222): " NEW_PORT

if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -gt 65535 ]; then
    error "Invalid port. Please enter a number between 1 and 65535."
fi

# Check if port is already listening
if ss -tuln | grep -q ":$NEW_PORT "; then
    error "Port $NEW_PORT is already in use by another service."
fi

info "🚀 Starting migration to port $NEW_PORT..."

# 2. Backup configuration
cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak_$(date +%F_%T)"
info "Backup created at /etc/ssh/sshd_config.bak"

# 3. Update sshd_config
# Removes existing Port entries and ensures the new one is set
sed -i "/^Port /d" /etc/ssh/sshd_config
sed -i "/^#Port /d" /etc/ssh/sshd_config
echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
success "Configuration updated."

# 4. SELinux Configuration (For AlmaLinux, CentOS, Fedora, RHEL)
if command -v sestatus >/dev/null 2>&1 && sestatus | grep -q "enabled"; then
    info "SELinux detected. Configuring port $NEW_PORT..."
    if ! command -v semanage >/dev/null 2>&1; then
        warn "semanage not found. Attempting to install required tools..."
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y policycoreutils-python-utils
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y policycoreutils
        fi
    fi
    semanage port -a -t ssh_port_t -p tcp "$NEW_PORT" || semanage port -m -t ssh_port_t -p tcp "$NEW_PORT"
    success "SELinux updated."
fi

# 5. Firewall Configuration
# Handle Firewalld (RHEL-based)
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    info "Configuring Firewalld..."
    firewall-cmd --permanent --add-port="$NEW_PORT"/tcp
    firewall-cmd --permanent --remove-service=ssh >/dev/null 2>&1 || true
    firewall-cmd --reload
    success "Firewalld updated."
# Handle UFW (Debian/Ubuntu-based)
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    info "Configuring UFW..."
    ufw allow "$NEW_PORT"/tcp
    success "UFW updated."
else
    warn "No active firewall (Firewalld/UFW) detected. Please ensure port $NEW_PORT is open."
fi

# 6. Restart SSH Service
info "🔄 Restarting SSH service..."
if systemctl restart sshd; then
    success "SSH service restarted successfully."
else
    error "Failed to restart SSH. Checking backup..."
fi

echo "==================================================="
success "MIGRATION COMPLETED!"
info "Current SSH Port: $NEW_PORT"
warn "IMPORTANT: Do not disconnect! Test in a new terminal:"
echo -e "\e[33m   ssh $(whoami)@$(hostname -I | awk '{print $1}') -p $NEW_PORT\e[0m"
echo "==================================================="