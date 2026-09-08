#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build

# Pick an installed iPhone runtime, never a physical device or a hard-coded UUID.
nibble_simulator_id=${NIBBLE_SIMULATOR_ID:-$(xcrun simctl list devices available --json | jq -r '
  [.devices | to_entries[] | select(.key | contains("iOS")) | .value[]
   | select(.isAvailable and (.name | startswith("iPhone")))]
  | sort_by(.name) | last | .udid // empty')}
if [[ -z "$nibble_simulator_id" ]]; then
  echo "No available iPhone Simulator runtime. Install one through Xcode Settings → Components." >&2
  exit 1
fi

# Keep prior results on repeat runs; no destructive cleanup or simulator erase.
nibble_result_dir=$(mktemp -d "$PWD/.build/ui-run.XXXXXX")
echo "iPhone Simulator: $nibble_simulator_id"
echo "UI results: $nibble_result_dir/NibbleUI.xcresult"
xcodebuild -project Nibble.xcodeproj -scheme Nibble -configuration Debug \
  -destination "platform=iOS Simulator,id=$nibble_simulator_id" \
  -destination-timeout 120 -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath "$nibble_result_dir/NibbleUI.xcresult" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee "$nibble_result_dir/xcodebuild.log"
