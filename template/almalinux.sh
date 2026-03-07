#!/bin/bash
# Script chuẩn hóa VM AlmaLinux 8,9,10 cho template
# WARNING: Script này sẽ thay đổi nhiều cấu hình hệ thống
# Change interface name if needed

set -e

INTERFACE="ens192"
CONNECTION_NAME="ens192"

# Update system
echo "[1] Auto update packages..."
dnf update -y && dnf upgrade -y && dnf autoremove -y

echo "[2] Set hostname to default..."
hostnamectl set-hostname localhost

# Set timezone
echo "[3] Set timezone to Asia/Ho_Chi_Minh..."
timedatectl set-timezone Asia/Ho_Chi_Minh

# Install VMware Tools
echo "[4] Install VMware Tools..."
dnf install -y perl open-vm-tools cloud-utils-growpart
sudo systemctl enable --now vmtoolsd.service

# Set password policy
echo "[5] Set password policy..."
sed -i 's|^password\s\+requisite\s\+pam_pwquality.so.*|password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type= minlen=8 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root|' /etc/pam.d/system-auth

# SSH clean keys
rm -f /etc/ssh/ssh_host_*
rm -f /root/.ssh/authorized_keys
rm -f /home/*/.ssh/authorized_keys

# Auto resize partition on first boot
echo "[6] Auto resize partition on first boot..."
cat <<'EOF' > /usr/local/bin/arp.sh
#!/bin/bash
echo "1" >/sys/class/block/sda/device/rescan
growpart /dev/sda 3
pvresize /dev/sda3
lvextend -l +100%FREE /dev/mapper/almalinux-root
xfs_growfs /dev/mapper/almalinux-root
systemctl disable arp-resize.service
rm -f /etc/systemd/system/arp-resize.service
systemctl daemon-reload
rm -f /usr/local/bin/arp.sh
EOF

chmod +x /usr/local/bin/arp.sh

# Create systemd unit file
cat <<'EOF' > /etc/systemd/system/arp-resize.service
[Unit]
Description=Auto resize partition on boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/arp.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

systemctl enable arp-resize.service

# Setup cloud-init
echo "[7] Setup cloud-init..."
dnf install -y cloud-init

systemctl enable cloud-init-local.service
systemctl enable cloud-init.service
systemctl enable cloud-config.service
systemctl enable cloud-final.service

cloud-init clean --logs

# Setup network
echo "[8] Setup network..."

echo "Deleting old connection..."
nmcli connection delete "$CONNECTION_NAME" 2>/dev/null || true

echo "Creating new connection with new UUID..."
nmcli connection add type ethernet con-name "$CONNECTION_NAME" ifname "$INTERFACE"

echo "Configuring network settings..."
nmcli connection modify "$CONNECTION_NAME" ipv4.method auto
nmcli connection modify "$CONNECTION_NAME" ipv6.method ignore  
nmcli connection modify "$CONNECTION_NAME" connection.autoconnect yes

# Remove cloned MAC address (if any)
nmcli connection modify "$CONNECTION_NAME" 802-3-ethernet.cloned-mac-address ""

echo "[9] Cleaning up lease files and udev rules..."
rm -f /var/lib/NetworkManager/*.lease
rm -f /etc/udev/rules.d/70-persistent-net.rules

echo "[10] Restarting NetworkManager..."
systemctl enable NetworkManager
systemctl restart NetworkManager
g
# Clear machine_id
echo "[11] Clear machine ID..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clear logs	
echo "[12] Clear logs..."
journalctl --rotate
journalctl --vacuum-time=1s
rm -f ~/.bash_history
history -c

echo "[13] Done. Self-destructing..."
echo "AlmaLinux VM template customization completed. \n you should now run "history -c", remove the script, shut down the VM and convert it to a template."

shred -u "$0"