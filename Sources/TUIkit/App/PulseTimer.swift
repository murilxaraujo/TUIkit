//  🖥️ TUIKit — Terminal UI Kit for Swift
//  PulseTimer.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation

/// Drives the breathing animation for the active focus section indicator.
///
/// `PulseTimer` maintains a phase value (0–1) that oscillates smoothly
/// using a sine curve. On each step, it calls `setNeedsRender()` to
/// trigger a re-render with the updated phase.
///
/// The timer runs in a structured Swift concurrency task. The task sleeps in
/// the background and only performs the tiny tick mutation/render invalidation
/// needed to keep the terminal interaction loop responsive.
///
/// ## Breathing Cycle
///
/// - The phase follows `sin(step * π / totalSteps)`, producing a smooth
///   0 → 1 → 0 oscillation.
/// - Default: 10 steps at 300ms each = 3 second cycle.
/// - At phase 0: color is dimmed (20% of accent). At phase 1: full accent.
///
/// ## Usage
///
/// ```swift
/// let pulse = PulseTimer(renderNotifier: appState)
/// pulse.start()
/// // ... later
/// pulse.stop()
/// ```
final class PulseTimer: @unchecked Sendable {
    /// The number of discrete steps in a half-cycle (dim → bright).
    ///
    /// A full breathing cycle (dim → bright → dim) is `totalHalfSteps * 2` steps.
    /// At 100ms per step and 10 half-steps: full cycle = 20 × 100ms = 2 seconds.
    private let totalHalfSteps = 10

    /// The interval between steps in milliseconds.
    private let stepIntervalMs = 100

    /// Lock protecting timer state shared between the main loop and timer queue.
    private let lock = NSLock()

    /// The current step in the full cycle (0 ..< totalHalfSteps * 2).
    private var currentStep = 0

    /// The structured concurrency task that drives ticks.
    private var task: Task<Void, Never>?

    /// The render notifier to trigger re-renders.
    private weak var renderNotifier: AppState?

    /// The current pulse phase (0–1), computed from the current step.
    ///
    /// Uses a sine curve mapped to 0–1 for smooth breathing:
    /// - Step 0: phase = 0 (dimmest)
    /// - Step totalHalfSteps: phase = 1 (brightest)
    /// - Step totalHalfSteps * 2: phase = 0 (dimmest, cycle repeats)
    var phase: Double {
        lock.lock()
        let step = currentStep
        lock.unlock()
        return phase(forStep: step)
    }

    /// Creates a new pulse timer.
    ///
    /// - Parameter renderNotifier: The app state to notify when a re-render
    ///   is needed. Held weakly to avoid retain cycles.
    init(renderNotifier: AppState) {
        self.renderNotifier = renderNotifier
    }

    deinit {
        stop()
    }
}

// MARK: - Internal API

extension PulseTimer {
    /// Starts the breathing animation.
    ///
    /// If the timer is already running, this is a no-op.
    func start() {
        lock.lock()
        guard task == nil else {
            lock.unlock()
            return
        }

        let interval = stepIntervalMs
        let task = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(interval))
                } catch {
                    break
                }

                guard let self, !Task.isCancelled else { break }
                self.tick()
            }
        }
        self.task = task
        lock.unlock()
    }

    /// Stops the breathing animation.
    func stop() {
        lock.lock()
        task?.cancel()
        task = nil
        currentStep = 0
        lock.unlock()
    }

    private func tick() {
        lock.lock()
        currentStep = (currentStep + 1) % (totalHalfSteps * 2)
        let notifier = renderNotifier
        lock.unlock()
        notifier?.setNeedsRender()
    }

    /// Resets the animation to the brightest point (phase = 1).
    ///
    /// Called when focus changes to make the indicator immediately visible
    /// on the newly focused element instead of continuing mid-cycle.
    func reset() {
        // Set to peak brightness (step = totalHalfSteps → phase = 1.0)
        lock.lock()
        currentStep = totalHalfSteps
        lock.unlock()
    }

    private func phase(forStep step: Int) -> Double {
        let fullCycle = totalHalfSteps * 2
        let normalized = Double(step) / Double(fullCycle)
        // sin(0) = 0, sin(π) = 0, peak at sin(π/2) = 1
        return sin(normalized * .pi)
    }
}
