# HiveMind

HiveMind is a background daemon that syncs your AI coding sessions to the [HiveMind Dashboard](https://hivemind.wandb.tools). It works with Claude Code, Codex, Cursor, and Gemini.

> [!NOTE]
> HiveMind is currently restricted to members of the wandb and coreweave GitHub orgs.

## What it does

AI coding agents generate session logs on your machine. HiveMind watches for those sessions, reads the raw log files, and ships them to our backend. You get a dashboard showing usage and costs across all your agents.  You also get a CLI and API to analyze or inject historic session context.

## How it works

```
      Your machine                  HiveMind Backend
┌─────────────────────┐       ┌──────────────────────────┐
│                     │       │                          │
│  Claude Code        │       │  Normalizes sessions     │
│  Codex              │       │  into AG-UI events       │
│  Cursor             ├──────>│                          │
│  Gemini             │       │  Stores them in          │
│                     │       │  ClickHouse              │
│  (raw session logs) │       │                          │
└─────────────────────┘       │  Serves API & dashboard  │
         hivemind             └──────────────────────────┘
reads + redacts + uploads
```

The only processing hivemind performs on your machine is secret redaction. It reads log entries from JSONL and SQLite files, redacts any detected secrets, and uploads them. It's designed to be simple and resource efficient. Parsing and normalization happen server-side.

The backend normalizes entries into [AG-UI events](https://docs.ag-ui.com/concepts/events), stores them in ClickHouse, and serves the API & dashboard.

## Installation

```bash
brew install wandb/taps/hivemind
hivemind start
```

> [!CAUTION]
> There's an unrelated `hivemind` package in homebrew-core, be sure to use the full tap name.

To upgrade:

```bash
brew upgrade wandb/taps/hivemind
hivemind restart
```

The restart matters -- after an upgrade, launchd will still be running the old binary.

### If Homebrew cannot clone the tap (HTTPS / authentication)

`brew install` clones the tap over HTTPS. That can fail if GitHub credentials are not set up for HTTPS, or if your environment blocks or interferes with HTTPS access to GitHub. In those cases, add the tap with SSH instead (same tap and formula names as above; only the Git transport changes).

Prerequisites: an [SSH key on your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) and access to the `wandb/homebrew-taps` repository.

```bash
brew tap wandb/taps git@github.com:wandb/homebrew-taps.git
brew install wandb/taps/hivemind
hivemind start
```

If you already added `wandb/taps` over HTTPS and want to switch the remote to SSH:

```bash
brew untap wandb/taps
brew tap wandb/taps git@github.com:wandb/homebrew-taps.git
brew install wandb/taps/hivemind
```

## Authentication

HiveMind attempts to auto-login using GitHub credentials found on your machine.  If no credentials are available, hivemind also provides an OAuth flow that can be manually initiated with `hivemind login --method device`.

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
> The first time HiveMind is started, historic sessions from the last 90 days are synced.  Run `hivemind config set import.max_age_days 30` before running start to re-configure.

## HiveMind CLI & Agent

HiveMind also provides a CLI and automatically installs a custom sub-agent (`@hivemind`) that knows how to use the CLI to provide historic sessions as context in coding sessions.

```bash
hivemind search "file:cli.py"  # Find historic sessions that edited cli.py
hivemind search --limit 3      # Return a markdown transcript of your last 3 sessions
hivemind transcript $UUID      # Return a markdown transcript for a specific session
```

## Troubleshooting

Start with `hivemind doctor`. It checks auth, daemon health, and configuration.

To see what the daemon is doing, `hivemind logs -f`.
