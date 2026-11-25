import AppKit
import Combine
import SwiftUI

/// The status item: a template icon of the chosen vessel that fills with progress, remaining time beside it,
/// a popover on left click and a small menu on right click.
@MainActor
final class MenuBarController: NSObject {
    private let coordinator: AppCoordinator
    private let openWindow: (WindowTab) -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastIconKey = ""

    init(coordinator: AppCoordinator, openWindow: @escaping (WindowTab) -> Void) {
        self.coordinator = coordinator
        self.openWindow = openWindow
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: TimerView(coordinator: coordinator, openWindow: { [weak self] tab in
                self?.popover.performClose(nil)
                self?.openWindow(tab)
            }))

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickAndRefresh() }
        }
        timer?.tolerance = 0.1
        RunLoop.main.add(timer!, forMode: .common)

        coordinator.settings.objectWillChange
            .merge(with: coordinator.engine.objectWillChange)
            .sink { [weak self] in DispatchQueue.main.async { self?.refresh() } }
            .store(in: &cancellables)
        refresh()
    }

    func cleanup() {
        timer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func tickAndRefresh() {
        coordinator.tick()
        refresh()
    }

    private func refresh() {
        guard let button = statusItem.button else { return }
        let engine = coordinator.engine, settings = coordinator.settings
        let level = engine.fillLevel
        let key = "\(settings.vessel.rawValue)-\(Int((level * 400).rounded()))"
        if key != lastIconKey {
            lastIconKey = key
            let image = MenuBarIconRenderer.image(vessel: settings.vessel, level: level)
            image.accessibilityDescription = "NitroBrew"
            button.image = image
        }
        button.title = settings.showTimeInMenuBar ? " " + TimeFormat.mmss(engine.remaining) : ""
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            statusItem.menu = makeMenu()
            sender.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let running = coordinator.engine.phase == .running
        menu.addItem(item(running ? String(localized: "Pause") : String(localized: "Start"), #selector(toggleRun)))
        menu.addItem(item(String(localized: "Reset"), #selector(reset)))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Open Window"), #selector(openMain)))
        menu.addItem(item(String(localized: "Settings…"), #selector(openSettings)))
        menu.addItem(item(String(localized: "About NitroBrew"), #selector(about)))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Quit NitroBrew"), #selector(quit)))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc private func toggleRun() {
        coordinator.engine.phase == .running ? coordinator.pause() : coordinator.start()
    }
    @objc private func reset() { coordinator.reset() }
    @objc private func openMain() { openWindow(.timer) }
    @objc private func openSettings() { openWindow(.settings) }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
