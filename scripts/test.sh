#!/usr/bin/env bash
# Usage: scripts/test.sh [unit|ui|all]   (default: unit)
# Generates the project and runs tests on the first available iPhone simulator with iOS 18.
set -euo pipefail
cd "$(dirname "$0")/.."
KIND="${1:-unit}"

command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen"; exit 1; }
xcodegen generate --quiet

DEVICE_ID="${SIM_ID:-$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
ids=[x["udid"] for rt,devs in sorted(d.items(),reverse=True) if "iOS-18" in rt for x in devs if x["name"].startswith("iPhone")]
print(ids[0] if ids else "")')}"
[ -n "$DEVICE_ID" ] || { echo "No iPhone simulator with iOS 18 found"; exit 1; }

run() {
  xcodebuild -project SeryaPlayer.xcodeproj -scheme "$1" \
    -destination "id=$DEVICE_ID" -derivedDataPath build/DD \
    CODE_SIGNING_ALLOWED=NO test | { command -v xcbeautify >/dev/null && xcbeautify || cat; }
}
case "$KIND" in
  unit) run SeryaPlayer ;;
  ui)   run SeryaPlayerUITests ;;
  all)  run SeryaPlayer; run SeryaPlayerUITests ;;
esac
