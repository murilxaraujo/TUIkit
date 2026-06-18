# API Stability Policy

TUIkit is currently pre-1.0. The framework is usable for experimentation and dogfooding, but its public API is not yet frozen for production use.

This policy defines how public API changes should be handled while TUIkit moves toward a stable release.

## Stability levels

Every public API should be understood as one of the following:

| Level | Meaning |
|-------|---------|
| Stable candidate | Intended to become part of the 1.0 API after documentation, parity, and compatibility review. Breaking changes should be rare and recorded. |
| Experimental | Public for evaluation or advanced use, but may change before 1.0. Use in production code should be isolated. |
| Internal-leak candidate | Public primarily because of current package/module boundaries. Should be made internal, hidden, or explicitly promoted before 1.0. |
| Deprecated candidate | Public API that appears superseded or misaligned and needs a migration path before removal. |

## SemVer expectations

### Before 1.0

- Minor versions may contain breaking changes.
- Breaking changes must be listed in `CHANGELOG.md` under **Migration Notes**.
- Stable-candidate APIs should be deprecated before removal where practical.
- Experimental APIs may change faster, but changes still need changelog entries.

### 1.0 and later

- Public stable APIs follow semantic versioning.
- Breaking changes require a major version bump.
- Deprecated APIs should remain available for at least one minor release cycle unless keeping them creates a correctness or security risk.
- Migration guidance is required for removals or behavior changes.

## Module stability

`TUIkit` is the primary app-author API surface and should receive the strongest stability guarantees.

Lower-level modules are public SwiftPM products but should be treated as advanced or experimental until reviewed:

| Module | Stability intent |
|--------|------------------|
| `TUIkit` | Primary app-facing API. High-level views, app lifecycle, state wrappers, focus, styles, and modifiers should become stable candidates. |
| `TUIkitStyling` | Styling extension points. Core color/style values are stable candidates; theme registries/managers need lifecycle review. |
| `TUIkitView` | Declarative view engine. `View`, `ViewBuilder`, `State`, `Binding`, and environment wrappers are stable candidates; rendering internals need boundary review. |
| `TUIkitCore` | Low-level rendering/input/environment primitives. Public access is advanced/experimental until API boundaries are finalized. |
| `TUIkitImage` | Image loading and ASCII conversion. Experimental until terminal/image capability policy and performance are finalized. |
| `CSTBImage` | Implementation support module, not intended as an app-facing stable API. |

## Public API change rules

Before adding, changing, or removing public API:

1. Check whether there is an equivalent SwiftUI API and mirror its spelling, parameter order, bindings, and builder closures where terminal constraints allow.
2. Decide the stability level for the symbol.
3. Add documentation comments for stable-candidate APIs.
4. Add tests for behavior, modifier propagation, environment propagation, and disabled/focus behavior where relevant.
5. Update `CHANGELOG.md`.
6. Add migration notes for breaking changes.
7. Document terminal-specific deviations from SwiftUI.

## Experimental API marking

Until a dedicated annotation convention exists, experimental APIs should be called out in documentation comments with:

```swift
/// Experimental: this API may change before TUIkit 1.0.
```

For larger areas, document the experimental status in DocC or the relevant guide.

## Deprecation guidance

Use Swift's `@available(*, deprecated, message:)` where a replacement exists:

```swift
@available(*, deprecated, message: "Use NewView.init(value:) instead.")
```

Deprecation messages should include the preferred replacement or migration action.

## Release notes and changelog

All public API changes should be recorded in `CHANGELOG.md` under one of:

- Added
- Changed
- Deprecated
- Removed
- Fixed
- Migration Notes

Migration notes are required when source changes are needed by downstream apps.

## API inventory

The current inventory lives in [Public API Inventory](PublicAPIInventory.md). Refresh it with:

```bash
./scripts/dump-public-api.sh
```
