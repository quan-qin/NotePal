#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="NotePal"
TARGET_NAME="NotePal"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-com.notepal.app}"
APP_VERSION="${APP_VERSION:-0.1.0-beta.1}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH_NAME="${ARCH_NAME:-$(uname -m)}"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/build/$APP_NAME-mac-$ARCH_NAME.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_ICON="$ROOT_DIR/Sources/NotePal/Resources/NotePal.icns"

cd "$ROOT_DIR"

if [[ -d "$ROOT_DIR/.build" ]]; then
  find "$ROOT_DIR/.build" -type d \( \
    -name "${APP_NAME}_${TARGET_NAME}.bundle" -o \
    -name "${TARGET_NAME}_${TARGET_NAME}.bundle" \
  \) -prune -exec rm -rf {} +
fi

swift build -c "$CONFIGURATION"

BINARY=""
for candidate in \
  "$ROOT_DIR/.build/$(uname -m)-apple-macosx/$CONFIGURATION/$APP_NAME" \
  "$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"
do
  if [[ -x "$candidate" ]]; then
    BINARY="$candidate"
    break
  fi
done

if [[ -z "$BINARY" ]]; then
  echo "Could not find the built $APP_NAME executable." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

RESOURCE_BUNDLE=""
for candidate in \
  "$ROOT_DIR/.build/$(uname -m)-apple-macosx/$CONFIGURATION/${APP_NAME}_${TARGET_NAME}.bundle" \
  "$ROOT_DIR/.build/$CONFIGURATION/${APP_NAME}_${TARGET_NAME}.bundle" \
  "$ROOT_DIR/.build/$(uname -m)-apple-macosx/$CONFIGURATION/${TARGET_NAME}_${TARGET_NAME}.bundle" \
  "$ROOT_DIR/.build/$CONFIGURATION/${TARGET_NAME}_${TARGET_NAME}.bundle"
do
  if [[ -d "$candidate" ]]; then
    RESOURCE_BUNDLE="$candidate"
    break
  fi
done

if [[ -n "$RESOURCE_BUNDLE" ]]; then
  RESOURCE_BUNDLE_NAME="$(basename "$RESOURCE_BUNDLE")"
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME"
fi

find "$APP_DIR" -mindepth 1 -maxdepth 1 -type d -name "*.bundle" -prune -exec rm -rf {} +

if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$RESOURCES_DIR/NotePal.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>NotePal</string>
    <key>CFBundleExecutable</key>
    <string>NotePal</string>
    <key>CFBundleIconFile</key>
    <string>NotePal</string>
    <key>CFBundleIdentifier</key>
    <string>$APP_BUNDLE_IDENTIFIER</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NotePal</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if command -v xattr >/dev/null; then
  xattr -cr "$APP_DIR" 2>/dev/null || true
fi

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

if command -v xattr >/dev/null; then
  xattr -cr "$APP_DIR" 2>/dev/null || true
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$ZIP_PATH"
ditto -c -k --norsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Built $APP_DIR"
echo "Packaged $ZIP_PATH"
