#!/usr/bin/env bash

# ==============================================================================
# NAME: SFTP Chroot Provisioner
# DESCRIPTION: Creates a restricted SFTP-only user with Chroot jail.
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
echo "         SFTP CHROOT USER PROVISIONER"
echo "==================================================="

# 1. Input
read -p "Enter the new SFTP username: " SFTP_USER
if id "$SFTP_USER" >/dev/null 2>&1; then
    error "User '$SFTP_USER' already exists."
fi

# 2. Group and User Creation
groupadd -r sftp_users 2>/dev/null || true
useradd -m -g sftp_users -s /bin/false "$SFTP_USER"
info "Set a password for $SFTP_USER:"
passwd "$SFTP_USER"

# 3. Chroot Permissions (Root must own Home)
chown root:root "/home/$SFTP_USER"
chmod 755 "/home/$SFTP_USER"

# 4. Upload Directory
mkdir -p "/home/$SFTP_USER/uploads"
chown "$SFTP_USER:sftp_users" "/home/$SFTP_USER/uploads"
chmod 700 "/home/$SFTP_USER/uploads"
success "User and directory structure created."

# 5. SSHD Configuration
SSHD_CONF="/etc/ssh/sshd_config"
MATCH_RULE="Match Group sftp_users"

if ! grep -q "$MATCH_RULE" "$SSHD_CONF"; then
    cp "$SSHD_CONF" "$SSHD_CONF.bak_$(date +%F)"
    cat >> "$SSHD_CONF" <<EOF

# SFTP Restricted Group Rules
Match Group sftp_users
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PasswordAuthentication yes
EOF
    info "Restarting SSH service..."
    systemctl restart ssh || systemctl restart sshd
    success "SSHD rules applied."
else
    info "SSHD rules already present. Skipping config update."
fi

echo "==================================================="
success "SFTP PROVISIONING COMPLETED!"
info "User: $SFTP_USER | Jail: /home/$SFTP_USER/uploads"
echo "==================================================="