import Foundation

enum AlertSound: String, CaseIterable, Codable, Identifiable {
    case softChime, glass, hero, ping, pop, purr, submarine, none

    var id: String { rawValue }

    /// macOS system sound name, or nil for the built-in chime and for silence.
    var systemSoundName: String? {
        switch self {
        case .softChime, .none: nil
        case .glass: "Glass"
        case .hero: "Hero"
        case .ping: "Ping"
        case .pop: "Pop"
        case .purr: "Purr"
        case .submarine: "Submarine"
        }
    }

    var displayName: String {
        switch self {
        case .softChime: String(localized: "Soft chime")
        case .none: String(localized: "None")
        default: systemSoundName ?? rawValue
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var vessel: Vessel { didSet { defaults.set(vessel.rawValue, forKey: "vessel") } }
    @Published var autoStartBreaks: Bool { didSet { defaults.set(autoStartBreaks, forKey: "autoStartBreaks") } }
    @Published var autoStartWork: Bool { didSet { defaults.set(autoStartWork, forKey: "autoStartWork") } }
    @Published var alertSound: AlertSound { didSet { defaults.set(alertSound.rawValue, forKey: "alertSound") } }
    @Published var showTimeInMenuBar: Bool { didSet { defaults.set(showTimeInMenuBar, forKey: "showTimeInMenuBar") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        vessel = defaults.string(forKey: "vessel").flatMap(Vessel.init(rawValue:)) ?? .pint
        autoStartBreaks = defaults.object(forKey: "autoStartBreaks") as? Bool ?? false
        autoStartWork = defaults.object(forKey: "autoStartWork") as? Bool ?? false
        alertSound = defaults.string(forKey: "alertSound").flatMap(AlertSound.init(rawValue:)) ?? .softChime
        showTimeInMenuBar = defaults.object(forKey: "showTimeInMenuBar") as? Bool ?? true
    }
}
