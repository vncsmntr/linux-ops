# 🐧 Linux Ops Toolkit

Centralized automation hub for Linux infrastructure. Contains provisioning scripts, security hardening, and system maintenance tools compatible with Ubuntu and RHEL-based systems.

## 🚀 Usage Pattern
Execute scripts via curl:
`curl -sSL https://raw.githubusercontent.com/vncsmntr/linux-ops/main/[folder]/[script].sh | sudo bash`

## 📂 Project Structure

### 🛡️ Security
* **`ssh-port-migrator.sh`**: Changes default SSH port, updates SELinux and Firewalls (UFW/Firewalld).

### 🛠️ Maintenance
* **`beszel-purge.sh`**: Completely removes Beszel Agent traces, services, and users.
* **`lvm-expand.sh`**: Automatically extends LVM partitions to use 100% of free disk space.

### ⚙️ Setup
* **`sftp-user-setup.sh`**: Provisions a restricted, chrooted SFTP-only user.
* **`graylog-install.sh`**: (AlmaLinux 10 Only) Full Graylog 7.0 stack installation with hardware-based optimization.