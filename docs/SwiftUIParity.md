# SwiftUI Parity Notes

TUIkit intentionally follows SwiftUI naming and composition where terminal constraints allow. This document records the current release-candidate interpretation for public API parity and known deviations.

## Parity rules

- Public controls should be `View` values with `body: some View`.
- Caller-supplied content should use `@ViewBuilder` closures where SwiftUI would.
- Bindings should use SwiftUI-style labels such as `isOn`, `selection`, and `text`.
- Styling should prefer modifiers and style protocols over terminal-specific initializer parameters.
- TUI-only behavior should be documented as a terminal constraint, not an accidental API shape.

## Intentional terminal-specific deviations

| Area | Deviation | Rationale |
| --- | --- | --- |
| `App` / `WindowGroup` | A single terminal window is the practical runtime target. | Terminals do not expose SwiftUI's multi-window scene model. |
| `StatusBar` | TUIkit provides status-bar shortcut items. | Keyboard discoverability is essential in terminal apps and has no direct SwiftUI equivalent. |
| Focus IDs | TUIkit exposes explicit focus IDs and focus sections for terminal navigation. | Terminals are keyboard-first and need deterministic focus traversal. |
| Key handling | `KeyEvent` and terminal-specific keys are first-class. | Terminal apps need direct access to escape sequences, function keys, and modifier combinations. |
| Rendering primitives | Some low-level primitives render directly to frame buffers. | ANSI buffers and terminal dimensions require explicit handling below public compositional views. |
| Colors/palettes | Phosphor/system palettes model terminal themes. | Terminal color capability and theme contrast differ from GUI color spaces. |

## Current RC audit scope

The architecture audit confirms public controls no longer expose accidental `body: Never` / `fatalError()` rendering paths except documented primitive boundaries. Remaining parity work before 1.0 should focus on exact initializer labels, overload completeness, and DocC examples for each SwiftUI-like control.

## Change policy

If a future API intentionally differs from SwiftUI, update this document and include a migration or rationale note in `CHANGELOG.md`.
