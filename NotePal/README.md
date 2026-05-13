# NotePal macOS

This directory contains the macOS Swift Package for NotePal.

## Build and Run

```sh
swift build
swift run NotePal
```

## Package a Local App

```sh
Scripts/build_app.sh
```

Outputs:

```text
build/NotePal.app
build/NotePal-mac-arm64.zip
```

The beta package is ad-hoc signed and not Apple-notarized.
