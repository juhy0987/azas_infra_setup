#!/bin/bash
set -euo pipefail

# Minimal installer for ansible, terraform, awscli and prometheus ansible collection
# Rocky Linux only

info() { printf "[INFO] %s\n" "$*"; }
err() { printf "[ERROR] %s\n" "$*" >&2; exit 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    info "Not running as root, will use sudo for privileged commands"
  else
    err "This script requires sudo or root privileges"
  fi
fi

if ! command -v yum >/dev/null 2>&1; then
  err "yum not found. This script supports Rocky Linux only."
fi

info "Enabling EPEL repository"
$SUDO yum install -y epel-release

info "Updating package lists"
$SUDO yum makecache -y
$SUDO yum install -y curl unzip

info "Installing Ansible (yum)"
$SUDO yum install -y ansible

info "Installing awscli v2 (official bundle installer)"
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -o -q /tmp/awscliv2.zip -d /tmp
$SUDO /tmp/aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws

info "Installing Terraform (HashiCorp official repo)"
$SUDO yum install -y yum-utils
$SUDO yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
$SUDO yum install -y terraform

info "Installing Prometheus Ansible collection"
ansible-galaxy collection install prometheus.prometheus --force >/dev/null

info "Installation complete"

exit 0
