---
name: telegram-relay
description: >-
  Bidirectional Telegram messaging for Claude Code sessions. Use this skill when
  the user says "start telegram", "set up telegram", "telegram relay", "check
  telegram", "stop telegram", "read my messages", or wants to communicate via
  Telegram between sessions. Also use when the user wants to receive notifications
  or send messages through a Telegram bot, or when they mention wanting to
  communicate "on the go" or "from my phone" with Claude Code. This skill manages
  a background relay that captures incoming Telegram messages, auto-acknowledges
  them, and injects unread messages into every new session via a SessionStart hook.
---

# Telegram Relay

A three-layer system that gives Claude Code bidirectional Telegram messaging:

1. **Relay** — Background script that polls Telegram's `getUpdates` API and writes incoming messages to a local inbox file.
2. **Auto-Responder** — Background script that watches the inbox and sends instant "✅ received" acknowledgments so the sender always knows their message arrived.
3. **SessionStart Hook** — Automatically injects unread messages into Claude's context at the start of every session, so Claude sees and responds to them without being asked.

## Why three layers?

Claude Code is request-response — it can't be "woken up" by external events. The relay captures messages continuously. The auto-responder provides instant feedback to the sender. The SessionStart hook bridges the gap by surfacing unread messages whenever a new session begins. Together, they create the experience of async communication even though Claude only processes messages at session boundaries.

## Commands

### `/telegram-relay start`

Sets up and starts all three layers. On first run, prompts for configuration (bot token + chat ID). On subsequent runs, reads existing config.

### `/telegram-relay stop`

Stops the relay and auto-responder background processes. The SessionStart hook remains installed (it's harmless when no relay is running — it just finds no new messages).

### `/telegram-relay check`

Reads the inbox file and displays any unread messages, then updates the processed marker. Useful mid-session when you want to check for new messages without waiting for the next SessionStart.

### `/telegram-relay send <message>`

Sends a message to the configured chat via the Telegram bot API.

### `/telegram-relay status`

Shows whether the relay and auto-responder are running, the inbox path, and unread message count.

---

## Setup

### Prerequisites

- A Telegram bot token (create one via [@BotFather](https://t.me/BotFather))
- The chat ID of the person you want to communicate with (send `/start` to your bot, then check `getUpdates` for the chat ID)
- `curl` and `python3` available on the system

### Configuration

Config is stored at `~/.config/telegram-relay/config.sh`:

```bash
BOT_TOKEN="your-bot-token-here"
CHAT_ID="your-chat-id-here"
INBOX_DIR="$HOME/.config/telegram-relay"
POLL_INTERVAL=5        # seconds between getUpdates polls
ACK_INTERVAL=10        # seconds between auto-responder checks
```

The skill creates this file on first run if it doesn't exist.

### Installation Steps

When the user runs `/telegram-relay start` for the first time:

1. **Create config directory:** `~/.config/telegram-relay/`
2. **Prompt for bot token and chat ID** (or read from existing config)
3. **Write config file** at `~/.config/telegram-relay/config.sh`
4. **Copy scripts** from the skill's `scripts/` directory to `~/.config/telegram-relay/`
5. **Start the relay script** in background: `nohup bash ~/.config/telegram-relay/relay.sh &`
6. **Start the auto-responder** in background: `nohup bash ~/.config/telegram-relay/autoresponder.sh &`
7. **Install the SessionStart hook** in `~/.claude/settings.json` — add a `SessionStart` hook entry that runs `bash ~/.config/telegram-relay/session-check.sh`
8. **Write PID files** so we can stop them later
9. **Send a test message** to confirm the bot is working
10. **Report success** with the PIDs and inbox path

### Hook Installation

The SessionStart hook entry in `~/.claude/settings.json` should look like:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/telegram-relay/session-check.sh 2>/dev/null"
          }
        ]
      }
    ]
  }
}
```

If `SessionStart` already has entries, append to the existing array. If hooks already exist for other events, merge — don't overwrite.

---

## How to respond to Telegram messages

When the SessionStart hook surfaces unread messages, or when `/telegram-relay check` shows new messages:

1. Read each message carefully
2. Compose an appropriate response
3. Send the response using the Telegram bot API:
   ```bash
   curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
     -d chat_id="${CHAT_ID}" \
     --data-urlencode "text=Your response here"
   ```
4. Update the processed marker file so the same messages aren't shown again

The processed marker is at `~/.config/telegram-relay/.archie-processed` and contains the line number of the last message processed by Claude. After responding, update it:

```bash
wc -l < ~/.config/telegram-relay/inbox.log | tr -d ' ' > ~/.config/telegram-relay/.archie-processed
```

---

## Stopping the relay

When the user runs `/telegram-relay stop`:

1. Read PIDs from `~/.config/telegram-relay/relay.pid` and `~/.config/telegram-relay/autoresponder.pid`
2. Kill both processes
3. Remove PID files
4. Report that the relay is stopped
5. The SessionStart hook remains (it's a no-op when no relay is running)

---

## Important notes

- **The relay only captures messages from the configured chat ID.** Group chats and other users are ignored.
- **Auto-responder acknowledgments include "(Auto-ack)"** so the sender knows it's automated, not a real response.
- **The inbox file grows indefinitely.** For long-running relays, consider periodic rotation (rename and start fresh).
- **If `curl` requires approval** (e.g., in environments with network restrictions), the relay will stall. Make sure `curl` to `api.telegram.org` is permitted.
- **Bot tokens are sensitive.** The config file should be chmod 600. The skill sets this automatically on creation.
