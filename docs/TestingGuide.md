# Testing Guide

TUIkit uses Swift Testing for framework tests and encourages app authors to use the same approach. Tests should be deterministic, parallel-safe, and independent of a real terminal whenever possible.

## Recommended layers

1. **Pure unit tests** for state, handlers, formatters, and bindings.
2. **Render tests** using `renderToBuffer` and a fixed `RenderContext`.
3. **Interaction tests** for key handlers, focus managers, and lifecycle managers.
4. **Manual terminal validation** with `make example` and the release checklist.

## Rendering tests

Render tests should assert semantic output, not every byte unless the exact ANSI sequence is the behavior under test.

```swift
@MainActor
@Test("empty state renders recovery guidance")
func emptyStateRendersGuidance() {
    let context = RenderContext(availableWidth: 80, availableHeight: 24, tuiContext: TUIContext())
    let buffer = renderToBuffer(ContentUnavailableView("No results", systemImage: "magnifyingglass"), context: context)

    #expect(buffer.lines.joined().contains("No results"))
}
```

Prefer fixed widths and heights. Include narrow-width cases for public components.

## Focus and keyboard tests

Use `FocusManager`, handlers, or rendered controls with a fresh `TUIContext` per test. Verify disabled controls do not register focus and that focus IDs are stable for repeated rows.

## Lifecycle and concurrency tests

Lifecycle tests should verify that tasks cancel on disappearance and context reset. Avoid sleeps where possible; use explicit clocks, expectations, or short bounded waits.

## Performance checks

Performance tests in `Tests/TUIkitTests/RenderPerformanceTests.swift`, `RenderBottleneckTests.swift`, and `StringPerformanceTests.swift` are smoke baselines. Keep thresholds conservative so CI remains stable across machines.

## Manual validation

Before release-candidate claims, run:

```bash
swift build
swift test --parallel
./scripts/release-validation-checklist.sh
```

Run `swiftlint` and `./scripts/test-linux.sh` where available. Record real terminal results in `docs/TerminalCompatibility.md`.
