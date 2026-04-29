#!/bin/bash

# Ensure the script is running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "--- Available Network Interfaces ---"
nmcli -t -f DEVICE,TYPE,STATE device status
echo "------------------------------------"

# Use /dev/tty to ensure input works when piped
exec 3<&1
exec < /dev/tty

# 1. Ask for the interface name and trim whitespace
read -p "Enter the interface name: " RAW_IFACE
IFACE=$(echo "$RAW_IFACE" | xargs)

# Check if the interface exists in the system
if ! ip link show "$IFACE" > /dev/null 2>&1; then
    echo "Error: Interface '$IFACE' not found in ip link."
    exit 1
fi

# 2. Ask for IP address and CIDR
read -p "Enter the static IP with CIDR (e.g., 10.0.0.50/24): " IP_ADDR

# 3. Ask for Gateway
read -p "Enter the Gateway (e.g., 10.0.0.1): " GATEWAY

# 4. Ask for DNS
read -p "Enter DNS server (default 8.8.8.8): " DNS_SERVER
DNS_SERVER=${DNS_SERVER:-8.8.8.8}

# Restore stdin
exec <&3
exec 3<&-

echo "🚀 Configuring interface $IFACE..."

# Find connection name associated with the device
# We use -g (get) to fetch the connection name directly
CONN_NAME=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" | head -n 1)

# If connection is empty or "--", we create a new one
if [ -z "$CONN_NAME" ] || [ "$CONN_NAME" == "--" ] || [ "$CONN_NAME" == "" ]; then
    echo "No active connection profile for $IFACE. Creating 'static-$IFACE'..."
    CONN_NAME="static-$IFACE"
    # Delete if a profile with this name already exists to avoid conflicts
    nmcli con del "$CONN_NAME" > /dev/null 2>&1
    nmcli con add type ethernet con-name "$CONN_NAME" ifname "$IFACE"
fi

# Apply configurations
nmcli con mod "$CONN_NAME" ipv4.addresses "$IP_ADDR"
nmcli con mod "$CONN_NAME" ipv4.gateway "$GATEWAY"
nmcli con mod "$CONN_NAME" ipv4.dns "$DNS_SERVER"
nmcli con mod "$CONN_NAME" ipv4.method manual
nmcli con mod "$CONN_NAME" connection.autoconnect yes

# Bring the connection up
echo "🔄 Activating connection $CONN_NAME..."
nmcli con up "$CONN_NAME"

echo "✅ Success! Details for $IFACE:"
nmcli device show "$IFACE"