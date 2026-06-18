# TUIkit Production Readiness Plan

This plan tracks the work needed to move TUIkit from a work-in-progress framework to a first-class TUI framework suitable for production applications.

## Goal

TUIkit should become a stable, documented, tested, cross-platform Swift framework for building high-quality terminal user interfaces with SwiftUI-like ergonomics.

A production-ready TUIkit should provide:

- A stable public API with clear versioning and migration guarantees.
- Reliable terminal behavior across macOS, Linux, common terminal emulators, and multiplexers.
- Strong keyboard-first interaction patterns, focus behavior, and visual feedback.
- Safe state, rendering, lifecycle, and concurrency behavior.
- Practical documentation, examples, templates, and testing guidance for real app teams.
- Repeatable release engineering with tagged versions, changelogs, and compatibility notes.

## Current baseline

Observed from the repository overview:

- Swift 6 package with macOS and Linux support intent.
- Modular targets: `TUIkitCore`, `TUIkitStyling`, `TUIkitView`, `TUIkitImage`, and `TUIkit`.
- SwiftUI-like primitives: `View`, `@ViewBuilder`, `@State`, `@Environment`, `App`, scenes, layout, and modifiers.
- Interactive controls: buttons, toggles, text fields, secure fields, sliders, steppers, menus, lists, tables, split views, alerts, dialogs, progress, spinners, and notifications.
- ANSI rendering pipeline with terminal raw mode, frame buffers, diff writing, and render caching.
- Focus and keyboard dispatch system.
- Theming, palettes, colors, borders, and i18n support.
- DocC documentation and example app.
- CI for macOS and Linux with lint, build, and tests.
- Local test run passed: `swift test --parallel` with 1170 tests in 158 suites.

## Definition of production-ready

TUIkit is ready for production adoption when the following are true:

1. Public APIs are intentionally designed, documented, and governed by SemVer.
2. Existing public APIs have a deprecation and migration path instead of arbitrary breakage.
3. Terminal setup, raw mode, alternate screen, signals, resize handling, and cleanup are reliable.
4. Keyboard navigation and focus behavior are predictable, testable, and documented.
5. Rendering is correct under narrow terminals, Unicode text, ANSI styling, resizing, and large data sets.
6. Shared state, global services, and concurrency boundaries have documented invariants and tests.
7. macOS and Linux CI remain green, with an explicit terminal compatibility matrix for manual or automated validation.
8. Documentation enables a developer to build, test, theme, package, and maintain a real TUI app.
9. A realistic dogfood application exercises the framework beyond the component gallery.
10. Releases are tagged, changelogged, and consumable by downstream packages without depending on `main`.

## Workstreams

### 1. Public API stabilization

Objective: establish a trustworthy API surface for app developers.

Tasks:

- [x] Inventory all `public` declarations across framework targets. See [Public API Inventory](PublicAPIInventory.md).
- [x] Classify each public symbol as stable, experimental, internal-leak, or deprecated candidate. Initial classification is conservative and should be reviewed.
- [x] Decide whether submodules are intended for public direct import or only through `TUIkit`. See [API Stability Policy](APIStability.md).
- [ ] Add documentation comments to stable public APIs.
- [x] Add an API stability policy to README or DocC. See [API Stability Policy](APIStability.md).
- [x] Introduce a changelog and release-note process. See `../CHANGELOG.md`.
- [x] Define SemVer expectations for `0.x`, beta, and eventual `1.0`.
- [x] Add an API diff/check step if practical. See `../scripts/dump-public-api.sh`.

Acceptance criteria:

- [x] There is a documented public API policy.
- [x] New breaking changes require explicit migration notes.
- [x] Stable APIs are distinguishable from experimental APIs.

### 2. Architecture and SwiftUI parity audit

Objective: align implementation with the framework's stated architecture rules.

Tasks:

- [x] Audit public controls and modifiers for `body: Never` and `fatalError()` rendering paths. Initial pass recorded in [Architecture Audit](ArchitectureAudit.md).
- [ ] Confirm which `Renderable` uses are acceptable primitives/private cores and which should become compositional public views. Initial implementation-only wrappers were made internal; remaining cases are queued in the audit.
- [ ] Verify SwiftUI-equivalent APIs match SwiftUI naming, parameter order, bindings, and `@ViewBuilder` shapes where practical.
- [ ] Document terminal-specific API deviations and rationale.
- [ ] Audit modifier and environment propagation through containers and controls.
- [ ] Add regression tests for any fixed propagation or compositional behavior.

Initial files worth reviewing:

- `Sources/TUIkit/Modifiers/BadgeModifier.swift`
- `Sources/TUIkit/Modifiers/OverlayModifier.swift`
- `Sources/TUIkit/Modifiers/ModalPresentationModifier.swift`
- `Sources/TUIkit/Modifiers/ListRowSeparatorModifier.swift`
- `Sources/TUIkit/AppHeader/AppHeader.swift`

Acceptance criteria:

- [ ] Public controls either compose real views or have a documented primitive exception.
- [ ] SwiftUI-like APIs have explicit parity notes.
- [ ] Modifier/environment propagation is covered by tests for major containers.

### 3. State, lifecycle, and concurrency hardening

Objective: make state mutation, rendering, tasks, and shared services safe and predictable.

Tasks:

- [ ] Audit uses of `@unchecked Sendable` and document invariants for each.
- [ ] Audit uses of `nonisolated(unsafe)` and document why each is safe.
- [ ] Review `AppState.shared`, `RenderCache.shared`, and `AppStorage.backend` against the “no singletons for state” principle.
- [ ] Move global/shared services behind environment or explicit lifecycle ownership where possible.
- [ ] Add stress tests for rapid state changes, focus changes, timers, and render invalidation.
- [ ] Add lifecycle tests for `.task()`, cancellation, disappearance, and shutdown cleanup.
- [ ] Review signal handling for async-signal-safety and minimal side effects.

Acceptance criteria:

- [ ] Every unsafe concurrency annotation has a written invariant.
- [ ] Long-running app scenarios do not leak tasks or stale state.
- [ ] Global mutable state is removed, isolated, or explicitly justified.

### 4. Terminal reliability and compatibility

Objective: prove TUIkit behaves well in real terminals.

Tasks:

- [ ] Create a terminal compatibility matrix.
- [ ] Validate macOS Terminal, iTerm2, Ghostty, WezTerm, Alacritty, Kitty, VS Code terminal, tmux, screen, and Linux console where practical.
- [ ] Test alternate screen enter/exit behavior.
- [ ] Test raw mode restoration on normal quit, Ctrl-C, thrown errors, and crashes where possible.
- [ ] Test SIGWINCH resize behavior under rapid resizing.
- [ ] Test Unicode width behavior, emoji, combining marks, and CJK wide characters.
- [ ] Test color fallback behavior for monochrome, 8-color, 256-color, and true-color terminals.
- [ ] Decide and document bracketed paste support.
- [ ] Decide and document mouse support policy.

Acceptance criteria:

- [ ] A compatibility matrix exists and is kept with release notes.
- [ ] Terminal cleanup is reliable in normal and interrupted exits.
- [ ] Known terminal limitations are documented.

### 5. Keyboard, focus, and UX quality

Objective: make keyboard-first terminal interaction feel first-class.

Tasks:

- [ ] Document focus behavior and shortcut conventions for app authors.
- [ ] Audit default focus IDs and repeated row identity for dynamic collections.
- [ ] Ensure disabled controls do not register focus targets.
- [ ] Verify visible focus states are distinct from selected states.
- [ ] Review status bar shortcut discoverability.
- [ ] Add examples for list navigation, forms, modals, command palettes, and split views.
- [ ] Add tests for focus order, disabled focus exclusion, modal focus containment, and section navigation.
- [ ] Review empty, loading, error, success, disabled, selected, and focused states for built-in components.

Acceptance criteria:

- [ ] Core controls have predictable keyboard behavior documented and tested.
- [ ] Example app demonstrates production-grade focus and shortcut patterns.
- [ ] Built-in components remain usable in monochrome and narrow terminals.

### 6. Rendering performance and scalability

Objective: understand and improve behavior under production-sized workloads.

Tasks:

- [ ] Add benchmark or performance test scenarios for large lists and tables.
- [ ] Measure render cost for rapid input and frequent state updates.
- [ ] Measure memory growth over long-running sessions.
- [ ] Stress test render cache invalidation with dynamic view trees.
- [ ] Document when to use lazy stacks, lists, tables, and `.equatable()`.
- [ ] Optimize hot paths only after measurement.

Acceptance criteria:

- [ ] Performance baselines are recorded.
- [ ] Large-data guidance exists for app developers.
- [ ] No known unbounded memory growth in normal long-running app scenarios.

### 7. Documentation and developer experience

Objective: make TUIkit approachable for production app teams.

Tasks:

- [ ] Add a “Build a Real App” tutorial.
- [ ] Add a testing guide for TUI apps and framework components.
- [ ] Add a custom component guide.
- [ ] Add a theming and style guide.
- [ ] Add a keyboard and focus UX guide.
- [ ] Add a known limitations page.
- [ ] Add a troubleshooting page for terminal issues.
- [ ] Update the project template to reflect recommended app architecture.
- [ ] Ensure README, DocC, and examples agree.

Acceptance criteria:

- [ ] A new developer can create, test, theme, and ship a small app from docs alone.
- [ ] Common terminal and rendering problems have troubleshooting entries.
- [ ] Public examples avoid anti-patterns such as hidden global state.

### 8. Dogfood applications and examples

Objective: validate the framework against realistic app needs.

Tasks:

- [ ] Expand `TUIkitExample` beyond a component gallery into realistic flows.
- [ ] Add or build a separate dogfood app with routing/navigation, forms, persistence, async loading, tables, modals, notifications, and long-running progress.
- [ ] Track API friction discovered during dogfooding as issues or backlog items.
- [ ] Use dogfood scenarios as regression tests where possible.

Acceptance criteria:

- [ ] At least one realistic app exercises the major framework systems together.
- [ ] Dogfood findings are converted into prioritized framework work.

### 9. Release engineering and governance

Objective: make TUIkit consumable and maintainable as a dependency.

Tasks:

- [ ] Create `CHANGELOG.md`.
- [ ] Create or update issue templates.
- [ ] Add a security policy if accepting vulnerability reports.
- [ ] Define supported Swift versions and platform versions.
- [ ] Prefer tagged releases in installation docs over `branch: "main"` once release flow is ready.
- [ ] Tie DocC publishing to releases or clearly label docs by version.
- [ ] Add release checklist with build, test, lint, docs, examples, and compatibility notes.

Acceptance criteria:

- [ ] Consumers can depend on tagged versions.
- [ ] Releases include migration notes and known limitations.
- [ ] Documentation matches released APIs.

## Milestones

### Milestone 0: Baseline and backlog

- [ ] Commit this plan.
- [ ] Create tracking issues or backlog entries for each workstream.
- [ ] Record current test, lint, build, and documentation status.
- [ ] Add a `Known Limitations` draft.

Exit criteria:

- [ ] Team has an agreed production-readiness checklist and prioritized first tasks.

### Milestone 1: Beta-quality API discipline

- [ ] Public API inventory complete.
- [ ] SemVer and deprecation policy documented.
- [ ] Changelog created.
- [ ] Public `body: Never` / `Renderable` audit complete.
- [ ] Initial known limitations documented.

Exit criteria:

- [ ] Framework can publish intentional beta releases with migration notes.

### Milestone 2: Runtime hardening

- [ ] Concurrency and shared state audit complete.
- [ ] Terminal compatibility matrix started.
- [ ] Raw mode and alternate-screen cleanup validated.
- [ ] Resize, focus, and lifecycle stress tests added.

Exit criteria:

- [ ] Runtime behavior is reliable enough for internal production pilots.

### Milestone 3: Developer experience and dogfood

- [ ] Real app tutorial complete.
- [ ] Testing guide complete.
- [ ] Dogfood app or realistic example complete.
- [ ] Performance baselines recorded.

Exit criteria:

- [ ] External developers can build a practical TUI app without source-diving.

### Milestone 4: 1.0 readiness

- [ ] Stable API candidate frozen.
- [ ] Compatibility matrix validated for target terminals.
- [ ] Docs and examples aligned with stable APIs.
- [ ] Tagged release process proven through at least one beta/RC.
- [ ] Known limitations are acceptable and documented.

Exit criteria:

- [ ] TUIkit can remove or soften the README production warning and publish a stable release candidate.

## Immediate next actions

Recommended starting order:

1. Create backlog issues from this document.
2. Add `CHANGELOG.md` and a short API stability policy.
3. Run the public API inventory.
4. Audit `body: Never` and `Renderable` usage against the architecture rules.
5. Draft `docs/KnownLimitations.md`.
6. Start the terminal compatibility matrix.

## Validation commands

Use these commands while working through the plan:

```bash
swift build
swift test --parallel
swiftlint
swift package --allow-writing-to-directory docc-output \
  generate-documentation \
  --target TUIkit \
  --output-path docc-output \
  --transform-for-static-hosting
```

Run Linux validation before major production-readiness claims:

```bash
./scripts/test-linux.sh
```
