# NavigationStack

Use `NavigationStack` to model terminal navigation as data instead of manual page switches.

```swift
enum Route: Hashable {
    case colors
    case buttons
}

struct ContentView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                NavigationLink("Colors", value: Route.colors)
                NavigationLink("Buttons", value: Route.buttons)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .colors: ColorsPage()
                case .buttons: ButtonsPage()
                }
            }
        }
    }
}
```

The root view is non-removable. Pressing Escape pops one route while the path is non-empty, and bubbles when the stack is already at the root so the app-level default handler can run.

Destination declarations are collected in a semantic pass before the visible route is rendered. During semantic collection, TUIkit suppresses live focus, key handler, lifecycle, and status bar side effects so hidden root controls do not receive input while a destination is active.

## Route values

Use a homogeneous collection such as `[Route]` for ordinary typed navigation. Use `NavigationPath` when you need heterogeneous route values or direct destination links:

```swift
@State private var path = NavigationPath()

NavigationStack(path: $path) {
    NavigationLink("Details") {
        DetailsView()
    }
}
```

## Presentations

Sheets are available with SwiftUI-style spelling:

```swift
.sheet(isPresented: $showingSettings) {
    SettingsView()
}
```

In terminals, sheets currently use the same centered, dimmed, input-isolating presentation behavior as `modal(isPresented:)`.
