---
name: tuikit-human-interface-guidelines
description: Human Interface Guidelines for designing, building, reviewing, and polishing GUI-like terminal apps with Swift TUIkit. Use proactively for TUIkit app screens, examples, navigation, layout, component choice, keyboard/focus behavior, hints/status bars, empty/loading/error states, and when preventing CLI-like command-driven UX in favor of approachable graphical terminal interfaces.
---

# TUIKit Human Interface Guidelines

Use this skill whenever you design, implement, review, or polish a TUIkit app. TUIkit is **not** a command-line prompt framework. Its product goal is a **GUI-like terminal interface**: visible controls, navigation, focus, shortcuts, panels, dialogs, stateful feedback, and discoverable flows that ordinary users can operate without memorizing commands.

When in doubt, model the experience after `Sources/TUIkitExample`: a root `NavigationStack`, a clear app header, visible menus, stateful controls, grouped demo sections, status-bar hints, and Escape-to-back navigation.

## Core Product Principles

1. **GUI-like, not CLI-like**
   - Prefer `Menu`, `NavigationLink`, `Button`, `Toggle`, `List`, `Table`, `Slider`, `Stepper`, `TextField`, `Dialog`, and `Alert` over text prompts and command parsing.
   - Do not build flows around `:commands`, shell-style verbs, hidden hotkeys, or “type an action name”.
   - Users should be able to look at a screen and understand what they can do next.

2. **Discoverable keyboard-first interaction**
   - Every interactive screen needs visible guidance: status bar items for global/current actions and inline help for local controls.
   - Standard defaults:
     - `↑/↓` or `Tab` moves focus/selection.
     - `Enter` and often `Space` activate/select.
     - `Escape` goes back or closes the top presentation.
     - `Ctrl+C` remains an emergency/global terminal exit.
   - Avoid unadvertised shortcuts except truly universal behavior.

3. **State is visible**
   - Show current selection, count, enabled/disabled mode, progress, validation state, and success/error feedback.
   - Use patterns like `ValueDisplayRow("Selection:", value)` so users can confirm what changed.

4. **Calm visual hierarchy**
   - Use app headers for screen identity, sections for grouping, panels/cards for important grouped content, and status bars for shortcuts.
   - Avoid boxing every line. Borders should group information or establish focus, not decorate noise.
   - Use palette tokens (`.palette.accent`, `.palette.foregroundSecondary`, `.palette.border`) instead of hard-coded ANSI/color choices.

5. **Progressive disclosure**
   - Root screens should orient and route.
   - Detail screens should focus on one task.
   - Advanced/help/API details belong in secondary panels or expandable sections, not in the primary action path.

## Anti-Patterns to Prevent

Avoid these CLI-shaped designs in TUIkit apps:

```swift
Text("Type 'delete 42' to delete an item")
TextField("Command", text: $command)
Button("Run") { parseCommand(command) }
```

Prefer visible, GUI-like controls:

```swift
List("Files", selection: $selectedFile) {
    ForEach(files) { file in
        HStack(spacing: 1) {
            Text(file.icon)
            Text(file.name)
        }
    }
}

ButtonRow {
    Button("Delete", style: .destructive) { showDeleteConfirmation = true }
    Button("Rename") { showRenameDialog = true }
}
.statusBarItems {
    StatusBarItem(shortcut: Shortcut.arrowsUpDown, label: "nav")
    StatusBarItem(shortcut: Shortcut.enter, label: "select", key: .enter)
    StatusBarItem(shortcut: Shortcut.escape, label: "back")
}
```

## App Structure Pattern

Use a root navigation shell for multi-screen apps:

```swift
struct ContentView: View {
    @State private var path: [Page] = []
    @State private var menuSelection = 0

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuPage(selection: $menuSelection) { page in
                path.append(page)
            }
            .statusBarItems {
                StatusBarItem(shortcut: Shortcut.arrowsUpDown, label: "nav")
                StatusBarItem(shortcut: Shortcut.enter, label: "open", key: .enter)
            }
            .navigationDestination(for: Page.self) { page in
                pageView(page)
                    .statusBarItems {
                        StatusBarItem(shortcut: Shortcut.escape, label: "back")
                    }
            }
        }
        .statusBarQuitBehavior(.rootOnly)
    }
}
```

Guidelines:

- Root screen: show `q quit` if enabled, route with `Menu`, and describe the app.
- Destination screens: hide quit (`.statusBarQuitBehavior(.rootOnly)`), show `Esc back`, and keep Ctrl+C as global exit.
- Use `NavigationStack` data routes (`enum Page: Hashable`) rather than scattered booleans for screen routing.

## Component Selection Guide

### Navigation and screen routing

Use:

- `NavigationStack` for app-level page navigation.
- `NavigationLink` for visible row/card links.
- `Menu` for a compact root or side menu of mutually exclusive destinations/actions.
- `NavigationSplitView` when the interface naturally has master-detail panes.

Avoid:

- Asking users to type page names.
- One screen with a long command grammar.
- Hidden numeric shortcuts without a visible menu label.

### Actions

Use:

- `Button` for a single action.
- `ButtonRow` for related actions like Cancel/Save, Back/Continue, Reset/Apply.
- Button styles to encode intent:
  - `.primary` for the main action.
  - `.success` for positive completion.
  - `.destructive` for irreversible or dangerous actions.
  - `.plain` for link-like secondary actions.

Rules:

- Destructive actions should usually open `Alert`/`Dialog` confirmation.
- Disabled actions should be visibly disabled and unfocusable.
- Every ButtonRow should have an obvious default/primary action.

### Choices and settings

Use:

- `Toggle` for independent on/off settings.
- `RadioButtonGroup` for one-of-many choices where all choices should be visible.
- `Menu` for longer one-of-many lists.
- `Picker`-like custom list only if the available component does not fit.

Show the selected value near the control or in a “Current Selection” section.

### Collections and data

Use:

- `List` for selectable rows, scrolling item sets, and master panes.
- `Table` for multi-column structured data.
- `ContentUnavailableView` or list empty placeholders for empty states.
- Stable IDs for focus and selection; never depend on row indices when items can reorder.

Add keyboard help for list-heavy screens:

```swift
KeyboardHelpSection("Navigation", shortcuts: [
    "Use [↑/↓] to navigate items",
    "Use [Home/End] to jump to first/last",
    "Use [PageUp/PageDown] for fast scrolling",
    "Use [Enter/Space] to select/deselect",
    "Use [Tab] to switch between lists",
])
```

### Text input

Use:

- `TextField` for short editable text.
- `SecureField` for secrets.
- `TextArea` for multiline input.

Always provide:

- A clear label/prompt.
- Validation feedback.
- Save/Cancel or Apply/Reset actions.
- Shortcut hints for submit/cancel when not obvious.

Avoid command boxes. If a user must enter structured text, label it as data, not commands.

### Containers and layout

Use:

- `VStack` for vertical screen flow.
- `HStack` for peer panes or action rows.
- `Spacer` to center root experiences or push content into stable areas.
- `DemoSection`-style sections for semantic grouping.
- `Card` for self-contained information blocks.
- `.border()` for lightweight grouping.
- `Panel` when a group needs a title and optional footer.
- `ProgressView` for determinate work; `Spinner` for indeterminate work.

Layout rules:

- Prefer `VStack(alignment: .leading, spacing: 1)` for dense but readable terminal screens.
- Use `HStack(spacing: 2...3)` for side-by-side panes.
- Keep important content visible above the fold; put help/details below or in a side panel.
- Test narrow terminals: long labels should wrap or truncate gracefully.

### Presentation

Use:

- `.alert(isPresented:)` / `Alert` for important confirmation, warning, error, or destructive decision.
- `.modal(isPresented:)` / `Dialog` for richer blocking workflows.
- `NotificationService.current.post(...)` with `.notificationHost()` for non-blocking success/info feedback.

Rules:

- When a modal is open, `Escape` should close the modal before navigating back.
- Status bar items must change with presentation state: `Esc close` while modal is shown, `Esc back` otherwise.
- Dim the background and focus the presented content where the library supports it.

## Hints, Help, and Status Bars

Every screen should answer: “Where am I?”, “What is focused/selected?”, “What can I press?”

Use app headers for location:

```swift
.appHeader {
    DemoAppHeader("Buttons & Focus Demo")
}
```

Use status bar items for current actionable keys:

```swift
.statusBarItems {
    StatusBarItem(shortcut: Shortcut.escape, label: "back")
    StatusBarItem(shortcut: Shortcut.arrowsUpDown, label: "nav")
    StatusBarItem(shortcut: Shortcut.enter, label: "show")
}
```

Use inline help for component-specific controls:

```swift
KeyboardHelpSection("Focus Navigation", shortcuts: [
    "Use [Tab] to move focus between buttons",
    "Use [Enter] or [Space] to press the focused button",
])
```

Use value displays for state confirmation:

```swift
DemoSection("Current Selections") {
    ValueDisplayRow("Single:", selectedName ?? "(none)")
    ValueDisplayRow("Mode:", isEditing ? "Editing" : "Viewing")
}
```

Guidelines:

- Status bar = short global/current controls.
- Inline help = local, educational, or less frequent controls.
- Do not overload either with every possible key.
- Update hints when mode changes, especially for modals, edit modes, and selection modes.

## Screen Blueprint

A strong TUIkit screen usually has:

1. **Header**: app/screen title and optional subtitle.
2. **Primary content**: menu, list, form, table, or focused workflow.
3. **State summary**: selected item, current value, progress, or mode.
4. **Actions**: buttons or ButtonRow, visibly focusable.
5. **Guidance**: status bar + optional keyboard help section.
6. **Feedback states**: loading, empty, error, success.

Example skeleton:

```swift
struct FilesScreen: View {
    @State private var selection: String?
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            List("Files", selection: $selection) {
                ForEach(files) { file in
                    HStack(spacing: 1) {
                        Text(file.icon)
                        Text(file.name)
                    }
                }
            }

            DemoSection("Current Selection") {
                ValueDisplayRow("File:", selection ?? "(none)")
            }

            ButtonRow {
                Button("Rename") { startRename() }
                    .disabled(selection == nil)
                Button("Delete", style: .destructive) { showDeleteAlert = true }
                    .disabled(selection == nil)
            }

            KeyboardHelpSection(shortcuts: [
                "Use [↑/↓] to navigate files",
                "Use [Enter] to select",
                "Use [Tab] to move to actions",
            ])

            Spacer()
        }
        .appHeader { DemoAppHeader("Files") }
        .alert("Delete file?", isPresented: $showDeleteAlert) {
            Button("Cancel") { showDeleteAlert = false }
            Button("Delete", style: .destructive) { deleteSelected() }
        } message: {
            Text("This action cannot be undone.")
        }
        .statusBarItems {
            StatusBarItem(shortcut: Shortcut.escape, label: "back")
            StatusBarItem(shortcut: Shortcut.arrowsUpDown, label: "nav")
            StatusBarItem(shortcut: Shortcut.enter, label: "select")
        }
    }
}
```

## Empty, Loading, Error, and Success States

Design these as real screens or panels, not bare strings.

- **Empty**: explain what is missing and how to create/import/add it.
- **Loading**: show `ProgressView` if progress is known; `Spinner` plus specific text otherwise.
- **Error**: state what failed, why if known, and a recovery action.
- **Success**: prefer non-blocking notification unless the user must acknowledge it.

Good error pattern:

```swift
Panel("Couldn’t Load Files", titleColor: .palette.error) {
    Text("The workspace index is unavailable.")
    Text("Check that the project exists and try again.")
        .foregroundStyle(.palette.foregroundSecondary)
    Button("Retry", style: .primary) { reload() }
}
```

## Visual Style Rules

- Use `.bold()` for titles and important values, not for whole paragraphs.
- Use `.dim()` / `.foregroundStyle(.palette.foregroundSecondary)` for help and secondary copy.
- Use `.palette.accent` for active titles, selected values, and primary emphasis.
- Use semantic palette colors for warning/error/success/info.
- Align label/value rows so state can be scanned quickly.
- Keep copy short. Prefer “Esc back” over “Press Escape to return to the previous page” in status bars.
- Use emoji/icons only when they improve scanning and degrade acceptably.

## Accessibility and Usability Checklist

Before shipping a TUIkit screen:

- [ ] Can a first-time user tell what screen they are on?
- [ ] Can they see the primary action without reading docs?
- [ ] Are keyboard controls visible in status bar or inline help?
- [ ] Is focus visible and predictable?
- [ ] Are focused, selected, disabled, and destructive states visually distinct?
- [ ] Does Escape go back/close consistently?
- [ ] Does Ctrl+C still exit the app?
- [ ] Does the screen work without color as the only signal?
- [ ] Are empty/loading/error states useful and actionable?
- [ ] Does it fit or degrade gracefully in a narrow terminal?

## Implementation Checklist for Agents

When building with TUIkit:

1. Search `Sources/TUIkitExample` for the closest page pattern before inventing a new pattern.
2. Start with data/state and visible controls; do not start with a command grammar.
3. Choose components from the guide above.
4. Add `.appHeader` and `.statusBarItems` early.
5. Add inline `KeyboardHelpSection` for non-trivial control sets.
6. Use stable `@State`, `Binding`, and route enums.
7. Use palette-driven styling, not raw ANSI.
8. Add tests for rendering, focus/key behavior, state updates, and status bar hints when practical.
9. Run `swift build` and relevant `swift test` before claiming done.

## References in This Repository

Useful example files to inspect:

- `Sources/TUIkitExample/ContentView.swift` — NavigationStack shell and root/destination routing.
- `Sources/TUIkitExample/Pages/MainMenuPage.swift` — root menu, feature boxes, app header.
- `Sources/TUIkitExample/Components/KeyboardHelpSection.swift` — inline keyboard guidance.
- `Sources/TUIkitExample/Components/DemoSection.swift` — simple section grouping.
- `Sources/TUIkitExample/Components/ValueDisplayRow.swift` — visible state display.
- `Sources/TUIkitExample/Pages/ButtonsPage.swift` — buttons, ButtonRow, focus help, live state.
- `Sources/TUIkitExample/Pages/ListPage.swift` — list selection, empty state, navigation help.
- `Sources/TUIkitExample/Pages/OverlaysPage.swift` — modal/status-bar mode changes.
- `Sources/TUIkitExample/Pages/ContainersPage.swift` — cards, panels, progress, section layout.
