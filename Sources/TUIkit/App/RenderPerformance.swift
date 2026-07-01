//  🖥️ TUIKit — Terminal UI Kit for Swift
//  RenderPerformance.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation

/// Snapshot of recent render-loop performance.
///
/// Values are measured from completed render-loop entries, not from terminal
/// refresh rate. The snapshot is intended for lightweight diagnostics in demo
/// and development UIs.
public struct TUIRenderPerformance: Equatable, Sendable {
    /// Rolling render rate over the recent sampling window.
    public let framesPerSecond: Double

    /// Total render calls recorded by this runtime context.
    public let frameCount: Int

    /// Length of the rolling sampling window in seconds.
    public let windowSeconds: Double

    /// Creates a render performance snapshot.
    public init(framesPerSecond: Double = 0, frameCount: Int = 0, windowSeconds: Double = 1) {
        self.framesPerSecond = framesPerSecond
        self.frameCount = frameCount
        self.windowSeconds = windowSeconds
    }

    /// FPS formatted for compact terminal diagnostics.
    public var formattedFPS: String {
        String(format: "%.1f FPS", framesPerSecond)
    }
}

/// Tracks render-loop cadence for one runtime context.
final class RenderPerformanceMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private let windowSeconds: TimeInterval
    private var timestamps: [Date] = []
    private var frameCount = 0
    private var latestSnapshot = TUIRenderPerformance()

    init(windowSeconds: TimeInterval = 1) {
        self.windowSeconds = windowSeconds
    }
}

// MARK: - Internal API

extension RenderPerformanceMonitor {
    var snapshot: TUIRenderPerformance {
        lock.lock()
        defer { lock.unlock() }
        return latestSnapshot
    }

    @discardableResult
    func recordFrame(now: Date = Date()) -> TUIRenderPerformance {
        lock.lock()
        defer { lock.unlock() }

        frameCount += 1
        timestamps.append(now)

        let cutoff = now.addingTimeInterval(-windowSeconds)
        timestamps.removeAll { $0 < cutoff }

        let fps: Double
        if let first = timestamps.first, let last = timestamps.last, timestamps.count > 1 {
            let span = max(last.timeIntervalSince(first), 0.001)
            fps = Double(timestamps.count - 1) / span
        } else {
            fps = 0
        }

        latestSnapshot = TUIRenderPerformance(
            framesPerSecond: fps,
            frameCount: frameCount,
            windowSeconds: windowSeconds
        )
        return latestSnapshot
    }

    func reset() {
        lock.lock()
        timestamps.removeAll(keepingCapacity: true)
        frameCount = 0
        latestSnapshot = TUIRenderPerformance(windowSeconds: windowSeconds)
        lock.unlock()
    }
}
