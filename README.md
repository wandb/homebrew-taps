# HiveMind

HiveMind is a background daemon that syncs your AI coding sessions to the [HiveMind Dashboard](https://hivemind.wandb.tools). It works with Claude Code, Codex, Cursor, and Gemini.

> [!NOTE]
> HiveMind is currently restricted to members of the wandb and coreweave GitHub orgs.

## What it does

AI coding agents generate session logs on your machine. HiveMind watches for those sessions, reads the raw log files, and ships them to our backend. You get a dashboard showing usage and costs across all your agents.

The daemon doesn't try to be smart. It reads log entries from JSONL and SQLite files and uploads them as-is. Parsing and normalization happen server-side.

## How it works

```
      Your machine                  Hivemind Backend
┌─────────────────────┐       ┌──────────────────────────┐
│                     │       │                          │
│  Claude Code        │       │  Normalizes sessions     │
│  Codex              │       │  into AG-UI events       │
│  Cursor             ├──────>│                          │
│  Gemini             │       │  Stores them in          │
│                     │       │  ClickHouse              │
│  (raw session logs) │       │                          │
└─────────────────────┘       │  Serves a dashboard      │
         hivemind             └──────────────────────────┘
      reads + uploads
```

The daemon picks up agent sessions on your machine and uploads raw log entries. The backend normalizes them into [AG-UI events](https://docs.ag-ui.com/concepts/events), stores them in ClickHouse, and serves the dashboard.

## Installation

```bash
brew install wandb/taps/hivemind
hivemind start
```

> [!CAUTION]
> There's an unrelated `hivemind` package in homebrew-core, be sure to use the full tap name:

To upgrade:

```bash
brew upgrade wandb/taps/hivemind
hivemind restart
```

The restart matters -- after an upgrade, launchd will still be running the old binary.

## Authentication

Hivemind attempts to auto-login using GitHub credentials found on your machine.  If no credentials are available, hivemind also provides an OAuth flow that can be manually initiated with `hivemind login --method device`.

## Daemon Commands

```bash
hivemind start          # Start the background daemon
hivemind stop           # Stop it
hivemind restart        # Restart (useful after upgrades)
hivemind status         # Check if it's running

hivemind config         # Configure hivemind
hivemind login          # Authenticate the daemon
hivemind logs -f        # Tail daemon logs
hivemind doctor         # Run diagnostics
```

Once started and authenticated, the daemon finds and syncs sessions every 30 seconds.

> [!TIP]
> The first time Hivemind is started, historic sessions from the last 90 days are synced.  Run `hivemind config set import.max_age_days 30` before running start to re-configure.

## Hivemind CLI & Agent

Hivemind also provides a CLI and automatically installs a custom sub-agent (`@hivemind`) that knows how to use the CLI to provide historic sessions as context in coding sessions.

```bash
hivemind search "file:cli.py"  # Find historic sessions that edited cli.py
hivemind search --limit 3      # Return a markdown transcript of your last 3 sessions
hivemind transcript $UUID      # Return a markdown transcript for a specific session
```

## Troubleshooting

Start with `hivemind doctor`. It checks auth, daemon health, and configuration.

To see what the daemon is doing, `hivemind logs -f`.
