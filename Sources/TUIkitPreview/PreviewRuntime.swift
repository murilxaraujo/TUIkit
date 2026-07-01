//  🖥️ TUIKit — Terminal UI Kit for Swift
//  PreviewRuntime.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation
import TUIkit

/// Concrete terminal size used by the live preview host.
public typealias TerminalSize = TUIPreviewSize

/// Runtime environment used while rendering a preview.
public struct PreviewEnvironment: Sendable, Equatable {
    public var size: TerminalSize
    public var theme: PreviewTheme
    public var isPreview: Bool

    public init(size: TerminalSize = .standard, theme: PreviewTheme = .system, isPreview: Bool = true) {
        self.size = size
        self.theme = theme
        self.isPreview = isPreview
    }
}

/// Input events understood by preview hosts.
public enum PreviewInput: Sendable, Equatable {
    case quit
    case reload
    case picker
    case up
    case down
    case left
    case right
    case enter
    case space
    case character(Character)
}

/// A host capable of rendering and updating a preview.
@MainActor
public protocol PreviewHost {
    func render() async throws
    func handleInput(_ input: PreviewInput) async throws
}

/// Deterministic host used by tests and non-interactive CLI rendering.
@MainActor
public final class StaticPreviewHost: PreviewHost {
    private let preview: TUIPreview
    private var environment: PreviewEnvironment
    private let output: @MainActor (String) -> Void

    public init(
        preview: TUIPreview,
        environment: PreviewEnvironment,
        output: @escaping @MainActor (String) -> Void = { print($0) }
    ) {
        self.preview = preview
        self.environment = environment
        self.output = output
    }

    public func render() async throws {
        let buffer = preview.render(size: environment.size, theme: environment.theme)
        output(buffer.lines.joined(separator: "\n"))
    }

    public func handleInput(_ input: PreviewInput) async throws {
        switch input {
        case .reload:
            try await render()
        default:
            break
        }
    }
}

/// A filesystem change reported by a preview watcher.
public struct FileChange: Sendable, Equatable {
    public var path: String
    public var modifiedAt: Date

    public init(path: String, modifiedAt: Date) {
        self.path = path
        self.modifiedAt = modifiedAt
    }
}

/// Platform-neutral file watching abstraction.
public protocol FileWatcher: Sendable {
    func events() -> AsyncStream<FileChange>
}

/// Portable polling watcher for Swift packages.
public struct PollingFileWatcher: FileWatcher {
    public var root: URL
    public var interval: TimeInterval
    public var ignoredPathComponents: Set<String>

    public init(
        root: URL,
        interval: TimeInterval = 0.25,
        ignoredPathComponents: Set<String> = [".build", ".git", "DerivedData", ".swiftpm"]
    ) {
        self.root = root
        self.interval = interval
        self.ignoredPathComponents = ignoredPathComponents
    }

    public func events() -> AsyncStream<FileChange> {
        AsyncStream { continuation in
            let task = Task.detached {
                var snapshot = self.snapshot()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    let next = self.snapshot()
                    for (path, date) in next where snapshot[path] != date {
                        continuation.yield(FileChange(path: path, modifiedAt: date))
                    }
                    snapshot = next
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func snapshot() -> [String: Date] {
        let manager = FileManager.default
        var result: [String: Date] = [:]
        let package = root.appendingPathComponent("Package.swift")
        if let date = modifiedDate(for: package) {
            result[package.path] = date
        }

        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsPackageDescendants]
        ) else { return result }

        for case let url as URL in enumerator {
            if shouldIgnore(url) { continue }
            guard url.pathExtension == "swift" || url.lastPathComponent == "Package.resolved" else { continue }
            if let date = modifiedDate(for: url) {
                result[url.path] = date
            }
        }
        return result
    }

    private func shouldIgnore(_ url: URL) -> Bool {
        let parts = Set(url.pathComponents)
        return !parts.isDisjoint(with: ignoredPathComponents)
    }

    private func modifiedDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
