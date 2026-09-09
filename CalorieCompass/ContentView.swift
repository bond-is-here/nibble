import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if appState.hasStarted { MainTabView() }
            else { OnboardingView() }
        }
        .background(Color.canvas)
        .preferredColorScheme(.light)
        .tint(Color.ink)
        .overlay(alignment: .top) {
            if let error = appState.storageError { InlineMessage(text: error).padding(12) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { appState.refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in appState.refreshDay() }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = 0
    @State private var addRequest: AddRequest?
    private struct AddRequest: Identifiable {
        let id = UUID()
        let meal: Meal
        var scan = false
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 0: DashboardView(onAddFood: { addRequest = AddRequest(meal: $0) }, onScan: { addRequest = AddRequest(meal: .suggested(), scan: true) })
                case 1: LogView()
                default: ProfileView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) { toastView }
            bottomBar
        }
        .background(Color.canvas.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: appState.toast)
        // Add Food is a multi-step task with long, editable forms. On iPhone, a
        // full-screen cover prevents a downward scroll at the top of a compact
        // device from being interpreted as sheet dismissal and losing the draft.
        #if os(iOS)
        .fullScreenCover(item: $addRequest) { request in AddFoodView(initialMeal: request.meal, startWithScan: request.scan) }
        #else
        .sheet(item: $addRequest) { request in AddFoodView(initialMeal: request.meal, startWithScan: request.scan).phoneSheet() }
        #endif
    }

    @ViewBuilder private var toastView: some View {
            if let toast = appState.toast {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lime)
                    Text(toast).nibbleFont(size: 12, weight: .medium).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if appState.canUndo {
                        Button("Undo") { appState.undo() }.nibbleFont(size: 12, weight: .bold).foregroundStyle(Color.lime).buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }.padding(16).foregroundStyle(.white).background(Color.ink, in: Capsule())
                    .padding(.horizontal, 22).padding(.bottom, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .contain)
            }
    }

    private var bottomBar: some View {
        NibbleAdaptiveStack(spacing: 8) {
            HStack(spacing: 4) {
            navItem(0, title: "Diary", icon: "square.grid.2x2")
            navItem(1, title: "Patterns", icon: "chart.bar.xaxis")
            navItem(2, title: "You", icon: "face.smiling")
            }
            Button { addRequest = AddRequest(meal: .suggested()) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 17, weight: .medium))
                    Text("Add food").nibbleFont(size: 14, weight: .semibold)
                }.foregroundStyle(Color.ink).padding(.horizontal, 20).padding(.vertical, 13)
                    .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 49)
                    .background(Color.lime, in: Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 13)
        .background(Color.paper)
        .overlay(alignment: .top) { Color.line.frame(height: 1) }
    }

    private func navItem(_ value: Int, title: String, icon: String) -> some View {
        Button { tab = value } label: {
            VStack(spacing: 5) {
                Image(systemName: tab == value && value == 0 ? "square.grid.2x2.fill" : icon).font(.system(size: 19, weight: .medium))
                Text(title).nibbleFont(size: 11, weight: tab == value ? .bold : .medium)
            }.foregroundStyle(tab == value ? Color.ink : Color.muted)
                .frame(maxWidth: .infinity, minHeight: 47).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}
