import AppKit
import SwiftUI

struct StatsView: View {
    @ObservedObject var stats: StatsStore
    @State private var confirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                tile(String(localized: "Today"), "\(stats.todayCount())")
                tile(String(localized: "Pours"), "\(stats.totalWorkSessions)")
                tile(String(localized: "Work time"), TimeFormat.hoursMinutes(stats.totalWorkTime))
            }
            Text(String(localized: "Recent sessions")).font(.headline).foregroundStyle(Theme.cream)
            if stats.recent.isEmpty {
                Text(String(localized: "No sessions yet. Pour your first one.")).foregroundStyle(Theme.mute)
            } else {
                ForEach(stats.recent) { record in
                    HStack {
                        Text(record.mode.isWork ? String(localized: "Work \(record.mode.minutes)") : String(localized: "Break \(record.mode.minutes)"))
                        Spacer()
                        Text(record.completed ? String(localized: "Done") : String(localized: "Skipped"))
                            .foregroundStyle(record.completed ? Theme.amber : Theme.mute)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(Theme.mute)
                    }
                    .font(.callout)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button(String(localized: "Export CSV"), action: export).buttonStyle(NitroButtonStyle(prominent: false))
                if confirmingClear {
                    Text(String(localized: "Delete all history?")).foregroundStyle(Theme.mute)
                    Button(String(localized: "Delete")) { stats.clear(); confirmingClear = false }.buttonStyle(NitroButtonStyle(prominent: true))
                    Button(String(localized: "Cancel")) { confirmingClear = false }.buttonStyle(NitroButtonStyle(prominent: false))
                } else {
                    Button(String(localized: "Clear history")) { confirmingClear = true }.buttonStyle(NitroButtonStyle(prominent: false))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .foregroundStyle(Theme.cream)
        .preferredColorScheme(.dark)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 26, weight: .semibold, design: .serif)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(Theme.mute)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "nitrobrew-sessions.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? stats.exportCSV().write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
