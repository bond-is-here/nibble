#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash Tests/UIReportChecks.sh
mkdir -p .build
plutil -lint Nibble.xcodeproj/project.pbxproj CalorieCompass/PrivacyInfo.xcprivacy
xmllint --noout Nibble.xcodeproj/xcshareddata/xcschemes/Nibble.xcscheme
xcrun swiftc -swift-version 5 -warnings-as-errors -typecheck -target "$(uname -m)-apple-macosx14.0" CalorieCompass/*.swift
xcrun swiftc -swift-version 5 -D DEBUG -warnings-as-errors -typecheck -target "$(uname -m)-apple-macosx14.0" CalorieCompass/*.swift
xcrun swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/NutritionEngine.swift CalorieCompass/AppState.swift Tests/DiaryChecks.swift -o .build/diary-checks
.build/diary-checks
xcrun swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/OpenFoodFactsClient.swift Tests/BarcodeLookupChecks.swift -o .build/barcode-checks
.build/barcode-checks
xcrun swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/NutritionEngine.swift CalorieCompass/AppState.swift CalorieCompass/MacroEngine.swift Tests/MacroChecks.swift -o .build/macro-checks
.build/macro-checks
xcrun swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/NutritionEngine.swift CalorieCompass/AppState.swift Tests/StorageProtectionChecks.swift -o .build/storage-checks
.build/storage-checks
xcrun swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/NutritionEngine.swift CalorieCompass/Theme.swift Tests/AccessibilityPaletteChecks.swift -o .build/accessibility-palette-checks
.build/accessibility-palette-checks
