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
| Public implementation wrappers | `BadgeModifier`, `OverlayModifier`, `ModalPresentationModifier`, `ListRowSeparatorModifier`, `KeyPressModifier`, `AlertPresentationModifier`, `DimmedModifier`, `SelectionDisabledModifier`, `FlexibleFrameView` | Make internal so public API is the extension method, not the render wrapper. |
| Internal terminal-only utilities | `AppHeader` | Keep internal `Renderable`; document as acceptable terminal chrome. |

## Changes made

The following render wrappers were made internal implementation details:

- `BadgeModifier`
- `OverlayModifier`
- `ModalPresentationModifier`
- `ListRowSeparatorModifier`
- `KeyPressModifier`
- `AlertPresentationModifier`
- `DimmedModifier`
- `SelectionDisabledModifier`
- `FlexibleFrameView`
- `extractBadgeValue(from:)`

The public app-facing APIs remain available through extension methods:

- `.badge(_:)`
- `.overlay(alignment:content:)`
- `.modal(isPresented:content:)`
- `.alert(...)`
- `.dimmed()`
- `.selectionDisabled(_:)`
- `.frame(...)`
- `.onKeyPress(...)`
- `.listRowSeparator(_:edges:)`

`BadgeValue`, `Visibility`, `VerticalEdge`, and `FrameDimension` remain public because they are part of app-facing API or observable row/list/layout behavior.

## Rationale

These types are render wrappers, not concepts app authors should construct directly. Keeping them public expands the compatibility surface and conflicts with the public API stabilization goal. Making them internal preserves behavior while clarifying that the public API is the SwiftUI-like modifier method.

Tests use `@testable import TUIkit`, so they can still directly validate internal wrappers where focused rendering coverage is useful.

## Remaining public primitive exceptions

After the cleanup, the remaining `public var body: Never` cases are intentionally public structural or leaf primitives:

| Symbol | File | Decision |
|--------|------|----------|
| `Text` | `Sources/TUIkit/Views/Text.swift` | Keep public leaf primitive; direct terminal text rendering is its core behavior. |
| `Spacer` | `Sources/TUIkit/Views/Spacer.swift` | Keep public leaf/layout primitive. |
| `Divider` | `Sources/TUIkit/Views/Spacer.swift` | Keep public leaf/layout primitive. |
| `ForEach` | `Sources/TUIkit/Views/ForEach.swift` | Keep public structural primitive, matching SwiftUI's structural collection role. It does not render standalone and is consumed by builders/extractors. |
| `EmptyView` | `Sources/TUIkitView/Core/PrimitiveViews.swift` | Keep public structural primitive. |
| `ConditionalView` | `Sources/TUIkitView/Core/PrimitiveViews.swift` | Keep public result-builder structural primitive. |
| `ViewArray` | `Sources/TUIkitView/Core/PrimitiveViews.swift` | Keep public result-builder/collection structural primitive. |
| `AnyView` | `Sources/TUIkitView/Core/PrimitiveViews.swift` | Keep public type-erasure structural primitive. |
| `Never` view conformance | `Sources/TUIkitView/Core/PrimitiveTypes+View.swift` | Keep public uninhabited helper required by the `View.Body == Never` model. |
| `TupleView` | `Sources/TUIkitView/Core/TupleViews.swift` | Keep public result-builder structural primitive. |
| `ModifiedView` | `Sources/TUIkitView/Core/ViewModifier.swift` | Keep public structural primitive returned by `.modifier(_:)`. |
| `EquatableView` | `Sources/TUIkitView/Core/EquatableView.swift` | Keep public structural primitive returned by `.equatable()`. |

These types form the framework's primitive/structural rendering model. They are documented exceptions to the “public controls should compose real views” rule because they are not app controls; they are the low-level building blocks that make the compositional model work.

## Follow-up audit queue

The broad public wrapper cleanup for Workstream 2 is complete. Remaining follow-ups move into API stabilization and documentation work:

1. Add or refine DocC/comments for every documented primitive exception above.
2. Review lower-level `TUIkitView` structural types during the public API stabilization pass to decide whether direct import of `TUIkitView` is a supported advanced use case.
3. Prefer public extension-method tests for app-facing APIs; keep `@testable` direct-wrapper tests only where they verify implementation details that cannot be exercised through public API.
4. Continue applying the same rule to new modifiers: public method first, internal render wrapper unless direct construction is an explicit API goal.

## Acceptance status

- [x] Initial `body: Never` / `fatalError()` scan completed.
- [x] Implementation-only public wrappers made internal.
- [x] App-facing modifier methods preserved.
- [x] Public API inventory regenerated.
- [x] Remaining public render wrappers classified and fixed or documented.
- [x] Architecture audit updated with the final primitive exception list.
