import SwiftUI

@main
struct NibbleApp: App {
    @StateObject private var appState = AppState(demo: CommandLine.arguments.contains("--demo"))
    var body: some Scene {
        #if os(macOS)
        WindowGroup("Nibble") {
            ContentView().environmentObject(appState).frame(minWidth: 390, idealWidth: 430, maxWidth: 520, minHeight: 700)
        }
        .defaultSize(width: 430, height: 900)
        .windowResizability(.contentSize)
        #else
        WindowGroup { ContentView().environmentObject(appState) }
        #endif
    }
}
