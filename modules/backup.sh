#!/bin/bash
# WHMOS Backup Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

backup_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  Backup Status"
    echo "  $SEP"
    echo ""
    echo "    1  JetBackup Status"
    echo "    2  Recent Backup Jobs"
    echo "    3  Backup Disk Usage"
    echo "    4  cPanel Backup Status"
    echo "    5  Check Backup Alert"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-5] or b to go back: "
    read choice
    case $choice in
      1) backup_jetbackup ;;
      2) backup_recent ;;
      3) backup_disk ;;
      4) backup_cpanel ;;
      5) backup_alert ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

backup_jetbackup() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  JetBackup Status"
  echo "  $SEP"
  echo ""
  if ! command -v jetbackup5 &>/dev/null && ! command -v jetbackup &>/dev/null; then
    echo "  JetBackup is not installed."
    echo ""
    echo -n "  Press [ENTER] to return..."
    read
    return
  fi
  systemctl status jetbackup5d 2>/dev/null | head -10 | while read line; do echo "  $line"; done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

backup_recent() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Recent Backup Jobs"
  echo "  $SEP"
  echo ""
  BACKUP_LOG="/var/log/jetbackup5/jetbackup.log"
  CPANEL_LOG="/usr/local/cpanel/logs/cpbackup"

  if [ -f "$BACKUP_LOG" ]; then
    echo "  JetBackup recent jobs:"
    tail -30 "$BACKUP_LOG" | grep -E "success|fail|error|complete|start" | \
    while read line; do echo "  $line"; done
  elif [ -f "$CPANEL_LOG" ]; then
    echo "  cPanel backup recent jobs:"
    ls -lt "$CPANEL_LOG"* 2>/dev/null | head -10 | while read line; do echo "  $line"; done
  else
    echo "  No backup logs found."
  fi
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

backup_disk() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Backup Disk Usage"
  echo "  $SEP"
  echo ""
  BACKUP_DIRS="/backup /home/backup /var/backup /usr/local/cpanel/backup"
  for dir in $BACKUP_DIRS; do
    if [ -d "$dir" ]; then
      SIZE=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
      echo "  $dir : $SIZE"
    fi
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

backup_cpanel() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  cPanel Backup Status"
  echo "  $SEP"
  echo ""
  if [ -f /var/cpanel/backups/config ]; then
    grep -E "BACKUPENABLE|BACKUPDIR|BACKUPTYPE|BACKUPDAYS" /var/cpanel/backups/config 2>/dev/null | \
    while read line; do echo "  $line"; done
  else
    echo "  cPanel backup config not found."
  fi
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

backup_alert() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Backup Alert Check"
  echo "  $SEP"
  echo ""
  BACKUP_LOG="/var/log/jetbackup5/jetbackup.log"
  if [ -f "$BACKUP_LOG" ]; then
    FAILURES=$(grep -c -i "fail\|error" "$BACKUP_LOG" 2>/dev/null || echo 0)
    if [ "$FAILURES" -gt 0 ]; then
      echo "  WARNING: $FAILURES backup failure(s) detected."
      send_telegram "critical" "Backup Failure Alert" "<b>$FAILURES backup failure(s)</b> detected on $SERVER_NAME. Check JetBackup logs."
    else
      echo "  Backup logs look healthy. No failures found."
    fi
  else
    echo "  No backup log found to check."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
