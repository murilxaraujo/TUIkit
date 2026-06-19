# Troubleshooting

This guide collects common terminal and development issues for TUIkit apps.

## Terminal input or echo is broken after exit

Run:

```bash
stty sane
```

Then file an issue with terminal name/version, OS, shell, `$TERM`, whether you were inside tmux/screen, and the quit path used (`q`, `ESC`, `Ctrl+C`, crash, or thrown error).

## Colors look wrong

Check `$TERM` and terminal color settings. Validate in 8-color, 256-color, and true-color modes where your users are likely to run the app. Do not depend on color alone for meaning.

## Unicode or emoji alignment is off

Unicode width can vary by terminal, font, locale, and emoji presentation. Prefer ASCII or box-drawing alternatives for critical alignment. Test representative CJK, combining mark, and emoji strings before claiming support.

## Keyboard shortcuts do not fire

Integrated terminals and multiplexers may intercept shortcuts. Test direct terminal use first, then tmux/screen or VS Code. Surface alternate shortcuts for important actions when possible.

## Resize leaves stale lines

Record terminal details and whether alternate screen was enabled. Try reproducing with `make example`, then update `docs/TerminalCompatibility.md` if it is environment-specific.

## SwiftPM build issues

Run commands from the package root:

```bash
swift package reset
swift build
swift test --parallel
```

If a package-manager command appears stuck, ensure another `swift build` or `swift test` is not running in the same checkout.
