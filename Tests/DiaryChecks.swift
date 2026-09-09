// Standalone macOS checks against the real Foundation + Combine app core:
// swiftc -swift-version 5 -warnings-as-errors CalorieCompass/Models.swift CalorieCompass/NutritionEngine.swift CalorieCompass/AppState.swift Tests/DiaryChecks.swift -o /tmp/nibble-diary-checks
// /tmp/nibble-diary-checks
//
// Each scenario owns a UUID-named temporary directory and UserDefaults suite.
// Failures are collected across scenarios and produce exit status 1. Regression
// checks assert the intended behavior even when the current implementation fails.
import Foundation
import Combine
import Darwin

@main
@MainActor
struct DiaryChecks {
    private static var assertions = 0
    private static var scenarios = 0
    private static var failures: [String] = []

    static func main() {
        run("fresh install and tracking without a target", noTargetChecks)
        run("manual target, estimate, and plan changes", targetChecks)
        run("diary export is an explicit portable snapshot", exportChecks)
        run("nutrition reference values and macro energy", engineChecks)
        run("portion multiplication and units", portionChecks)
        run("add and undo", addUndoChecks)
        run("edit, delete, undo, and persistence", editDeleteChecks)
        run("undo an edit made with a stale entry snapshot", staleEditChecks)
        run("undo a deletion made with a stale entry snapshot", staleDeleteChecks)
        run("deleting a missing entry cannot create it through undo", missingDeleteChecks)
        run("selected history and today's totals stay separate", historyChecks)
        run("zero calorie foods and incomplete macros", incompleteMacroChecks)
        run("stable favorites and saved food deduplication", favoriteChecks)
        run("recent and quick food deduplication", recentChecks)
        run("profile conversions and inch rollover", unitChecks)
        run("invalid targets and profiles are rejected", invalidPlanChecks)
        run("invalid foods and portions are rejected", invalidEntryChecks)
        for mutation in Mutation.allCases {
            run("failed write is transactional: \(mutation.rawValue)") {
                try failedWriteChecks(mutation)
            }
        }
        run("failed first save does not finish setup", failedFirstSaveChecks)
        run("corrupt JSON is preserved and cannot be overwritten") {
            try corruptArchiveChecks(Data("{broken diary\n".utf8))
        }
        for corruption in ArchiveCorruption.allCases {
            run("invalid archive is preserved: \(corruption.rawValue)") {
                try semanticCorruptionChecks(corruption)
            }
        }
        run("old UserDefaults migration and protected recovery records", migrationChecks)
        run("legacy display units survive migration", legacyDisplayUnitMigrationChecks)
        run("saved-food-only legacy data is persisted", savedFoodsOnlyMigrationChecks)
        run("failed migration write does not expose an unsaved diary", failedMigrationWriteChecks)
        run("corrupt legacy import does not expose partial data", corruptMigrationChecks)
        for corruption in LegacyCorruption.allCases {
            run("invalid legacy data is rejected: \(corruption.rawValue)") {
                try invalidMigrationChecks(corruption)
            }
        }

        print("\n\(scenarios - failures.count)/\(scenarios) scenarios passed; \(assertions) assertions evaluated.")
        if !failures.isEmpty {
            print("\nFailures:")
            for failure in failures { print("- \(failure)") }
            // Every scenario's deferred cleanup has completed before exiting.
            exit(EXIT_FAILURE)
        }
    }

    private static func run(_ name: String, _ action: () throws -> Void) {
        scenarios += 1
        do {
            try action()
            print("PASS \(name)")
        } catch {
            failures.append("\(name): \(error)")
            print("FAIL \(name): \(error)")
        }
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        assertions += 1
        guard try condition() else { throw CheckFailure(message: message) }
    }

    private static func near(_ actual: Double, _ expected: Double, _ message: String,
                             tolerance: Double = 0.000_001) throws {
        try expect(actual.isFinite && abs(actual - expected) <= tolerance,
                   "\(message): expected \(expected), got \(actual)")
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        try expect(value != nil, message)
        guard let value else { throw CheckFailure(message: message) }
        return value
    }

    private static func withFixture(_ action: (Fixture) throws -> Void) throws {
        let fixture = try Fixture()
        var actionError: Error?
        do { try action(fixture) } catch { actionError = error }
        // Report cleanup failures, including when the scenario itself failed.
        do { try fixture.cleanup() } catch {
            throw CheckFailure(message: "\(actionError.map { "\($0); " } ?? "")cleanup failed: \(error)")
        }
        if let actionError { throw actionError }
    }

    private static func food(_ name: String = "Fixture bowl", serving: String = "1 bowl",
                             barcode: String? = nil, source: FoodSource = .custom) -> FoodItem {
        FoodItem(name: name, brand: "Diary checks", servingText: serving,
                 calories: 240, protein: 12, carbs: 30, fat: 8, barcode: barcode, source: source)
    }

    private static func profile() -> UserProfile {
        UserProfile(heightCentimeters: 175, weightKilograms: 70, age: 30, sex: .male,
                    activity: .lightlyActive, goal: .maintain, goalWeightKilograms: 70,
                    displayUnits: .metric)
    }

    private static func historicalDate(daysAgo: Int = 2, hour: Int = 12) throws -> Date {
        let calendar = Calendar.current
        let day = try require(calendar.date(byAdding: .day, value: -daysAgo,
                                            to: calendar.startOfDay(for: Date())), "Construct historical day")
        return try require(calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                           "Construct historical time")
    }

    private static func expectEnergy(_ targets: MacroTargets) throws {
        try expect([targets.calories, targets.protein, targets.carbs, targets.fat]
            .allSatisfy { $0.isFinite && $0 >= 0 }, "Targets must be finite and nonnegative")
        try near(4 * targets.protein + 4 * targets.carbs + 9 * targets.fat, targets.calories,
                 "Protein, carbohydrate, and fat energy must sum to the calorie target")
    }

    private static func expectPersisted(_ state: AppState, _ fixture: Fixture) throws {
        let decoded = try JSONDecoder().decode(DiaryArchive.self, from: fixture.readDiary())
        try expect(decoded == state.archive, "Successful mutation must match the archive on disk")
        let reloaded = fixture.state()
        try expect(reloaded.archive == state.archive, "A new AppState must recover the saved diary exactly")
        try expect(reloaded.storageError == nil, "A valid saved diary must reload without a storage error")
        try expect(!reloaded.canUndo && reloaded.toast == nil, "Transient feedback and undo must not survive relaunch")
    }

    private static func noTargetChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            try expect(state.archive == DiaryArchive() && !state.isPreview && state.targets == nil,
                       "Fresh install must not invent a profile, target, or demo data")
            try expect(state.storageError == nil && !state.canUndo && state.toast == nil, "Clean initial feedback")
            try near(state.todayTotals.calories, 0, "Empty diary")
            state.undo()
            try expect(!fixture.diaryExists, "Undo without an action must not create a diary")
            try expect(state.startTracking(units: .metric), "Start without a target")
            try expect(state.hasStarted && state.profile == nil && state.targets == nil, "Just tracking remains target-free")
            try expect(state.archive.units == .metric, "Remember units without a profile")
            try expectPersisted(state, fixture)
        }
    }

    private static func targetChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            try expect(state.startTracking(target: 2_123.5), "Start with a manual target")
            try near(try require(state.targets, "Manual targets").calories, 2_123.5, "Do not round manual calories")
            try expect(state.profile == nil, "Manual plan needs no body profile")
            try expectPersisted(state, fixture)
            try expect(state.startTracking(profile: profile(), units: .metric), "Switch to an estimate")
            try expect(state.archive.calorieTarget == nil, "Estimate clears the manual override")
            try near(try require(state.targets, "Estimated targets").calories, 2_250, "Reference estimate")
            try expectPersisted(state, fixture)
            try expect(state.startTracking(profile: profile(), target: 1_800), "Override the estimate")
            try near(try require(state.targets, "Override targets").calories, 1_800, "Manual target takes precedence")
            try expect(state.addEntry(food: food(), meal: .lunch, servings: 1), "Log before changing plan")
            let entries = state.entries
            try expect(state.startTracking(), "Switch back to just tracking")
            try expect(state.targets == nil && state.profile == nil && state.entries == entries,
                       "Just tracking clears targets and retains the diary")
            try expectPersisted(state, fixture)
        }
    }

    private static func exportChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let date = try historicalDate(daysAgo: 1)
            try expect(state.startTracking(profile: profile(), target: 2_100, units: .metric), "Start export fixture")
            let item = food("Export snack", serving: "1 bowl", source: .custom)
            try expect(state.addEntry(food: item, meal: .snack, servings: 1.5, date: date), "Add export fixture")

            let exported = try state.exportData()
            let decoded = try JSONDecoder().decode(DiaryArchive.self, from: exported)
            try expect(decoded == state.archive, "Export must represent the exact current archive")
            let json = String(decoding: exported, as: UTF8.self)
            try expect(json.contains("\"profile\"") && json.contains("\"entries\""),
                       "Export must include profile and diary records")

            try expect(state.addEntry(food: food("Later snack"), meal: .lunch, servings: 1), "Mutate after export")
            let exportedArchive = try JSONDecoder().decode(DiaryArchive.self, from: exported)
            try expect(exportedArchive.entries.count == 1 && state.entries.count == 2,
                       "Export must remain an immutable snapshot after later changes")
        }
    }

    private static func engineChecks() throws {
        // Independent reference cases and an energy invariant, not a copied formula.
        for (sex, bmr) in [(Sex.male, 1_648.75), (.female, 1_482.75), (.unspecified, 1_565.75)] {
            var person = profile(); person.sex = sex
            try near(NutritionEngine.basalMetabolicRate(for: person), bmr, "Reference resting energy for \(sex)")
        }
        for (goal, calories) in [(Goal.maintain, 2_250.0), (.lose, 1_950), (.gain, 2_500)] {
            var person = profile(); person.goal = goal
            let targets = NutritionEngine.targets(for: person)
            try near(targets.calories, calories, "Reference estimate for \(goal)")
            try expectEnergy(targets)
        }
        let small = UserProfile(heightCentimeters: 120, weightKilograms: 35, age: 100, sex: .female,
                                activity: .sedentary, goal: .lose, goalWeightKilograms: 35)
        try near(NutritionEngine.targets(for: small).calories, 1_500, "Automated estimate floor")
        for calories in [1_000.0, 2_123.5, 6_000] {
            let targets = NutritionEngine.balancedTargets(calories: calories)
            try near(targets.calories, calories, "Preserve manual calories")
            try expectEnergy(targets)
        }
        let split = NutritionEngine.balancedTargets(calories: 2_000)
        try near(split.protein, 125, "25% protein")
        try near(split.carbs, 225, "45% carbohydrate")
        try near(split.fat, 200.0 / 3, "30% fat")
    }

    private static func portionChecks() throws {
        for quantity in [0.01, 0.015, 1, 100, 1000, 10000] {
            try expect(Double(quantity.inputString) == quantity, "Editable portions must round-trip without grouping or rounding")
        }
        let entry = FoodLogEntry(meal: .lunch, food: food(), servings: 2.5)
        try near(entry.calories, 600, "Calories scale with amount")
        try near(entry.protein, 30, "Protein scales with amount")
        try near(entry.carbs, 75, "Carbohydrate scales with amount")
        try near(entry.fat, 20, "Fat scales with amount")
        for (basis, unit) in [("100g", "g"), ("per 100 g", "g"), ("PER 100 ML", "ml"), ("100ml", "ml")] {
            let item = food(serving: basis)
            let measured = FoodLogEntry(meal: .snack, food: item, servings: 2.5)
            try expect(item.isPerHundred && item.quantityUnit == unit, "Recognize exact basis \(basis)")
            try expect(measured.portionDescription == "250 \(unit)", "Display actual consumed amount")
            try near(measured.calories, 600, "250 units uses 2.5 portions")
        }
        for basis in ["1 bowl", "1 serving (100 g)", "1000 g", "100 g package", "100-cal serving"] {
            let item = food(serving: basis)
            try expect(!item.isPerHundred && item.quantityUnit == "servings", "Do not reinterpret serving text \(basis)")
        }
        let totals = DailyTotals(entries: [entry, entry])
        try near(totals.calories, 1_200, "Sum entry calories")
        try near(totals.protein, 60, "Sum protein")
        try near(totals.carbs, 150, "Sum carbohydrate")
        try near(totals.fat, 40, "Sum fat")
    }

    private static func addUndoChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let date = try historicalDate()
            let item = food()
            state.selectedDate = date
            try expect(state.addEntry(food: item, meal: .dinner, servings: 2.5), "Add food")
            let entry = try require(state.entries.first, "Added entry")
            try expect(entry.food == item && entry.meal == .dinner && entry.date == date,
                       "Add must preserve the selected historical date, meal, and nutrition snapshot")
            try near(state.selectedTotals.calories, 600, "Added calories")
            try expect(state.canUndo && state.toast != nil, "Successful add supplies feedback and undo")
            try expect(state.archive.savedFoods.contains(item), "Custom food must be available after relaunch")
            try expectPersisted(state, fixture)
            state.undo()
            try expect(state.entries.isEmpty && !state.canUndo, "Undo add removes exactly that entry")
            try near(state.selectedTotals.calories, 0, "Undo add restores totals")
            try expectPersisted(state, fixture)
            let bytes = try fixture.readDiary()
            state.undo()
            try expect(state.entries.isEmpty && fixture.readDiary() == bytes, "A second undo has no effect")
        }
    }

    private static func editDeleteChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let date = try historicalDate()
            try expect(state.addEntry(food: food("Earlier"), meal: .breakfast, servings: 1,
                                      date: date.addingTimeInterval(-3_600)), "Seed an unrelated entry")
            let other = try require(state.entries.first, "Unrelated entry")
            try expect(state.addEntry(food: food(), meal: .lunch, servings: 1, date: date), "Seed editable entry")
            let original = try require(state.entries.first, "Editable entry")
            try expect(state.editEntry(original, meal: .dinner, servings: 0.5), "Edit amount and meal")
            let edited = try require(state.entries.first { $0.id == original.id }, "Edited identity must survive")
            try expect(edited.meal == .dinner && edited.servings == 0.5, "Edit changes meal and amount")
            try expect(edited.date == original.date && edited.food == original.food,
                       "Editing the portion must retain its historical date and food snapshot")
            try near(edited.calories, 120, "Edited nutrition")
            try expectPersisted(state, fixture)
            state.undo()
            try expect(state.entries.contains(original) && state.entries.contains(other), "Undo edit restores exact values")
            try expect(!state.canUndo, "Undo edit is consumed once")
            state.deleteEntry(original)
            try expect(state.entries == [other] && state.canUndo, "Delete only the requested entry")
            try expectPersisted(state, fixture)
            state.undo()
            try expect(state.entries(on: date) == [original, other], "Undo delete restores data and visible chronological order")
            try expect(Set(state.entries.map(\.id)).count == 2, "Undo must not duplicate identities")
            try expectPersisted(state, fixture)
        }
    }

    private static func staleEditChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            try expect(state.addEntry(food: food(), meal: .lunch, servings: 1), "Seed an entry")
            let snapshot = try require(state.entries.first, "Original UI snapshot")
            try expect(state.editEntry(snapshot, meal: .dinner, servings: 2), "First edit")
            let beforeSecondEdit = state.entries
            try expect(state.editEntry(snapshot, meal: .snack, servings: 3), "Second edit using the same UI snapshot")
            state.undo()
            try expect(state.entries == beforeSecondEdit,
                       "Undo must restore the state immediately before the second edit, not the caller's stale snapshot")
            try expectPersisted(state, fixture)
        }
    }

    private static func staleDeleteChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            try expect(state.addEntry(food: food(), meal: .lunch, servings: 1), "Seed an entry")
            let snapshot = try require(state.entries.first, "Original UI snapshot")
            try expect(state.editEntry(snapshot, meal: .dinner, servings: 2), "Edit before deleting")
            let beforeDelete = state.entries
            state.deleteEntry(snapshot)
            try expect(state.entries.isEmpty, "Delete resolves the stored entry by identity")
            state.undo()
            try expect(state.entries == beforeDelete,
                       "Undo delete must restore the actual removed entry, including intervening edits")
        }
    }

    private static func missingDeleteChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let missing = FoodLogEntry(meal: .snack, food: food("Never logged"), servings: 1)
            state.deleteEntry(missing)
            state.undo()
            try expect(state.entries.isEmpty, "Deleting an unknown ID and undoing must never insert an unlogged food")
            try expect(!state.canUndo, "A nonexistent deletion must not create an undo action")
        }
    }

    private static func historyChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let history = try historicalDate()
            try expect(state.addEntry(food: food("Today"), meal: .breakfast, servings: 1, date: Date()), "Log today")
            let todayID = try require(state.todayEntries.first?.id, "Today's entry")
            state.selectedDate = history
            try expect(state.addEntry(food: food("History"), meal: .lunch, servings: 2), "Log to selected history by default")
            let historyEntry = try require(state.selectedEntries.first, "Historical entry")
            try expect(historyEntry.date == history, "Historical add must not silently move to today")
            try near(state.selectedTotals.calories, 480, "Selected historical calories")
            try near(state.todayTotals.calories, 240, "Today's calories while viewing history")
            try expect(state.todayEntries.map(\.id) == [todayID], "Today accessor ignores selectedDate")
            try expect(state.addEntry(food: food("Explicit today"), meal: .snack, servings: 0.5, date: Date()),
                       "An explicit date overrides selection")
            try near(state.todayTotals.calories, 360, "Explicit today add")
            try near(state.selectedTotals.calories, 480, "Explicit today add does not affect selected history")
            state.refreshDay()
            try expect(state.selectedDate == history, "Day refresh must retain a historical selection")
            let anotherDay = try historicalDate(daysAgo: 4)
            try expect(state.entries(on: anotherDay).isEmpty, "An empty day must not inherit another day's entries")
            let future = try require(Calendar.current.date(byAdding: .day, value: 2, to: Date()), "Future date")
            let before = state.archive
            try expect(!state.addEntry(food: food(), meal: .lunch, servings: 1, date: future), "Future date must be rejected")
            try expect(state.archive == before, "Rejected future log must leave the archive unchanged")
            state.selectedDate = Date()
            try near(state.selectedTotals.calories, 360, "Selecting today follows today's data")
            try expect(state.editEntry(historyEntry, meal: .dinner, servings: 3), "Edit history while today is selected")
            try near(state.todayTotals.calories, 360, "Editing history must not affect today")
            try near(DailyTotals(entries: state.entries(on: history)).calories, 720, "Historical edit affects the original day")
            try expectPersisted(state, fixture)
        }
    }

    private static func incompleteMacroChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            var water = food("Water", serving: "per 100 ml")
            water.calories = 0; water.protein = 0; water.carbs = 0; water.fat = 0
            water.macrosComplete = true
            try expect(water.isValid && water.hasMacros, "Explicit zero nutrition is valid and complete")
            try expect(state.addEntry(food: water, meal: .snack, servings: 2.5), "Log zero calorie water")
            var calorieOnly = food("Calories only")
            calorieOnly.calories = 80; calorieOnly.protein = 0; calorieOnly.carbs = 0; calorieOnly.fat = 0
            calorieOnly.macrosComplete = false
            try expect(calorieOnly.isValid && !calorieOnly.hasMacros, "Calorie-only food is valid but not complete")
            try expect(state.addEntry(food: calorieOnly, meal: .lunch, servings: 2), "Log calories without macros")
            let incomplete = try require(state.entries.first { $0.food.id == calorieOnly.id }, "Incomplete entry")
            try expect(state.addEntry(food: food(), meal: .dinner, servings: 0.5), "Log complete nutrition alongside it")
            let totals = state.todayTotals
            try near(totals.calories, 280, "Calories include complete, zero, and calorie-only entries")
            try near(totals.protein, 6, "Known protein still contributes")
            try near(totals.carbs, 15, "Known carbohydrate still contributes")
            try near(totals.fat, 4, "Known fat still contributes")
            try expect(totals.hasIncompleteMacros, "Mixed totals must disclose incomplete macros")
            try expectPersisted(state, fixture)
            try expect(fixture.state().todayTotals.hasIncompleteMacros, "Explicit false survives persistence")
            state.deleteEntry(incomplete)
            try expect(!state.todayTotals.hasIncompleteMacros, "Removing the unknown macros clears the warning")
            state.undo()
            try expect(state.todayTotals.hasIncompleteMacros, "Undo restores the incomplete-macro warning")
            try expect(food().hasMacros, "Legacy nil completeness treats existing macro values as known")
        }
    }

    private static func favoriteChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let first = food("Scanned cereal", barcode: "036000291452", source: .openFoodFacts)
            var fetchedAgain = food("Renamed cereal", barcode: "0036000291452", source: .openFoodFacts)
            fetchedAgain.calories = 250
            try expect(first.id != fetchedAgain.id && first.stableKey == fetchedAgain.stableKey
                       && first.stableKey == "barcode:00036000291452",
                       "Repeated UPC-A and EAN-13 lookups share a validated barcode identity")
            try expect(first.barcode == "036000291452" && fetchedAgain.barcode == "0036000291452",
                       "Canonical identity must not rewrite the original barcode values")
            state.toggleFavorite(first)
            try expect(state.archive.favorites == [first.stableKey], "New favorites persist the canonical identity key")
            try expect(state.isFavorite(fetchedAgain), "Favorite lookup must survive a different barcode representation")
            try expect(state.favoriteFoods.count == 1 && state.favoriteFoods.first == first, "Favorite food is saved and visible once")
            let historical = try historicalDate()
            try expect(state.addEntry(food: first, meal: .breakfast, servings: 1, date: historical),
                       "Log the original barcode representation")
            try expect(state.addEntry(food: fetchedAgain, meal: .lunch, servings: 1), "Log a repeated lookup")
            try expect(state.archive.savedFoods.filter { $0.stableKey == first.stableKey }.count == 1,
                       "Repeated barcode must not duplicate saved foods")
            try expect(state.entries.first?.food == fetchedAgain, "Logged nutrition retains the actual lookup snapshot")
            try expect(state.entries.contains { $0.food.barcode == first.barcode },
                       "Historical entry snapshots retain the original barcode representation")
            try expectPersisted(state, fixture)
            let reloaded = fixture.state()
            try expect(reloaded.isFavorite(fetchedAgain) && reloaded.favoriteFoods.count == 1
                       && reloaded.entries.contains { $0.food.barcode == first.barcode },
                       "Canonical favorite and historical snapshot survive relaunch")
            reloaded.toggleFavorite(fetchedAgain)
            try expect(!reloaded.isFavorite(first) && reloaded.favoriteFoods.isEmpty, "Either lookup can remove the same favorite")
            try expectPersisted(reloaded, fixture)

            let legacyKey = "barcode:\(first.barcode!)"
            var legacyArchive = reloaded.archive
            legacyArchive.favorites = [legacyKey]
            try fixture.writeDiary(JSONEncoder().encode(legacyArchive))
            let legacy = fixture.state()
            try expect(legacy.archive.favorites == [legacyKey], "Relaunch preserves an old literal favorite key")
            try expect(legacy.isFavorite(fetchedAgain) && legacy.favoriteFoods.count == 1,
                       "Old literal favorite keys match the canonical barcode")
            let legacyBytes = try fixture.readDiary()
            let beforeFailedUnfavorite = legacy.archive
            try fixture.blockWrites()
            legacy.toggleFavorite(fetchedAgain)
            try expect(legacy.archive == beforeFailedUnfavorite && legacy.storageError != nil,
                       "A failed unfavorite leaves the old favorite state unchanged")
            try expect(fixture.readBlockedDiary() == legacyBytes, "A failed unfavorite preserves the archive bytes")
            try fixture.unblockWrites()
            legacy.toggleFavorite(fetchedAgain)
            try expect(!legacy.isFavorite(first) && legacy.archive.favorites.isEmpty,
                       "Unfavorite removes canonical and compatible legacy keys")
            try expectPersisted(legacy, fixture)

            let builtin = try require(AppState.foodDatabase.first, "Starter library fixture")
            var custom = builtin
            custom.id = UUID(); custom.name = builtin.name.uppercased(); custom.source = .custom
            custom.calories += 10
            try expect(custom.stableKey == builtin.stableKey, "Local stable identity ignores name casing and UUID")
            try expect(legacy.addEntry(food: custom, meal: .snack, servings: 1), "Save a customized library food")
            let matches = legacy.allFoods.filter { $0.stableKey == builtin.stableKey }
            try expect(matches == [custom], "Saved nutrition must take precedence over a duplicate generic library food")
            var otherPortion = custom
            otherPortion.servingText = "1 tablespoon"
            try expect(otherPortion.stableKey != custom.stableKey, "Different serving bases are distinct foods")
            let unit = food("GTIN-13 unit", barcode: "3017620422003", source: .openFoodFacts)
            let casePack = food("GTIN-14 case pack", barcode: "13017620422000", source: .openFoodFacts)
            try expect(unit.stableKey == "barcode:03017620422003",
                       "GTIN-13 identity uses the fixed 14-digit representation")
            try expect(casePack.stableKey == "barcode:13017620422000" && casePack.stableKey != unit.stableKey,
                       "A nonzero GTIN-14 packaging indicator remains a distinct identity")
            let invalid = food("Invalid barcode", barcode: "036000291453", source: .openFoodFacts)
            let separated = food("Separated barcode", barcode: "036-000-291452", source: .openFoodFacts)
            try expect(invalid.stableKey == "barcode:036000291453" && separated.stableKey == "barcode:036-000-291452"
                       && invalid.stableKey != first.stableKey && separated.stableKey != first.stableKey,
                       "Invalid or ambiguously formatted legacy barcodes stay literal and distinct")
            legacy.toggleFavorite(custom)
            try expect(legacy.quickFoods.first?.stableKey == custom.stableKey, "Favorites lead quick food choices")
            try expectPersisted(legacy, fixture)
        }
    }

    private static func recentChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let date = try historicalDate()
            let old = food("Older lookup", barcode: "3017620422003", source: .openFoodFacts)
            let latest = food("Latest lookup", barcode: "3017620422003", source: .openFoodFacts)
            try expect(state.addEntry(food: old, meal: .breakfast, servings: 1, date: date), "Older barcode entry")
            for offset in 1...3 {
                try expect(state.addEntry(food: food("Recent \(offset)"), meal: .lunch, servings: 1,
                                          date: date.addingTimeInterval(Double(offset * 60))), "Add distinct recent food")
            }
            try expect(state.addEntry(food: latest, meal: .dinner, servings: 1,
                                      date: date.addingTimeInterval(1_800)), "Most recent barcode entry")
            try expect(state.recentFoods.first == latest, "Recents choose the newest nutrition snapshot, not the saved-food version")
            for foods in [state.allFoods, state.recentFoods, state.quickFoods] {
                try expect(Set(foods.map(\.stableKey)).count == foods.count, "Food suggestions must contain unique stable identities")
            }
            state.toggleFavorite(old)
            try expect(state.quickFoods.first?.stableKey == old.stableKey, "A recent favorite still appears first")
            try expect(state.quickFoods.filter { $0.stableKey == old.stableKey }.count == 1,
                       "Favorite plus recent references must not duplicate quick choices")
            let reloaded = fixture.state()
            try expect(reloaded.recentFoods == state.recentFoods && reloaded.quickFoods == state.quickFoods,
                       "Recent order and quick choices survive relaunch")
        }
    }

    private static func unitChecks() throws {
        try near(NutritionEngine.inchesToCentimeters(70), 177.8, "Inches to centimeters")
        try near(NutritionEngine.centimetersToInches(177.8), 70, "Centimeters to inches")
        // Tolerance accounts for the app's five-decimal lb/kg conversion constant.
        try near(NutritionEngine.poundsToKilograms(154.323_583_529), 70, "Pounds to kilograms", tolerance: 0.0002)
        try near(NutritionEngine.kilogramsToPounds(70), 154.323_583_529, "Kilograms to pounds", tolerance: 0.0002)
        for (inches, feet, remainder) in [(59.49, 4, 11), (59.51, 5, 0), (71.49, 5, 11), (71.51, 6, 0)] {
            var person = profile(); person.heightCentimeters = inches * 2.54
            try expect(person.heightFeet == feet && person.heightInchesRemainder == remainder,
                       "\(inches) inches must round to \(feet) feet \(remainder) inches")
        }
        try withFixture { fixture in
            let state = fixture.state()
            var person = profile(); person.goalWeightKilograms = 65
            try near(person.weightPounds, 154.323_583_529, "Profile weight", tolerance: 0.0002)
            try near(person.goalWeightPounds, 143.300_470_420, "Profile goal weight", tolerance: 0.0002)
            try expect(state.startTracking(profile: person, units: .metric), "Save metric profile")
            let targets = state.targets
            person.displayUnits = .imperial
            try expect(state.startTracking(profile: person, units: .imperial), "Switch display units")
            try expect(state.targets == targets && state.profile?.weightKilograms == 70,
                       "Display units must not change body measurements or calorie estimates")
            try expectPersisted(state, fixture)
            try expect(fixture.state().archive.units == .imperial, "Persist display units")
        }
    }

    private static func invalidPlanChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            try expect(state.startTracking(profile: profile(), target: 2_000), "Seed valid plan")
            let before = state.archive
            let bytes = try fixture.readDiary()
            for target in [Double.nan, .infinity, -.infinity, 999, 6_001, .greatestFiniteMagnitude] {
                try expect(!state.startTracking(target: target), "Reject target \(target)")
                try expect(state.archive == before && fixture.readDiary() == bytes, "Rejected target changes neither memory nor disk")
            }
            let fields: [WritableKeyPath<UserProfile, Double>] = [\.heightCentimeters, \.weightKilograms, \.goalWeightKilograms]
            for key in fields {
                for value in [Double.nan, .infinity, -.infinity, -1, .greatestFiniteMagnitude] {
                    var person = profile(); person[keyPath: key] = value
                    try expect(!person.isValid && !state.startTracking(profile: person), "Reject invalid profile number \(value)")
                    try expect(state.archive == before && fixture.readDiary() == bytes, "Rejected profile leaves saved plan intact")
                }
            }
            for age in [17, 101] {
                var person = profile(); person.age = age
                try expect(!person.isValid && !state.startTracking(profile: person), "Reject age \(age)")
            }
            for target in [1_000.0, 6_000] {
                try expect(state.startTracking(target: target), "Accept inclusive target boundary")
            }
        }
    }

    private static func invalidEntryChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            try expect(state.addEntry(food: food(), meal: .lunch, servings: 1), "Seed valid entry")
            let entry = try require(state.entries.first, "Saved entry")
            let before = state.archive
            let bytes = try fixture.readDiary()
            for amount in [Double.nan, .infinity, -.infinity, -1, 0, 0.009, 100.001, .greatestFiniteMagnitude] {
                try expect(!state.addEntry(food: food(), meal: .snack, servings: amount), "Reject add amount \(amount)")
                try expect(!state.editEntry(entry, meal: .dinner, servings: amount), "Reject edit amount \(amount)")
                try expect(state.archive == before && fixture.readDiary() == bytes, "Invalid amount changes neither memory nor disk")
            }
            let fields: [WritableKeyPath<FoodItem, Double>] = [\.calories, \.protein, \.carbs, \.fat]
            for key in fields {
                for value in [Double.nan, .infinity, -.infinity, -0.01, 10_000.01] {
                    var item = food(); item[keyPath: key] = value
                    try expect(!item.isValid && !state.addEntry(food: item, meal: .lunch, servings: 1), "Reject nutrient \(value)")
                    try expect(state.archive == before && fixture.readDiary() == bytes, "Invalid food leaves diary and library intact")
                }
            }
            state.undo()
            try expect(state.entries.isEmpty, "Invalid requests must not consume the previous successful undo")
            for amount in [0.01, 100.0] {
                try expect(state.addEntry(food: food(), meal: .snack, servings: amount), "Accept inclusive portion boundary")
            }
            try expectPersisted(state, fixture)
        }
    }

    private enum Mutation: String, CaseIterable { case start, add, edit, delete, favorite, undo }

    private static func mutate(_ kind: Mutation, state: AppState, entry: FoodLogEntry) -> Bool? {
        switch kind {
        case .start: return state.startTracking(target: 2_300, units: .metric)
        case .add: return state.addEntry(food: food("New food"), meal: .snack, servings: 0.5)
        case .edit: return state.editEntry(entry, meal: .dinner, servings: 3)
        case .delete: state.deleteEntry(entry)
        case .favorite: state.toggleFavorite(entry.food)
        case .undo: state.undo()
        }
        return nil
    }

    private static func failedWriteChecks(_ mutation: Mutation) throws {
        try withFixture { fixture in
            let state = fixture.state()
            try expect(state.startTracking(target: 2_000), "Seed a saved plan")
            try expect(state.addEntry(food: food(), meal: .lunch, servings: 1), "Seed a saved entry and undo")
            let entry = try require(state.entries.first, "Saved entry")
            let before = state.archive
            let feedback = state.toast
            let undo = state.canUndo
            let bytes = try fixture.readDiary()
            try fixture.blockWrites()
            var publications = 0
            let observer = state.$archive.dropFirst().sink { _ in publications += 1 }
            defer { observer.cancel() }
            let result = mutate(mutation, state: state, entry: entry)
            if let result { try expect(!result, "Failed \(mutation.rawValue) must return false") }
            try expect(state.storageError != nil, "Failed \(mutation.rawValue) must expose a storage error")
            try expect(state.archive == before && publications == 0, "Failed save must neither mutate nor publish the archive")
            try expect(state.toast == feedback && state.canUndo == undo, "Failed save must not announce success or replace undo state")
            try expect(fixture.readBlockedDiary() == bytes, "Failed save must preserve the last successful diary bytes")
            try expect(fixture.readBlocker() == Fixture.blockerBytes, "Failed save must not overwrite the path obstruction")
            try fixture.unblockWrites()
            let retry = mutate(mutation, state: state, entry: entry)
            if let retry { try expect(retry, "Retry must succeed after storage recovers") }
            try expect(state.storageError == nil && state.archive != before, "Retry clears the error and applies the change")
            try expect(publications == 1, "Only the successful retry publishes a changed archive")
            try expectPersisted(state, fixture)
        }
    }

    private static func failedFirstSaveChecks() throws {
        try withFixture { fixture in
            let state = fixture.state()
            let before = state.archive
            try fixture.blockWrites()
            try expect(!state.startTracking(target: 2_000), "Failed setup save must return false")
            try expect(!state.hasStarted && state.archive == before && state.targets == nil,
                       "Failed setup must leave the user in setup with no unsaved plan")
            try expect(state.storageError != nil && state.toast == nil && !state.canUndo,
                       "Failed setup shows an error without success feedback")
            try fixture.unblockWrites()
            try expect(state.startTracking(target: 2_000), "Setup can be retried after storage recovers")
            try expectPersisted(state, fixture)
        }
    }

    private static func corruptArchiveChecks(_ bytes: Data) throws {
        try withFixture { fixture in
            try fixture.writeDiary(bytes)
            let state = fixture.state()
            try expect(state.storageError != nil, "Invalid saved diary must be identified as unreadable")
            try expect(state.archive == DiaryArchive(), "Unreadable data must not become a partially loaded diary")
            let error = state.storageError
            try expect(!state.startTracking(target: 2_000), "Setup must not overwrite an unreadable existing file")
            try expect(!state.addEntry(food: food(), meal: .snack, servings: 1), "Add must not overwrite an unreadable existing file")
            let entry = FoodLogEntry(meal: .lunch, food: food(), servings: 1)
            try expect(!state.editEntry(entry, meal: .dinner, servings: 2), "Edit cannot write over a corrupt diary")
            state.deleteEntry(entry); state.toggleFavorite(entry.food); state.undo()
            try expect(fixture.readDiary() == bytes, "All attempted mutations must preserve the original corrupt bytes exactly")
            try expect(state.archive == DiaryArchive() && state.toast == nil && !state.canUndo,
                       "Blocked corrupt-file writes must not report success or mutate state")
            try expect(state.storageError == error, "Preserve the actionable read error")
            try expect((try? state.exportData()) == nil, "Unreadable archive must not export an empty replacement")
            try expect(fixture.state().storageError != nil, "Relaunch still detects the preserved file")
        }
    }

    private enum ArchiveCorruption: String, CaseIterable { case version, target, portion, food, savedFood, profile }

    private static func semanticCorruptionChecks(_ corruption: ArchiveCorruption) throws {
        var archive = DiaryArchive()
        archive.hasStarted = true
        archive.entries = [FoodLogEntry(meal: .lunch, food: food(), servings: 1)]
        switch corruption {
        case .version: archive.version = 999
        case .target: archive.calorieTarget = 999
        case .portion: archive.entries[0].servings = -1
        case .food: archive.entries[0].food.calories = -1
        case .savedFood:
            var invalid = food(); invalid.fat = -1; archive.savedFoods = [invalid]
        case .profile:
            var invalid = profile(); invalid.heightCentimeters = 1e100; archive.profile = invalid
        }
        try corruptArchiveChecks(JSONEncoder().encode(archive))
    }

    private static let legacyProfileKey = "calorieCompass.profile"
    private static let legacyEntriesKey = "calorieCompass.entries"
    private static let legacyFoodsKey = "calorieCompass.savedFoods"

    private static func legacyPayloads() -> [String: Data] {
        // Literal v0 fixtures deliberately omit displayUnits and macrosComplete;
        // encoding today's model would not exercise that compatibility contract.
        let oldFood = """
        {"id":"22222222-2222-4222-8222-222222222222","name":"Legacy oats","brand":"Original",
         "servingText":"1 cup","calories":160,"protein":6,"carbs":25,"fat":4,"source":"custom"}
        """
        return [
            legacyProfileKey: Data("""
            {"heightCentimeters":175,"weightKilograms":70,"age":30,"sex":"male",
             "activity":"lightlyActive","goal":"maintain","goalWeightKilograms":70}
            """.utf8),
            legacyEntriesKey: Data("""
            [{"id":"11111111-1111-4111-8111-111111111111","date":700000000,
              "meal":"breakfast","food":\(oldFood),"servings":1.5}]
            """.utf8),
            legacyFoodsKey: Data("[\(oldFood)]".utf8)
        ]
    }

    private static func seedLegacy(_ payloads: [String: Data], _ fixture: Fixture) {
        for (key, bytes) in payloads { fixture.defaults.set(bytes, forKey: key) }
    }

    private static func expectLegacyRetained(_ payloads: [String: Data], _ fixture: Fixture) throws {
        let recovery = try fixture.legacyRecovery()
        for (key, bytes) in payloads {
            try expect(fixture.defaults.data(forKey: key) == bytes || recovery.contains { ($0[key] as? Data) == bytes },
                       "Migration must preserve the original \(key) bytes in defaults or protected recovery")
        }
    }

    private static func migrationChecks() throws {
        try withFixture { fixture in
            let payloads = legacyPayloads()
            seedLegacy(payloads, fixture)
            let state = fixture.state()
            try expect(state.storageError == nil && state.hasStarted, "Valid legacy profile starts tracking")
            try expect(state.profile?.displayUnits == nil && state.profile?.weightKilograms == 70,
                       "Old profile without displayUnits remains decodable")
            try near(try require(state.targets, "Migrated profile should supply estimated targets").calories, 2_250,
                     "Legacy estimate")
            let entry = try require(state.entries.first, "Migrated entry")
            try expect(state.entries.count == 1 && entry.id.uuidString == "11111111-1111-4111-8111-111111111111",
                       "Migration preserves entry identity")
            try expect(entry.date == Date(timeIntervalSinceReferenceDate: 700_000_000) && entry.meal == .breakfast,
                       "Migration preserves historical timestamp and meal")
            try near(entry.calories, 240, "Migration preserves quantity multiplication")
            try expect(entry.food.macrosComplete == nil && entry.food.hasMacros, "Old foods retain known macro semantics")
            try expect(state.archive.savedFoods == [entry.food], "Saved foods survive migration")
            try expectLegacyRetained(payloads, fixture)
            try expectPersisted(state, fixture)
            state.deleteEntry(entry)
            try expect(state.startTracking(target: 1_900), "Update the imported diary")
            let reloaded = fixture.state()
            try expect(reloaded.entries.isEmpty && reloaded.archive.calorieTarget == 1_900,
                       "Existing JSON must take precedence over retained legacy keys; do not resurrect deleted entries")
            try expectLegacyRetained(payloads, fixture)
        }
    }

    private static func legacyDisplayUnitMigrationChecks() throws {
        try withFixture { fixture in
            var payloads = legacyPayloads()
            payloads[legacyProfileKey] = try JSONEncoder().encode(profile())
            seedLegacy(payloads, fixture)
            let state = fixture.state()
            try expect(state.profile?.displayUnits == .metric, "Metric legacy profile remains decodable")
            try expect(state.archive.units == .metric, "Legacy profile units become the current archive preference")
            try expect(fixture.state().archive.units == .metric, "Migrated display units survive relaunch")
        }
    }

    private static func savedFoodsOnlyMigrationChecks() throws {
        try withFixture { fixture in
            let payloads = [legacyFoodsKey: try require(legacyPayloads()[legacyFoodsKey], "Saved food fixture")]
            seedLegacy(payloads, fixture)
            let state = fixture.state()
            try expect(state.archive.savedFoods.count == 1, "Import saved foods even without a profile or entries")
            try expectLegacyRetained(payloads, fixture)
            try expect(fixture.diaryExists, "Saved-food-only migration must persist the imported library to JSON")
            try expectPersisted(state, fixture)
        }
    }

    private static func failedMigrationWriteChecks() throws {
        try withFixture { fixture in
            let payloads = legacyPayloads()
            seedLegacy(payloads, fixture)
            try fixture.blockWrites()
            let state = fixture.state()
            try expect(state.storageError != nil, "Failed migration persistence exposes an error")
            try expectLegacyRetained(payloads, fixture)
            try expect(fixture.readBlocker() == Fixture.blockerBytes, "Migration preserves the obstructing file")
            try expect(state.archive == DiaryArchive() && !state.hasStarted && state.targets == nil,
                       "An unsuccessful import save must not expose an unsaved imported diary as active")
        }
    }

    private static func corruptMigrationChecks() throws {
        try withFixture { fixture in
            var payloads = legacyPayloads()
            payloads[legacyFoodsKey] = Data("not json".utf8)
            seedLegacy(payloads, fixture)
            let state = fixture.state()
            try expect(state.storageError != nil, "Corruption in the last legacy key must be reported")
            try expectLegacyRetained(payloads, fixture)
            try expect(!fixture.diaryExists, "Failed decoding must not write a partial archive")
            try expect(!state.startTracking(target: 2_000), "Unreadable legacy data must not be overwritten")
            try expect(state.archive == DiaryArchive() && !state.hasStarted,
                       "A corrupt final legacy key must not leave the earlier profile and entries partially imported")
        }
    }

    private enum LegacyCorruption: String, CaseIterable { case profile, portion, savedFood }

    private static func invalidMigrationChecks(_ corruption: LegacyCorruption) throws {
        try withFixture { fixture in
            var payloads = legacyPayloads()
            switch corruption {
            case .profile:
                var person = profile(); person.heightCentimeters = 1e100
                payloads[legacyProfileKey] = try JSONEncoder().encode(person)
            case .portion:
                payloads[legacyEntriesKey] = try JSONEncoder().encode([
                    FoodLogEntry(meal: .lunch, food: food(), servings: -1)
                ])
            case .savedFood:
                var invalid = food(); invalid.calories = -1
                payloads[legacyFoodsKey] = try JSONEncoder().encode([invalid])
            }
            seedLegacy(payloads, fixture)
            let state = fixture.state()
            try expectLegacyRetained(payloads, fixture)
            try expect(state.storageError != nil, "Invalid numeric \(corruption.rawValue) must be rejected during legacy import")
            try expect(state.archive == DiaryArchive() && !fixture.diaryExists,
                       "Invalid legacy data must not become an active or persisted diary")
        }
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

@MainActor
private final class Fixture {
    static let blockerBytes = Data("DiaryChecks: this ordinary file deliberately blocks a directory".utf8)
    let defaults: UserDefaults
    private let suiteName: String
    private let directory: URL
    private let manager = FileManager()
    private var storeDirectory: URL { directory.appendingPathComponent("store", isDirectory: true) }
    private var backupDirectory: URL { directory.appendingPathComponent("last-good-store", isDirectory: true) }
    private var storageURL: URL { storeDirectory.appendingPathComponent("diary.json") }
    var diaryExists: Bool { manager.fileExists(atPath: storageURL.path) }

    init() throws {
        let id = UUID().uuidString
        suiteName = "dev.nibble.DiaryChecks.\(id)"
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Nibble-DiaryChecks-\(id)", isDirectory: true)
        guard let isolated = UserDefaults(suiteName: suiteName) else {
            throw CheckFailure(message: "Could not create isolated UserDefaults suite")
        }
        defaults = isolated
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    func state() -> AppState { AppState(storageURL: storageURL, defaults: defaults) }
    func readDiary() throws -> Data { try Data(contentsOf: storageURL) }
    func readBlockedDiary() throws -> Data { try Data(contentsOf: backupDirectory.appendingPathComponent("diary.json")) }
    func readBlocker() throws -> Data { try Data(contentsOf: storeDirectory) }
    func legacyRecovery() throws -> [[String: Any]] {
        let url = storeDirectory.appendingPathComponent("legacy-recovery.plist")
        guard manager.fileExists(atPath: url.path) else { return [] }
        return try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [[String: Any]] ?? []
    }

    func writeDiary(_ bytes: Data) throws {
        try manager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try bytes.write(to: storageURL, options: .atomic)
    }

    func blockWrites() throws {
        // A regular file where the parent directory belongs fails deterministically,
        // including under privileged users; chmod-based tests would not do that.
        try manager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try manager.moveItem(at: storeDirectory, to: backupDirectory)
        try Self.blockerBytes.write(to: storeDirectory)
    }

    func unblockWrites() throws {
        try manager.moveItem(at: storeDirectory, to: directory.appendingPathComponent("released-blocker"))
        try manager.moveItem(at: backupDirectory, to: storeDirectory)
    }

    func cleanup() throws {
        defaults.removePersistentDomain(forName: suiteName)
        // The only removal target is this fixture's exact, generated directory.
        // Never remove the shared temporary root, app support directory, or standard defaults.
        try manager.removeItem(at: directory)
        guard !manager.fileExists(atPath: directory.path) else {
            throw CheckFailure(message: "Fixture directory still exists after cleanup: \(directory.path)")
        }
    }
}
