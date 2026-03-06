# GT Station

A native macOS command dashboard for monitoring and managing your Gas Town distributed system.

## Features

- **Mail** — Thread-grouped inbox with compose, reply, priority levels, and native notifications
- **Nudge** — iMessage-style messaging to agents with delivery modes (immediate, scheduled, etc.)
- **Rigs** — Monitor status, start/stop infrastructure units, manage the full rig lifecycle
- **Dolt Health** — Direct database monitoring via MySQLNIO with real-time health metrics
- **Contacts** — Agent directory with quick-action nudge and mail capabilities
- **Escalations** — Centralized critical issue monitoring

## Requirements

- macOS (Xcode 15.4+)
- [Dolt](https://github.com/dolthub/dolt) running on `127.0.0.1:3307`
- `gt` CLI binary at `/opt/homebrew/bin/gt`

## Build

```bash
# Clone
git clone https://github.com/aramb-dev/gt-station.git
cd gt-station

# Open in Xcode
open GTStation.xcodeproj
```

Build and run with Xcode (Cmd+R).

## Tech Stack

- SwiftUI
- Swift Concurrency (async/await, actors)
- MySQLNIO (Vapor)
- Dolt database
