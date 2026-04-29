# Static IP Configuration Script for AlmaLinux

A robust Bash script designed to configure static IPv4 addresses on AlmaLinux 8/9 using NetworkManager (nmcli). This script is optimized to be executed directly via curl or locally, ensuring seamless network management in virtualized environments like VMware or Cisco Modeling Labs (CML).

## 🚀 Quick Start (One-Liner)

The most efficient way to run this script is by passing arguments directly to bash. This avoids interactive input issues when piping from curl.

```bash
curl -sSL https://raw.githubusercontent.com/vncsmntr/linux-ops/main/maintenance/add-ip-address.sh | sudo bash -s -- <interface> <ip/cidr> <gateway> <dns>
```

```bash
Example: curl -sSL https://raw.githubusercontent.com/vncsmntr/linux-ops/main/maintenance/add-ip-address.sh | sudo bash -s -- ens35 10.0.0.50/24 10.0.0.1 8.8.8.8
```

## 🛠 Features

Non-Interactive Execution: Optimized for automation and remote execution.

Auto-Profile Creation: Automatically detects if a NetworkManager connection exists for the interface; if not, it creates a new one.

SELinux & Firewall Friendly: Uses native nmcli commands that comply with RHEL/AlmaLinux security policies.

Validation: Checks for root privileges and verifies if the interface hardware exists before applying changes.

## 📋 Prerequisites

Operating System: AlmaLinux 8, AlmaLinux 9, or any RHEL-based distribution.
Permissions: Must be executed as root or with sudo.
Service: NetworkManager must be running.

## 📖 Usage Details

1 - Interface: "The network device name (e.g., from nmcli device)" (EX: ens160)

2 - IP/CIDR: The static IP address followed by the subnet mask (EX: 192.168.1.10/24)

3 - Gateway: The default gateway IP address (EX: 192.168.1.1)

4 - DNS: Primary DNS server. (Defaults to 8.8.8.8)

Local Execution

If you prefer to download the script first:

```bash
chmod +x add-ip-address.sh
```

```bash
sudo ./add-ip-address.sh ens160 172.16.0.10/24 172.16.0.1
```

## ⚠️ Troubleshooting

1. Interface not found: Ensure the interface name matches the output of nmcli device status.

2. GitHub Content Caching: If you recently updated the script and the curl command is still fetching the old version, append a timestamp or version string to the URL:

```bash
curl -sSL https://raw.githubusercontent.com/vncsmntr/linux-ops/main/maintenance/add-ip-address.sh?v=$(date +%s) | sudo bash -s -- ...
```

Author: Vinícius Monteiro

License: MIT