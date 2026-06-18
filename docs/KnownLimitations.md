# Known Limitations

This page records current production-readiness limitations for TUIkit. It is intentionally conservative: entries here are not necessarily bugs, but they are areas app teams should understand before depending on TUIkit in production.

See also the [Production Readiness Plan](ProductionReadinessPlan.md) and [Terminal Compatibility Matrix](TerminalCompatibility.md).

## Stability status

TUIkit is still pre-1.0. Public API discipline is now documented in the [API Stability Policy](APIStability.md), but the stable API candidate is not frozen yet.

Production consumers should expect:

- breaking changes during `0.x` releases when needed to improve correctness or SwiftUI parity;
- migration notes for intentional public API changes;
- some lower-level module APIs to remain experimental until reviewed.

## Terminal compatibility is not fully validated

The framework targets macOS and Linux and uses ANSI/POSIX terminal behavior, but the full compatibility matrix is still in progress.

Before shipping an app, validate at least:

- your target terminal emulator;
- tmux or screen if your users commonly run inside multiplexers;
- narrow terminal widths;
- terminal resize behavior;
- color and Unicode behavior for your content.

Tracked in [Terminal Compatibility Matrix](TerminalCompatibility.md). Use the [Release Validation Checklist](ReleaseValidationChecklist.md) before making release or production-readiness claims.

## Raw mode and alternate-screen failure modes need more proof

TUIkit configures terminal input/output state for interactive apps. Normal example-app exit paths are expected to restore the terminal, but production-readiness validation still needs broader coverage for:

- thrown startup/runtime errors;
- Ctrl-C and signal-triggered shutdown;
- rapid quit during rendering;
- crashes or forced termination;
- nested terminal sessions or multiplexers.

If the terminal is left in a bad state during development, run:

```bash
stty sane
reset
```

## Unicode width behavior may vary by terminal

TUIkit has ANSI-aware string helpers and wrapping tests, but production validation for all Unicode categories is not complete.

Validate app-specific content that includes:

- emoji and emoji sequences;
- combining marks;
- CJK wide characters;
- zero-width joiners;
- mixed ANSI styling and wide characters.

Terminal fonts, locale, and emulator behavior can affect alignment.

## Color fidelity depends on terminal support

TUIkit supports ANSI colors, 256-color values, and 24-bit RGB colors. Actual output depends on the terminal's color capabilities and theme.

App authors should verify:

- monochrome or low-color fallback readability;
- 8-color and 256-color terminals;
- true-color terminals;
- selected/focused/disabled contrast under each palette.

Do not rely on color alone to communicate critical state.

## Keyboard handling is keyboard-first but policy is still being refined

TUIkit has a focus system, key event dispatcher, status bar shortcuts, and interactive controls. The production UX policy still needs additional documentation and validation for:

- app-level shortcut conventions;
- modal focus containment;
- repeated rows and dynamic collection identity;
- disabled control focus exclusion across all controls;
- discoverability of shortcuts in complex screens.

Existing apps should test focus order and shortcut conflicts in their final UI, not only in isolated components.

## Mouse support is not a production guarantee

Mouse support is not currently documented as a production-ready feature. Apps should be fully usable with the keyboard.

If mouse support is added later, it should be documented as a capability with terminal compatibility notes.

## Bracketed paste policy is undecided

The project has not yet documented a production policy for bracketed paste. Text-entry-heavy apps should validate paste behavior for their target terminals and avoid assuming shell-like paste semantics until this is specified.

## Performance baselines are not yet recorded

TUIkit includes render caching, lazy containers, and a live example-app FPS header for manual observation, but formal production performance baselines are still pending.

Before shipping large-data apps, validate:

- large lists and tables;
- rapid keyboard input;
- frequent state updates;
- whether the example-app FPS header remains live during interaction, resize, and async work;
- long-running sessions;
- memory growth over time.

## Documentation is still being expanded

DocC articles and the README cover many framework areas, but production app teams still need more guides, especially:

- building a realistic app end to end;
- testing TUI apps;
- terminal troubleshooting;
- custom component patterns;
- large-data performance guidance.

## Current recommendation

TUIkit is suitable for experiments, prototypes, internal tools, and early pilots where teams can validate terminal behavior and absorb pre-1.0 API changes.

It is not yet recommended as a general-purpose, stable production dependency until runtime hardening, compatibility validation, documentation, and release processes are further along.
