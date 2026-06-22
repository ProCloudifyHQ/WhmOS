#!/bin/bash
# WHMOS Notification Engine — Telegram

WHMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WHMOS_DIR/config.conf" 2>/dev/null

send_telegram() {
  local TYPE="$1"   # info | warning | critical
  local TITLE="$2"
  local MESSAGE="$3"

  if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "  [notify] Telegram not configured." && return 1
  fi

  case "$TYPE" in
    critical) ICON="🔴" ;;
    warning)  ICON="🟡" ;;
    info)     ICON="🟢" ;;
    *)        ICON="⚪" ;;
  esac

  local TEXT="$ICON <b>WHMOS | ${SERVER_NAME}</b>
━━━━━━━━━━━━━━━━━━━━━━━
<b>${TITLE}</b>

${MESSAGE}

<i>$(date '+%Y-%m-%d %H:%M:%S')</i>"

  local PAYLOAD="chat_id=${TELEGRAM_CHAT_ID}&parse_mode=HTML&text=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$TEXT")"

  if [ -n "$TELEGRAM_TOPIC_ID" ]; then
    PAYLOAD="${PAYLOAD}&message_thread_id=${TELEGRAM_TOPIC_ID}"
  fi

  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "$PAYLOAD" > /dev/null 2>&1
}

test_telegram() {
  send_telegram "info" "Test Notification" "WHMOS is connected and working correctly on <b>${SERVER_NAME}</b>."
  echo "  Test message sent to Telegram."
}
