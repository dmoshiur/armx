#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
#
# Line-coverage gate over an lcov info file. Used by CI (see .github/workflows/ci.yml).
#
#   python3 tool/coverage_gate.py coverage/core_data.info 70
#
# Exits non-zero when the measured line coverage is below the threshold.

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    path = Path(sys.argv[1])
    threshold = float(sys.argv[2])
    if not path.exists():
        print(f"coverage file not found: {path}")
        return 1

    found = hit = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("LF:"):
            found += int(line[3:])
        elif line.startswith("LH:"):
            hit += int(line[3:])

    if found == 0:
        print("no coverage records found")
        return 1
    percent = hit / found * 100
    print(f"line coverage: {percent:.2f}% ({hit}/{found}) — gate {threshold:.0f}%")
    if percent + 1e-9 < threshold:
        print("FAILED: coverage below the gate")
        return 1
    print("PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
