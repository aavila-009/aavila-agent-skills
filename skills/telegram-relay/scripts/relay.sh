#!/bin/bash
# Telegram Relay — polls getUpdates and writes messages to inbox
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
OFFSET_FILE="${INBOX_DIR}/.relay-offset"
PID_FILE="${INBOX_DIR}/relay.pid"
POLL_INTERVAL="${POLL_INTERVAL:-5}"

# Write PID for management
echo $$ > "$PID_FILE"

# Initialize offset
if [ -f "$OFFSET_FILE" ]; then
  OFFSET=$(cat "$OFFSET_FILE")
else
  # Get current offset without consuming messages
  INITIAL=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=1&timeout=0" 2>/dev/null)
  OFFSET=$(echo "$INITIAL" | python3 -c "
import sys, json
data = json.load(sys.stdin)
updates = data.get('result', [])
if updates:
    print(updates[-1]['update_id'] + 1)
else:
    print(0)
" 2>/dev/null)
  OFFSET=${OFFSET:-0}
  echo "$OFFSET" > "$OFFSET_FILE"
fi

echo "[$(date)] Telegram relay started. Polling every ${POLL_INTERVAL}s. Offset: ${OFFSET}" >> "$INBOX"

# Cleanup on exit
trap 'rm -f "$PID_FILE"; echo "[$(date)] Relay stopped." >> "$INBOX"' EXIT

while true; do
  curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=4" 2>/dev/null \
    | python3 -c "
import sys, json
from datetime import datetime

data = json.load(sys.stdin)
updates = data.get('result', [])
max_id = int(sys.argv[1])
chat_filter = sys.argv[2]
inbox_path = sys.argv[3]
offset_path = sys.argv[4]

for u in updates:
    uid = u['update_id']
    if uid >= max_id:
        max_id = uid + 1
    msg = u.get('message', {})
    chat_id = str(msg.get('chat', {}).get('id', ''))
    if chat_id == chat_filter:
        text = msg.get('text', '')
        ts = datetime.fromtimestamp(msg.get('date', 0)).strftime('%Y-%m-%d %H:%M:%S')
        sender = msg.get('from', {}).get('first_name', 'Unknown')
        with open(inbox_path, 'a') as f:
            f.write(f'[{ts}] {sender}: {text}\n')

with open(offset_path, 'w') as f:
    f.write(str(max_id))
" "$OFFSET" "$CHAT_ID" "$INBOX" "$OFFSET_FILE" 2>/dev/null

  if [ -f "$OFFSET_FILE" ]; then
    OFFSET=$(cat "$OFFSET_FILE")
  fi

  sleep "$POLL_INTERVAL"
done
