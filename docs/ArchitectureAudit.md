# Architecture Audit: Primitive Rendering and Public View Boundaries

This audit tracks Workstream 2 from the production-readiness plan: aligning TUIkit's implementation with its architecture rule that public app-facing controls should compose real views where practical, while direct `Renderable` implementations remain limited to primitives, private `_*Core` views, and implementation-only wrappers.

## Principle

TUIkit supports two rendering shapes:

1. **Compositional views** expose `body: some View` and are preferred for public app-facing controls.
2. **Primitive/render-core views** expose `body: Never` and conform to `Renderable` when they need direct terminal buffer work.

A `body: Never` implementation is acceptable when the type is one of:

- a leaf primitive, such as `Text`, `Spacer`, or `Divider`;
- a SwiftUI-like structural primitive, such as `TupleView`, `AnyView`, `EmptyView`, or `ModifiedView`;
- a private/internal `_*Core` or modifier wrapper used behind public extension methods;
- a documented terminal-specific exception where composition would obscure behavior or significantly harm correctness/performance.

A `body: Never` implementation is suspicious when the type is a public app-author API that does not need to be named or constructed directly.

## Initial scan

Command used:

```bash
rg -n "body\\s*:\\s*Never|fatalError\\(" Sources/TUIkit Sources/TUIkitView
```

The scan found several categories:

| Category | Examples | Decision |
|----------|----------|----------|
| Leaf primitives | `Text`, `Spacer`, `Divider` | Keep as documented primitive exceptions. |
| Structural view engine primitives | `EmptyView`, `TupleView`, `AnyView`, `ModifiedView`, `EquatableView`, `ForEach` | Keep for now; review as part of lower-level API stabilization. |
| Private/internal render cores | `_ButtonCore`, `_ListCore`, `_TableCore`, `_VStackCore`, `_ImageCore` | Keep; direct rendering is the intended role. |
| Public implementation wrappers | `BadgeModifier`, `OverlayModifier`, `ModalPresentationModifier`, `ListRowSeparatorModifier` | Make internal so public API is the extension method, not the render wrapper. |
| Remaining public modifier wrappers | `KeyPressModifier`, `AlertPresentationModifier`, `DimmedModifier`, `SelectionDisabledModifier`, `FlexibleFrameView` | Leave for follow-up audit to avoid broad source compatibility changes in one step. |
| Internal terminal-only utilities | `AppHeader` | Keep internal `Renderable`; document as acceptable terminal chrome. |

## Changes made in this pass

The following render wrappers were made internal implementation details:

- `BadgeModifier`
- `OverlayModifier`
- `ModalPresentationModifier`
- `ListRowSeparatorModifier`
- `extractBadgeValue(from:)`

The public app-facing APIs remain available through extension methods:

- `.badge(_:)`
- `.overlay(alignment:content:)`
- `.modal(isPresented:content:)`
- `.listRowSeparator(_:edges:)`

`BadgeValue`, `Visibility`, and `VerticalEdge` remain public because they are part of app-facing API or observable row/list behavior.

## Rationale

These types are render wrappers, not concepts app authors should construct directly. Keeping them public expands the compatibility surface and conflicts with the public API stabilization goal. Making them internal preserves behavior while clarifying that the public API is the SwiftUI-like modifier method.

Tests use `@testable import TUIkit`, so they can still directly validate internal wrappers where focused rendering coverage is useful.

## Follow-up audit queue

Review these remaining public `body: Never` or direct-render wrapper types next:

- `Sources/TUIkit/Modifiers/KeyPressModifier.swift`
- `Sources/TUIkit/Modifiers/AlertPresentationModifier.swift`
- `Sources/TUIkit/Modifiers/DimmedModifier.swift`
- `Sources/TUIkit/Modifiers/SelectionDisabledModifier.swift`
- `Sources/TUIkit/Modifiers/FrameModifier.swift` (`FlexibleFrameView`)
- `Sources/TUIkit/Views/ForEach.swift`
- `Sources/TUIkitView/Core/PrimitiveViews.swift`
- `Sources/TUIkitView/Core/TupleViews.swift`
- `Sources/TUIkitView/Core/ViewModifier.swift`
- `Sources/TUIkitView/Core/EquatableView.swift`

For each type, choose one of:

1. Keep public and document it as a primitive/structural exception.
2. Make the render wrapper internal and keep only the extension method public.
3. Split into a public compositional wrapper plus private/internal render core.
4. Replace direct construction tests with public API rendering tests if direct construction is not part of the contract.

## Acceptance status

- [x] Initial `body: Never` / `fatalError()` scan completed.
- [x] First implementation-only public wrappers made internal.
- [x] App-facing modifier methods preserved.
- [x] Public API inventory regenerated.
- [ ] Remaining public render wrappers classified and fixed or documented.
- [ ] Architecture guide updated with the final primitive exception list.
