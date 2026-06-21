#!/bin/bash

set -e

OS_ID=$(source /etc/os-release && echo "$ID")

# Hapus branding provider

rm -rf /etc/profile.d/99-idcloudhost-motd.sh
rm -rf /etc/profile.d/motd.sh

rm -f /etc/update-motd.d/10-help-text

# Hapus banner login

echo "" > /etc/issue
echo "" > /etc/issue.net

# Disable SSH banner safely
if grep -q "^Banner" /etc/ssh/sshd_config; then
    sed -i 's|^Banner.*|Banner none|' /etc/ssh/sshd_config
else
    echo "Banner none" >> /etc/ssh/sshd_config
fi

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
