#!/bin/bash

# Output colors
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}===> Starting Security Updates Configuration (AlmaLinux 10)${NC}"

# 1. Package Installation
echo "Installing dnf-automatic..."
sudo dnf install -y dnf-automatic

# 2. Backup Original Configuration
if [ -f /etc/dnf/automatic.conf ]; then
    sudo cp /etc/dnf/automatic.conf /etc/dnf/automatic.conf.bak
    echo "Backup created at /etc/dnf/automatic.conf.bak"
fi

# 3. Applying security parameters via sed
echo "Configuring security parameters..."
# Set upgrade type to security only
sudo sed -i 's/^upgrade_type =.*/upgrade_type = security/' /etc/dnf/automatic.conf
# Enable automatic download
sudo sed -i 's/^download_updates =.*/download_updates = yes/' /etc/dnf/automatic.conf
# Enable automatic application
sudo sed -i 's/^apply_updates =.*/apply_updates = yes/' /etc/dnf/automatic.conf
# Set output to standard I/O
sudo sed -i 's/^emit_via =.*/emit_via = stdio/' /etc/dnf/automatic.conf

# 4. Enabling Systemd Timer
echo "Enabling and starting dnf-automatic timer..."
sudo systemctl enable --now dnf-automatic.timer

# 5. Final Verification
echo -e "${GREEN}===> Configuration completed successfully!${NC}"
echo "Timer Status:"
systemctl status dnf-automatic.timer | grep "Active"