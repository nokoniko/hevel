import SwiftUI

/// The Developer pane (developer builds only): show each island event on demand,
/// and hide it again.
struct DeveloperSettingsView: View {
    /// The rows the sidebar search leaves visible.
    let shown: Set<SettingsItem>
    let run: (DeveloperMode.Command) -> Void

    var body: some View {
        if shown.contains(.previewEvents) {
            Section {
                ForEach(PreviewEvent.allCases) { event in
                    LabeledContent {
                        HStack(spacing: 8) {
                            if event == .music {
                                // Flip the cover to a previous / next made-up track.
                                Button { run(.track(forward: false)) } label: { Image(systemName: "backward.fill") }
                                    .help(tr("Previous track"))
                                Button { run(.track(forward: true)) } label: { Image(systemName: "forward.fill") }
                                    .help(tr("Next track"))
                            }
                            Button(tr("Show")) { run(.preview(event)) }
                            Button(tr("Hide")) { run(.hide(event)) }
                        }
                    } label: {
                        Label {
                            Text(event.title)
                        } icon: {
                            icon(for: event)
                        }
                    }
                }
            } header: {
                Text(tr("Preview events"))
            } footer: {
                Text(tr("Only in builds from cargo run. From the terminal: ./preview.sh [hide] %@",
                        PreviewEvent.allCases.map(\.rawValue).joined(separator: " | ")))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func icon(for event: PreviewEvent) -> SettingsIcon {
        switch event {
        case .music: SettingsIcon(symbol: "music.note", color: .pink)
        case .charging: SettingsIcon(symbol: "bolt.fill", color: .green)
        case .lowBattery: SettingsIcon(symbol: "battery.25percent", color: .red)
        case .lock: SettingsIcon(symbol: "lock.fill", color: .indigo)
        }
    }
}
