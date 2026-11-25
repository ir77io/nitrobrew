import Foundation

struct SessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let mode: SessionMode
    let date: Date
    let completed: Bool
}

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = (try? decoder.decode([SessionRecord].self, from: data)) ?? []
        }
    }

    func add(_ record: SessionRecord) {
        records.append(record)
        save()
    }

    func clear() {
        records = []
        save()
    }

    func todayCount(calendar: Calendar = .current, now: Date = Date()) -> Int {
        records.filter { $0.completed && calendar.isDate($0.date, inSameDayAs: now) }.count
    }

    var totalWorkSessions: Int { records.filter { $0.completed && $0.mode.isWork }.count }

    var totalWorkTime: TimeInterval {
        records.filter { $0.completed && $0.mode.isWork }.reduce(0) { $0 + $1.mode.duration }
    }

    /// The ten most recent records, newest first.
    var recent: [SessionRecord] {
        Array(records.sorted { $0.date > $1.date }.prefix(10))
    }

    func exportCSV() -> String {
        let formatter = ISO8601DateFormatter()
        let rows = records.map { "\(formatter.string(from: $0.date)),\($0.mode.rawValue),\($0.completed)" }
        return (["date,mode,completed"] + rows).joined(separator: "\n") + "\n"
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
