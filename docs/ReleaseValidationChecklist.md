# Release Validation Checklist

Use this checklist before tagging a release candidate or making production-readiness claims. It complements automated CI: CI can build and test rendering logic, but interactive terminal lifecycle behavior still requires manual validation in real terminals and multiplexers.

Do not mark an environment as validated unless it was actually tested. Prefer conservative notes such as “Not started” or “Smoke passed” in the [Terminal Compatibility Matrix](TerminalCompatibility.md).

## 1. Automated baseline

Run from the repository root:

```bash
swift build
swift test --parallel
swiftlint
```

For substantial changes, also run Linux validation when Docker is available:

```bash
./scripts/test-linux.sh
```

If a command cannot be run, record why in the release notes.

## 2. Example app lifecycle smoke test

Run:

```bash
make example
```

Validate each item in every terminal environment that is part of the release smoke matrix:

- [ ] App launches into the alternate screen without warnings or shell corruption.
- [ ] Header shows platform information and a live FPS value, for example `macOS 27.0 · arm64 · 60.0 FPS`.
- [ ] FPS value changes or refreshes while the app is running and does not visibly freeze during normal interaction.
- [ ] `Tab` and `Shift+Tab` move focus predictably.
- [ ] Focus and cursor animations continue to update while the app is idle.
- [ ] Lists, menus, sliders, steppers, text fields, and other interactive controls respond to arrow keys where applicable.
- [ ] `Enter` and `Space` activate focused controls where applicable.
- [ ] Async/demo work does not block keyboard input, animations, resize handling, or quit shortcuts.
- [ ] Rapid resize wider, narrower, taller, and shorter redraws without stale lines or crashes.
- [ ] Quit with `q` restores the shell prompt, cursor, echo, and line editing.
- [ ] Quit with `ESC` restores the shell prompt, cursor, echo, and line editing.
- [ ] Quit with `Ctrl+C` restores the shell prompt, cursor, echo, and line editing.
- [ ] After every quit path, `stty -a` looks sane for the shell. Use `stty sane` only to recover from a failure, then file an issue.

## 3. Terminal and multiplexer matrix

At minimum, smoke-test the environments that downstream users are expected to use. Suggested release-candidate matrix:

| Environment | Required for RC? | Notes to record |
| --- | --- | --- |
| Apple Terminal.app | Recommended on macOS | Version, macOS version, shell, `$TERM`. |
| iTerm2 | Recommended on macOS | Version, true-color setting, shell, `$TERM`. |
| Ghostty | Optional until available to maintainers | Version, OS, `$TERM`, Unicode/color notes. |
| WezTerm | Optional until available to maintainers | Version, OS, resize/color notes. |
| Alacritty | Optional until available to maintainers | Version, OS, keyboard/resize notes. |
| Kitty | Optional until available to maintainers | Version, OS, Unicode/keyboard notes. |
| VS Code integrated terminal | Recommended for developer-tooling users | VS Code version, shell integration caveats. |
| tmux | Recommended when multiplexers are in scope | tmux version, outer terminal, `$TERM` inside and outside tmux. |
| GNU screen | Optional unless user base requires it | screen version, outer terminal, `$TERM`. |
| Linux console | Optional / capability-limited | Distro, tty, color/input caveats. |

For tmux and screen:

- [ ] Launch `make example` inside the multiplexer.
- [ ] Resize panes and windows.
- [ ] Switch panes/windows and return.
- [ ] Confirm focus, colors, key input, FPS refresh, and cleanup still behave acceptably.

## 4. Compatibility notes for the release

Before publishing release notes:

- [ ] Update [TerminalCompatibility.md](TerminalCompatibility.md) with only the environments actually tested.
- [ ] Add terminal versions, OS/shell, `$TERM`, date, and direct-vs-multiplexer details.
- [ ] Link any caveats or failures to issues.
- [ ] Update [KnownLimitations.md](KnownLimitations.md) if a limitation affects production users.
- [ ] Keep claims conservative: “Smoke passed on iTerm2 3.x” is acceptable; “all terminals supported” is not.

## 5. Quick checklist helper

To print a concise terminal smoke checklist during release prep, run:

```bash
./scripts/release-validation-checklist.sh
```
