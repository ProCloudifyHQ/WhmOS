#!/bin/bash
# WHMOS SSL Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ssl_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  SSL Expiry"
    echo "  $SEP"
    echo ""
    echo "    1  Check All Domain SSLs"
    echo "    2  Check Single Domain"
    echo "    3  Enable Daily SSL Alert Cron"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-3] or b to go back: "
    read choice
    case $choice in
      1) ssl_check_all ;;
      2) ssl_check_single ;;
      3) ssl_cron ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

ssl_check_domain() {
  local DOMAIN="$1"
  local EXPIRY
  EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
           openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -z "$EXPIRY" ]; then
    echo "ERROR"
    return
  fi
  EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null)
  NOW_EPOCH=$(date +%s)
  DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
  echo "$DAYS_LEFT"
}

ssl_check_all() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  SSL Expiry Check"
  echo "  $SEP"
  echo ""
  printf "  %-35s %-12s %-10s\n" "DOMAIN" "DAYS LEFT" "STATUS"
  echo "  $SEP"

  DOMAINS=""
  if [ -d /etc/userdomains ]; then
    DOMAINS=$(cat /etc/userdomains 2>/dev/null | awk '{print $1}' | sed 's/://')
  elif [ -d /var/cpanel/userdata ]; then
    DOMAINS=$(find /var/cpanel/userdata -name "*.cache" 2>/dev/null | xargs grep -h "^main_domain\|^sub_domains" 2>/dev/null | awk '{print $2}')
  fi

  [ -z "$DOMAINS" ] && DOMAINS=$(hostname)

  ALERT_MSG=""
  for domain in $DOMAINS; do
    DAYS=$(ssl_check_domain "$domain")
    if [ "$DAYS" = "ERROR" ]; then
      printf "  %-35s %-12s %-10s\n" "$domain" "N/A" "NO SSL"
    elif [ "$DAYS" -le 0 ] 2>/dev/null; then
      printf "  %-35s %-12s %-10s\n" "$domain" "EXPIRED" "CRITICAL"
      ALERT_MSG="$ALERT_MSG\n$domain — EXPIRED"
    elif [ "$DAYS" -le "${SSL_EXPIRY_ALERT_DAYS:-30}" ] 2>/dev/null; then
      printf "  %-35s %-12s %-10s\n" "$domain" "$DAYS days" "WARNING"
      ALERT_MSG="$ALERT_MSG\n$domain — $DAYS days left"
    else
      printf "  %-35s %-12s %-10s\n" "$domain" "$DAYS days" "OK"
    fi
  done

  if [ -n "$ALERT_MSG" ]; then
    send_telegram "critical" "SSL Expiry Alert" "The following domains need SSL renewal on $SERVER_NAME:$ALERT_MSG"
  fi

  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

ssl_check_single() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Check Single Domain SSL"
  echo "  $SEP"
  echo -n "  Enter domain: "
  read DOMAIN
  [ -z "$DOMAIN" ] && echo "  Cancelled." && sleep 1 && return
  echo ""
  DAYS=$(ssl_check_domain "$DOMAIN")
  if [ "$DAYS" = "ERROR" ]; then
    echo "  Could not retrieve SSL info for $DOMAIN."
  elif [ "$DAYS" -le 0 ] 2>/dev/null; then
    echo "  $DOMAIN SSL is EXPIRED."
  else
    echo "  $DOMAIN SSL expires in: $DAYS days"
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

ssl_cron() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Enable SSL Alert Cron"
  echo "  $SEP"
  echo ""
  CRON_JOB="0 8 * * * /usr/local/bin/whmos ssl-check >> /var/log/whmos-ssl.log 2>&1"
  if crontab -l 2>/dev/null | grep -q "whmos ssl-check"; then
    echo "  SSL alert cron is already enabled."
  else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "  SSL alert cron enabled (runs daily at 8 AM)."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
