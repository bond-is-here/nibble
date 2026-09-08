import SwiftUI

@main
struct NibbleApp: App {
    #if os(macOS)
    // This target is a development-only native preview, never a real diary.
    @StateObject private var appState = AppState(demo: true)
    #else
    @StateObject private var appState = NibbleApp.makeAppState()

    @MainActor private static func makeAppState() -> AppState {
        #if DEBUG
        // UI tests exercise real persistence, but never share or erase a customer's diary.
        // A validated UUID prevents a launch environment value from choosing arbitrary paths.
        if let value = ProcessInfo.processInfo.environment["NIBBLE_UI_TEST_ID"],
           let id = UUID(uuidString: value),
           let defaults = UserDefaults(suiteName: "com.caloriecompass.uitests.\(id.uuidString)") {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NibbleUITests-\(id.uuidString)", isDirectory: true)
            return AppState(storageURL: directory.appendingPathComponent("diary.json"), defaults: defaults)
        }
        #endif
        return AppState(demo: CommandLine.arguments.contains("--demo"))
    }
    #endif
    var body: some Scene {
        #if os(macOS)
        WindowGroup("Nibble") {
            ContentView().environmentObject(appState).frame(minWidth: 390, idealWidth: 430, maxWidth: 520, minHeight: 700)
        }
        .defaultSize(width: 430, height: 900)
        .windowResizability(.contentSize)
        #else
        WindowGroup { ContentView().environmentObject(appState).modifier(NibbleUITestAppearance()) }
        #endif
    }
}

/// Exercise the same Dynamic Type layout path without changing device-wide settings.
/// Only UUID-isolated Debug test launches can override the real environment.
private struct NibbleUITestAppearance: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["NIBBLE_UI_TEST_ID"], UUID(uuidString: id) != nil,
           ProcessInfo.processInfo.environment["NIBBLE_UI_TEST_TEXT_SIZE"] == "accessibility5" {
            content.dynamicTypeSize(.accessibility5).environment(\.accessibilityReduceMotion, true)
        } else { content }
        #else
        content
        #endif
    }
}
