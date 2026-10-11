import SwiftUI

/// A battery alert's content, below the notch: "80% Battery" and a line about it on
/// the left, the battery at its level and color on the right (mirrored in Hebrew).
struct BatteryAlertView: View {
    let alert: BatteryAlert
    let metrics: NotchMetrics

    private var subtitle: String {
        switch alert.direction {
        case .up:
            tr("Reached while charging")
        case .down, .both:   // shown alerts carry the way it went; never .both
            ProcessInfo.processInfo.isLowPowerModeEnabled
                ? tr("Low Power Mode is on") : tr("Click to open Low Power Mode settings")
        }
    }

    /// The SF Symbol battery closest to the level.
    private var symbol: String {
        switch alert.level {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }

    var body: some View {
        let color = ChargingRing.color(for: alert.level)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("%@ Battery", (Double(alert.level) / 100).formatted(.percent.locale(Localization.locale))))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 64, height: 42)
                .background(Capsule().fill(color.opacity(0.22)))
        }
        .padding(.horizontal, 22)
        .frame(width: metrics.alertWidth, height: metrics.alertContentHeight)
        .padding(.top, metrics.notchHeight)
    }
}
