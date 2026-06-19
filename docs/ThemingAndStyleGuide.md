# Theming and Style Guide

TUIkit supports semantic terminal styling through palettes, foreground styles, borders, and component styles. Production apps should use these abstractions instead of raw ANSI strings.

## Principles

- Use color to reinforce meaning, not as the only signal.
- Keep one primary accent per screen.
- Preserve readable contrast in dark, light, monochrome, and low-color terminals.
- Make focused, selected, disabled, destructive, success, warning, and error states distinct without relying only on hue.
- Prefer spacing, alignment, and concise labels over heavy borders.

## Palettes

Choose a system palette at the app or scene boundary:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .palette(SystemPalette(.green))
    }
}
```

Available palettes include green, amber, red, violet, blue, and white. Validate each important screen in the palette your app ships.

## Borders and grouping

Use borders for meaningful grouping or active surfaces. Avoid boxing every row. In narrow terminals, content clarity is more important than decorative chrome.

## State styling

Recommended non-color cues:

| State | Non-color cue |
| --- | --- |
| Focused | cursor marker, brackets, underline, inverse style |
| Selected | checkmark, bullet, persistent marker |
| Disabled | dimmed style plus unavailable copy when needed |
| Error | `Error:` prefix, warning icon, recovery text |
| Success | `Done`/`Saved` copy, checkmark |
| Loading | spinner plus stable progress text |

## Copy

Keep labels short and specific. Error messages should say what happened and what the user can do next.

Bad:

```text
Failed.
```

Better:

```text
Could not save settings. Check the file path and try again.
```
