import SwiftUI

/// Island → Battery alerts: a 0–100 % bar you click to add an alert at that level,
/// and a row per alert to pick whether it fires charging up, running down, or both.
struct BatteryAlertsSettingsView: View {
    @AppStorage(Preferences.batteryAlertsEnabledKey) private var enabled = true
    @AppStorage(Preferences.batteryAlertsKey) private var data = Data()

    private var alerts: [BatteryAlert] {
        get { BatteryAlerts.decode(data) }
        nonmutating set { data = BatteryAlerts.encode(newValue) }
    }

    var body: some View {
        Section {
            Toggle(isOn: $enabled) {
                SettingsLabel(.batteryAlerts)
            }
        }
        Section {
            BatteryAlertBar(alerts: alerts) { level in
                alerts = BatteryAlerts.adding(level: level, to: alerts)
            } move: { id, level in
                alerts = BatteryAlerts.moving(id, to: level, in: alerts)
            }
        } header: {
            Text(tr("Click the bar to add an alert at that level"))
        }
        .disabled(!enabled)
        Section {
            if alerts.isEmpty {
                Text(tr("No alerts yet"))
                    .foregroundStyle(.secondary)
            }
            ForEach(alerts.sorted { $0.level > $1.level }) { alert in
                row(alert)
            }
        } footer: {
            Text(tr("Up: when charging reaches the level. Down: when the battery runs down to it. Both: either way."))
                .foregroundStyle(.secondary)
        }
        .disabled(!enabled)
    }

    private func row(_ alert: BatteryAlert) -> some View {
        LabeledContent {
            HStack(spacing: 10) {
                Picker(selection: direction(of: alert)) {
                    Label(tr("Charging up"), systemImage: "arrow.up").tag(BatteryAlert.Direction.up)
                    Label(tr("Running down"), systemImage: "arrow.down").tag(BatteryAlert.Direction.down)
                    Label(tr("Both"), systemImage: "arrow.up.arrow.down").tag(BatteryAlert.Direction.both)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Button {
                    alerts.removeAll { $0.id == alert.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(tr("Delete"))
            }
        } label: {
            Label {
                Text((Double(alert.level) / 100).formatted(.percent.locale(Localization.locale)))
                    .monospacedDigit()
            } icon: {
                SettingsIcon(symbol: alert.direction.symbol, color: ChargingRing.color(for: alert.level))
            }
        }
    }

    private func direction(of alert: BatteryAlert) -> Binding<BatteryAlert.Direction> {
        Binding(
            get: { alert.direction },
            set: { direction in
                alerts = alerts.map { $0.id == alert.id ? BatteryAlert(id: $0.id, level: $0.level, direction: direction) : $0 }
            }
        )
    }
}

/// The 0–100 % bar, colored like the battery (red, orange, green), with a pin per
/// alert. A click on the bar reports the level under the pointer; a pin can be
/// dragged along it to a new level.
struct BatteryAlertBar: View {
    let alerts: [BatteryAlert]
    let add: (Int) -> Void
    let move: (BatteryAlert.ID, Int) -> Void

    /// The pin being dragged and the level it's over; saved when it's let go.
    @State private var dragging: (id: BatteryAlert.ID, level: Int)?

    private let barHeight: CGFloat = 10
    private let pinArea: CGFloat = 30

    var body: some View {
        // Percent runs left to right in every language.
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(LinearGradient(stops: [
                        .init(color: ChargingRing.color(for: 0), location: 0),
                        .init(color: ChargingRing.color(for: 0), location: 0.17),
                        .init(color: ChargingRing.color(for: 50), location: 0.23),
                        .init(color: ChargingRing.color(for: 50), location: 0.77),
                        .init(color: ChargingRing.color(for: 100), location: 0.83),
                        .init(color: ChargingRing.color(for: 100), location: 1),
                    ], startPoint: .leading, endPoint: .trailing))
                    .opacity(0.85)
                    .frame(width: width, height: barHeight)
                    .offset(y: pinArea)
                ForEach(alerts) { alert in
                    let level = dragging?.id == alert.id ? dragging!.level : alert.level
                    pin(BatteryAlert(id: alert.id, level: level, direction: alert.direction))
                        .scaleEffect(dragging?.id == alert.id ? 1.2 : 1)
                        .position(x: width * CGFloat(level) / 100, y: pinArea / 2)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .named("bar"))
                                .onChanged { drag in
                                    let level = BatteryAlerts.level(atFraction: Double(drag.location.x / max(width, 1)))
                                    dragging = (alert.id, level)
                                }
                                .onEnded { _ in
                                    if let dragging { move(dragging.id, dragging.level) }
                                    dragging = nil
                                }
                        )
                        .onHover { inside in
                            if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
                        }
                }
                ForEach([0, 25, 50, 75, 100], id: \.self) { level in
                    Text((Double(level) / 100).formatted(.percent.locale(Localization.locale)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: min(max(width * CGFloat(level) / 100, 12), width - 12),
                                  y: pinArea + barHeight + 12)
                }
            }
            .coordinateSpace(.named("bar"))
            .contentShape(Rectangle())
            .onTapGesture { location in
                add(BatteryAlerts.level(atFraction: Double(location.x / max(width, 1))))
            }
        }
        .frame(height: pinArea + barHeight + 22)
        .environment(\.layoutDirection, .leftToRight)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Battery alerts"))
    }

    private func pin(_ alert: BatteryAlert) -> some View {
        VStack(spacing: 1) {
            Text(verbatim: "\(alert.level)")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
            Image(systemName: alert.direction.pinSymbol)
                .font(.system(size: 8))
        }
        .foregroundStyle(ChargingRing.color(for: alert.level))
        // A bigger target than the little pin itself, so it's easy to grab.
        .frame(width: 30, height: pinArea)
        .contentShape(Rectangle())
    }
}

extension BatteryAlert.Direction {
    var symbol: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .both: "arrow.up.arrow.down"
        }
    }

    var pinSymbol: String {
        switch self {
        case .up: "arrowtriangle.up.fill"
        case .down: "arrowtriangle.down.fill"
        case .both: "arrow.up.arrow.down"
        }
    }

    /// For the one-line summary in the Island pane.
    var arrow: String {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .both: "↕"
        }
    }
}
