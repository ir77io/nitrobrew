import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var menuBar: MenuBarController?
    private var windowController: WindowController?

    func applicationDidFinishLaunching(_: Notification) {
        // Menu bar only app: no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        // The unit-test host launches this app too; do not create UI, ask for permissions or touch real data there.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NitroBrew", isDirectory: true)
        let notifier = UserNotifier()
        let coordinator = AppCoordinator(
            engine: SessionEngine(clock: Self.makeClock()),
            settings: AppSettings(),
            stats: StatsStore(fileURL: support.appendingPathComponent("sessions.json")),
            notifier: notifier,
            sound: SystemSoundPlayer())
        coordinator.restoreState()
        self.coordinator = coordinator
        Task { await notifier.requestAuthorization() }

        let window = WindowController(coordinator: coordinator)
        windowController = window
        menuBar = MenuBarController(coordinator: coordinator, openWindow: { window.show($0) })
    }

    func applicationWillTerminate(_: Notification) {
        coordinator?.saveState()
        menuBar?.cleanup()
    }

    /// Real time, except in DEBUG builds launched with `-NitroBrewDebugSpeed <n>`, which run `n` times faster.
    private static func makeClock() -> () -> Date {
        #if DEBUG
        let speed = UserDefaults.standard.double(forKey: "NitroBrewDebugSpeed")
        if speed > 1 {
            let start = Date()
            return { start.addingTimeInterval(Date().timeIntervalSince(start) * speed) }
        }
        #endif
        return Date.init
    }
}
