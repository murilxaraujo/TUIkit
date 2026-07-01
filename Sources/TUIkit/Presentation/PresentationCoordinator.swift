//  🖥️ TUIKit — Terminal UI Kit for Swift
//  PresentationCoordinator.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation

/// Identifier for a presentation registered in the view tree.
public struct PresentationID: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String = UUID().uuidString) {
        self.rawValue = rawValue
    }
}

/// Describes the broad category of presentation layer.
public enum PresentationLayerKind: Sendable, Equatable {
    case navigation
    case sheet
    case modal
    case alert
    case overlay
}

/// Minimal coordinator placeholder for the presentation architecture.
///
/// Existing modal and alert modifiers already enforce the most important MVP
/// invariant: while presented, background content is rendered through an
/// isolated focus/key context so hidden controls are inert. This coordinator is
/// the public architectural anchor for future unification of sheets, dialogs,
/// alerts, and overlays.
public final class PresentationCoordinator: @unchecked Sendable {
    private var activeLayers: [(PresentationID, PresentationLayerKind)] = []

    public init() {}

    public var topmostLayer: PresentationLayerKind? {
        activeLayers.last?.1
    }

    public func push(_ id: PresentationID, kind: PresentationLayerKind) {
        activeLayers.removeAll { $0.0 == id }
        activeLayers.append((id, kind))
    }

    public func dismiss(_ id: PresentationID) {
        activeLayers.removeAll { $0.0 == id }
    }

    public func dismissTopmost() {
        _ = activeLayers.popLast()
    }
}

private struct PresentationCoordinatorKey: EnvironmentKey {
    static let defaultValue: PresentationCoordinator? = nil
}

extension EnvironmentValues {
    public var presentationCoordinator: PresentationCoordinator? {
        get { self[PresentationCoordinatorKey.self] }
        set { self[PresentationCoordinatorKey.self] = newValue }
    }
}

public extension View {
    /// Presents a sheet when a binding to a Boolean value is true.
    ///
    /// Terminal sheets currently share TUIkit's centered modal presentation
    /// mechanics: the background is dimmed and rendered inert, while focus and
    /// keyboard input are routed to the presented content.
    func sheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modal(isPresented: isPresented, content: content)
    }
}
