# Terminal Compatibility Matrix

This matrix tracks real-world terminal validation for TUIkit. It is a living production-readiness document, not a claim that every listed terminal is fully supported today.

Statuses:

- **Not started** — no current production-readiness validation recorded.
- **Smoke passed** — basic app launch, navigation, rendering, resize, and exit checked manually.
- **Validated** — smoke checks plus targeted checks for raw mode cleanup, alternate screen behavior, colors, Unicode width, and multiplexer behavior where applicable.
- **Known issues** — usable only with documented caveats.

## Compatibility matrix

| Environment | Platform | Status | Notes |
| --- | --- | --- | --- |
| Apple Terminal.app | macOS | Not started | Validate default macOS terminal behavior, colors, resize, and cleanup. |
| iTerm2 | macOS | Not started | Validate common developer setup and true-color behavior. |
| Ghostty | macOS/Linux | Not started | Validate modern terminal behavior and Unicode rendering. |
| WezTerm | macOS/Linux | Not started | Validate true-color, resize, and multiplexing-style panes. |
| Alacritty | macOS/Linux | Not started | Validate fast rendering, resize, and keyboard input. |
| Kitty | macOS/Linux | Not started | Validate true-color, keyboard input, and Unicode width behavior. |
| VS Code integrated terminal | macOS/Linux | Not started | Validate embedded terminal behavior and shortcut conflicts. |
| tmux | macOS/Linux | Not started | Validate nested terminal capabilities, resize propagation, and colors. |
| GNU screen | macOS/Linux | Not started | Validate lower-capability multiplexer behavior. |
| Linux console | Linux | Not started | Validate limited color and key handling behavior. |
| CI shell | macOS/Linux | Partial | `swift test --parallel` covers non-interactive rendering/unit behavior, not full terminal lifecycle behavior. |

## Manual smoke checklist

Run the example app (or print the concise checklist with `./scripts/release-validation-checklist.sh`):

```bash
make example
```

For each terminal environment, record:

- [ ] App launches without shell corruption or warnings.
- [ ] Initial screen renders correctly.
- [ ] Header includes platform information and live FPS, for example `macOS 27.0 · arm64 · 60.0 FPS`.
- [ ] FPS updates continue while idle and during normal interaction.
- [ ] `Tab` and `Shift+Tab` move focus predictably.
- [ ] Arrow keys work in lists, menus, sliders, steppers, and text fields where applicable.
- [ ] `Enter` and `Space` activate focused controls where applicable.
- [ ] `ESC` and `q` quit cleanly.
- [ ] Cursor visibility is restored after exit.
- [ ] Echo and canonical input are restored after exit.
- [ ] `stty -a` looks sane after exit.
- [ ] Narrow widths do not crash or corrupt the shell.
- [ ] Rapid resizing does not crash the app or leave stale lines.
- [ ] Focus and cursor animations continue updating.
- [ ] Async/demo work does not block input, animations, resize, or quit.
- [ ] Colors remain readable with the active palette.
- [ ] Disabled, focused, selected, and destructive states are visually distinguishable.
- [ ] Unicode sample content aligns acceptably for app needs.

## Targeted lifecycle checks

Use these for release-candidate validation or when touching terminal lifecycle code. The full release checklist lives in [ReleaseValidationChecklist.md](ReleaseValidationChecklist.md).

### Normal quit

1. Run `make example`.
2. Navigate through multiple screens/controls.
3. Quit with `q`.
4. Confirm the shell prompt, cursor, echo, and line editing are restored.

### Escape quit

1. Run `make example`.
2. Quit with `ESC`.
3. Confirm terminal state is restored.

### Interrupt handling

1. Run `make example`.
2. Send Ctrl-C.
3. Confirm terminal state is restored.
4. Run `stty sane` only if cleanup failed, then file an issue with terminal details.

### Resize behavior

1. Run `make example`.
2. Resize the terminal rapidly wider, narrower, taller, and shorter.
3. Confirm the app redraws without stale lines, crashes, or broken focus.
4. Quit and confirm terminal state is restored.

### Multiplexer behavior

Inside tmux or screen:

1. Run `make example`.
2. Resize panes.
3. Switch panes/windows and return.
4. Confirm colors, key input, focus, and cleanup still work.

## Rendering compatibility areas

### Width and wrapping

Validate:

- narrow widths near 20, 40, and 80 columns;
- long unbroken words;
- nested borders and panels;
- tables with constrained columns;
- lists with selected and disabled rows.

### Unicode

Validate representative content for:

- emoji: `✅ ⚠️ 🚀 👩‍💻`;
- combining marks: `é å ñ`;
- CJK: `日本語 中文 한국어`;
- box drawing and border styles;
- mixed ANSI styling and Unicode.

### Colors

Validate:

- monochrome or low-color terminal profiles;
- 8-color mode where available;
- 256-color mode;
- true-color mode;
- light and dark terminal themes;
- all built-in palettes.

## Current production-readiness interpretation

TUIkit has strong automated rendering and component tests, but the terminal compatibility matrix has not yet been validated across real terminal environments. Until at least the primary developer terminals and multiplexers have smoke-passed entries, terminal behavior should be treated as promising but not production-proven.

## Recording results

When validating a terminal, update the matrix with:

- terminal name and version;
- OS and shell;
- `$TERM` and color settings where relevant;
- whether validation was direct or inside tmux/screen;
- date of validation;
- any known caveats or linked issues.

Example note:

> Smoke passed on iTerm2 3.x, macOS 14.x, zsh, `TERM=xterm-256color`, outside tmux, 2026-06-18. Resize and normal quit passed; Unicode emoji alignment has minor font-dependent variation.
