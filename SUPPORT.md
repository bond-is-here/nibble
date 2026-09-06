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

Targets are estimates, not prescriptions or guaranteed weight outcomes. The automated estimate form accepts ages 18–100 and states that its estimates exclude pregnancy and breastfeeding. Its 1,500-calorie floor is an app guardrail, not an individual medical minimum. You > About targets & food data explains the calculation, macro split, and data sources. This support channel provides help with the software, not personalized medical or dietary advice.

## Storage errors and starting over

If a change cannot be saved, check available iPhone storage and retry. If an existing diary cannot be opened or an earlier Calorie Compass diary cannot be imported, Nibble preserves the original data and displays an error. Reopen after addressing storage problems; report a persistent error using its wording and sample reproduction steps, without attaching your diary. Do not delete the app as a troubleshooting step if you need to keep that local diary. There is no in-app export or developer cloud recovery service.

To intentionally erase all local Nibble information, open Settings > General > iPhone Storage > Nibble > Delete App and confirm. This removes the app container, including locally saved health/body information and original migration records. Offloading keeps the data. Backups and publicly posted support requests are separate: follow the [privacy policy's retention and deletion instructions](PRIVACY.md#retention-and-deletion), including Apple's backup controls. Nibble does not use Apple Health/HealthKit, so it has no HealthKit records to remove.

## Price and privacy

This release is planned as a free app with no subscriptions or in-app purchases. Nibble has no sign-up, app analytics, or app cloud sync. Barcode lookups contact Open Food Facts and expose the barcode and ordinary network information to that provider. See the [privacy policy](PRIVACY.md) for storage, third-party requests, support posts, and deletion details.
