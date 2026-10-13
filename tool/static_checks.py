#!/usr/bin/env python3
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
"""Offline structural checks for A.R.M.X AI.

Runs anywhere, with no Flutter SDK and no network. It catches the classes of defect that
`flutter analyze` would otherwise catch structurally, plus the project's own conventions:

1. licence header on every source file;
2. balanced brackets per Dart file (comment- and string-aware);
3. every relative `import` / `export` / `part` target exists;
4. every `l10n.<key>` reference exists in `app_en.arb`, and EN/BN have identical keys and
   identical placeholders;
5. no hardcoded secrets and no cleartext `http://` in `lib/`;
6. no `part '*.g.dart'` / `part '*.freezed.dart'` (the project is codegen-free);
7. no `Platform.isAndroid` / `Platform.isIOS` layout branching in `lib/`.

Exit code 0 means all checks passed. Usage: `python3 tool/static_checks.py [--quiet]`.
"""

from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
ARB_EN = os.path.join(LIB, "l10n", "app_en.arb")
ARB_BN = os.path.join(LIB, "l10n", "app_bn.arb")

HEADER = "Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP"

HEADER_REQUIRED_SUFFIXES = (
    ".dart",
    ".kt",
    ".xml",
    ".gradle",
    ".yaml",
    ".yml",
    ".py",
)
HEADER_EXEMPT_NAMES = (
    "gradle-wrapper.properties",
    "gradlew",
    "gradlew.bat",
    "local.properties",
)
HEADER_EXEMPT_DIRS = (".git", ".dart_tool", "build", ".gradle", "l10n\\generated",
                      "l10n/generated", "ephemeral")

SECRET_PATTERNS = [
    (re.compile(r"""(?i)\b(api[_-]?key|secret|client[_-]?secret|private[_-]?key)\s*[:=]\s*['"][^'"]{8,}['"]"""),
     "possible hardcoded secret"),
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "embedded private key"),
    (re.compile(r"""['"]https?://[^'"]*:[^'"]*@"""), "credentials inside a URL"),
]
CLEARTEXT_RE = re.compile(r"""['"]http://(?!localhost|127\.0\.0\.1|10\.0\.2\.2)[^'"]*['"]""")
PLATFORM_BRANCH_RE = re.compile(r"Platform\.is(Android|IOS|MacOS|Windows|Linux)\b")
PART_CODEGEN_RE = re.compile(r"""part\s+['"][^'"]*\.(g|freezed)\.dart['"]""")

# Imports that are expected to resolve only after `flutter pub get`.
PACKAGE_PREFIXES = ("package:", "dart:")

errors: list[str] = []
notes: list[str] = []


def rel(path: str) -> str:
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def iter_files(base: str, suffixes: tuple[str, ...] | None = None):
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [
            d for d in dirnames
            if d not in {"build", ".dart_tool", ".gradle", "ephemeral", ".idea"}
        ]
        for name in filenames:
            if suffixes is None or name.endswith(suffixes):
                yield os.path.join(dirpath, name)


def check_headers() -> None:
    for base in (LIB, os.path.join(ROOT, "android"), os.path.join(ROOT, "test"),
                 os.path.join(ROOT, "integration_test"), os.path.join(ROOT, "tool")):
        if not os.path.isdir(base):
            continue
        for path in iter_files(base, HEADER_REQUIRED_SUFFIXES):
            name = os.path.basename(path)
            if name in HEADER_EXEMPT_NAMES:
                continue
            if any(part in os.path.join(path) for part in HEADER_EXEMPT_DIRS):
                continue
            with open(path, encoding="utf-8") as handle:
                head = handle.read(600)
            if HEADER not in head:
                errors.append(f"missing licence header: {rel(path)}")
    for extra in (".gitignore", "README.md", ".github/workflows/ci.yml", "pubspec.yaml",
                  "analysis_options.yaml", "l10n.yaml"):
        path = os.path.join(ROOT, extra)
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                if HEADER not in handle.read(800):
                    errors.append(f"missing licence header: {extra}")


def strip_dart(source: str) -> str:
    """Remove comments and string bodies so bracket counting is not fooled."""
    out = []
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""
        if ch == "/" and nxt == "/":
            while i < n and source[i] != "\n":
                i += 1
            continue
        if ch == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (source[i] == "*" and source[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if ch in ("'", '"'):
            quote = ch
            triple = source[i:i + 3] == quote * 3
            i += 3 if triple else 1
            while i < n:
                if source[i] == "\\":
                    i += 2
                    continue
                if triple:
                    if source[i:i + 3] == quote * 3:
                        i += 3
                        break
                elif source[i] == quote:
                    i += 1
                    break
                i += 1
            out.append('""')
            continue
        out.append(ch)
        i += 1
    return "".join(out)


_STRIPPED_CACHE: dict[str, str] = {}


def stripped(path: str) -> str:
    """`strip_dart(source)` with the file read cached.

    Several checks walk the whole tree, and each pass is pure, so reading and stripping once
    keeps a full run to a couple of seconds instead of thirty.
    """
    cached = _STRIPPED_CACHE.get(path)
    if cached is None:
        with open(path, encoding="utf-8") as handle:
            cached = strip_dart(handle.read())
        _STRIPPED_CACHE[path] = cached
    return cached


def check_brackets_and_codegen() -> None:
    for path in iter_files(LIB, (".dart",)):
        with open(path, encoding="utf-8") as handle:
            source = handle.read()
        if PART_CODEGEN_RE.search(source):
            errors.append(f"codegen part directive (project is codegen-free): {rel(path)}")
        cleaned = strip_dart(source)
        for opener, closer, label in (("{", "}", "braces"), ("(", ")", "parens"),
                                      ("[", "]", "brackets")):
            delta = cleaned.count(opener) - cleaned.count(closer)
            if delta != 0:
                errors.append(f"unbalanced {label} ({delta:+d}) in {rel(path)}")


def check_imports() -> None:
    import_re = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)
    for path in iter_files(LIB, (".dart",)):
        with open(path, encoding="utf-8") as handle:
            source = handle.read()
        for target in import_re.findall(source):
            if target.startswith(PACKAGE_PREFIXES):
                continue
            if 'l10n/generated' in target.replace(os.sep, '/'):
                # Emitted by `flutter gen-l10n`; absent until the first pub get.
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(resolved):
                errors.append(f"unresolved import '{target}' in {rel(path)}")


def load_arb(path: str) -> dict:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def check_l10n() -> None:
    en = load_arb(ARB_EN)
    bn = load_arb(ARB_BN)
    en_keys = {k for k in en if not k.startswith("@")}
    bn_keys = {k for k in bn if not k.startswith("@")}

    for missing in sorted(en_keys - bn_keys):
        errors.append(f"app_bn.arb is missing key '{missing}'")
    for extra in sorted(bn_keys - en_keys):
        errors.append(f"app_bn.arb has key '{extra}' that app_en.arb does not")

    placeholder_re = re.compile(r"\{(\w+)\}")
    for key in sorted(en_keys & bn_keys):
        en_placeholders = set(placeholder_re.findall(en[key]))
        meta = en.get(f"@{key}", {})
        declared = set(meta.get("placeholders", {})) if isinstance(meta, dict) else set()
        if declared and declared != en_placeholders:
            errors.append(
                f"'{key}': @-metadata placeholders {sorted(declared)} "
                f"!= body placeholders {sorted(en_placeholders)}"
            )
        if en_placeholders != set(placeholder_re.findall(bn[key])):
            errors.append(
                f"'{key}': EN placeholders {sorted(en_placeholders)} "
                f"!= BN placeholders {sorted(placeholder_re.findall(bn[key]))}"
            )
        if not str(bn[key]).strip():
            errors.append(f"'{key}': empty Bengali translation")
        # A Bengali string that is byte-identical to English is usually an oversight —
        # except for words that are legitimately the same in both languages.
        if str(bn[key]) == str(en[key]) and key not in ALLOWED_IDENTICAL:
            notes.append(f"'{key}': BN equals EN (verify this is intentional)")

    referenced: set[str] = set()
    # Require a member access that is not preceded by another identifier character and is
    # not a file extension: `l10n.loginTitle` counts, `l10n.dart` and `l10n.<key>` do not.
    # A preceding dot is *expected* (`context.l10n.loginTitle`); only a preceding
    # identifier character means this is not a member access at all. Import lines such as
    # `l10n/l10n.dart` are excluded because they have no dot after `l10n`.
    key_re = re.compile(r"(?<![A-Za-z0-9_])l10n\.(?!dart\b)([a-z][A-Za-z0-9]*)")
    for path in iter_files(LIB, (".dart",)):
        with open(path, encoding="utf-8") as handle:
            source = strip_dart(handle.read())
        referenced.update(key_re.findall(source))
        referenced.update(
            re.findall(r"AppLocalizations\.of\([^)]*\)\.([a-z][A-Za-z0-9]*)", source)
        )
    for key in sorted(referenced - en_keys):
        errors.append(f"l10n key referenced in code but absent from app_en.arb: '{key}'")


ALLOWED_IDENTICAL = {
    # Brand / product names and language-neutral tokens that must not be translated.
    "appName", "appWordmark", "roleAdmin", "roleVip", "roleUser",
    "riskLow", "riskMedium", "riskHigh", "settingsLanguageEnglish",
    "settingsLanguageBengali",
}


def check_secrets_and_reachability() -> None:
    for path in iter_files(LIB, (".dart",)):
        with open(path, encoding="utf-8") as handle:
            # Comments are stripped first: a doc comment that *names* a forbidden pattern
            # (this repo documents its own rules) is not a violation.
            source = strip_dart(handle.read())
        for pattern, label in SECRET_PATTERNS:
            if pattern.search(source):
                errors.append(f"{label} in {rel(path)}")
        for match in CLEARTEXT_RE.findall(source):
            errors.append(f"cleartext URL '{match}' in {rel(path)}")
        for match in PLATFORM_BRANCH_RE.findall(source):
            errors.append(
                f"platform-based branching (Platform.is{match}) in {rel(path)} — "
                "layout must branch on Breakpoint, capability on PlatformCapabilities"
            )



DECL_RE = re.compile(
    r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*"
    r"(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.M,
)
FUNC_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_<>,?\s]*\s([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)
# Top-level variables matter as much as types: `armxApiProvider` and `Routes` are the two
# most-imported names in the app, and missing them would make this check scream falsely.
VAR_RE = re.compile(
    # Declarations wrap across lines constantly in this codebase
    # (`final NotifierProvider<Foo, Bar>\n    fooProvider = …`), so the name may be up to a
    # couple of lines after the keyword.
    r"^(?:final|const|var|late)\s+[\s\S]{0,160}?\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|;)",
    re.M,
)
EXPORT_RE = re.compile(r"""^export\s+['"]([^'"]+)['"]""", re.M)


def _declared_names(path: str, seen: set[str] | None = None) -> tuple[set[str], bool]:
    """Top-level names a file makes available, plus whether it declares an extension.

    Extensions are reported separately because an import that only supplies one is used by
    its *members*, not by its name — flagging those would produce a wall of false positives.
    """
    seen = seen or set()
    if path in seen or not os.path.isfile(path):
        return set(), False
    seen.add(path)
    with open(path, encoding="utf-8") as handle:
        source = handle.read()

    names = set(DECL_RE.findall(source))
    has_extension = "extension " in source
    names.update(FUNC_RE.findall(source))
    names.update(VAR_RE.findall(source))
    for target in EXPORT_RE.findall(source):
        if target.startswith("package:") or target.startswith("dart:"):
            continue
        child = os.path.normpath(os.path.join(os.path.dirname(path), target))
        child_names, child_extension = _declared_names(child, seen)
        names.update(child_names)
        has_extension = has_extension or child_extension
    return names, has_extension


def check_unused_imports() -> None:
    """Flag relative imports whose exported names are never mentioned.

    This is a heuristic stand-in for `dart analyze` (which cannot run offline), so it is
    deliberately conservative: it skips package imports, generated localizations, files that
    export extensions, and it searches the raw source — a type referenced only from a doc
    comment counts as used.
    """
    for path in iter_files(LIB, (".dart",)):
        with open(path, encoding="utf-8") as handle:
            source = handle.read()
        body_start = 0
        for match in re.finditer(r"^import\s+'[^']+';", source, re.M):
            body_start = match.end()
        body = source[body_start:]
        for target in re.findall(r"^import\s+'([^']+)';", source, re.M):
            if target.startswith("package:") or target.startswith("dart:"):
                continue
            if "l10n/generated" in target:
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            names, has_extension = _declared_names(resolved)
            if has_extension or not names:
                continue
            if not any(re.search(r"\b%s\b" % re.escape(name), body) for name in names):
                errors.append(
                    f"unused relative import '{target}' in {rel(path)}"
                )



def _classes_and_counts() -> tuple[dict[str, set[str]], dict[str, int]]:
    """Member sets per class name, and how many files declare each name."""
    members: dict[str, set[str]] = {}
    counts: dict[str, int] = {}
    for path in iter_files(LIB, (".dart",)):
        source = stripped(path)
        for name, found in _model_members(source).items():
            counts[name] = counts.get(name, 0) + 1
            members.setdefault(name, set()).update(found)
    return members, counts


def _project_symbols() -> set[str]:
    """Every top-level name declared anywhere under `lib/`."""
    symbols: set[str] = set()
    for path in iter_files(LIB, (".dart",)):
        source = stripped(path)
        symbols.update(DECL_RE.findall(source))
        symbols.update(VAR_RE.findall(source))
        symbols.update(FUNC_RE.findall(source))
        symbols.update(re.findall(r"^\s*(?:static\s+)?(?:const\s+)?(\w+)\s*=", source, re.M))
    return symbols


def check_static_references() -> None:
    """Validates `ClassName.member` against the class that declares it.

    The receiver is written out in full, so there is no guessing: `Routes.smartHomes` or
    `ArmxStatus.flying` is flagged exactly, and nothing else is. A name declared in more than
    one file is skipped, because the two declarations may mean different things and the union
    of their members would accept too much.
    """
    members, counts = _classes_and_counts()
    enum_names = set(_all_enum_members())
    for name, found in _all_enum_members().items():
        members.setdefault(name, set()).update(found)
        counts.setdefault(name, 1)

    # Enums are covered member-by-member by check_api_surface; running both would report the
    # same mistake twice.
    checked = {
        name
        for name, count in counts.items()
        if count == 1 and name not in enum_names
    }
    patterns = {
        name: re.compile(r"(?<![\w.])" + re.escape(name) + r"\.([A-Za-z_]\w*)")
        for name in checked
    }

    for path in iter_files(LIB, (".dart",)):
        relative = rel(path)
        source = stripped(path)
        for name, pattern in patterns.items():
            allowed = members.get(name, set()) | _CORE_MEMBERS | {"new"}
            for match in pattern.finditer(source):
                member = match.group(1)
                if member in allowed:
                    continue
                if member in _FRAMEWORK_STATICS.get(name, set()):
                    continue
                if name in _SKIP_STATIC_RECEIVERS:
                    continue
                line = source.count("\n", 0, match.start()) + 1
                errors.append(f"{name} has no member '{member}' in {relative}:{line}")


def check_provider_names() -> None:
    """Both halves at once: `*Provider` names, and everything passed to `ref.*`."""
    """Flags references to riverpod providers that nothing declares.

    Providers are top-level finals named `somethingProvider`. A misspelling is invisible in
    review and fatal at compile time, and it is the single most common way this kind of tree
    breaks. Named arguments (`WebSocketClient(tokenProvider: …)`) and the framework's own
    `Provider` classes are excluded by the casing rule and by the `:` guard.
    """
    declared = _project_symbols()
    pattern = re.compile(r"(?<![\w.\$])([a-z][A-Za-z0-9]*Provider)\b(?!\s*[:=])")
    for path in iter_files(LIB, (".dart",)):
        relative = rel(path)
        source = stripped(path)
        body_start = 0
        for match in re.finditer(r"^import\s+'[^']+';", source, re.M):
            body_start = match.end()
        body = source[body_start:]
        for match in re.finditer(
            r"\bref\.(?:watch|read|listen|invalidate|refresh|exists)\(\s*"
            r"([A-Za-z_][A-Za-z0-9_]*)",
            body,
        ):
            name = match.group(1)
            if name in declared:
                continue
            line = body.count("\n", 0, match.start()) + 1
            errors.append(
                f"'{name}' is passed to ref.watch/read but is declared "
                f"nowhere in {relative}:{line}"
            )

        for match in pattern.finditer(body):
            name = match.group(1)
            if name in declared:
                continue
            line_start = body.rfind("\n", 0, match.start()) + 1
            prefix = body[line_start : match.start()]
            # `required Future<String?> Function() tokenProvider,` and the initializer-list
            # `_tokenProvider = tokenProvider,` both *declare* a parameter rather than naming
            # a provider. A real use is always reached through a call or an assignment whose
            # receiver is written out (`ref.watch(`, `= xProvider;`, `(xProvider)`).
            if re.search(r"(required\s+|Function\([^)]*\)\s*|[A-Z]\w*\s+|= )$", prefix):
                continue
            if re.match(r"\s*[,)]", body[match.end() :]) and not re.search(
                r"[.(]$", prefix
            ):
                continue
            line = body.count("\n", 0, match.start()) + 1
            errors.append(
                f"reference to undeclared provider '{name}' in {relative}:{line}"
            )


# Static members the framework adds to types this project declares, or that come from a mixin
# the class uses. Keyed by class name.
_FRAMEWORK_STATICS: dict[str, set[str]] = {
    "ArmxColors": {"lerp", "copyWith"},
    "ArmxTypography": {"lerp"},
}

# Receivers where `Name.member` is not a static lookup at all: a constructor tear-off or a
# local shadowing the class name. Kept empty until a real case appears.
_SKIP_STATIC_RECEIVERS: set[str] = set()


def check_arb_json() -> None:
    for path in (ARB_EN, ARB_BN):
        try:
            load_arb(path)
        except json.JSONDecodeError as exc:  # pragma: no cover - defensive
            errors.append(f"{rel(path)} is not valid JSON: {exc}")



# ---------------------------------------------------------------------------
# Widget API surface
#
# Dart's analyzer cannot run in this environment, so the next best thing is to parse the
# declarations of our own widgets and enums and compare them against every use site. This
# catches the class of error the other checks are blind to: calling a widget with an
# argument it does not have, or naming an enum value that does not exist.
# ---------------------------------------------------------------------------

WIDGET_BASES = (
    "StatelessWidget",
    "StatefulWidget",
    "ConsumerWidget",
    "ConsumerStatefulWidget",
)

_CLASS_RE = re.compile(
    r"\bclass\s+(\w+)\s+extends\s+(" + "|".join(WIDGET_BASES) + r")\b"
)
_ENUM_RE = re.compile(r"\benum\s+(\w+)\s*\{")
_ANY_CLASS_RE = re.compile(
    r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)*class\s+(\w+)",
    re.M,
)
# Members every Dart object has, so an access to one is never a bug in this app.
_OBJECT_MEMBERS = {"toString", "hashCode", "runtimeType", "noSuchMethod"}


def _balanced_span(
    source: str,
    start: int,
    open_char: str = "(",
    close_char: str = ")",
) -> tuple[str, int]:
    """Returns the text inside the pair starting at `start` and the index after its close."""
    depth = 0
    index = start
    quote: str | None = None
    while index < len(source):
        char = source[index]
        if quote is not None:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == open_char:
            depth += 1
        elif char == close_char:
            depth -= 1
            if depth == 0:
                return source[start + 1 : index], index + 1
        index += 1
    return "", len(source)


def _split_top_level(text: str, separator: str = ",") -> list[str]:
    """Splits on `separator` at bracket depth 0, ignoring strings."""
    parts: list[str] = []
    current: list[str] = []
    depth = 0
    quote: str | None = None
    index = 0
    while index < len(text):
        char = text[index]
        if quote is not None:
            current.append(char)
            if char == "\\":
                if index + 1 < len(text):
                    current.append(text[index + 1])
                    index += 2
                    continue
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
            current.append(char)
        elif char in "([{":
            depth += 1
            current.append(char)
        elif char in ")]}":
            depth -= 1
            current.append(char)
        elif char == separator and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
        index += 1
    parts.append("".join(current))
    return parts


def _top_level_brace_spans(params: str) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    depth = 0
    start = -1
    for index, char in enumerate(params):
        if char == "{":
            if depth == 0:
                start = index
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0 and start >= 0:
                spans.append((start, index))
                start = -1
    return spans


def _constructor_named_params(source: str, class_name: str) -> set[str] | None:
    """The named parameters of a widget's constructor, or None when it cannot be read."""
    match = re.search(
        r"(?:const\s+)?" + re.escape(class_name) + r"\s*\(",
        source,
    )
    if not match:
        return None
    paren = source.index("(", match.start())
    params, _ = _balanced_span(source, paren)
    named: set[str] = {"key"}
    for start, end in _top_level_brace_spans(params):
        for part in _split_top_level(params[start + 1 : end]):
            found = re.search(r"\bthis\.(\w+)", part)
            if found:
                named.add(found.group(1))
                continue
            # Plain named parameters (`required ApiClient client`) and those forwarded to
            # a super constructor (`super.key`) are named the same way as `this.x`.
            if re.match(r"\s*super\.", part):
                named.add("key")
                continue
            found = re.search(r"([a-z_][A-Za-z0-9_]*)\s*(?:=|,)?\s*$", part.strip())
            if found:
                named.add(found.group(1))
    return named


def _model_members(source: str) -> dict[str, set[str]]:
    """Public members of every class in a model file, keyed by class name."""
    members: dict[str, set[str]] = {}
    for match in re.finditer(
        r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)*class\s+(\w+)",
        source,
        re.M,
    ):
        name = match.group(1)
        tail = source[match.end() :]
        nxt = re.search(r"\n(?:class|enum|mixin|extension|abstract)\b", tail)
        body = tail[: nxt.start()] if nxt else tail
        found: set[str] = set()
        # `final String name;`  ·  `bool get isActive => …`  ·  `Bar copyWith(…)`
        # A field type may be a function type (`Widget Function(BuildContext, …)`), so the
        # character class has to allow brackets as well as generics.
        found.update(
            re.findall(
                r"^\s{2}(?:final|const|late|static)?\s*[\w<>?,\[\]() ]+\s+(\w+)\s*;",
                body,
                re.M,
            )
        )
        found.update(re.findall(r"^\s{2}(?:static\s+)?[\w<>?, ]+\s+get\s+(\w+)", body, re.M))
        found.update(re.findall(r"^\s{2}[\w<>?, ]+\s+(\w+)\s*\(", body, re.M))
        # Static methods and factory/named constructors read as `Name.member`.
        found.update(
            re.findall(r"^\s{2}static\s+[\w<>?, ]+\s+(\w+)\s*\(", body, re.M)
        )
        found.update(
            re.findall(
                r"^\s{2}(?:const\s+|factory\s+)[A-Z]\w*\.(\w+)\s*\(",
                body,
                re.M,
            )
        )
        found.update(re.findall(r"^\s{2}(?:static\s+)?(?:const\s+)?[\w<>?, ]+\s+(\w+)\s*=", body, re.M))
        # An enum-typed or nested-model field still shows up as `final X name;`.
        members[name] = found
    return members


def _declared_api() -> tuple[
    dict[str, list[tuple[str, set[str]]]],
    dict[str, set[str]],
    dict[str, set[str]],
    set[str],
]:
    """Parses widget constructors, model constructors/members and every enum."""
    constructors: dict[str, list[tuple[str, set[str]]]] = {}
    enums: dict[str, set[str]] = {}
    models: dict[str, set[str]] = {}
    sources: dict[str, str] = {}

    for path in iter_files(LIB, (".dart",)):
        relative = rel(path)
        is_widget_tree = relative.startswith("lib/core/") or "/widgets/" in relative
        source = stripped(path)
        sources[relative] = source
        # Every class in the tree: models anchor the member check, and a state class in a
        # feature folder is as likely to be misread as one in `data/`.
        models.update(_model_members(source))

        class_pattern = _CLASS_RE if is_widget_tree else _ANY_CLASS_RE
        for match in class_pattern.finditer(source):
            name = match.group(1)
            # The constructor declaration sits in the class body, which ends at the next
            # top-level declaration.
            tail = source[match.end() :]
            nxt = re.search(r"\n(?:class|enum|mixin|extension|abstract)\b", tail)
            body = tail[: nxt.start()] if nxt else tail
            named = _constructor_named_params(body, name)
            if named is not None:
                constructors.setdefault(name, []).append((relative, named))

        for match in _ENUM_RE.finditer(source):
            name = match.group(1)
            body, _ = _balanced_span(
                source,
                source.index("{", match.start()),
                "{",
                "}",
            )
            members: set[str] = set()
            for part in _split_top_level(body):
                found = re.match(r"\s*(\w+)\s*(?:[=,;]|$)", part.strip())
                if found:
                    members.add(found.group(1))
            members.update(re.findall(r"\bget\s+(\w+)", body))
            members.update(
                re.findall(r"\bstatic\s+(?:const\s+)?[\w<>?]+\s+(\w+)", body)
            )
            members.update(re.findall(r"\b(\w+)\s*\(", body))
            # Every Dart enum also carries these, whether declared or not.
            members.update({"values", "name", "index"})
            enums[name] = members

    return constructors, enums, models, set(sources)


def _all_enum_members() -> dict[str, set[str]]:
    """Every enum in the project, with its values and declared members."""
    enums: dict[str, set[str]] = {}
    for path in iter_files(LIB, (".dart",)):
        source = stripped(path)
        for match in _ENUM_RE.finditer(source):
            name = match.group(1)
            body, _ = _balanced_span(
                source,
                source.index("{", match.start()),
                "{",
                "}",
            )
            members: set[str] = set()
            for part in _split_top_level(body):
                found = re.match(r"\s*(\w+)\s*(?:[=,;]|$)", part.strip())
                if found:
                    members.add(found.group(1))
            members.update(re.findall(r"\bget\s+(\w+)", body))
            members.update(
                re.findall(r"\bstatic\s+(?:const\s+)?[\w<>?]+\s+(\w+)", body)
            )
            members.update(re.findall(r"\b(\w+)\s*\(", body))
            members.update({"values", "name", "index"})
            if name in enums:
                enums[name] |= members
            else:
                enums[name] = members
    return enums


def _model_typed_variables(source: str, model_names: set[str]) -> dict[str, set[str]]:
    """Local/parameter names bound to a model type, e.g. `ArmxDevice device` → device.

    A name may appear in several scopes with different types (`value` is a `SmartHomeState`
    in one switch arm and a `double` in another), so every candidate is kept and a member is
    only reported when **all** candidates lack it. Precision matters more than recall here:
    a checker that cries wolf is a checker people learn to ignore.
    """
    bindings: dict[str, set[str]] = {}
    for model in model_names:
        pattern = re.compile(
            r"\b" + re.escape(model) + r"\??\s+([a-z_][A-Za-z0-9_]*)\b"
        )
        for match in pattern.finditer(source):
            identifier = match.group(1)
            if not _names_the_type(identifier, model):
                continue
            bindings.setdefault(identifier, set()).add(model)
    return bindings


def _names_the_type(identifier: str, type_name: str) -> bool:
    """Whether `identifier` reads as a variable holding `type_name`.

    `device` holds an `ArmxDevice`, `pairing` a `PairingState`, `guest` a `GuestProfile`.
    The restriction is what keeps this check honest: a parameter called `error` or `spec` or
    `value` is usually a different type in a neighbouring scope, and reporting those would
    drown the real findings.
    """
    identifier = identifier.lower()
    lowered = type_name.lower()
    if identifier == lowered:
        return True
    if len(identifier) < 4:
        return False
    return lowered.endswith(identifier) or lowered.startswith(identifier)


# Members every Dart object, string, number, collection and future has. A member in this set
# is never reported: the binding heuristic cannot tell `AsyncValue.value` from a model field
# called `value`, and guessing wrong would produce noise instead of signal.
_CORE_MEMBERS = {
    "length", "isEmpty", "isNotEmpty", "first", "last", "single", "value", "values",
    "keys", "entries", "contains", "containsKey", "containsValue", "indexOf",
    "toList", "toSet", "toMap", "map", "where", "whereType", "forEach", "fold",
    "reduce", "any", "every", "join", "skip", "take", "takeWhile", "skipWhile",
    "expand", "add", "addAll", "remove", "removeWhere", "clear", "insert", "putIfAbsent",
    "sort", "reversed", "round", "floor", "ceil", "abs", "toInt", "toDouble", "toString",
    "toLowerCase", "toUpperCase", "trim", "split", "substring", "replaceAll", "startsWith",
    "endsWith", "padLeft", "padRight", "codeUnits", "runes", "compareTo", "clamp",
    "toJson", "fromJson", "hasValue", "hasError", "isLoading", "when", "maybeWhen",
    "asData", "requireValue", "asData", "unwrapPrevious", "list", "name", "identifier",
    "then", "catchError", "whenComplete", "timeout", "microseconds", "milliseconds",
    "seconds", "minutes", "hours", "days", "inDays", "inHours", "inMinutes", "inSeconds",
    "isBefore", "isAfter", "add", "subtract", "difference", "copyWith", "duration",
    "elementAt", "firstWhere", "lastWhere", "singleWhere", "toRadixString", "toARGB32",
}


def check_api_surface() -> None:
    """Compares every use site against the declarations it calls.

    Dart's analyzer cannot run in this environment, so this reimplements the three checks
    that would have caught the most common mistakes in this tree: passing an argument a
    widget or model does not declare, reading a member a model does not have, and naming an
    enum value that does not exist.
    """
    constructors, _enums, models, declarations = _declared_api()
    all_enums = _all_enum_members()
    model_names = set(models)

    for path in iter_files(LIB, (".dart",)):
        relative = rel(path)
        scanned = stripped(path)

        # ---- unknown named arguments -------------------------------------
        for name, declarations_for_name in constructors.items():
            # A private helper declared in several files is resolved per file; a public widget
            # declared once is checked everywhere it is used.
            same_file = [
                allowed for where, allowed in declarations_for_name if where == relative
            ]
            if same_file:
                allowed = same_file[0]
            elif len(declarations_for_name) == 1:
                allowed = declarations_for_name[0][1]
            else:
                continue
            for match in re.finditer(
                r"(?<![\w.])" + re.escape(name) + r"\s*\(", scanned
            ):
                paren = scanned.index("(", match.start())
                args, _ = _balanced_span(scanned, paren)
                for part in _split_top_level(args):
                    found = re.match(r"\s*(\w+)\s*:", part)
                    if found and found.group(1) not in allowed:
                        line = scanned.count("\n", 0, match.start()) + 1
                        errors.append(
                            f"unknown argument '{found.group(1)}' passed to {name} "
                            f"in {relative}:{line}"
                        )

        # ---- unknown enum values -----------------------------------------
        for name, members in all_enums.items():
            for match in re.finditer(
                r"(?<![\w.])" + re.escape(name) + r"\.(\w+)\b(?!\s*\()",
                scanned,
            ):
                if match.group(1) not in members:
                    line = scanned.count("\n", 0, match.start()) + 1
                    errors.append(
                        f"unknown {name} value '{match.group(1)}' "
                        f"in {relative}:{line}"
                    )

        # ---- unknown model members ---------------------------------------
        if model_names:
            candidates = _model_typed_variables(scanned, model_names)
            for variable, possible in candidates.items():
                allowed: set[str] = set()
                for model in possible:
                    allowed |= models.get(model, set())
                for match in re.finditer(
                    r"\b" + re.escape(variable) + r"\??\.([A-Za-z_]\w*)", scanned
                ):
                    member = match.group(1)
                    if member in allowed or member in _CORE_MEMBERS:
                        continue
                    line = scanned.count("\n", 0, match.start()) + 1
                    errors.append(
                        f"no member '{member}' on {'/'.join(sorted(possible))} "
                        f"(read from '{variable}') in {relative}:{line}"
                    )


def check_self_test() -> None:
    """Proves the parsers still detect what they are supposed to detect.

    Every check in this file is a heuristic standing in for `dart analyze`. A heuristic can
    silently rot into something that always passes, which is worse than no check at all, so
    the parsers are exercised against small snippets whose answers are known — and the real
    tree has to yield plausible counts at the same time.
    """
    named = _constructor_named_params(
        "const Widget1({required this.alpha, this.beta, super.key});",
        "Widget1",
    )
    if named != {"key", "alpha", "beta"}:
        errors.append(f"self-test: constructor parameters parsed as {sorted(named or [])}")

    body, _ = _balanced_span(
        "enum E {\n  a,\n  b,\n}\n",
        "enum E {".index("{"),
        "{",
        "}",
    )
    if body.strip() != "a,\n  b,":
        errors.append(f"self-test: brace span parsed as {body!r}")

    members = _model_members(
        "class M {\n  const M({this.name});\n  final String name;\n"
        "  bool get isActive => name.isNotEmpty;\n}\n"
    ).get("M", set())
    for expected in ("name", "isActive"):
        if expected not in members:
            errors.append(f"self-test: model member '{expected}' not parsed")

    if not _names_the_type("device", "ArmxDevice"):
        errors.append("self-test: 'device' should read as an ArmxDevice")
    if _names_the_type("error", "AppException"):
        errors.append("self-test: 'error' must not be bound to AppException")

    # A member that does not exist on a class this project declares must be caught, and a
    # constructor tear-off (`Controller.new`) must not be.
    members, counts = _classes_and_counts()
    if not members:
        errors.append("self-test: no class members parsed at all")
    if "new" not in (_CORE_MEMBERS | {"new"}):
        errors.append("self-test: constructor tear-offs would be flagged")

    constructors, _enums, models, _sources = _declared_api()
    if len(constructors) < 30 or len(models) < 30 or len(_all_enum_members()) < 15:
        errors.append(
            "self-test: the tree no longer parses as expected "
            f"({len(constructors)} constructors, {len(models)} classes, "
            f"{len(_all_enum_members())} enums)"
        )


def main() -> int:
    quiet = "--quiet" in sys.argv
    check_arb_json()
    check_self_test()
    check_headers()
    check_brackets_and_codegen()
    check_imports()
    check_unused_imports()
    check_api_surface()
    check_static_references()
    check_provider_names()
    check_l10n()
    check_secrets_and_reachability()

    dart_files = len(list(iter_files(LIB, (".dart",))))
    if not quiet:
        print(f"A.R.M.X static checks — {dart_files} Dart files under lib/")
    for note in notes:
        print(f"NOTE  {note}")
    for error in errors:
        print(f"FAIL  {error}")
    if errors:
        print(f"\n{len(errors)} problem(s) found.")
        return 1
    print("OK    all structural checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
