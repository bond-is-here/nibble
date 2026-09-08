# Nibble support

Last updated: September 5, 2026

For app problems, questions, or feature requests, use [Nibble GitHub Issues](https://github.com/bond-is-here/nibble/issues). Search existing issues first, then open a new issue if needed. Posting requires a GitHub account; using Nibble does not.

Issues are public. Do not include health or medical information, body measurements, personal diary entries, diary files, passwords, or other private details. Use fictional food entries when demonstrating a problem, and remove private information from any screenshots. No private support email is published here.

## Reporting a problem

Include your iPhone model, iOS version, Nibble version/build if known, the screen or action involved, and what you expected versus what happened. Describe reproducible steps using sample data. If the app shows an error, include its wording only after checking it for private information. The maintainers cannot access your on-device diary.

## Getting started

Choose Just start logging on the welcome screen to use the diary without a body profile or target. Let's make it yours opens setup, where you can choose Estimate for me, Set my own, or Just track. Later, use You > Tune my plan to change the plan. The estimate form supports metric and imperial units.

Use Add food to search the starter library and your saved foods, open recent foods or favorites, scan a barcode, or enter a food yourself. Text search is local; it does not search the entire Open Food Facts database by name. For custom food entry, tap the pencil button (accessibility label: Enter calories or create a food), provide a name, portion, and calories, then choose a portion and log it. Leave Add macros off if you do not know the macros; the diary labels those totals as partial. Custom foods are saved when logged.

## Barcode or camera trouble

- Open Add food > Scan barcode. On a physical iPhone, Open camera asks for camera permission. If access is off, use Open Settings in the scanner or iOS Settings > Privacy & Security > Camera > Nibble. You can always close the scanner and type the barcode.
- Typed lookup accepts valid 8-, 12-, 13-, or 14-digit product barcodes with a valid check digit. Check every digit, including leading zeroes. It needs an internet connection.
- Open Food Facts may not have the product, may be temporarily unavailable, or may lack complete nutrition and a clear gram/milliliter basis. Use Enter the label instead after an error, or the pencil button to make a food manually. Compare returned nutrition and portions with the actual package before logging.
- Previously saved foods and the diary work offline. A new barcode request does not. A simulator cannot provide the physical-camera test required for release.

## Correcting the diary

Use the date control on Diary to open today or an earlier day. Tap an entry to edit its portion or meal. Open its three-dot menu and choose Delete to remove that diary entry; use the Undo message immediately after a diary change to reverse it. Deleting an entry leaves its saved food available for reuse.

Patterns shows the recent week and an average calculated from days with entries. Unlogged days are excluded, and partially logged days can make the average lower.

## Targets and food values

### Macro Mix and the mixing desk

On Diary, tap Explore in Macro Mix or tap Protein, Carbs, or Fat. The three rings show progress toward the current gram targets; without targets they show each macro's share of known macro energy. Tap a macro in the full view for its current amount, meal breakdown, and largest logged-food contributors. Partial macro data is clearly labeled.

“Next little bite” runs locally. It compares the remaining proportions of your targets and ranks foods in the starter/saved library with all three macro values. Suggested amounts are the food's displayed serving, not a personalized portion recommendation. Tap to review and adjust the portion; nothing logs automatically. Suggestions pause for calorie-only entries, past dates, no targets, or reached calorie/all-macro targets. They do not account for allergies, ingredients, or dietary restrictions.

Open the mixing desk from Macro Mix or You > Tune macro mix. Enter whole percentages from 1–98 totaling 100, check the gram preview, and Save my mix. Reset changes the draft only until saved. Without a calorie target, the mix saves as a preference without creating targets. Changing a calorie target recalculates grams with your saved mix; old food entries stay unchanged. Historical comparisons use the current plan, not historical targets.

Portion screens show before/after daily macro grams as you edit the amount. An edited portion replaces the old entry in the preview. Patterns' “Seven days, three colors” shows known macro energy proportions and gram averages only across days with macro data. Calorie-only days are excluded from these averages, unlike the separate calorie average. Incomplete days carry a ◐ marker, and partial logging can lower averages.

### Estimates

Targets are estimates, not prescriptions or guaranteed weight outcomes. The automated estimate form accepts ages 18–100 and states that its estimates exclude pregnancy and breastfeeding. Its 1,500-calorie floor is an app guardrail, not an individual medical minimum. You > About targets & food data explains the calculation, macro split, and data sources. This support channel provides help with the software, not personalized medical or dietary advice.

## Storage errors and starting over

If a change cannot be saved, check available iPhone storage and retry. If an existing diary cannot be opened or an earlier Calorie Compass diary cannot be imported, Nibble preserves the original data and displays an error. Reopen after addressing storage problems; report a persistent error using its wording and sample reproduction steps, without attaching your diary. Do not delete the app as a troubleshooting step if you need to keep that local diary. There is no in-app export or developer cloud recovery service.

To intentionally erase all local Nibble information, open Settings > General > iPhone Storage > Nibble > Delete App and confirm. This removes the app container, including locally saved health/body information and original migration records. Offloading keeps the data. Backups and publicly posted support requests are separate: follow the [privacy policy's retention and deletion instructions](PRIVACY.md#retention-and-deletion), including Apple's backup controls. Nibble does not use Apple Health/HealthKit, so it has no HealthKit records to remove.

## Price and privacy

The diary and retained migration records are kept in a local folder excluded from device backups. They use complete file protection on iOS. If you see a storage protection error, unlock the device, check free storage, and reopen Nibble. An unreadable original is preserved; do not uninstall as a troubleshooting step unless you intend to erase your data. Older backup copies are managed separately through iOS or your computer. The app has no automatic cloud recovery if the device is lost.

This release is planned as a free app with no subscriptions or in-app purchases. Nibble has no sign-up, app analytics, or app cloud sync. Barcode lookups contact Open Food Facts and expose the barcode and ordinary network information to that provider. See the [privacy policy](PRIVACY.md) for storage, third-party requests, support posts, and deletion details.
