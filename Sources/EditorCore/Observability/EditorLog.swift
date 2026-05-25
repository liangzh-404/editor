import Foundation
import OSLog
#if os(iOS)
import UIKit
#endif

enum EditorLog {
    private static let subsystem = "com.liangzhang.editor"

    static let focus = Logger(subsystem: subsystem, category: "editor.focus")
    static let selection = Logger(subsystem: subsystem, category: "editor.selection")
    static let input = Logger(subsystem: subsystem, category: "editor.input")
    static let markdown = Logger(subsystem: subsystem, category: "editor.markdown")
    static let render = Logger(subsystem: subsystem, category: "editor.render")
    static let scroll = Logger(subsystem: subsystem, category: "editor.scroll")
    static let store = Logger(subsystem: subsystem, category: "store.transaction")
    static let sync = Logger(subsystem: subsystem, category: "sync.cloudkit")
    static let attachment = Logger(subsystem: subsystem, category: "attachment.preview")
    static let security = Logger(subsystem: subsystem, category: "security.encrypted-page")
    static let performance = Logger(subsystem: subsystem, category: "editor.performance")
}

struct EditorPerformanceTraceToken {
    fileprivate let eventName: String
    fileprivate let metadata: [String: String]
    fileprivate let startedAtNanoseconds: UInt64
}

enum EditorPerformanceTrace {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["EDITOR_PERFORMANCE_TRACE_ENABLED"] == "1"
            || UserDefaults.standard.bool(forKey: "EditorPerformanceTraceEnabled")
    }

    static func point(
        _ eventName: String,
        metadata: () -> [String: String] = { [:] }
    ) {
        guard isEnabled else {
            return
        }

        let renderedMetadata = render(metadataWithDefaults(metadata()))
        EditorLog.performance.notice(
            "perf_point name=\(eventName, privacy: .public) \(renderedMetadata, privacy: .public)"
        )
        EditorPerformanceTraceFileSink.record(
            kind: "perf_point",
            name: eventName,
            renderedMetadata: renderedMetadata
        )
    }

    static func point(
        _ eventName: String,
        metadata: [String: String]
    ) {
        point(eventName) { metadata }
    }

    static func nextRunLoopPoint(
        _ eventName: String,
        metadata: () -> [String: String] = { [:] }
    ) {
        guard isEnabled else {
            return
        }

        let capturedMetadata = metadata()
        DispatchQueue.main.async {
            point(eventName, metadata: capturedMetadata)
        }
    }

    static func begin(
        _ eventName: String,
        metadata: () -> [String: String] = { [:] }
    ) -> EditorPerformanceTraceToken? {
        guard isEnabled else {
            return nil
        }

        let capturedMetadata = metadata()
        point("\(eventName)_start", metadata: capturedMetadata)
        return EditorPerformanceTraceToken(
            eventName: eventName,
            metadata: capturedMetadata,
            startedAtNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
    }

    static func end(
        _ token: EditorPerformanceTraceToken?,
        as eventName: String? = nil,
        metadata: () -> [String: String] = { [:] }
    ) {
        guard let token, isEnabled else {
            return
        }

        let endedAtNanoseconds = DispatchTime.now().uptimeNanoseconds
        let durationMilliseconds = Double(endedAtNanoseconds - token.startedAtNanoseconds) / 1_000_000
        var mergedMetadata = token.metadata
        for (key, value) in metadata() {
            mergedMetadata[key] = value
        }
        mergedMetadata["duration_ms"] = String(format: "%.3f", durationMilliseconds)

        let renderedMetadata = render(metadataWithDefaults(mergedMetadata))
        let resolvedEventName = eventName ?? "\(token.eventName)_done"
        EditorLog.performance.notice(
            "perf_interval name=\(resolvedEventName, privacy: .public) \(renderedMetadata, privacy: .public)"
        )
        EditorPerformanceTraceFileSink.record(
            kind: "perf_interval",
            name: resolvedEventName,
            renderedMetadata: renderedMetadata
        )
    }

    static func interval(
        _ eventName: String,
        durationMilliseconds: Double,
        metadata: [String: String]
    ) {
        guard isEnabled else {
            return
        }

        var mergedMetadata = metadata
        mergedMetadata["duration_ms"] = String(format: "%.3f", durationMilliseconds)
        let renderedMetadata = render(metadataWithDefaults(mergedMetadata))
        EditorLog.performance.notice(
            "perf_interval name=\(eventName, privacy: .public) \(renderedMetadata, privacy: .public)"
        )
        EditorPerformanceTraceFileSink.record(
            kind: "perf_interval",
            name: eventName,
            renderedMetadata: renderedMetadata
        )
    }

    private static func metadataWithDefaults(_ metadata: [String: String]) -> [String: String] {
        var defaults: [String: String] = [
            "platform": platformName
        ]
        let environment = ProcessInfo.processInfo.environment
        if let dataset = environment["EDITOR_PERFORMANCE_DATASET_LABEL"], !dataset.isEmpty {
            defaults["dataset"] = dataset
        }
        for (key, value) in metadata {
            defaults[key] = value
        }
        return defaults
    }

    private static var platformName: String {
#if os(iOS)
        "iOS"
#elseif os(macOS)
        "macOS"
#else
        "unknown"
#endif
    }

    private static func render(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty else {
            return "metadata=none"
        }

        return metadata
            .sorted { lhs, rhs in lhs.key < rhs.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
    }
}

private enum EditorPerformanceTraceFileSink {
    private static let queue = DispatchQueue(label: "com.liangzhang.editor.performance-trace-file")
    private static let timestampFormatterLock = NSLock()
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        return formatter
    }()

    static func record(kind: String, name: String, renderedMetadata: String) {
        guard let path = ProcessInfo.processInfo.environment["EDITOR_PERFORMANCE_TRACE_FILE"],
              !path.isEmpty else {
            return
        }

        let timestamp = formattedTimestamp()
        let line = "\(timestamp) EditorPerformanceTrace[0]: [com.liangzhang.editor:editor.performance] \(kind) name=\(name) \(renderedMetadata)\n"
        queue.async {
            let url = URL(fileURLWithPath: path)
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: url)
                defer {
                    try? handle.close()
                }
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } catch {
                EditorLog.performance.error(
                    "perf_trace_file_write_failed path=\(path, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private static func formattedTimestamp() -> String {
        timestampFormatterLock.lock()
        defer {
            timestampFormatterLock.unlock()
        }
        return timestampFormatter.string(from: Date())
    }
}

enum EditorFramePacingTrace {
    static func begin(
        _ eventName: String,
        metadata: [String: String]
    ) -> String? {
#if os(iOS) || os(macOS)
        guard EditorPerformanceTrace.isEnabled else {
            return nil
        }

        let token = UUID().uuidString
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                EditorFramePacingMonitor.shared.begin(token: token, eventName: eventName, metadata: metadata)
            }
        } else {
            Task { @MainActor in
                EditorFramePacingMonitor.shared.begin(token: token, eventName: eventName, metadata: metadata)
            }
        }
        return token
#else
        return nil
#endif
    }

    static func end(
        _ token: String?,
        metadata: [String: String] = [:]
    ) {
#if os(iOS) || os(macOS)
        guard let token, EditorPerformanceTrace.isEnabled else {
            return
        }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                EditorFramePacingMonitor.shared.end(token: token, metadata: metadata)
            }
        } else {
            Task { @MainActor in
                EditorFramePacingMonitor.shared.end(token: token, metadata: metadata)
            }
        }
#endif
    }

    static func cancel(_ token: String?) {
#if os(iOS) || os(macOS)
        guard let token, EditorPerformanceTrace.isEnabled else {
            return
        }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                EditorFramePacingMonitor.shared.cancel(token: token)
            }
        } else {
            Task { @MainActor in
                EditorFramePacingMonitor.shared.cancel(token: token)
            }
        }
#endif
    }
}

#if os(iOS) || os(macOS)
private struct EditorFramePacingSession {
    let eventName: String
    var metadata: [String: String]
    let startedAtNanoseconds: UInt64
    let refreshRate: Int
    let frameBudgetMilliseconds: Double
    var lastTimestamp: TimeInterval?
    var frameSampleCount = 0
    var maxFrameMilliseconds = 0.0
    var slowFrameCount = 0
    var droppedFrameEstimate = 0
    var frameDurationsMilliseconds: [Double] = []

    mutating func applyUnsampledDurationFallback(_ durationMilliseconds: Double) {
        guard frameSampleCount == 0,
              frameBudgetMilliseconds > 0,
              durationMilliseconds > frameBudgetMilliseconds else {
            return
        }

        frameSampleCount = 1
        maxFrameMilliseconds = durationMilliseconds
        slowFrameCount = 1
        frameDurationsMilliseconds = [durationMilliseconds]
        let estimatedFrameCount = Int((durationMilliseconds / frameBudgetMilliseconds).rounded(.down))
        droppedFrameEstimate = max(0, estimatedFrameCount - 1)
    }

    func percentileFrameMilliseconds(_ percentile: Double) -> Double {
        guard !frameDurationsMilliseconds.isEmpty else {
            return 0
        }
        let sortedDurations = frameDurationsMilliseconds.sorted()
        let clampedPercentile = min(max(percentile, 0), 100)
        let rank = (clampedPercentile / 100) * Double(sortedDurations.count - 1)
        return sortedDurations[Int(rank.rounded(.up))]
    }
}
#endif

#if os(iOS)
@MainActor
private final class EditorFramePacingMonitor: NSObject {
    static let shared = EditorFramePacingMonitor()

    private var displayLink: CADisplayLink?
    private var sessions: [String: EditorFramePacingSession] = [:]

    func begin(token: String, eventName: String, metadata: [String: String]) {
        guard sessions[token] == nil else {
            return
        }

        let refreshRate = UIScreen.main.maximumFramesPerSecond
        let frameBudgetMilliseconds = refreshRate > 0 ? 1_000 / Double(refreshRate) : 16.667
        sessions[token] = EditorFramePacingSession(
            eventName: eventName,
            metadata: metadata,
            startedAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
            refreshRate: refreshRate,
            frameBudgetMilliseconds: frameBudgetMilliseconds
        )
        startDisplayLinkIfNeeded()
    }

    func end(token: String, metadata: [String: String]) {
        guard var session = sessions.removeValue(forKey: token) else {
            stopDisplayLinkIfIdle()
            return
        }

        stopDisplayLinkIfIdle()

        for (key, value) in metadata {
            session.metadata[key] = value
        }
        let endedAtNanoseconds = DispatchTime.now().uptimeNanoseconds
        let durationMilliseconds = Double(endedAtNanoseconds - session.startedAtNanoseconds) / 1_000_000
        session.applyUnsampledDurationFallback(durationMilliseconds)
        session.metadata["refresh_rate_hz"] = "\(session.refreshRate)"
        session.metadata["frame_budget_ms"] = String(format: "%.3f", session.frameBudgetMilliseconds)
        session.metadata["frame_sample_count"] = "\(session.frameSampleCount)"
        session.metadata["p50_frame_ms"] = String(format: "%.3f", session.percentileFrameMilliseconds(50))
        session.metadata["p95_frame_ms"] = String(format: "%.3f", session.percentileFrameMilliseconds(95))
        session.metadata["p99_frame_ms"] = String(format: "%.3f", session.percentileFrameMilliseconds(99))
        session.metadata["max_frame_ms"] = String(format: "%.3f", session.maxFrameMilliseconds)
        session.metadata["slow_frame_count"] = "\(session.slowFrameCount)"
        session.metadata["dropped_frame_estimate"] = "\(session.droppedFrameEstimate)"

        EditorPerformanceTrace.interval(
            "\(session.eventName)_frame_pacing_done",
            durationMilliseconds: durationMilliseconds,
            metadata: session.metadata
        )
    }

    func cancel(token: String) {
        sessions.removeValue(forKey: token)
        stopDisplayLinkIfIdle()
    }

    @objc private func displayLinkDidTick(_ displayLink: CADisplayLink) {
        guard !sessions.isEmpty else {
            stopDisplayLinkIfIdle()
            return
        }

        for token in sessions.keys {
            guard var session = sessions[token] else {
                continue
            }
            if let lastTimestamp = session.lastTimestamp {
                let frameMilliseconds = (displayLink.timestamp - lastTimestamp) * 1_000
                session.frameSampleCount += 1
                session.frameDurationsMilliseconds.append(frameMilliseconds)
                session.maxFrameMilliseconds = max(session.maxFrameMilliseconds, frameMilliseconds)
                let slowThresholdMilliseconds = session.frameBudgetMilliseconds * 1.25
                if frameMilliseconds > slowThresholdMilliseconds {
                    session.slowFrameCount += 1
                }
                if session.frameBudgetMilliseconds > 0 {
                    let estimatedFrameCount = Int((frameMilliseconds / session.frameBudgetMilliseconds).rounded(.down))
                    session.droppedFrameEstimate += max(0, estimatedFrameCount - 1)
                }
            }
            session.lastTimestamp = displayLink.timestamp
            sessions[token] = session
        }
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else {
            return
        }

        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLinkIfIdle() {
        guard sessions.isEmpty else {
            return
        }

        displayLink?.invalidate()
        displayLink = nil
    }
}
#endif

#if os(macOS)
@MainActor
private final class EditorFramePacingMonitor: NSObject {
    static let shared = EditorFramePacingMonitor()

    private var timer: Timer?
    private var sessions: [String: EditorFramePacingSession] = [:]

    func begin(token: String, eventName: String, metadata: [String: String]) {
        guard sessions[token] == nil else {
            return
        }

        let refreshRate = 60
        let frameBudgetMilliseconds = 1_000 / Double(refreshRate)
        sessions[token] = EditorFramePacingSession(
            eventName: eventName,
            metadata: metadata,
            startedAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
            refreshRate: refreshRate,
            frameBudgetMilliseconds: frameBudgetMilliseconds
        )
        startTimerIfNeeded(frameBudgetMilliseconds: frameBudgetMilliseconds)
    }

    func end(token: String, metadata: [String: String]) {
        guard var session = sessions.removeValue(forKey: token) else {
            stopTimerIfIdle()
            return
        }

        stopTimerIfIdle()

        for (key, value) in metadata {
            session.metadata[key] = value
        }
        let endedAtNanoseconds = DispatchTime.now().uptimeNanoseconds
        let durationMilliseconds = Double(endedAtNanoseconds - session.startedAtNanoseconds) / 1_000_000
        session.applyUnsampledDurationFallback(durationMilliseconds)
        session.metadata["refresh_rate_hz"] = "\(session.refreshRate)"
        session.metadata["frame_budget_ms"] = String(format: "%.3f", session.frameBudgetMilliseconds)
        session.metadata["frame_sample_count"] = "\(session.frameSampleCount)"
        session.metadata["p50_frame_ms"] = String(format: "%.3f", session.percentileFrameMilliseconds(50))
        session.metadata["p95_frame_ms"] = String(format: "%.3f", session.percentileFrameMilliseconds(95))
        session.metadata["p99_frame_ms"] = String(format: "%.3f", session.percentileFrameMilliseconds(99))
        session.metadata["max_frame_ms"] = String(format: "%.3f", session.maxFrameMilliseconds)
        session.metadata["slow_frame_count"] = "\(session.slowFrameCount)"
        session.metadata["dropped_frame_estimate"] = "\(session.droppedFrameEstimate)"

        EditorPerformanceTrace.interval(
            "\(session.eventName)_frame_pacing_done",
            durationMilliseconds: durationMilliseconds,
            metadata: session.metadata
        )
    }

    func cancel(token: String) {
        sessions.removeValue(forKey: token)
        stopTimerIfIdle()
    }

    @objc private func timerDidTick(_ timer: Timer) {
        guard !sessions.isEmpty else {
            stopTimerIfIdle()
            return
        }

        let timestamp = ProcessInfo.processInfo.systemUptime
        for token in sessions.keys {
            guard var session = sessions[token] else {
                continue
            }
            if let lastTimestamp = session.lastTimestamp {
                let frameMilliseconds = (timestamp - lastTimestamp) * 1_000
                session.frameSampleCount += 1
                session.frameDurationsMilliseconds.append(frameMilliseconds)
                session.maxFrameMilliseconds = max(session.maxFrameMilliseconds, frameMilliseconds)
                let slowThresholdMilliseconds = session.frameBudgetMilliseconds * 1.25
                if frameMilliseconds > slowThresholdMilliseconds {
                    session.slowFrameCount += 1
                }
                if session.frameBudgetMilliseconds > 0 {
                    let estimatedFrameCount = Int((frameMilliseconds / session.frameBudgetMilliseconds).rounded(.down))
                    session.droppedFrameEstimate += max(0, estimatedFrameCount - 1)
                }
            }
            session.lastTimestamp = timestamp
            sessions[token] = session
        }
    }

    private func startTimerIfNeeded(frameBudgetMilliseconds: Double) {
        guard timer == nil else {
            return
        }

        let timer = Timer(
            timeInterval: frameBudgetMilliseconds / 1_000,
            target: self,
            selector: #selector(timerDidTick(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimerIfIdle() {
        guard sessions.isEmpty else {
            return
        }

        timer?.invalidate()
        timer = nil
    }
}
#endif
