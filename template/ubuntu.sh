#!/bin/bash
# Script chuẩn hóa VM Ubuntu 20.04, 22.04, 24.04 cho template
# WARNING: Script này sẽ thay đổi nhiều cấu hình hệ thống

set -e

# update system
echo "[1] Auto update packages..."
apt update -y && apt upgrade -y && apt install cloud-guest-utils -y && apt autoremove -y

echo "[2] Set hostname to default..."
hostnamectl set-hostname localhost

# set timezone
echo "[3] Set timezone Asia/Ho_Chi_Minh..."
timedatectl set-timezone Asia/Ho_Chi_Minh

# install VMware Tools
echo "[4] Install VMware Tools..."
apt install -y open-vm-tools
systemctl enable --now open-vm-tools.service

echo "[6] Install strong password policy..."
apt install -y libpam-pwquality

# Xóa mọi dòng pam_pwquality.so hiện có
sed -i '/pam_pwquality.so/d' /etc/pam.d/common-password

# Thêm lại cấu hình mạnh
echo "password requisite pam_pwquality.so retry=3 minlen=8 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root" >> /etc/pam.d/common-password

echo "[7] Resize sda3 to full capacity..."
pvresize /dev/sda3 || true
growpart /dev/sda 3 || true
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv || true
resize2fs /dev/ubuntu-vg/ubuntu-lv || true

echo "[8] Enable SSH for root..."
apt install -y openssh-server
systemctl enable ssh
systemctl start ssh
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh

echo "[9] Create rc.local for first boot..."
cat << 'EOF' > /etc/rc.local
#!/bin/bash
/home/arp.sh
exit 0
EOF
chmod 755 /etc/rc.local

echo "[10] Create arp.sh (auto resize partition on first boot)..."
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

echo "[11] Remove netplan config..."
rm -f /etc/netplan/*.yaml

echo "[12] Clear machine ID..."
truncate -s0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

echo "[13] Clear logs..."
echo > /var/log/wtmp
rm -f ~/.bash_history
journalctl --rotate
journalctl --vacuum-time=1s
history -c


# Setup cloud-init
echo "[14] Setup cloud-init..."
cloud-init clean

# MOTD

echo "[15] Done. Self-destructing..."

echo "Remember to delete default user accounts before converting to template."
echo "Ubuntu VM template customization completed. \n you should now run "history -c", remove the script, shut down the VM and convert it to a template."

shred -u "$0"