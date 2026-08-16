#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || { echo "This smoke script requires macOS." >&2; exit 1; }
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

command -v xcodegen >/dev/null || { echo "Missing required tool: xcodegen" >&2; exit 1; }
xcodegen generate

DEVICE_ID=${COURTVOICE_DEVICE_ID:-$(xcodebuild -showdestinations -project CourtVoice.xcodeproj -scheme CourtVoice 2>/dev/null | python3 -c '
import re, sys
for line in sys.stdin:
    match = re.search(r"platform:iOS, arch:arm64, id:([0-9A-F-]+), name:(.+)", line)
    if match and "Simulator" not in line:
        print(match.group(1))
        raise SystemExit
raise SystemExit("No physical iOS device destination found")
')}
TEAM_ID=${DEVELOPMENT_TEAM:-A2YR8HBQKY}
SCREEN_DIR=${COURTVOICE_SCREENSHOT_DIR:-"$ROOT/build/device-screenshots"}
mkdir -p "$SCREEN_DIR"
SCREEN_DIR=$(cd "$SCREEN_DIR" && pwd)

echo "device_id=$DEVICE_ID"
echo "team_id=$TEAM_ID"
echo "screenshots=$SCREEN_DIR"

TEST_RUNNER_COURTVOICE_SCREENSHOT_DIR="$SCREEN_DIR" xcodebuild \
  -project CourtVoice.xcodeproj \
  -scheme CourtVoice \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$ROOT/build/device-smoke" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  COMPILER_INDEX_STORE_ENABLE=NO \
  -only-testing:CourtVoiceAppUITests \
  test

RESULT=$(find "$ROOT/build/device-smoke/Logs/Test" -name '*.xcresult' -print | sort | tail -n 1)
if [[ -n "$RESULT" ]]; then
  EXPORT_DIR="$ROOT/build/device-xcresult-attachments"
  rm -rf "$EXPORT_DIR"
  mkdir -p "$EXPORT_DIR"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT_DIR"
  echo "Exported attachments from $RESULT"
fi

echo "DEVICE_SMOKE_PASSED"
echo "Screenshots: $SCREEN_DIR"
