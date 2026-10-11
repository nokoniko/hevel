import Foundation

/// User settings, stored in UserDefaults. The settings window binds to the same
/// keys with `@AppStorage`; the rest of the app reads them at the moment it acts.
enum Preferences {
    static let hideWhilePlayerInFrontKey = "hideWhilePlayerInFront"
    static let showInFullscreenKey = "showInFullscreen"
    static let flipArtworkKey = "flipArtworkOnTrackChange"
    static let chargingAnimationKey = "chargingAnimation"
    static let lockScreenIconKey = "lockScreenIcon"
    /// The switch for all battery alerts (named from when there was only the 20 % one).
    static let batteryAlertsEnabledKey = "lowBatteryAlert"
    /// The alerts themselves, JSON (`BatteryAlerts.encode`).
    static let batteryAlertsKey = "batteryAlerts"
    static let islandScaleKey = "islandScale"
    static let autoCheckForUpdatesKey = "autoCheckForUpdates"
    static let installUpdatesAutomaticallyKey = "installUpdatesAutomatically"
    static let skipSmallUpdatesKey = "skipSmallUpdates"
    static let appLanguageKey = "appLanguage"
    static let updateFrequencyKey = "updateFrequency"
    static let updateTimeOfDayKey = "updateTimeOfDay"
    /// Seconds since 1970 of the last check that reached GitHub; absent until the first one.
    static let lastUpdateCheckKey = "lastUpdateCheck"

    /// The defaults match how the app behaved before it had settings — except that
    /// updates now install without asking.
    static let defaults: [String: Any] = [
        hideWhilePlayerInFrontKey: true,
        showInFullscreenKey: false,
        flipArtworkKey: true,
        chargingAnimationKey: true,
        lockScreenIconKey: true,
        batteryAlertsEnabledKey: true,
        batteryAlertsKey: BatteryAlerts.encode(BatteryAlerts.defaults),
        islandScaleKey: 1.0,
        autoCheckForUpdatesKey: true,
        installUpdatesAutomaticallyKey: true,
        skipSmallUpdatesKey: false,
        appLanguageKey: AppLanguage.system.rawValue,
        updateFrequencyKey: UpdateFrequency.daily.rawValue,
        updateTimeOfDayKey: UpdateTimeOfDay.morning.rawValue,
    ]

    static func register() {
        UserDefaults.standard.register(defaults: defaults)
    }

    static var hideWhilePlayerInFront: Bool { UserDefaults.standard.bool(forKey: hideWhilePlayerInFrontKey) }
    static var showInFullscreen: Bool { UserDefaults.standard.bool(forKey: showInFullscreenKey) }
    static var chargingAnimation: Bool { UserDefaults.standard.bool(forKey: chargingAnimationKey) }
    static var lockScreenIcon: Bool { UserDefaults.standard.bool(forKey: lockScreenIconKey) }
    static var batteryAlertsEnabled: Bool { UserDefaults.standard.bool(forKey: batteryAlertsEnabledKey) }
    static var batteryAlerts: [BatteryAlert] {
        BatteryAlerts.decode(UserDefaults.standard.data(forKey: batteryAlertsKey))
    }
    static var islandScale: Double {
        let range = NotchMetrics.scaleRange
        return min(max(UserDefaults.standard.double(forKey: islandScaleKey), range.lowerBound), range.upperBound)
    }
    static var autoCheckForUpdates: Bool { UserDefaults.standard.bool(forKey: autoCheckForUpdatesKey) }
    static var installUpdatesAutomatically: Bool { UserDefaults.standard.bool(forKey: installUpdatesAutomaticallyKey) }
    static var skipSmallUpdates: Bool { UserDefaults.standard.bool(forKey: skipSmallUpdatesKey) }

    static var appLanguage: AppLanguage {
        UserDefaults.standard.string(forKey: appLanguageKey).flatMap(AppLanguage.init) ?? .system
    }

    static var updateFrequency: UpdateFrequency {
        UserDefaults.standard.string(forKey: updateFrequencyKey).flatMap(UpdateFrequency.init) ?? .daily
    }

    static var updateTimeOfDay: UpdateTimeOfDay {
        UserDefaults.standard.string(forKey: updateTimeOfDayKey).flatMap(UpdateTimeOfDay.init) ?? .morning
    }

    static var lastUpdateCheck: Date? {
        get {
            let seconds = UserDefaults.standard.double(forKey: lastUpdateCheckKey)
            return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        }
        set { UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: lastUpdateCheckKey) }
    }

    static func nextUpdateCheck(now: Date = Date()) -> Date {
        UpdateSchedule.nextCheck(after: lastUpdateCheck, frequency: updateFrequency,
                                 timeOfDay: updateTimeOfDay, now: now, calendar: .current)
    }
}
