#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build

# Pick an installed iPhone runtime, never a physical device or a hard-coded UUID.
# Compact QA creates its own SE-sized simulator; it never erases an existing one.
nibble_simulator_id=${NIBBLE_SIMULATOR_ID:-}
if [[ -z "$nibble_simulator_id" && "${NIBBLE_SIMULATOR_KIND:-standard}" == "compact" ]]; then
  nibble_runtime_id=$(xcrun simctl list runtimes --json | jq -r '
    [.runtimes[] | select(.isAvailable and (.identifier | contains(".iOS-")))]
    | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')
  nibble_device_type=$(xcrun simctl list devicetypes --json | jq -r '
    .devicetypes[] | select(.name == "iPhone SE (3rd generation)") | .identifier')
  if [[ -z "$nibble_runtime_id" || -z "$nibble_device_type" ]]; then
    echo "Compact QA requires an available iOS runtime and iPhone SE (3rd generation) device type." >&2
    exit 1
  fi
  nibble_simulator_id=$(xcrun simctl create "Nibble compact QA $(uuidgen)" "$nibble_device_type" "$nibble_runtime_id")
elif [[ -z "$nibble_simulator_id" ]]; then
  nibble_simulator_id=$(xcrun simctl list devices available --json | jq -r '
  [.devices | to_entries[] | select(.key | contains("iOS")) | .value[]
   | select(.isAvailable and (.name | startswith("iPhone")))]
  | sort_by(.name) | last | .udid // empty')
fi
if [[ -z "$nibble_simulator_id" ]]; then
  echo "No available iPhone Simulator runtime. Install one through Xcode Settings → Components." >&2
  exit 1
fi

# Keep prior results on repeat runs; no destructive cleanup or simulator erase.
nibble_result_dir=$(mktemp -d "$PWD/.build/ui-run.XXXXXX")
echo "iPhone Simulator: $nibble_simulator_id"
echo "UI results: $nibble_result_dir/NibbleUI.xcresult"
set +e
xcodebuild -project Nibble.xcodeproj -scheme Nibble -configuration Debug \
  -destination "platform=iOS Simulator,id=$nibble_simulator_id" \
  -destination-timeout 120 -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath "$nibble_result_dir/NibbleUI.xcresult" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee "$nibble_result_dir/xcodebuild.log"
nibble_test_status=$?
set -e

# Export ordinary images as well as the full bundle so visual QA does not require
# opening Xcode. Preserve the test exit status even when diagnostics cannot export.
if [[ -d "$nibble_result_dir/NibbleUI.xcresult" ]]; then
  xcrun xcresulttool get test-results summary --path "$nibble_result_dir/NibbleUI.xcresult" \
    > "$nibble_result_dir/summary.json" || echo "Could not export test summary." >&2
  if [[ -s "$nibble_result_dir/summary.json" ]]; then
    bash Tools/report-ui-results.sh "$nibble_result_dir/summary.json" \
      || echo "Could not publish test summary; inspect the xcresult bundle." >&2
  fi
  xcrun xcresulttool export attachments --path "$nibble_result_dir/NibbleUI.xcresult" \
    --output-path "$nibble_result_dir/attachments" || echo "Could not export attachments; inspect the xcresult bundle." >&2
fi
exit "$nibble_test_status"
