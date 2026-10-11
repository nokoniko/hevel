import Foundation

/// A battery alert the user set up: shown when the level reaches `level` — going up
/// while the Mac charges, down while it runs on battery, or both.
struct BatteryAlert: Codable, Hashable, Identifiable {
    enum Direction: String, Codable, CaseIterable {
        case up, down, both

        func fires(goingUp: Bool) -> Bool {
            switch self {
            case .up: goingUp
            case .down: !goingUp
            case .both: true
            }
        }
    }

    var id = UUID()
    var level: Int
    var direction: Direction
}

enum BatteryAlerts {
    /// Until changed in Settings: the old fixed alert, 20 % on the way down.
    static let defaults = [BatteryAlert(level: 20, direction: .down)]

    static let levelRange = 5...100

    static func decode(_ data: Data?) -> [BatteryAlert] {
        guard let data, let alerts = try? JSONDecoder().decode([BatteryAlert].self, from: data) else { return defaults }
        return alerts
    }

    static func encode(_ alerts: [BatteryAlert]) -> Data {
        (try? JSONEncoder().encode(alerts)) ?? Data()
    }

    /// The alert a change from `previous` to `current` % reaches: one crossed going up
    /// while plugged in, or going down on battery, that fires that way (`both` fires
    /// either way). If one jump crosses several, the one nearest the new level wins.
    static func triggered(_ alerts: [BatteryAlert], from previous: Int, to current: Int, pluggedIn: Bool) -> BatteryAlert? {
        alerts
            .filter { alert in
                let crossedUp = pluggedIn && previous < alert.level && current >= alert.level
                let crossedDown = !pluggedIn && previous > alert.level && current <= alert.level
                return (crossedUp && alert.direction.fires(goingUp: true))
                    || (crossedDown && alert.direction.fires(goingUp: false))
            }
            .min { abs($0.level - current) < abs($1.level - current) }
    }

    /// The level a click on the bar picks: the nearest 5 %, within `levelRange`.
    static func level(atFraction fraction: Double) -> Int {
        let rounded = Int((min(max(fraction, 0), 1) * 20).rounded()) * 5
        return min(max(rounded, levelRange.lowerBound), levelRange.upperBound)
    }

    /// What the settings preview cycles through: each alert from the top level down,
    /// a `both` one shown going down and then up — or the default if there are none.
    static func previewSequence(_ alerts: [BatteryAlert]) -> [BatteryAlert] {
        let sorted = (alerts.isEmpty ? defaults : alerts).sorted { $0.level > $1.level }
        return sorted.flatMap { alert -> [BatteryAlert] in
            switch alert.direction {
            case .up, .down: [alert]
            case .both: [BatteryAlert(id: alert.id, level: alert.level, direction: .down),
                         BatteryAlert(id: alert.id, level: alert.level, direction: .up)]
            }
        }
    }

    /// The alert `id` moved to `level` (a pin dragged along the bar) — unless another
    /// alert already sits there, then nothing changes.
    static func moving(_ id: BatteryAlert.ID, to level: Int, in alerts: [BatteryAlert]) -> [BatteryAlert] {
        guard !alerts.contains(where: { $0.level == level && $0.id != id }) else { return alerts }
        return alerts.map { $0.id == id ? BatteryAlert(id: $0.id, level: level, direction: $0.direction) : $0 }
    }

    /// Adds an alert at `level` — counting up from the top half, down from the bottom
    /// half — unless that level already has one.
    static func adding(level: Int, to alerts: [BatteryAlert]) -> [BatteryAlert] {
        guard !alerts.contains(where: { $0.level == level }) else { return alerts }
        return alerts + [BatteryAlert(level: level, direction: level >= 50 ? .up : .down)]
    }
}
