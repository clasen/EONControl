#!/bin/zsh
# Builds "EON Control.app" into build/ with its Bluetooth usage string, ad-hoc signed.
set -euo pipefail

root="${0:A:h:h}"
app="$root/build/EON Control.app"

swift build --package-path "$root" -c release --product EONControl
bin="$(swift build --package-path "$root" -c release --show-bin-path)/EONControl"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/EONControl"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>app.eoncontrol</string>
  <key>CFBundleName</key><string>EON Control</string>
  <key>CFBundleDisplayName</key><string>EON Control</string>
  <key>CFBundleExecutable</key><string>EONControl</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>EON Control talks to your JBL EON speakers over Bluetooth.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "$app"
