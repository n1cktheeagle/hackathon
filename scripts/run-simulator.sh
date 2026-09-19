#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="${DETOUR_DERIVED_DATA:-/tmp/detour-derived-data}"
build_log="${DETOUR_BUILD_LOG:-/tmp/detour-build.log}"
simulator_id="${DETOUR_SIMULATOR_ID:-}"

if [[ -z "$simulator_id" ]]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
phones = [d for devices in json.load(sys.stdin)["devices"].values() for d in devices if "iPhone" in d["name"]]
device = next((d for d in phones if d["state"] == "Booted"), None) or next((d for d in phones if d["name"] == "iPhone 17 Pro"), None) or next(iter(phones), None)
if device is None:
    sys.exit("Install an iPhone simulator in Xcode first.")
print(device["udid"])
')"
fi

xcrun simctl bootstatus "$simulator_id" -b
echo "Building Detour…"
if ! xcodebuild -project "$project_root/ios/Detour.xcodeproj" -scheme Detour \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$derived_data" build > "$build_log" 2>&1; then
  tail -50 "$build_log"
  exit 1
fi
xcrun simctl install "$simulator_id" "$derived_data/Build/Products/Debug-iphonesimulator/Detour.app"
xcrun simctl launch --terminate-running-process "$simulator_id" com.steph.detour "$@"
echo "Detour is running. Build log: $build_log"
