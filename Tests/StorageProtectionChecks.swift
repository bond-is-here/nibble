import Foundation

@main
@MainActor
struct StorageProtectionChecks {
    static var checks = 0
    struct Failure: Error { let message: String }
    static func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        checks += 1
        if try !value() { throw Failure(message: message) }
    }
    static func fixture(_ body: (URL, UserDefaults) throws -> Void) throws {
        let id = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NibbleStorage-\(id)")
        let defaults = UserDefaults(suiteName: "NibbleStorage.\(id)")!
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: "NibbleStorage.\(id)")
        }
        try body(directory.appendingPathComponent("store/diary.json"), defaults)
    }
    static let key = "calorieCompass.entries"
    static let sample = FoodLogEntry(meal: .lunch, food: FoodItem(name: "Sample", servingText: "1 bowl",
        calories: 200, protein: 10, carbs: 20, fat: 8), servings: 1)
    static func recovery(_ url: URL) -> URL { url.deletingLastPathComponent().appendingPathComponent("legacy-recovery.plist") }
    static func snapshots(_ url: URL) throws -> [[String: Any]] {
        guard let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: recovery(url)), format: nil) as? [[String: Any]] else {
            throw Failure(message: "Recovery must preserve property-list values")
        }
        return values
    }
    static func excluded(_ url: URL) throws -> Bool {
        // Fresh URL avoids a cached resource value from before migration.
        try URL(fileURLWithPath: url.deletingLastPathComponent().path)
            .resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true
    }
    static func main() throws {
        try fixture { url, defaults in
            let state = AppState(storageURL: url, defaults: defaults)
            try check(excluded(url), "Exclude folder before the first diary write")
            try check(state.startTracking(target: 2000), "First protected save")
            try check(state.addEntry(food: sample.food, meal: .lunch, servings: 1), "Second atomic save")
            try check(excluded(url), "Atomic replacement must retain inherited backup exclusion")
            try check(AppState(storageURL: url, defaults: defaults).archive == state.archive, "Protected diary survives relaunch")
        }
        try fixture { url, defaults in
            let bytes = try JSONEncoder().encode([sample])
            defaults.set(bytes, forKey: key)
            defaults.set("Keep me", forKey: "unrelated.preference")
            let state = AppState(storageURL: url, defaults: defaults)
            try check(state.hasStarted && state.entries == [sample], "Entries-only legacy install opens its existing diary")
            try check(defaults.object(forKey: key) == nil, "Health data removed from backup-eligible defaults")
            try check((snapshots(url).last?[key] as? Data) == bytes, "Original bytes retained exactly")
            try check(defaults.string(forKey: "unrelated.preference") == "Keep me", "Migration changes only its own keys")
            try check(excluded(url), "Recovery shares excluded folder")
            state.deleteEntry(sample)
            try check(AppState(storageURL: url, defaults: defaults).entries.isEmpty, "Recovery must never resurrect a deleted entry")
        }
        // Legacy copies still exist in build 2 even after a successful JSON migration.
        try fixture { url, defaults in
            let current = AppState(storageURL: url, defaults: defaults)
            try check(current.startTracking(target: 2400), "Seed current diary")
            defaults.set(try JSONEncoder().encode([sample]), forKey: key)
            let before = try Data(contentsOf: url)
            let reopened = AppState(storageURL: url, defaults: defaults)
            try check(reopened.archive == current.archive && Data(contentsOf: url) == before, "Current archive wins during cleanup")
            try check(defaults.object(forKey: key) == nil && snapshots(url).count == 1, "Existing installs relocate retained defaults too")
        }
        for malformed: Any in [Data("broken JSON".utf8), "unexpected property-list type"] {
            try fixture { url, defaults in
                defaults.set(malformed, forKey: key)
                let state = AppState(storageURL: url, defaults: defaults)
                try check(state.storageError != nil && !state.startTracking(), "Malformed legacy values cannot be silently discarded")
                try check(defaults.object(forKey: key) == nil, "Even malformed records leave backup-eligible defaults")
                try check(NSDictionary(dictionary: try snapshots(url).last!).isEqual(to: [key: malformed]), "Malformed originals stay recoverable")
                try check(AppState(storageURL: url, defaults: defaults).storageError != nil, "Relaunch still protects invalid recovery")
            }
        }
        // Simulate termination between recovery write and completing defaults cleanup/import.
        try fixture { url, defaults in
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let bytes = try JSONEncoder().encode([sample])
            let payload: [String: Any] = [key: bytes, "calorieCompass.savedFoods": try JSONEncoder().encode([sample.food])]
            try PropertyListSerialization.data(fromPropertyList: [payload], format: .binary, options: 0).write(to: recovery(url))
            defaults.set(bytes, forKey: key)
            let state = AppState(storageURL: url, defaults: defaults)
            try check(state.entries == [sample] && state.archive.savedFoods == [sample.food], "Resume interrupted cleanup with the full snapshot")
            try check(snapshots(url).count == 1 && defaults.object(forKey: key) == nil, "Retry is idempotent")
            try check(excluded(url), "Existing files protected on startup")
        }
        try fixture { url, defaults in
            let bytes = try JSONEncoder().encode([sample])
            try FileManager.default.createDirectory(at: recovery(url), withIntermediateDirectories: true)
            defaults.set(bytes, forKey: key)
            let state = AppState(storageURL: url, defaults: defaults)
            try check(state.storageError != nil && defaults.data(forKey: key) == bytes, "Failed recovery save never removes the source")
            try check(!state.startTracking(), "Failed protection cannot be bypassed by starting fresh")
        }
        try fixture { url, defaults in
            let demo = AppState(storageURL: url, defaults: defaults, demo: true)
            try check(demo.isPreview && !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path), "Demo never writes or migrates personal data")
        }
        print("Passed \(checks) protected-storage checks.")
    }
}
