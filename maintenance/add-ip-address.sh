#!/bin/bash

# Ensure the script is running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "--- Available Network Interfaces ---"
nmcli device status
echo "------------------------------------"

# 1. Ask for the interface name
read -p "Enter the interface name (e.g., ens160, eth0): " IFACE

# Check if the interface exists
if ! nmcli device show "$IFACE" > /dev/null 2>&1; then
    echo "Error: Interface $IFACE not found."
    exit 1
fi

# 2. Ask for IP address and CIDR
read -p "Enter the static IP with CIDR (e.g., 192.168.1.10/24): " IP_ADDR

# 3. Ask for Gateway
read -p "Enter the Gateway (e.g., 192.168.1.1): " GATEWAY

# 4. Ask for DNS (Optional, defaults to Google)
read -p "Enter DNS server (press enter for 8.8.8.8): " DNS_SERVER
DNS_SERVER=${DNS_SERVER:-8.8.8.8}

echo "🚀 Configuring interface $IFACE..."

# Modify the connection
# Note: nmcli connection modify usually uses the connection name. 
# We'll target the connection bound to the specific device.
CONN_NAME=$(nmcli -g GENERAL.CONNECTION device show "$IFACE")

if [ -z "$CONN_NAME" ]; then
    echo "No active connection found for $IFACE. Creating a new one..."
    CONN_NAME="static-$IFACE"
    nmcli con add type ethernet con-name "$CONN_NAME" ifname "$IFACE"
fi

nmcli con mod "$CONN_NAME" ipv4.addresses "$IP_ADDR"
nmcli con mod "$CONN_NAME" ipv4.gateway "$GATEWAY"
nmcli con mod "$CONN_NAME" ipv4.dns "$DNS_SERVER"
nmcli con mod "$CONN_NAME" ipv4.method manual
nmcli con mod "$CONN_NAME" connection.autoconnect yes

# 5. Apply changes
echo "🔄 Restarting interface $IFACE..."
nmcli con up "$CONN_NAME"

echo "✅ Success! Network configuration applied to $IFACE."
nmcli device show "$IFACE"