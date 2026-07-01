# TUIkit Previews

TUIkit previews give you a native-feeling edit/build/render loop for terminal views. They are intentionally implemented as ordinary Swift executable targets instead of an Xcode-only private integration, which keeps the workflow portable across macOS, Linux, Xcode, VS Code, and terminal-only development.

## What you get

- Deterministic previews of any `View` on a fixed terminal canvas.
- A SwiftUI-like declaration style with `TUIPreview` and result-builder lists.
- CLI selection by stable preview ID.
- Size and theme metadata for responsive and narrow-terminal checks.
- Snapshot output for docs and regression fixtures.
- A package-level watcher command that rebuilds and rerenders on source changes.
- A SwiftPM command plugin for Xcode-adjacent workflows.

## Add a preview executable

In your package, add a small executable target for previews. It should depend on your app/library module plus `TUIkitPreview`.

```swift
// Package.swift
.executableTarget(
    name: "MyAppPreviews",
    dependencies: ["MyApp", "TUIkit", "TUIkitPreview"]
)
```

Then create `Sources/MyAppPreviews/main.swift`:

```swift
import MyApp
import TUIkit
import TUIkitPreview

@main
struct MyAppPreviews: TUIkitPreviewApp {
    static var previews: [TUIPreview] {
        TUIPreview("Dashboard", size: .desktop) {
            DashboardView()
        }

        TUIPreview("Dashboard / Narrow", size: .narrow) {
            DashboardView()
        }

        TUIPreview("Empty State", width: 80, height: 24) {
            DashboardView(items: [])
        }
    }
}
```

> Tip: keep preview state deterministic. Prefer explicit fixtures like `items: []`, mock services, and stable dates instead of live network calls or wall-clock state.

## Run previews

Render the first preview:

```bash
swift run MyAppPreviews
```

List all previews:

```bash
swift run MyAppPreviews -- --list
```

Render a specific preview by ID or exact name:

```bash
swift run MyAppPreviews -- --preview dashboard
swift run MyAppPreviews -- --preview "Dashboard / Narrow"
```

Override the terminal canvas without changing source:

```bash
swift run MyAppPreviews -- --preview dashboard --size 100x30
# --width and --height remain supported for compatibility.
```

Print only the render buffer, without preview chrome:

```bash
swift run MyAppPreviews -- --preview dashboard --snapshot
```

## Live preview loop

Use the `tuikit-preview` executable to build the preview target, run the selected preview, and rerun it whenever `Package.swift`, `Package.resolved`, or Swift source files change:

```bash
swift run tuikit-preview -- --target MyAppPreviews --preview dashboard
swift run tuikit-preview -- list --target MyAppPreviews
swift run tuikit-preview -- --target MyAppPreviews --preview dashboard --size 100x30 --theme dark
```

Use `--no-watch` for a one-shot build/render. You can also persist defaults in `.tuikit-preview.yml`:

```yaml
target: MyAppPreviews
defaultPreview: dashboard
theme: dark
size:
  width: 100
  height: 30
```

For Xcode-adjacent workflows, run the command plugin from SwiftPM or Xcode's package plugin UI:

```bash
swift package plugin tuikit-preview --target MyAppPreviews --preview dashboard
```

The older command-wrapper mode remains available for custom scripts:

```bash
swift run tuikit-preview -- --watch swift run MyAppPreviews -- --preview dashboard
```

This works well next to Xcode: keep Xcode focused on editing and place the preview terminal beside it.

## Recommended preview coverage

For each substantial screen, include previews for:

1. **Happy path** — representative real content.
2. **Empty state** — no items or first-run setup.
3. **Error state** — user-recoverable failure copy.
4. **Narrow terminal** — `.narrow` or custom `width: 48`.
5. **Long content** — truncation, wrapping, and scrolling stress.

Example:

```swift
static var previews: [TUIPreview] {
    TUIPreview("Tasks / Active", size: .desktop) {
        TaskListView(tasks: .sampleActive)
    }

    TUIPreview("Tasks / Empty", size: .standard) {
        TaskListView(tasks: [])
    }

    TUIPreview("Tasks / Error", size: .standard) {
        TaskListView(state: .failed("Could not load tasks."))
    }

    TUIPreview("Tasks / Narrow", size: .narrow) {
        TaskListView(tasks: .sampleActive)
    }
}
```

## Why this design

Xcode's built-in SwiftUI Preview canvas is private Apple infrastructure. TUIkit previews instead use public Swift and SwiftPM primitives:

- preview declarations compile in your package;
- rendering uses the same `renderToBuffer(_:context:)` path as TUIkit apps;
- terminal output stays ANSI-native;
- the workflow remains portable to Linux and CI.

A future macOS companion preview window can build on the same `TUIkitPreview` declarations without changing app preview code.
