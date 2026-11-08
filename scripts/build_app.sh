#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_DIR="$PROJECT_DIR/dist/CopyShelf.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swiftc \
  -O \
  -target "$(uname -m)-apple-macosx13.0" \
  -module-name CopyShelf \
  -module-cache-path "$PROJECT_DIR/.build/module-cache" \
  -framework AppKit \
  -framework Carbon \
  -framework CoreGraphics \
  -framework SwiftUI \
  Sources/CopyShelf/*.swift \
  -o "$APP_DIR/Contents/MacOS/CopyShelf"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>CopyShelf</string>
	<key>CFBundleIdentifier</key>
	<string>app.copyshelf.CopyShelf</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>CopyShelf</string>
	<key>CFBundleDisplayName</key>
	<string>CopyShelf</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
codesign --force --deep --sign - "$APP_DIR"

echo "Built: $APP_DIR"
