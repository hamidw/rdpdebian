#!/bin/bash

set -e

# Deteksi OS dan versi
OS_ID=$(source /etc/os-release && echo "$ID")
OS_VERSION=$(source /etc/os-release && echo "$VERSION_ID" | cut -d. -f1)

echo "Detected OS: $OS_ID $OS_VERSION"

# ============================================
# FUNGSI: Hapus MOTD dengan aman untuk semua OS
# ============================================
remove_motd() {
    local os_id="$1"
    local os_version="$2"
    
    echo "Removing MOTD files for $os_id $os_version..."
    
    case "$os_id" in
        ubuntu|debian)
            # Hapus semua file di update-motd.d
            if [ -d "/etc/update-motd.d" ]; then
                find /etc/update-motd.d/ -type f -exec rm -f {} \; 2>/dev/null || true
            fi
            
            # Bersihkan file motd
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /var/run/motd 2>/dev/null || true
            echo "" > /run/motd 2>/dev/null || true
            
            # Nonaktifkan service motd
            systemctl disable motd 2>/dev/null || true
            systemctl mask motd 2>/dev/null || true
            
            # Hapus symlink jika ada
            rm -f /etc/motd 2>/dev/null || true
            
            # Khusus Debian 11, nonaktifkan dynamic motd
            if [[ "$os_id" == "debian" ]] && [[ "$os_version" -le 11 ]]; then
                chmod -x /usr/bin/motd 2>/dev/null || true
                chmod -x /usr/sbin/motd 2>/dev/null || true
            fi
            
            # Khusus Debian 12, hapus direktori motd.d
            if [[ "$os_id" == "debian" ]] && [[ "$os_version" -ge 12 ]]; then
                rm -rf /etc/motd.d/* 2>/dev/null || true
            fi
            ;;
            
        almalinux|rocky|fedora|centos)
            # Untuk RHEL family
            rm -rf /etc/update-motd.d/* 2>/dev/null || true
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /etc/issue 2>/dev/null || true
            echo "" > /etc/issue.net 2>/dev/null || true
            ;;
            
        opensuse*|opensuse-leap|opensuse-tumbleweed|suse)
            # Untuk SUSE family
            rm -rf /etc/update-motd.d/* 2>/dev/null || true
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /etc/issue 2>/dev/null || true
            echo "" > /etc/issue.net 2>/dev/null || true
            ;;
            
        *)
            echo "Unknown OS, cleaning standard MOTD locations..."
            rm -rf /etc/update-motd.d/* 2>/dev/null || true
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /etc/issue 2>/dev/null || true
            echo "" > /etc/issue.net 2>/dev/null || true
            ;;
    esac
    
    # Hapus semua file terkait MOTD di profile.d
    rm -f /etc/profile.d/*motd* 2>/dev/null || true
    rm -f /etc/profile.d/99-idcloudhost-motd.sh 2>/dev/null || true
    rm -f /etc/profile.d/motd.sh 2>/dev/null || true
    
    echo "MOTD cleaned successfully"
}

# ============================================
# FUNGSI: Fix SSH untuk AlmaLinux 8 dan 10
# ============================================
fix_almalinux_ssh() {
    local os_version="$1"
    
    echo "Fixing SSH for AlmaLinux $os_version..."
    
    # Backup konfigurasi asli
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    # Konfigurasi dasar SSH
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    sed -i 's/^UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    
    # Khusus AlmaLinux 8
    if [[ "$os_version" == "8" ]]; then
        # Nonaktifkan GSSAPI
        sed -i 's/^#GSSAPIAuthentication.*/GSSAPIAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^GSSAPIAuthentication.*/GSSAPIAuthentication no/' /etc/ssh/sshd_config
        
        # Fix PAM untuk login root
        if [ -f /etc/pam.d/login ]; then
            sed -i 's/^auth.*required.*pam_securetty.so/#auth required pam_securetty.so/' /etc/pam.d/login
        fi
        if [ -f /etc/pam.d/sshd ]; then
            sed -i 's/^auth.*required.*pam_securetty.so/#auth required pam_securetty.so/' /etc/pam.d/sshd
        fi
        
        # Tambahkan konfigurasi tambahan
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
        echo "HostKey /etc/ssh/ssh_host_rsa_key" >> /etc/ssh/sshd_config
        echo "HostKey /etc/ssh/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config
        echo "HostKey /etc/ssh/ssh_host_ed25519_key" >> /etc/ssh/sshd_config
    fi
    
    # Khusus AlmaLinux 10
    if [[ "$os_version" == "10" ]]; then
        # AlmaLinux 10 menggunakan OpenSSH 9.x
        echo "Subsystem sftp /usr/libexec/openssh/sftp-server" >> /etc/ssh/sshd_config
        
        # Nonaktifkan Match Group untuk root (jika ada)
        sed -i '/^Match Group .*/,/^$/d' /etc/ssh/sshd_config
        
        # Fix PAM configuration untuk AlmaLinux 10
        cat > /etc/pam.d/sshd << 'EOF'
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    required     pam_selinux.so open
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
EOF
        
        # Pastikan SSH key di-generate
        ssh-keygen -A 2>/dev/null || true
    fi
    
    # Restart SSH
    systemctl restart sshd 2>/dev/null || true
    systemctl enable sshd 2>/dev/null || true
    
    echo "SSH fixed for AlmaLinux $os_version"
}

# ============================================
# EKSEKUSI UTAMA
# ============================================

# 1. Hapus branding provider
remove_motd "$OS_ID" "$OS_VERSION"

# 2. Hapus banner login
echo "" > /etc/issue 2>/dev/null || true
echo "" > /etc/issue.net 2>/dev/null || true

# 3. Disable SSH banner safely
if grep -q "^Banner" /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's|^Banner.*|Banner none|' /etc/ssh/sshd_config
else
    echo "Banner none" >> /etc/ssh/sshd_config
fi

# 4. Fix khusus AlmaLinux
if [[ "$OS_ID" == "almalinux" ]]; then
    fix_almalinux_ssh "$OS_VERSION"
fi

# 5. Download dashboard sesuai OS
echo "Downloading dashboard for $OS_ID..."
case "$OS_ID" in
    ubuntu)
        DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_ubuntu.sh"
        ;;
    debian)
        DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_debian.sh"
        ;;
    almalinux)
        DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_almalinux.sh"
        ;;
    rocky)
        DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_rocky.sh"
        ;;
    fedora)
        DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_fedora.sh"
        ;;
    opensuse*|opensuse-leap|opensuse-tumbleweed)
        DASHBOARD_URL="https://raw.githubusercontent.com/hamidw/osimpu-cloudinit/main/vps_linux/osimpu_suse.sh"
        ;;
    *)
        echo "OS tidak didukung: $OS_ID"
        echo "Skipping dashboard installation..."
        DASHBOARD_URL=""
        ;;
esac

if [ -n "$DASHBOARD_URL" ]; then
    curl -fsSL "$DASHBOARD_URL" -o /etc/profile.d/osimpu.sh 2>/dev/null || {
        echo "Warning: Failed to download dashboard"
    }
    chmod +x /etc/profile.d/osimpu.sh 2>/dev/null || true
fi

# 6. Hush login untuk root
touch /root/.hushlogin

# 7. Restart SSH dengan benar
echo "Restarting SSH service..."
if [[ "$OS_ID" == "almalinux" ]] || [[ "$OS_ID" == "rocky" ]] || [[ "$OS_ID" == "centos" ]] || [[ "$OS_ID" == "fedora" ]]; then
    systemctl stop sshd 2>/dev/null || true
    systemctl start sshd 2>/dev/null || true
    systemctl enable sshd 2>/dev/null || true
else
    systemctl stop ssh 2>/dev/null || true
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null || true
fi

# 8. Verifikasi SSH status
echo -e "\n========================================"
echo "Setup completed successfully!"
echo "OS: $OS_ID $OS_VERSION"
echo "SSH Status:"
systemctl status ssh 2>/dev/null || systemctl status sshd 2>/dev/null || echo "SSH service status unknown"
echo "========================================"

# 9. Optional: Tampilkan informasi login
echo -e "\nInformasi Login:"
echo "- Root login: Enabled"
echo "- Password authentication: Enabled"
echo "- MOTD: Disabled"
echo "- SSH Banner: Disabled"
echo "- Dashboard: Installed at /etc/profile.d/osimpu.sh"

# 10. Bersihkan history
history -c 2>/dev/null || true
echo "Done."
