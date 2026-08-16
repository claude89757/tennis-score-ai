#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || { echo "This smoke script requires macOS." >&2; exit 1; }
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

command -v xcodegen >/dev/null || { echo "Missing required tool: xcodegen" >&2; exit 1; }
xcodegen generate

SCREEN_DIR=${COURTVOICE_SCREENSHOT_DIR:-"$ROOT/build/simulator-screenshots"}
mkdir -p "$SCREEN_DIR"
SCREEN_DIR=$(cd "$SCREEN_DIR" && pwd)

SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
payload = json.load(sys.stdin)
preferred = []
for runtime, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable"):
            continue
        if device.get("state") == "Booted" and "iPhone" in device.get("name", ""):
            print(device["udid"])
            raise SystemExit
        if "iPhone" in device.get("name", ""):
            preferred.append(device["udid"])
if not preferred:
    raise SystemExit("No available iPhone Simulator found")
print(preferred[0])
')

echo "simulator_id=$SIMULATOR_ID"
echo "screenshots=$SCREEN_DIR"

TEST_RUNNER_COURTVOICE_SCREENSHOT_DIR="$SCREEN_DIR" xcodebuild \
  -project CourtVoice.xcodeproj \
  -scheme CourtVoice \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$ROOT/build/simulator-smoke" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  -only-testing:CourtVoiceAppUITests \
  test

echo "SIMULATOR_SMOKE_PASSED"
echo "Screenshots: $SCREEN_DIR"
