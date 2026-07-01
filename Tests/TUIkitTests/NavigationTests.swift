//  🖥️ TUIKit — Terminal UI Kit for Swift
//  NavigationTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

private func navigationTestContext(width: Int = 80, height: Int = 24) -> RenderContext {
    var environment = EnvironmentValues()
    environment.focusManager = FocusManager()
    return RenderContext(
        availableWidth: width,
        availableHeight: height,
        environment: environment,
        tuiContext: TUIContext()
    )
}

@MainActor
private final class NavigationHarness {
    let tuiContext = TUIContext()
    let focusManager = FocusManager()
    let statusBar = StatusBarState()
    let inputHandler: InputHandler

    init() {
        inputHandler = InputHandler(
            statusBar: statusBar,
            keyEventDispatcher: tuiContext.keyEventDispatcher,
            focusManager: focusManager,
            paletteManager: ThemeManager(items: PaletteRegistry.all),
            appearanceManager: ThemeManager(items: AppearanceRegistry.all),
            onQuit: {}
        )
    }

    @discardableResult
    func render<V: View>(_ view: V) -> FrameBuffer {
        tuiContext.keyEventDispatcher.clearHandlers()
        focusManager.beginRenderPass()
        statusBar.clearUserItems()
        statusBar.resetNavigationDepth()
        tuiContext.lifecycle.beginRenderPass()
        tuiContext.stateStorage.beginRenderPass()
        tuiContext.renderCache.beginRenderPass()

        var environment = EnvironmentValues()
        environment.focusManager = focusManager
        environment.statusBar = statusBar
        environment.palette = SystemPalette.default
        environment.appearance = .default
        environment.stateStorage = tuiContext.stateStorage
        environment.lifecycle = tuiContext.lifecycle
        environment.keyEventDispatcher = tuiContext.keyEventDispatcher
        environment.renderCache = tuiContext.renderCache
        environment.preferenceStorage = tuiContext.preferences

        var context = RenderContext(
            availableWidth: 80,
            availableHeight: 24,
            environment: environment
        )
        context.hasExplicitWidth = true
        context.hasExplicitHeight = true
        let buffer = renderToBuffer(view, context: context)
        focusManager.endRenderPass()
        tuiContext.lifecycle.endRenderPass()
        tuiContext.stateStorage.endRenderPass()
        return buffer
    }

    func send(_ key: Key) {
        inputHandler.handle(KeyEvent(key: key))
    }
}

private struct StatefulNavigationDestination: View {
    @State private var expanded = false

    var body: some View {
        VStack {
            Button(expanded ? "Hide" : "Show") { expanded.toggle() }
            Text(expanded ? "expanded" : "collapsed")
        }
    }
}

private struct ConditionalStatefulNavigationDestination: View {
    let showStatefulBranch: Bool

    var body: some View {
        if showStatefulBranch {
            StatefulNavigationDestination()
        } else {
            Text("inactive")
        }
    }
}

@MainActor
@Suite("NavigationPath Tests", .serialized)
struct NavigationPathTests {
    @Test("empty path")
    func emptyPath() {
        let path = NavigationPath()
        #expect(path.isEmpty)
        #expect(path.count == 0)
    }

    @Test("append and remove values")
    func appendAndRemove() {
        var path = NavigationPath()
        path.append("colors")
        path.append(42)
        #expect(!path.isEmpty)
        #expect(path.count == 2)
        path.removeLast()
        #expect(path.count == 1)
        path.removeLast(10)
        #expect(path.isEmpty)
    }
}

@MainActor
@Suite("Navigation Destination Registry Tests", .serialized)
struct NavigationDestinationRegistryTests {
    @Test("register and resolve route type")
    func resolveRouteType() {
        let registry = NavigationDestinationRegistry()
        registry.register(String.self) { value in
            Text("Destination: \(value)")
        }

        let resolved = registry.resolve(AnyHashable("colors"))
        let buffer = renderToBuffer(resolved ?? AnyView(EmptyView()), context: navigationTestContext())
        #expect(buffer.lines.joined().contains("Destination: colors"))
    }

    @Test("no matching route returns nil")
    func noMatchingRoute() {
        let registry = NavigationDestinationRegistry()
        registry.register(Int.self) { value in Text("\(value)") }
        #expect(registry.resolve(AnyHashable("missing")) == nil)
    }

    @Test("duplicate registration uses last builder")
    func duplicateRegistrationUsesLastBuilder() {
        let registry = NavigationDestinationRegistry()
        registry.register(String.self) { _ in Text("first") }
        registry.register(String.self) { _ in Text("second") }
        let resolved = registry.resolve(AnyHashable("route"))
        let buffer = renderToBuffer(resolved ?? AnyView(EmptyView()), context: navigationTestContext())
        #expect(buffer.lines.joined().contains("second"))
    }
}

@MainActor
@Suite("NavigationStack Tests", .serialized)
struct NavigationStackTests {
    enum Route: Hashable {
        case detail
        case other
    }

    @Test("empty path renders root")
    func emptyPathRendersRoot() {
        var path: [Route] = []
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let stack = NavigationStack(path: binding) {
            Text("Root")
                .navigationDestination(for: Route.self) { _ in Text("Detail") }
        }

        let buffer = renderToBuffer(stack, context: navigationTestContext())
        #expect(buffer.lines.joined().contains("Root"))
    }

    @Test("non-empty path renders destination")
    func nonEmptyPathRendersDestination() {
        var path: [Route] = [.detail]
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let stack = NavigationStack(path: binding) {
            Text("Root")
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .detail: Text("Detail")
                    case .other: Text("Other")
                    }
                }
        }

        let buffer = renderToBuffer(stack, context: navigationTestContext())
        #expect(buffer.lines.joined().contains("Detail"))
        #expect(!buffer.lines.joined().contains("Root"))
    }

    @Test("escape pops one path element and bubbles at root")
    func escapePopAndBubble() {
        var path: [Route] = [.detail, .other]
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let context = navigationTestContext()
        let stack = NavigationStack(path: binding) {
            Text("Root")
                .navigationDestination(for: Route.self) { _ in Text("Destination") }
        }

        _ = renderToBuffer(stack, context: context)
        #expect(context.environment.keyEventDispatcher!.dispatch(KeyEvent(key: .escape)))
        #expect(path == [.detail])

        context.environment.keyEventDispatcher!.clearHandlers()
        _ = renderToBuffer(stack, context: context)
        #expect(context.environment.keyEventDispatcher!.dispatch(KeyEvent(key: .escape)))
        #expect(path.isEmpty)

        context.environment.keyEventDispatcher!.clearHandlers()
        _ = renderToBuffer(stack, context: context)
        #expect(!context.environment.keyEventDispatcher!.dispatch(KeyEvent(key: .escape)))
    }

    @Test("destination button receives enter")
    func destinationButtonReceivesEnter() {
        var path: [Route] = [.detail]
        var pressed = false
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let context = navigationTestContext()
        let stack = NavigationStack(path: binding) {
            Text("Root")
                .navigationDestination(for: Route.self) { _ in
                    Button("Press") { pressed = true }
                }
        }

        _ = renderToBuffer(stack, context: context)
        #expect(context.environment.focusManager.currentFocusedID != nil)
        #expect(context.environment.focusManager.dispatchKeyEvent(KeyEvent(key: .enter)))
        #expect(pressed)
    }

    @Test("runtime input handler activates destination controls")
    func runtimeInputHandlerActivatesDestinationControls() {
        var path: [Route] = [.detail]
        var buttonPressed = false
        var toggleValue = false
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let toggleBinding = Binding<Bool>(get: { toggleValue }, set: { toggleValue = $0 })
        let harness = NavigationHarness()
        let stack = NavigationStack(path: binding) {
            VStack {
                Button("Hidden Root Button") { buttonPressed = false }
            }
            .navigationDestination(for: Route.self) { _ in
                VStack {
                    Button("Press") { buttonPressed = true }
                    Toggle("Toggle", isOn: toggleBinding)
                }
            }
        }

        harness.render(stack)
        harness.send(.enter)
        #expect(buttonPressed)

        harness.render(stack)
        harness.send(.down)
        harness.send(.space)
        #expect(toggleValue)
    }

    @Test("destination own @State hydrates and updates from input")
    func destinationOwnStateHydratesAndUpdatesFromInput() {
        var path: [Route] = [.detail]
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let harness = NavigationHarness()
        let stack = NavigationStack(path: binding) {
            Text("Root")
                .navigationDestination(for: Route.self) { _ in
                    StatefulNavigationDestination()
                }
        }

        var buffer = harness.render(stack)
        #expect(buffer.lines.joined().stripped.contains("collapsed"))
        harness.send(.enter)
        buffer = harness.render(stack)
        #expect(buffer.lines.joined().stripped.contains("expanded"))
    }

    @Test("destination @State survives conditional destination builder wrapper")
    func destinationStateSurvivesConditionalDestinationBuilderWrapper() {
        var path: [Route] = [.detail]
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let harness = NavigationHarness()
        let stack = NavigationStack(path: binding) {
            Text("Root")
                .navigationDestination(for: Route.self) { _ in
                    ConditionalStatefulNavigationDestination(showStatefulBranch: true)
                }
        }

        var buffer = harness.render(stack)
        #expect(buffer.lines.joined().stripped.contains("collapsed"))
        harness.send(.enter)
        buffer = harness.render(stack)
        #expect(buffer.lines.joined().stripped.contains("expanded"))
    }

    @Test("root-only quit hides q on navigation destinations")
    func rootOnlyQuitHidesQOnNavigationDestinations() {
        var path: [Route] = []
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let harness = NavigationHarness()
        harness.statusBar.quitBehavior = .rootOnly
        let stack = NavigationStack(path: binding) {
            Text("Root")
                .navigationDestination(for: Route.self) { _ in Text("Destination") }
        }

        _ = harness.render(stack)
        #expect(harness.statusBar.currentItems.contains { $0.shortcut == "q" && $0.label == "quit" })

        path = [.detail]
        _ = harness.render(stack)
        #expect(!harness.statusBar.currentItems.contains { $0.shortcut == "q" && $0.label == "quit" })

        path = []
        _ = harness.render(stack)
        #expect(harness.statusBar.currentItems.contains { $0.shortcut == "q" && $0.label == "quit" })
    }

    @Test("semantic collection does not leak hidden root key handlers or focus")
    func semanticCollectionDoesNotLeakHiddenRootInteractions() {
        var path: [Route] = [.detail]
        var hiddenRootKeyHandled = false
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let context = navigationTestContext()
        let stack = NavigationStack(path: binding) {
            VStack {
                Button("Hidden Root Button") {}
                Text("Root")
            }
            .onKeyPress { event in
                guard event.key == .character("x") else { return false }
                hiddenRootKeyHandled = true
                return true
            }
            .navigationDestination(for: Route.self) { _ in Text("Destination") }
        }

        _ = renderToBuffer(stack, context: context)
        #expect(!context.environment.keyEventDispatcher!.dispatch(KeyEvent(key: .character("x"))))
        #expect(hiddenRootKeyHandled == false)
        #expect(context.environment.focusManager.currentFocusedID == nil)
    }
}

@MainActor
@Suite("NavigationLink Tests", .serialized)
struct NavigationLinkTests {
    enum Route: Hashable { case detail }

    @Test("enabled value link focuses and enter pushes value")
    func valueLinkPushes() {
        var path: [Route] = []
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let context = navigationTestContext()
        let stack = NavigationStack(path: binding) {
            NavigationLink("Go", value: Route.detail)
                .navigationDestination(for: Route.self) { _ in Text("Detail") }
        }

        _ = renderToBuffer(stack, context: context)
        #expect(context.environment.focusManager.currentFocusedID != nil)
        #expect(context.environment.focusManager.dispatchKeyEvent(KeyEvent(key: .enter)))
        #expect(path == [.detail])
    }

    @Test("nil value link is disabled and not focusable")
    func nilValueDisabled() {
        var path: [Route] = []
        let binding = Binding<[Route]>(get: { path }, set: { path = $0 })
        let context = navigationTestContext()
        let stack = NavigationStack(path: binding) {
            NavigationLink("No-op", value: Optional<Route>.none)
                .navigationDestination(for: Route.self) { _ in Text("Detail") }
        }

        let buffer = renderToBuffer(stack, context: context)
        #expect(buffer.lines.joined().stripped.contains("No-op"))
        #expect(context.environment.focusManager.currentFocusedID == nil)
    }

    @Test("direct destination link works with NavigationPath")
    func directDestinationLink() {
        var path = NavigationPath()
        let binding = Binding<NavigationPath>(get: { path }, set: { path = $0 })
        let context = navigationTestContext()
        let stack = NavigationStack(path: binding) {
            NavigationLink("Direct") { Text("Direct Destination") }
        }

        _ = renderToBuffer(stack, context: context)
        #expect(context.environment.focusManager.dispatchKeyEvent(KeyEvent(key: .enter)))
        context.environment.keyEventDispatcher!.clearHandlers()
        let destinationBuffer = renderToBuffer(stack, context: context)
        #expect(destinationBuffer.lines.joined().contains("Direct Destination"))
    }
}
