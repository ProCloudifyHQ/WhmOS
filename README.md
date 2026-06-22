# WhmOS

Open-source CLI-based server management toolkit for WHM/cPanel dedicated servers.

## One-Line Install

```bash
bash <(curl -s https://raw.githubusercontent.com/ProCloudifyHQ/WhmOS/main/install.sh)
```

## Features

| Module | Description |
|---|---|
| Security | fail2ban, malware scan, rootkit detection, file integrity |
| Monitor | CPU, RAM, disk, bandwidth, network connections |
| Services | Status, restart, auto-heal for Apache/MySQL/PHP-FPM/Exim/Dovecot |
| Audit | SSH logins, WHM logins, cron audit, SUID check |
| SSL | Expiry check for all domains with Telegram alerts |
| Mail | Queue monitor, top senders, frozen messages |
| Backup | JetBackup/cPanel backup status & alerts |
| WordPress | Outdated core/plugins, suspicious file scan |
| Reports | Daily & weekly Telegram reports |

## Usage

```bash
whmos          # Interactive menu
whmos config   # Reconfigure settings
```

## Automated Tasks (set up during install)

| Task | Schedule |
|---|---|
| Daily report | Every day at 8 AM |
| Weekly summary | Every Monday at 9 AM |
| Service auto-heal | Every 5 minutes |
| SSL expiry check | Every day at 8 AM |
| Mail queue check | Every 30 minutes |
| System alert check | Every 10 minutes |
| SSH login alert | On every SSH login |

## Requirements

- AlmaLinux / CentOS / RHEL 8+
- WHM/cPanel server
- Root access
- Telegram Bot (for alerts)

## Author

[ProCloudify](https://procloudify.com)
