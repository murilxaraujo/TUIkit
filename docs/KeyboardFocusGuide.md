# Keyboard and Focus Guide

TUIkit applications should be fully usable from the keyboard. This guide documents the conventions expected for release-candidate quality apps and framework components.

## Core conventions

- `Tab` moves to the next focusable control.
- `Shift+Tab` moves to the previous focusable control.
- Arrow keys move within controls that own a collection or value, such as lists, menus, sliders, steppers, text fields, and split views.
- `Enter` activates the focused default action when applicable.
- `Space` toggles or activates the focused control when that matches platform convention.
- `ESC` backs out of transient UI such as dialogs, or quits the example app from the top level.
- `q` is reserved by the example app as a global quit shortcut; production apps may choose their own global shortcuts, but should display them in the status bar.

## Focus identity

Use stable, deterministic focus IDs for repeated or dynamic content:

```swift
ForEach(items, id: \.id) { item in
    Button(item.title) { select(item.id) }
        .focusID("item.\(item.id)")
}
```

Avoid row indices as persistent focus IDs when rows can be inserted, removed, filtered, or reordered. Prefer model IDs so focus follows user intent rather than screen position.

## Disabled controls

Disabled controls must not participate in focus navigation. They should still render useful state and explain why the action is unavailable when that context is not obvious.

```swift
Button("Delete") { deleteSelection() }
    .disabled(selection == nil)
```

## Focus versus selection

Focused state answers “where will the next key act?” Selection answers “which item is chosen?” They must remain visually distinguishable, including in monochrome terminals. Pair color with shape, text, or placement.

Recommended patterns:

- focused row: leading cursor, bracket, underline, or inverse video;
- selected row: checkmark, bullet, or persistent marker;
- disabled row: dimmed style plus unavailable copy where space allows.

## Sections and modals

Use focus sections to group complex layouts. Modal surfaces should contain focus until dismissed, and dismissal shortcuts should be discoverable in the modal body or status bar.

## Status bar hints

Every screen with non-obvious shortcuts should expose them through `.statusBarItems`:

```swift
.statusBarItems {
    StatusBarItem(shortcut: "Tab", label: "next")
    StatusBarItem(shortcut: "Enter", label: "select")
    StatusBarItem(shortcut: "q", label: "quit")
}
```

Keep hints short and contextual. Prefer four or fewer primary hints on narrow screens.

## Test expectations

Framework controls and production app screens should include tests for:

- focus order;
- disabled focus exclusion;
- focused/selected visual distinction;
- modal focus containment;
- section navigation;
- preservation of focus when collection data changes.
