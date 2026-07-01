---
name: tuikit-senior-dev
description: Human Interface Guidelines and senior UX guidance for building beautiful, usable terminal experiences with the Swift TUIkit framework. Use proactively whenever designing, implementing, reviewing, polishing, or debugging any TUIkit terminal app, screen, view, component, control, layout, navigation flow, focus/keyboard interaction, style/theme, copy, empty/loading/error state, accessibility behavior, or visual experience in this repository or an app that depends on TUIkit.
---

# TUIkit Human Interface Guidelines

Use this skill whenever you build or review TUIkit app code or app design. Act like a senior terminal product designer and Swift/TUI engineer: create beautiful, calm, keyboard-first terminal experiences while preserving SwiftUI-like API ergonomics, cross-platform correctness, and testability.

This skill is not only for framework internals. Trigger it for app screens, examples, demos, prototypes, visual polish, layout decisions, interaction design, copy, accessibility, state presentation, and any request where the result is a user-facing TUI experience.

## Human Interface Principles

- **Clarity first**: every screen should make the current state, primary action, and available navigation obvious at a glance.
- **Beautiful restraint**: use spacing, alignment, borders, weight, and color intentionally. Avoid noisy boxes, rainbow palettes, dense text walls, or generic dashboard clutter.
- **Keyboard-first by default**: all core flows must be usable without a mouse, with predictable focus movement and visible shortcut hints.
- **Terminal-native elegance**: embrace terminal strengths: fast scanning, compact density, command hints, stable layout, and graceful degradation in monochrome or narrow windows.
- **Progressive disclosure**: show the essentials first; place secondary metadata, help, diagnostics, and destructive actions where they do not compete with the main task.
- **Stateful feedback**: loading, empty, error, success, disabled, selected, and focused states must be intentionally designed, not left as incidental text.
- **Respect attention**: avoid flicker, layout jumps, excessive animation, and constantly changing status text unless it communicates meaningful progress.
- **Accessible contrast**: color can enhance meaning but must never be the only carrier of meaning. Pair it with labels, icons, symbols, or structure.
- **Humane copy**: write concise, specific labels and recovery guidance. Error messages should explain what happened and what the user can do next.

## Non-Negotiables

- **Swift 6.0 only**: do not use APIs or language features requiring a newer compiler.
- **macOS + Linux**: avoid Apple-only APIs unless guarded and isolated; keep XDG/Linux behavior in mind.
- **Pure ANSI terminal UI**: do not introduce ncurses or platform terminal dependencies.
- **SwiftUI API parity**: when adding SwiftUI-equivalent APIs, look up the exact SwiftUI signature first and match names/order/closures unless terminal constraints require a documented deviation.
- **Environment-driven state**: no global singletons for app state. Prefer `Environment`, bindings, preferences, and explicit dependencies.
- **Every public control is a real `View`**: public controls must have `body: some View`, propagate modifiers/environment, and never use `Never` or `fatalError()` as the public rendering path.
- **Modifier-first design**: TUI-specific behavior belongs in modifiers when that is how SwiftUI would express it (`.focusID`, `.buttonStyle`, `.listEmptyPlaceholder`, etc.).
- **Tests before done**: add/update Swift Testing coverage for behavior, rendering, focus, state, localization, and regression cases.

## First 5 Minutes: Orient Before Editing

1. Read the target code and closest existing examples/tests.
2. Identify the layer being changed:
   - `TUIkitCore`: primitives, key events, buffers, preferences, concurrency helpers.
   - `TUIkitStyling`: colors, palettes, borders, themes.
   - `TUIkitView`: `View`, `ViewBuilder`, state/environment, renderable bridge.
   - `TUIkitImage`: image loading/conversion.
   - `TUIkit`: public app API, controls, modifiers, focus, rendering, localization, notifications.
   - `TUIkitExample`: executable examples only.
3. Search for an existing component, modifier, style, environment key, or test pattern to reuse before inventing a new one.
4. Decide whether this is **app usage** or **framework API**. Framework API changes require stricter SwiftUI parity, docs, and tests.

## App Architecture Defaults

Prefer small, composable screens:

```swift
struct SettingsScreen: View {
    @State private var username = ""
    @State private var notificationsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Settings")
                .fontWeight(.bold)

            TextField("Username", text: $username)
                .focusID("settings.username")

            Toggle("Notifications", isOn: $notificationsEnabled)
                .focusID("settings.notifications")
        }
        .padding()
    }
}
```

Senior defaults:

- Keep state near the owning screen; lift only when multiple screens need it.
- Model navigation and selection as data (`enum Page`, selected IDs), not as scattered booleans.
- Keep terminal side effects at boundaries (app startup, services, persistence), not inside render logic.
- Prefer reusable view modifiers/styles over ad-hoc styling repeated across screens.
- Design for narrow terminals: truncation, wrapping, empty states, and keyboard-only operation are product requirements.

## Focus and Keyboard UX

Interactive terminal apps live or die by focus behavior.

- Give stable `.focusID(...)` values to interactive controls that need keyboard navigation.
- IDs must be deterministic and unique across repeated rows; use item IDs, not indices if rows can reorder.
- Disabled views must not register as interactive focus targets.
- Avoid focus traps. There must be a predictable path in/out with arrows/tab/escape as appropriate.
- Add status bar hints for important shortcuts when a screen introduces non-obvious keys.
- Test focus order, disabled behavior, selection preservation, and key handling.

## Rendering and Layout Rules

- Treat rendering as a pure function of view state + environment + terminal dimensions.
- Do not mutate app state during rendering except through established state/storage mechanisms.
- All modifiers must propagate through nested content; verify with tests when adding containers.
- Prefer existing layout primitives (`VStack`, `HStack`, `ZStack`, `Spacer`, `Frame`, `Padding`, `Overlay`, `Border`) before custom rendering.
- For custom components, compose existing views first. Drop to lower-level renderable/core code only when composition cannot express the behavior.
- Handle edge dimensions: width 0/1, narrow terminal, empty collections, long Unicode text, and clipped borders.

## Styling, Theming, and Copy

Design screens before decorating them:

- Establish a clear visual hierarchy: title, context, primary content, actions, status/help.
- Prefer one strong accent and a small semantic palette over many unrelated colors.
- Align labels, values, columns, and controls so users can scan vertically.
- Use borders sparingly to group or focus content; avoid boxing every element.
- Keep dense data readable with spacing, truncation rules, and stable columns.
- Make focused and selected states visually distinct from each other.
- Put shortcut hints where the user needs them: footer/status bar for global actions, inline hints for local controls.
- Use TUIkit styling primitives and theme palettes instead of hard-coded ANSI sequences.
- Expose customization through style protocols or modifiers when callers need control.
- Keep color meaningful but not required; UI must remain understandable in monochrome terminals.
- For user-facing strings in framework/demo surfaces, use localization facilities and maintain all supported translations when applicable.
- Always provide useful empty/error/loading states for app screens.

## Public API Design Checklist

Before adding or changing public API:

1. Is there a SwiftUI equivalent? Match it as closely as terminal constraints allow.
2. Is this better as a modifier than an initializer parameter?
3. Are generic constraints, `@ViewBuilder` closures, binding parameters, and trailing closure shape SwiftUI-like?
4. Does the public type remain a `View` with a real `body`?
5. Do existing modifiers/environment values flow through all child content?
6. Is the API source-compatible with Swift 6.0 and Linux?
7. Are tests and docs/examples updated?

## Testing Playbook

Use Swift Testing and the existing test style.

Run targeted tests while iterating:

```bash
swift test --filter <TestSuiteName>
```

Before claiming done, run as much as practical:

```bash
swift build
swift test
swiftlint
```

Format when touching many Swift files:

```bash
swift-format format -i -r Sources Tests
```

Test categories to consider:

- View output/render buffer snapshots or structural assertions.
- Modifier propagation through containers.
- Environment values and preferences.
- Focus registration/order, disabled state, and keyboard actions.
- Bindings and state persistence across renders.
- Localization key coverage and fallback behavior.
- Linux-safe path/process behavior.
- Regression tests for every bug fixed.

## Review Checklist

Use this checklist before final response or PR handoff:

- [ ] Builds with Swift 6.0 assumptions.
- [ ] No macOS-only assumptions in shared code.
- [ ] Public APIs match SwiftUI naming/order where applicable.
- [ ] Public controls are real `View`s; no public `Never`/`fatalError()` render path.
- [ ] Environment, modifiers, disabled state, and focus flow correctly.
- [ ] Terminal UX works for keyboard-only users and narrow terminals.
- [ ] Styling uses TUIkit primitives/theme, not raw ANSI strings.
- [ ] Tests cover the behavior and likely regressions.
- [ ] Example/docs updated if user-facing behavior changed.
- [ ] `swift build`, relevant `swift test`, and lint/format status are reported.

## Common Pitfalls

- Replacing SwiftUI-like composition with hidden imperative rendering too early.
- Adding initializer parameters for styling that should be modifiers/styles.
- Using row indices as focus IDs in dynamic lists.
- Hard-coding terminal widths, colors, home directories, or platform paths.
- Forgetting disabled-state propagation to nested controls.
- Passing prebuilt views where a `@ViewBuilder` closure is expected.
- Updating English strings but not localization resources/tests.
- Declaring success without running targeted tests or explaining why validation was not run.
