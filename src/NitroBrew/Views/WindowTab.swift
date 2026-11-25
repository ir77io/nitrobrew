enum WindowTab: String, CaseIterable, Identifiable {
    case timer, stats, settings
    var id: String { rawValue }
}
