//  🖥️ TUIKit — Terminal UI Kit for Swift
//  ViewEvaluationPhase.swift
//
//  Created by LAYERED.work
//  License: MIT

/// The internal phase currently evaluating a view tree.
///
/// TUIkit uses this to separate semantic discovery from live rendering. Views
/// should only register live input, focus, lifecycle, and status-bar side
/// effects during ``render``.
public enum ViewEvaluationPhase: Sendable, Equatable {
    /// Collect semantic declarations such as navigation destinations.
    case semanticCollection

    /// Measure or resolve layout.
    case layout

    /// Produce visible output and register live interactions.
    case render
}
