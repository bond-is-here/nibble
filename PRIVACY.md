# Nibble privacy policy

Last updated: September 5, 2026

This policy describes the Nibble iPhone app in this repository, including its migration from Calorie Compass. Nibble is a food diary with optional calorie and macro targets. It does not require a Nibble account.

## Information kept on your device

Nibble stores the information you enter so it can display your diary, calculate totals and targets, and let you reuse foods:

- Food names, nutrition values, portions, meal categories, dates, and saved product barcodes.
- Custom foods, saved barcode results, favorites, and preferences such as display units and your chosen calorie target.
- If you use the estimate flow: age, height, weight, formula selection (female, male, or midpoint), activity level, direction, and goal weight. If no separate goal weight is entered, the current weight is used.

The app saves these records in a JSON file at `Application Support/Nibble/diary.json` inside its app container. It has no developer-operated diary server or app cloud-sync feature. Your saved diary and body profile are not included in barcode requests or otherwise uploaded by the app. Device backups are a separate matter, described below.

When an existing Calorie Compass installation is upgraded and no Nibble archive exists, Nibble imports the original `calorieCompass.profile`, `calorieCompass.entries`, and `calorieCompass.savedFoods` UserDefaults data. These original records are retained on the device after migration. An unreadable archive or failed migration is preserved and reported as a storage error rather than silently discarded.

Nibble does not read from or write to Apple Health or HealthKit. Its locally saved nutrition and body information is app data; it is not an Apple Health database.

## Barcode lookups and camera access

Looking up a typed or scanned barcode sends that barcode in an HTTPS request to Open Food Facts at `world.openfoodfacts.org`. The request identifies Nibble and its version through an app User-Agent. Like other internet requests, it also exposes network/request information, including the source IP address, to the receiving provider and its infrastructure. A lookup reveals which product was requested. Open Food Facts may process or retain request information under its own practices; Nibble does not control those systems or promise that they keep no logs.

The request does not contain your saved diary, portions eaten, calorie target, age, height, weight, or other saved body-profile fields. The returned food information can be saved locally when you log or favorite it. Normal text search searches the starter library and your saved foods on the device.

The camera is optional and used to recognize a package barcode on the device. Nibble does not save or upload camera photos or video. You can deny or revoke camera access in iOS Settings under Privacy & Security > Camera > Nibble and type a barcode instead. Typed lookup still contacts Open Food Facts. To avoid barcode requests, use the starter library, previously saved foods, or manual food entry.

See the provider's [privacy page](https://world.openfoodfacts.org/privacy) and [terms of use](https://world.openfoodfacts.org/terms-of-use). Opening external links in the app or these pages also connects to the destination website, whose own privacy practices apply.

## Analytics, advertising, and support

Nibble contains no analytics, advertising, tracking, or third-party crash-reporting SDK. It does not sell your diary or body information.

If you choose to contact the maintainers through [Nibble GitHub Issues](https://github.com/bond-is-here/nibble/issues), your GitHub identity and anything you post are visible to maintainers and other readers of that public issue. This information is used to respond to and investigate your request. GitHub operates that service under its own policies. Do not post diary archives, body measurements, medical information, credentials, or screenshots containing private details. Closing an issue does not erase its content; manage submitted content through GitHub. General privacy questions can be raised there without disclosing personal information.

## Retention and deletion

Nibble keeps local records until you change or remove them. There is no automatic expiration of the diary or saved foods.

To remove an individual diary entry, open its date in Diary, open the entry's three-dot menu, and choose Delete. The change is saved locally; Undo can restore it. The last changed entry may also remain in memory for Undo during that app session. Deleting a diary entry does not delete the food from the saved library or clear the retained Calorie Compass migration records. Removing a favorite removes the star, not the saved food.

To delete all Nibble data stored in the current iPhone app container, including your locally saved nutrition/body information, saved foods, preferences, and retained migration records:

1. Open iOS Settings > General > iPhone Storage > Nibble.
2. Choose Delete App and confirm deletion.

This permanently removes that local app data. Offload App preserves documents and data, and Remove from Home Screen does not uninstall the app. See [Apple's explanation of app storage and deletion](https://support.apple.com/en-us/108429). The current app has no separate erase-all button or account to delete. The maintainers cannot remotely access or erase your device's diary. No Apple Health cleanup is needed for Nibble because this app creates no HealthKit records; deleting Nibble does not delete records created by other apps in Apple Health.

Your iCloud or computer device backups may contain earlier app data, including migrated data. Deleting the app or individual entries does not promise removal of those backup copies, and restoring a backup may restore that information. To manage Nibble's iCloud backup data, open Settings > your name > iCloud > Storage (or Manage Account Storage) > Backups > this device, then turn off Nibble if listed and confirm. Consult [Apple's backup management instructions](https://support.apple.com/en-us/108922) for your OS version and other device backups. Computer backups must be managed separately. Nibble cannot delete backups held outside its app container.

Uninstalling also does not delete any information already held by Open Food Facts or posted to GitHub; use those providers' privacy and account controls for their records.

## Questions and changes

For help with these controls, see [Nibble Support](SUPPORT.md) or raise a general, non-sensitive question through [GitHub Issues](https://github.com/bond-is-here/nibble/issues). Updates to this policy will be published here with a revised date.
