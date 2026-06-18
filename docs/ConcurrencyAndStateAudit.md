# Concurrency and Shared-State Audit

This audit tracks TUIkit's current concurrency boundaries, shared services, and unsafe Swift concurrency annotations. It supports Workstream 3 of the [Production Readiness Plan](ProductionReadinessPlan.md).

## Scope and current model

TUIkit's app runtime is designed around a SwiftUI-like responsiveness model: a narrow interaction lane coordinates UI work, while expensive jobs run in background tasks.

- rendering, input dispatch, focus mutation, render scheduling, and terminal I/O stay on the runtime/main interaction loop;
- `.task` work, image loading, timers, persistence, networking, indexing, and other expensive jobs run in detached background tasks;
- background work must publish only small state changes back to the UI model;
- cross-thread notifications should only set render-needed flags or update explicitly locked state;
- view rendering should remain a pure function of view value, environment, state storage, and terminal dimensions.

`TUIRuntimeActor` is now available as the framework's explicit runtime actor marker. The current portable terminal loop remains synchronous, so migration is incremental: runtime-owned objects can adopt that actor over time without forcing all `View` APIs to become async.

The audit does **not** mean every listed item is a bug. It distinguishes accepted invariants from items that should be fixed or revisited before beta/1.0.

## Summary

| Area | Current status | Production-readiness decision |
| --- | --- | --- |
| `AppState` | Locked, `Sendable`, has `shared` fallback | Accept temporarily; prefer per-runner instance for runtime. |
| Signal flags | `nonisolated(unsafe)` booleans | Accept with documented async-signal-safety invariant. |
| `StateRegistration` | `nonisolated(unsafe)` render globals | Accept only under single-threaded render invariant; revisit for reentrant/concurrent rendering. |
| `RenderCache.shared` | Locked compatibility fallback | Runtime fixed: `TUIContext` now owns a fresh render cache by default. Keep `shared` only for standalone compatibility until 1.0 policy is decided. |
| `StorageDefaults.backend` | Lock-backed process default | Fixed: get/set access is synchronized; existing `@AppStorage` instances keep the backend captured at initialization. |
| `NotificationService.current` | `nonisolated(unsafe)` mutable global | Accept temporarily for callback ergonomics; prefer environment/action injection long term. |
| `PulseTimer` / `CursorTimer` | Structured timer tasks + locked counters | Fixed in this pass with Swift concurrency tasks and locks around shared timer state. |
| `ThemeManager`, `FocusManager`, `StatusBarState`, `TUIContext` | `@unchecked Sendable` but intended main-loop scoped | Accept only when owned by `AppRunner`; add docs/tests before exposing cross-thread use. |
| `LifecycleManager`, `StateStorage`, `PreferenceStorage`, `LocalizationService`, storage backends, image cache | Locked or otherwise isolated | Mostly acceptable; `.task` work now runs detached from the interaction loop. |

## Unsafe annotation inventory

### Accepted with current invariants

#### `Sources/TUIkit/App/SignalManager.swift`

- `signalNeedsRerender`
- `signalTerminalResized`
- `signalNeedsShutdown`

Invariant:

- These booleans are written by POSIX signal handlers and read/cleared by the main loop.
- Signal handlers must not allocate, lock, call Swift runtime-heavy APIs, write terminal output, or perform cleanup.
- Missing or duplicate reads are acceptable because resize/render/shutdown handling is idempotent at the app-loop level.

Decision: accepted for now. Keep the explanatory comments in source.

#### `Sources/TUIkitView/State/State.swift` — `StateRegistration`

- `activeContext`
- `counter`
- `activeEnvironment`

Invariant:

- These globals are only set while evaluating a view `body` during a render pass.
- Rendering is single-threaded and non-reentrant within one `AppRunner`.
- Callers must save and restore prior values around nested body evaluation.

Decision: accepted for the current renderer. Before supporting concurrent rendering, previews, or multiple active app runners, replace this with an explicit render-local stack/context object.

#### `Sources/TUIkit/Environment/ServiceEnvironment.swift`

- `CursorTimerKey.defaultValue`

Invariant:

- The default value is immutable `nil` and does not carry state.

Decision: acceptable.

### Accepted temporarily, but should be redesigned

#### `Sources/TUIkit/Notification/NotificationService.swift`

- `NotificationService.current`

Invariant:

- The service itself protects its entry array with a lock.
- The static mutable reference is intended as a bridge for button/action callbacks that cannot currently read environment values.

Risk:

- Tests and multiple app sessions can leak service identity across runs if the static is replaced or mutated.
- Static mutation is not synchronized.

Recommendation:

- For beta, keep but document as app-runtime global.
- Before 1.0, prefer an action-context/environment accessor for callbacks or make `current` immutable per process with explicit test reset hooks.

#### `Sources/TUIkit/State/AppStorage.swift` — `StorageDefaults.backend`

Invariant:

- The process default backend can still be configured through the source-compatible `StorageDefaults.backend` property.
- Get/set access is synchronized by a private lock-backed box.
- Existing `@AppStorage` instances keep the backend captured at initialization, matching the previous behavior.
- Concrete default backend (`JSONFileStorage`) is internally locked and snapshots its cache before asynchronous disk writes.

Resolved risk:

- Concurrent reads/writes of the default backend no longer race on an unsynchronized static variable.

Remaining guidance:

- Prefer configuring the default backend during app startup so all `@AppStorage` properties use the same backend identity.

### Needs technical remediation

#### `Sources/TUIkitView/Rendering/RenderCache.swift` — `RenderCache.shared`

Current invariant:

- Runtime rendering uses a `TUIContext`-owned `RenderCache` by default.
- `StateStorage` creates `StateBox` instances wired to the same owning cache, so `@State` changes invalidate the correct app/session cache.
- `RenderCache.shared` remains as a locked compatibility fallback for standalone `StateBox` / `StateStorage` usage outside a `TUIContext`.

Resolved risk:

- New `TUIContext()` instances no longer share memoized subtree state.
- Background task state publication can invalidate cache entries safely because `RenderCache` is locked.

Remaining recommendation:

- Decide before 1.0 whether `RenderCache.shared` stays public as an advanced fallback, becomes deprecated, or is removed from public API.

## `@unchecked Sendable` inventory

### Locked/isolated and acceptable

- `Lock<State>`: wrapper over platform lock implementations; accepted.
- `AppState`: uses `Lock<StateData>`; accepted, though `shared` should remain infrastructure-only.
- `StateStorage`: expected to protect internal storage; accepted if lock invariants remain true.
- `StateBox<Value>`: protects value mutation and render invalidation path; accepted if value access stays locked.
- `PreferenceStorage`: locked preference collection; accepted.
- `LifecycleManager`: uses `NSLock`, executes callbacks outside lock, cancels tasks on reset; accepted with continued tests.
- `LocalizationService`: uses `NSLock` for language/cache access; accepted.
- `JSONFileStorage` / `UserDefaultsStorage`: concrete storage backends use locking or platform thread-safe storage; accepted.
- `URLImageCache`: acceptable if cache dictionary access stays locked.

### Main-loop scoped and acceptable only under ownership rules

- `FocusManager`
- `KeyEventDispatcher`
- `StatusBarState`
- `ThemeManager`
- `AppHeaderState`
- `TUIContext`
- `EnvironmentValues`
- `PreferenceValues`
- `StatusBarItem`
- `AppStorage<Value>`

Invariant:

- These values are created by `AppRunner`, `RenderLoop`, or view construction and are expected to be used from the main render/input loop unless explicitly documented otherwise.
- They are marked `@unchecked Sendable` primarily to satisfy closure/environment transport requirements, not to advertise arbitrary concurrent mutation.

Recommendation:

- Add source comments to each major type explaining whether it is truly thread-safe or main-loop-confined.
- Consider removing public `Sendable` surface where not needed before 1.0.
- Add stress tests around focus/status/lifecycle if any of these become accessible from background tasks.

## Modern concurrency migration completed in this pass

TUIkit now has the first concrete pieces of its SwiftUI-like concurrency model:

- Added `TUIRuntimeActor` as the explicit runtime/interaction-lane actor marker.
- Added `TUIRuntime.runInBackground(priority:operation:)` for work that must not inherit the runtime/main actor.
- Added per-context render performance monitoring exposed through `EnvironmentValues.renderPerformance` for lightweight diagnostics such as the example app's live FPS readout.
- `LifecycleManager.startTask` now uses detached background tasks, so `.task` work does not freeze input handling or rendering by inheriting the interaction loop.
- `PulseTimer` and `CursorTimer` now use structured Swift concurrency tasks instead of `DispatchSourceTimer`.
- `PulseTimer` protects `currentStep` and task lifecycle with `NSLock`.
- `CursorTimer` protects `elapsedTicks` and task lifecycle with `NSLock`.
- `StateStorage`, `StateBox`, and `RenderCache` now protect mutable state with locks so background task results can safely publish through `@State`/bindings and request cache invalidation.

This does not make rendering concurrent. Rendering remains single-lane by design; the performance win comes from keeping I/O and expensive work off that lane.

## Global/shared state review

### `AppState.shared`

Purpose:

- Compatibility/fallback render notifier used by property wrappers and observable tracking when no runner-local `AppState` is available.

Decision:

- Accept for now as framework infrastructure.
- Long term, route all runtime invalidation through the `AppRunner`-owned `AppState` in `EnvironmentValues`/`StateStorage` where possible.

### `RenderCache.shared`

Decision:

- Runtime ownership follow-up completed: `TUIContext` now creates a fresh render cache by default and wires `StateStorage` to it.
- `RenderCache.shared` remains only as a compatibility fallback for standalone storage/box usage.

### `StorageDefaults.backend`

Decision:

- Accept for pre-1.0 as a lock-backed process default.
- Public get/set API is preserved; replacement remains best done during startup so existing `@AppStorage` wrappers do not intentionally retain an older backend.

### `LocalizationService.shared`

Decision:

- Accept temporarily because localization is process-wide today and internally locked.
- Long term, prefer environment-owned localization for multi-session isolation.

### `NotificationService.current`

Decision:

- Accept temporarily due to callback ergonomics.
- Revisit once actions can access environment services without a static global.

## Follow-up backlog

Required before beta-quality runtime claims:

1. Decide whether `RenderCache.shared` remains public API, becomes deprecated, or is removed before 1.0.
2. Add source-level invariant comments for each `@unchecked Sendable` type that is main-loop-confined rather than generally thread-safe.
3. Add lifecycle stress tests for `.task()` cancellation during rapid appear/disappear and app shutdown.
4. Add render invalidation stress tests for rapid timer ticks, focus changes, and state changes.
5. Decide whether `NotificationService.current` remains public API or moves behind an environment/action context before 1.0.
6. Gradually annotate runtime-owned managers with `TUIRuntimeActor` as APIs become async-safe.
7. Evaluate whether `StateRegistration` can become explicit render-local state instead of static render globals.

## Current readiness interpretation

The framework has a coherent single-threaded runtime model, and several core shared services are already locked. The main production risks are not broad unsafe behavior everywhere; they are a few static/global escape hatches that need ownership cleanup before beta/1.0.

This audit moves Workstream 3 from unknown to mapped. The `RenderCache.shared` runtime ownership follow-up is complete, and `StorageDefaults.backend` now has synchronized access. The next highest-risk shared-state item is `NotificationService.current`.
