#!/usr/bin/env bash

# ==============================================================================
# NAME: Graylog 7.0 (Noir) Unified Installer
# DESCRIPTION: Optimized installation for AlmaLinux 10 (Small & Medium Profiles).
# REPOSITORY: vncsmntr/linux-ops
# ==============================================================================

set -euo pipefail

# --- UI Functions ---
info() { echo -e "\e[34mℹ️  $1\e[0m"; }
success() { echo -e "\e[32m✅ $1\e[0m"; }
warn() { echo -e "\e[33m⚠️  $1\e[0m"; }
error() { echo -e "\e[31m🚨 $1\e[0m"; exit 1; }

if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)."
fi

clear
echo "====================================================="
echo "       GRAYLOG 7.0 INSTALLATION & OPTIMIZATION"
echo "====================================================="

# 1. IP Detection
SERVER_IP=$(hostname -I | awk '{print $1}')
info "Detected Server IP: $SERVER_IP"
read -p "Use this IP for Web Access? (y/n): " IP_CONFIRM
[[ "$IP_CONFIRM" != "y" ]] && read -p "Enter correct IP: " SERVER_IP

# 2. Hardware Templates (Refined)
echo -e "\nSelect your hardware profile:"
echo "1) Small  [ 2 vCPU / 4 GB RAM ] -> (Lab/Testing)"
echo "2) Medium [ 4 vCPU / 8 GB RAM ] -> (Standard/Production)"
read -p "Option [1-2]: " HW_OPT

case $HW_OPT in
    1) OS_HEAP="2g"; GL_HEAP="1g";;
    2) OS_HEAP="4g"; GL_HEAP="2g";;
    *) OS_HEAP="2g"; GL_HEAP="1g"; warn "Invalid option. Defaulting to Small.";;
esac

# 3. Password Setup
echo ""
read -sp "Set 'admin' password: " USER_PASS
echo -e "\n"
read -sp "Confirm password: " USER_PASS_CONFIRM
echo -e "\n"
[[ "$USER_PASS" != "$USER_PASS_CONFIRM" ]] && error "Passwords do not match!"

info "🚀 Initializing Graylog v7.0 Installation..."

# 4. Repositories (MongoDB 7.0) with GPG workaround
info "Configuring Repositories..."
sudo dnf install -y java-21-openjdk-devel perl-Digest-SHA wget epel-release curl -q

# Download the key to a temporary file
wget -qO- https://www.mongodb.org/static/pgp/server-7.0.asc > /tmp/mongodb-server-7.0.asc

# Manually import the key to the RPM database (ignoring the policy check)
sudo rpm --import /tmp/mongodb-server-7.0.asc

cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo > /dev/null
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=file:///tmp/mongodb-server-7.0.asc
EOF

# Use --nogpgcheck specifically for the installation if the repo still complains
sudo dnf install -y mongodb-org --nogpgcheck -q
sudo systemctl enable --now mongod

# 5. OpenSearch 2.11 (Engine)
info "Installing and Tuning OpenSearch ($OS_HEAP Heap)..."
wget -q https://artifacts.opensearch.org/releases/bundle/opensearch/2.11.0/opensearch-2.11.0-linux-x64.rpm
sudo dnf localinstall -y opensearch-2.11.0-linux-x64.rpm -q

# Tuning OpenSearch
sudo sed -i 's/#cluster.name: my-application/cluster.name: graylog/' /etc/opensearch/opensearch.yml
echo -e "discovery.type: single-node\nplugins.security.disabled: true" | sudo tee -a /etc/opensearch/opensearch.yml > /dev/null

# Heap Adjustment
OS_JVM_CONF="/etc/opensearch/jvm.options"
sudo sed -i "s/^-Xms.*/-Xms$OS_HEAP/" $OS_JVM_CONF
sudo sed -i "s/^-Xmx.*/-Xmx$OS_HEAP/" $OS_JVM_CONF

# System Limits for OpenSearch
sudo sysctl -w vm.max_map_count=262144 > /dev/null
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf > /dev/null
sudo systemctl enable --now opensearch

# 6. Graylog Server 7.0 (Noir)
info "Installing Graylog Server ($GL_HEAP Heap)..."
sudo rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-7.0-repository_latest.rpm > /dev/null
sudo dnf install -y graylog-server --nogpgcheck -q

# Config Generation
SECRET=$(python3 -c 'import secrets; print(secrets.token_urlsafe(72)[:96])')
PASSWORD_HASH=$(echo -n "$USER_PASS" | shasum -a 256 | awk '{print $1}')

GL_CONF="/etc/graylog/server/server.conf"
sudo sed -i "s/password_secret =.*/password_secret = $SECRET/" $GL_CONF
sudo sed -i "s/root_password_sha2 =.*/root_password_sha2 = $PASSWORD_HASH/" $GL_CONF
sudo sed -i 's/#http_bind_address = 127.0.0.1:9000/http_bind_address = 0.0.0.0:9000/' $GL_CONF
echo "http_publish_uri = http://$SERVER_IP:9000/" | sudo tee -a $GL_CONF > /dev/null

# Graylog Heap Adjustment
GL_ENV_CONF="/etc/sysconfig/graylog-server"
sudo sed -i "s/-Xms1g -Xmx1g/-Xms$GL_HEAP -Xmx$GL_HEAP/" $GL_ENV_CONF

# 7. Security & Firewall
info "Finalizing Security Rules..."
sudo firewall-cmd --add-port={9000/tcp,1514/udp,1514/tcp,514/udp,514/tcp} --permanent > /dev/null
sudo firewall-cmd --reload > /dev/null
sudo setenforce 0

# 8. Start Services
sudo systemctl daemon-reload
sudo systemctl enable --now graylog-server

echo "====================================================="
success "GRAYLOG 7.0 INSTALLED SUCCESSFULLY!"
info "URL: http://$SERVER_IP:9000"
info "Profile: $OS_HEAP OpenSearch / $GL_HEAP Graylog"
warn "Initial boot takes ~60s. Log tail following..."
echo "====================================================="
sleep 15
sudo tail -n 20 /var/log/graylog-server/server.log