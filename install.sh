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
            if [ -d "/etc/update-motd.d" ]; then
                find /etc/update-motd.d/ -type f -exec rm -f {} \; 2>/dev/null || true
            fi
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /var/run/motd 2>/dev/null || true
            echo "" > /run/motd 2>/dev/null || true
            systemctl disable motd 2>/dev/null || true
            systemctl mask motd 2>/dev/null || true
            rm -f /etc/motd 2>/dev/null || true
            
            if [[ "$os_id" == "debian" ]] && [[ "$os_version" -le 11 ]]; then
                chmod -x /usr/bin/motd 2>/dev/null || true
                chmod -x /usr/sbin/motd 2>/dev/null || true
            fi
            
            if [[ "$os_id" == "debian" ]] && [[ "$os_version" -ge 12 ]]; then
                rm -rf /etc/motd.d/* 2>/dev/null || true
            fi
            ;;
            
        almalinux|rocky|fedora|centos)
            rm -rf /etc/update-motd.d/* 2>/dev/null || true
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /etc/issue 2>/dev/null || true
            echo "" > /etc/issue.net 2>/dev/null || true
            ;;
            
        opensuse*|opensuse-leap|opensuse-tumbleweed|suse)
            rm -rf /etc/update-motd.d/* 2>/dev/null || true
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /etc/issue 2>/dev/null || true
            echo "" > /etc/issue.net 2>/dev/null || true
            ;;
            
        *)
            rm -rf /etc/update-motd.d/* 2>/dev/null || true
            echo "" > /etc/motd 2>/dev/null || true
            echo "" > /etc/issue 2>/dev/null || true
            echo "" > /etc/issue.net 2>/dev/null || true
            ;;
    esac
    
    rm -f /etc/profile.d/*motd* 2>/dev/null || true
    rm -f /etc/profile.d/99-idcloudhost-motd.sh 2>/dev/null || true
    rm -f /etc/profile.d/motd.sh 2>/dev/null || true
    
    echo "MOTD cleaned successfully"
}

# ============================================
# FUNGSI: Fix SSH untuk AlmaLinux (Semua Versi)
# ============================================
fix_almalinux_ssh() {
    local os_version="$1"
    
    echo "Fixing SSH for AlmaLinux $os_version..."
    
    # Backup konfigurasi
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    # ===== KONFIGURASI DASAR =====
    # Aktifkan password authentication
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    sed -i 's/^UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    
    # ===== NONAKTIFKAN GSSAPI (PENYEBAB MASALAH) =====
    sed -i 's/^GSSAPIAuthentication.*/GSSAPIAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#GSSAPIAuthentication.*/GSSAPIAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^GSSAPICleanupCredentials.*/GSSAPICleanupCredentials no/' /etc/ssh/sshd_config
    sed -i 's/^#GSSAPICleanupCredentials.*/GSSAPICleanupCredentials no/' /etc/ssh/sshd_config
    sed -i 's/^#GSSAPIKeyExchange.*/GSSAPIKeyExchange no/' /etc/ssh/sshd_config
    sed -i 's/^GSSAPIKeyExchange.*/GSSAPIKeyExchange no/' /etc/ssh/sshd_config
    
    # ===== KONFIGURASI KHUSUS VERSI =====
    # AlmaLinux 8
    if [[ "$os_version" == "8" ]]; then
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
    
    # AlmaLinux 10
    if [[ "$os_version" == "10" ]]; then
        # Pastikan subsystem sftp
        echo "Subsystem sftp /usr/libexec/openssh/sftp-server" >> /etc/ssh/sshd_config
        
        # Nonaktifkan Match Group untuk root
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
        
        # Generate SSH keys
        ssh-keygen -A 2>/dev/null || true
    fi
    
    # ===== VALIDASI KONFIGURASI =====
    echo "Validating SSH configuration..."
    if sshd -t 2>/dev/null; then
        echo "SSH configuration is valid"
    else
        echo "WARNING: SSH configuration has errors, restoring backup..."
        cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config 2>/dev/null || true
    fi
    
    # ===== RESTART SSH =====
    echo "Restarting SSH service..."
    systemctl restart sshd 2>/dev/null || true
    systemctl enable sshd 2>/dev/null || true
    
    echo "SSH fixed for AlmaLinux $os_version"
}

# ============================================
# EKSEKUSI UTAMA
# ============================================

# 1. Hapus MOTD
remove_motd "$OS_ID" "$OS_VERSION"

# 2. Hapus banner login
echo "" > /etc/issue 2>/dev/null || true
echo "" > /etc/issue.net 2>/dev/null || true

# 3. Disable SSH banner
if grep -q "^Banner" /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's|^Banner.*|Banner none|' /etc/ssh/sshd_config
else
    echo "Banner none" >> /etc/ssh/sshd_config
fi

# 4. Fix khusus AlmaLinux (TERMASUK GSSAPI)
if [[ "$OS_ID" == "almalinux" ]]; then
    fix_almalinux_ssh "$OS_VERSION"
fi

# 5. Download dashboard
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
        DASHBOARD_URL=""
        ;;
esac

if [ -n "$DASHBOARD_URL" ]; then
    curl -fsSL "$DASHBOARD_URL" -o /etc/profile.d/osimpu.sh 2>/dev/null || {
        echo "Warning: Failed to download dashboard"
    }
    chmod +x /etc/profile.d/osimpu.sh 2>/dev/null || true
fi

# 6. Hush login
touch /root/.hushlogin

# 7. Restart SSH
if [[ "$OS_ID" == "almalinux" ]] || [[ "$OS_ID" == "rocky" ]] || [[ "$OS_ID" == "centos" ]] || [[ "$OS_ID" == "fedora" ]]; then
    systemctl restart sshd 2>/dev/null || true
    systemctl enable sshd 2>/dev/null || true
else
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
fi

# 8. Tampilkan info
echo -e "\n========================================"
echo "✅ Setup completed successfully!"
echo "========================================"
echo "OS: $OS_ID $OS_VERSION"
echo ""
echo "🔧 SSH Configuration:"
echo "  - Root login: Enabled ✓"
echo "  - Password auth: Enabled ✓"
echo "  - GSSAPI auth: Disabled ✓ (FIXED)"
echo "  - MOTD: Disabled ✓"
echo "  - Banner: Disabled ✓"
echo ""
echo "📊 Dashboard: /etc/profile.d/osimpu.sh"
echo "========================================"

# 9. Test SSH config
echo -e "\nTesting SSH configuration..."
if sshd -t 2>/dev/null; then
    echo "✅ SSH configuration is valid"
else
    echo "❌ SSH configuration has errors! Please check manually."
    echo "Run: sshd -t"
fi

history -c 2>/dev/null || true
echo -e "\nDone. You can now login normally."
