#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/docs/PublicAPIInventory.md}"

python3 - "$ROOT_DIR" "$OUTPUT_PATH" <<'PY'
import collections
import datetime
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])

source_root = root / "Sources"
pattern = re.compile(r"^public\s+(?:(final)\s+)?(struct|class|actor|enum|protocol|func|var|let|typealias|extension)\s+([^\s:<({=]+)")

stable_tuikit_dirs = {
    "App", "Environment", "Focus", "Localization", "Modifiers", "Notification",
    "State", "StatusBar", "Styles", "Views",
}
stable_view_names = {
    "View", "ViewBuilder", "ViewModifier", "ModifiedView", "EmptyView", "AnyView",
    "TupleView", "ConditionalView", "ViewArray", "EquatableView", "State", "Binding",
    "Environment", "EnvironmentModifier", "ObjectEnvironmentModifier",
}
stable_styling_names = {
    "Color", "ANSIColor", "SemanticColor", "BorderStyle", "ContentMode", "TextContentType",
    "TextCursorStyle", "Appearance", "Palette", "SystemPalette", "Cyclable",
}
internal_name_fragments = (
    "Core", "Cache", "Storage", "Manager", "Service", "Protocol", "Context",
    "Child", "Hydration", "Registration", "TerminalProtocol",
)
internal_exact = {
    "RenderContext", "Renderable", "Layoutable", "renderToBuffer", "ChildView", "ChildInfo",
    "ChildInfoProvider", "ChildViewProvider", "makeChildInfo", "measureChild", "renderChild",
    "resolveChildInfos", "resolveChildViews", "RenderCache", "StateStorage", "StateBox",
    "AppState", "StorageBackend", "JSONFileStorage", "TerminalProtocol", "FocusManager",
    "NotificationService", "LocalizationService", "StatusBarState", "extractBadgeValue",
}

records = []
for path in sorted(source_root.rglob("*.swift")):
    rel = path.relative_to(root)
    parts = rel.parts
    target = parts[1] if len(parts) > 1 else "Unknown"
    area = parts[2] if len(parts) > 2 else ""
    for line_no, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.strip()
        match = pattern.match(stripped)
        if not match:
            continue
        kind = match.group(2)
        name = match.group(3)
        if kind == "extension":
            # Extension members are represented by their own public declarations.
            classification = "Context extension"
            rationale = "Public extension scope; classify member declarations individually."
        elif target == "TUIkit" and area in stable_tuikit_dirs:
            if name in internal_exact or name.endswith("Modifier") or any(fragment in name for fragment in internal_name_fragments):
                classification = "Internal-leak candidate"
                rationale = "Public app-facing module symbol that appears implementation-oriented and needs boundary review."
            else:
                classification = "Stable candidate"
                rationale = "Primary app-facing TUIkit API surface."
        elif target == "TUIkitView":
            if name in stable_view_names:
                classification = "Stable candidate"
                rationale = "Core declarative view API intended for SwiftUI-like app code."
            elif name in internal_exact or any(fragment in name for fragment in internal_name_fragments):
                classification = "Internal-leak candidate"
                rationale = "Rendering/state engine detail exposed across module boundaries; review before 1.0."
            else:
                classification = "Experimental"
                rationale = "Lower-level view engine API requiring stability review."
        elif target == "TUIkitStyling":
            if name in stable_styling_names:
                classification = "Stable candidate"
                rationale = "Reusable styling value or extension point likely intended for app authors."
            elif any(fragment in name for fragment in internal_name_fragments):
                classification = "Experimental"
                rationale = "Styling service/registry lifecycle requires review."
            else:
                classification = "Experimental"
                rationale = "Styling API requiring explicit stability review."
        elif target == "TUIkitImage":
            classification = "Experimental"
            rationale = "Image loading/conversion API needs capability, performance, and terminal policy review."
        elif target == "TUIkitCore":
            if name in {"KeyEvent", "Key", "EnvironmentKey", "EnvironmentValues", "PreferenceKey", "PreferenceValues", "ProposedSize", "ViewSize", "FrameBuffer", "ViewIdentity"}:
                classification = "Experimental"
                rationale = "Useful low-level primitive, but lower-level module stability is not finalized."
            else:
                classification = "Internal-leak candidate"
                rationale = "Low-level implementation detail exposed publicly; review before 1.0."
        else:
            classification = "Experimental"
            rationale = "Needs explicit stability review."
        records.append({
            "target": target,
            "area": area or "Root",
            "path": str(rel),
            "line": line_no,
            "kind": kind,
            "name": name,
            "signature": stripped,
            "classification": classification,
            "rationale": rationale,
        })

by_target = collections.defaultdict(list)
by_class = collections.Counter()
for record in records:
    by_target[record["target"]].append(record)
    by_class[record["classification"]] += 1

def esc(text):
    return text.replace("|", "\\|")

lines = []
lines.append("# Public API Inventory")
lines.append("")
lines.append("This file is generated by `./scripts/dump-public-api.sh` and provides the starting point for Workstream 1: public API stabilization.")
lines.append("")
lines.append("> Classification is intentionally conservative. Treat this as an audit queue, not as a final 1.0 promise.")
lines.append("")
lines.append(f"Generated: {datetime.date.today().isoformat()}")
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"Total public declarations found: **{len(records)}**")
lines.append("")
lines.append("### By target")
lines.append("")
lines.append("| Target | Public declarations |")
lines.append("|--------|---------------------|")
for target in sorted(by_target):
    lines.append(f"| `{target}` | {len(by_target[target])} |")
lines.append("")
lines.append("### By classification")
lines.append("")
lines.append("| Classification | Count |")
lines.append("|----------------|-------|")
for classification, count in sorted(by_class.items()):
    lines.append(f"| {classification} | {count} |")
lines.append("")
lines.append("## Classification key")
lines.append("")
lines.append("- **Stable candidate**: likely intended to become part of the 1.0 app-author API after documentation and compatibility review.")
lines.append("- **Experimental**: usable for experimentation or advanced users, but not yet a compatibility promise.")
lines.append("- **Internal-leak candidate**: likely exposed because of current module boundaries or implementation needs; should be hidden, wrapped, or explicitly promoted before 1.0.")
lines.append("- **Context extension**: public extension scope; classify concrete public members separately.")
lines.append("")
lines.append("## Next review actions")
lines.append("")
lines.append("1. Review every **Internal-leak candidate** and decide whether to make it internal, wrap it behind app-facing API, or promote it to experimental/stable.")
lines.append("2. Add documentation comments to every **Stable candidate**.")
lines.append("3. Mark **Experimental** APIs in docs or comments where app authors may encounter them.")
lines.append("4. Move accepted breaking changes into `CHANGELOG.md` migration notes.")
lines.append("")

for target in sorted(by_target):
    lines.append(f"## {target}")
    lines.append("")
    lines.append("| Classification | Kind | Name | Location | Rationale |")
    lines.append("|----------------|------|------|----------|-----------|")
    for r in by_target[target]:
        loc = f"`{r['path']}:{r['line']}`"
        lines.append(f"| {r['classification']} | `{r['kind']}` | `{esc(r['name'])}` | {loc} | {esc(r['rationale'])} |")
    lines.append("")

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines) + "\n")
PY

echo "Wrote $OUTPUT_PATH"
