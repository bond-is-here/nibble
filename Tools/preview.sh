#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/NibblePreview.app/Contents/MacOS
cp Tools/PreviewInfo.plist .build/NibblePreview.app/Contents/Info.plist
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macosx14.0" CalorieCompass/*.swift -o .build/NibblePreview.app/Contents/MacOS/NibblePreview
codesign --force --sign - .build/NibblePreview.app
if [[ "${1:-}" != "--build-only" ]]; then
  open .build/NibblePreview.app --args --demo
fi
