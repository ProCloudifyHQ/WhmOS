#!/bin/bash
# WHMOS Monitor Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

monitor_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  Monitor"
    echo "  $SEP"
    echo ""
    echo "    1  CPU & Load Average"
    echo "    2  Memory Usage"
    echo "    3  Disk Usage"
    echo "    4  Top Processes"
    echo "    5  Bandwidth & Traffic"
    echo "    6  Network Connections"
    echo "    7  Full System Overview"
    echo "    8  Run Alert Check (send Telegram if threshold exceeded)"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-8] or b to go back: "
    read choice
    case $choice in
      1) mon_cpu ;;
      2) mon_ram ;;
      3) mon_disk ;;
      4) mon_processes ;;
      5) mon_bandwidth ;;
      6) mon_connections ;;
      7) mon_overview ;;
      8) mon_alert_check ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

mon_cpu() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  CPU & Load"
  echo "  $SEP"
  echo ""
  LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
  CORES=$(nproc)
  CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
  echo "  Load Average  : $LOAD"
  echo "  CPU Cores     : $CORES"
  echo "  CPU Usage     : ${CPU_USAGE}%"
  echo "  Uptime        : $(uptime -p)"
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mon_ram() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Memory Usage"
  echo "  $SEP"
  echo ""
  free -h | awk 'NR==1{printf "  %-12s %-10s %-10s %-10s\n", "", $1, $2, $3}
                 NR==2{printf "  %-12s %-10s %-10s %-10s\n", "Memory:", $2, $3, $4}
                 NR==3{printf "  %-12s %-10s %-10s %-10s\n", "Swap:", $2, $3, $4}'
  echo ""
  USED=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}')
  echo "  Usage: ${USED}%"
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mon_disk() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Disk Usage"
  echo "  $SEP"
  echo ""
  printf "  %-20s %-8s %-8s %-8s %-6s\n" "FILESYSTEM" "SIZE" "USED" "AVAIL" "USE%"
  echo "  $SEP"
  df -h | grep -v tmpfs | grep -v udev | tail -n +2 | while read fs size used avail pct mount; do
    PCT=${pct/\%/}
    if [ "$PCT" -ge "${DISK_ALERT_THRESHOLD:-80}" ] 2>/dev/null; then
      printf "  %-20s %-8s %-8s %-8s %-6s  *** HIGH ***\n" "$fs" "$size" "$used" "$avail" "$pct"
    else
      printf "  %-20s %-8s %-8s %-8s %-6s\n" "$fs" "$size" "$used" "$avail" "$pct"
    fi
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mon_processes() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Top Processes"
  echo "  $SEP"
  echo ""
  printf "  %-10s %-8s %-8s %-8s %-20s\n" "PID" "CPU%" "MEM%" "USER" "COMMAND"
  echo "  $SEP"
  ps aux --sort=-%cpu | awk 'NR>1 && NR<=16 {printf "  %-10s %-8s %-8s %-8s %-20s\n", $2, $3, $4, $1, substr($11,1,20)}'
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mon_bandwidth() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Bandwidth & Traffic"
  echo "  $SEP"
  echo ""
  printf "  %-12s %-20s %-20s\n" "INTERFACE" "RX BYTES" "TX BYTES"
  echo "  $SEP"
  cat /proc/net/dev | tail -n +3 | while read iface rest; do
    IFACE=${iface/:/}
    [ "$IFACE" = "lo" ] && continue
    RX=$(echo $rest | awk '{print $1}')
    TX=$(echo $rest | awk '{print $9}')
    RX_MB=$(echo "scale=2; $RX/1048576" | bc 2>/dev/null || echo $RX)
    TX_MB=$(echo "scale=2; $TX/1048576" | bc 2>/dev/null || echo $TX)
    printf "  %-12s %-20s %-20s\n" "$IFACE" "${RX_MB} MB" "${TX_MB} MB"
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mon_connections() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Network Connections"
  echo "  $SEP"
  echo ""
  ss -s
  echo ""
  echo "  $SEP"
  echo "  Top IPs by Connection Count:"
  echo "  $SEP"
  printf "  %-8s %-20s\n" "COUNT" "IP ADDRESS"
  ss -ntu | awk 'NR>1{print $5}' | grep -oP '^\d+\.\d+\.\d+\.\d+' | sort | uniq -c | sort -rn | head -15 | while read cnt ip; do
    printf "  %-8s %-20s\n" "$cnt" "$ip"
  done
  echo ""
  echo "  SYN_RECV (flood indicator): $(ss -nt state syn-recv | wc -l)"
  echo "  ESTABLISHED               : $(ss -nt state established | wc -l)"
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mon_overview() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  System Overview"
  echo "  $SEP"
  echo ""
  LOAD=$(cat /proc/loadavg | awk '{print $1}')
  CORES=$(nproc)
  RAM_USED=$(free -h | awk '/Mem/{print $3}')
  RAM_TOTAL=$(free -h | awk '/Mem/{print $2}')
  RAM_PCT=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}')
  DISK_PCT=$(df / | awk 'NR==2{print $5}')
  UPTIME=$(uptime -p)
  BANNED=$(fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | awk '{print $NF}')
  echo "  Hostname   : $(hostname)"
  echo "  IP Address : ${SERVER_IP}"
  echo "  Uptime     : ${UPTIME}"
  echo ""
  echo "  CPU Load   : ${LOAD} (${CORES} cores)"
  echo "  Memory     : ${RAM_USED} / ${RAM_TOTAL} (${RAM_PCT}%)"
  echo "  Disk (/)   : ${DISK_PCT}"
  echo "  Banned IPs : ${BANNED}"
  echo ""
  echo "  $SEP"
  echo "  Services:"
  for svc in $SERVICES; do
    STATUS=$(systemctl is-active $svc 2>/dev/null)
    printf "  %-20s %s\n" "$svc" "$STATUS"
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

mon_alert_check() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Running Alert Checks..."
  echo "  $SEP"
  echo ""
  ALERTS=""

  # Disk
  df -h | grep -v tmpfs | tail -n +2 | while read fs size used avail pct mount; do
    PCT=${pct/\%/}
    if [ "$PCT" -ge "${DISK_ALERT_THRESHOLD:-80}" ] 2>/dev/null; then
      ALERTS="$ALERTS\nDisk ${mount}: ${pct} used"
      send_telegram "critical" "Disk Space Alert" "Disk <b>${mount}</b> is at <b>${pct}</b> on ${SERVER_NAME}."
      echo "  [ALERT] Disk ${mount} at ${pct}"
    else
      echo "  [OK]    Disk ${mount} at ${pct}"
    fi
  done

  # RAM
  RAM_PCT=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}')
  if [ "$RAM_PCT" -ge "${RAM_ALERT_THRESHOLD:-90}" ]; then
    send_telegram "critical" "Memory Alert" "RAM usage is at <b>${RAM_PCT}%</b> on ${SERVER_NAME}."
    echo "  [ALERT] RAM at ${RAM_PCT}%"
  else
    echo "  [OK]    RAM at ${RAM_PCT}%"
  fi

  # Load
  LOAD=$(cat /proc/loadavg | awk '{print $1}')
  CORES=$(nproc)
  LOAD_INT=$(echo "$LOAD" | cut -d. -f1)
  if [ "$LOAD_INT" -ge "${LOAD_ALERT_THRESHOLD:-5}" ]; then
    send_telegram "warning" "High Load Average" "Load average is <b>${LOAD}</b> on ${SERVER_NAME}."
    echo "  [ALERT] Load at ${LOAD}"
  else
    echo "  [OK]    Load at ${LOAD}"
  fi

  echo ""
  echo "  Alert check complete."
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
