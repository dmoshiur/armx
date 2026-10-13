#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
"""Fails the build when line coverage drops below the floor.

Reads the lcov file `flutter test --coverage` writes. Two numbers matter and both are
reported: the whole project, and the files a change touched. A gate on the total alone lets a
well-tested module hide an untested one, so untested files can be named explicitly with
`--require`, which insists on a per-file floor as well.

Usage:
    python3 tool/coverage_gate.py [--threshold 70] [--lcov coverage/lcov.info]
                                  [--require lib/core/confirm/confirm_policy.dart]
                                  [--require-prefix lib/core]
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LCOV = os.path.join(ROOT, "coverage", "lcov.info")

# Records look like:
#   SF:lib/core/theme/colors.dart
#   DA:12,1
#   LF:40
#   LH:36
SF_RE = re.compile(r"^SF:(.+)$")
DA_RE = re.compile(r"^DA:(\d+),(\d+)$")


def parse_lcov(path: str) -> dict[str, tuple[int, int]]:
    """Maps file → (lines found, lines hit)."""
    files: dict[str, list[int]] = {}
    current: str | None = None
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            file_match = SF_RE.match(line)
            if file_match:
                current = file_match.group(1).replace(os.sep, "/")
                files.setdefault(current, [0, 0])
                continue
            da_match = DA_RE.match(line)
            if da_match and current is not None:
                files[current][0] += 1
                if int(da_match.group(2)) > 0:
                    files[current][1] += 1
    return {name: (found, hit) for name, (found, hit) in files.items()}


def percent(found: int, hit: int) -> float:
    return 100.0 if found == 0 else (hit / found) * 100.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lcov", default=DEFAULT_LCOV)
    parser.add_argument(
        "--threshold",
        type=float,
        default=70.0,
        help="minimum project-wide line coverage percentage (default: 70)",
    )
    parser.add_argument(
        "--require",
        action="append",
        default=[],
        help="a file that must meet --threshold on its own (repeatable)",
    )
    parser.add_argument(
        "--require-prefix",
        action="append",
        default=[],
        help="every file under this prefix must meet --threshold (repeatable)",
    )
    args = parser.parse_args()

    if not os.path.exists(args.lcov):
        print(f"coverage gate: no lcov file at {args.lcov}", file=sys.stderr)
        print("run: flutter test --coverage", file=sys.stderr)
        return 1

    coverage = parse_lcov(args.lcov)
    if not coverage:
        print("coverage gate: the lcov file has no records", file=sys.stderr)
        return 1

    total_found = sum(found for found, _ in coverage.values())
    total_hit = sum(hit for _, hit in coverage.values())
    total = percent(total_found, total_hit)

    failures: list[str] = []
    print("per-file coverage, lowest first:")
    for name, (found, hit) in sorted(
        coverage.items(), key=lambda item: percent(item[1][0], item[1][1])
    ):
        share = percent(found, hit)
        marker = "  " if share >= args.threshold else "!!"
        print(f"  {marker} {share:6.2f}%  {name} ({hit}/{found})")

    print(f"project line coverage: {total:.2f}% ({total_hit}/{total_found})")
    if total < args.threshold:
        failures.append(
            f"project coverage {total:.2f}% is below the {args.threshold:.0f}% floor"
        )

    # A file the gate names must clear the floor on its own.
    for name in args.require:
        found, hit = coverage.get(name, (0, 0))
        share = percent(found, hit)
        print(f"required file {name}: {share:.2f}% ({hit}/{found})")
        if found == 0 or share < args.threshold:
            failures.append(f"{name} is at {share:.2f}%, below {args.threshold:.0f}%")

    # Same, for a whole directory tree.
    for prefix in args.require_prefix:
        matched = {
            name: values
            for name, values in coverage.items()
            if name.startswith(prefix)
        }
        if not matched:
            failures.append(f"no coverage records under {prefix}")
            continue
        found = sum(values[0] for values in matched.values())
        hit = sum(values[1] for values in matched.values())
        share = percent(found, hit)
        print(f"required prefix {prefix}: {share:.2f}% ({hit}/{found})")
        if share < args.threshold:
            failures.append(f"{prefix} is at {share:.2f}%, below {args.threshold:.0f}%")

    untested = [
        name
        for name, (found, hit) in coverage.items()
        if found > 0 and hit == 0
    ]
    if untested:
        print(f"files with no covered lines ({len(untested)}):")
        for name in sorted(untested):
            print(f"    {name}")

    if failures:
        print("\ncoverage gate FAILED:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    print("\ncoverage gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
