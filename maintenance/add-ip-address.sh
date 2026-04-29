#!/bin/bash

# Function to show usage
usage() {
    echo "Usage: curl -sSL [URL] | sudo bash -s -- <interface> <ip/cidr> <gateway> [dns]"
    exit 1
}

# Ensure root
if [[ $EUID -ne 0 ]]; then
   echo "Error: Must be run as root"
   exit 1
fi

# Variables from arguments
IFACE=$1
IP_ADDR=$2
GATEWAY=$3
DNS_SERVER=${4:-8.8.8.8}

if [[ -z "$IFACE" || -z "$IP_ADDR" || -z "$GATEWAY" ]]; then
    usage
fi

echo "--- Available Network Interfaces ---"
nmcli -t -f DEVICE,TYPE,STATE device status
echo "------------------------------------"

# Hardware check
if ! ip link show "$IFACE" > /dev/null 2>&1; then
    echo "Error: Interface $IFACE not found."
    exit 1
fi

# Get connection name
CONN_NAME=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" | head -n 1)

if [[ -z "$CONN_NAME" || "$CONN_NAME" == "--" ]]; then
    CONN_NAME="static-$IFACE"
    nmcli con del "$CONN_NAME" > /dev/null 2>&1
    nmcli con add type ethernet con-name "$CONN_NAME" ifname "$IFACE"
fi

# Configure
nmcli con mod "$CONN_NAME" ipv4.addresses "$IP_ADDR"
nmcli con mod "$CONN_NAME" ipv4.gateway "$GATEWAY"
nmcli con mod "$CONN_NAME" ipv4.dns "$DNS_SERVER"
nmcli con mod "$CONN_NAME" ipv4.method manual
nmcli con mod "$CONN_NAME" connection.autoconnect yes

# Up
nmcli con up "$CONN_NAME"
echo "✅ Configuration complete for $IFACE"