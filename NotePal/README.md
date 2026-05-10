# NotePal

NotePal is a lightweight desktop companion for quick notes, todos, wellness reminders, and gentle on-screen prompts. It stays close at hand without requiring an account, cloud sync, or a background service outside the app.

The project includes a macOS app and a Windows WPF client. The Windows build is published as a portable, self-contained `NotePal.exe` for Windows 10+ x64.

## Features

- Floating desktop companion with click-to-open notes, todos, and wellness controls.
- Local notes and todos with reminder bubbles for due items.
- Independent wellness reminders that do not mix with the todo list.
- Built-in companion themes plus optional locked themes.
- Theme menu, quiet mode for casual chatter, animation toggle, and tray/menu controls.
- Local JSON persistence only; no telemetry, accounts, or network access.
- Windows portable single-file publish target for `win-x64`.

## Downloading Windows Builds

Windows builds are produced by GitHub Actions. Open the latest successful **Build NotePal Windows** workflow run and download the `NotePal-win-x64` artifact. The artifact contains:

```text
NotePal.exe
```

The executable is unsigned and portable. Windows may show a first-run warning because code signing is not part of this project yet.

## Build From Source

### macOS

Build and run the Swift package:

```sh
swift build
swift run NotePal
```

Create a local `.app` bundle:

```sh
Scripts/build_app.sh
```

The bundle is written to:

```text
build/NotePal.app
```

### Windows

Build the WPF client from Windows with the .NET 8 SDK:

```powershell
dotnet build Windows\NotePal.Windows\NotePal.Windows.csproj -c Release
```

Publish the portable self-contained executable:

```powershell
Scripts\publish_windows.ps1
```

The published executable is written to:

```text
build\windows\NotePal-win-x64\NotePal.exe
```

## Local Data

NotePal stores user data on the local machine.

macOS:

```text
~/Library/Application Support/NotePal/notepal-data.json
```

Windows:

```text
%APPDATA%\NotePal\
```

On first launch, NotePal also attempts to import compatible legacy local data so existing notes and todos can carry forward into the renamed app.

## Repository Layout

```text
NotePal/
  Sources/NotePal/              macOS Swift app
  Windows/NotePal.Windows/      Windows WPF app
  Scripts/                      local build and publishing scripts
.github/workflows/              GitHub Actions release workflow
```
