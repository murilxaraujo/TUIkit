//  🖥️ TUIKit — Terminal UI Kit for Swift
//  LifecycleManagerTests.swift
//
//  Created by LAYERED.work
//  License: MIT  render pass management, and async task lifecycle.
//

#if canImport(Darwin)
    import Darwin
#endif
import Foundation
import Testing

@testable import TUIkit

// MARK: - Appear Tracking Tests

@MainActor
@Suite("LifecycleManager Appear Tests")
struct LifecycleManagerAppearTests {

    @Test("recordAppear returns true on first appearance")
    func firstAppearance() {
        let manager = LifecycleManager()
        nonisolated(unsafe) var actionCalled = false
        let result = manager.recordAppear(token: "view-1") {
            actionCalled = true
        }
        #expect(result == true)
        #expect(actionCalled == true)
    }

    @Test("recordAppear returns false on repeated appearance")
    func repeatedAppearance() {
        let manager = LifecycleManager()
        _ = manager.recordAppear(token: "view-1") {}
        nonisolated(unsafe) var secondCalled = false
        let result = manager.recordAppear(token: "view-1") {
            secondCalled = true
        }
        #expect(result == false)
        #expect(secondCalled == false)
    }

    @Test("hasAppeared returns false for unseen token")
    func hasNotAppeared() {
        let manager = LifecycleManager()
        #expect(manager.hasAppeared(token: "never-seen") == false)
    }

    @Test("hasAppeared returns true after recordAppear")
    func hasAppearedAfterRecord() {
        let manager = LifecycleManager()
        _ = manager.recordAppear(token: "view-1") {}
        #expect(manager.hasAppeared(token: "view-1") == true)
    }

    @Test("Multiple tokens are tracked independently")
    func independentTokens() {
        let manager = LifecycleManager()
        _ = manager.recordAppear(token: "a") {}
        _ = manager.recordAppear(token: "b") {}
        #expect(manager.hasAppeared(token: "a") == true)
        #expect(manager.hasAppeared(token: "b") == true)
        #expect(manager.hasAppeared(token: "c") == false)
    }

    @Test("reset clears all appeared tokens")
    func resetClears() {
        let manager = LifecycleManager()
        _ = manager.recordAppear(token: "view-1") {}
        _ = manager.recordAppear(token: "view-2") {}
        manager.reset()
        #expect(manager.hasAppeared(token: "view-1") == false)
        #expect(manager.hasAppeared(token: "view-2") == false)
    }
}

// MARK: - Render Pass Tests

@MainActor
@Suite("LifecycleManager Render Pass Tests")
struct LifecycleManagerRenderPassTests {

    @Test("beginRenderPass clears current render tokens")
    func beginRenderPassClears() {
        let manager = LifecycleManager()
        // Pass 1: view appears
        manager.beginRenderPass()
        _ = manager.recordAppear(token: "view-1") {}
        manager.endRenderPass() // sets visibleTokens = {"view-1"}

        // Pass 2: view does NOT appear
        manager.beginRenderPass() // clears currentRenderTokens
        manager.endRenderPass() // disappeared = {"view-1"}, removes from appearedTokens

        #expect(manager.hasAppeared(token: "view-1") == false)
    }

    @Test("endRenderPass triggers disappear for removed views")
    func disappearTriggered() {
        let manager = LifecycleManager()
        nonisolated(unsafe) var disappeared = false

        // Render pass 1: view appears
        manager.beginRenderPass()
        _ = manager.recordAppear(token: "view-1") {}
        manager.registerDisappear(token: "view-1") {
            disappeared = true
        }
        manager.endRenderPass()
        #expect(disappeared == false) // Still visible

        // Render pass 2: view is NOT rendered
        manager.beginRenderPass()
        // view-1 not recorded
        manager.endRenderPass()
        #expect(disappeared == true) // Now disappeared
    }

    @Test("endRenderPass does not trigger for views still visible")
    func noDisappearForVisible() {
        let manager = LifecycleManager()
        nonisolated(unsafe) var disappeared = false

        // Render pass 1
        manager.beginRenderPass()
        _ = manager.recordAppear(token: "view-1") {}
        manager.registerDisappear(token: "view-1") {
            disappeared = true
        }
        manager.endRenderPass()

        // Render pass 2: view still rendered
        manager.beginRenderPass()
        _ = manager.recordAppear(token: "view-1") {}
        manager.endRenderPass()
        #expect(disappeared == false) // Still visible, no disappear
    }

    @Test("View can reappear after disappearing")
    func reappearAfterDisappear() {
        let manager = LifecycleManager()
        nonisolated(unsafe) var appearCount = 0

        // Pass 1: appear
        manager.beginRenderPass()
        _ = manager.recordAppear(token: "view-1") { appearCount += 1 }
        manager.endRenderPass()
        #expect(appearCount == 1)

        // Pass 2: disappear (not rendered)
        manager.beginRenderPass()
        manager.endRenderPass()

        // Pass 3: reappear — action should fire again
        manager.beginRenderPass()
        _ = manager.recordAppear(token: "view-1") { appearCount += 1 }
        manager.endRenderPass()
        #expect(appearCount == 2)
    }
}

// MARK: - Disappear Callback Storage Tests

@MainActor
@Suite("LifecycleManager Disappear Callback Tests")
struct LifecycleManagerDisappearTests {

    @Test("registerDisappear stores callback")
    func registerStoresCallback() {
        let manager = LifecycleManager()
        nonisolated(unsafe) var called = false
        manager.registerDisappear(token: "view-1") {
            called = true
        }
        // Callback is stored but not called yet
        #expect(called == false)
    }

    @Test("unregisterDisappear removes callback")
    func unregisterRemoves() {
        let manager = LifecycleManager()
        nonisolated(unsafe) var called = false
        manager.registerDisappear(token: "view-1") {
            called = true
        }
        manager.unregisterDisappear(token: "view-1")

        // Simulate disappear — callback should NOT fire
        manager.beginRenderPass()
        _ = manager.recordAppear(token: "view-1") {}
        manager.endRenderPass()

        manager.beginRenderPass()
        // view-1 not rendered
        manager.endRenderPass()
        #expect(called == false) // Callback was unregistered
    }
}

// MARK: - Task Storage Tests

@MainActor
@Suite("LifecycleManager Task Tests")
struct LifecycleManagerTaskTests {

    @Test("startTask creates a task")
    func startTask() async throws {
        let manager = LifecycleManager()
        let probe = TaskExecutionProbe()
        manager.startTask(token: "task-1", priority: .medium) {
            probe.markExecuted()
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(probe.executed == true)
    }

    @Test("startTask runs detached from the main thread")
    func startTaskRunsDetachedFromMainThread() async throws {
        let manager = LifecycleManager()
        let probe = TaskExecutionProbe()

        manager.startTask(token: "task-1", priority: .medium) {
            probe.markThread(isMainThread: isCurrentThreadMain())
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(probe.executed == true)
        #expect(probe.ranOnMainThread == false)
    }

    @Test("cancelTask cancels without crashing")
    func cancelTask() async throws {
        let manager = LifecycleManager()
        manager.startTask(token: "task-1", priority: .medium) {
            try? await Task.sleep(for: .seconds(10))
        }
        // Cancel immediately. This verifies cancellation is requested and the
        // lifecycle manager remains usable.
        manager.cancelTask(token: "task-1")
        try await Task.sleep(for: .milliseconds(50))
        manager.startTask(token: "task-1", priority: .medium) {}
        manager.cancelTask(token: "task-1")
    }

    @Test("startTask replaces existing task for same token")
    func replaceTask() async throws {
        let manager = LifecycleManager()
        let probe = TaskExecutionProbe()

        manager.startTask(token: "task-1", priority: .medium) {
            // Long-running first task
            try? await Task.sleep(for: .seconds(10))
        }
        // Replace immediately with short task
        manager.startTask(token: "task-1", priority: .medium) {
            probe.markExecuted()
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(probe.executed == true)
    }

    @Test("reset does not crash with running tasks")
    func resetWithRunningTasks() async throws {
        let manager = LifecycleManager()
        manager.startTask(token: "task-1", priority: .medium) {
            try? await Task.sleep(for: .seconds(10))
        }
        manager.startTask(token: "task-2", priority: .medium) {
            try? await Task.sleep(for: .seconds(10))
        }
        // Reset should cancel all tasks without crashing
        manager.reset()
        // Verify clean state
        #expect(manager.hasAppeared(token: "task-1") == false)
    }

    @Test("rapid appear/disappear cancels each task before reappearance")
    func rapidAppearDisappearCancelsEachTaskBeforeReappearance() async throws {
        let manager = LifecycleManager()
        let probe = TaskLifecycleProbe()
        let token = "rapid-task-view"
        let cycles = 20

        for cycle in 0..<cycles {
            manager.beginRenderPass()
            let shouldStartTask = !manager.hasAppeared(token: token)
            _ = manager.recordAppear(token: token) {}
            if shouldStartTask {
                manager.startTask(token: token, priority: .medium) {
                    await probe.runTask(index: cycle)
                }
            }
            manager.registerDisappear(token: token) { [manager] in
                manager.cancelTask(token: token)
            }
            manager.endRenderPass()

            try await probe.waitForStartedCount(cycle + 1)

            manager.beginRenderPass()
            manager.endRenderPass()

            try await probe.waitForCancelledCount(cycle + 1)
            #expect(manager.hasAppeared(token: token) == false)
        }

        #expect(probe.startedCount == cycles)
        #expect(probe.cancelledCount == cycles)
    }

    @Test("TUIContext reset cancels lifecycle background tasks")
    func contextResetCancelsLifecycleBackgroundTasks() async throws {
        let context = TUIContext()
        let probe = TaskLifecycleProbe()
        let taskCount = 8

        for index in 0..<taskCount {
            context.lifecycle.startTask(token: "shutdown-task-\(index)", priority: .medium) {
                await probe.runTask(index: index)
            }
        }

        try await probe.waitForStartedCount(taskCount)
        context.reset()
        try await probe.waitForCancelledCount(taskCount)

        for index in 0..<taskCount {
            #expect(context.lifecycle.hasAppeared(token: "shutdown-task-\(index)") == false)
        }
    }
}

private func isCurrentThreadMain() -> Bool {
    #if canImport(Darwin)
        pthread_main_np() != 0
    #else
        false
    #endif
}

private final class TaskExecutionProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var _executed = false
    private var _ranOnMainThread: Bool?

    var executed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _executed
    }

    var ranOnMainThread: Bool? {
        lock.lock()
        defer { lock.unlock() }
        return _ranOnMainThread
    }

    func markExecuted() {
        lock.lock()
        _executed = true
        lock.unlock()
    }

    func markThread(isMainThread: Bool) {
        lock.lock()
        _executed = true
        _ranOnMainThread = isMainThread
        lock.unlock()
    }
}

private struct TaskLifecycleProbeTimeout: Error {}

private func waitWithTimeout(
    _ timeout: Duration,
    operation: @escaping @Sendable () async -> Void
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            await operation()
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TaskLifecycleProbeTimeout()
        }

        try await group.next()
        group.cancelAll()
    }
}

private final class TaskLifecycleProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var started: Set<Int> = []
    private var cancelled: Set<Int> = []
    private var startedWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var cancelledWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    var startedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return started.count
    }

    var cancelledCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cancelled.count
    }

    func runTask(index: Int) async {
        markStarted(index)
        await withTaskCancellationHandler {
            try? await Task.sleep(for: .seconds(10))
        } onCancel: {
            self.markCancelled(index)
        }
    }

    func waitForStartedCount(_ expectedCount: Int, timeout: Duration = .seconds(1)) async throws {
        try await waitWithTimeout(timeout) {
            await self.waitForStartedCountUnbounded(expectedCount)
        }
    }

    func waitForCancelledCount(_ expectedCount: Int, timeout: Duration = .seconds(1)) async throws {
        try await waitWithTimeout(timeout) {
            await self.waitForCancelledCountUnbounded(expectedCount)
        }
    }

    private func waitForStartedCountUnbounded(_ expectedCount: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if started.count >= expectedCount {
                lock.unlock()
                continuation.resume()
            } else {
                startedWaiters.append((expectedCount, continuation))
                lock.unlock()
            }
        }
    }

    private func waitForCancelledCountUnbounded(_ expectedCount: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if cancelled.count >= expectedCount {
                lock.unlock()
                continuation.resume()
            } else {
                cancelledWaiters.append((expectedCount, continuation))
                lock.unlock()
            }
        }
    }

    private func markStarted(_ index: Int) {
        lock.lock()
        started.insert(index)
        let resumable = startedWaiters.filter { started.count >= $0.0 }.map(\.1)
        startedWaiters.removeAll { started.count >= $0.0 }
        lock.unlock()

        resumable.forEach { $0.resume() }
    }

    private func markCancelled(_ index: Int) {
        lock.lock()
        cancelled.insert(index)
        let resumable = cancelledWaiters.filter { cancelled.count >= $0.0 }.map(\.1)
        cancelledWaiters.removeAll { cancelled.count >= $0.0 }
        lock.unlock()

        resumable.forEach { $0.resume() }
    }
}
