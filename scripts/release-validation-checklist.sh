#!/usr/bin/env bash
set -euo pipefail

cat <<'CHECKLIST'
TUIkit release/manual terminal validation checklist
===================================================

Automated baseline:
  [ ] swift build
  [ ] swift test --parallel
  [ ] swiftlint
  [ ] ./scripts/test-linux.sh        # when Docker/Linux validation is available

For each terminal or multiplexer environment under test:
  [ ] Record terminal name/version, OS, shell, TERM, and date
  [ ] Run: make example
  [ ] App launches cleanly with no shell corruption
  [ ] Header shows platform info plus live FPS, e.g. macOS 27.0 · arm64 · 60.0 FPS
  [ ] FPS/focus/cursor animations continue while idle
  [ ] Keyboard navigation works: Tab, Shift+Tab, arrows, Enter, Space
  [ ] Async/demo work does not block input, animations, resize, or quit
  [ ] Rapid resize redraws without stale lines or crashes
  [ ] Quit with q restores prompt, cursor, echo, and line editing
  [ ] Quit with ESC restores prompt, cursor, echo, and line editing
  [ ] Quit with Ctrl+C restores prompt, cursor, echo, and line editing
  [ ] stty -a looks sane after each quit path

Multiplexer-specific checks for tmux/screen:
  [ ] Run make example inside the multiplexer
  [ ] Resize panes/windows
  [ ] Switch panes/windows and return
  [ ] Confirm colors, key input, focus, FPS refresh, and cleanup

After validation:
  [ ] Update docs/TerminalCompatibility.md only with environments actually tested
  [ ] Update docs/KnownLimitations.md for release-impacting caveats
  [ ] Keep release notes conservative; do not claim untested compatibility

Full checklist: docs/ReleaseValidationChecklist.md
CHECKLIST
