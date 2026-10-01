#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
#
# Adds localization keys to *both* ARB files in one step, so English and Bengali can never
# drift apart. The insertion is textual and preserves the existing file formatting (the
# template keeps one-line "@key": {...} metadata, which a JSON re-serialization would
# expand and pollute the diff with).
#
# Usage:
#   python3 tool/l10n_add.py keys.json
#
# where keys.json is:
#   {
#     "voiceTitle": {
#       "en": "Voice",
#       "bn": "ভয়েস",
#       "placeholders": {"name": "String"}     # optional
#     }
#   }
#
# Existing keys are replaced in place. Every added key is validated by
# tool/static_checks.py (header, placeholder parity, en/bn parity).

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EN = ROOT / "lib" / "l10n" / "app_en.arb"
BN = ROOT / "lib" / "l10n" / "app_bn.arb"


def render_entry(key: str, value: str, placeholders: dict[str, str] | None) -> str:
    lines = [f'  "{key}": {json.dumps(value, ensure_ascii=False)}']
    if placeholders:
        rendered = ", ".join(
            f'"{name}": {{"type": "{kind}"}}' for name, kind in placeholders.items()
        )
        lines.append(f'  "@{key}": {{"placeholders": {{{rendered}}}}}')
    return ",\n".join(lines)


def upsert(path: Path, key: str, value: str, placeholders: dict[str, str] | None) -> bool:
    """Replaces or appends one key. Returns True when the file changed."""
    text = path.read_text(encoding="utf-8")
    existing = json.loads(text)

    entry = render_entry(key, value, placeholders)
    needle = f'  "{key}": '
    if needle in text:
        if path == BN or path == EN:
            # Replace the value line (and leave any existing metadata alone).
            lines = text.splitlines()
            for index, line in enumerate(lines):
                if line.startswith(needle):
                    suffix = "," if line.rstrip().endswith(",") else ""
                    lines[index] = f'  "{key}": {json.dumps(value, ensure_ascii=False)}{suffix}'
                    break
            text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
        else:  # pragma: no cover - defensive
            text = text.replace(needle, f'  "{key}": ')
        path.write_text(text, encoding="utf-8")
        return True

    # Append before the final closing brace, keeping the trailing newline.
    closing = text.rstrip().rfind("}")
    prefix = text[:closing].rstrip()
    if not prefix.endswith(","):
        prefix += ","
    updated = f"{prefix}\n{entry}\n}}\n"
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    for key, entry in payload.items():
        en_value = entry["en"]
        bn_value = entry["bn"]
        placeholders = entry.get("placeholders")
        if not placeholders:
            placeholders = {
                name: "String"
                for name in json.loads(json.dumps(entry.get("placeholder_types", {})))
            }
        upsert(EN, key, en_value, placeholders or None)
        upsert(BN, key, bn_value, placeholders or None)
        print(f"added {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
