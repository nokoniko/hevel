import AppKit

/// The now-playing helper runs inside `/usr/bin/python3`, which is only a stub
/// until Apple's Command Line Tools are installed: running the stub fails and pops
/// up macOS's own install dialog, every time. So check first (without running it),
/// fall back to AppleScript, and ask in our own words instead.
@MainActor
enum DeveloperTools {
    private static let suppressKey = "developerToolsPromptSuppressed"
    private static var watchTimer: Timer?

    /// True when `/usr/bin/python3` will actually run. `xcode-select -p` only
    /// reports the selected tools folder (it never prompts); the folder still has to
    /// hold a real python3.
    nonisolated static var isInstalled: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty
        else { return false }
        return FileManager.default.isExecutableFile(atPath: path + "/usr/bin/python3")
    }

    /// Asks once per launch (unless the user ticked "Don't ask again") and, on yes,
    /// opens Apple's installer. `onInstalled` runs once the tools show up.
    static func offerInstall(onInstalled: @escaping () -> Void) {
        guard !UserDefaults.standard.bool(forKey: suppressKey) else { return }
        let alert = NSAlert()
        alert.messageText = tr("Install the Command Line Tools?")
        alert.informativeText = tr("Hevel needs Apple's Command Line Tools to show what's playing in every app, browsers included. Until then, only Spotify and Music are shown. The download is free and comes from Apple.")
        alert.addButton(withTitle: tr("Install"))
        alert.addButton(withTitle: tr("Later"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = tr("Don't ask again")
        NSApp.activate()
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: suppressKey)
        }
        guard response == .alertFirstButtonReturn else { return }

        let install = Process()
        install.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        install.arguments = ["--install"]
        install.standardOutput = FileHandle.nullDevice
        install.standardError = FileHandle.nullDevice
        try? install.run()
        watch(onInstalled: onInstalled)
    }

    /// The installer takes a few minutes; look every 10 s, for up to an hour.
    private static func watch(onInstalled: @escaping () -> Void) {
        watchTimer?.invalidate()
        let deadline = Date().addingTimeInterval(3600)
        watchTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
            DispatchQueue.global(qos: .utility).async {
                let installed = isInstalled
                DispatchQueue.main.async {
                    guard timer.isValid else { return }
                    if installed {
                        timer.invalidate()
                        onInstalled()
                    } else if Date() > deadline {
                        timer.invalidate()
                    }
                }
            }
        }
    }
}
