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
- Repeatable release engineering with tagged versions, changelogs, compatibility notes, and a manual release validation checklist.

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

- [x] Audit public controls and modifiers for `body: Never` and `fatalError()` rendering paths. Recorded in [Architecture Audit](ArchitectureAudit.md).
- [x] Confirm which `Renderable` uses are acceptable primitives/private cores and which should become compositional public views. Implementation-only wrappers were made internal and remaining public primitive exceptions are documented in the audit.
- [x] Verify SwiftUI-equivalent APIs match SwiftUI naming, parameter order, bindings, and `@ViewBuilder` shapes where practical. Current RC notes are in [SwiftUI Parity Notes](SwiftUIParity.md); exact overload completeness remains a 1.0 follow-up.
- [x] Document terminal-specific API deviations and rationale. See [SwiftUI Parity Notes](SwiftUIParity.md).
- [x] Audit modifier and environment propagation through containers and controls. Existing modifier propagation suites cover representative containers and controls.
- [x] Add regression tests for any fixed propagation or compositional behavior. See `ModifierPropagationTests`, presentation modifier tests, and container/control render tests.

Initial files worth reviewing:

- `Sources/TUIkit/Modifiers/BadgeModifier.swift`
- `Sources/TUIkit/Modifiers/OverlayModifier.swift`
- `Sources/TUIkit/Modifiers/ModalPresentationModifier.swift`
- `Sources/TUIkit/Modifiers/ListRowSeparatorModifier.swift`
- `Sources/TUIkit/AppHeader/AppHeader.swift`

Acceptance criteria:

- [x] Public controls either compose real views or have a documented primitive exception.
- [x] SwiftUI-like APIs have explicit parity notes. See [SwiftUI Parity Notes](SwiftUIParity.md).
- [x] Modifier/environment propagation is covered by tests for major containers.

### 3. State, lifecycle, and concurrency hardening

Objective: make state mutation, rendering, tasks, and shared services safe and predictable.

Tasks:

- [x] Audit uses of `@unchecked Sendable` and document invariants for each. See [Concurrency and Shared-State Audit](ConcurrencyAndStateAudit.md).
- [x] Audit uses of `nonisolated(unsafe)` and document why each is safe. See [Concurrency and Shared-State Audit](ConcurrencyAndStateAudit.md).
- [x] Review `AppState.shared`, `RenderCache.shared`, and `AppStorage.backend` against the “no singletons for state” principle. See [Concurrency and Shared-State Audit](ConcurrencyAndStateAudit.md).
- [x] Move first runtime services toward explicit lifecycle/concurrency ownership: `.task` work now runs detached from the interaction loop, timers use structured concurrency, and `StateStorage`/`StateBox`/`RenderCache` are locked for background result publication.
- [ ] Move remaining global/shared services behind environment or explicit lifecycle ownership where possible. `RenderCache.shared` is no longer the default runtime cache; `StorageDefaults.backend` access is synchronized; `NotificationService.current` is the highest-priority remaining follow-up.
- [x] Add stress tests for rapid state changes, focus changes, timers, and render invalidation.
- [x] Surface live example-app render FPS so performance impact can be observed during manual validation.
- [x] Add lifecycle tests for `.task()`, cancellation, disappearance, and shutdown cleanup.
- [x] Review signal handling for async-signal-safety and minimal side effects. `SignalManager` handlers only set file-private flags; cleanup remains in the main loop.

Acceptance criteria:

- [x] Every unsafe concurrency annotation has a written invariant.
- [x] Long-running app scenarios do not leak tasks or stale state at the RC smoke-test level. Stress coverage verifies rapid `.task` cancellation and context reset cleanup; broader leak profiling remains a 1.0 follow-up.
- [x] Global mutable state is removed, isolated, or explicitly justified. Remaining shared services are documented in [Concurrency and Shared-State Audit](ConcurrencyAndStateAudit.md).

### 4. Terminal reliability and compatibility

Objective: prove TUIkit behaves well in real terminals.

Tasks:

- [x] Create a terminal compatibility matrix. See [Terminal Compatibility Matrix](TerminalCompatibility.md).
- [x] Add a release/manual validation checklist covering example app lifecycle, raw mode cleanup, quit shortcuts, resize, FPS, focus/cursor animations, async responsiveness, and terminal/multiplexer matrix. See [Release Validation Checklist](ReleaseValidationChecklist.md).
- [ ] Validate macOS Terminal, iTerm2, Ghostty, WezTerm, Alacritty, Kitty, VS Code terminal, tmux, screen, and Linux console where practical.
- [ ] Test alternate screen enter/exit behavior.
- [ ] Test raw mode restoration on normal quit, Ctrl-C, thrown errors, and crashes where possible.
- [ ] Test SIGWINCH resize behavior under rapid resizing.
- [ ] Test Unicode width behavior, emoji, combining marks, and CJK wide characters.
- [ ] Test color fallback behavior for monochrome, 8-color, 256-color, and true-color terminals.
- [x] Decide and document bracketed paste support. See [Terminal Input Policy](TerminalInputPolicy.md).
- [x] Decide and document mouse support policy. See [Terminal Input Policy](TerminalInputPolicy.md).

Acceptance criteria:

- [x] A compatibility matrix exists and is kept with release notes.
- [ ] Terminal cleanup is reliable in normal and interrupted exits.
- [ ] Known terminal limitations are documented.

### 5. Keyboard, focus, and UX quality

Objective: make keyboard-first terminal interaction feel first-class.

Tasks:

- [x] Document focus behavior and shortcut conventions for app authors. See [Keyboard and Focus Guide](KeyboardFocusGuide.md).
- [x] Audit default focus IDs and repeated row identity for dynamic collections. See [Focus and UX Audit](FocusUXAudit.md).
- [x] Ensure disabled controls do not register focus targets. Core focus-manager behavior is covered by tests and summarized in [Focus and UX Audit](FocusUXAudit.md).
- [x] Verify visible focus states are distinct from selected states. See [Keyboard and Focus Guide](KeyboardFocusGuide.md) and [Focus and UX Audit](FocusUXAudit.md).
- [x] Review status bar shortcut discoverability. The example app now includes contextual status hints and the dogfood workflow documents expected shortcuts.
- [x] Add examples for list navigation, forms, modals, command palettes, and split views. Component demos cover lists/forms/modals/split views, and `TaskWorkflowPage` adds an integrated realistic flow.
- [x] Add tests for focus order, disabled focus exclusion, modal focus containment, and section navigation. Existing focus-manager, focus-section, navigation split-view, control handler, and modifier tests cover the RC baseline; modal containment remains a 1.0 follow-up.
- [x] Review empty, loading, error, success, disabled, selected, and focused states for built-in components. See [Focus and UX Audit](FocusUXAudit.md).

Acceptance criteria:

- [x] Core controls have predictable keyboard behavior documented and tested.
- [x] Example app demonstrates production-grade focus and shortcut patterns.
- [x] Built-in components remain usable in monochrome and narrow terminals by design guidance; manual terminal validation remains required before broad compatibility claims.

### 6. Rendering performance and scalability

Objective: understand and improve behavior under production-sized workloads.

Tasks:

- [x] Add benchmark or performance test scenarios for large lists and tables. Existing render/performance suites cover hierarchy size, `ForEach`, strings, and render performance smoke baselines.
- [x] Measure render cost for rapid input and frequent state updates. Existing stress/performance tests cover rapid invalidation and render monitor snapshots.
- [ ] Measure memory growth over long-running sessions.
- [x] Stress test render cache invalidation with dynamic view trees. See `RenderInvalidationStressTests` and render cache tests.
- [x] Document when to use lazy stacks, lists, tables, and `.equatable()`. See [Performance Guide](PerformanceGuide.md).
- [ ] Optimize hot paths only after measurement.

Acceptance criteria:

- [x] Performance baselines are recorded in CI-safe smoke suites and documented in [Performance Guide](PerformanceGuide.md).
- [x] Large-data guidance exists for app developers. See [Performance Guide](PerformanceGuide.md).
- [ ] No known unbounded memory growth in normal long-running app scenarios.

### 7. Documentation and developer experience

Objective: make TUIkit approachable for production app teams.

Tasks:

- [x] Add a “Build a Real App” tutorial. See [Build a Real App with TUIkit](BuildARealAppTutorial.md).
- [x] Add a testing guide for TUI apps and framework components. See [Testing Guide](TestingGuide.md).
- [x] Add a custom component guide. See [Custom Component Guide](CustomComponentGuide.md).
- [x] Add a theming and style guide. See [Theming and Style Guide](ThemingAndStyleGuide.md).
- [x] Add a keyboard and focus UX guide. See [Keyboard and Focus Guide](KeyboardFocusGuide.md).
- [x] Add a known limitations page. See [Known Limitations](KnownLimitations.md).
- [x] Add a troubleshooting page for terminal issues. See [Troubleshooting](Troubleshooting.md).
- [x] Update the project template to reflect recommended app architecture.
- [x] Ensure README, DocC, and examples agree. README now links the production-readiness docs and examples include an integrated dogfood workflow.

Acceptance criteria:

- [ ] A new developer can create, test, theme, and ship a small app from docs alone.
- [x] Common terminal and rendering problems have troubleshooting entries. See [Troubleshooting](Troubleshooting.md).
- [x] Public examples avoid anti-patterns such as hidden global state.

### 8. Dogfood applications and examples

Objective: validate the framework against realistic app needs.

Tasks:

- [x] Expand `TUIkitExample` beyond a component gallery into realistic flows. `TaskWorkflowPage` combines list navigation, forms, validation state, actions, and status hints.
- [x] Add or build a separate dogfood app with routing/navigation, forms, persistence, async loading, tables, modals, notifications, and long-running progress. `TaskWorkflowPage` covers the RC dogfood baseline; deeper async/live data scenarios remain a 1.0 follow-up.
- [x] Track API friction discovered during dogfooding as issues or backlog items. Current findings are reflected in [Focus and UX Audit](FocusUXAudit.md) and [Known Limitations](KnownLimitations.md).
- [ ] Use dogfood scenarios as regression tests where possible. Example builds now compile the workflow; direct render tests for the executable target remain open.

Acceptance criteria:

- [x] At least one realistic app exercises the major framework systems together.
- [x] Dogfood findings are converted into prioritized framework work.

### 9. Release engineering and governance

Objective: make TUIkit consumable and maintainable as a dependency.

Tasks:

- [x] Create `CHANGELOG.md`.
- [x] Create or update issue templates.
- [x] Add a security policy if accepting vulnerability reports. See `../SECURITY.md`.
- [x] Define supported Swift versions and platform versions. See [Supported Platforms](SupportedPlatforms.md).
- [x] Prefer tagged releases in installation docs over `branch: "main"` once release flow is ready.
- [x] Tie DocC publishing to releases or clearly label docs by version. See [Release Process](ReleaseProcess.md).
- [x] Add release checklist with build, test, lint, example-app lifecycle, terminal cleanup, FPS, and compatibility notes. See [Release Validation Checklist](ReleaseValidationChecklist.md).

Acceptance criteria:

- [x] Consumers can depend on tagged versions.
- [x] Releases include migration notes and known limitations.
- [x] Documentation matches released APIs, with DocC generation included in the release process.

## Milestones

### Milestone 0: Baseline and backlog

- [x] Commit this plan.
- [ ] Create tracking issues or backlog entries for each workstream.
- [x] Record current test, lint, build, and documentation status.
- [x] Add a `Known Limitations` draft.

Exit criteria:

- [ ] Team has an agreed production-readiness checklist and prioritized first tasks.

### Milestone 1: Beta-quality API discipline

- [x] Public API inventory complete.
- [x] SemVer and deprecation policy documented.
- [x] Changelog created.
- [x] Public `body: Never` / `Renderable` audit complete.
- [x] Initial known limitations documented.

Exit criteria:

- [ ] Framework can publish intentional beta releases with migration notes.

### Milestone 2: Runtime hardening

- [x] Concurrency and shared state audit complete.
- [x] Terminal compatibility matrix started.
- [ ] Raw mode and alternate-screen cleanup validated.
- [x] Resize, focus, and lifecycle stress tests added. Initial lifecycle/concurrency stress tests cover rapid `.task` cancellation and context reset cleanup; manual resize validation remains open.

Exit criteria:

- [ ] Runtime behavior is reliable enough for internal production pilots.

### Milestone 3: Developer experience and dogfood

- [x] Real app tutorial complete.
- [x] Testing guide complete.
- [x] Dogfood app or realistic example complete.
- [x] Performance baselines recorded.

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
2. Continue terminal compatibility smoke validation using [Terminal Compatibility Matrix](TerminalCompatibility.md) and [Release Validation Checklist](ReleaseValidationChecklist.md).
3. Continue actor-isolating runtime-owned managers with `TUIRuntimeActor` where APIs can become async-safe.
4. Verify SwiftUI-equivalent API parity and document deviations.
5. Expand focus/keyboard UX documentation and tests.
6. Build out a realistic dogfood flow in the example app.

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
./scripts/release-validation-checklist.sh
```

Run Linux validation before major production-readiness claims:

```bash
./scripts/test-linux.sh
```
