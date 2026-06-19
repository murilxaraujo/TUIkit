# Performance Guide

TUIkit rendering should stay responsive under frequent input, animations, and large data sets. Measure before optimizing.

## Existing baselines

The repository includes CI-safe performance smoke tests:

- `Tests/TUIkitTests/RenderPerformanceTests.swift` — common view hierarchy render thresholds.
- `Tests/TUIkitTests/RenderBottleneckTests.swift` — stack depth, child count, and `ForEach` analysis.
- `Tests/TUIkitTests/StringPerformanceTests.swift` — ANSI/string width operations.
- `Tests/TUIkitTests/RenderPerformanceMonitorTests.swift` — runtime FPS/performance snapshots.

Run targeted checks with:

```bash
swift test --filter RenderPerformanceTests
swift test --filter RenderBottleneckTests
swift test --filter StringPerformanceTests
swift test --filter RenderPerformanceMonitorTests
```

## App guidance

- Prefer lazy stacks, lists, and tables for large collections.
- Keep row views small and deterministic.
- Use `.equatable()` for expensive subtrees whose inputs change infrequently.
- Avoid starting async work from rendering paths.
- Debounce high-frequency external updates before writing state.
- Test narrow terminal sizes; clipping and wrapping can dominate perceived performance.

## Release-candidate expectations

A release candidate should record:

- the machine and Swift version used for performance checks;
- targeted performance test commands and pass/fail status;
- any known large-data caveats in `docs/KnownLimitations.md`.

Do not advertise hard FPS guarantees across all terminals until the compatibility matrix has validated representative environments.
