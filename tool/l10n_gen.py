#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
"""Regenerate lib/l10n/app_en.arb and lib/l10n/app_bn.arb from tool/l10n_keys.py.

    python3 tool/l10n_gen.py

Refuses to write when a key is duplicated, when a Bengali string is missing, or when the
placeholder sets of the two languages differ — the same invariants `tool/static_checks.py`
re-checks on every run, enforced here at the point of authorship.
"""

from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from l10n_keys import IDENTICAL_OK, KEYS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "lib", "l10n")
PLACEHOLDER = re.compile(r"\{(\w+)\}")


def main() -> int:
    en: dict = {}
    bn: dict = {}
    seen: set[str] = set()
    problems: list[str] = []

    for entry in KEYS:
        key = entry["key"]
        if key in seen:
            problems.append(f"duplicate key '{key}'")
            continue
        seen.add(key)
        english = entry.get("en")
        bengali = entry.get("bn")
        if not english or not bengali:
            problems.append(f"'{key}' is missing an en or bn string")
            continue
        en_placeholders = set(PLACEHOLDER.findall(english))
        if en_placeholders != set(PLACEHOLDER.findall(bengali)):
            problems.append(
                f"'{key}' placeholder mismatch: "
                f"en={sorted(en_placeholders)} bn={sorted(PLACEHOLDER.findall(bengali))}"
            )
            continue
        if key not in IDENTICAL_OK and english == bengali:
            problems.append(f"'{key}' has an untranslated Bengali string")
            continue

        en[key] = english
        bn[key] = bengali
        meta: dict = {}
        if entry.get("description"):
            meta["description"] = entry["description"]
        if entry.get("placeholders"):
            meta["placeholders"] = entry["placeholders"]
        if meta:
            en[f"@{key}"] = meta
        elif key in IDENTICAL_OK:
            # Document why an identical string is deliberate, so a translator knows.
            en[f"@{key}"] = {
                "description": "Kept in Latin script in both languages by design."
            }

    if problems:
        for problem in problems:
            print(f"FAIL  {problem}")
        return 1

    os.makedirs(OUT, exist_ok=True)
    for path, data in (
        (os.path.join(OUT, "app_en.arb"), en),
        (os.path.join(OUT, "app_bn.arb"), bn),
    ):
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")

    print(f"wrote {len(seen)} keys to app_en.arb and app_bn.arb")
    return 0


if __name__ == "__main__":
    sys.exit(main())
