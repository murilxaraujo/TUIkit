# Release Process

TUIkit releases should be tagged, changelogged, documented, and validated before publication.

## Version selection

- Pre-1.0 feature releases use `0.x.0`.
- Pre-1.0 patch releases use `0.x.y`.
- Release candidates use a prerelease suffix such as `0.7.0-rc.1`.
- Do not tag an RC until automated validation passes and manual terminal-validation gaps are explicitly accepted or completed.

## Required checks

```bash
swift build
swift test --parallel
swiftlint
swift package --allow-writing-to-directory docc-output \
  generate-documentation \
  --target TUIkit \
  --output-path docc-output \
  --transform-for-static-hosting
./scripts/release-validation-checklist.sh
```

Run `./scripts/test-linux.sh` when Docker/Linux validation is available.

## Manual validation

Use `docs/ReleaseValidationChecklist.md` and record only actually-tested terminal results in `docs/TerminalCompatibility.md`.

## Release notes

Before tagging:

1. Move `CHANGELOG.md` entries from `Unreleased` into a versioned section.
2. Include migration notes for breaking changes.
3. Include known limitations and terminal compatibility status.
4. Confirm README installation examples use a tag appropriate for the release line.
5. Generate DocC and keep docs clearly associated with the release tag or labeled as main-branch docs.

## Tagging

After validation and maintainer approval:

```bash
git tag -a <version> -m "TUIkit <version>"
git push origin <version>
```

Do not tag from a dirty working tree.
