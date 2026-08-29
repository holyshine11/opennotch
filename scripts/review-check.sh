#!/bin/bash
# 빌드된 앱의 entitlements와 사설 심볼을 점검한다. 사용: scripts/review-check.sh path/to/OpenNotch.app
set -euo pipefail
APP="${1:?usage: review-check.sh <OpenNotch.app>}"
BIN="$APP/Contents/MacOS/OpenNotch"
echo "== entitlements =="
codesign -d --entitlements :- "$APP" 2>/dev/null | plutil -p - | sed 's/^/  /'
echo "== private symbols (must be empty) =="
if nm -u "$BIN" 2>/dev/null | grep -E 'MRMediaRemote|_SLS|_CGS[A-Z]' ; then echo "FAIL: private symbols found"; exit 1; fi
if otool -L "$BIN" | grep -iE 'PrivateFrameworks|MediaRemote|SkyLight' ; then echo "FAIL: private framework linked"; exit 1; fi
echo "  none"
echo "== Info.plist required keys =="
for key in LSUIElement LSApplicationCategoryType LSMinimumSystemVersion ITSAppUsesNonExemptEncryption; do
  printf '  %s = ' "$key"; /usr/libexec/PlistBuddy -c "Print :$key" "$APP/Contents/Info.plist"
done
echo "OK"
