# Supported Platforms

TUIkit is a Swift 6.0 package intended for macOS and Linux.

## Swift

- Minimum Swift tools version: 6.0.
- Public APIs should remain source-compatible with Swift 6.0 during the pre-1.0 release-candidate line.

## Apple platforms

- Package manifest minimum: macOS 14.
- Terminal behavior must be validated in real terminal emulators before compatibility claims are made.

## Linux

- Linux is supported through SwiftPM without an explicit platform declaration.
- Validate Linux changes with `./scripts/test-linux.sh` when Docker is available.

## Terminal environments

The authoritative terminal status is `docs/TerminalCompatibility.md`. Until an environment is smoke-passed or validated there, treat compatibility as unproven.

## Versioning

See `docs/APIStability.md` for SemVer, pre-1.0 compatibility, and migration-note rules.
