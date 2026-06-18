//  🖥️ TUIKit — Terminal UI Kit for Swift
//  RenderPerformanceMonitorTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation
import Testing

@testable import TUIkit

@MainActor
@Suite("Render Performance Monitor Tests")
struct RenderPerformanceMonitorTests {

    @Test("Monitor reports rolling FPS")
    func monitorReportsRollingFPS() {
        let monitor = RenderPerformanceMonitor(windowSeconds: 1)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = monitor.recordFrame(now: start)
        let snapshot = monitor.recordFrame(now: start.addingTimeInterval(0.5))

        #expect(snapshot.frameCount == 2)
        #expect(snapshot.framesPerSecond == 2)
        #expect(snapshot.formattedFPS == "2.0 FPS")
    }

    @Test("Monitor resets snapshot")
    func monitorResetsSnapshot() {
        let monitor = RenderPerformanceMonitor(windowSeconds: 1)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        monitor.recordFrame(now: start)
        monitor.recordFrame(now: start.addingTimeInterval(0.5))
        monitor.reset()

        #expect(monitor.snapshot == TUIRenderPerformance(frameCount: 0, windowSeconds: 1))
    }

    @Test("TUIContext reset clears render performance")
    func contextResetClearsRenderPerformance() {
        let context = TUIContext()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        context.renderPerformanceMonitor.recordFrame(now: start)
        context.renderPerformanceMonitor.recordFrame(now: start.addingTimeInterval(0.5))
        context.reset()

        #expect(context.renderPerformanceMonitor.snapshot.frameCount == 0)
    }
}
