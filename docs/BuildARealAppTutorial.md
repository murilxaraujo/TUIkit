# Build a Real App with TUIkit

This tutorial sketches the recommended architecture for a small production-style terminal app.

## 1. Create the package

```bash
tuikit init TasksApp
cd TasksApp
swift run
```

Or add TUIkit manually in `Package.swift` using a tagged release or release-candidate tag.

## 2. Model app state as data

```swift
struct TaskItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
}

enum Route: Equatable {
    case inbox
    case details(UUID)
    case settings
}
```

## 3. Compose screens

```swift
struct TasksScreen: View {
    @State private var route: Route = .inbox
    @State private var tasks: [TaskItem] = []

    var body: some View {
        NavigationSplitView {
            TaskList(tasks: tasks, route: $route)
        } detail: {
            TaskDetail(route: route, tasks: $tasks)
        }
        .statusBarItems {
            StatusBarItem(shortcut: "Tab", label: "next")
            StatusBarItem(shortcut: "Enter", label: "open")
            StatusBarItem(shortcut: "q", label: "quit")
        }
    }
}
```

## 4. Use stable focus IDs

```swift
ForEach(tasks, id: \.id) { task in
    Button(task.title) { route = .details(task.id) }
        .focusID("task.\(task.id)")
}
```

## 5. Design states intentionally

Every production screen should have useful loading, empty, error, disabled, focused, and selected states. Prefer concise recovery guidance over generic failure text.

## 6. Test and validate

Add render tests for each state and interaction tests for important keyboard behavior. Before shipping, run:

```bash
swift build
swift test --parallel
./scripts/release-validation-checklist.sh
```

Then manually validate in the terminals your users depend on and record results in `docs/TerminalCompatibility.md`.
