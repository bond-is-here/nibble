# Nibble — App Store release checklist

Last audited September 8, 2026. This is release-readiness documentation, not a customer-ready or submitted-release claim. Nibble has not been signed for distribution, uploaded, submitted, or approved. No new account, agreement, payment, or external write was made in this audit.

## Current release status — audited, still gated

Nibble is being reviewed on branch `codex/iphone-release-qa`. Main-branch PR2 is merged; [PR3 is open](https://github.com/bond-is-here/nibble/pull/3). This release pass includes canonical GTIN identity matching, legacy favorite compatibility, delayed barcode-flow coverage, and direction-aware compact-screen UI navigation.

| Area | Current evidence | Status |
| --- | --- | --- |
| Local checks | `Tools/check.sh` passed 1,154 checks: 618 diary, 159 barcode, 331 macro, 28 storage, 12 palette, and 6 reporter. | Verified locally; not a release approval. |
| Verified iPhone UI baseline | `febc521`, [run 34181081328](https://github.com/bond-is-here/nibble/actions/runs/34181081328): artifact locally verified at iPhone Air / iOS 26.2 with 7 passed, 0 failed, 0 skipped; screenshots inspected. | Historical baseline; it predates later Dynamic Type and barcode-cancellation changes. |
| Later CI | At `440c7ec`, [run 34182565224](https://github.com/bond-is-here/nibble/actions/runs/34182565224) had standard-device success for both builds and the UI step. The compact UI summary was 5 passed, 3 failed; all three failures were the old one-direction scroll helper overshooting off-screen targets. | Fixed in this release pass; revalidate both sizes in the follow-up run. |
| Latest recorded CI | [Run 34183944655](https://github.com/bond-is-here/nibble/actions/runs/34183944655) at `da25adb` completed with the same compact navigation failure after passing shared checks and both builds. Ten UI journeys are configured per size. | Superseded by the follow-up run for this release pass; no ten-journey pass claim yet. |
| Access and toolchain | Browser artifact review is available. Local full Xcode still requires the owner’s license/first launch. | Open. |
| Distribution | Apple account/team, signing access, membership, identifier continuity, seller/copyright identity, and App Review contact are unknown. No upload, payment, or agreement acceptance has occurred. | Open. |
| Hardware and broad QA | Physical-iPhone camera, lock/backup behavior, broad VoiceOver, and supported-OS/device QA have not been performed. | Open. |
| Provider and privacy label | Open Food Facts API v2 remains supported but deprecated. The current provider contact/registration, production request retention, and final App Store privacy answer are unresolved. | Open; never finalize Data Not Collected from local-only storage alone. |

The latest local checks validate implementation behavior, including the local storage and request configuration. They do not establish provider-side retention, physical-device protection behavior, signed-release behavior, App Review acceptance, or customer readiness.

## 1. Account, identity, and no-payment boundary

- [ ] Sign in to App Store Connect and confirm an active Apple Developer Program membership or authorized team. Do not infer this from repository access.
- [ ] Confirm control of `com.caloriecompass.app`, or choose/register an available identifier before the first release. Preserve continuity only if an existing Calorie Compass listing is actually confirmed.
- [ ] Verify availability and rights to the proposed name Nibble, and create/select the correct iOS app record.
- [ ] Supply the actual seller/copyright identity and private App Review contact name, email, and phone directly in App Store Connect. Do not invent or commit these details to this public repository.
- [ ] Set price Free, with no subscriptions or in-app purchases. Any agreement acceptance, banking setup, or membership payment remains with the authorized account owner; none was initiated here.
- [ ] Choose territories, resolve applicable trader/contact declarations, and decide release timing.

## 2. Signing, toolchain, device, and runtime QA

- [ ] Complete the owner’s local Xcode license/first-launch setup, then use a full Xcode 26-or-later installation with the required iOS SDK for the final upload. CI build success does not replace this gate.
- [ ] Produce and validate a signed Release archive for a generic iOS device using the correct team and provisioning. Verify bundle ID, entitlements, icon, camera purpose string, privacy manifest inclusion, version/build uniqueness, and archive validation.
- [ ] Review export-compliance answers against the final archive. The project currently sets `ITSAppUsesNonExemptEncryption = NO`; confirm that remains accurate for the shipped code and dependencies.
- [ ] Test a normal launch without `--demo`: all three plan modes, metric/imperial input, calorie-only foods, favorites/recents, serving and gram/milliliter portions, edit/delete/Undo, historical dates, Patterns, and Macro Mix.
- [ ] Test migration, retained legacy records, persistence after relaunch, storage failure, and unreadable archives with fixtures. Use disposable sample data only for uninstall/reinstall tests.
- [ ] On a physical iPhone, test camera allow/deny/restricted states, Settings return, reopening, background/foreground, and package scans. Test typed lookup, incomplete/unknown products, timeout/offline/rate limits, manual fallback, and saved foods offline.
- [ ] Check supported phone sizes/OS versions, keyboard layout, larger text, VoiceOver, and Reduce Motion. MacOS design previews are not evidence of iPhone UI, camera, or accessibility QA.

## 3. Privacy, support, storage, and provider gates

- [ ] After PR3 is merged, verify the public [privacy policy](https://github.com/bond-is-here/nibble/blob/main/PRIVACY.md), [support page](https://github.com/bond-is-here/nibble/blob/main/SUPPORT.md), and [Issues contact](https://github.com/bond-is-here/nibble/issues) load without authentication.
- [ ] Verify the in-app Privacy policy and Help & support links under You on the signed release candidate. Keep public policy, in-app disclosure, store metadata, and the shipped behavior aligned.
- [ ] Resolve the Support URL requirement for the chosen territories. GitHub Issues is the planned public support route, but the current page intentionally publishes no private email or legal address; confirm whether actual legal address, email, and telephone details must be exposed and provide real details if required. Never invent contact information.
- [ ] Verify Open Food Facts’ production handling of barcode requests, source IPs, logs, retention, purpose, and linkage. Nibble’s ephemeral session and no-local-HTTP-history behavior do not prove provider-side deletion or non-retention.
- [ ] Resolve the provider integration gate: obtain the actual owner contact for the User-Agent, complete the provider’s requested app/usage registration or form as applicable, and decide whether to migrate from the still-supported but deprecated v2 product endpoint. The current code identifies itself with `Nibble/1.0 (+https://github.com/bond-is-here/nibble)`, not an invented contact email. A successful lookup is not proof of registration, approval, or privacy-label correctness.
- [ ] Complete App Privacy using Apple’s definitions and the actual provider/support facts. Do not select Data Not Collected until the third-party request-retention question is resolved; classify any retained request data by its actual use and review optional GitHub support submissions separately.
- [ ] Verify on a physical iPhone that the dedicated `Application Support/Nibble` directory and its diary/profile/migration files behave as intended during lock/unlock and backup. The source marks the directory excluded from future backups and uses complete file protection for iOS writes; local storage checks verified those settings, but physical-device behavior remains unverified. Existing external backup copies remain outside Nibble’s control.
- [ ] Verify deletion instructions: deleting an entry retains its saved food and legacy migration records; Delete App removes the current app container, while Offload App keeps data. Backups, Open Food Facts records, and public support posts are separate. Nibble creates no HealthKit records.

## 4. Listing, screenshots, review, and submission

- [ ] Review [metadata.md](metadata.md) against the final signed build. Recheck field lengths, Macro Mix wording, the local-storage/backup wording, provider disclosure, name, category, price, and actual rights-holder copyright.
- [ ] Complete the live age-rating questionnaire. Calorie tracking is a Health or Wellness Topic; evaluate Medical or Treatment Information separately. Do not infer a final rating from the adult-only estimate form.
- [ ] Rehearse the draft reviewer steps on the release candidate. No login should be needed, and manual entry must work when the live barcode provider fails. Keep estimate limitations and data attribution accessible.
- [ ] Capture actual iOS screenshots using fictional data and Apple’s required dimensions. Follow the [screenshot plan](metadata.md#screenshot-plan). Do not submit MacOS design previews, even if resized.
- [ ] Verify artwork rights and Open Food Facts attribution/license.
- [ ] Upload the validated signed build, finish privacy/age-rating/contact fields, and submit only after every applicable gate passes. Record Apple’s review outcome; submission is not approval or availability.

## Implementation evidence carried forward

- [x] Local storage implementation marks the dedicated folder excluded from backups, applies complete file protection to iOS writes/existing files, and preserves legacy UserDefaults values in protected recovery storage before removal. The 28 local storage checks include failed writes, migration retries, backup-exclusion metadata, and demo isolation.
- [x] Barcode networking uses an ephemeral session with no HTTP cache, cookies, or credential storage. Local tests cover request configuration, cancellation, delayed responses, offline fallback, and saved-food reuse. These are client-side checks only; provider retention and contact/registration remain open.
- [x] Macro Mix, portion previews, weekly macro summaries, and local suggestions are implemented. The standard split is 25% protein, 45% carbs, and 30% fat by energy; unknown macros remain unknown and are not silently converted to zero. The 331 macro checks are local evidence, not a substitute for current iPhone runtime/accessibility QA.
- [x] The shared scheme, UI target, named-failure reporter, larger-text branches, and ten-journey matrix are configured. Configuration is not a passed runtime or accessibility result.

## Preserved historical evidence — not current certification

- `bd1ac48` / [run 34177621406](https://github.com/bond-is-here/nibble/actions/runs/34177621406): prior storage-hardening commit passed shared checks and both iOS builds.
- `4232629` / [run 34177188557](https://github.com/bond-is-here/nibble/actions/runs/34177188557): prior Macro Mix commit passed both iOS build configurations.
- [Run 34178369288](https://github.com/bond-is-here/nibble/actions/runs/34178369288) recorded three earlier iPhone journeys; later changes mean it is historical evidence only.
- `febc521` / [run 34181081328](https://github.com/bond-is-here/nibble/actions/runs/34181081328) is the latest locally verified seven-journey baseline described above, including inspected iPhone screenshots.
- `440c7ec` / [run 34182565224](https://github.com/bond-is-here/nibble/actions/runs/34182565224) is retained as qualified build/UI evidence: standard-device success, compact UI failure with public exit 65, and no established root cause. The exact eight-test summaries and screenshots were not downloaded.

Earlier notes cited 1,079, 1,116, 1,128, or 1,134 local checks as features landed. Those are historical snapshots; the current aggregate is 1,154 with the breakdown in the status table. Recheck all linked platform and provider requirements at the actual submission date.
