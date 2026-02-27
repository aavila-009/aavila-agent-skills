#!/bin/bash
# SessionStart hook — reads unprocessed Telegram messages for Claude
# Output is injected into session context automatically.
# Managed by the telegram-relay skill.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/telegram-relay"
CONFIG="${SCRIPT_DIR}/config.sh"
[ ! -f "$CONFIG" ] && CONFIG="${SCRIPT_DIR}/../config.sh"
[ ! -f "$CONFIG" ] && CONFIG="${CONFIG_DIR}/config.sh"

# Silent exit if not configured
if [ ! -f "$CONFIG" ]; then
  exit 0
fi

source "$CONFIG"

INBOX="${INBOX_DIR}/inbox.log"
ARCHIE_PROCESSED="${INBOX_DIR}/.archie-processed"

if [ ! -f "$INBOX" ]; then
  exit 0
fi

# Track which line Claude last processed
if [ -f "$ARCHIE_PROCESSED" ]; then
  LAST_LINE=$(cat "$ARCHIE_PROCESSED")
else
  LAST_LINE=0
fi

CURRENT_LINES=$(wc -l < "$INBOX" | tr -d ' ')

if [ "$CURRENT_LINES" -gt "$LAST_LINE" ]; then
  NEW_START=$((LAST_LINE + 1))
  # Filter for actual user messages
  UNREAD=$(tail -n +"$NEW_START" "$INBOX" | grep -E '^\[.*\] [A-Z][a-z]+:' | grep -v 'relay started\|responder started\|stopped')

  if [ -n "$UNREAD" ]; then
    MSG_COUNT=$(echo "$UNREAD" | wc -l | tr -d ' ')
    echo "📬 TELEGRAM INBOX — ${MSG_COUNT} unread message(s):"
    echo "$UNREAD"
    echo ""
    echo "⚡ Respond via: curl -s \"https://api.telegram.org/bot\${BOT_TOKEN}/sendMessage\" -d chat_id=\"\${CHAT_ID}\" --data-urlencode \"text=YOUR RESPONSE\""
    echo "⚡ Then update marker: echo ${CURRENT_LINES} > ${ARCHIE_PROCESSED}"
    echo ""
    echo "Config: source ${CONFIG} for BOT_TOKEN and CHAT_ID values."
  fi
fi
