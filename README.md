# NotePal

NotePal is a lightweight macOS desktop companion for quick notes, todos, wellness reminders, and gentle on-screen prompts. It stays close at hand without requiring an account, cloud sync, telemetry, or a background service outside the app.

## Features

- Floating desktop companion with click-to-open notes, todos, and wellness controls.
- Separate text notes and sketch notes, with local image paste support for text notes.
- Local todos with reminder bubbles for due items.
- Independent wellness reminders that do not mix with the todo list.
- Built-in companion themes plus optional locked themes.
- Theme menu, quiet mode for casual chatter, animation toggle, and menu controls.
- Local JSON persistence only.

## Download

Open the latest GitHub Release and download:

```text
NotePal-mac-arm64.zip
```

Unzip it and move `NotePal.app` to `/Applications`.

This beta build is ad-hoc signed and not notarized with Apple. On first launch, macOS may block the app. If you trust this build, open it from Finder with Control-click, choose Open, then confirm Open.

## System Requirements

- macOS 13 or newer
- Apple Silicon Mac for the published `arm64` build

## Build From Source

Build and run the Swift package:

```sh
cd NotePal
swift build
swift run NotePal
```

Create a local `.app` bundle:

```sh
cd NotePal
Scripts/build_app.sh
```

The bundle and zip are written to:

```text
NotePal/build/NotePal.app
NotePal/build/NotePal-mac-arm64.zip
```

## Local Data

NotePal stores user data locally:

```text
~/Library/Application Support/NotePal/notepal-data.json
```

On first launch, NotePal attempts to import compatible legacy local data so existing notes and todos can carry forward into the renamed app.

## Repository Layout

```text
NotePal/
  Sources/NotePal/      macOS Swift app
  Scripts/              local build and asset utility scripts
.github/workflows/      GitHub Actions release workflow
```
