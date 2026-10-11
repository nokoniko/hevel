import SwiftUI

/// Non-interactive island shown on the lock screen: a black pill with a lock icon
/// peeking to the left of the notch (right in Hebrew). Each time the screen locks it
/// grows out from behind the notch, like the other pop-outs. Lives in its own panel
/// (see `NotchController.buildLockWindow`).
struct LockIslandView: View {
    @ObservedObject var state: IslandState
    @AppStorage(Preferences.appLanguageKey) private var language = AppLanguage.system
    @State private var revealed = false

    private var metrics: NotchMetrics { state.metrics }

    private var shape: NotchShape {
        NotchShape(topRadius: 0, bottomRadius: metrics.collapsedCornerRadius)
    }

    var body: some View {
        shape
            .fill(Color.black)
            .frame(width: revealed ? metrics.collapsedWidth : metrics.notchWidth, height: metrics.restHeight)
            .overlay(alignment: .top) {
                HStack(spacing: 0) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: metrics.symbolSize(12), weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: metrics.collapsedSidePadding, alignment: .center)
                    Spacer(minLength: metrics.notchWidth)
                    Color.clear.frame(width: metrics.collapsedSidePadding)
                }
                .frame(width: metrics.collapsedWidth, height: metrics.restHeight)
            }
            .clipShape(shape)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear { reveal(state.locked) }
            .onChange(of: state.locked) { reveal(state.locked) }
            .environment(\.layoutDirection, Localization.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    /// Start at the notch's width, then spring out — the icon is clipped by the pill,
    /// so it slides out from behind the notch.
    private func reveal(_ locked: Bool) {
        revealed = false
        guard locked else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { revealed = true }
        }
    }
}
