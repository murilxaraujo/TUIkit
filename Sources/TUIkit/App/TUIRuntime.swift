//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIRuntime.swift
//
//  Created by LAYERED.work
//  License: MIT

/// Utilities for scheduling work outside the synchronous terminal render loop.
public enum TUIRuntime {
    /// Starts background work that does not inherit the current actor.
    ///
    /// Use this for file I/O, networking, image decoding, indexing, or other
    /// expensive work kicked off by TUI actions. Publish the final result through
    /// `@State`, `@Binding`, or an observable model on the UI's owning actor.
    ///
    /// - Parameters:
    ///   - priority: Priority for the detached task. Defaults to `.userInitiated`.
    ///   - operation: The asynchronous work to perform off the interaction loop.
    /// - Returns: The created task so callers can cancel it if needed.
    @discardableResult
    public static func runInBackground(
        priority: TaskPriority = .userInitiated,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task.detached(priority: priority) {
            await operation()
        }
    }
}
