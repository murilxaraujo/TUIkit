# Changelog

All notable changes to TUIkit should be documented in this file.

TUIkit is currently pre-1.0. Breaking changes may occur before a stable release, but they should be recorded here with migration notes.

## Unreleased

### Added

- Added `docs/APIStability.md` to define pre-1.0 API stability, SemVer expectations, module stability, and public API change rules.
- Added `docs/PublicAPIInventory.md` as the starting inventory for public API classification.
- Added `docs/ArchitectureAudit.md` to track `body: Never` / `Renderable` boundary decisions.
- Added `docs/KnownLimitations.md` to document current production-readiness caveats.
- Added `docs/TerminalCompatibility.md` as the starting terminal compatibility matrix and manual validation checklist.
- Added `docs/ConcurrencyAndStateAudit.md` to document unsafe concurrency invariants, global/shared state risks, and runtime-hardening follow-ups.
- Added render invalidation stress tests covering rapid state changes, focus changes, and pulse/cursor timer render requests against context-owned render caches.
- Added `scripts/dump-public-api.sh` to regenerate the public API inventory from source.
- Added production-readiness guides for building a real app, testing, custom components, theming/style, keyboard/focus UX, performance, troubleshooting, supported platforms, SwiftUI parity, and terminal input policy.
- Added GitHub issue templates for bugs, feature requests, and terminal compatibility reports.
- Added `docs/ReleaseProcess.md` to define RC/release validation, documentation generation, and tagging gates.
- Added `SECURITY.md` for vulnerability reporting scope and supported-version expectations.

### Changed

- Linked production-readiness and API-stability documentation from the README and contribution guidance.
- Made `BadgeModifier`, `OverlayModifier`, `ModalPresentationModifier`, `ListRowSeparatorModifier`, `KeyPressModifier`, `AlertPresentationModifier`, `DimmedModifier`, `SelectionDisabledModifier`, `FlexibleFrameView`, and `extractBadgeValue(from:)` internal implementation details; app-facing modifier methods remain public.
- Introduced `TUIRuntimeActor` and `TUIRuntime.runInBackground(priority:operation:)` as the foundation for a SwiftUI-like concurrency model: UI interaction/render coordination stays on the runtime lane while expensive work runs in background tasks.
- Moved lifecycle `.task` execution to detached background tasks so view tasks do not inherit and freeze the interaction loop.
- Replaced `PulseTimer` and `CursorTimer` `DispatchSourceTimer` usage with structured Swift concurrency tasks and locked shared timer state.
- Added locking to `StateStorage`, `StateBox`, and `RenderCache` so background task results can safely publish through state and invalidate render cache entries.
- Changed `TUIContext` to own a fresh `RenderCache` by default and wire `StateStorage`/`StateBox` invalidation to that context-owned cache instead of sharing `RenderCache.shared` across app sessions.
- Added per-context render performance snapshots and surfaced live FPS in the example app header next to OS/architecture info.
- Made `StorageDefaults.backend` a synchronized process default while preserving source-compatible get/set access and existing `@AppStorage` backend capture behavior.
- Added lifecycle/concurrency stress coverage for rapid `.task` appear/disappear cancellation and `TUIContext.reset()` task cleanup.
- Added a production-style dogfood workflow page to the example app covering list navigation, forms, validation state, actions, and contextual status hints.
- Expanded the Makefile with build, test, lint, documentation, and release-checklist targets.
- Updated installation guidance to prefer a tagged release over depending on `main`.
- Updated the project template to generate an app with explicit route state, stable focus IDs, status bar hints, Swift 6.0, and macOS 14 alignment.

### Deprecated

- Nothing yet.

### Removed

- Nothing yet.

### Fixed

- Fixed raw-mode Ctrl+C handling so it exits through the normal app cleanup path before focused controls or custom handlers can consume it.
- Stopped the cursor animation timer explicitly during app shutdown cleanup.

### Migration Notes

- None.
