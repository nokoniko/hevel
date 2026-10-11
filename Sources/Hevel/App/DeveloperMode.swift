import Foundation

/// Builds from `cargo run` (never releases) are developer builds: Settings gets a
/// Developer pane, and the `hevel://` URL scheme (used by `preview.sh`) triggers the
/// island's events on demand instead of waiting for them to happen.
enum DeveloperMode {
    static var isEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "HevelDeveloperBuild") as? Bool ?? false
    }

    enum Command: Equatable {
        case preview(PreviewEvent)
        case hide(PreviewEvent)
        /// Next (`true`) or previous made-up track during the playback preview.
        case track(forward: Bool)
        case openSettings
    }

    /// `hevel://preview/<event>`, `hevel://hide/<event>`, `hevel://track/next`,
    /// `hevel://track/previous` or `hevel://settings`.
    static func command(for url: URL) -> Command? {
        guard url.scheme == "hevel" else { return nil }
        switch url.host() {
        case "settings":
            return .openSettings
        case "preview":
            return PreviewEvent(rawValue: url.lastPathComponent).map(Command.preview)
        case "hide":
            return PreviewEvent(rawValue: url.lastPathComponent).map(Command.hide)
        case "track":
            switch url.lastPathComponent {
            case "next": return .track(forward: true)
            case "previous": return .track(forward: false)
            default: return nil
            }
        default:
            return nil
        }
    }
}

/// An island event that can be shown on demand in a developer build.
enum PreviewEvent: String, CaseIterable, Identifiable {
    case music, charging, lowBattery, lock

    var id: Self { self }

    var title: String {
        switch self {
        case .music: tr("Playback")
        case .charging: tr("Charging animation")
        case .lowBattery: tr("Low battery alert")
        case .lock: tr("Lock screen icon")
        }
    }
}
