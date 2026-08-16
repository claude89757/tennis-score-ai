#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || { echo "This acceptance script requires macOS." >&2; exit 1; }
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

for tool in xcodebuild xcrun xcodegen swift python3; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

RUN_DIR=${COURTVOICE_MAC_RUN_DIR:-"$ROOT/build/mac-acceptance-$(date +%Y%m%d-%H%M%S)"}
mkdir -p "$RUN_DIR"
RUN_DIR=$(cd "$RUN_DIR" && pwd)
LOG="$RUN_DIR/acceptance.log"
exec > >(tee "$LOG") 2>&1

echo "CourtVoice macOS acceptance"
echo "run_dir=$RUN_DIR"
xcodebuild -version
swift --version

printf '\n== Portable Swift tests ==\n'
swift test

printf '\n== Generate Xcode project ==\n'
xcodegen generate
xcodebuild -project CourtVoice.xcodeproj -scheme CourtVoice -resolvePackageDependencies

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
        if device.get("state") == "Booted":
            print(device["udid"])
            raise SystemExit
        if "iPhone" in device.get("name", ""):
            preferred.append(device["udid"])
if not preferred:
    raise SystemExit("No available iPhone Simulator found")
print(preferred[0])
')
echo "simulator_id=$SIMULATOR_ID"

printf '\n== Debug build and tests ==\n'
xcodebuild \
  -project CourtVoice.xcodeproj \
  -scheme CourtVoice \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -resultBundlePath "$RUN_DIR/TestResults.xcresult" \
  -derivedDataPath "$RUN_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  test

printf '\n== Release Simulator build ==\n'
xcodebuild \
  -project CourtVoice.xcodeproj \
  -scheme CourtVoice \
  -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$RUN_DIR/DerivedData-Release" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build

echo "MAC_ACCEPTANCE_PASSED"
echo "Artifacts: $RUN_DIR"
