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
- [ ] Resolve the provider's current [API integration requirements](https://openfoodfacts.github.io/openfoodfacts-server/api/): actual owner contact for the User-Agent, usage registration, and a reviewed migration from the still-supported but deprecated v2 product endpoint. The present agent links to the public repository; it does not invent a contact email. Do not treat a successful product lookup as approval of the integration or privacy declaration.
- [ ] Complete App Privacy using [Apple's definitions](https://developer.apple.com/app-store/app-privacy-details/) and the [code evidence](metadata.md#app-privacy-preparation--declaration-remains-open). Do not choose Data Not Collected just because the diary is local. Reconcile any retained provider/support data with the manifest and policy.
- [ ] Verify health-data storage protections on a physical iPhone. The dedicated storage folder now excludes diary/profile and migration recovery records from backups; iOS writes use complete file protection. Legacy UserDefaults values move to a verified recovery file before removal, including on already-migrated installations. Test lock/unlock, migration, and a device backup against [Guideline 5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/) and [Apple's backup guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup). Existing external backup copies remain outside the app's control.
- [ ] Verify deletion instructions: removing an entry retains its saved food and legacy migration records; Delete App removes the current app container, while Offload App keeps data. Backups and third-party support records are separate. The app creates no HealthKit records.

## 4. Listing, screenshots, and submission

- [ ] Review [metadata.md](metadata.md) against the final build. Recheck listing field lengths after edits, including the Macro Mix and no-backup disclosures. Confirm name, category Health & Fitness, free pricing, and actual rights-holder copyright.
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
- [x] Storage commit `bd1ac48` passed all shared checks and both iOS builds in [CI run 34177621406](https://github.com/bond-is-here/nibble/actions/runs/34177621406).
- [ ] Verify protection during physical-device lock/unlock and backup. Local and build-only checks do not exercise physical iOS data-protection behavior.

## iPhone runtime regression tests

- [x] Add a shared-scheme XCTest UI target and a simulator runner, with UUID-isolated real storage enabled only in Debug builds.
- [x] Cover fresh onboarding, quick logging, delete/Undo, portion-preview replacement, edited-entry Undo, calorie-only foods, fractional manual targets, valid/invalid macro splits, reset/cancel, and relaunch persistence.
- [x] In [run 34178369288](https://github.com/bond-is-here/nibble/actions/runs/34178369288), three iPhone journeys passed: calorie-only foods/relaunch, live portion previews/edit/Undo, and quick logging/delete/Undo/relaunch.
- [ ] Verify the complete UI suite after fixing its text-replacement helper: the first run inserted `30` before the existing `25` in the macro field. The manual-target/custom-split journey did not complete, so its remaining assertions are still unverified.
- [ ] Inspect the resulting iPhone screenshots, then test additional supported screen sizes and accessibility settings. Complete physical camera, signing, account, and privacy gates above before release.

## Barcode network privacy

- [x] Replace the shared networking session with an ephemeral session, no HTTP cache, no cookie handling, and no credential store. Logged and favorited products still persist through the protected diary archive.
- [x] All 1,116 local checks passed, including nine new request/configuration assertions. These verify client behavior, not provider-side retention.
- [ ] Verify this change's iOS CI and complete the provider/contact/privacy checks above.

## Expanded customer-journey checks

- [x] Correct the UI text helper's placeholder-equality assumption. A real saved `25` must be cleared even when the placeholder is also `25`; backspacing an empty field is harmless. The follow-up run exposed this remaining helper error before the custom-split journey could complete.
- [x] Fix Patterns to display `0` for an actual logged zero-calorie day; reserve `—` for a week with no logged days. Add a relaunch regression journey.
- [x] Add iPhone journeys for rejected underage estimates and saved metric profiles, plus invalid barcode → manual macros → 200 ml portion → saved favorites.
- [x] Pin the artifact uploader to Node-24-based v7.0.1 after CI reported the v4 runtime deprecation.
- [ ] Run and inspect all seven UI journeys after these changes. Local checks do not substitute for the runtime assertions or screenshot review.

## Portion-screen usability and current QA

- [x] Inspect actual iPhone Air screenshots from run `34179135984`: diary totals, calorie-only macro state, and two-serving preview. The preview's Save button was below the initial viewport.
- [x] Move the portion Save action and validation feedback into a bottom safe-area bar; add an assertion that Save is reachable before scrolling. Keep the nutrition details scrollable.
- [x] Replace decorative text symbols that rendered as green emoji tiles on iOS with accessibility-hidden SF Symbols.
- [x] In [run 34179784015](https://github.com/bond-is-here/nibble/actions/runs/34179784015), shared checks and both iOS builds passed. The expanded UI run failed on the estimate's formatted `2,100` label and the macro field's retained `25` during replacement. Neither incomplete journey is certified.
- [x] Correct the locale-specific display expectation and use the iOS Select All editing action for percentage replacement instead of assuming the caret position.
- [x] Verify the new commit's complete simulator result and inspect its sticky-button screenshots (evidence below). Physical-device, accessibility, privacy, signing, and account gates remain open.
- [x] Follow-up commit `febc521` passed shared checks, both iOS builds, and the UI-test step in [run 34181081328](https://github.com/bond-is-here/nibble/actions/runs/34181081328). This result predates the Dynamic Type changes below.
- [x] Download and verify that run's artifact digest, read its summary (7 passed, 0 failed, 0 skipped on iPhone Air / iOS 26.2), and inspect actual iPhone screenshots of the visible portion Save, saved 30/40/30 split, 200 ml manual-label preview, and zero-calorie average.

## Dynamic Type and compact-screen pass

- [x] Use scaled fonts for diary, food entry, onboarding, profile, Patterns, and Macro Mix text. Stack dense rows at accessibility sizes; keep decorative ring labels fixed because accessible, scalable values are repeated outside the rings.
- [x] Make the entire food picker scrollable, grow form/button heights, enlarge small action targets, and keep the bottom navigation usable at larger sizes. Respect Reduce Motion for date, onboarding, and toast transitions.
- [x] Darken secondary text; all 12 shared ink/muted contrast pairs meet 4.5:1 on the actual six surface colors. All 1,128 local checks and the shared warnings-as-errors typecheck pass.
- [x] Inspect macOS previews of regular and accessibility-layout diary, portion, and Macro Mix screens. They verify shared layout branching, not iOS font scaling or VoiceOver.
- [x] Add a largest-text iPhone journey with real isolated persistence, a scaling assertion, visible portion Save, and XCTest clipping/description/contrast audits. Add independent regular and SE-sized CI jobs without cancelling one on the other's failure.
- [ ] Run and inspect both eight-journey jobs and their actual iOS screenshots after this pass. An audit of one visible screen does not certify whole-app accessibility; complete VoiceOver, intermediate text sizes, older supported iOS versions, and physical-device gates above.
- [x] The first matrix run (`34182133064`) exposed a Debug-only compiler error: Reduce Motion is a read-only environment value. Remove the attempted test override; app behavior continues to read the real system preference. Add a Debug shared-code typecheck so test-only branches are checked locally as well. Re-run both iPhone jobs; no accessibility runtime result exists from this failed build.

Implementation follows Apple's [Dynamic Type guidance](https://developer.apple.com/videos/play/wwdc2024/10074/) and [XCTest accessibility audit guidance](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app). Do not treat implemented support or configured audits as a passed release gate.

## Pending-lookup review

- [x] Cancel in-flight barcode work when switching to manual food entry, opening the camera, editing the typed code, leaving barcode mode, or dismissing the picker. Existing cancellation guards discard late results; a manual label draft must not be replaced by a stale product response.
- [x] Clarify the portion caption and give the manual-label fallback a 44-point action height. All 1,128 local checks and both shared-code typechecks pass after the change.
- [ ] Verify the follow-up iPhone run. The existing HTTP fixture suite verifies transport cancellation, but it does not exercise the timing of a manual-form switch during a slow lookup; include that scenario in device QA.
- [x] Refresh draft store copy to describe Macro Mix and clearly disclose that the diary is not cloud-synced or included in device backups. This remains unpublished draft metadata.
