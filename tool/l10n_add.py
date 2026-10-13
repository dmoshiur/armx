#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
"""Add localization keys to BOTH ARB files atomically.

Usage:
    python3 tool/l10n_add.py keys.json

`keys.json` is a list of objects:

    [
      {"key": "loginTitle", "en": "Sign in", "bn": "সাইন ইন",
       "placeholders": {"email": {"type": "String", "example": "a@b.com"}},
       "description": "Login screen headline"}
    ]

`en`, `bn` and `description` are optional when the key already exists (a rewrite), but a
new key needs at least `en` and `bn`. The script refuses to write a half-applied change:
English is updated first in memory, Bengali second, and both files are written only when
both merges succeed. Existing keys keep their original position so diffs stay small.
"""

from __future__ import annotations

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN_PATH = os.path.join(ROOT, "lib", "l10n", "app_en.arb")
BN_PATH = os.path.join(ROOT, "lib", "l10n", "app_bn.arb")


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def dump(path: str, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def merge(target: dict, entry: dict, is_template: bool) -> None:
    key = entry["key"]
    body = entry.get("en" if is_template else "bn")
    if body is None:
        if key in target:
            return
        raise SystemExit(f"key '{key}' is new and needs an "
                         f"'{('en' if is_template else 'bn')}' value")
    if key in target and target[key] == body:
        return
    target[key] = body
    if is_template:
        meta: dict = {}
        if entry.get("placeholders"):
            meta["placeholders"] = entry["placeholders"]
        if entry.get("description"):
            meta["description"] = entry["description"]
        if meta:
            target[f"@{key}"] = meta
    else:
        if entry.get("description") and f"@{key}" not in target:
            target[f"@{key}"] = {"description": entry["description"]}


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    with open(argv[1], encoding="utf-8") as handle:
        entries = json.load(handle)
    if not isinstance(entries, list):
        raise SystemExit("keys.json must contain a list of objects")

    en = load(EN_PATH)
    bn = load(BN_PATH)
    added = 0
    for entry in entries:
        if "key" not in entry:
            raise SystemExit(f"entry without a 'key': {entry!r}")
        before = entry["key"] in en
        merge(en, entry, is_template=True)
        merge(bn, entry, is_template=False)
        if not before:
            added += 1
    dump(EN_PATH, en)
    dump(BN_PATH, bn)
    print(f"applied {len(entries)} key(s) to app_en.arb and app_bn.arb "
          f"({added} new)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
