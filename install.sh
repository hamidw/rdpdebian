#!/bin/bash

set -e

OS_ID=$(source /etc/os-release && echo "$ID")

# Hapus branding provider

rm -f /etc/profile.d/99-idcloudhost-motd.sh
rm -f /etc/profile.d/motd.sh

# Hapus banner login

echo "" > /etc/issue
echo "" > /etc/issue.net

# Hapus khusus Opensuse
echo "" > /etc/motd

# Disable SSH banner

sed -i 's/^#?Banner.*/Banner none/' /etc/ssh/sshd_config

# Download dashboard sesuai OS

case "$OS_ID" in
ubuntu|debian)
DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_ubuntu.sh"
;;
almalinux|rocky)
DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_almalinux.sh"
;;
fedora)
DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_fedora.sh"
;;
opensuse*|opensuse-leap|opensuse-tumbleweed)
DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_suse.sh"
;;
*)
echo "OS tidak didukung: $OS_ID"
exit 0
;;
esac

curl -fsSL "$DASHBOARD_URL" -o /etc/profile.d/osimpu.sh
chmod +x /etc/profile.d/osimpu.sh

touch /root/.hushlogin

systemctl restart ssh 2>/dev/null || true
systemctl restart sshd 2>/dev/null || true

echo "Selesai."
