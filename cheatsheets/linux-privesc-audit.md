# Linux privilege-escalation audit cheatsheet

Copy-paste enumeration for auditing a host **you own** (or an authorized lab). Cross-reference
findings against https://gtfobins.github.io. Defensive goal: find the path, then close it.

## Quick situational awareness
```bash
id; whoami; hostname; uname -a
cat /etc/os-release
sudo -l 2>/dev/null                 # what can I run as root? (the #1 win)
```

## SUID / SGID / capabilities
```bash
find / -perm -4000 -type f 2>/dev/null      # SUID
find / -perm -2000 -type f 2>/dev/null      # SGID
getcap -r / 2>/dev/null                      # file capabilities (cap_setuid = danger)
```
Anything unusual here → check GTFOBins for a shell escape.

## Writable things that root executes
```bash
# Cron
cat /etc/crontab; ls -la /etc/cron.*; crontab -l 2>/dev/null
# systemd units you can write
find /etc/systemd /lib/systemd -writable -type f 2>/dev/null
# world-writable dirs in PATH
echo $PATH | tr ':' '\n' | while read d; do [ -w "$d" ] && echo "WRITABLE: $d"; done
# world-writable files/dirs generally
find / -writable -type f 2>/dev/null | grep -vE '^/proc|^/sys' | head -50
```

## Credentials & secrets on disk
```bash
grep -RiE 'password|passwd|secret|api[_-]?key|token' /etc /home /var/www 2>/dev/null | head
find / -name '*.env' 2>/dev/null
find / -name 'id_rsa' -o -name '*.pem' 2>/dev/null      # private keys
cat ~/.bash_history ~/.mysql_history 2>/dev/null
ls -la /var/backups 2>/dev/null
# Cloud metadata / creds
env | grep -iE 'aws|gcp|azure|token'
cat ~/.aws/credentials ~/.config/gcloud/* 2>/dev/null
```

## Kernel / distro version → known CVEs
```bash
uname -r                              # match against local-privesc CVE DBs
# In a lab, tools like linux-exploit-suggester map version → candidate exploits.
```

## Automate (lab)
```bash
./linpeas.sh -a | tee linpeas.txt     # peass-ng — colored, ranks findings by likelihood
./lse.sh -l1                          # linux-smart-enumeration
pspy64                                # watch cron/other users' processes w/o root
```
In production, use **lynis** or **OpenSCAP/CIS-CAT** (read-only audit) instead of offensive enum.

## Fix map
| Finding | Fix |
|---------|-----|
| `sudo NOPASSWD` on shell-escapable binary | scope to non-escapable commands; audit sudoers in CI |
| unexpected SUID binary | remove SUID bit / `nosuid` mount / delete |
| writable cron/systemd/PATH | `root:root 0755`, remove writable dirs from PATH |
| secrets on disk | move to Vault/SSM/secrets manager; `chmod 600` keys |
| dangerous capability | remove with `setcap -r`, drop from container spec |
| outdated kernel | patch cadence + unattended security updates |
