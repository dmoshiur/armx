#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
#
# Offline source sanity checks for the A.R.M.X AI client.
#
# This script is a *supplement* to `flutter analyze` + `flutter test`, never a replacement.
# It catches the structural mistakes an analyzer would catch (missing files, unresolved
# imports, undefined types, unused imports, unknown localization keys, unbalanced brackets,
# missing licence headers, hardcoded secrets, cleartext URLs) in environments where the
# Flutter SDK and pub.dev are unreachable. See docs/verification.md.
#
# Usage:
#   python3 tool/static_checks.py            # full output
#   python3 tool/static_checks.py --quiet    # failures and notes only

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE_COMMIT = "676dc0c83ce9907f931523f67ab1ab26d1b05ad8"

HEADER = (
    "Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. "
    "All Rights Reserved."
)
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
    """Removes comments and string literals so bracket/symbol checks see only code."""
    out: list[str] = []
    i = 0
    length = len(source)
    while i < length:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < length else ""
        if ch == "/" and nxt == "/":
            while i < length and source[i] != "\n":
                i += 1
            continue
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
                # Keep interpolation expressions: `'${Foo.bar()}'` really does reference Foo.
                if source[i] == "$" and not raw:
                    if i + 1 < length and source[i + 1] == "{":
                        depth = 1
                        j = i + 2
                        while j < length and depth:
                            if source[j] == "{":
                                depth += 1
                            elif source[j] == "}":
                                depth -= 1
                            j += 1
                        out.append(" " + source[i + 2 : j - 1] + " ")
                        i = j
                        continue
                    if i + 1 < length and (source[i + 1].isalpha() or source[i + 1] == "_"):
                        j = i + 1
                        while j < length and (source[j].isalnum() or source[j] == "_"):
                            j += 1
                        out.append(" " + source[i + 1 : j] + " ")
                        i = j
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
            out.append(" _ ")
            continue
        out.append(ch)
        i += 1
    return "".join(out)


# ---------------------------------------------------------------------------------------
# Headers
# ---------------------------------------------------------------------------------------


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
                continue  # JSON cannot carry comments
            if "generated" in path.parts or "build" in path.parts:
                continue
            try:
                head = path.read_text(encoding="utf-8")[:2000]
            except UnicodeDecodeError:
                continue
            if HEADER not in head:
                fail(relative, "missing copyright header")


# ---------------------------------------------------------------------------------------
# Brackets
# ---------------------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------


def is_generated_target(target: str) -> bool:
    """build_runner / gen-l10n outputs are intentionally not committed."""
    return (
        target.endswith(".g.dart")
        or target.endswith(".freezed.dart")
        or "l10n/generated/" in target
    )


def check_imports() -> None:
    pattern = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.MULTILINE)
    for path in dart_files():
        source = path.read_text(encoding="utf-8")
        for target in pattern.findall(source):
            if is_generated_target(target):
                continue
            if target.startswith("package:armx_ai/"):
                resolved = ROOT / "lib" / target[len("package:armx_ai/") :]
            elif target.startswith(("package:", "dart:")):
                continue
            else:
                resolved = (path.parent / target).resolve()
            if not resolved.exists():
                fail(rel(path), f"unresolved target '{target}'")


# ---------------------------------------------------------------------------------------
# Localization
# ---------------------------------------------------------------------------------------


def check_localization() -> None:
    en_path = ROOT / "lib" / "l10n" / "app_en.arb"
    bn_path = ROOT / "lib" / "l10n" / "app_bn.arb"
    try:
        en = json.loads(en_path.read_text(encoding="utf-8"))
        bn = json.loads(bn_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail("lib/l10n", f"invalid ARB JSON: {error}")
        return

    en_keys = {key for key in en if not key.startswith("@")}
    bn_keys = {key for key in bn if not key.startswith("@")}
    for missing in sorted(en_keys - bn_keys):
        fail("lib/l10n/app_bn.arb", f"missing translation for '{missing}'")
    for extra in sorted(bn_keys - en_keys):
        fail("lib/l10n/app_bn.arb", f"key '{extra}' is not in the template file")

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

    key_re = re.compile(r"(?:\bl10n|\.l10n)\.([a-z][A-Za-z0-9]*)\b(?!['\"])")
    ignored = {"of", "delegate", "localeName", "locale", "supportedLocales", "maybeOf", "dart"}
    for path in dart_files():
        if "l10n/generated" in rel(path):
            continue
        for match in key_re.findall(path.read_text(encoding="utf-8")):
            if match in ignored or match in en_keys:
                continue
            fail(rel(path), f"unknown localization key 'l10n.{match}'")


# ---------------------------------------------------------------------------------------
# Secrets and transport hygiene
# ---------------------------------------------------------------------------------------


def check_secrets_and_transport() -> None:
    secret_re = re.compile(
        r"""(?i)(api[_-]?key|secret|passwd|password)\s*[:=]\s*['"][^'"]{8,}['"]"""
    )
    allowed = ("test/", "docs/", "tool/static_checks.py")
    for path in dart_files():
        relative = rel(path)
        source = path.read_text(encoding="utf-8")
        if not relative.startswith(allowed):
            for match in secret_re.finditer(source):
                line_no = source[: match.start()].count("\n") + 1
                fail(relative, f"possible hardcoded secret on line {line_no}")
        for cleartext in re.findall(r"""['"]http://[^'"]+['"]""", source):
            fail(relative, f"cleartext URL {cleartext}")


# ---------------------------------------------------------------------------------------
# File budget
# ---------------------------------------------------------------------------------------


def check_file_budget() -> None:
    for path in dart_files():
        count = len(path.read_text(encoding="utf-8").splitlines())
        if count > 320:
            notes.append(f"{rel(path)}: {count} lines (budget is ~300)")


# ---------------------------------------------------------------------------------------
# Codegen policy (decision 0004)
# ---------------------------------------------------------------------------------------


def preexisting_files() -> set[str]:
    try:
        output = subprocess.run(
            ["git", "ls-tree", "-r", "--name-only", BASELINE_COMMIT],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except Exception:  # pragma: no cover - git unavailable
        return set()
    return {line.strip() for line in output.splitlines() if line.strip()}


def check_generated_parts() -> None:
    baseline = preexisting_files()
    if not baseline:
        notes.append("could not read the baseline commit; codegen-part check skipped")
        return
    for path in dart_files():
        relative = rel(path)
        if relative in baseline:
            continue
        if re.search(r"part\s+'[^']*\.(g|freezed)\.dart'", path.read_text(encoding="utf-8")):
            fail(relative, "new code must not depend on build_runner parts (docs/decisions/0004)")


# ---------------------------------------------------------------------------------------
# Symbol resolution (a poor man's analyzer)
# ---------------------------------------------------------------------------------------


def declared_symbols(source: str) -> set[str]:
    code = strip_dart_code(source)
    symbols: set[str] = set()
    patterns = (
        r"\b(?:abstract\s+final\s+class|abstract\s+interface\s+class|final\s+class|sealed\s+class|"
        r"class|mixin|enum|extension)\s+([A-Z][A-Za-z0-9_]*)",
        r"\btypedef\s+([A-Z][A-Za-z0-9_]*)",
        r"^final\s+(?:Provider|FutureProvider|StreamProvider|NotifierProvider|"
        r"AsyncNotifierProvider)[^=]*?\s([a-z][A-Za-z0-9_]*Provider)\s*=",
        r"^const\s+([a-zA-Z][A-Za-z0-9_]*)\s*=",
    )
    for pattern in patterns:
        symbols.update(re.findall(pattern, code, re.MULTILINE))
    return symbols


def library_units(sources: dict[str, str]) -> dict[str, set[str]]:
    units: dict[str, set[str]] = {name: {name} for name in sources}
    for name, source in sources.items():
        for target in re.findall(r"part\s+'([^']+\.dart)'", source) + re.findall(
            r"part\s+of\s+'([^']+\.dart)'", source
        ):
            resolved = os.path.normpath(
                os.path.join(str(Path(name).parent), target)
            ).replace(os.sep, "/")
            if resolved in sources:
                units[name].add(resolved)
                units.setdefault(resolved, {resolved}).add(name)
    return units


def check_symbol_resolution() -> None:
    files = {rel(path): path for path in dart_files()}
    sources = {name: path.read_text(encoding="utf-8") for name, path in files.items()}
    units = library_units(sources)

    declarations: dict[str, set[str]] = {}
    for name, source in sources.items():
        symbols = declared_symbols(source)
        annotated_classes = re.findall(
            r"@Riverpod\([^)]*\)\s*\n(?:@\w+[^\n]*\n)*class\s+([A-Za-z_][A-Za-z0-9_]*)",
            source,
        )
        annotated_functions = re.findall(
            r"@Riverpod\([^)]*\)\s*\n(?:@\w+[^\n]*\n)*(?:[\w<>?,\[\] ]+\s+)?([a-z][A-Za-z0-9_]*)\s*\(",
            source,
        )
        for decorated in annotated_classes + annotated_functions:
            # riverpod_generator lower-camel-cases the provider name: `ChatController` ->
            # `chatControllerProvider`, `appRouter` -> `appRouterProvider`.
            symbols.add(f"{decorated}Provider")
            symbols.add(f"{decorated[0].lower()}{decorated[1:]}Provider")
        declarations[name] = symbols

    def imports_of(name: str) -> list[str]:
        return re.findall(r"^\s*import\s+['\"]([^'\"]+)['\"]", sources[name], re.MULTILINE)

    def exports_of(name: str) -> list[str]:
        return re.findall(r"^\s*export\s+['\"]([^'\"]+)['\"]", sources[name], re.MULTILINE)

    def resolve(target: str, from_file: str) -> str | None:
        if target.startswith("package:armx_ai/"):
            candidate = "lib/" + target[len("package:armx_ai/") :]
        elif target.startswith(("dart:", "package:")):
            return None
        else:
            candidate = os.path.normpath(
                os.path.join(str(Path(from_file).parent), target)
            ).replace(os.sep, "/")
        return candidate if candidate in sources else None

    def visible_symbols(name: str) -> set[str]:
        visible: set[str] = set()
        queue: list[tuple[str, str]] = []
        for member in units[name]:
            queue.extend((target, member) for target in imports_of(member))
            queue.extend((target, member) for target in exports_of(member))
        seen: set[str] = set()
        while queue:
            target, from_file = queue.pop(0)
            resolved = resolve(target, from_file)
            if resolved is None or resolved in seen:
                continue
            seen.add(resolved)
            for member in units[resolved]:
                visible |= declarations[member]
                queue.extend((exported, member) for exported in exports_of(member))
                queue.extend((imported, member) for imported in imports_of(member))
        return visible

    symbol_to_file: dict[str, str] = {}
    for name, symbols in declarations.items():
        for symbol in symbols:
            symbol_to_file.setdefault(symbol, name)

    identifier_re = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\b")
    for name, source in sources.items():
        if "l10n/generated" in name or re.search(r"^\s*part\s+of\s+", source, re.MULTILINE):
            continue
        body = strip_dart_code(source)
        body = re.sub(r"^\s*(?:import|export|part)\s+[^;]+;", "", body, flags=re.MULTILINE)
        used = set(identifier_re.findall(body))
        local = set().union(*(declarations[member] for member in units[name]))
        visible = visible_symbols(name)

        for symbol in sorted(used):
            if symbol in local or symbol.startswith("_"):
                continue
            if not (symbol[0].isupper() or symbol.endswith("Provider")):
                continue
            owner = symbol_to_file.get(symbol)
            if owner is None or owner in units[name] or symbol in visible:
                continue
            fail(name, f"uses '{symbol}' declared in {owner} without importing it")

        # A part file's usages count for the whole library unit, so imports of the entry
        # file are matched against everything the unit references.
        unit_used: set[str] = set(used)
        for member in units[name]:
            if member == name:
                continue
            member_body = strip_dart_code(sources[member])
            member_body = re.sub(
                r"^\s*(?:import|export|part)\s+[^;]+;", "", member_body, flags=re.MULTILINE
            )
            unit_used |= set(identifier_re.findall(member_body))

        for target in imports_of(name):
            resolved = resolve(target, name)
            if resolved is None or resolved in units[name]:
                continue
            if not declarations[resolved]:
                continue
            if declarations[resolved] & unit_used:
                continue
            if exports_of(resolved):
                continue  # barrel: contributes transitively
            if re.search(r"\bextension\b", sources[resolved]):
                continue  # extension methods are used implicitly
            fail(name, f"unused import '{target}'")


# ---------------------------------------------------------------------------------------
# README status table
# ---------------------------------------------------------------------------------------


def check_readme_status() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for step in range(1, 11):
        if f"| {step} |" not in readme:
            notes.append(f"README.md: no status row for step {step}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Offline sanity checks for A.R.M.X AI")
    parser.add_argument("--quiet", action="store_true", help="suppress the notes section")
    args = parser.parse_args()

    check_headers()
    check_brackets()
    check_imports()
    check_localization()
    check_secrets_and_transport()
    check_generated_parts()
    check_symbol_resolution()
    check_file_budget()
    check_readme_status()

    if notes and not args.quiet:
        print("Notes:")
        for note in notes:
            print(f"  - {note}")
    if failures:
        print(f"\n{len(failures)} problem(s) found:")
        for problem in failures:
            print(f"  x {problem}")
        return 1
    print("static_checks: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
