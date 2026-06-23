//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIPreview.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation
import TUIkit

/// A fixed terminal canvas used to render a preview.
public struct TUIPreviewSize: Sendable, Equatable {
    /// The canvas width in terminal columns.
    public var width: Int

    /// The canvas height in terminal rows.
    public var height: Int

    /// Creates a preview size.
    public init(width: Int = 80, height: Int = 24) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    /// The classic 80×24 terminal size.
    public static let standard = Self(width: 80, height: 24)

    /// A roomy desktop terminal size.
    public static let desktop = Self(width: 120, height: 36)

    /// A narrow terminal size for stress-testing truncation and wrapping.
    public static let narrow = Self(width: 48, height: 24)
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

    private let makeView: @MainActor () -> AnyView

    /// Creates a preview from a TUIkit view builder.
    public init<Content: View>(
        _ name: String,
        id: String? = nil,
        width: Int = 80,
        height: Int = 24,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.init(name, id: id, size: TUIPreviewSize(width: width, height: height), content: content)
    }

    /// Creates a preview from a TUIkit view builder.
    public init<Content: View>(
        _ name: String,
        id: String? = nil,
        size: TUIPreviewSize = .standard,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.name = name
        self.id = id ?? Self.makeID(from: name)
        self.size = size
        self.makeView = { AnyView(content()) }
    }

    /// Renders the preview into a frame buffer.
    public func render(size overrideSize: TUIPreviewSize? = nil) -> FrameBuffer {
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

    private static func makeID(from name: String) -> String {
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
