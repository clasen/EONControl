#!/bin/zsh
# Builds "EON Control.app", signs it with Developer ID, notarizes and staples it,
# and writes build/EON-Control.zip ready to attach to a GitHub release.
# Needs a notarytool keychain profile named $profile (see README).
set -euo pipefail

identity="Developer ID Application: Blyts LLC (69VZST7GND)"
profile="blendline-notary"

root="${0:A:h:h}"
app="$root/build/EON Control.app"
zip="$root/build/EON-Control.zip"

"$root/scripts/build-app.sh"

codesign --force --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --strict --verbose=2 "$app"

rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"

rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose=2 "$app"
echo "$zip"
