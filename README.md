# aavila-agent-skills

Agent skills and plugins for the ClawCamp build pipeline.

## Skills

### telegram-relay

Bidirectional Telegram messaging for Claude Code sessions. Provides a background relay that captures incoming messages, auto-acknowledges them, and injects unread messages into every new session via a SessionStart hook.

**Commands:**
- `/telegram-relay start` — Set up and launch the relay
- `/telegram-relay stop` — Stop background processes
- `/telegram-relay check` — Show unread messages mid-session
- `/telegram-relay send <message>` — Send a Telegram message
- `/telegram-relay status` — Show relay status

**Install:** Copy `skills/telegram-relay/` to `~/.claude/skills/telegram-relay/` and run `/telegram-relay start`.

## Installation

```bash
# Clone the repo
git clone https://github.com/aavila-009/aavila-agent-skills.git

# Install a skill (example: telegram-relay)
cp -r aavila-agent-skills/skills/telegram-relay ~/.claude/skills/
```

## Structure

```
skills/
  telegram-relay/
    SKILL.md          # Skill definition + instructions
    scripts/          # Bundled shell scripts
plugins/
  (future plugins)
```
