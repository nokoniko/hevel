import SwiftUI
import ImageIO

/// What the preview at the top of the Island pane shows.
enum IslandPreviewState: String, CaseIterable, Identifiable {
    case lockScreen, idle, charging, battery, track

    var id: Self { self }

    var title: String {
        switch self {
        case .lockScreen: tr("Lock Screen")
        case .idle: tr("Idle")
        case .charging: tr("Charging")
        case .battery: tr("Battery")
        case .track: tr("Track")
        }
    }
}

/// The top of the Mac's screen in miniature — your wallpaper, a menu bar and the
/// island in the chosen state — with the Island size slider under it. The island is
/// the real `IslandView` on its own model and state, so it looks exactly like the
/// one around the notch, and it follows the slider as you drag.
struct IslandPreviewSection: View {
    @AppStorage(Preferences.islandScaleKey) private var scale = 1.0

    @State private var showing = IslandPreviewState.track
    @State private var wallpaper: NSImage?
    @StateObject private var model = NowPlayingModel()
    @StateObject private var state = IslandState(metrics: NotchController.currentMetrics())

    /// The preview draws the screen at this fraction of its real size.
    private let zoom: CGFloat = 0.72

    var body: some View {
        VStack(spacing: 14) {
            screen
            Picker(selection: $showing) {
                ForEach(IslandPreviewState.allCases) { Text($0.title).tag($0) }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack(spacing: 12) {
                Image(systemName: "capsule.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .help(tr("Smaller"))
                Slider(value: $scale, in: Double(NotchMetrics.scaleRange.lowerBound)...Double(NotchMetrics.scaleRange.upperBound))
                    .labelsHidden()
                    .accessibilityLabel(tr("Island size"))
                Image(systemName: "capsule.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .help(tr("Larger"))
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 6)
        .task { wallpaper = await Self.loadWallpaper() }
        .onChange(of: showing, initial: true) { show(showing) }
        .onChange(of: scale) { state.metrics.scale = CGFloat(scale) }
        .task(id: showing) {
            switch showing {
            case .track:
                // A new track every few seconds, so the cover flip shows.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled { model.stepPreview(forward: true) }
                }
            case .battery:
                await cycleBatteryAlerts()
            default:
                break
            }
        }
        .onDisappear { model.stopPreview() }
    }

    private func show(_ preview: IslandPreviewState) {
        model.stopPreview()
        state.chargingFlourish = nil
        state.batteryAlert = nil
        state.locked = preview == .lockScreen
        state.metrics.scale = CGFloat(scale)
        switch preview {
        case .lockScreen, .idle: break
        case .charging: state.chargingFlourish = PowerMonitor.currentLevel() ?? 80
        case .battery: break   // cycleBatteryAlerts takes it from here
        case .track: model.startPreview()
        }
    }

    /// Shows the alerts set up under Battery alerts one after another, each growing
    /// out of the notch for a few seconds — re-read every round, so edits show up.
    private func cycleBatteryAlerts() async {
        while !Task.isCancelled {
            for alert in BatteryAlerts.previewSequence(Preferences.batteryAlerts) {
                state.batteryAlert = alert
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                state.batteryAlert = nil
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled else { return }
            }
        }
    }

    // MARK: The screen

    private var screen: some View {
        let height = state.metrics.maxWindowSize.height * zoom
        return ZStack(alignment: .top) {
            background
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
                .blur(radius: showing == .lockScreen ? 10 : 0)
                .clipped()
            if showing == .lockScreen {
                lockClock
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            } else {
                menuBar
                    .transition(.opacity)
            }
            ZStack(alignment: .top) {
                // The notch itself never fades — only what's around it does.
                NotchShape(topRadius: 0, bottomRadius: state.metrics.collapsedCornerRadius)
                    .fill(Color.black)
                    .frame(width: state.metrics.notchWidth, height: state.metrics.restHeight)
                if showing == .lockScreen {
                    LockIslandView(state: state)
                        .transition(.opacity)
                } else {
                    IslandView(model: model, state: state)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: state.metrics.maxWindowSize.height)
            .scaleEffect(zoom, anchor: .top)
            .frame(height: height, alignment: .top)
            .allowsHitTesting(false)
        }
        .frame(height: height)
        // Smooth into and out of the lock screen: blur, clock and menu bar fade.
        .animation(.easeInOut(duration: 0.45), value: showing)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous))
        // The MacBook's bezel around the top of the screen.
        .padding([.top, .horizontal], 7)
        .background(Color.black, in: UnevenRoundedRectangle(topLeadingRadius: 19, topTrailingRadius: 19, style: .continuous))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var background: some View {
        if let wallpaper {
            Image(nsImage: wallpaper)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(colors: [Color(red: 0.36, green: 0.22, blue: 0.62), Color(red: 0.13, green: 0.2, blue: 0.42)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var menuBar: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 14 * zoom) {
                Image(systemName: "apple.logo")
                Text(verbatim: "Finder").fontWeight(.bold)
                Text(tr("File"))
                Text(tr("Edit"))
                Text(tr("View"))
                Spacer(minLength: 0)
                Image(systemName: "capsule.fill")
                Text(context.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()
                    .locale(Localization.locale)))
                Text(context.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Localization.locale)))
            }
            .font(.system(size: 13 * zoom, weight: .medium))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
            .lineLimit(1)
            .padding(.horizontal, 12 * zoom)
            .frame(height: state.metrics.notchHeight * zoom)
        }
    }

    private var lockClock: some View {
        TimelineView(.everyMinute) { context in
            Text(context.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Localization.locale)))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, state.metrics.notchHeight * zoom + 18)
        }
    }

    /// The current desktop picture, downscaled so a 6K wallpaper doesn't cost much
    /// memory. `nil` for dynamic/aerial wallpapers that aren't a plain image.
    private static func loadWallpaper() async -> NSImage? {
        guard let screen = NotchController.targetScreen() ?? NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen)
        else { return nil }
        return await Task.detached(priority: .utility) { thumbnail(of: url, maxPixels: 1200) }.value
    }

    nonisolated private static func thumbnail(of url: URL, maxPixels: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
