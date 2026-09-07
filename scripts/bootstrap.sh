#!/usr/bin/env bash
# One-shot box provisioning. Run as root. Reads deploy public keys from
# /tmp/deploy_authorized_keys (one key per line), placed there before running.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg fail2ban unattended-upgrades rsync

# --- Docker (official apt repo) ---
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# --- deploy user in docker group ---
id -u deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
usermod -aG docker deploy
install -d -o deploy -g deploy -m 0700 /home/deploy/.ssh
if [ -f /tmp/deploy_authorized_keys ]; then
  install -o deploy -g deploy -m 0600 /tmp/deploy_authorized_keys /home/deploy/.ssh/authorized_keys
fi

# --- app dir ---
install -d -o deploy -g deploy -m 0755 /srv/codeknight-infra

# --- harden sshd: key-only, no root login ---
# Write to a drop-in that wins: Ubuntu 24.04's sshd_config does
# `Include /etc/ssh/sshd_config.d/*.conf` and uses first-value-wins, so a
# 00- file is read before the AMI's 50-cloud-init.conf. Validate before restart.
printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' \
  > /etc/ssh/sshd_config.d/00-hardening.conf
sshd -t && systemctl restart ssh ssh.socket

# --- automatic security updates ---
dpkg-reconfigure -f noninteractive unattended-upgrades || true

echo "BOOTSTRAP_OK"

# --- nightly database backup ---
# VACUUM INTO snapshot of the internal SQLite database, kept 14 days. Runs as
# deploy because the script talks to the compose stack.
install -d -o deploy -g deploy -m 0750 /srv/backups/codeknight
cat > /etc/cron.d/codeknight-backup <<'CRON'
# m h dom mon dow user command
17 3 * * * deploy cd /srv/codeknight-infra && ./scripts/backup-db.sh >> /var/log/codeknight-backup.log 2>&1
CRON
chmod 0644 /etc/cron.d/codeknight-backup
