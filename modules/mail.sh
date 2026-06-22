#!/bin/bash
# WHMOS Mail Queue Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mail_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  Mail Queue"
    echo "  $SEP"
    echo ""
    echo "    1  Queue Summary"
    echo "    2  Top Senders"
    echo "    3  Queue by Domain"
    echo "    4  Frozen Messages"
    echo "    5  Flush Mail Queue"
    echo "    6  Delete Frozen Messages"
    echo "    7  Enable Queue Alert Cron"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-7] or b to go back: "
    read choice
    case $choice in
      1) mail_summary ;;
      2) mail_top_senders ;;
      3) mail_by_domain ;;
      4) mail_frozen ;;
      5) mail_flush ;;
      6) mail_delete_frozen ;;
      7) mail_cron ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

mail_summary() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Mail Queue Summary"
  echo "  $SEP"
  echo ""
  TOTAL=$(exim -bpc 2>/dev/null || echo 0)
  FROZEN=$(exim -bpr 2>/dev/null | grep -c frozen || echo 0)
  echo "  Total messages in queue : $TOTAL"
  echo "  Frozen messages         : $FROZEN"
  echo ""
  if [ "$TOTAL" -ge "${MAIL_QUEUE_ALERT:-100}" ]; then
    echo "  WARNING: Queue size exceeds threshold (${MAIL_QUEUE_ALERT:-100})!"
    send_telegram "warning" "Mail Queue Alert" "Mail queue has <b>$TOTAL messages</b> on $SERVER_NAME. ($FROZEN frozen)"
  fi
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mail_top_senders() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Top Senders"
  echo "  $SEP"
  echo ""
  printf "  %-8s %-40s\n" "COUNT" "SENDER"
  echo "  $SEP"
  exim -bpr 2>/dev/null | grep "<" | awk '{print $4}' | sort | uniq -c | sort -rn | head -20 | \
  while read cnt sender; do
    printf "  %-8s %-40s\n" "$cnt" "$sender"
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mail_by_domain() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Queue by Domain"
  echo "  $SEP"
  echo ""
  printf "  %-8s %-40s\n" "COUNT" "DOMAIN"
  echo "  $SEP"
  exim -bpr 2>/dev/null | grep "<" | awk '{print $4}' | awk -F@ '{print $2}' | tr -d '>' | \
  sort | uniq -c | sort -rn | head -20 | \
  while read cnt domain; do
    printf "  %-8s %-40s\n" "$cnt" "$domain"
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mail_frozen() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Frozen Messages"
  echo "  $SEP"
  echo ""
  exim -bpr 2>/dev/null | grep frozen | head -30 | while read line; do
    echo "  $line"
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mail_flush() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Flush Mail Queue"
  echo "  $SEP"
  echo -n "  Confirm flush entire queue? [y/n]: "
  read confirm
  [ "$confirm" != "y" ] && echo "  Cancelled." && sleep 1 && return
  exim -qf 2>/dev/null
  echo "  Mail queue flushed."
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

mail_delete_frozen() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Delete Frozen Messages"
  echo "  $SEP"
  FROZEN=$(exim -bpr 2>/dev/null | grep -c frozen)
  echo "  Frozen messages: $FROZEN"
  echo -n "  Confirm delete all frozen messages? [y/n]: "
  read confirm
  [ "$confirm" != "y" ] && echo "  Cancelled." && sleep 1 && return
  exim -bpr 2>/dev/null | grep frozen | awk '{print $3}' | xargs exim -Mrm 2>/dev/null
  echo "  Frozen messages deleted."
  send_telegram "info" "Frozen Mail Cleared" "<b>$FROZEN frozen messages</b> were deleted from the mail queue on $SERVER_NAME."
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

mail_cron() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Enable Queue Alert Cron"
  echo "  $SEP"
  echo ""
  CRON_JOB="*/30 * * * * /usr/local/bin/whmos mail-check >> /var/log/whmos-mail.log 2>&1"
  if crontab -l 2>/dev/null | grep -q "whmos mail-check"; then
    echo "  Mail queue alert cron is already enabled."
  else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "  Mail queue cron enabled (checks every 30 minutes)."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
