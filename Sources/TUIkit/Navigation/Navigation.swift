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

    public mutating func removeLast(_ count: Int) {
        guard count > 0 else { return }
        elements.removeLast(min(count, elements.count))
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
        if let explicit = value.base as? ExplicitNavigationDestination {
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
        getPath: () -> [AnyHashable],
        getTop: () -> AnyHashable?,
        append: (AnyHashable) -> Void,
        removeLast: () -> Bool
    )
}

private struct ExplicitCollectionDestination {
    let destination: ExplicitNavigationDestination
    let routeDepth: Int
}

private final class NavigationCollectionState: @unchecked Sendable {
    var explicitDestinations: [ExplicitCollectionDestination] = []
    var lastPath: [AnyHashable]

    init(lastPath: [AnyHashable]) {
        self.lastPath = lastPath
    }
}

private struct NavigationStackBindings {
    let topValue: AnyHashable?
    let depth: Int
    let appendValue: (AnyHashable) -> Void
    let appendExplicit: (AnyView) -> Void
    let pop: () -> Bool
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
            getPath: { path.wrappedValue.map { AnyHashable($0) } },
            getTop: { path.wrappedValue.last.map { AnyHashable($0) } },
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
        var liveEnvironment = context.environment
        liveEnvironment.navigationDestinationRegistry = registry

        let bindings = makeNavigationBindings(context: context)

        let coordinatorPop: @MainActor @Sendable () -> Bool = { bindings.pop() }
        liveEnvironment.navigationCoordinator = NavigationCoordinator(
            pushValue: { value in bindings.appendValue(value) },
            pushExplicit: { view in bindings.appendExplicit(view) },
            pop: coordinatorPop
        )
        let liveContext = context.withEnvironment(liveEnvironment)

        if context.allowsRenderSideEffects {
            context.environment.statusBar.reportNavigationDepth(bindings.depth)
            context.environment.keyEventDispatcher!.addHandler { event in
                guard event.key == .escape else { return false }
                return bindings.pop()
            }
        }

        // An empty stack renders its root live once. A semantic prepass is
        // needed only when rendering a destination, so that destinations
        // declared in the root can be resolved without also rendering the
        // root's interactive side effects twice.
        if bindings.topValue != nil {
            var collectionEnvironment = context.environment
            collectionEnvironment.navigationDestinationRegistry = registry
            let collectionContext = context
                .withEnvironment(collectionEnvironment)
                .withPhase(.measure)
                .withBranchIdentity("navigation-semantic-root")
            _ = TUIkit.renderToBuffer(root, context: collectionContext)
        }

        let content: FrameBuffer
        if let topValue = bindings.topValue {
            let destinationIdentity = "navigation-destination-\(String(describing: type(of: topValue.base)))-\(String(describing: topValue.base))"
            let destinationContext = liveContext.withBranchIdentity(destinationIdentity)
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

        return content
    }

    private func makeNavigationBindings(context: RenderContext) -> NavigationStackBindings {
        switch storage {
        case .unmanaged:
            let stateStorage = context.environment.stateStorage!
            stateStorage.markActive(context.identity)
            let key = StateStorage.StateKey(identity: context.identity, propertyIndex: 0)
            let box: StateBox<NavigationPath> = stateStorage.storage(for: key, default: NavigationPath())
            return NavigationStackBindings(
                topValue: box.value.lastElement,
                depth: box.value.count,
                appendValue: { box.value.append($0) },
                appendExplicit: { box.value.append(ExplicitNavigationDestination(view: $0)) },
                pop: {
                    guard !box.value.isEmpty else { return false }
                    box.value.removeLast()
                    return true
                }
            )
        case .navigationPath(let path):
            return NavigationStackBindings(
                topValue: path.wrappedValue.lastElement,
                depth: path.wrappedValue.count,
                appendValue: { path.wrappedValue.append($0) },
                appendExplicit: { path.wrappedValue.append(ExplicitNavigationDestination(view: $0)) },
                pop: {
                    guard !path.wrappedValue.isEmpty else { return false }
                    path.wrappedValue.removeLast()
                    return true
                }
            )
        case .collection(let getPath, let getTop, let append, let removeLast):
            return collectionNavigationBindings(
                context: context,
                getPath: getPath,
                getTop: getTop,
                append: append,
                removeLast: removeLast
            )
        }
    }

    private func collectionNavigationBindings(
        context: RenderContext,
        getPath: @escaping () -> [AnyHashable],
        getTop: @escaping () -> AnyHashable?,
        append: @escaping (AnyHashable) -> Void,
        removeLast: @escaping () -> Bool
    ) -> NavigationStackBindings {
        let pathValues = getPath()
        let stateStorage = context.environment.stateStorage!
        stateStorage.markActive(context.identity)
        let key = StateStorage.StateKey(identity: context.identity, propertyIndex: 1)
        let stateBox: StateBox<NavigationCollectionState> = stateStorage.storage(
            for: key,
            default: NavigationCollectionState(lastPath: pathValues)
        )
        let state = stateBox.value
        if state.lastPath != pathValues {
            let commonPrefixCount = zip(state.lastPath, pathValues)
                .prefix { $0.0 == $0.1 }
                .count
            state.explicitDestinations.removeAll { $0.routeDepth > commonPrefixCount }
            state.lastPath = pathValues
        }

        let visibleExplicit = state.explicitDestinations.last { $0.routeDepth == pathValues.count }
        return NavigationStackBindings(
            topValue: visibleExplicit.map { AnyHashable($0.destination) } ?? getTop(),
            depth: pathValues.count + state.explicitDestinations.count,
            appendValue: append,
            appendExplicit: { view in
                state.explicitDestinations.append(ExplicitCollectionDestination(
                    destination: ExplicitNavigationDestination(view: view),
                    routeDepth: getPath().count
                ))
            },
            pop: {
                let currentPathCount = getPath().count
                if let last = state.explicitDestinations.last, last.routeDepth == currentPathCount {
                    state.explicitDestinations.removeLast()
                    return true
                }
                let removed = removeLast()
                if removed {
                    state.lastPath = getPath()
                    state.explicitDestinations.removeAll { $0.routeDepth > state.lastPath.count }
                }
                return removed
            }
        )
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

struct ExplicitNavigationDestination: Hashable, @unchecked Sendable {
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
        self.value = value.map { AnyHashable($0) }
        self.destination = nil
    }

    public init<P: Hashable>(_ title: String, value: P?) where Label == Text, Destination == EmptyView {
        self.label = Text(title)
        self.value = value.map { AnyHashable($0) }
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
