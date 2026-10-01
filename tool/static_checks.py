#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
#
# Offline source sanity checks for the A.R.M.X AI client.
#
# This script is a *supplement* to `flutter analyze` + `flutter test`, never a replacement.
# It exists so that structural mistakes which the Dart analyzer would catch (missing files,
# unresolved imports, unknown localization keys, unbalanced brackets, missing licence
# headers, hardcoded secrets, non-TLS URLs) are still caught in environments where the
# Flutter SDK / pub.dev are unavailable.
#
# Usage:
#   python3 tool/static_checks.py            # check the repository
#   python3 tool/static_checks.py --quiet    # only print failures

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

HEADER = "Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved."
HEADER_EXEMPT = {
    "assets/fonts/OFL-Inter.txt",
    "assets/fonts/OFL-JetBrainsMono.txt",
    "assets/images/README.md",
    "assets/models/README.md",
}
SOURCE_SUFFIXES = {".dart", ".kt", ".xml", ".yaml", ".arb", ".gradle"}
SOURCE_ROOTS = ("lib", "test", "integration_test", "android", "tool")

failures: list[str] = []
notes: list[str] = []


def fail(path: Path | str, message: str) -> None:
    failures.append(f"{path}: {message}")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def dart_files() -> list[Path]:
    return sorted(p for p in (ROOT / "lib").rglob("*.dart"))


def strip_dart_code(source: str) -> str:
    """Removes comments and string literals so bracket checks are not confused by text."""
    out: list[str] = []
    i = 0
    length = len(source)
    while i < length:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < length else ""
        # Line comment
        if ch == "/" and nxt == "/":
            while i < length and source[i] != "\n":
                i += 1
            continue
        # Block comment (Dart block comments nest)
        if ch == "/" and nxt == "*":
            depth = 1
            i += 2
            while i < length and depth:
                if source[i] == "/" and i + 1 < length and source[i + 1] == "*":
                    depth += 1
                    i += 2
                    continue
                if source[i] == "*" and i + 1 < length and source[i + 1] == "/":
                    depth -= 1
                    i += 2
                    continue
                i += 1
            continue
        # Raw / normal string literals
        if ch in "'\"" or (ch == "r" and nxt in "'\""):
            raw = ch == "r"
            if raw:
                i += 1
                ch = source[i]
            quote = ch
            triple = source[i : i + 3] == quote * 3
            i += 3 if triple else 1
            while i < length:
                if source[i] == "\\" and not raw:
                    i += 2
                    continue
                if triple:
                    if source[i : i + 3] == quote * 3:
                        i += 3
                        break
                elif source[i] == quote:
                    i += 1
                    break
                if source[i] == "\n" and not triple:
                    break
                i += 1
            out.append(" S ")  # placeholder keeps offsets irrelevant
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def check_headers() -> None:
    for root in SOURCE_ROOTS:
        base = ROOT / root
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
                continue
            relative = rel(path)
            if relative in HEADER_EXEMPT or path.suffix in {".arb", ".json"}:
                # JSON cannot carry comments; the ARB files inherit the repo licence via
                # lib/l10n/README.md and the generated sources.
                continue
            if "generated" in path.parts or "build" in path.parts:
                continue
            try:
                head = path.read_text(encoding="utf-8")[:2000]
            except UnicodeDecodeError:
                continue
            if HEADER not in head:
                fail(relative, "missing copyright header")


def check_brackets() -> None:
    pairs = {")": "(", "]": "[", "}": "{"}
    for path in dart_files():
        code = strip_dart_code(path.read_text(encoding="utf-8"))
        stack: list[str] = []
        for ch in code:
            if ch in "([{":
                stack.append(ch)
            elif ch in ")]}":
                if not stack or stack[-1] != pairs[ch]:
                    fail(rel(path), f"unbalanced '{ch}'")
                    break
                stack.pop()
        else:
            if stack:
                fail(rel(path), f"unclosed brackets: {''.join(stack)}")


def is_generated_target(target: str) -> bool:
    """True for build_runner / gen-l10n outputs, which are intentionally not committed."""
    if target.endswith(".g.dart") or target.endswith(".freezed.dart"):
        return True
    return "l10n/generated/" in target


def check_imports() -> None:
    import_re = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.MULTILINE)
    for path in dart_files():
        source = path.read_text(encoding="utf-8")
        for target in import_re.findall(source):
            if target.startswith("package:armx_ai/"):
                resolved = ROOT / "lib" / target[len("package:armx_ai/") :]
            elif target.startswith("package:"):
                continue
            elif target.startswith("dart:"):
                continue
            else:
                resolved = (path.parent / target).resolve()
            if is_generated_target(target):
                continue
            if not resolved.exists():
                fail(rel(path), f"unresolved target '{target}'")


def check_localization() -> None:
    en_path = ROOT / "lib" / "l10n" / "app_en.arb"
    bn_path = ROOT / "lib" / "l10n" / "app_bn.arb"
    try:
        en = json.loads(en_path.read_text(encoding="utf-8"))
        bn = json.loads(bn_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail("lib/l10n", f"invalid ARB JSON: {error}")
        return

    en_keys = {k for k in en if not k.startswith("@")}
    bn_keys = {k for k in bn if not k.startswith("@")}
    for missing in sorted(en_keys - bn_keys):
        fail("lib/l10n/app_bn.arb", f"missing translation for '{missing}'")
    for extra in sorted(bn_keys - en_keys):
        fail("lib/l10n/app_bn.arb", f"key '{extra}' is not in the template file")

    # Placeholder declarations: every {name} in a value must be declared in the @-metadata.
    for key in sorted(en_keys):
        value = en[key]
        if not isinstance(value, str):
            continue
        placeholders = set(re.findall(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}", value))
        declared = set((en.get("@" + key, {}) or {}).get("placeholders", {}))
        undeclared = placeholders - declared
        if undeclared:
            fail("lib/l10n/app_en.arb", f"'{key}' uses undeclared placeholders {sorted(undeclared)}")
        bn_placeholders = set(re.findall(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}", bn.get(key, "")))
        if placeholders != bn_placeholders:
            fail(
                "lib/l10n/app_bn.arb",
                f"'{key}' placeholder mismatch {sorted(bn_placeholders)} != {sorted(placeholders)}",
            )

    # Localization keys referenced from Dart must exist. `l10n.dart` (the import) and
    # method calls such as `l10n.of(...)` are not keys.
    l10n_re = re.compile(r"(?:\bl10n|\.l10n)\.([a-z][A-Za-z0-9]*)\b(?!['\"])")
    known = en_keys
    ignored = {"of", "delegate", "localeName", "locale", "supportedLocales", "maybeOf", "dart"}
    for path in dart_files():
        if "l10n/generated" in rel(path):
            continue
        for match in l10n_re.findall(path.read_text(encoding="utf-8")):
            if match in ignored or match in known:
                continue
            fail(rel(path), f"unknown localization key 'l10n.{match}'")


def check_secrets_and_transport() -> None:
    secret_re = re.compile(
        r"""(?i)(api[_-]?key|secret|passwd|password|bearer\s+[A-Za-z0-9\-_]{16,})\s*[:=]\s*['"][^'"]{8,}['"]"""
    )
    allowed_context = ("test/", "docs/", "tool/static_checks.py")
    for path in dart_files():
        relative = rel(path)
        source = path.read_text(encoding="utf-8")
        if not relative.startswith(allowed_context):
            for match in secret_re.finditer(source):
                line_no = source[: match.start()].count("\n") + 1
                fail(relative, f"possible hardcoded secret on line {line_no}")
        for cleartext in re.findall(r"['\"]http://[^'\"]+['\"]", source):
            fail(relative, f"cleartext URL {cleartext}")


def check_file_budget() -> None:
    for path in dart_files():
        line_count = len(path.read_text(encoding="utf-8").splitlines())
        if line_count > 320:
            notes.append(f"{rel(path)}: {line_count} lines (budget is ~300)")


def preexisting_files() -> set[str]:
    """Files present at the branch point, taken from git (empty set when unavailable)."""
    import subprocess

    try:
        output = subprocess.run(
            ["git", "ls-tree", "-r", "--name-only", "676dc0c83ce9907f931523f67ab1ab26d1b05ad8"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except Exception:  # pragma: no cover - git missing or shallow clone
        return set()
    return {line.strip() for line in output.splitlines() if line.strip()}


def check_generated_parts() -> None:
    """New code must not add codegen parts, so the tree stays analyzable without build_runner."""
    baseline = preexisting_files()
    if not baseline:
        notes.append("static_checks: could not read the baseline commit; codegen-part check skipped")
        return
    for path in dart_files():
        relative = rel(path)
        if relative in baseline:
            continue
        source = path.read_text(encoding="utf-8")
        if re.search(r"part\s+'[^']*\.(g|freezed)\.dart'", source):
            fail(relative, "new code must not depend on build_runner parts (see docs/decisions/0004)")


def check_readme_status() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for step in range(1, 11):
        if f"| {step} |" not in readme:
            notes.append(f"README.md: no status row for step {step}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Offline sanity checks for A.R.M.X AI")
    parser.add_argument("--quiet", action="store_true", help="only print failures")
    args = parser.parse_args()

    check_headers()
    check_brackets()
    check_imports()
    check_localization()
    check_secrets_and_transport()
    check_generated_parts()
    check_file_budget()
    check_readme_status()

    if notes and not args.quiet:
        print("Notes:")
        for note in notes:
            print(f"  - {note}")
    if failures:
        print(f"\n{len(failures)} problem(s) found:")
        for problem in failures:
            print(f"  ✗ {problem}")
        return 1
    print("static_checks: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
