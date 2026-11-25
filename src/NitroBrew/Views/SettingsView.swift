import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var engine: SessionEngine

    var body: some View {
        Form {
            Section(String(localized: "Vessel")) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 10) {
                        ForEach(Vessel.allCases) { vessel in
                            let on = settings.vessel == vessel
                            Button { settings.vessel = vessel } label: {
                                VStack(spacing: 6) {
                                    Image(nsImage: MenuBarIconRenderer.image(vessel: vessel, level: engine.fillLevel, pointSize: 40))
                                        .renderingMode(.template)
                                        .foregroundStyle(Theme.cream)
                                    Text(vessel.displayName).font(.caption).foregroundStyle(on ? Theme.cream : Theme.mute)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(on ? Theme.panelRaised : Theme.panel, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Theme.amber : Theme.line))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
            Section(String(localized: "Timer")) {
                Toggle(String(localized: "Start the break automatically after a pour"), isOn: $settings.autoStartBreaks)
                Toggle(String(localized: "Start the next pour automatically after a break"), isOn: $settings.autoStartWork)
                Toggle(String(localized: "Show remaining time in the menu bar"), isOn: $settings.showTimeInMenuBar)
            }
            Section(String(localized: "Sound")) {
                Picker(String(localized: "Alert sound"), selection: $settings.alertSound) {
                    ForEach(AlertSound.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section {
                Text(AppVersion.current()).foregroundStyle(Theme.mute).font(.caption)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}
