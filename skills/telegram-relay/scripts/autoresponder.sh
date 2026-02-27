#!/bin/bash
# Telegram Auto-Responder — watches inbox for new messages, sends acknowledgments
# Managed by the telegram-relay skill. Do not run directly.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${SCRIPT_DIR}/config.sh"
[ ! -f "$CONFIG" ] && CONFIG="${SCRIPT_DIR}/../config.sh"
[ ! -f "$CONFIG" ] && CONFIG="$HOME/.config/telegram-relay/config.sh"

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: Config not found at $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

INBOX="${INBOX_DIR}/inbox.log"
PROCESSED_FILE="${INBOX_DIR}/.ack-processed"
PID_FILE="${INBOX_DIR}/autoresponder.pid"
ACK_INTERVAL="${ACK_INTERVAL:-10}"

# Write PID for management
echo $$ > "$PID_FILE"

# Initialize processed line counter (start from current end to skip old messages)
if [ -f "$PROCESSED_FILE" ]; then
  LAST_PROCESSED=$(cat "$PROCESSED_FILE")
else
  LAST_PROCESSED=$(wc -l < "$INBOX" 2>/dev/null | tr -d ' ')
  LAST_PROCESSED=${LAST_PROCESSED:-0}
  echo "$LAST_PROCESSED" > "$PROCESSED_FILE"
fi

echo "[$(date)] Auto-responder started. Last processed line: $LAST_PROCESSED" >> "${INBOX_DIR}/autoresponder.log"

# Cleanup on exit
trap 'rm -f "$PID_FILE"; echo "[$(date)] Auto-responder stopped." >> "${INBOX_DIR}/autoresponder.log"' EXIT

while true; do
  if [ ! -f "$INBOX" ]; then
    sleep "$ACK_INTERVAL"
    continue
  fi

  CURRENT_LINES=$(wc -l < "$INBOX" | tr -d ' ')

  if [ "$CURRENT_LINES" -gt "$LAST_PROCESSED" ]; then
    NEW_START=$((LAST_PROCESSED + 1))
    # Filter for actual user messages (not system lines like "relay started")
    NEW_MESSAGES=$(tail -n +"$NEW_START" "$INBOX" | grep -E '^\[.*\] [A-Z][a-z]+:' | grep -v 'relay started\|responder started\|stopped')

    if [ -n "$NEW_MESSAGES" ]; then
      MSG_COUNT=$(echo "$NEW_MESSAGES" | wc -l | tr -d ' ')

      if [ "$MSG_COUNT" -eq 1 ]; then
        ACK_TEXT="✅ Got your message. Claude will process it on the next session start. (Auto-ack)"
      else
        ACK_TEXT="✅ Got your ${MSG_COUNT} messages. Claude will process them on the next session start. (Auto-ack)"
      fi

      curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        --data-urlencode "text=${ACK_TEXT}" > /dev/null 2>&1

      echo "[$(date)] Auto-acked ${MSG_COUNT} message(s)" >> "${INBOX_DIR}/autoresponder.log"
    fi

    LAST_PROCESSED=$CURRENT_LINES
    echo "$LAST_PROCESSED" > "$PROCESSED_FILE"
  fi

  sleep "$ACK_INTERVAL"
done
