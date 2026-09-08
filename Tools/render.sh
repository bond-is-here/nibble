#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
nibble_sources=()
for source in CalorieCompass/*.swift; do
  if [[ "$source" != "CalorieCompass/CalorieCompassApp.swift" ]]; then
    nibble_sources+=("$source")
  fi
done
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macosx14.0" "${nibble_sources[@]}" Tools/RenderPreview.swift -o .build/render-preview
nibble_render_output=${1:-Design}
.build/render-preview "$nibble_render_output"
if [[ "$nibble_render_output" == "Design" ]]; then
  cp Design/AppIcon.png CalorieCompass/Assets.xcassets/AppIcon.appiconset/AppIcon.png
fi
