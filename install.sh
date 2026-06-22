#!/bin/bash
# WHMOS Installer
# Usage: bash <(curl -s https://raw.githubusercontent.com/ProCloudifyHQ/WhmOS/main/install.sh)

WHMOS_VERSION="1.0.0"
WHMOS_DIR="/usr/local/whmos"
SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo ""
echo -e "${BOLD}  $SEP"
echo "  WHMOS  v${WHMOS_VERSION}  —  Installer"
echo "  WHM OS Server Manager by ProCloudify"
echo -e "  $SEP${NC}"
echo ""

step()  { echo -e "  ${CYAN}[STEP $1]${NC} ${BOLD}$2${NC}"; }
ok()    { echo -e "  ${GREEN}  ✔ $1${NC}"; }
fail()  { echo -e "  ${RED}  ✖ $1${NC}"; exit 1; }
info()  { echo -e "  ${YELLOW}  ℹ $1${NC}"; }
ask()   { echo -e -n "  ${BOLD}  $1: ${NC}"; }

# Root check
if [ "$EUID" -ne 0 ]; then
  fail "Please run as root."
fi

# OS check
if ! command -v dnf &>/dev/null && ! command -v yum &>/dev/null; then
  fail "This installer requires dnf/yum (AlmaLinux, CentOS, RHEL)."
fi

# Step 1 — Dependencies
step 1 "Installing dependencies..."
dnf install -y -q curl wget bc openssl fail2ban epel-release 2>/dev/null || \
yum install -y -q curl wget bc openssl fail2ban epel-release 2>/dev/null
ok "Dependencies installed"

# Step 2 — Create directories
step 2 "Creating WHMOS directory..."
mkdir -p "$WHMOS_DIR/modules" "$WHMOS_DIR/logs"
ok "Directory created at $WHMOS_DIR"

# Step 3 — Download files
step 3 "Downloading WHMOS files..."
BASE_URL="https://raw.githubusercontent.com/ProCloudifyHQ/WhmOS/main"
FILES="whmos modules/notify.sh modules/security.sh modules/monitor.sh modules/services.sh modules/audit.sh modules/ssl.sh modules/mail.sh modules/backup.sh modules/wordpress.sh modules/report.sh"
for f in $FILES; do
  curl -s "$BASE_URL/$f" -o "$WHMOS_DIR/$f" || fail "Failed to download $f"
done
chmod +x "$WHMOS_DIR/whmos"
chmod +x "$WHMOS_DIR/modules/"*.sh
ln -sf "$WHMOS_DIR/whmos" /usr/local/bin/whmos
ok "WHMOS files downloaded"

# Step 4 — Configure
step 4 "Configuration setup..."
echo ""
MY_IP=$(echo $SSH_CLIENT | awk '{print $1}')
HOSTNAME=$(hostname)
SERVER_IP_DETECTED=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

ask "Server name [${HOSTNAME}]"
read SERVER_NAME
[ -z "$SERVER_NAME" ] && SERVER_NAME="$HOSTNAME"

ask "Server IP [${SERVER_IP_DETECTED}]"
read SERVER_IP
[ -z "$SERVER_IP" ] && SERVER_IP="$SERVER_IP_DETECTED"

echo ""
info "Telegram Setup (for alerts & reports)"
ask "Bot Token"
read TELEGRAM_BOT_TOKEN

ask "Chat ID"
read TELEGRAM_CHAT_ID

ask "Topic ID (leave blank if none)"
read TELEGRAM_TOPIC_ID

echo ""
info "Alert Thresholds"
ask "Disk alert % [80]"
read DISK_THRESHOLD
[ -z "$DISK_THRESHOLD" ] && DISK_THRESHOLD=80

ask "RAM alert % [90]"
read RAM_THRESHOLD
[ -z "$RAM_THRESHOLD" ] && RAM_THRESHOLD=90

ask "CPU load alert [5]"
read LOAD_THRESHOLD
[ -z "$LOAD_THRESHOLD" ] && LOAD_THRESHOLD=5

ask "Additional IPs to whitelist (space-separated)"
read EXTRA_IPS

WHITELIST_IPS="127.0.0.1 $SERVER_IP $MY_IP $EXTRA_IPS"

cat > "$WHMOS_DIR/config.conf" << CONF
WHMOS_VERSION="${WHMOS_VERSION}"
SERVER_NAME="${SERVER_NAME}"
SERVER_IP="${SERVER_IP}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
TELEGRAM_TOPIC_ID="${TELEGRAM_TOPIC_ID}"
DISK_ALERT_THRESHOLD=${DISK_THRESHOLD}
CPU_ALERT_THRESHOLD=90
RAM_ALERT_THRESHOLD=${RAM_THRESHOLD}
LOAD_ALERT_THRESHOLD=${LOAD_THRESHOLD}
MAIL_QUEUE_ALERT=100
SSL_EXPIRY_ALERT_DAYS=30
SERVICES="httpd mysql php-fpm exim dovecot"
BACKUP_ENABLED=true
DAILY_REPORT_ENABLED=true
WEEKLY_REPORT_ENABLED=true
CONF
ok "Configuration saved"

# Step 5 — Setup fail2ban
step 5 "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << F2B
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 5
ignoreip = $WHITELIST_IPS
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 3
bantime = 86400
F2B
systemctl enable fail2ban --quiet
systemctl restart fail2ban
ok "fail2ban configured and started"

# Step 6 — Setup crons
step 6 "Setting up automated cron jobs..."
(crontab -l 2>/dev/null | grep -v whmos; \
  echo "0 8 * * * /usr/local/bin/whmos daily-report >> /var/log/whmos-report.log 2>&1"; \
  echo "0 9 * * 1 /usr/local/bin/whmos weekly-report >> /var/log/whmos-report.log 2>&1"; \
  echo "*/5 * * * * /usr/local/bin/whmos autoheal >> /var/log/whmos-autoheal.log 2>&1"; \
  echo "0 8 * * * /usr/local/bin/whmos ssl-check >> /var/log/whmos-ssl.log 2>&1"; \
  echo "*/30 * * * * /usr/local/bin/whmos mail-check >> /var/log/whmos-mail.log 2>&1"; \
  echo "*/10 * * * * /usr/local/bin/whmos alert-check >> /var/log/whmos-alerts.log 2>&1" \
) | crontab -
ok "Cron jobs configured"

# Step 7 — SSH login alert
step 7 "Enabling SSH login Telegram alerts..."
cat > /etc/profile.d/whmos-ssh-alert.sh << ALERT
#!/bin/bash
if [ -n "\$SSH_CLIENT" ]; then
  IP=\$(echo \$SSH_CLIENT | awk '{print \$1}')
  USER=\$(whoami)
  source ${WHMOS_DIR}/config.conf 2>/dev/null
  TEXT="🔐 SSH Login Alert%0A━━━━━━━━━━━━━━━━━━%0AServer: \${SERVER_NAME}%0AUser: \${USER}%0AIP: \${IP}%0ATime: \$(date)"
  PAYLOAD="chat_id=\${TELEGRAM_CHAT_ID}&text=\${TEXT}"
  [ -n "\${TELEGRAM_TOPIC_ID}" ] && PAYLOAD="\${PAYLOAD}&message_thread_id=\${TELEGRAM_TOPIC_ID}"
  curl -s "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage" -d "\$PAYLOAD" > /dev/null 2>&1
fi
ALERT
chmod +x /etc/profile.d/whmos-ssh-alert.sh
ok "SSH login alert enabled"

# Done
echo ""
echo -e "${BOLD}${GREEN}  $SEP"
echo "  WHMOS v${WHMOS_VERSION} installed successfully!"
echo -e "  $SEP${NC}"
echo ""
echo "  Run: whmos"
echo ""
echo -e "  ${CYAN}What's set up:${NC}"
echo "  ✔ fail2ban (SSH brute force protection)"
echo "  ✔ Automated daily/weekly Telegram reports"
echo "  ✔ Service auto-heal every 5 minutes"
echo "  ✔ SSL expiry check daily"
echo "  ✔ Mail queue check every 30 minutes"
echo "  ✔ System alert check every 10 minutes"
echo "  ✔ SSH login Telegram alerts"
echo ""
