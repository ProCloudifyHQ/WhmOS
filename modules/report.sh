#!/bin/bash
# WHMOS Report Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

report_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  Reports"
    echo "  $SEP"
    echo ""
    echo "    1  Send Daily Report Now"
    echo "    2  Send Weekly Summary Now"
    echo "    3  Enable Daily Report Cron"
    echo "    4  Enable Weekly Report Cron"
    echo "    5  View Last Report"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-5] or b to go back: "
    read choice
    case $choice in
      1) report_daily ;;
      2) report_weekly ;;
      3) report_cron_daily ;;
      4) report_cron_weekly ;;
      5) report_view_last ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

generate_daily_report() {
  LOAD=$(cat /proc/loadavg | awk '{print $1}')
  RAM_PCT=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}')
  RAM_USED=$(free -h | awk '/Mem/{print $3}')
  RAM_TOTAL=$(free -h | awk '/Mem/{print $2}')
  DISK_PCT=$(df / | awk 'NR==2{print $5}')
  DISK_USED=$(df -h / | awk 'NR==2{print $3}')
  DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
  BANNED=$(fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | awk '{print $NF}')
  TOTAL_BANNED=$(fail2ban-client status sshd 2>/dev/null | grep 'Total banned' | awk '{print $NF}')
  SSH_FAILS=$(journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep -c "Failed password\|Invalid user" || echo 0)
  MAIL_QUEUE=$(exim -bpc 2>/dev/null || echo "N/A")
  UPTIME=$(uptime -p)

  # Service status
  SVC_STATUS=""
  for svc in $SERVICES; do
    STATUS=$(systemctl is-active $svc 2>/dev/null)
    if [ "$STATUS" = "active" ]; then
      SVC_STATUS="$SVC_STATUS\n✅ $svc"
    else
      SVC_STATUS="$SVC_STATUS\n🔴 $svc (DOWN)"
    fi
  done

  cat << REPORT
📊 <b>Daily Server Report</b>
━━━━━━━━━━━━━━━━━━━━━━━
🖥 <b>${SERVER_NAME}</b>
📅 $(date '+%Y-%m-%d %H:%M')

<b>System</b>
• Uptime   : ${UPTIME}
• Load     : ${LOAD}
• Memory   : ${RAM_USED} / ${RAM_TOTAL} (${RAM_PCT}%)
• Disk (/) : ${DISK_USED} / ${DISK_TOTAL} (${DISK_PCT})

<b>Security</b>
• Banned Now    : ${BANNED}
• Total Banned  : ${TOTAL_BANNED}
• SSH Failures  : ${SSH_FAILS} (24h)

<b>Mail</b>
• Queue Size : ${MAIL_QUEUE}

<b>Services</b>$(echo -e "$SVC_STATUS")
REPORT
}

report_daily() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Sending Daily Report..."
  echo "  $SEP"
  echo ""
  REPORT=$(generate_daily_report)
  echo "$REPORT" > /var/log/whmos-last-report.log

  if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "  Telegram not configured. Report saved to /var/log/whmos-last-report.log"
  else
    TEXT=$(echo "$REPORT")
    PAYLOAD="chat_id=${TELEGRAM_CHAT_ID}&parse_mode=HTML&text=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$TEXT")"
    [ -n "$TELEGRAM_TOPIC_ID" ] && PAYLOAD="${PAYLOAD}&message_thread_id=${TELEGRAM_TOPIC_ID}"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -d "$PAYLOAD" > /dev/null
    echo "  Daily report sent to Telegram."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

report_weekly() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Sending Weekly Summary..."
  echo "  $SEP"
  echo ""
  TOTAL_BANNED=$(fail2ban-client status sshd 2>/dev/null | grep 'Total banned' | awk '{print $NF}')
  SSH_FAILS=$(journalctl -u sshd --since "7 days ago" 2>/dev/null | grep -c "Failed password\|Invalid user" || echo 0)
  DISK_PCT=$(df / | awk 'NR==2{print $5}')

  REPORT="📈 <b>Weekly Server Summary</b>
━━━━━━━━━━━━━━━━━━━━━━━
🖥 <b>${SERVER_NAME}</b>
📅 Week ending $(date '+%Y-%m-%d')

<b>Security (7 days)</b>
• Total IPs Banned  : ${TOTAL_BANNED}
• SSH Failed Logins : ${SSH_FAILS}

<b>Resources</b>
• Disk Usage (/)    : ${DISK_PCT}
• Uptime            : $(uptime -p)"

  TEXT="$REPORT"
  PAYLOAD="chat_id=${TELEGRAM_CHAT_ID}&parse_mode=HTML&text=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$TEXT")"
  [ -n "$TELEGRAM_TOPIC_ID" ] && PAYLOAD="${PAYLOAD}&message_thread_id=${TELEGRAM_TOPIC_ID}"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -d "$PAYLOAD" > /dev/null
  echo "  Weekly summary sent to Telegram."
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

report_cron_daily() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Enable Daily Report Cron"
  echo "  $SEP"
  echo ""
  CRON_JOB="0 8 * * * /usr/local/bin/whmos daily-report >> /var/log/whmos-report.log 2>&1"
  if crontab -l 2>/dev/null | grep -q "whmos daily-report"; then
    echo "  Daily report cron is already enabled."
  else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "  Daily report cron enabled (runs every day at 8 AM)."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

report_cron_weekly() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Enable Weekly Report Cron"
  echo "  $SEP"
  echo ""
  CRON_JOB="0 9 * * 1 /usr/local/bin/whmos weekly-report >> /var/log/whmos-report.log 2>&1"
  if crontab -l 2>/dev/null | grep -q "whmos weekly-report"; then
    echo "  Weekly report cron is already enabled."
  else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "  Weekly report cron enabled (runs every Monday at 9 AM)."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

report_view_last() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Last Report"
  echo "  $SEP"
  echo ""
  if [ -f /var/log/whmos-last-report.log ]; then
    cat /var/log/whmos-last-report.log | while read line; do echo "  $line"; done
  else
    echo "  No report has been generated yet."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
