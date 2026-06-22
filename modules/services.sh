#!/bin/bash
# WHMOS Services Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

services_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  Services"
    echo "  $SEP"
    echo ""
    echo "    1  Service Status Overview"
    echo "    2  Restart a Service"
    echo "    3  Stop a Service"
    echo "    4  Start a Service"
    echo "    5  Auto-Heal Check (restart if down)"
    echo "    6  Enable Auto-Heal via Cron"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-6] or b to go back: "
    read choice
    case $choice in
      1) svc_status ;;
      2) svc_restart ;;
      3) svc_stop ;;
      4) svc_start ;;
      5) svc_autoheal ;;
      6) svc_cron ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

svc_status() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Service Status"
  echo "  $SEP"
  echo ""
  printf "  %-25s %-12s %-10s\n" "SERVICE" "STATUS" "PID"
  echo "  $SEP"
  ALL_SERVICES="httpd nginx mysql mariadb php-fpm exim dovecot named pure-ftpd cpsrvd cpanel whostmgrd"
  for svc in $ALL_SERVICES; do
    STATUS=$(systemctl is-active $svc 2>/dev/null)
    [ "$STATUS" = "inactive" ] || [ -z "$STATUS" ] && STATUS="stopped"
    PID=$(systemctl show $svc --property=MainPID 2>/dev/null | cut -d= -f2)
    [ "$PID" = "0" ] && PID="-"
    if [ "$STATUS" = "active" ]; then
      printf "  %-25s %-12s %-10s\n" "$svc" "running" "$PID"
    else
      printf "  %-25s %-12s %-10s\n" "$svc" "STOPPED" "-"
    fi
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

svc_restart() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Restart Service"
  echo "  $SEP"
  echo -n "  Service name (e.g. httpd, mysql, exim): "
  read SVC
  [ -z "$SVC" ] && echo "  Cancelled." && sleep 1 && return
  echo "  Restarting $SVC..."
  systemctl restart $SVC
  STATUS=$(systemctl is-active $SVC)
  echo "  Status: $STATUS"
  send_telegram "info" "Service Restarted" "<b>$SVC</b> was restarted on $SERVER_NAME. Status: $STATUS"
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

svc_stop() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Stop Service"
  echo "  $SEP"
  echo -n "  Service name to stop: "
  read SVC
  [ -z "$SVC" ] && echo "  Cancelled." && sleep 1 && return
  echo -n "  Confirm stop $SVC? [y/n]: "
  read confirm
  [ "$confirm" != "y" ] && echo "  Cancelled." && sleep 1 && return
  systemctl stop $SVC
  send_telegram "warning" "Service Stopped" "<b>$SVC</b> was manually stopped on $SERVER_NAME."
  echo "  $SVC stopped."
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

svc_start() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Start Service"
  echo "  $SEP"
  echo -n "  Service name to start: "
  read SVC
  [ -z "$SVC" ] && echo "  Cancelled." && sleep 1 && return
  systemctl start $SVC
  STATUS=$(systemctl is-active $SVC)
  echo "  $SVC status: $STATUS"
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

svc_autoheal() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Auto-Heal Check"
  echo "  $SEP"
  echo ""
  for svc in $SERVICES; do
    STATUS=$(systemctl is-active $svc 2>/dev/null)
    if [ "$STATUS" != "active" ]; then
      echo "  [DOWN] $svc — attempting restart..."
      systemctl restart $svc
      sleep 2
      NEW_STATUS=$(systemctl is-active $svc 2>/dev/null)
      if [ "$NEW_STATUS" = "active" ]; then
        echo "  [RECOVERED] $svc is back online."
        send_telegram "warning" "Service Auto-Healed" "<b>$svc</b> was down and has been automatically restarted on $SERVER_NAME."
      else
        echo "  [FAILED] $svc could not be restarted!"
        send_telegram "critical" "Service Down" "<b>$svc</b> is DOWN and could not be restarted on $SERVER_NAME. Manual intervention required."
      fi
    else
      echo "  [OK]   $svc is running."
    fi
  done
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

svc_cron() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Enable Auto-Heal via Cron"
  echo "  $SEP"
  echo ""
  CRON_JOB="*/5 * * * * /usr/local/bin/whmos autoheal >> /var/log/whmos-autoheal.log 2>&1"
  if crontab -l 2>/dev/null | grep -q "whmos autoheal"; then
    echo "  Auto-heal cron is already enabled."
  else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "  Auto-heal cron enabled (runs every 5 minutes)."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
