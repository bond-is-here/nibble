import Foundation
import Combine

@main
@MainActor
struct MacroChecks {
    static var assertions = 0
    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        assertions += 1
        if try !condition() { throw Failure(message: message) }
    }
    static func near(_ actual: Double, _ expected: Double, _ message: String) throws {
        try check(actual.isFinite && abs(actual - expected) < 0.000_001, message)
    }
    static func food(_ name: String = "Sample", calories: Double = 200, p: Double = 20, c: Double = 20,
                     f: Double = 5, known: Bool = true, barcode: String? = nil) -> FoodItem {
        FoodItem(name: name, servingText: "1 serving", calories: calories, protein: p, carbs: c, fat: f,
                 barcode: barcode, source: .custom, macrosComplete: known)
    }
    static func log(_ food: FoodItem, amount: Double = 1, day: Date = Date()) -> FoodLogEntry {
        FoodLogEntry(date: day, meal: .lunch, food: food, servings: amount)
    }
    static let targets = MacroTargets(calories: 2000, protein: 125, carbs: 225, fat: 2000 * 0.3 / 9)

    static func main() throws {
        try splits()
        try snapshots()
        try insights()
        try previews()
        try weeks()
        try persistence()
        print("Passed \(assertions) Macro Mix checks: arithmetic, confidence, suggestions, previews, trends, and persistence.")
    }

    static func splits() throws {
        try check(MacroSplit.standard.isValid, "Default split valid")
        for p in stride(from: 1, through: 90, by: 7) {
            for c in stride(from: 1, through: 95 - p, by: 9) {
                let split = MacroSplit(protein: p, carbs: c, fat: 100 - p - c)
                try check(split.isValid, "Sum-preserving positive split valid")
                let values = NutritionEngine.macroTargets(calories: 2137, split: split)
                try near(values.protein * 4 + values.carbs * 4 + values.fat * 9, 2137, "Macro energy must preserve calories")
                try near(values.protein * 4 / 2137, Double(p) / 100, "Protein percentage applied")
            }
        }
        for split in [MacroSplit(protein: 0, carbs: 70, fat: 30), MacroSplit(protein: -1, carbs: 71, fat: 30),
                      MacroSplit(protein: 25, carbs: 40, fat: 30), MacroSplit(protein: Int.max, carbs: Int.max, fat: Int.max)] {
            try check(!split.isValid, "Reject invalid/overflowing percentages without arithmetic overflow")
            try check(NutritionEngine.macroTargets(calories: 2000, split: split) == NutritionEngine.balancedTargets(calories: 2000), "Invalid split fallback")
        }
    }

    static func snapshots() throws {
        let known = log(food(), amount: 1.5)
        // Even nonzero stored placeholders must never masquerade as known macros.
        let unknown = log(food("Calories only", calories: 100, p: 99, c: 99, f: 99, known: false))
        let snapshot = MacroSnapshot(entries: [known, unknown], targets: targets)
        try near(snapshot.totals.calories, 400, "All calories included")
        try near(snapshot.totals.protein, 30, "Unknown protein excluded")
        try near(snapshot.totals.carbs, 30, "Unknown carbs excluded")
        try near(snapshot.totals.fat, 7.5, "Unknown fat excluded")
        try check(snapshot.isPartial && snapshot.knownCount == 1 && snapshot.missingCount == 1, "Explicit completeness")
        try near(MacroKind.allCases.reduce(0) { $0 + snapshot.share($1) }, 1, "Known energy shares sum to one")
        try near(snapshot.share(.fat), 67.5 / 307.5, "Shares use energy, not gram ratios or label calories")
        try near(snapshot.progress(.protein) ?? -1, 30 / 125, "Progress uses target grams")
        try check(snapshot.contributors(to: .protein).map(\.id) == [known.id], "Unknown contributors omitted")
        let high = log(food("High", p: 100), amount: 2)
        let ordered = MacroSnapshot(entries: [known, high], targets: targets)
        try check(ordered.contributors(to: .protein).first?.id == high.id, "Contributors ranked by logged portion")
        try check((ordered.progress(.protein) ?? 0) > 1, "Preserve over-target arithmetic; UI alone caps rings")
        for entries in [[], [log(food("Water", calories: 0, p: 0, c: 0, f: 0))], [unknown]] {
            let zero = MacroSnapshot(entries: entries, targets: nil)
            for macro in MacroKind.allCases {
                try near(zero.share(macro), 0, "No division by zero for no known energy")
                try check(zero.progress(macro) == nil, "No invented targets")
            }
        }
    }

    static func insights() throws {
        let base = log(food("Logged", calories: 1200, p: 20, c: 170, f: 50))
        let snapshot = MacroSnapshot(entries: [base], targets: targets)
        let good = food("Yogurt", calories: 150, p: 25, c: 5, f: 2)
        let overshoot = food("Large bowl", calories: 500, p: 25, c: 100, f: 45)
        let unknown = food("Unknown", p: 100, known: false)
        let huge = food("Huge", calories: 900, p: 100)
        let zero = food("Zero", calories: 0, p: 90)
        let result = MacroEngine.insight(snapshot: snapshot, foods: [unknown, overshoot, huge, zero, good, good], isToday: true)
        try check(result.nudge == .explore(.protein), "Focus on largest relative gap")
        try check(result.suggestions.first?.food == good, "Reward filling gap, penalize overshoot")
        try check(Set(result.suggestions.map(\.id)).count == result.suggestions.count, "Deduplicate suggestions")
        try check(!result.suggestions.contains { [unknown, huge, zero].contains($0.food) }, "Skip incomplete, oversized, and zero-calorie suggestions")
        let twin = food("Twin", calories: 150, p: 25, c: 5, f: 2)
        let favorites = MacroEngine.insight(snapshot: snapshot, foods: [good, twin], favorites: [twin.stableKey], isToday: true)
        try check(favorites.suggestions.first?.food == twin, "Favorite wins an equal-score tie")
        let upc = food("UPC cereal", calories: 150, p: 25, c: 5, f: 2, barcode: "036000291452")
        let ean = food("EAN cereal", calories: 150, p: 25, c: 5, f: 2, barcode: "0036000291452")
        try check(upc.stableKey == ean.stableKey && upc.stableKey == "barcode:00036000291452",
                  "UPC-A and zero-prefixed EAN-13 share a validated GTIN identity")
        let legacyFavorite = MacroEngine.insight(snapshot: snapshot, foods: [good, ean],
                                                  favorites: ["barcode:036000291452"], isToday: true)
        try check(legacyFavorite.suggestions.first?.food == ean,
                  "Legacy literal barcode favorites still break suggestion ties")
        let many = (0..<9).map { food("Food \($0)", calories: 150, p: 25, c: 5, f: 2) }
        let top = MacroEngine.insight(snapshot: snapshot, foods: many, isToday: true)
        try check(top.suggestions.count == 3, "Keep choices small")
        try check(top.suggestions.map(\.id) == MacroEngine.insight(snapshot: snapshot, foods: many.reversed(), isToday: true).suggestions.map(\.id), "Stable ranking independent of library order")
        let cases: [(MacroSnapshot, Bool, MacroNudge)] = [
            (MacroSnapshot(entries: [], targets: targets), true, .empty),
            (MacroSnapshot(entries: [base, log(unknown)], targets: targets), true, .incomplete),
            (MacroSnapshot(entries: [base], targets: nil), true, .observing),
            (snapshot, false, .history),
            (MacroSnapshot(entries: [log(food(calories: 2000))], targets: targets), true, .enoughForNow),
            (MacroSnapshot(entries: [log(food(calories: 1500, p: 150, c: 250, f: 75))], targets: targets), true, .enoughForNow),
            (MacroSnapshot(entries: [base], targets: MacroTargets(calories: 2000, protein: 0, carbs: 100, fat: 10)), true, .observing)
        ]
        for (sample, today, nudge) in cases {
            let info = MacroEngine.insight(snapshot: sample, foods: [good], isToday: today)
            try check(info.nudge == nudge && info.suggestions.isEmpty, "No inappropriate suggestions for \(nudge)")
        }
        try check(MacroEngine.insight(snapshot: snapshot, foods: [], isToday: true).nudge == .noMatch, "Empty eligible library explained")
        var fatGapTargets = targets; fatGapTargets.fat = 500
        try check(MacroEngine.insight(snapshot: MacroSnapshot(entries: [base], targets: fatGapTargets), foods: [good], isToday: true).nudge == .explore(.fat), "Focus is not hard-coded to protein")
    }

    static func previews() throws {
        let original = log(food(), amount: 2)
        let snapshot = MacroSnapshot(entries: [original], targets: targets)
        let added = MacroEngine.preview(snapshot: snapshot, food: food(), servings: 0.5)
        try near(added?.totals.protein ?? -1, 50, "Preview adds chosen fraction")
        try check(snapshot.entries.count == 1 && snapshot.totals.protein == 40, "Preview never mutates diary")
        let edited = MacroEngine.preview(snapshot: snapshot, food: food(), servings: 0.5, replacing: original.id)
        try near(edited?.totals.protein ?? -1, 10, "Edit preview replaces, never double counts")
        try check(edited?.entries.count == 1, "One entry after edit preview")
        try check(MacroEngine.preview(snapshot: snapshot, food: food(), servings: 1, replacing: UUID()) == nil, "Stale edits rejected")
        for amount in [0, -1, 101, Double.nan, Double.infinity] {
            try check(MacroEngine.preview(snapshot: snapshot, food: food(), servings: amount) == nil, "Reject invalid preview quantity")
        }
        let missing = MacroEngine.preview(snapshot: snapshot, food: food(known: false), servings: 1)
        try check(missing?.isPartial == true && missing?.totals.protein == 40, "Unknown preview doesn't fake macros")
    }

    static func weeks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
        func day(_ delta: Int) -> Date { calendar.date(byAdding: .day, value: delta, to: end)! }
        let entries = [log(food(), day: day(0)), log(food(), amount: 2, day: day(-3)),
                       log(food(known: false), day: day(-3)), log(food(known: false), day: day(-1)),
                       log(food(), amount: 10, day: day(-7)), log(food(), amount: 10, day: day(1))]
        let week = MacroWeek(entries: entries, ending: end, calendar: calendar)
        try check(week.days.count == 7 && Set(week.days).count == 7, "Seven unique local dates across DST")
        try check(week.daysWithMacros == 2 && week.missingCount == 2, "Exclude unknown-only and outside-range days")
        try near(week.average(.protein) ?? -1, 30, "Average only days with known macros")
        try check(week.snapshots[3].isPartial, "Partial day explicitly marked")
        let empty = MacroWeek(entries: [], ending: end, calendar: calendar)
        try check(empty.average(.protein) == nil, "No data stays absent rather than zero average")
    }

    static func persistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NibbleMacroChecks-\(UUID().uuidString)")
        let suite = "NibbleMacroChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let url = directory.appendingPathComponent("store/diary.json")
        let state = AppState(storageURL: url, defaults: defaults)
        let split = MacroSplit(protein: 30, carbs: 40, fat: 30)
        try check(state.setMacroSplit(split), "Save mix before a calorie target exists")
        try check(state.targets == nil && !state.hasStarted, "Saving mix never invents goal or starts diary")
        try check(state.startTracking(target: 2000), "Start target")
        try near(state.targets?.protein ?? -1, 150, "Custom protein target applied")
        let reopened = AppState(storageURL: url, defaults: defaults)
        try check(reopened.macroSplit == split && reopened.targets == state.targets, "Mix survives relaunch")
        try check(state.addEntry(food: food(), meal: .lunch, servings: 1), "Seed unchanged diary")
        let before = state.entries
        try check(state.startTracking(target: 2400), "Change calorie target")
        try near(state.targets?.protein ?? -1, 180, "Mix scales with calorie changes")
        try check(state.entries == before && state.macroSplit == split, "Plan changes preserve logged nutrition and mix")
        try check(!state.setMacroSplit(MacroSplit(protein: 30, carbs: 30, fat: 30)), "Invalid mix not persisted")
        try check(state.macroSplit == split, "Invalid save preserves current mix")
        try check(state.setMacroSplit(.standard) && state.archive.macroSplit == nil, "Default reset preserves compatibility")
        let oldBytes = Data("{\"version\":1,\"hasStarted\":false,\"entries\":[],\"savedFoods\":[],\"favorites\":[],\"units\":\"imperial\"}".utf8)
        let old = try JSONDecoder().decode(DiaryArchive.self, from: oldBytes)
        try check(old.macroSplit == nil, "Archives predating macro preferences remain decodable")
        let blocker = directory.appendingPathComponent("blocked")
        try Data("blocker".utf8).write(to: blocker)
        let blocked = AppState(storageURL: blocker.appendingPathComponent("diary.json"), defaults: defaults)
        try check(!blocked.setMacroSplit(split) && blocked.macroSplit == .standard && blocked.storageError != nil, "Failed mix write is transactional")
        var corrupt = state.archive; corrupt.macroSplit = MacroSplit(protein: 80, carbs: 80, fat: 80)
        let corruptBytes = try JSONEncoder().encode(corrupt)
        try corruptBytes.write(to: url)
        let bad = AppState(storageURL: url, defaults: defaults)
        try check(bad.storageError != nil && !bad.setMacroSplit(split), "Corrupt saved split is protected")
        try check(Data(contentsOf: url) == corruptBytes, "Do not overwrite original invalid archive")
    }
    struct Failure: Error { let message: String }
}
