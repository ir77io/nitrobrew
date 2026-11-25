import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // Menu bar only app: no Dock icon.
        NSApp.setActivationPolicy(.accessory)
    }
}
