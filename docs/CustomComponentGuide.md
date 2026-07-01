# Custom Component Guide

Custom TUIkit components should feel like SwiftUI views while respecting terminal constraints.

## Start with composition

Prefer composing existing views and modifiers before introducing a custom renderer:

```swift
struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack {
            Text(key).bold()
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
```

Use private `_*Core` renderable views only when composition cannot express the behavior or when direct buffer control is required for performance or terminal-specific output.

## API design checklist

- Match SwiftUI naming and parameter order where an equivalent exists.
- Prefer `@ViewBuilder` closures for caller-supplied content.
- Expose styling through modifiers or style protocols when practical.
- Keep public controls as real `View` values with `body: some View`.
- Propagate environment and modifiers through child content.
- Avoid hidden global state; use bindings, environment, preferences, or explicit dependencies.

## Layout and rendering

Design for width `0`, `1`, narrow terminals, and long text. Render output should degrade gracefully instead of trapping.

Use these checks for complex components:

- empty data;
- one item;
- many items;
- narrow width;
- Unicode and ANSI-styled text;
- disabled, focused, selected, loading, and error states.

## Interaction

Interactive components need stable focus IDs, disabled-state exclusion, and clear keyboard behavior. Document non-standard shortcuts and surface important hints in the status bar.

## Tests

Add tests for:

- body/composition output;
- modifier and environment propagation;
- focus registration and disabled exclusion;
- key handling;
- narrow rendering;
- localization if the component displays built-in strings.
