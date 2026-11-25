import AppKit
import UserNotifications

protocol Notifying {
    func requestAuthorization() async
    func notify(_ message: CompletionMessage)
}

protocol SoundPlaying {
    func play(_ sound: AlertSound)
}

/// Lets banners show while NitroBrew is the active app (a menu bar app often is, after its popover was opened).
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let presentationOptions: UNNotificationPresentationOptions = [.banner, .list]

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(Self.presentationOptions)
    }
}

/// Posts a local notification. Failure or denied permission is silent: the app still works.
final class UserNotifier: Notifying {
    private let presenter = NotificationPresenter()

    init() {
        UNUserNotificationCenter.current().delegate = presenter
    }

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    }

    func notify(_ message: CompletionMessage) {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

final class SystemSoundPlayer: SoundPlaying {
    private var current: NSSound?

    func play(_ sound: AlertSound) {
        switch sound {
        case .none:
            return
        case .softChime:
            current = NSSound(data: Self.chimeWAV())
        default:
            current = sound.systemSoundName.flatMap { NSSound(named: NSSound.Name($0)) }
        }
        current?.play()
    }

    /// Two soft sine notes (660 Hz then 880 Hz) as 16-bit mono WAV data.
    static func chimeWAV() -> Data {
        let rate = 44_100
        let seconds = 1.5
        let count = Int(Double(rate) * seconds)
        var samples = [Int16](repeating: 0, count: count)
        for (freq, start) in [(660.0, 0.0), (880.0, 0.22)] {
            let first = Int(start * Double(rate))
            for i in first..<count {
                let t = Double(i - first) / Double(rate)
                let env = min(1, t / 0.03) * exp(-t * 3.2)
                let v = sin(2 * .pi * freq * t) * env * 0.35
                samples[i] = Int16(clamping: Int(Double(samples[i]) + v * 32_767))
            }
        }
        var data = Data()
        func put<T: FixedWidthInteger>(_ v: T) { var le = v.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        data.append("RIFF".data(using: .ascii)!); put(UInt32(36 + count * 2)); data.append("WAVEfmt ".data(using: .ascii)!)
        put(UInt32(16)); put(UInt16(1)); put(UInt16(1)); put(UInt32(rate)); put(UInt32(rate * 2)); put(UInt16(2)); put(UInt16(16))
        data.append("data".data(using: .ascii)!); put(UInt32(count * 2))
        for s in samples { put(s) }
        return data
    }
}
