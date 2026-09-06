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
.build/render-preview Design
cp Design/AppIcon.png CalorieCompass/Assets.xcassets/AppIcon.appiconset/AppIcon.png
