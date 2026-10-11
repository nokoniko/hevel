import AppKit
import SwiftUI

/// Owns the single settings window and brings it to the front on request. While
/// it's open the app shows in the Dock and the app switcher like a regular app.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let updater: Updater
    private let developer: (DeveloperMode.Command) -> Void
    private var window: NSWindow?

    var isOpen: Bool { window?.isVisible == true }

    init(updater: Updater, developer: @escaping (DeveloperMode.Command) -> Void) {
        self.updater = updater
        self.developer = developer
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: makeContent())
            window.title = "Hevel"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            // The sidebar shows where you are, so no title in the window; it's still
            // there for the Window menu, Mission Control and VoiceOver.
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        guard let window else { return }
        if window.contentViewController == nil { window.contentViewController = makeContent() }
        let alreadyOpen = window.isVisible
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        // Opened from the menu bar another app is still active, and macOS may not
        // hand activation over — so put the window in front regardless.
        window.orderFrontRegardless()
        // Centered after it's laid out (toolbar included), still within this run-loop
        // turn, so it never visibly jumps.
        if !alreadyOpen { center(window) }
        // Becoming a regular app takes effect a moment later, and macOS won't make an
        // accessory app active — so activate again on the next turn. Without it the
        // window is in front but the first click only activates it.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func makeContent() -> NSViewController {
        let hosting = NSHostingController(rootView: SettingsView(updater: updater, developer: developer))
        // Let SwiftUI drive the toolbar (sidebar layout), like System Settings.
        hosting.sceneBridgingOptions = [.toolbars]
        return hosting
    }

    /// Dead center of the screen the pointer is on, i.e. where the user is looking.
    private func center(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return window.center() }
        // SwiftUI sizes the window lazily; settle it first or we'd center a 0×0 frame.
        window.layoutIfNeeded()
        window.displayIfNeeded()
        let area = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: (area.midX - size.width / 2).rounded(),
                                      y: (area.midY - size.height / 2).rounded()))
    }

    /// ⌘Q from the settings window quits the whole app — island included — so ask
    /// first. Without the window open it quits straight away.
    func confirmQuit(then quit: @escaping () -> Void) {
        guard let window, window.isVisible else { return quit() }
        let alert = NSAlert()
        alert.messageText = tr("Quit Hevel?")
        alert.informativeText = tr("The island disappears from the notch until you open the app again. To just close the settings, press ⌘W.")
        alert.addButton(withTitle: tr("Quit"))
        alert.addButton(withTitle: tr("Cancel"))
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { quit() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu-bar-only agent: no Dock icon.
        NSApp.setActivationPolicy(.accessory)
        // Drop the SwiftUI content — with its wallpaper thumbnail and island preview —
        // so a closed settings window costs next to nothing; it's rebuilt on the next
        // open. (The window itself stays: AppKit keeps closed windows around anyway.)
        DispatchQueue.main.async { [weak self] in self?.window?.contentViewController = nil }
    }
}
