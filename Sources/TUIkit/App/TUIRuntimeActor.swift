//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIRuntimeActor.swift
//
//  Created by LAYERED.work
//  License: MIT

/// Serial executor for TUIkit runtime coordination.
///
/// TUIkit follows a SwiftUI-like responsiveness model: input handling, focus
/// changes, render scheduling, and terminal writes are coordinated on one
/// runtime lane, while expensive work should run in background tasks and publish
/// small state changes back to the UI model.
///
/// The current app loop is still synchronous for terminal portability, so not
/// every runtime type is actor-isolated yet. This actor is the public marker for
/// that direction and can be used by applications that want an explicit hop back
/// to TUIkit's interaction lane after background work completes.
@globalActor
public actor TUIRuntimeActor {
    /// Shared runtime actor instance.
    public static let shared = TUIRuntimeActor()
}

/// Utilities for scheduling work without blocking the terminal interaction loop.
public enum TUIRuntime {
    /// Starts background work that does not inherit the current actor.
    ///
    /// Use this for file I/O, networking, image decoding, indexing, or other
    /// expensive work kicked off by TUI actions. Publish the final result through
    /// `@State`, `@Binding`, an observable model, or an explicit actor hop.
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
