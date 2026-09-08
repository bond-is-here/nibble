import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var archive = DiaryArchive()
    @Published var selectedDate = Date()
    @Published private(set) var toast: String?
    @Published private(set) var storageError: String?
    @Published private(set) var canUndo = false
    private let storageURL: URL
    private let isDemo: Bool
    private var writable = true
    private var undoAction: UndoAction?
    private var toastTask: Task<Void, Never>?
    private var lastToday = Date()
    private enum UndoAction { case added(UUID), removed(FoodLogEntry), edited(FoodLogEntry) }

    init(storageURL: URL? = nil, defaults: UserDefaults = .standard, demo: Bool = false) {
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Nibble/diary.json")
        self.isDemo = demo
        if demo {
            seedPreview()
            return
        }
        do {
            try prepareStorage()
            let legacy = try relocateLegacy(defaults)
            if FileManager.default.fileExists(atPath: self.storageURL.path) {
                let loaded = try JSONDecoder().decode(DiaryArchive.self, from: Data(contentsOf: self.storageURL))
                guard Self.isValid(loaded) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                archive = loaded
            } else {
                var imported = DiaryArchive()
                func data(_ key: String) throws -> Data? {
                    guard let value = legacy[key] else { return nil }
                    guard let bytes = value as? Data else { throw CocoaError(.fileReadCorruptFile) }
                    return bytes
                }
                if let data = try data("calorieCompass.profile") {
                    imported.profile = try JSONDecoder().decode(UserProfile.self, from: data)
                    imported.hasStarted = true
                }
                if let data = try data("calorieCompass.entries") {
                    imported.entries = try JSONDecoder().decode([FoodLogEntry].self, from: data)
                }
                if let data = try data("calorieCompass.savedFoods") {
                    imported.savedFoods = try JSONDecoder().decode([FoodItem].self, from: data)
                }
                imported.hasStarted = imported.hasStarted || !imported.entries.isEmpty
                guard Self.isValid(imported) else { throw CocoaError(.fileReadCorruptFile) }
                if imported.hasStarted || !imported.entries.isEmpty || !imported.savedFoods.isEmpty {
                    if !commit(imported) {
                        writable = false
                        storageError = "Your earlier diary couldn’t be saved. Its original data is preserved; free storage and reopen Nibble to retry."
                    }
                }
            }
        } catch {
            writable = false
            archive = DiaryArchive()
            storageError = "Your saved data couldn’t be opened or protected. The original records are preserved. Free storage and reopen Nibble to retry."
        }
    }

    private var legacyURL: URL { storageURL.deletingLastPathComponent().appendingPathComponent("legacy-recovery.plist") }
    private static let legacyKeys = ["calorieCompass.profile", "calorieCompass.entries", "calorieCompass.savedFoods"]

    /// Exclude the dedicated folder before writing, so atomic replacements and recovery files
    /// inherit the exclusion. Existing files also receive iOS complete data protection.
    private func prepareStorage() throws {
        let manager = FileManager.default
        var directory = storageURL.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        #if os(iOS)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        for file in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
        }
        #endif
    }

    private func writeProtected(_ data: Data, to url: URL) throws {
        try prepareStorage()
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    /// Preserve the exact legacy property-list values (even malformed JSON) before removing
    /// their backup-eligible defaults copies. The last snapshot resumes an interrupted import.
    /// Existing diary.json always wins over these recovery records.
    private func relocateLegacy(_ defaults: UserDefaults) throws -> [String: Any] {
        var snapshots: [[String: Any]] = []
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            let data = try Data(contentsOf: legacyURL)
            guard let decoded = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]],
                  !decoded.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            snapshots = decoded
        }
        let live = Dictionary(uniqueKeysWithValues: Self.legacyKeys.compactMap { key in
            defaults.object(forKey: key).map { (key, $0) }
        })
        if !live.isEmpty {
            // A crash during defaults cleanup can leave only a subset of a saved snapshot.
            let alreadySaved = snapshots.last.map { snapshot in
                live.allSatisfy { key, value in
                    guard let original = snapshot[key] else { return false }
                    return NSDictionary(dictionary: [key: original]).isEqual(to: [key: value])
                }
            } ?? false
            if !alreadySaved {
                snapshots.append(live)
                let bytes = try PropertyListSerialization.data(fromPropertyList: snapshots, format: .binary, options: 0)
                try writeProtected(bytes, to: legacyURL)
                guard try Data(contentsOf: legacyURL) == bytes else { throw CocoaError(.fileWriteUnknown) }
            }
            for key in live.keys { defaults.removeObject(forKey: key) }
            // This one-time migration must flush removals before reporting completion.
            guard defaults.synchronize() else { throw CocoaError(.fileWriteUnknown) }
        }
        return snapshots.last ?? [:]
    }

    var profile: UserProfile? { archive.profile }
    var entries: [FoodLogEntry] { archive.entries }
    var hasStarted: Bool { archive.hasStarted }
    var isPreview: Bool { isDemo }
    var macroSplit: MacroSplit { archive.macroSplit ?? .standard }
    var targets: MacroTargets? {
        let calories = archive.calorieTarget ?? profile.flatMap { $0.isValid ? NutritionEngine.targets(for: $0).calories : nil }
        return calories.map { NutritionEngine.macroTargets(calories: $0, split: macroSplit) }
    }
    @discardableResult
    func setMacroSplit(_ split: MacroSplit) -> Bool {
        guard split.isValid else { return false }
        var next = archive
        next.macroSplit = split == .standard ? nil : split
        return commit(next)
    }
    var selectedEntries: [FoodLogEntry] { entries(on: selectedDate) }
    var selectedTotals: DailyTotals { DailyTotals(entries: selectedEntries) }
    var todayEntries: [FoodLogEntry] { entries(on: Date()) }
    var todayTotals: DailyTotals { DailyTotals(entries: todayEntries) }
    var allFoods: [FoodItem] {
        var keys = Set<String>()
        return (archive.savedFoods + Self.foodDatabase).filter { keys.insert($0.stableKey).inserted }
    }
    var recentFoods: [FoodItem] {
        var keys = Set<String>()
        return entries.sorted { $0.date > $1.date }.compactMap { keys.insert($0.food.stableKey).inserted ? $0.food : nil }.prefix(12).map { $0 }
    }
    var favoriteFoods: [FoodItem] { allFoods.filter(isFavorite) }
    var quickFoods: [FoodItem] {
        var keys = Set<String>()
        return (favoriteFoods + recentFoods + Self.foodDatabase).filter { keys.insert($0.stableKey).inserted }.prefix(8).map { $0 }
    }
    func entries(on date: Date) -> [FoodLogEntry] {
        archive.entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date }
    }
    func isFavorite(_ food: FoodItem) -> Bool {
        !archive.favorites.isDisjoint(with: food.favoriteKeys)
    }
    func toggleFavorite(_ food: FoodItem) {
        guard food.isValid else { return }
        var next = archive
        if !next.favorites.isDisjoint(with: food.favoriteKeys) {
            next.favorites.subtract(food.favoriteKeys)
        }
        else {
            next.favorites.insert(food.stableKey)
            if !next.savedFoods.contains(where: { $0.stableKey == food.stableKey }) { next.savedFoods.append(food) }
        }
        _ = commit(next)
    }

    @discardableResult
    func startTracking(profile: UserProfile? = nil, target: Double? = nil, units: DisplayUnits = .imperial) -> Bool {
        if let profile, !profile.isValid { return false }
        if let target, !target.isFinite || !(1000...6000).contains(target) { return false }
        var next = archive
        next.hasStarted = true
        next.profile = profile
        next.calorieTarget = target
        next.units = units
        return commit(next)
    }

    @discardableResult
    func addEntry(food: FoodItem, meal: Meal, servings: Double, date: Date? = nil) -> Bool {
        guard food.isValid, servings.isFinite, (0.01...100).contains(servings) else { return false }
        let selected = date ?? selectedDate
        guard Calendar.current.startOfDay(for: selected) <= Calendar.current.startOfDay(for: Date()) else { return false }
        let stamp = Calendar.current.isDateInToday(selected) ? Date() : selected
        let entry = FoodLogEntry(date: stamp, meal: meal, food: food, servings: servings)
        var next = archive
        next.entries.insert(entry, at: 0)
        if food.source != .local {
            if let index = next.savedFoods.firstIndex(where: { $0.stableKey == food.stableKey }) { next.savedFoods[index] = food }
            else { next.savedFoods.insert(food, at: 0) }
        }
        guard commit(next) else { return false }
        undoAction = .added(entry.id)
        announce("\(food.name) added", undo: true)
        return true
    }

    func deleteEntry(_ entry: FoodLogEntry) {
        guard let actual = archive.entries.first(where: { $0.id == entry.id }) else { return }
        var next = archive
        next.entries.removeAll { $0.id == entry.id }
        guard commit(next) else { return }
        undoAction = .removed(actual)
        announce("Food removed", undo: true)
    }

    @discardableResult
    func editEntry(_ entry: FoodLogEntry, meal: Meal, servings: Double) -> Bool {
        guard servings.isFinite, (0.01...100).contains(servings), let index = archive.entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        let actual = archive.entries[index]
        var next = archive
        next.entries[index].servings = servings
        next.entries[index].meal = meal
        guard commit(next) else { return false }
        undoAction = .edited(actual)
        announce("Entry updated", undo: true)
        return true
    }

    func undo() {
        guard let action = undoAction else { return }
        var next = archive
        switch action {
        case .added(let id): next.entries.removeAll { $0.id == id }
        case .removed(let entry): next.entries.append(entry)
        case .edited(let entry):
            if let index = next.entries.firstIndex(where: { $0.id == entry.id }) { next.entries[index] = entry }
        }
        guard commit(next) else { return }
        undoAction = nil
        announce("Undone", undo: false)
    }

    func refreshDay() {
        if Calendar.current.isDate(selectedDate, inSameDayAs: lastToday) { selectedDate = Date() }
        lastToday = Date()
    }

    private func announce(_ message: String, undo: Bool) {
        toastTask?.cancel()
        toast = message
        canUndo = undo
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func commit(_ next: DiaryArchive) -> Bool {
        guard writable else { return false }
        guard Self.isValid(next) else {
            storageError = "That change contains invalid data and wasn’t saved."
            return false
        }
        do {
            if !isDemo {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                try writeProtected(encoder.encode(next), to: storageURL)
            }
            archive = next
            storageError = nil
            return true
        } catch {
            storageError = "That change couldn’t be saved. Check available storage and try again."
            return false
        }
    }

    private static func isValid(_ data: DiaryArchive) -> Bool {
        data.version == 1
        && (data.profile.map(\.isValid) ?? true)
        && (data.macroSplit.map(\.isValid) ?? true)
        && (data.calorieTarget.map { $0.isFinite && (1000...6000).contains($0) } ?? true)
        && data.entries.allSatisfy {
            $0.food.isValid && $0.date.timeIntervalSince1970.isFinite
            && $0.servings.isFinite && (0.01...100).contains($0.servings)
        }
        && Set(data.entries.map(\.id)).count == data.entries.count
        && data.savedFoods.allSatisfy(\.isValid)
    }

    private func seedPreview() {
        archive.hasStarted = true
        archive.calorieTarget = 2100
        let foods = Self.foodDatabase
        let selections: [(Int, Meal)] = [(0, .breakfast), (1, .breakfast), (6, .lunch), (8, .snack)]
        for (index, meal) in selections { archive.entries.append(FoodLogEntry(meal: meal, food: foods[index], servings: 1)) }
        for offset in 1...5 {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            archive.entries.append(FoodLogEntry(date: date, meal: .lunch, food: foods[6], servings: Double(offset % 3 + 2)))
        }
        archive.favorites = [foods[0].stableKey, foods[1].stableKey, foods[7].stableKey]
    }

    // Generic estimates. Exact label values can be entered with Make a food.
    static let foodDatabase: [FoodItem] = [
        FoodItem(name: "Greek yogurt", brand: "Plain, 2%", servingText: "1 cup", calories: 150, protein: 20, carbs: 8, fat: 4),
        FoodItem(name: "Banana", brand: nil, servingText: "1 medium", calories: 105, protein: 1.3, carbs: 27, fat: 0.4),
        FoodItem(name: "Eggs", brand: "Large", servingText: "2 eggs", calories: 144, protein: 13, carbs: 1, fat: 10),
        FoodItem(name: "Chicken breast", brand: "Roasted", servingText: "100 g", calories: 165, protein: 31, carbs: 0, fat: 3.6),
        FoodItem(name: "Oatmeal", brand: "Cooked in water", servingText: "1 cup", calories: 166, protein: 6, carbs: 28, fat: 3.6),
        FoodItem(name: "Avocado toast", brand: "Generic estimate", servingText: "1 slice", calories: 260, protein: 7, carbs: 31, fat: 13),
        FoodItem(name: "Salmon bowl", brand: "Rice + greens · estimate", servingText: "1 bowl", calories: 485, protein: 32, carbs: 48, fat: 17),
        FoodItem(name: "Almond butter toast", brand: "Generic estimate", servingText: "1 slice", calories: 275, protein: 10, carbs: 28, fat: 15),
        FoodItem(name: "Berry smoothie", brand: "Whey + berries · estimate", servingText: "1 glass", calories: 310, protein: 30, carbs: 32, fat: 7),
        FoodItem(name: "Apple", brand: nil, servingText: "1 medium", calories: 95, protein: 0.5, carbs: 25, fat: 0.3),
        FoodItem(name: "White rice", brand: "Cooked", servingText: "100 g", calories: 130, protein: 2.7, carbs: 28, fat: 0.3),
        FoodItem(name: "Black coffee", brand: nil, servingText: "1 cup", calories: 2, protein: 0.3, carbs: 0, fat: 0),
        FoodItem(name: "Almonds", brand: nil, servingText: "28 g handful", calories: 164, protein: 6, carbs: 6, fat: 14),
        FoodItem(name: "Whole milk", brand: nil, servingText: "100 ml", calories: 61, protein: 3.2, carbs: 4.8, fat: 3.3),
        FoodItem(name: "Pasta", brand: "Cooked, plain", servingText: "100 g", calories: 158, protein: 5.8, carbs: 31, fat: 0.9),
        FoodItem(name: "Baked potato", brand: "No toppings", servingText: "1 medium", calories: 161, protein: 4.3, carbs: 37, fat: 0.2),
        FoodItem(name: "Dark chocolate", brand: "70–85% cocoa", servingText: "28 g", calories: 170, protein: 2.2, carbs: 13, fat: 12)
    ]
}
