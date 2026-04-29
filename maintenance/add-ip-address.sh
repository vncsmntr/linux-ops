#!/bin/bash

# Function to show usage
usage() {
    echo "Usage: curl -sSL [URL] | sudo bash -s -- <interface> <ip/cidr> <gateway> [dns]"
    echo "Example: curl -sSL [URL] | sudo bash -s -- ens35 10.181.214.132/25 10.181.214.254 10.181.214.130"
    exit 1
}

# Ensure the script is running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

# Map arguments
IFACE=$1
IP_ADDR=$2
GATEWAY=$3
DNS_SERVER=${4:-8.8.8.8}

# Check for mandatory arguments
if [[ -z "$IFACE" || -z "$IP_ADDR" || -z "$GATEWAY" ]]; then
    usage
fi

echo "--- Available Network Interfaces ---"
nmcli -t -f DEVICE,TYPE,STATE device status
echo "------------------------------------"

echo "🚀 Starting network configuration for $IFACE..."

# Verify if interface exists
if ! ip link show "$IFACE" > /dev/null 2>&1; then
    echo "Error: Interface $IFACE not found."
    exit 1
fi

# Detect or create NetworkManager connection
CONN_NAME=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" | head -n 1)

if [[ -z "$CONN_NAME" || "$CONN_NAME" == "--" ]]; then
    echo "No active profile for $IFACE. Creating 'static-$IFACE'..."
    CONN_NAME="static-$IFACE"
    nmcli con del "$CONN_NAME" > /dev/null 2>&1
    nmcli con add type ethernet con-name "$CONN_NAME" ifname "$IFACE"
fi

# Apply settings
nmcli con mod "$CONN_NAME" ipv4.addresses "$IP_ADDR"
nmcli con mod "$CONN_NAME" ipv4.gateway "$GATEWAY"
nmcli con mod "$CONN_NAME" ipv4.dns "$DNS_SERVER"
nmcli con mod "$CONN_NAME" ipv4.method manual
nmcli con mod "$CONN_NAME" connection.autoconnect yes

# Apply changes
echo "🔄 Activating connection $CONN_NAME..."
nmcli con up "$CONN_NAME"

echo "✅ Success! IP $IP_ADDR applied to $IFACE."