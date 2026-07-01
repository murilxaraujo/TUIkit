//  🖥️ TUIKit — Terminal UI Kit for Swift
//  Navigation.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation

// MARK: - NavigationPath

/// A type-erased stack of hashable route values.
public struct NavigationPath: Equatable, @unchecked Sendable {
    private var elements: [AnyHashable]

    public init() {
        self.elements = []
    }

    init(elements: [AnyHashable]) {
        self.elements = elements
    }

    public var isEmpty: Bool { elements.isEmpty }
    public var count: Int { elements.count }

    public mutating func append<V: Hashable>(_ value: V) {
        elements.append(AnyHashable(value))
    }

    public mutating func removeLast() {
        guard !elements.isEmpty else { return }
        elements.removeLast()
    }

    public mutating func removeLast(_ k: Int) {
        guard k > 0 else { return }
        elements.removeLast(min(k, elements.count))
    }

    var lastElement: AnyHashable? { elements.last }
}

// MARK: - Destination Registry

/// Type-keyed registry used by NavigationStack to resolve route values.
@MainActor
public final class NavigationDestinationRegistry: @unchecked Sendable {
    private var builders: [ObjectIdentifier: @MainActor (AnyHashable) -> AnyView?] = [:]

    public init() {}

    public func register<D: Hashable, C: View>(
        _ type: D.Type,
        destination: @escaping (D) -> C
    ) {
        builders[ObjectIdentifier(type)] = { value in
            guard let typedValue = value.base as? D else { return nil }
            return AnyView { context in
                let destinationView = StateRegistration.withHydration(context: context) {
                    destination(typedValue)
                }
                context.environment.stateStorage?.markActive(context.identity)
                return TUIkit.renderToBuffer(destinationView, context: context)
            }
        }
    }

    public func resolve(_ value: AnyHashable) -> AnyView? {
        if let explicit = value.base as? _ExplicitNavigationDestination {
            return explicit.view
        }
        return builders[ObjectIdentifier(type(of: value.base))]?(value)
    }
}

struct NavigationCoordinator: @unchecked Sendable {
    var pushValue: @MainActor @Sendable (AnyHashable) -> Void
    var pushExplicit: @MainActor @Sendable (AnyView) -> Void
    var pop: @MainActor @Sendable () -> Bool
}

private struct NavigationDestinationRegistryKey: EnvironmentKey {
    static let defaultValue: NavigationDestinationRegistry? = nil
}

private struct NavigationCoordinatorKey: EnvironmentKey {
    static let defaultValue: NavigationCoordinator? = nil
}

extension EnvironmentValues {
    var navigationDestinationRegistry: NavigationDestinationRegistry? {
        get { self[NavigationDestinationRegistryKey.self] }
        set { self[NavigationDestinationRegistryKey.self] = newValue }
    }

    var navigationCoordinator: NavigationCoordinator? {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}

// MARK: - navigationDestination

struct NavigationDestinationModifier<Content: View, D: Hashable, Destination: View>: View, Renderable {
    let content: Content
    let dataType: D.Type
    let destination: (D) -> Destination

    var body: Never {
        fatalError("NavigationDestinationModifier renders via Renderable")
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        context.environment.navigationDestinationRegistry?.register(dataType, destination: destination)
        return TUIkit.renderToBuffer(content, context: context)
    }
}

public extension View {
    /// Associates a destination view with a route data type for the nearest navigation stack.
    func navigationDestination<D, C>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View where D: Hashable, C: View {
        NavigationDestinationModifier(content: self, dataType: data, destination: destination)
    }
}

// MARK: - NavigationStack

private enum NavigationStackStorage<Data> {
    case unmanaged
    case navigationPath(Binding<NavigationPath>)
    case collection(
        getTop: () -> AnyHashable?,
        append: (AnyHashable) -> Void,
        removeLast: () -> Bool
    )
}

/// A SwiftUI-inspired stack-based navigation container for terminal views.
public struct NavigationStack<Data, Root: View>: View, Renderable {
    private let root: Root
    private let storage: NavigationStackStorage<Data>

    public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {
        self.root = root()
        self.storage = .unmanaged
    }

    public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) where Data == NavigationPath {
        self.root = root()
        self.storage = .navigationPath(path)
    }

    public init(
        path: Binding<Data>,
        @ViewBuilder root: () -> Root
    ) where Data: MutableCollection,
            Data: RandomAccessCollection,
            Data: RangeReplaceableCollection,
            Data.Element: Hashable {
        self.root = root()
        self.storage = .collection(
            getTop: { path.wrappedValue.last.map(AnyHashable.init) },
            append: { value in
                guard let typed = value.base as? Data.Element else { return }
                path.wrappedValue.append(typed)
            },
            removeLast: {
                guard !path.wrappedValue.isEmpty else { return false }
                path.wrappedValue.removeLast()
                return true
            }
        )
    }

    public var body: Never {
        fatalError("NavigationStack renders via Renderable")
    }

    public func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let registry = NavigationDestinationRegistry()
        var collectionEnvironment = context.environment
        collectionEnvironment.navigationDestinationRegistry = registry
        let collectionContext = context
            .withEnvironment(collectionEnvironment)
            .withPhase(.semanticCollection)
            .withBranchIdentity("navigation-semantic-root")
        _ = TUIkit.renderToBuffer(root, context: collectionContext)

        var liveEnvironment = context.environment
        liveEnvironment.navigationDestinationRegistry = registry

        let topValue: AnyHashable?
        let appendValue: (AnyHashable) -> Void
        let appendExplicit: (AnyView) -> Void
        let popValue: () -> Bool

        switch storage {
        case .unmanaged:
            let stateStorage = context.environment.stateStorage!
            let key = StateStorage.StateKey(identity: context.identity, propertyIndex: 0)
            let box: StateBox<NavigationPath> = stateStorage.storage(for: key, default: NavigationPath())
            topValue = box.value.lastElement
            appendValue = { box.value.append($0) }
            appendExplicit = { box.value.append(_ExplicitNavigationDestination(view: $0)) }
            popValue = {
                guard !box.value.isEmpty else { return false }
                box.value.removeLast()
                return true
            }
        case .navigationPath(let path):
            topValue = path.wrappedValue.lastElement
            appendValue = { path.wrappedValue.append($0) }
            appendExplicit = { path.wrappedValue.append(_ExplicitNavigationDestination(view: $0)) }
            popValue = {
                guard !path.wrappedValue.isEmpty else { return false }
                path.wrappedValue.removeLast()
                return true
            }
        case .collection(let getTop, let append, let removeLast):
            topValue = getTop()
            appendValue = append
            appendExplicit = { _ in }
            popValue = removeLast
        }

        let coordinatorPop: @MainActor @Sendable () -> Bool = { popValue() }
        liveEnvironment.navigationCoordinator = NavigationCoordinator(
            pushValue: { value in appendValue(value) },
            pushExplicit: { view in appendExplicit(view) },
            pop: coordinatorPop
        )
        let liveContext = context.withEnvironment(liveEnvironment)

        if context.allowsRenderSideEffects {
            context.environment.statusBar.reportNavigationDepth(topValue == nil ? 0 : 1)
        }

        let content: FrameBuffer
        if let topValue {
            let destinationContext = liveContext.withBranchIdentity("navigation-destination-\(String(describing: type(of: topValue.base)))-\(String(describing: topValue.base))")
            let destinationView = registry.resolve(topValue) ?? AnyView(missingDestinationView(for: topValue))
            content = TUIkit.renderToBuffer(
                destinationView,
                context: destinationContext
            )
        } else {
            content = TUIkit.renderToBuffer(
                root,
                context: liveContext.withBranchIdentity("navigation-root")
            )
        }

        guard context.allowsRenderSideEffects else { return content }
        context.environment.keyEventDispatcher!.addHandler { event in
            guard event.key == .escape else { return false }
            return popValue()
        }
        return content
    }

    private func missingDestinationView(for value: AnyHashable) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Missing navigation destination")
                .bold()
                .foregroundStyle(.palette.warning)
            Text("No .navigationDestination(for:) was registered for \(String(describing: type(of: value.base))).")
                .foregroundStyle(.palette.foregroundSecondary)
        }
        .padding()
    }
}

// MARK: - NavigationLink

struct _ExplicitNavigationDestination: Hashable, @unchecked Sendable {
    let id = UUID()
    let view: AnyView

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public struct NavigationLink<Label: View, Destination: View>: View {
    private let label: Label
    private let value: AnyHashable?
    private let destination: AnyView?

    public init<P: Hashable>(value: P?, @ViewBuilder label: () -> Label) where Destination == EmptyView {
        self.label = label()
        self.value = value.map(AnyHashable.init)
        self.destination = nil
    }

    public init<P: Hashable>(_ title: String, value: P?) where Label == Text, Destination == EmptyView {
        self.label = Text(title)
        self.value = value.map(AnyHashable.init)
        self.destination = nil
    }

    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.label = label()
        self.value = nil
        self.destination = AnyView(destination())
    }

    public init(_ title: String, @ViewBuilder destination: () -> Destination) where Label == Text {
        self.label = Text(title)
        self.value = nil
        self.destination = AnyView(destination())
    }

    public var body: some View {
        _NavigationLinkCore(label: label, value: value, destination: destination)
    }
}

private struct _NavigationLinkCore<Label: View>: View, Renderable {
    let label: Label
    let value: AnyHashable?
    let destination: AnyView?

    var body: Never {
        fatalError("_NavigationLinkCore renders via Renderable")
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let labelBuffer = TUIkit.renderToBuffer(label, context: context)
        let isEnabled = value != nil || destination != nil

        let persistedFocusID = FocusRegistration.persistFocusID(
            context: context,
            explicitFocusID: nil,
            defaultPrefix: "navigation-link",
            propertyIndex: 0
        )
        let handler = ActionHandler(
            focusID: persistedFocusID,
            action: {
                if let value {
                    context.environment.navigationCoordinator?.pushValue(value)
                } else if let destination {
                    context.environment.navigationCoordinator?.pushExplicit(destination)
                }
            },
            canBeFocused: isEnabled
        )
        FocusRegistration.register(context: context, handler: handler)
        let isFocused = FocusRegistration.isFocused(context: context, focusID: persistedFocusID)

        let palette = context.environment.palette
        let prefix = BorderRenderer.focusIndicatorPrefix(
            isFocused: isFocused && isEnabled,
            pulsePhase: context.environment.pulsePhase,
            palette: palette
        )
        let chevron = isEnabled ? "› " : "  "
        let dimmed = !isEnabled
        let lines = labelBuffer.lines.enumerated().map { index, line in
            let leading = index == 0 ? prefix + chevron : "  "
            if dimmed {
                return leading + ANSIRenderer.colorize(line.stripped, foreground: palette.foregroundTertiary.opacity(ViewConstants.disabledForeground))
            }
            return leading + line
        }
        return FrameBuffer(lines: lines.isEmpty ? [prefix + chevron] : lines)
    }
}
