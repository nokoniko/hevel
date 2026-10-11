import AppKit

// Playback controls (play/pause, next, previous) — currently unused: the island has
// no controls, so nothing calls them. Kept here out of the build (`#if false`) in
// case they come back. Re-enabling needs some `private` members opened up again
// (`NowPlayingModel.currentSource`/`lastUpdate`, `MediaFallback.sources`/`browsers`/
// `isRunning`, `SystemNowPlaying.runPythonOnce`/`pyString`) and `mr_command` restored
// in Helpers/mrhelper.c (below). NSAppleScript isn't thread-safe: if re-enabled, every
// AppleScript call here must run on `NowPlayingModel.fallbackQueue`, like the
// now-playing queries, never on the main thread.

#if false

extension NowPlayingModel {
    // MARK: Controls

    func togglePlayPause() {
        control(appleScript: "playpause", mediaKey: .playPause)
        isPlaying.toggle()          // optimistic; the stream corrects it within ~1s
        lastUpdate = Date()
    }

    func next() {
        control(appleScript: "next track", mediaKey: .next)
    }

    func previous() {
        control(appleScript: "previous track", mediaKey: .previous)
    }

    /// Route a control to whatever is *actually* playing. When the track comes
    /// from the system now-playing helper (the usual case — covers browsers, all
    /// apps), send a MediaRemote command, which targets the real now-playing app.
    /// Otherwise fall back to Spotify/Music AppleScript or the system media key.
    private func control(appleScript command: String, mediaKey: MediaKey) {
        if currentSource == "system", SystemNowPlaying.isAvailable {
            let cmd = command == "playpause" ? 2 : (command == "next track" ? 4 : 5)
            DispatchQueue.global(qos: .userInitiated).async { SystemNowPlaying.sendCommand(cmd) }
        } else if let source = currentSource, MediaFallback.isBrowser(source) {
            let browserCmd: MediaFallback.BrowserCommand =
                command == "playpause" ? .playPause : (command == "next track" ? .next : .previous)
            MediaFallback.browserCommand(browserCmd, in: source, chromium: MediaFallback.isChromium(source))
        } else if let app = MediaFallback.activeApp() {
            MediaFallback.send(command, to: app)
        } else {
            MediaKeys.post(mediaKey)
        }
        // The stream corrects the real state within ~1s; the optimistic toggle in
        // togglePlayPause() gives instant feedback in the meantime.
    }
}

extension MediaFallback {
    /// The player app that currently has a track loaded (playing or paused).
    static func activeApp() -> String? {
        for s in sources where isRunning(s.bundle) {
            let src = """
            tell application "\(s.app)"
                if it is running then return player state as text
                return "stopped"
            end tell
            """
            guard let script = NSAppleScript(source: src) else { continue }
            var error: NSDictionary?
            let state = script.executeAndReturnError(&error).stringValue ?? ""
            if error == nil, state != "stopped", !state.isEmpty { return s.app }
        }
        return nil
    }

    /// Send a transport command (e.g. "playpause", "next track", "previous track")
    /// to the given app. Returns true on success.
    @discardableResult
    static func send(_ command: String, to app: String) -> Bool {
        let src = "tell application \"\(app)\" to \(command)"
        guard let script = NSAppleScript(source: src) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    /// Toggle play/pause (or next/prev) in a browser's active tab via JavaScript.
    @discardableResult
    static func browserCommand(_ command: BrowserCommand, in name: String, chromium: Bool) -> Bool {
        let js: String
        switch command {
        case .playPause:
            js = "var v=document.querySelector('video,audio');if(v){v.paused?v.play():v.pause();}"
        case .next:
            js = "var b=document.querySelector('.ytp-next-button,[aria-label*=Next],[title*=Next]');if(b)b.click();"
        case .previous:
            js = "var b=document.querySelector('.ytp-prev-button,[aria-label*=Previous],[title*=Previous]');if(b)b.click();"
        }
        let escaped = js.replacingOccurrences(of: "\"", with: "\\\"")
        let source = chromium
            ? "tell application \"\(name)\" to execute front window's active tab javascript \"\(escaped)\""
            : "tell application \"\(name)\" to do JavaScript \"\(escaped)\" in current tab of front window"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    enum BrowserCommand { case playPause, next, previous }

    static func isBrowser(_ app: String) -> Bool { browsers.contains { $0.name == app } }
    static func isChromium(_ app: String) -> Bool { browsers.first { $0.name == app }?.chromium ?? true }
}

extension SystemNowPlaying {
    /// Send a MediaRemote transport command (0 play, 1 pause, 2 toggle, 4 next, 5 prev).
    static func sendCommand(_ command: Int) {
        guard let dylib = dylibPath else { return }
        _ = runPythonOnce("import ctypes; ctypes.CDLL(\(pyString(dylib))).mr_command(\(command))")
    }
}

/// Sends system media keys (play/pause, next, previous) the same way the
/// physical keys on the keyboard do. Works system-wide against whatever app is
/// currently playing audio, and needs no special entitlements.
enum MediaKey: Int32 {
    case playPause = 16   // NX_KEYTYPE_PLAY
    case next      = 17   // NX_KEYTYPE_NEXT
    case previous  = 18   // NX_KEYTYPE_PREVIOUS
}

enum MediaKeys {
    static func post(_ key: MediaKey) {
        press(key, down: true)
        press(key, down: false)
    }

    private static func press(_ key: MediaKey, down: Bool) {
        let flags: NSEvent.ModifierFlags = down ? NSEvent.ModifierFlags(rawValue: 0xA00)
                                                 : NSEvent.ModifierFlags(rawValue: 0xB00)
        let data1 = (Int(key.rawValue) << 16) | (down ? 0xA00 : 0xB00)

        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }

        event.cgEvent?.post(tap: .cghidEventTap)
    }
}

#endif

// Helpers/mrhelper.c, removed along with the above:
//
// typedef Boolean (*SendCmd)(int, CFDictionaryRef);
// // --- Transport command: 0 play,1 pause,2 toggle,4 next,5 previous. ---
// void mr_command(int cmd){
//     void* h=mrHandle(); if(!h) return;
//     SendCmd s=(SendCmd)dlsym(h,"MRMediaRemoteSendCommand");
//     if(s) s(cmd,NULL);
//     CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.5,false);
// }
