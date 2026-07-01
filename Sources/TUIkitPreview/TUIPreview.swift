//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIPreview.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation
import TUIkit

/// A fixed terminal canvas used to render a preview.
public struct TUIPreviewSize: Sendable, Equatable, Codable {
    /// The canvas width in terminal columns.
    public var width: Int

    /// The canvas height in terminal rows.
    public var height: Int

    /// Creates a preview size.
    public init(width: Int = 80, height: Int = 24) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    /// Parses a size in `80x24` or `80×24` form.
    public init?(string: String) {
        let parts = string
            .replacingOccurrences(of: "×", with: "x")
            .lowercased()
            .split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]) else { return nil }
        self.init(width: width, height: height)
    }

    /// The classic 80×24 terminal size.
    public static let standard = Self(width: 80, height: 24)

    /// A roomy desktop terminal size.
    public static let desktop = Self(width: 120, height: 36)

    /// A narrow terminal size for stress-testing truncation and wrapping.
    public static let narrow = Self(width: 48, height: 24)

    /// SwiftUI-preview-inspired fixed-size spelling.
    public static func fixed(width: Int, height: Int) -> Self {
        Self(width: width, height: height)
    }
}

/// Spec-compatible name for preview canvas sizes.
public typealias PreviewSize = TUIPreviewSize

/// Terminal color scheme requested for a preview.
public enum PreviewTheme: String, Sendable, Codable, CaseIterable {
    case system
    case light
    case dark
}

/// Spec-compatible name for TUIkit's type-erased view.
public typealias AnyTUIView = AnyView

/// Metadata and factory for one TUIkit live preview.
public struct TUIkitPreviewDescriptor: @unchecked Sendable {
    public let id: String
    public let name: String
    public let file: StaticString
    public let line: UInt
    public let size: PreviewSize?
    public let theme: PreviewTheme?
    public let makeView: @MainActor @Sendable () -> AnyTUIView

    public init(
        id: String,
        name: String,
        file: StaticString = #file,
        line: UInt = #line,
        size: PreviewSize? = nil,
        theme: PreviewTheme? = nil,
        makeView: @escaping @MainActor @Sendable () -> AnyTUIView
    ) {
        self.id = id.isEmpty ? Self.makeID(from: name) : id
        self.name = name
        self.file = file
        self.line = line
        self.size = size
        self.theme = theme
        self.makeView = makeView
    }

    static func makeID(from name: String) -> String {
        let scalarID = name.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalarID)
            .lowercased()
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "preview" : collapsed
    }
}

/// Process-local preview registry used by preview executables and generated code.
@MainActor
public enum TUIkitPreviewRegistry {
    private static var descriptors: [TUIkitPreviewDescriptor] = []

    /// Registers a descriptor unless an identical id has already been registered.
    public static func register(_ descriptor: TUIkitPreviewDescriptor) {
        guard !descriptors.contains(where: { $0.id == descriptor.id }) else { return }
        descriptors.append(descriptor)
    }

    /// Removes all descriptors. Intended for tests and generated preview hosts.
    public static func reset() {
        descriptors.removeAll()
    }

    /// Returns registered descriptors in registration order.
    public static func all() -> [TUIkitPreviewDescriptor] {
        descriptors
    }

    /// Finds a preview by id or case-insensitive display name.
    public static func find(idOrName: String) -> TUIkitPreviewDescriptor? {
        descriptors.first { descriptor in
            descriptor.id == idOrName || descriptor.name.localizedCaseInsensitiveCompare(idOrName) == .orderedSame
        }
    }
}

/// A named, deterministic TUIkit view preview.
///
/// Declare previews in a small preview executable by conforming to
/// ``TUIkitPreviewApp``:
///
/// ```swift
/// @main
/// struct MyPreviews: TUIkitPreviewApp {
///     static var previews: [TUIPreview] {
///         TUIPreview("Dashboard", size: .desktop) {
///             DashboardView()
///         }
///     }
/// }
/// ```
@MainActor
public struct TUIPreview {
    /// User-visible preview name.
    public let name: String

    /// Optional stable identifier used by `--preview`.
    public let id: String

    /// The default terminal canvas for this preview.
    public let size: TUIPreviewSize

    /// The requested preview theme.
    public let theme: PreviewTheme

    /// Source file where this preview was declared, when available.
    public let file: StaticString

    /// Source line where this preview was declared, when available.
    public let line: UInt

    private let makeView: @MainActor @Sendable () -> AnyView

    /// Creates a preview from a TUIkit view builder.
    public init<Content: View>(
        _ name: String,
        id: String? = nil,
        width: Int = 80,
        height: Int = 24,
        theme: PreviewTheme = .system,
        file: StaticString = #file,
        line: UInt = #line,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.init(name, id: id, size: TUIPreviewSize(width: width, height: height), theme: theme, file: file, line: line, content: content)
    }

    /// Creates a preview from a TUIkit view builder.
    public init<Content: View>(
        _ name: String,
        id: String? = nil,
        size: TUIPreviewSize = .standard,
        theme: PreviewTheme = .system,
        file: StaticString = #file,
        line: UInt = #line,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.name = name
        self.id = id ?? TUIkitPreviewDescriptor.makeID(from: name)
        self.size = size
        self.theme = theme
        self.file = file
        self.line = line
        self.makeView = { AnyView(content()) }
    }

    /// Creates a preview from a descriptor.
    public init(_ descriptor: TUIkitPreviewDescriptor) {
        self.name = descriptor.name
        self.id = descriptor.id
        self.size = descriptor.size ?? .standard
        self.theme = descriptor.theme ?? .system
        self.file = descriptor.file
        self.line = descriptor.line
        self.makeView = descriptor.makeView
    }

    /// A descriptor representation suitable for registry registration.
    public var descriptor: TUIkitPreviewDescriptor {
        TUIkitPreviewDescriptor(id: id, name: name, file: file, line: line, size: size, theme: theme, makeView: makeView)
    }

    /// Renders the preview into a frame buffer.
    public func render(size overrideSize: TUIPreviewSize? = nil, theme _: PreviewTheme? = nil) -> FrameBuffer {
        let resolvedSize = overrideSize ?? size
        var environment = EnvironmentValues()
        environment.stateStorage = StateStorage()
        environment.renderCache = RenderCache()
        var context = RenderContext(
            availableWidth: resolvedSize.width,
            availableHeight: resolvedSize.height,
            environment: environment
        )
        context.hasExplicitWidth = true
        context.hasExplicitHeight = true
        return renderToBuffer(makeView(), context: context)
    }
}

/// Result-builder support for preview lists.
@MainActor
@resultBuilder
public enum TUIPreviewBuilder {
    public static func buildBlock(_ components: [TUIPreview]...) -> [TUIPreview] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: TUIPreview) -> [TUIPreview] {
        [expression]
    }

    public static func buildExpression(_ expression: [TUIPreview]) -> [TUIPreview] {
        expression
    }

    public static func buildOptional(_ component: [TUIPreview]?) -> [TUIPreview] {
        component ?? []
    }

    public static func buildEither(first component: [TUIPreview]) -> [TUIPreview] {
        component
    }

    public static func buildEither(second component: [TUIPreview]) -> [TUIPreview] {
        component
    }

    public static func buildArray(_ components: [[TUIPreview]]) -> [TUIPreview] {
        components.flatMap { $0 }
    }
}
