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
- Added `scripts/dump-public-api.sh` to regenerate the public API inventory from source.

### Changed

- Linked production-readiness and API-stability documentation from the README and contribution guidance.
- Made `BadgeModifier`, `OverlayModifier`, `ModalPresentationModifier`, `ListRowSeparatorModifier`, `KeyPressModifier`, `AlertPresentationModifier`, `DimmedModifier`, `SelectionDisabledModifier`, `FlexibleFrameView`, and `extractBadgeValue(from:)` internal implementation details; app-facing modifier methods remain public.
- Introduced `TUIRuntimeActor` and `TUIRuntime.runInBackground(priority:operation:)` as the foundation for a SwiftUI-like concurrency model: UI interaction/render coordination stays on the runtime lane while expensive work runs in background tasks.
- Moved lifecycle `.task` execution to detached background tasks so view tasks do not inherit and freeze the interaction loop.
- Replaced `PulseTimer` and `CursorTimer` `DispatchSourceTimer` usage with structured Swift concurrency tasks and locked shared timer state.
- Added locking to `StateStorage`, `StateBox`, and `RenderCache` so background task results can safely publish through state and invalidate render cache entries.

### Deprecated

- Nothing yet.

### Removed

- Nothing yet.

### Fixed

- Fixed raw-mode Ctrl+C handling so it exits through the normal app cleanup path before focused controls or custom handlers can consume it.

### Migration Notes

- None.
