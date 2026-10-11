import SwiftUI

/// The Island pane: a preview with the size slider, when the island shows and how it animates.
struct IslandSettingsView: View {
    /// The rows the sidebar search leaves visible.
    let shown: Set<SettingsItem>
    let openBatteryAlerts: () -> Void

    @AppStorage(Preferences.hideWhilePlayerInFrontKey) private var hideWhilePlayerInFront = true
    @AppStorage(Preferences.showInFullscreenKey) private var showInFullscreen = false
    @AppStorage(Preferences.flipArtworkKey) private var flipArtwork = true
    @AppStorage(Preferences.chargingAnimationKey) private var chargingAnimation = true
    @AppStorage(Preferences.lockScreenIconKey) private var lockScreenIcon = true
    @AppStorage(Preferences.batteryAlertsEnabledKey) private var batteryAlertsEnabled = true
    @AppStorage(Preferences.batteryAlertsKey) private var batteryAlertsData = Data()

    var body: some View {
        Group {
            if shown.contains(.islandSize) {
                Section {
                    IslandPreviewSection()
                }
            }
            section(tr("Visibility"), [
                (.hideWhilePlayerInFront, $hideWhilePlayerInFront),
                (.showInFullscreen, $showInFullscreen),
            ])
            section(tr("Animations"), [
                (.flipArtwork, $flipArtwork),
                (.chargingAnimation, $chargingAnimation),
            ])
            if shown.contains(.batteryAlerts) {
                Section(tr("Battery")) {
                    SettingsLinkRow(item: .batteryAlerts, subtitle: batteryAlertsSummary, open: openBatteryAlerts)
                }
            }
            section(tr("Lock Screen"), [
                (.lockScreenIcon, $lockScreenIcon),
            ])
        }
    }

    /// "Off", or the alerts at a glance: "↓ 20 %  ↑ 80 %".
    private var batteryAlertsSummary: String {
        guard batteryAlertsEnabled else { return tr("Off") }
        let alerts = BatteryAlerts.decode(batteryAlertsData).sorted { $0.level < $1.level }
        guard !alerts.isEmpty else { return tr("None") }
        return alerts.map { alert in
            "\(alert.direction.arrow) \((Double(alert.level) / 100).formatted(.percent.locale(Localization.locale)))"
        }.joined(separator: "   ")
    }

    /// A section of toggles, left out entirely when the search hides all of them.
    @ViewBuilder
    private func section(_ title: String, _ toggles: [(SettingsItem, Binding<Bool>)]) -> some View {
        let visible = toggles.filter { shown.contains($0.0) }
        if !visible.isEmpty {
            Section(title) {
                ForEach(visible, id: \.0) { item, isOn in
                    Toggle(isOn: isOn) {
                        SettingsLabel(item)
                    }
                }
            }
        }
    }
}
