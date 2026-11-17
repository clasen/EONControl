#!/bin/zsh
# Builds "EON Control.app" into build/ with its icon and Bluetooth usage string, ad-hoc signed.
set -euo pipefail

root="${0:A:h:h}"
app="$root/build/EON Control.app"

swift build --package-path "$root" -c release --product EONControl
bin="$(swift build --package-path "$root" -c release --show-bin-path)/EONControl"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/EONControl"

iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$root/Resources/AppIcon.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$root/Resources/AppIcon.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>app.eoncontrol</string>
  <key>CFBundleName</key><string>EON Control</string>
  <key>CFBundleDisplayName</key><string>EON Control</string>
  <key>CFBundleExecutable</key><string>EONControl</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
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
