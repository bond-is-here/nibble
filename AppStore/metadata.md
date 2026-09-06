# Nibble — App Store metadata draft

Prepared September 5, 2026 from the current README and Swift source. This is preparation material, not evidence of an App Store listing, reserved name, approved privacy declaration, or completed submission. Copy only the intended field contents into App Store Connect after the release checks pass.

## Listing fields (English — U.S.)

| Field | Draft value | Verification / owner action |
| --- | --- | --- |
| Name | Nibble | 6 characters. Availability and rights to this name are not established; verify in App Store Connect. |
| Subtitle | Food diary, calories & macros | 29 characters; maximum 30. |
| Primary category | Health & Fitness | Matches the implemented nutrition diary and optional targets. |
| Secondary category | None planned | Optional. |
| Price | Free | All implemented features included; no subscriptions, in-app purchases, or paid upgrade. Configure and verify in App Store Connect. |
| Primary language | English (U.S.) | Draft locale; confirm the actual app record. |
| Platform / device family | iOS / iPhone | Project targets iPhone (`TARGETED_DEVICE_FAMILY = 1`) and portrait orientation. |
| Minimum OS | iOS 17.0 | Runtime deployment target in the project; separate from Apple's required upload SDK. |
| Version / build | 1.0 / 2 | Current project values; reconcile with existing App Store Connect records before upload. |
| Bundle ID | com.caloriecompass.app | Retained for Calorie Compass continuity. Owner must establish registration and signing access. |
| Copyright | Owner to supply the year and actual rights-holder name | Required field; do not infer a legal identity from the GitHub username. |
| Age rating | Not yet determined | Complete the current questionnaire; see evidence below. |

Apple documents the [30-character subtitle and keyword guidance](https://developer.apple.com/app-store/product-page/) and [version fields, description limit, and keyword byte limit](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information). This draft's keywords are ASCII, so its 88 characters also occupy 88 bytes, below both 100 limits.

### Keywords

```text
nutrition,barcode,meal,portion,protein,carbs,fat,favorites,tracker,daily,balance,journal
```

### Description

```text
Little bites. Real life.

Nibble is a food diary for iPhone that makes everyday logging a little easier. Start without a target, bring a daily calorie target you already use, or explore an optional estimate. No account required.

MAKE ROOM FOR YOUR USUALS
Quick-add a serving, return to recent foods, and star your favorites. Search the starter library and the foods you have saved.

SCAN OR MAKE A FOOD
Scan a package barcode or type its number to look up a product with Open Food Facts. Check the package, choose your portion, and add it to a meal. If a product is missing or incomplete, enter the label yourself. Calories alone are enough; unknown macros stay marked as incomplete.

A DIARY THAT CAN CHANGE WITH YOUR DAY
Edit a portion or meal, delete an entry, or undo your last diary change. Open earlier days with the date picker. Patterns shows your recent week and an average based on days you actually logged.

YOUR KIND OF BALANCE
Track without a target or adjust your plan whenever you need to. Optional calorie estimates use your age, height, weight, formula choice, activity, and direction. Metric and imperial units are supported.

Your diary and saved foods are stored on your device and remain usable offline. Barcode lookup needs internet access and sends the requested barcode and ordinary network information to Open Food Facts; your saved diary and body profile are not sent. Device backups are managed separately by iOS. Nibble includes no analytics, advertising, subscriptions, or in-app purchases.

Nutrition values and targets are estimates, not medical advice or a weight-loss guarantee. Automated estimates are for adults and exclude pregnancy and breastfeeding. Check product values against the package.

Product nutrition data is provided by the Open Food Facts community under the Open Database License (ODbL).
```

Description is 1,839 characters of plain text and must remain within Apple's 4,000-character limit after edits. Promotional text and a marketing URL are optional and omitted from this draft. For a first App Store version, leave What's New unused; if this is an update to an existing Calorie Compass listing, supply an accurate change summary after verifying that record.

## Planned public URLs

| App Store Connect field | Planned URL |
| --- | --- |
| Privacy Policy URL | [Repository privacy policy](https://github.com/bond-is-here/nibble/blob/main/PRIVACY.md) |
| Support URL | [Repository support page](https://github.com/bond-is-here/nibble/blob/main/SUPPORT.md) |
| Support contact linked by those pages | [Nibble GitHub Issues](https://github.com/bond-is-here/nibble/issues) |

These URLs target the repository's public default branch. After merge, verify both pages load without authentication and Issues permits users to contact the maintainers. Preserve these paths or update every reference if the repository moves. `ProfileView.swift` includes Privacy policy and Help & support links under You. Verify their accessibility and public destinations in the release candidate.

GitHub Issues is the planned public contact channel; never invent an email address. Apple's [Support URL field guidance](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) calls for actual contact information as applicable to local law. The owner must resolve any additional contact details required for the selected territories or by review. App Review's private contact fields are separate: the owner must supply a real contact name, email address, and phone number directly in App Store Connect. None has been provided for this draft.

## App Privacy preparation — declaration remains open

The code supports these observations:

- `AppState.swift` stores diary, foods, preferences, and an optional profile locally; migration retains earlier UserDefaults records. `Models.swift` defines the saved fields. There is no HealthKit integration or developer cloud sync.
- `OpenFoodFactsClient.swift` sends a barcode in an HTTPS product request, plus a Nibble/version User-Agent. No stored diary or profile is included. The receiving provider also sees source IP and other request information.
- `BarcodeScannerView.swift` recognizes barcode metadata locally; it does not upload images. No analytics, ad, or third-party crash SDK appears in the source.
- `PrivacyInfo.xcprivacy` currently declares no tracking, an empty collected-data list, and UserDefaults reason `CA92.1`. That file is evidence of the present declaration, not validation of third-party retention or the final App Store privacy label.

Apple distinguishes on-device processing from collection and considers off-device data retained beyond servicing a request to be collected. Finalize the label only after investigating Open Food Facts' production request logging, retention, purposes, and linkage, including IP handling. Do not assume an optional barcode feature qualifies for optional disclosure, or select Data Not Collected merely because the diary is local. Classify any retained request data by its actual use; do not guess identifier, diagnostics, location, or search categories. Review optional GitHub support submissions separately. See [Apple's App Privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).

The provider's [privacy page](https://world.openfoodfacts.org/privacy) returned a bot-block page during research, so its current production retention practices were not verified. This remains a release-owner check, not a claim that logging occurs or does not occur. Ensure the final privacy manifest, public policy, in-app disclosure, and App Store Connect answers agree with the shipped build. Also resolve the backup handling item in the [release checklist](release-checklist.md).

## Age-rating evidence — no submitted answers

Apple's [current content definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions) explicitly include calorie tracking in Health or Wellness Topics. That topic is present in Nibble and must be represented truthfully. Medical or Treatment Information is a separate question: review the estimator, target guidance, linked material, and all release content against Apple's wording before choosing its presence/frequency. This draft does not pre-answer that clinical-content classification.

`OnboardingView.swift` and `Models.swift` restrict estimated profiles to ages 18–100 and display the pregnancy/breastfeeding exclusion. Just start logging and Set my own do not ask for age, so this is not an app-wide age assurance system. Do not infer a 4+ or 18+ App Store rating from those code facts alone.

The submitter must complete every applicable live question and review Apple's calculated regional and older-OS ratings. The owner must also decide the intended audience and whether a higher rating is appropriate; the draft does not select Made for Kids or declare the app clinically suitable for children. Apple explains [rating calculation and overrides](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating).

## App Review notes draft

Rehearse these steps on the signed release candidate and then paste the notes below, updating anything that changed. No login credentials are needed. Enter the owner's private review contact separately.

```text
Nibble is a free iPhone food diary. It has no account/login, subscriptions, in-app purchases, or ads. A clean installation opens onboarding; no reviewer account or seeded diary is required.

1. Tap "Just start logging" to enter Diary without a profile or target. For optional setup, tap "Let's make it yours" and choose Estimate for me, Set my own, or Just track. You > Tune my plan reopens those choices.

2. Tap Add food > Find a food. Search for Banana, select the food, choose a portion and meal, and add it. The plus controls quick-add one serving; the star saves a favorite. Text search covers the starter library and saved foods.

3. In Add food, tap the pencil button ("Enter calories or create a food"). Enter fictional sample food "Review snack", portion "1 serving", and 100 calories. Leave Add macros off, choose a portion, and log it. The diary indicates partial macros. Custom foods are saved when logged.

4. Tap a Diary entry to change its portion or meal. Its three-dot menu includes Delete. Undo is offered after a diary change. The date control opens earlier days; Patterns shows recent logged days and an average that excludes unlogged days.

5. Add food > Scan barcode supports typing a product barcode and camera scanning. The field's example is 3017620422003; this is a live third-party product lookup, not a fixed fixture, and availability or nutrition completeness can change. Camera scanning needs a physical iPhone and permission. Denied camera access offers Settings and typed entry. An unsuccessful lookup displays an error and offers Enter the label instead. Previously saved foods remain usable offline; new lookups require internet access.

6. You > About targets & food data explains estimates and links the calculation/data sources. Automated profiles accept ages 18-100 and describe exclusions for pregnancy/breastfeeding. The 1,500-calorie estimate floor is a product guardrail, not a clinical minimum. The macro starting split is 25% protein, 45% carbs, and 30% fat. The app does not promise weight outcomes or offer diagnosis.

The diary and optional body profile are saved locally. Barcode requests go to Open Food Facts with the barcode and standard network/request information; the saved diary and body profile are not sent. The app has no HealthKit integration. Delete removes an individual diary entry; saved foods and earlier migration records remain. All data in the current app container can be removed with iOS Settings > General > iPhone Storage > Nibble > Delete App. Device backups are managed separately.
```

The source now includes privacy/support links under You; add that location to the review notes after the pages are public and the links have passed device verification. Do not present the macOS `--demo` preview as the submitted iPhone app or claim these flows have passed device testing. If used during development, `--demo` keeps sample data in memory; submission must be verified with a normal launch and persistent storage.

## Screenshot plan

Capture the actual release-candidate iOS UI on an iPhone or iOS Simulator with fictional data. Suggested sequence: populated Diary; Find a food with favorites; a barcode product portion; Make a food; Patterns; You with the target explanation. Verify camera behavior separately on hardware.

Apple accepts 1–10 JPEG/PNG screenshots without transparency. Plan portrait captures at 1320 × 2868 for the 6.9-inch slot; 1290 × 2796 and 1260 × 2736 are also listed. A 6.5-inch set is required if no 6.9-inch set is provided. Recheck the [current screenshot specification](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) for the final device family. If iPad support is added, capture the required iPad set too.

`Design/` boards and `Tools/render.sh` output are macOS design previews with an illustrative status bar, as the README states. They are not iOS screenshots and must not be submitted as such. Apple's [review guidance](https://developer.apple.com/app-store/review/) requires screenshots that accurately represent the app and matching device type. No App Store screenshot assets or preview video were produced in this documentation task.
