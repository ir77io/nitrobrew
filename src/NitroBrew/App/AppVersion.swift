import Foundation

/// The version the app shows. It comes from the bundle, which is built from `MARKETING_VERSION` in `src/project.yml`.
enum AppVersion {
    static func display(from info: [String: Any]?) -> String {
        guard let short = info?["CFBundleShortVersionString"] as? String, !short.isEmpty else {
            return String(localized: "Version unknown")
        }
        if let build = info?["CFBundleVersion"] as? String, !build.isEmpty {
            return String(localized: "Version \(short) (\(build))")
        }
        return String(localized: "Version \(short)")
    }

    static func current(bundle: Bundle = .main) -> String {
        display(from: bundle.infoDictionary)
    }
}
