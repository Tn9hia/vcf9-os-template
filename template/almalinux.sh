#!/bin/bash
# Script chuẩn hóa VM AlmaLinux 8,9,10 cho template
# WARNING: Script này sẽ thay đổi nhiều cấu hình hệ thống
# Thay đổi interface name nếu cần

set -e

INTERFACE="ens192"
CONNECTION_NAME="ens192"

# Update system
echo "[1] Auto update packages..."
dnf update -y && dnf upgrade -y 
dnf install -y perl open-vm-tools cloud-utils-growpart cloud-init && dnf autoremove -y
package-cleanup --oldkernels --count=2

# Enable necessary service
systemctl enable --now vmtoolsd.service

# Setup enviroment information
echo "[2] Set hostname to default..."
hostnamectl set-hostname localhost

echo "[3] Set timezone to Asia/Ho_Chi_Minh..."
timedatectl set-timezone Asia/Ho_Chi_Minh

# echo "[4] Set Root password to expire..."
# passwd --expire root

# Set strong password policy
echo "[5] Set password policy..."
sed -i 's|^password\s\+requisite\s\+pam_pwquality.so.*|password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type= minlen=8 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root|' /etc/pam.d/system-auth

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

# Enable SSH for root
# echo "[7] Enable SSH for root (Deprecated) ..."
# apt install -y openssh-server
# systemctl enable ssh
# systemctl start ssh
# sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
# systemctl restart ssh

# SSH clean keys
echo "[8] SSH clean keys..."
rm -f /etc/ssh/ssh_host_*
rm -f /root/.ssh/authorized_keys
rm -f /home/*/.ssh/authorized_keys

# Clear logs	
echo "[12] Clear logs..."
journalctl --rotate
journalctl --vacuum-time=1s
rm -f ~/.bash_history
history -c

# Enable cloud-init
echo "[11] Enable cloud-init..."
rm /etc/cloud/cloud-init.disabled

echo "[12] Add vmware datasource..."
echo "datasource_list: [ VMware, OVF, None ]" > /etc/cloud/cloud.cfg.d/98-vmware.cfg

echo "[13] Enable cloud-init services..."
systemctl enable cloud-init.service
systemctl enable cloud-init-local.service
systemctl enable cloud-config.service
systemctl enable cloud-final.service

cloud-init clean --logs --configs all --machine-id
echo "policy: auto" >  /etc/cloud/ds-identify.cfg

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

echo "[13] Done. Self-destructing..."
echo "AlmaLinux VM template customization completed. \n you should now run "history -c", remove the script, shut down the VM and convert it to a template."

shred -u "$0"