import AppKit

extension NotchController {

    func setupCharging() {
        power.onPlugChange = { [weak self] pluggedIn in
            guard let self else { return }
            self.chargingClearWork?.cancel()
            // Plugging in ends a "running down" alert, unplugging a "charging up" one.
            if let shown = self.state.batteryAlert, (shown.direction == .down) == pluggedIn {
                self.dismissBatteryAlert()
            }
            if pluggedIn && Preferences.chargingAnimation {
                self.showChargingFlourish(level: self.power.level)
            } else {
                self.state.chargingFlourish = nil
            }
        }
        power.onLevelChange = { [weak self] previous, current, pluggedIn in
            guard let self, Preferences.batteryAlertsEnabled,
                  BatteryAlerts.triggered(Preferences.batteryAlerts, from: previous, to: current,
                                          pluggedIn: pluggedIn) != nil
            else { return }
            // Shown the way it actually went, also for a `both` alert.
            self.showBatteryAlert(BatteryAlert(level: current, direction: pluggedIn ? .up : .down))
        }
        state.onTapAlert = { [weak self] in
            if self?.state.batteryAlert?.direction == .down,
               let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
            self?.dismissBatteryAlert()
        }
        power.start()
    }

    /// The bolt and battery ring for a few seconds.
    func showChargingFlourish(level: Int) {
        chargingClearWork?.cancel()
        state.chargingFlourish = level
        let work = DispatchWorkItem { [weak self] in self?.state.chargingFlourish = nil }
        chargingClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    /// Grows the island into a battery alert for a few seconds.
    func showBatteryAlert(_ alert: BatteryAlert) {
        batteryAlertClearWork?.cancel()
        state.batteryAlert = alert
        updateForPointer()
        let work = DispatchWorkItem { [weak self] in self?.dismissBatteryAlert() }
        batteryAlertClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    func dismissBatteryAlert() {
        batteryAlertClearWork?.cancel()
        guard state.batteryAlert != nil else { return }
        state.batteryAlert = nil
        updateForPointer()
    }
}
