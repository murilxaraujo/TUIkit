# Terminal Input Policy

This document records the release-candidate policy for terminal input features that vary across emulators and multiplexers.

## Bracketed paste

Bracketed paste support is **not claimed for the first release candidate**. Applications should treat pasted text as ordinary terminal input unless a future TUIkit release explicitly enables and tests bracketed paste mode.

Before enabling bracketed paste by default, TUIkit should add:

- terminal setup/cleanup tests for enabling and disabling paste mode;
- parser coverage for paste start/end escape sequences;
- validation inside direct terminals and tmux/screen;
- documentation for text fields and custom key handlers.

## Mouse input

Mouse input is **out of scope for the first release candidate**. TUIkit remains keyboard-first by default.

A future mouse policy should define:

- whether mouse reporting is opt-in per app or per view;
- supported terminal reporting modes;
- focus/selection semantics for click and scroll;
- cleanup behavior on normal and interrupted exits;
- accessibility and keyboard-equivalent requirements.

## RC implication

RC release notes should not claim bracketed paste or mouse support. If users need those capabilities, track them as feature requests rather than compatibility bugs.
