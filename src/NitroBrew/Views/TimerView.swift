import SwiftUI

/// The popover and window face: mode chips, animated vessel, time, status and controls.
struct TimerView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var engine: SessionEngine
    @ObservedObject private var settings: AppSettings
    var openWindow: (WindowTab) -> Void = { _ in }

    init(coordinator: AppCoordinator, openWindow: @escaping (WindowTab) -> Void = { _ in }) {
        self.coordinator = coordinator
        self.engine = coordinator.engine
        self.settings = coordinator.settings
        self.openWindow = openWindow
    }

    var body: some View {
        VStack(spacing: 12) {
            chips
            VesselView(vessel: settings.vessel, engine: engine)
                .frame(height: 220)
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                VStack(spacing: 4) {
                    Text(TimeFormat.mmss(engine.remaining))
                        .font(.system(size: 44, weight: .semibold, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(Theme.cream)
                    Text(StatusText.make(mode: engine.mode, phase: engine.phase, level: engine.fillLevel, vessel: settings.vessel))
                        .foregroundStyle(Theme.mute)
                        .font(.callout)
                }
            }
            controls
            if let message = coordinator.completion { banner(message) }
            footer
        }
        .padding(18)
        .frame(width: 340)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(SessionMode.allCases, id: \.self) { mode in
                let on = engine.mode == mode
                Button { coordinator.select(mode) } label: {
                    Text(label(for: mode))
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(on ? Theme.cream : .clear, in: Capsule())
                        .overlay(Capsule().stroke(on ? Theme.cream : Theme.line))
                        .foregroundStyle(on ? Color.black : Theme.mute)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func label(for mode: SessionMode) -> String {
        mode.isWork ? String(localized: "Work \(mode.minutes)") : String(localized: "Break \(mode.minutes)")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(primaryTitle) {
                switch engine.phase {
                case .running: coordinator.pause()
                default: coordinator.start()
                }
            }
            .buttonStyle(NitroButtonStyle(prominent: true))
            Button(String(localized: "Reset")) { coordinator.reset() }
                .buttonStyle(NitroButtonStyle(prominent: false))
        }
    }

    private var primaryTitle: String {
        switch engine.phase {
        case .running: String(localized: "Pause")
        case .paused: String(localized: "Resume")
        case .done: String(localized: "Again")
        case .idle: String(localized: "Start")
        }
    }

    private func banner(_ message: CompletionMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.cream)
            Text(message.body).font(.callout).foregroundStyle(Theme.mute)
            HStack {
                Button(message.actionTitle) { coordinator.startNext() }.buttonStyle(NitroButtonStyle(prominent: true))
                Button(String(localized: "Dismiss")) { coordinator.dismissCompletion() }.buttonStyle(NitroButtonStyle(prominent: false))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.amber))
    }

    private var footer: some View {
        HStack {
            Button(String(localized: "Stats")) { openWindow(.stats) }
            Spacer()
            Button(String(localized: "Settings")) { openWindow(.settings) }
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(Theme.mute)
    }
}

struct NitroButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(prominent ? Theme.amber : Theme.panelRaised, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(prominent ? Theme.amber : Theme.line))
            .foregroundStyle(prominent ? Color.black : Theme.cream)
            .fontWeight(prominent ? .semibold : .regular)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview("Idle") {
    TimerView(coordinator: PreviewSupport.coordinator())
}

#Preview("Running 40%") {
    TimerView(coordinator: PreviewSupport.coordinator(elapsed: 600))
}

#Preview("Done") {
    TimerView(coordinator: PreviewSupport.coordinator(elapsed: 1501, tick: true))
}

@MainActor
enum PreviewSupport {
    static func coordinator(elapsed: TimeInterval = 0, tick: Bool = false) -> AppCoordinator {
        var now = Date()
        let engine = SessionEngine(clock: { now })
        let defaults = UserDefaults(suiteName: "nitrobrew.preview")!
        let c = AppCoordinator(
            engine: engine, settings: AppSettings(defaults: defaults),
            stats: StatsStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("nb-preview.json")),
            notifier: UserNotifier(), sound: SystemSoundPlayer(), defaults: defaults)
        if elapsed > 0 { c.start(); now.addTimeInterval(elapsed); if tick { c.tick() } }
        return c
    }
}
