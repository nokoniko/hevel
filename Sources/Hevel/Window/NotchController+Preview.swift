import AppKit

extension NotchController {

    /// Shows an event as if it had happened, and keeps it up until `hidePreview`, so
    /// there's time to look at it (developer builds).
    func preview(_ event: PreviewEvent) {
        switch event {
        case .music:
            // A made-up track, playing; what's really playing comes back on hide.
            model.startPreview()
        case .charging:
            showChargingFlourish(level: power.level)
            chargingClearWork?.cancel()
        case .lowBattery:
            showBatteryAlert(BatteryAlert(level: min(power.level, 20), direction: .down))
            batteryAlertClearWork?.cancel()
        case .lock:
            // The lock-screen panel, over the desktop.
            setLocked(true)
        }
    }

    func hidePreview(_ event: PreviewEvent) {
        switch event {
        case .music:
            model.stopPreview()
        case .charging:
            chargingClearWork?.cancel()
            state.chargingFlourish = nil
        case .lowBattery:
            dismissBatteryAlert()
        case .lock:
            setLocked(false)
        }
    }

    /// The next or previous made-up track, to see the cover flip that way.
    func previewTrack(forward: Bool) {
        model.stepPreview(forward: forward)
    }
}
