# NavigationStack and Presentation Architecture Plan

## Purpose

This document captures the long-term implementation plan for SwiftUI-style `NavigationStack` in TUIkit, with enough architectural context to resume implementation after resetting agent context.

The goal is not just to add a demo-level router. The goal is a production-ready, performant, SwiftUI-inspired terminal UI framework that can support:

- `NavigationStack`
- `NavigationPath`
- `NavigationLink`
- `.navigationDestination(...)`
- future `.sheet(...)`, `.alert(...)`, `.confirmationDialog(...)`, and overlay behavior
- predictable focus and keyboard routing
- no hidden-view input/focus leakage

## Source references

Apple Developer Documentation reviewed via Apple Docs MCP:

- `NavigationStack`
- `NavigationPath`
- `NavigationLink`
- `NavigationStack.init(root:)`
- `NavigationStack.init(path:root:)`
- `NavigationLink.init(value:label:)`
- `NavigationLink.init(_:value:)`
- `NavigationLink.init(destination:label:)`
- `View.navigationDestination(for:destination:)`
- `View.navigationDestination(isPresented:destination:)`
- `View.navigationDestination(item:destination:)`

Important SwiftUI behavior to mirror:

1. A navigation stack has a non-removable root view.
2. Pushing appends data/view state to a stack path.
3. Popping removes the last path element.
4. Programmatic navigation happens by mutating a bound path.
5. `.navigationDestination(for:)` associates data types with destination builders.
6. `NavigationLink(value:)` pushes a value resolved by the nearest matching destination.
7. Destination modifiers should not be placed inside lazy containers because the navigation stack must always be able to discover them.
8. `NavigationPath` supports heterogeneous route values through type erasure; codable restoration is supported when stored values are codable.

## Current TUIkit state

The example app currently uses manual state routing:

- `Sources/TUIkitExample/ContentView.swift`
- `@State var currentPage: DemoPage`
- `switch currentPage` to choose a page
- `MainMenuPage` mutates the `currentPage` binding
- `Esc` returns to `.menu`

TUIkit already has pieces we can build on:

- `View` / `ViewBuilder` in `Sources/TUIkitView/`
- `AnyView` type erasure in `Sources/TUIkitView/Core/PrimitiveViews.swift`
- `Binding` and `@State`
- `EnvironmentValues`
- `PreferenceKey` and `.navigationTitle(...)`
- key handlers via `.onKeyPress`
- focus registration and handlers
- presentation-like modifiers today: alerts, modals, app header, status bar items
- `NavigationSplitView` already exists for multi-column selection-style navigation

However, many runtime behaviors are currently discovered during rendering. Examples include focus registration, key handlers, status bar items, and preferences. This is acceptable for simple visible trees but becomes fragile for SwiftUI-style hidden semantic declarations.

## Core architectural problem

SwiftUI code usually declares destinations on the root view:

```swift
NavigationStack(path: $path) {
    MenuView()
        .navigationDestination(for: DemoRoute.self) { route in
            switch route {
            case .colors: ColorsPage()
            case .buttons: ButtonsPage()
            }
        }
}
```

When `path` is non-empty, the visible page might be `ColorsPage`, not `MenuView`. TUIkit still needs to know about the destination builder declared on `MenuView`.

A naive solution is to render `MenuView` invisibly to collect destinations, then render `ColorsPage` visibly. That is risky because rendering currently has side effects:

- hidden buttons/lists/menus can register focus targets
- hidden `.onKeyPress` handlers can consume input
- hidden status items can leak into the real status bar
- lifecycle hooks and preferences can fire unexpectedly
- expensive drawing work can be duplicated

This same problem will appear with future `.sheet`, `.alert`, overlays, commands, toolbars, and focus scopes.

## Long-term production approach

Move TUIkit toward a multi-phase internal pipeline where semantic collection is separate from terminal drawing.

Target mental model:

```text
Declarative View Tree
        ↓
Semantic Collection / View Graph
        ↓
Presentation Resolution
        ↓
Layout
        ↓
Terminal Render Buffer
        ↓
Input Dispatch
```

Avoid this long-term model:

```text
Render tree and let views mutate global systems while drawing
```

Rendering should eventually be the final visual stage, not the phase where hidden semantic declarations are discovered.

## Proposed internal concepts

### Evaluation phase

Introduce an evaluation/render phase in `RenderContext` or adjacent context:

```swift
enum ViewEvaluationPhase: Sendable, Equatable {
    case semanticCollection
    case layout
    case render
}
```

Short-term use:

- In `.semanticCollection`, collect navigation destinations and presentation registrations.
- In `.render`, register live focus/key/status behavior and produce the visible buffer.
- Existing controls can guard side effects with `context.phase == .render` while we migrate.

This is a bridge toward a real semantic graph. It is better than a hidden render with fake global managers because intent is explicit and testable.

### Semantic collector

Add a per-frame collector for semantic registrations:

```swift
struct ViewGraphCollector {
    var navigationDestinations: NavigationDestinationRegistry
    var presentations: PresentationRegistry
    var preferences: PreferenceValues
    var statusItems: [StatusBarItemRegistration]
    var keyHandlers: [KeyHandlerRegistration]
    var focusCandidates: [FocusCandidate]
}
```

This does not need to exist fully on day one. Start with navigation destinations and presentation registrations, then migrate focus/key/status over time.

### Navigation destination registry

Type-keyed registry:

```swift
struct NavigationDestinationRegistry {
    mutating func register<D: Hashable, C: View>(
        _ type: D.Type,
        destination: @escaping (D) -> C
    )

    func resolve(_ value: AnyHashable) -> AnyView?
}
```

Implementation detail: store builders by `ObjectIdentifier(D.self)` and cast from `AnyHashable.base`/boxed route to `D`.

### Presentation coordinator

Unify navigation, sheets, modals, alerts, and overlays under a presentation layer rather than one-off modifiers:

```swift
final class PresentationCoordinator {
    var navigationStacks: [NavigationStackID: NavigationStackState]
    var sheets: [PresentationID: SheetState]
    var alerts: [PresentationID: AlertState]
    var overlays: [PresentationID: OverlayState]
}
```

Presentation order should eventually be explicit:

```text
Root / active navigation destination
    → sheet / modal
        → alert / confirmation dialog
            → non-blocking notification overlays
```

### Input dispatch policy

Only visible/active presentation layers should receive input.

Expected rules:

- If an alert is active, alert handles input first; background is inert.
- Else if a sheet/modal is active, sheet handles input; underlying route is visually dimmed/inert.
- Else active navigation destination handles input.
- `Esc` pops/dismisses the top active presentation when appropriate.
- `Esc` bubbles when there is nothing for the current layer to dismiss.

## Public API target

### NavigationStack

Add under `Sources/TUIkit/Navigation/` or `Sources/TUIkit/Views/` depending on project organization.

```swift
public struct NavigationStack<Data, Root: View>: View
```

Initializers to mirror SwiftUI:

```swift
public init(@ViewBuilder root: () -> Root)
    where Data == NavigationPath

public init(
    path: Binding<Data>,
    @ViewBuilder root: () -> Root
) where Data: MutableCollection,
        Data: RandomAccessCollection,
        Data: RangeReplaceableCollection,
        Data.Element: Hashable
```

Behavior:

- Empty path renders root.
- Non-empty path renders destination for the last path element.
- Root cannot be popped.
- `Esc` pops if path is non-empty.
- `Esc` bubbles if path is empty.
- Missing destination should produce a clear debug fallback in development, not crash by default.

### NavigationPath

```swift
public struct NavigationPath: Equatable, Sendable {
    public init()
    public var isEmpty: Bool { get }
    public var count: Int { get }
    public mutating func append<V: Hashable>(_ value: V)
    public mutating func removeLast()
    public mutating func removeLast(_ k: Int)
}
```

Phase 1 can omit codable restoration. Phase 2 should add CodableRepresentation if practical.

### NavigationLink

```swift
public struct NavigationLink<Label: View, Destination: View>: View
```

MVP overloads:

```swift
public init<P: Hashable>(
    value: P?,
    @ViewBuilder label: () -> Label
) where Destination == NeverOrEmptyDestination

public init<P: Hashable>(
    _ title: String,
    value: P?
) where Label == Text, Destination == NeverOrEmptyDestination

public init(
    @ViewBuilder destination: () -> Destination,
    @ViewBuilder label: () -> Label
)

public init(
    _ title: String,
    @ViewBuilder destination: () -> Destination
) where Label == Text
```

Exact generic shape can differ internally if Swift constraints require it, but public signatures should stay as close to SwiftUI as feasible.

Terminal behavior:

- Renders as a focusable row/action.
- Activation pushes either a value or an explicit destination view.
- `nil` value disables the link, matching SwiftUI behavior.
- Disabled links must not register focus.

### navigationDestination(for:destination:)

```swift
extension View {
    public func navigationDestination<D, C>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View where D: Hashable, C: View
}
```

Behavior:

- Registers a destination builder during semantic collection.
- Does not affect drawing directly.
- Multiple destination types are allowed.
- Nearest/most-local destination should win if duplicate registrations exist, matching SwiftUI spirit.
- Document that it should not be placed inside lazy containers.

### Later: binding destinations

After core stack is stable:

```swift
public func navigationDestination<V: View>(
    isPresented: Binding<Bool>,
    @ViewBuilder destination: () -> V
) -> some View

public func navigationDestination<D, C>(
    item: Binding<D?>,
    @ViewBuilder destination: @escaping (D) -> C
) -> some View where D: Hashable, C: View
```

These should use the same presentation coordinator machinery, not separate ad-hoc logic.

## Implementation phases

### Phase 0 — Tests and architecture scaffolding

Deliverables:

- Add this plan to docs.
- Add focused architecture tests where possible before code changes.
- Identify all render-time side-effect registrations:
  - focus registration
  - key handlers
  - status bar items
  - app header
  - modal/alert registration
  - lifecycle hooks
  - preferences

Recommended files to inspect:

- `Sources/TUIkitView/Rendering/Renderable.swift`
- `Sources/TUIkitView/Rendering/RenderContext.swift`
- `Sources/TUIkitCore/Environment/EnvironmentKey.swift`
- `Sources/TUIkit/Environment/Preferences.swift`
- `Sources/TUIkit/Modifiers/KeyPressModifier.swift`
- `Sources/TUIkit/Focus/`
- `Sources/TUIkit/StatusBar/`
- `Sources/TUIkit/Modifiers/ModalPresentationModifier.swift`
- `Sources/TUIkit/Modifiers/AlertPresentationModifier.swift`

### Phase 1 — Add evaluation phase support

Deliverables:

- Add `ViewEvaluationPhase`.
- Add phase to `RenderContext` with default `.render`.
- Add helpers like `context.withPhase(.semanticCollection)`.
- Update obvious side-effecting code to no-op or collect only in appropriate phase.

Acceptance criteria:

- Existing tests pass.
- Existing visible rendering behavior remains unchanged.
- A semantic collection pass can evaluate a tree without live key/focus/status leakage.

### Phase 2 — Navigation registries and environment

Deliverables:

- `NavigationDestinationRegistry`.
- `NavigationCoordinator` or navigation environment value.
- Environment accessors for active navigation coordinator/registry.
- Modifier for `.navigationDestination(for:)` that registers in semantic collection.

Acceptance criteria:

- Unit tests can register and resolve destinations by type.
- Duplicate destination behavior is deterministic and documented.

### Phase 3 — NavigationPath

Deliverables:

- Public `NavigationPath` MVP.
- Type-erased hashable storage.
- Append/remove/count/isEmpty.
- Tests for homogeneous and heterogeneous values.

Acceptance criteria:

- Path can store different hashable route types.
- Path can remove/popup safely.
- Root stack behavior never requires removing root from path.

### Phase 4 — NavigationStack MVP

Deliverables:

- Public `NavigationStack` with unmanaged and bound-path initializers.
- Semantic pass over root to collect destinations.
- Visible render pass for root or resolved destination.
- Escape key pops when non-empty and bubbles at root.

Acceptance criteria:

- Empty path renders root.
- Non-empty path renders destination for top element.
- Programmatically setting path deep-links to destination.
- Escape removes exactly one path element.
- Escape at root is not consumed.
- Hidden root controls do not receive live key/focus registrations while a destination is visible.

### Phase 5 — NavigationLink MVP

Deliverables:

- Value-based `NavigationLink`.
- Text convenience initializer.
- Optional value disables link.
- Direct destination link if feasible in this phase; otherwise phase 6.

Acceptance criteria:

- Focus + Enter activates link.
- Activation appends to bound path.
- Disabled/nil link is inert and not focusable.
- Label modifiers/environment propagate.

### Phase 6 — Direct destination links

Deliverables:

- `NavigationLink(destination:label:)` support.
- Internal route representation for explicit `AnyView` destinations.

Acceptance criteria:

- Direct destination links work without `.navigationDestination(for:)`.
- Back returns to previous screen.
- Explicit destination view state identity is stable enough for normal usage.

### Phase 7 — Example app migration

Deliverables:

- Replace manual `currentPage` router with `NavigationStack(path:)`.
- Add `DemoRoute: Hashable`.
- Convert menu rows to `NavigationLink(value:)` where possible.
- Keep keyboard shortcuts working from menu.
- Keep `Esc` back behavior.

Example target shape:

```swift
enum DemoRoute: Hashable {
    case textStyles
    case colors
    case containers
    case overlays
    case layout
    case buttons
    case toggles
    case textFields
    case secureFields
    case radioButtons
    case spinners
    case lists
    case tables
    case sliders
    case steppers
    case splitView
    case dogfoodWorkflow
    case imageFile
    case imageURL
}

struct ContentView: View {
    @State private var path: [DemoRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuPage()
                .navigationDestination(for: DemoRoute.self) { route in
                    switch route {
                    case .textStyles: TextStylesPage()
                    case .colors: ColorsPage()
                    case .containers: ContainersPage()
                    // etc.
                    }
                }
        }
    }
}
```

Acceptance criteria:

- Main menu still works with arrows + Enter.
- Shortcut keys still navigate from menu.
- Subpages do not accidentally respond to menu shortcuts.
- Escape returns to menu from subpages.
- App exits or bubbles Escape from root as before.

### Phase 8 — Presentation system for sheets/modals/alerts

Deliverables:

- General `PresentationRegistry` and `PresentationCoordinator`.
- Migrate existing `.modal` and `.alert` modifiers onto this architecture.
- Add SwiftUI-like `.sheet(isPresented:)`.
- Ensure topmost presentation controls input/focus.

Acceptance criteria:

- A sheet can be declared on root and presented over a navigation destination.
- Hidden/background controls are inert while modal presentation is active.
- Escape dismisses the topmost dismissible presentation.
- Status bar reflects topmost active context.

### Phase 9 — Polish and docs

Deliverables:

- `.navigationTitle` integration with stack header/breadcrumb/status.
- DocC article: NavigationStack.
- README/example update.
- Performance guide update if semantic pass has measurable cost.

Acceptance criteria:

- Public docs show common patterns.
- Example app demonstrates stack, deep link, and back behavior.
- Tests cover regressions.

## Testing checklist

Use Swift Testing. Add tests near existing relevant suites, mirroring source area.

Required test categories:

- `NavigationPathTests`
  - empty path
  - append one value
  - append heterogeneous values
  - remove last
  - remove multiple
  - remove over-count clamps or traps according to documented behavior

- `NavigationDestinationRegistryTests`
  - register route type
  - resolve matching route
  - no match returns nil/fallback
  - multiple types
  - duplicate registration precedence

- `NavigationStackTests`
  - root render
  - destination render
  - deep-link path render
  - missing destination fallback
  - Escape pop
  - Escape bubbles at root
  - semantic collection does not leak key handlers
  - semantic collection does not leak focus candidates

- `NavigationLinkTests`
  - label renders
  - focus registration only when enabled
  - Enter pushes value
  - nil value disabled
  - direct destination link pushes explicit view

- Example-level tests where practical
  - menu route mapping
  - back behavior

## Performance notes

Semantic collection adds a pass. Keep it cheap:

- Collect metadata, do not perform full expensive drawing where possible.
- Avoid running image loading or heavy render work in semantic phase.
- Cache destination registries by structural identity when the root subtree and relevant environment are unchanged.
- Invalidate semantic cache when state/environment used by destination modifiers changes.
- Prefer structural identity (`context.identity.path`) for stable graph keys.

Initial implementation may use body evaluation plus phase guards, then optimize after correctness.

## Design principles

- Match SwiftUI public API names, parameter order, and builder shapes where terminal constraints allow.
- Keep public controls as real `View`s with real `body`; private core views may remain renderable leaves.
- Do not introduce global singletons for navigation state.
- Route state through bindings, environment, coordinators, or explicit dependencies.
- Hidden views must not affect live input/focus/status.
- Topmost presentation owns input.
- Root view cannot be popped.
- Color/styling is secondary to predictable keyboard-first behavior.

## Immediate next steps after context reset

1. Read `AGENTS.md` and this document.
2. Inspect `RenderContext`, `Renderable.renderToBuffer`, focus registration, key handlers, status bar modifiers, and modal/alert modifiers.
3. Implement `ViewEvaluationPhase` in context.
4. Add narrow tests proving semantic-phase key/focus side effects do not leak.
5. Add navigation registry and `.navigationDestination(for:)` collection.
6. Implement `NavigationPath` and `NavigationStack` MVP.
7. Only then migrate example app routing.

## Validation commands

From repository root:

```bash
swift build
swift test --parallel
swift test --filter NavigationPathTests
swift test --filter NavigationStackTests
```

For substantial changes before pushing:

```bash
./scripts/test-linux.sh
```

Mention if Docker/Linux validation could not be run.
