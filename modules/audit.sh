#!/bin/bash
# WHMOS Audit Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

audit_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  Audit"
    echo "  $SEP"
    echo ""
    echo "    1  SSH Login History"
    echo "    2  Failed SSH Attempts"
    echo "    3  WHM / cPanel Login History"
    echo "    4  Root Command History"
    echo "    5  Cron Job Audit"
    echo "    6  New User Accounts Check"
    echo "    7  SUID/SGID Files Check"
    echo "    8  Enable SSH Login Telegram Alert"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-8] or b to go back: "
    read choice
    case $choice in
      1) audit_ssh_logins ;;
      2) audit_ssh_failed ;;
      3) audit_whm_logins ;;
      4) audit_root_history ;;
      5) audit_cron ;;
      6) audit_users ;;
      7) audit_suid ;;
      8) audit_ssh_alert ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

audit_ssh_logins() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  SSH Login History"
  echo "  $SEP"
  echo ""
  last | head -30 | while read line; do
    echo "  $line"
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

audit_ssh_failed() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Failed SSH Attempts (Last 24h)"
  echo "  $SEP"
  echo ""
  printf "  %-20s %-15s %-20s\n" "TIME" "IP" "USER"
  echo "  $SEP"
  journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep "Failed password\|Invalid user" | \
  awk '{
    for(i=1;i<=NF;i++) {
      if($i=="user") user=$(i+1)
      if($i=="from") ip=$(i+1)
    }
    printf "  %-20s %-15s %-20s\n", $1" "$2" "$3, ip, user
  }' | head -40
  echo ""
  TOTAL=$(journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep -c "Failed password\|Invalid user")
  echo "  Total failed attempts (24h): $TOTAL"
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

audit_whm_logins() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  WHM/cPanel Login History"
  echo "  $SEP"
  echo ""
  if [ -f /usr/local/cpanel/logs/access_log ]; then
    grep "login" /usr/local/cpanel/logs/access_log 2>/dev/null | tail -30 | while read line; do
      echo "  $line"
    done
  fi
  echo ""
  if [ -f /var/log/WHM-access_log ]; then
    tail -20 /var/log/WHM-access_log | while read line; do
      echo "  $line"
    done
  fi
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

audit_root_history() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Root Command History"
  echo "  $SEP"
  echo ""
  if [ -f /root/.bash_history ]; then
    tail -50 /root/.bash_history | nl | while read n line; do
      echo "  $n  $line"
    done
  else
    echo "  No history found."
  fi
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

audit_cron() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Cron Job Audit"
  echo "  $SEP"
  echo ""
  echo "  System crontabs:"
  echo "  $SEP"
  for f in /etc/cron.d/* /etc/crontab; do
    [ -f "$f" ] && echo "  [$f]" && cat "$f" | grep -v "^#\|^$" | while read line; do echo "    $line"; done
  done
  echo ""
  echo "  User crontabs:"
  echo "  $SEP"
  for user in $(cut -d: -f1 /etc/passwd); do
    CRON=$(crontab -u $user -l 2>/dev/null | grep -v "^#\|^$")
    [ -n "$CRON" ] && echo "  [$user]" && echo "$CRON" | while read line; do echo "    $line"; done
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

audit_users() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  User Accounts"
  echo "  $SEP"
  echo ""
  printf "  %-20s %-8s %-30s\n" "USERNAME" "UID" "SHELL"
  echo "  $SEP"
  awk -F: '$3 >= 1000 && $3 != 65534 {printf "  %-20s %-8s %-30s\n", $1, $3, $7}' /etc/passwd
  echo ""
  echo "  Users with sudo/root access:"
  echo "  $SEP"
  grep -Po '^sudo.+:\K.*$' /etc/group | tr ',' '\n' | while read u; do echo "  $u"; done
  grep -v "^#" /etc/sudoers 2>/dev/null | grep -v "^$" | while read line; do echo "  $line"; done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

audit_suid() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  SUID/SGID Files"
  echo "  $SEP"
  echo "  Scanning... (this may take a moment)"
  echo ""
  find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | while read f; do
    echo "  $f"
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

audit_ssh_alert() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  SSH Login Telegram Alert"
  echo "  $SEP"
  echo ""
  ALERT_SCRIPT="/etc/profile.d/whmos-ssh-alert.sh"
  if [ -f "$ALERT_SCRIPT" ]; then
    echo "  SSH login alert is already enabled."
  else
    cat > "$ALERT_SCRIPT" << ALERT
#!/bin/bash
if [ -n "\$SSH_CLIENT" ]; then
  IP=\$(echo \$SSH_CLIENT | awk '{print \$1}')
  USER=\$(whoami)
  source /usr/local/bin/../whmos/config.conf 2>/dev/null
  TEXT="🔐 SSH Login Alert%0A━━━━━━━━━━━━━━━━━━%0AServer: \${SERVER_NAME}%0AUser: \${USER}%0AIP: \${IP}%0ATime: \$(date)"
  curl -s "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=\${TELEGRAM_CHAT_ID}&message_thread_id=\${TELEGRAM_TOPIC_ID}&text=\${TEXT}" > /dev/null 2>&1
fi
ALERT
    chmod +x "$ALERT_SCRIPT"
    echo "  SSH login Telegram alert enabled."
    echo "  Every SSH login will now send a Telegram notification."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
