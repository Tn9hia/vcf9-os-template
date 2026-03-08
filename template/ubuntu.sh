#!/bin/bash
# Script chuẩn hóa VM Ubuntu 20.04, 22.04, 24.04 cho template
# WARNING: Script này sẽ thay đổi nhiều cấu hình hệ thống

set -e

# Update system
echo "[1] Auto update packages..."
apt update -y && apt upgrade -y && apt install cloud-guest-utils -y && apt autoremove -y

echo "[2] Set hostname to default..."
hostnamectl set-hostname localhost

# Set timezone
echo "[3] Set timezone Asia/Ho_Chi_Minh..."
timedatectl set-timezone Asia/Ho_Chi_Minh

# Install VMware Tools
echo "[4] Install VMware Tools..."
apt install -y open-vm-tools
systemctl enable --now open-vm-tools.service

# Install password policy package
echo "[5] Install strong password policy..."
apt install -y libpam-pwquality

# Delete all lines contain pam_pwquality.so 
sed -i '/pam_pwquality.so/d' /etc/pam.d/common-password

# Set strong password policy
echo "password requisite pam_pwquality.so retry=3 minlen=8 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root" >> /etc/pam.d/common-password

# Resize sda3 to full capacity
echo "[6] Resize sda3 to full capacity..."
pvresize /dev/sda3 || true
growpart /dev/sda 3 || true
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv || true
resize2fs /dev/ubuntu-vg/ubuntu-lv || true

# Enable SSH for root
echo "[7] Enable SSH for root..."
apt install -y openssh-server
systemctl enable ssh
systemctl start ssh
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh

# SSH clean keys
rm -f /etc/ssh/ssh_host_*
rm -f /root/.ssh/authorized_keys
rm -f /home/*/.ssh/authorized_keys

# Create rc.local for first boot
echo "[8] Create rc.local for first boot..."
cat << 'EOF' > /etc/rc.local
#!/bin/bash
/home/arp.sh
exit 0
EOF
chmod 755 /etc/rc.local

# Create arp.sh (auto resize partition on first boot)
echo "[9] Create arp.sh (auto resize partition on first boot)..."
cat << 'EOF' > /home/arp.sh
#!/bin/bash
echo "1" >/sys/class/block/sda/device/rescan
growpart /dev/sda 3
pvresize /dev/sda3
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
resize2fs /dev/ubuntu-vg/ubuntu-lv
rm -f /etc/rc.local
rm -f /home/arp.sh
history -c
EOF
chmod 755 /home/arp.sh

# Remove netplan config
echo "[10] Remove netplan config..."
rm -f /etc/netplan/*.yaml

# Clear machine ID
echo "[11] Clear machine ID..."
truncate -s0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clear logs
echo "[12] Clear logs..."
echo > /var/log/wtmp
rm -f ~/.bash_history
journalctl --rotate
journalctl --vacuum-time=1s
history -c

# Setup cloud-init
echo "[13] Setup cloud-init..."
cloud-init clean --logs --configs all --machine-id

echo "[14] Done. Self-destructing..."

echo "Remember to delete default user accounts before converting to template."
echo "Ubuntu VM template customization completed. \n you should now run "history -c", remove the script, shut down the VM and convert it to a template."

shred -u "$0"