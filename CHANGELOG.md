# Changelog

All notable changes to TUIkit should be documented in this file.

TUIkit is currently pre-1.0. Breaking changes may occur before a stable release, but they should be recorded here with migration notes.

## Unreleased

### Added

- Added `docs/APIStability.md` to define pre-1.0 API stability, SemVer expectations, module stability, and public API change rules.
- Added `docs/PublicAPIInventory.md` as the starting inventory for public API classification.
- Added `docs/ArchitectureAudit.md` to track `body: Never` / `Renderable` boundary decisions.
- Added `scripts/dump-public-api.sh` to regenerate the public API inventory from source.

### Changed

- Linked production-readiness and API-stability documentation from the README and contribution guidance.
- Made `BadgeModifier`, `OverlayModifier`, `ModalPresentationModifier`, `ListRowSeparatorModifier`, `KeyPressModifier`, `AlertPresentationModifier`, `DimmedModifier`, `SelectionDisabledModifier`, `FlexibleFrameView`, and `extractBadgeValue(from:)` internal implementation details; app-facing modifier methods remain public.

### Deprecated

- Nothing yet.

### Removed

- Nothing yet.

### Fixed

- Nothing yet.

### Migration Notes

- None.
