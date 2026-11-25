import AppKit
import SwiftUI

@MainActor
final class WindowState: ObservableObject {
    @Published var tab: WindowTab = .timer
}

/// The normal app window: the same timer face plus statistics and settings.
@MainActor
final class WindowController {
    private let state = WindowState()
    private let window: NSWindow

    init(coordinator: AppCoordinator) {
        let root = WindowRoot(coordinator: coordinator, state: state)
        let hosting = NSHostingController(rootView: root)
        window = NSWindow(contentViewController: hosting)
        window.title = "NitroBrew"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.setContentSize(NSSize(width: 460, height: 620))
    }

    func show(_ tab: WindowTab) {
        state.tab = tab
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct WindowRoot: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var state: WindowState

    var body: some View {
        TabView(selection: $state.tab) {
            TimerView(coordinator: coordinator).frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Text(String(localized: "Timer")) }.tag(WindowTab.timer)
            StatsView(stats: coordinator.stats)
                .tabItem { Text(String(localized: "Stats")) }.tag(WindowTab.stats)
            SettingsView(settings: coordinator.settings, engine: coordinator.engine)
                .tabItem { Text(String(localized: "Settings")) }.tag(WindowTab.settings)
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}
