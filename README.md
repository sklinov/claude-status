# Claude Status — macOS Menu Bar App

A lightweight native macOS menu bar app that monitors the status of all Claude services in real time.

## Features

- **Live status indicator** in the menu bar (🟢 green / 🟡 yellow / 🟠 orange / 🔴 red)
- Tracks all 5 Claude services: Claude.ai, Console, API, Claude Code, Government
- Shows **active incidents** with latest update details
- Click incidents to open them on the status page
- Auto-refreshes every 60 seconds
- Manual refresh with ⌘R
- No dock icon (runs as a pure menu bar app)
- Zero dependencies — pure AppKit, ~300 lines of Swift

## Data Source

Polls the public Atlassian Statuspage API at:
```
https://status.claude.com/api/v2/summary.json
```

## Build & Install

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
chmod +x build.sh
./build.sh
```

This creates `build/Claude Status.app`. To install:

```bash
cp -r "build/Claude Status.app" /Applications/
open "/Applications/Claude Status.app"
```

## Auto-Start at Login

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Claude Status.app", hidden:true}'
```

## Menu Bar States

| Icon | Meaning |
|------|---------|
| 🟢 | All systems operational |
| 🟡 | Degraded performance on one or more services |
| 🟠 | Partial outage |
| 🔴 | Major outage |
| ⚪ | Unable to fetch status |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘R | Refresh now |
| ⌘O | Open status page in browser |
| ⌘Q | Quit |

## Customization

Edit `main.swift` to change:
- `refreshInterval` (line ~155) — polling frequency in seconds (default: 60)
- `friendlyName()` — display names for each component
- `menuBarIcon()` — icon colors and size
