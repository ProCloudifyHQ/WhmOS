#!/bin/bash
# WHMOS Security Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  Security"
    echo "  $SEP"
    echo ""
    echo "  FAIL2BAN"
    echo "    1  View Blocked IPs"
    echo "    2  Whitelist an IP"
    echo "    3  Unban an IP"
    echo "    4  Manually Ban an IP"
    echo ""
    echo "  FIREWALL"
    echo "    5  View iptables Rules"
    echo "    6  Open Port Scanner"
    echo ""
    echo "  MALWARE & ROOTKIT"
    echo "    7  Run ClamAV Scan"
    echo "    8  Run Rootkit Check (rkhunter)"
    echo "    9  Run chkrootkit"
    echo "   10  File Integrity Check (AIDE)"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-10] or b to go back: "
    read choice
    case $choice in
      1) sec_banned ;;
      2) sec_whitelist_add ;;
      3) sec_unban ;;
      4) sec_ban ;;
      5) sec_iptables ;;
      6) sec_ports ;;
      7) sec_clamav ;;
      8) sec_rkhunter ;;
      9) sec_chkrootkit ;;
     10) sec_aide ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

sec_banned() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Blocked IPs"
  echo "  $SEP"
  printf "\n  %-22s %-12s %-12s %-10s\n" "IP ADDRESS" "PACKETS" "BYTES" "STATUS"
  echo "  $SEP"
  COUNT=$(iptables -nvL f2b-sshd 2>/dev/null | grep -c REJECT)
  if [ "$COUNT" -eq 0 ]; then
    echo "  No IPs currently blocked."
  else
    iptables -nvL f2b-sshd 2>/dev/null | grep REJECT | while read pkts bytes target prot opt in out src dst rest; do
      printf "  %-22s %-12s %-12s %-10s\n" "$src" "$pkts" "$bytes" "BLOCKED"
    done
  fi
  echo "  $SEP"
  echo "  Currently Banned : $(fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | awk '{print $NF}')"
  echo "  Total Banned Ever: $(fail2ban-client status sshd 2>/dev/null | grep 'Total banned' | awk '{print $NF}')"
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_whitelist_add() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Add IP to Whitelist"
  echo "  $SEP"
  echo -n "  Enter IP to whitelist: "
  read IP
  [ -z "$IP" ] && echo "  Cancelled." && sleep 1 && return
  current=$(grep 'ignoreip' /etc/fail2ban/jail.local | sed 's/ignoreip = //')
  if echo "$current" | grep -q "$IP"; then
    echo "  IP $IP is already whitelisted."
  else
    sed -i "s|ignoreip = $current|ignoreip = $current $IP|" /etc/fail2ban/jail.local
    systemctl restart fail2ban
    echo "  IP $IP added to whitelist."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_unban() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Unban an IP"
  echo "  $SEP"
  echo "  Currently banned:"
  iptables -nvL f2b-sshd 2>/dev/null | grep REJECT | awk '{print "    " $8}'
  echo ""
  echo -n "  Enter IP to unban: "
  read IP
  [ -z "$IP" ] && echo "  Cancelled." && sleep 1 && return
  fail2ban-client set sshd unbanip $IP
  echo "  IP $IP has been unbanned."
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_ban() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Manually Ban an IP"
  echo "  $SEP"
  echo -n "  Enter IP to ban: "
  read IP
  [ -z "$IP" ] && echo "  Cancelled." && sleep 1 && return
  fail2ban-client set sshd banip $IP
  send_telegram "warning" "IP Manually Banned" "IP <code>$IP</code> was manually banned via WHMOS."
  echo "  IP $IP has been banned."
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_iptables() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  iptables Rules"
  echo "  $SEP"
  iptables -nvL
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_ports() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Open Ports"
  echo "  $SEP"
  ss -tlnp | awk 'NR==1 || /LISTEN/'
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_clamav() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  ClamAV Malware Scan"
  echo "  $SEP"
  if ! command -v clamscan &>/dev/null; then
    echo "  ClamAV not installed."
    echo -n "  Install now? [y/n]: "
    read ans
    if [ "$ans" = "y" ]; then
      dnf install clamav clamd clamav-update -y
      freshclam
    else
      echo -n "  Press [ENTER] to return..." && read && return
    fi
  fi
  echo "  Updating virus definitions..."
  freshclam --quiet
  echo "  Scanning /home (this may take a while)..."
  clamscan -r /home --infected --quiet 2>/dev/null | tee /tmp/whmos_clamav.log
  FOUND=$(grep -c "FOUND" /tmp/whmos_clamav.log 2>/dev/null || echo 0)
  if [ "$FOUND" -gt 0 ]; then
    send_telegram "critical" "Malware Detected" "ClamAV found <b>$FOUND infected file(s)</b> on $SERVER_NAME.\n\n$(cat /tmp/whmos_clamav.log)"
    echo "  ALERT: $FOUND infected file(s) found. Telegram alert sent."
  else
    echo "  Scan complete. No threats found."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_rkhunter() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Rootkit Hunter"
  echo "  $SEP"
  if ! command -v rkhunter &>/dev/null; then
    echo "  rkhunter not installed."
    echo -n "  Install now? [y/n]: "
    read ans
    [ "$ans" = "y" ] && dnf install rkhunter -y || { echo -n "  Press [ENTER]..." && read && return; }
  fi
  rkhunter --update --quiet
  rkhunter --check --skip-keypress --quiet 2>/dev/null | tee /tmp/whmos_rkhunter.log
  WARNINGS=$(grep -c "Warning" /tmp/whmos_rkhunter.log 2>/dev/null || echo 0)
  if [ "$WARNINGS" -gt 0 ]; then
    send_telegram "critical" "Rootkit Warning" "rkhunter found <b>$WARNINGS warning(s)</b> on $SERVER_NAME."
    echo "  ALERT: $WARNINGS warning(s) found. Telegram alert sent."
  else
    echo "  Scan complete. No threats found."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_chkrootkit() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  chkrootkit"
  echo "  $SEP"
  if ! command -v chkrootkit &>/dev/null; then
    echo "  chkrootkit not installed."
    echo -n "  Install now? [y/n]: "
    read ans
    [ "$ans" = "y" ] && dnf install chkrootkit -y || { echo -n "  Press [ENTER]..." && read && return; }
  fi
  chkrootkit 2>/dev/null | grep -v "^$" | tee /tmp/whmos_chkrootkit.log
  INFECTED=$(grep -i "infected" /tmp/whmos_chkrootkit.log | grep -v "not infected" | wc -l)
  if [ "$INFECTED" -gt 0 ]; then
    send_telegram "critical" "Rootkit Detected" "chkrootkit found <b>$INFECTED issue(s)</b> on $SERVER_NAME."
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}

sec_aide() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  File Integrity Check (AIDE)"
  echo "  $SEP"
  if ! command -v aide &>/dev/null; then
    echo "  AIDE not installed."
    echo -n "  Install now? [y/n]: "
    read ans
    if [ "$ans" = "y" ]; then
      dnf install aide -y
      aide --init
      mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
      echo "  AIDE database initialized."
    else
      echo -n "  Press [ENTER]..." && read && return
    fi
  else
    aide --check 2>/dev/null | tee /tmp/whmos_aide.log
    CHANGES=$(grep -c "changed\|added\|removed" /tmp/whmos_aide.log 2>/dev/null || echo 0)
    if [ "$CHANGES" -gt 0 ]; then
      send_telegram "warning" "File Integrity Alert" "AIDE detected <b>$CHANGES file change(s)</b> on $SERVER_NAME."
      echo "  ALERT: $CHANGES change(s) detected. Telegram alert sent."
    else
      echo "  File integrity check passed. No changes detected."
    fi
  fi
  echo ""
  echo -n "  Press [ENTER] to return..."
  read
}
