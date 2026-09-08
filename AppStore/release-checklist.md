# Nibble — App Store release checklist

Prepared September 5, 2026. The app builds for iOS, but has not been signed, uploaded, submitted, or approved. No purchase or membership enrollment has been made.

## Completed preparation

- [x] Native iPhone app, app icon, camera purpose string, privacy manifest, and shared scheme.
- [x] 37 diary/storage scenarios (600 assertions) and 150 barcode checks.
- [x] Full iPhone Simulator Debug and unsigned iPhone Release builds on GitHub's standard macOS 26 runner.
- [x] Privacy/support documents, in-app links under You, listing copy, and review-notes draft.
- [x] [Pull request #1](https://github.com/bond-is-here/nibble/pull/1) opened with signed commits.
- [x] Importable [Ojas-equivalent branch rules](../.github/rulesets/README.md) recorded. JSON files do not activate protections; verify GitHub Settings separately.

Initial build evidence:

| Item | Result |
| --- | --- |
| Commit tested | `00bc15355f0cc682612bf92446c8c53cb073ec50` |
| Workflow | [Successful run 34000992086](https://github.com/bond-is-here/nibble/actions/runs/34000992086) |
| Xcode | 26.6, build 17F113 |
| SDK | iOS SDK major version >=26 check passed |
| Shared checks | Passed |
| iPhone Simulator Debug | Passed |
| Unsigned iphoneos Release | Passed |
| Signed archive / physical-device tests | Not performed |

Use the [latest workflow result](https://github.com/bond-is-here/nibble/actions/workflows/ios.yml) for subsequent commits. Build success does not prove runtime behavior, signing readiness, or App Store acceptance. Git commit signing is separate from Apple app signing.

## 1. Account and no-payment boundary

- [ ] Sign in to App Store Connect and confirm an existing active Apple Developer Program membership or authorized team. The browser currently requires sign-in, so membership is unknown.
- [ ] If there is no membership, stop before payment. A free Apple account supports limited personal-device testing, not App Store distribution. Standard membership is US$99/year, with regional pricing and waivers for eligible organizations. [Membership comparison](https://developer.apple.com/support/compare-memberships/), [enrollment](https://developer.apple.com/programs/enroll/).
- [ ] Confirm control of `com.caloriecompass.app`, or choose/register an available identifier before the first release. Preserve continuity if an existing Calorie Compass listing actually exists; repository history does not prove one does.
- [ ] Verify availability and rights to the proposed name Nibble, and create/select the correct iOS app record.
- [ ] Supply the actual seller/copyright identity and private App Review contact name, email, and phone directly in App Store Connect. None should be invented or committed to this public repository.
- [ ] Set price Free, with no subscriptions or in-app purchases. Do not initiate a Paid Apps Agreement, banking setup, or purchase for this release. Any agreement acceptance remains with the authorized account owner. [Apple's agreements guidance](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/).
- [ ] Choose territories, resolve applicable trader/contact declarations, and decide release timing.

## 2. Signing and device QA

- [ ] Use a full Xcode 26-or-later installation with iOS 26 SDK or later for upload. This requirement has applied since April 28, 2026; the app's iOS 17 deployment target is a separate runtime minimum. [Apple's SDK notice](https://developer.apple.com/news/?id=ueeok6yw).
- [ ] Produce and validate a signed Release archive for a generic iOS device using the correct team and provisioning. Verify bundle ID, entitlements, app icon, camera string, privacy manifest inclusion, version/build uniqueness, and archive validation.
- [ ] Review export-compliance answers against the final archive. The project currently sets `ITSAppUsesNonExemptEncryption = NO`; confirm it remains accurate for the shipped code and dependencies.
- [ ] Test a normal launch without `--demo`: all three plan modes, metric/imperial input, calorie-only foods, favorites/recents, serving and gram/milliliter portions, edit/delete/Undo, historical dates, and Patterns.
- [ ] Test migration, retained legacy records, persistence after relaunch, storage failure, and unreadable archives with fixtures. Only use disposable sample data for uninstall/reinstall tests.
- [ ] On a physical iPhone, test camera allow/deny/restricted states, Settings return, reopening, background/foreground, and package scans. Test typed lookup, incomplete/unknown products, timeout/offline/rate limits, manual fallback, and saved foods offline.
- [ ] Check supported phone sizes/OS versions, keyboard layout, larger text, VoiceOver, and Reduce Motion. macOS design previews are not evidence of iPhone UI or camera QA.

## 3. Privacy and support gates

- [ ] Verify the public [privacy policy](https://github.com/bond-is-here/nibble/blob/main/PRIVACY.md), [support page](https://github.com/bond-is-here/nibble/blob/main/SUPPORT.md), and [Issues contact](https://github.com/bond-is-here/nibble/issues) after merge, without authentication.
- [ ] Verify in-app Privacy policy and Help & support links under You on the release candidate. Apple requires an accessible policy in both the app and store metadata. [Review Guidelines 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/).
- [ ] Confirm GitHub Issues is an acceptable support route for the intended territories/review and supply any additional actual contact information required by the [Support URL field](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information). Warn against posting personal health information publicly.
- [ ] Verify Open Food Facts' handling of barcode requests, source IPs, logs, retention, purpose, and linkage. Its privacy page was bot-blocked during preparation; no retention guarantee has been established.
- [ ] Complete App Privacy using [Apple's definitions](https://developer.apple.com/app-store/app-privacy-details/) and the [code evidence](metadata.md#app-privacy-preparation--declaration-remains-open). Do not choose Data Not Collected just because the diary is local. Reconcile any retained provider/support data with the manifest and policy.
- [ ] Verify health-data storage protections on a physical iPhone. The dedicated storage folder now excludes diary/profile and migration recovery records from backups; iOS writes use complete file protection. Legacy UserDefaults values move to a verified recovery file before removal, including on already-migrated installations. Test lock/unlock, migration, and a device backup against [Guideline 5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/) and [Apple's backup guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup). Existing external backup copies remain outside the app's control.
- [ ] Verify deletion instructions: removing an entry retains its saved food and legacy migration records; Delete App removes the current app container, while Offload App keeps data. Backups and third-party support records are separate. The app creates no HealthKit records.

## 4. Listing, screenshots, and submission

- [ ] Review [metadata.md](metadata.md) against the final build. Subtitle: 29 characters; keywords: 88 ASCII bytes; description: 1,839 characters. Confirm name, category Health & Fitness, free pricing, and actual rights-holder copyright.
- [ ] Complete the live age-rating questionnaire. Calorie tracking is a Health or Wellness Topic; evaluate Medical or Treatment Information separately. The estimator's adult restriction is not an app-wide age gate, and no final rating is preselected. [Definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions), [rating setup](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating).
- [ ] Rehearse the draft reviewer steps. No login should be needed, and manual entry must work when the live barcode provider fails. Keep estimate limitations and data attribution accessible.
- [ ] Capture actual iOS screenshots using fictional data and [Apple's required dimensions](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications). Follow the [screenshot plan](metadata.md#screenshot-plan). Do not submit the macOS DEMO/design previews, even if resized.
- [ ] Verify artwork rights and Open Food Facts attribution/license.
- [ ] Upload the validated signed build, finish privacy/age-rating/contact fields, and submit only after all gates pass. Record Apple's review outcome; submission is not approval or availability.

Recheck linked requirements at the actual submission date.

## Macro Mix update — build 3

- [x] Macro rings/details, saved split editor, local suggestion engine, portion preview, and weekly macro patterns implemented.
- [x] Local shared SwiftUI typecheck, existing 750 assertions/checks, and 329 new Macro Mix checks passed.
- [x] Native macOS design previews rendered and visually inspected. These remain design previews, not iOS screenshots.
- [x] Macro Mix at commit `4232629` passed both iOS build configurations in [CI run 34177188557](https://github.com/bond-is-here/nibble/actions/runs/34177188557).
- [ ] Verify iPhone runtime after completing Xcode's first-launch license/setup. Check the newest commit's CI separately after each functional change.
- [ ] Test tap-to-explore, switching macro focus, save/cancel/reset/invalid splits, scaled gram targets, partial/no-target/history states, and suggestions → portion → save on iPhone.
- [ ] Verify existing-diary upgrade, reduced motion, small screens, larger text, and VoiceOver. Recheck all earlier release/privacy gates; this update does not resolve them automatically.

## Storage hardening

- [x] Exclude the Nibble folder from backups before storing health data; use complete file protection for iOS writes and existing files.
- [x] Preserve and verify original legacy property-list values in protected recovery storage before removing the three UserDefaults values. Interrupted cleanup resumes, malformed records stay recoverable, and existing JSON takes precedence.
- [x] All 1,079 diary/barcode/macro assertions and 28 protected-storage checks passed locally, including failed writes, migration retries, actual backup-exclusion metadata, and demo isolation.
- [ ] Confirm this commit's iOS CI, then verify protection during physical-device lock/unlock and backup. These local checks do not exercise iOS data-protection behavior.
