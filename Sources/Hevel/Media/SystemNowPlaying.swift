import AppKit

/// Reads the system-wide "Now Playing" (the same source Control Center uses — it
/// covers **every** app, browsers included) through a tiny bundled helper.
///
/// Apple blocks the private MediaRemote framework for third-party-signed processes,
/// but not for Apple-signed ones. So the helper is a small dylib loaded inside
/// `/usr/bin/python3` (Apple-signed) via ctypes.
///
/// To stay light on RAM, metadata streams from a **single long-lived** helper
/// process (one JSON line/second — no per-second process spawning, no zombies).
/// Artwork is an occasional one-off call.
///
/// Main-actor bound: the pipe and termination handlers arrive on background threads
/// and hop to the main thread before touching any state. The static helpers are
/// `nonisolated` — artwork is fetched off-main and the parsers are plain functions.
@MainActor
final class SystemNowPlaying {
    static let shared = SystemNowPlaying()
    private init() {}

    /// Located once: the bundled `mrhelper.dylib`.
    nonisolated static let dylibPath: String? = {
        let fm = FileManager.default
        if let res = Bundle.main.resourcePath {
            let p = res + "/mrhelper.dylib"
            if fm.fileExists(atPath: p) { return p }
        }
        if let dir = Bundle.main.executableURL?.deletingLastPathComponent() {
            let p = dir.appendingPathComponent("mrhelper.dylib").path
            if fm.fileExists(atPath: p) { return p }
        }
        return nil
    }()

    /// The helper is bundled and `/usr/bin/python3` is more than a stub (see
    /// `DeveloperTools`). Runs `xcode-select`, so check it once, not per frame.
    nonisolated static var isAvailable: Bool { dylibPath != nil && DeveloperTools.isInstalled }

    private var streamProcess: Process?
    private var buffer = Data()
    private var lastLine = Data()
    private var lastDelivered = Date.distantPast

    /// A paused track repeats the same line every second; such repeats are skipped,
    /// but one still goes through this often, so the model re-checks Spotify/Music now
    /// and then even if MediaRemote misses a change.
    nonisolated static let repeatInterval: TimeInterval = 10
    private var onUpdate: ((NowPlayingInfo?) -> Void)?
    private var stopped = false
    /// Helper exits in a row without a line in between; sets the relaunch delay.
    private var failures = 0

    /// Start streaming now-playing metadata. `onUpdate` is called on the main thread
    /// with each snapshot, or nil when nothing is playing.
    func start(onUpdate: @escaping (NowPlayingInfo?) -> Void) {
        guard Self.dylibPath != nil else { return }
        self.onUpdate = onUpdate
        launch()
    }

    func stop() {
        stopped = true
        streamProcess?.terminate()
        streamProcess = nil
    }

    private func launch() {
        guard !stopped, let dylib = Self.dylibPath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", "import ctypes; ctypes.CDLL(\(Self.pyString(dylib))).mr_stream()"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        // Both handlers run on background threads: read there, then hop to the main
        // thread (DispatchQueue.main keeps the chunks in order, a Task wouldn't).
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in self?.consume(chunk) }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.helperEnded() }
        }
        do { try process.run() } catch { return }
        streamProcess = process
    }

    /// Respawn if the helper ever dies — waiting longer after each exit that came
    /// without a line in between, so a helper that can't start (no Command Line
    /// Tools, a dylib that won't load) isn't relaunched every second forever.
    private func helperEnded() {
        guard !stopped else { return }
        let delay = Self.relaunchDelay(afterFailures: failures)
        failures += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.launch() }
    }

    /// 1 s, doubling with each failure in a row, up to a minute.
    nonisolated static func relaunchDelay(afterFailures failures: Int) -> TimeInterval {
        min(pow(2, Double(min(failures, 6))), 60)
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[buffer.startIndex..<nl])
            buffer.removeSubrange(buffer.startIndex...nl)
            failures = 0   // the helper is working
            let now = Date()
            guard Self.shouldDeliver(line, previous: lastLine, lastDelivered: lastDelivered, now: now) else { continue }
            lastLine = line
            lastDelivered = now
            onUpdate?(Self.parse(line))
        }
        if buffer.count > 8192 { buffer.removeAll(keepingCapacity: true) } // safety
    }

    /// A new line, or the same one again once `repeatInterval` has passed.
    nonisolated static func shouldDeliver(_ line: Data, previous: Data, lastDelivered: Date, now: Date) -> Bool {
        line != previous || now.timeIntervalSince(lastDelivered) >= repeatInterval
    }

    // MARK: One-off calls

    /// Fetch just the current artwork. Call only when the track changes.
    nonisolated static func fetchArtwork() -> NSImage? {
        guard let dylib = dylibPath else { return nil }
        let code = "import ctypes; ctypes.CDLL(\(pyString(dylib))).mr_get_artwork()"
        guard let out = runPythonOnce(code)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !out.isEmpty, let data = Data(base64Encoded: out) else { return nil }
        return NSImage(data: data)
    }

    // MARK: Internals

    nonisolated private static func pyString(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    nonisolated private static func runPythonOnce(_ code: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", code]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    /// One JSON line from the stream helper, or nil if it's malformed or nothing is playing.
    nonisolated static func parse(line: String) -> NowPlayingInfo? {
        parse(Data(line.utf8))
    }

    nonisolated static func parse(_ data: Data) -> NowPlayingInfo? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = obj["title"] as? String, !title.isEmpty
        else { return nil }
        var info = NowPlayingInfo()
        info.title = title
        info.artist = (obj["artist"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        info.album = (obj["album"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        info.duration = obj["duration"] as? Double
        info.elapsed = obj["elapsed"] as? Double
        info.isPlaying = obj["isPlaying"] as? Bool
        if let pid = obj["pid"] as? Int, pid > 0 { info.pid = pid }
        info.sourceApp = "system"
        return info
    }
}
