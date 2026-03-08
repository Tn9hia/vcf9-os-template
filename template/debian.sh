#!/bin/bash
# Script chuẩn hóa VM Debian 12, 13 cho template
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
echo "[4] Install VMware Tools package"
apt install open-vm-tools cloud-guest-utils -y
systemctl enable --now open-vm-tools.service

# Install strong password policy
echo "[5] Install strong password policy..."
apt install -y libpam-pwquality

# Xóa mọi dòng pam_pwquality.so hiện có
sed -i '/pam_pwquality.so/d' /etc/pam.d/common-password

# Thêm lại cấu hình mạnh
echo "password requisite pam_pwquality.so retry=3 minlen=8 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root" >> /etc/pam.d/common-password

# Enable SSH for root
echo "[6] Enable SSH for root..."
apt install -y openssh-server
systemctl enable ssh
systemctl start ssh
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh

# SSH clean keys
rm -f /etc/ssh/ssh_host_*
rm -f /root/.ssh/authorized_keys
rm -f /home/*/.ssh/authorized_keys

# Resize sda3 to full capacity
echo "[7] Resize sda3 to full capacity..."
pvresize /dev/sda3 || true
growpart /dev/sda 3 || true
lvextend -l +100%FREE /dev/debian-vg/root || true
resize2fs /dev/debian-vg/root || true

# Auto resize partition on first boot
echo "[8] Create rc.local for first boot..."
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
lvextend -l +100%FREE /dev/debian-vg/root
resize2fs /dev/debian-vg/root
NETWORK_CONFIG="/etc/network/interfaces"
TIMEOUT=30
for i in $(seq 1 $TIMEOUT); do
	if [ -f "$NETWORK_CONFIG" ]; then
		echo "Network configuration file found, restarting networking.service"
		# Restart networking service
		systemctl restart networking.service
		break
	fi
	echo "Waiting for $NETWORK_CONFIG ($i/$TIMEOUT)..."
	sleep 1
done
rm -f /etc/rc.local
rm -f /home/arp.sh
history -c
EOF
chmod 755 /home/arp.sh

echo "[11] Setup network..."
rm /etc/network/interfaces
SERVICE_FILE="/lib/systemd/system/networking.service"
sed -i '/^After=/ s/$/ vmtoolsd.service open-vm-tools.service/' "$SERVICE_FILE"

# Setup cloud-init
echo "[5] Setup cloud-init..."
apt install -y cloud-init
cloud-init clean --logs --configs all --machine-id

rm -f /run/systemd/network/*.lease
rm -f /var/lib/systemd/network/*.lease


# Clear machine ID
echo "[12] Clear machine ID..."
truncate -s0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clear logs
echo "[13] Clear logs..."
echo > /var/log/wtmp
rm -f ~/.bash_history
journalctl --rotate
journalctl --vacuum-time=1s
history -c

echo "[14] Done. Self-destructing..."
echo "Debian VM template customization completed. \n you should now run "history -c", remove the script, shut down the VM and convert it to a template."

shred -u "$0"