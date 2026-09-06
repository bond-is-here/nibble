#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
plutil -lint Nibble.xcodeproj/project.pbxproj CalorieCompass/PrivacyInfo.xcprivacy
xmllint --noout Nibble.xcodeproj/xcshareddata/xcschemes/Nibble.xcscheme
xcrun swiftc -swift-version 5 -warnings-as-errors -typecheck -target "$(uname -m)-apple-macosx14.0" CalorieCompass/*.swift
xcrun swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/NutritionEngine.swift CalorieCompass/AppState.swift Tests/DiaryChecks.swift -o .build/diary-checks
.build/diary-checks
xcrun swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/OpenFoodFactsClient.swift Tests/BarcodeLookupChecks.swift -o .build/barcode-checks
.build/barcode-checks
