## Message of the Day (MOTD) trên 3 distro

### TL;DR — Cấu hình chính:

| Distro | Static MOTD | Dynamic MOTD |
|--------|-------------|--------------|
| **AlmaLinux** | `/etc/motd` | `/etc/profile.d/*.sh` |
| **Debian** | `/etc/motd` | `/etc/update-motd.d/` |
| **Ubuntu** | `/etc/motd` | `/etc/update-motd.d/` |

---

### Chi tiết từng distro

**AlmaLinux (RHEL-based)**
```
/etc/motd                  ← static text, hiện sau login
/etc/issue                 ← hiện TRƯỚC login (pre-auth banner)
/etc/issue.net             ← pre-auth banner cho SSH
/etc/profile.d/motd.sh     ← dynamic, chạy script khi user login
```
> AlmaLinux **không có** `update-motd.d` theo mặc định. Muốn dynamic thì tự drop script vào `/etc/profile.d/`.

---

**Debian & Ubuntu**
```
/etc/motd                  ← static (nếu ghi thẳng vào đây)
/etc/update-motd.d/        ← dynamic scripts, chạy theo thứ tự số
  ├── 00-header
  ├── 10-sysinfo
  ├── 50-landscape-sysinfo  (Ubuntu)
  └── 99-custom             ← drop file của mày vào đây
```
> Files trong `/etc/update-motd.d/` phải **executable** và output ra `stdout` → kernel ghép lại thành `/run/motd.dynamic`.

---

### Quick setup — custom MOTD

**AlmaLinux:**
```bash
cat > /etc/motd << 'EOF'
#####################################
#  Production Server — Stay Sharp  #
#####################################
EOF
```

**Debian/Ubuntu (dynamic, recommended):**
```bash
cat > /etc/update-motd.d/99-custom << 'EOF'
#!/bin/bash
echo ""
echo "  Hostname : $(hostname)"
echo "  Uptime   : $(uptime -p)"
echo "  Load     : $(cut -d' ' -f1-3 /proc/loadavg)"
echo ""
EOF

chmod +x /etc/update-motd.d/99-custom
```

---

### Disable MOTD components (Ubuntu hay bị noisy)

```bash
# Tắt bớt cái không cần
chmod -x /etc/update-motd.d/10-help-text
chmod -x /etc/update-motd.d/50-landscape-sysinfo

# Tắt hẳn legal notice
chmod -x /etc/update-motd.d/00-header
```

---

### SSH-specific — cần check thêm

```bash
# /etc/ssh/sshd_config
PrintMotd yes        # bật MOTD qua SSH
Banner /etc/issue.net  # pre-auth banner (optional)
```

> ⚠️ Một số distro set `PrintMotd no` trong PAM + sshd cùng lúc → MOTD bị double print hoặc mất hẳn. Check `/etc/pam.d/sshd` nếu MOTD không hiện.