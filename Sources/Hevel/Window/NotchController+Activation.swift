import AppKit

extension NotchController {

    func setupActivation() {
        state.onTapIsland = { [weak self] in self?.activatePlayingApp() }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }

        // Re-evaluate when what's playing changes.
        model.$playingPID.removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }
            .store(in: &cancellables)
        model.$isPlaying.removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }
            .store(in: &cancellables)
        model.$hasMedia.removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }
            .store(in: &cancellables)

        // Apply the "hide while the playing app is in front" setting as soon as it changes.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }

        updateSuppressed()
    }

    private func updateSuppressed() {
        state.suppressedForFrontmost = Preferences.hideWhilePlayerInFront && isPlayerFrontmost()
        updateForPointer()
    }

    /// True when the app that owns the current track is already the frontmost app —
    /// then there's no point showing the island (including during the pause linger).
    private func isPlayerFrontmost() -> Bool {
        Self.isPlayerFrontmost(
            hasMedia: model.hasMedia,
            playingPID: model.playingPID,
            frontmost: {
                NSWorkspace.shared.frontmostApplication.map {
                    (pid: Int($0.processIdentifier), bundleID: $0.bundleIdentifier)
                }
            },
            bundleID: { NSRunningApplication(processIdentifier: pid_t($0))?.bundleIdentifier }
        )
    }

    /// The system lookups are closures so they only run when needed, as before.
    nonisolated static func isPlayerFrontmost(hasMedia: Bool, playingPID: Int?,
                                              frontmost: () -> (pid: Int, bundleID: String?)?,
                                              bundleID: (Int) -> String?) -> Bool {
        guard hasMedia, let pid = playingPID, let front = frontmost() else { return false }
        if front.pid == pid { return true }
        // Browsers register now-playing from a helper process — match the app family.
        if let pb = bundleID(pid), let fb = front.bundleID {
            return pb == fb || pb.hasPrefix(fb) || fb.hasPrefix(pb)
        }
        return false
    }

    /// Brings the app that's playing to the front. A browser plays from a helper
    /// process, so that's traced back to the browser itself first. It goes through
    /// `openApplication` — like clicking the app in the Dock — because macOS 14+
    /// ignores `activate()` from an app that isn't active itself, and clicking the
    /// island doesn't make Hevel active.
    private func activatePlayingApp() {
        guard let pid = model.playingPID, let app = Self.owningApp(ofPID: pid_t(pid)) else { return }
        guard let url = app.bundleURL else {
            app.activate(options: [.activateAllWindows])
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    /// The regular app behind `pid`: itself, the app macOS holds responsible for it,
    /// or the running app whose bundle ID it extends (com.google.Chrome.helper →
    /// com.google.Chrome).
    static func owningApp(ofPID pid: pid_t) -> NSRunningApplication? {
        let app = NSRunningApplication(processIdentifier: pid)
        if let app, app.activationPolicy == .regular { return app }
        if let responsible = responsiblePID(for: pid), responsible != pid,
           let owner = NSRunningApplication(processIdentifier: responsible), owner.activationPolicy == .regular {
            return owner
        }
        let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        guard let helperID = app?.bundleIdentifier,
              let index = familyApp(of: helperID, among: regular.map(\.bundleIdentifier)) else { return app }
        return regular[index]
    }

    /// The candidate whose bundle ID is the longest prefix of the helper's, if any.
    nonisolated static func familyApp(of helperID: String, among candidates: [String?]) -> Int? {
        candidates.indices
            .filter { i in candidates[i].map { helperID.hasPrefix($0 + ".") } ?? false }
            .max { (candidates[$0]?.count ?? 0) < (candidates[$1]?.count ?? 0) }
    }

    /// The process macOS holds responsible for `pid` (e.g. Safari for its WebKit
    /// helpers), via libSystem's `responsibility_get_pid_responsible_for_pid`.
    private static func responsiblePID(for pid: pid_t) -> pid_t? {
        typealias Responsible = @convention(c) (pid_t) -> pid_t
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid")
        else { return nil }
        let responsible = unsafeBitCast(symbol, to: Responsible.self)(pid)
        return responsible > 0 ? responsible : nil
    }
}
