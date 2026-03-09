#!/bin/bash
# Script chuẩn hóa VM Ubuntu 20.04, 22.04, 24.04 cho template
# WARNING: Script này sẽ thay đổi nhiều cấu hình hệ thống

set -e

# Update system
echo "[1] Auto update packages..."
apt update -y && apt upgrade -y && apt install cloud-guest-utils open-vm-tools libpam-pwquality -y && apt autoremove -y
sudo apt autoremove --purge

# Enable necessary service
systemctl enable --now open-vm-tools.service # Only for Ubuntu. Use vmtoolsd.service for AlmaLinux
systemctl start vmtoolsd

# Setup enviroment information
echo "[2] Set hostname to default..."
hostnamectl set-hostname localhost

echo "[3] Set timezone Asia/Ho_Chi_Minh..."
timedatectl set-timezone Asia/Ho_Chi_Minh

# echo "[4] Set Root password to expire..."
# passwd --expire root

# Set strong password policy 
echo "[5] Install strong password policy..."
sed -i '/pam_pwquality.so/d' /etc/pam.d/common-password
echo "password requisite pam_pwquality.so retry=3 minlen=8 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root" >> /etc/pam.d/common-password

# Expand disk on first boot
echo "[6] Create arp.sh (auto resize partition on first boot)..."
cat << 'EOF' > /etc/rc.local
#!/bin/bash
/home/arp.sh
exit 0
EOF
chmod 755 /etc/rc.local

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
echo "[10] Clear logs..."
echo > /var/log/wtmp
rm -f ~/.bash_history
journalctl --rotate
journalctl --vacuum-time=1s
history -c

# Remove the udev persistent device rules and DHCP leases
rm -f /etc/udev/rules.d/70*
rm -f /var/lib/dhclient/*
rm -f /var/lib/NetworkManager/*.lease

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

# Remove netplan config
echo "[9] Remove netplan config..."
rm -f /etc/netplan/*.yaml

# Cleanup
echo "[14] Done. Self-destructing..."

echo "Remember to delete default user accounts before converting to template."
echo "Ubuntu VM template customization completed."
echo "You should now run 'history -c', remove the script, shut down the VM and convert it to a template."

shred -u "$0"