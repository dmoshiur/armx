#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
"""Remove relative imports that `static_checks.py` reports as unused.

Kept as a separate script so the removal is reviewable: it deletes exactly the imports the
checker named, nothing else, and prints what it removed.
"""

from __future__ import annotations

import re
import subprocess
import sys
from collections import defaultdict

ROOT = "/home/user/armx"


def main() -> int:
    result = subprocess.run(
        [sys.executable, "tool/static_checks.py", "--quiet"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    pattern = re.compile(r"FAIL\s+unused relative import '([^']+)' in (.+)$")
    grouped: dict[str, list[str]] = defaultdict(list)
    for line in result.stdout.splitlines():
        match = pattern.search(line.strip())
        if match:
            grouped[match.group(2)].append(match.group(1))

    if not grouped:
        print("nothing to prune")
        return 0

    for path, imports in grouped.items():
        with open(f"{ROOT}/{path}", encoding="utf-8") as handle:
            source = handle.read()
        for target in imports:
            before = source
            source = re.sub(
                r"^import\s+'" + re.escape(target) + r"';\n", "", source, count=1, flags=re.M
            )
            if source == before:
                print(f"could not remove {target} from {path}")
            else:
                print(f"removed {target} from {path}")
        with open(f"{ROOT}/{path}", "w", encoding="utf-8") as handle:
            handle.write(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
