#!/bin/bash
# WHMOS WordPress Scanner Module

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null
source "$WHMOS_DIR/modules/notify.sh"

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

wordpress_menu() {
  while true; do
    clear
    echo ""
    echo "  $SEP"
    echo "  WHMOS  v${WHMOS_VERSION}  —  WordPress Scanner"
    echo "  $SEP"
    echo ""
    echo "    1  Find All WP Installations"
    echo "    2  Check WP Core Versions"
    echo "    3  Check Outdated Plugins"
    echo "    4  Check File Permissions"
    echo "    5  Scan for Suspicious Files"
    echo ""
    echo "  $SEP"
    echo -n "  Select [1-5] or b to go back: "
    read choice
    case $choice in
      1) wp_find ;;
      2) wp_versions ;;
      3) wp_plugins ;;
      4) wp_permissions ;;
      5) wp_suspicious ;;
      b|B) break ;;
      *) echo "  Invalid option." ; sleep 1 ;;
    esac
  done
}

wp_find() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  WordPress Installations"
  echo "  $SEP"
  echo "  Scanning /home... (may take a moment)"
  echo ""
  find /home -name "wp-config.php" 2>/dev/null | while read f; do
    DIR=$(dirname "$f")
    OWNER=$(stat -c '%U' "$f" 2>/dev/null)
    echo "  Path  : $DIR"
    echo "  Owner : $OWNER"
    echo ""
  done
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

wp_versions() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  WordPress Core Versions"
  echo "  $SEP"
  echo ""
  printf "  %-40s %-10s %-20s\n" "PATH" "VERSION" "OWNER"
  echo "  $SEP"
  LATEST=$(curl -s "https://api.wordpress.org/core/version-check/1.7/" 2>/dev/null | grep -o '"current":"[^"]*"' | cut -d'"' -f4)
  [ -z "$LATEST" ] && LATEST="unknown"
  OUTDATED=0
  find /home -name "wp-includes/version.php" 2>/dev/null | while read f; do
    VERSION=$(grep "\$wp_version" "$f" 2>/dev/null | head -1 | cut -d"'" -f2)
    DIR=$(echo "$f" | sed 's|/wp-includes/version.php||')
    OWNER=$(stat -c '%U' "$f" 2>/dev/null)
    if [ "$VERSION" = "$LATEST" ]; then
      printf "  %-40s %-10s %-20s\n" "${DIR:0:40}" "$VERSION" "$OWNER"
    else
      printf "  %-40s %-10s %-20s  OUTDATED (latest: $LATEST)\n" "${DIR:0:40}" "$VERSION" "$OWNER"
      OUTDATED=$((OUTDATED+1))
    fi
  done
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

wp_plugins() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  WordPress Plugins Check"
  echo "  $SEP"
  echo ""
  if ! command -v wp &>/dev/null; then
    echo "  WP-CLI not installed. Installing..."
    curl -s -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar 2>/dev/null
    chmod +x /usr/local/bin/wp
  fi
  find /home -name "wp-config.php" 2>/dev/null | while read f; do
    DIR=$(dirname "$f")
    OWNER=$(stat -c '%U' "$f" 2>/dev/null)
    echo "  $DIR ($OWNER)"
    echo "  $SEP"
    su -s /bin/bash "$OWNER" -c "wp plugin list --path='$DIR' --update=available --format=table 2>/dev/null" | \
    while read line; do echo "    $line"; done
    echo ""
  done
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

wp_permissions() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  WP File Permissions Check"
  echo "  $SEP"
  echo ""
  find /home -name "wp-config.php" 2>/dev/null | while read f; do
    DIR=$(dirname "$f")
    echo "  $DIR"
    PERM=$(stat -c '%a' "$f")
    if [ "$PERM" -gt 640 ] 2>/dev/null; then
      echo "    wp-config.php: $PERM  WARNING - should be 640 or less"
    else
      echo "    wp-config.php: $PERM  OK"
    fi
    echo ""
  done
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}

wp_suspicious() {
  clear
  echo ""
  echo "  $SEP"
  echo "  WHMOS  —  Suspicious File Scan"
  echo "  $SEP"
  echo "  Scanning for suspicious PHP files in WP directories..."
  echo ""
  FOUND=0
  find /home -name "wp-config.php" 2>/dev/null | while read f; do
    DIR=$(dirname "$f")
    find "$DIR" -name "*.php" 2>/dev/null | xargs grep -l "base64_decode\|eval.*base64\|str_rot13\|gzinflate\|preg_replace.*\/e" 2>/dev/null | \
    while read suspicious; do
      echo "  SUSPICIOUS: $suspicious"
      FOUND=$((FOUND+1))
    done
  done
  if [ "$FOUND" -eq 0 ]; then
    echo "  No suspicious files found."
  else
    send_telegram "critical" "Suspicious WP Files" "<b>$FOUND suspicious PHP file(s)</b> found in WordPress directories on $SERVER_NAME."
  fi
  echo ""
  echo "  $SEP"
  echo -n "  Press [ENTER] to return..."
  read
}
