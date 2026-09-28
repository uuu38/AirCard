#!/usr/bin/env python3
"""
Localization coverage checker for AirCard.

Keys are the English source text, so this script cross-checks three sources:

  1. Keys referenced by Swift code (Text/Button/Label/help/alert/L/Lf and the
     rawValue of the display enums).
  2. Keys declared in Localizations/en.lproj/Localizable.strings (the reference).
  3. Keys declared in every other Localizations/<lang>.lproj/Localizable.strings.

It reports keys used in code but missing from the reference, keys declared but
unused, per-language missing/extra keys and format-specifier mismatches.

Usage:
    python3 tools/check_localizations.py            # report only
    python3 tools/check_localizations.py --strict   # exit 1 when issues found
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_SOURCES = ["AirCardApp.swift", "Localization.swift"]
LOCALIZATIONS_DIR = ROOT / "Localizations"
REFERENCE_LANG = "en"

# Enum cases rendered through L(SomeEnum.rawValue) — their raw values are keys.
DISPLAY_ENUMS = [
    "AppTab",
    "PasscodeTabMode",
    "CreatorSubMode",
    "PasscodeLanguageTarget",
    "PasscodeBoldTarget",
]

# SwiftUI / AppKit APIs whose first string literal argument is a localization key.
KEY_CALL_PATTERNS = [
    r'\bText\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bButton\(\s*"((?:[^"\\]|\\.)*)"\s*[,{)]',
    r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'\.help\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'\.alert\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'\bL\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'\bLf\(\s*"((?:[^"\\]|\\.)*)"',
]

FORMAT_SPECIFIER_RE = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[dioufFeEgGxXcs@p]")

# Strings that must stay identical in every language (brand names, technical
# identifiers, bare punctuation/numbers). They are intentionally absent from the
# .strings tables and are therefore never reported as coverage gaps.
VERBATIM_KEYS = {
    "AirCard",
    "OK",
    "&",
    "·",
    "iPhone",
    "1.",
    "2.",
    "3.",
    "v1.2.4",
    ".passthm standard (Cowabunga / Nugget)",
    "airlift (AirTraffic sync escape)",
}


def swift_source_keys() -> set[str]:
    """Collect localization keys referenced by the Swift sources."""
    keys: set[str] = set()
    text = ""
    for name in SWIFT_SOURCES:
        path = ROOT / name
        if path.is_file():
            text += path.read_text(encoding="utf-8") + "\n"

    for pattern in KEY_CALL_PATTERNS:
        for match in re.finditer(pattern, text):
            raw = match.group(1)
            # `Text("\(value)")` is a Swift interpolation, not a key.
            if raw.startswith("\\("):
                continue
            keys.add(_unescape(raw))

    for enum_name in DISPLAY_ENUMS:
        block = re.search(rf"enum\s+{enum_name}\s*:[^{{]*\{{(.*?)\n\}}", text, re.DOTALL)
        if not block:
            continue
        for match in re.finditer(r'case\s+\w+\s*=\s*"((?:[^"\\]|\\.)*)"', block.group(1)):
            keys.add(_unescape(match.group(1)))

    # Backend message templates: the English format strings that
    # Localization.swift maps backend `code` values onto.
    catalog = re.search(
        r"private static let catalog: \[String: \(key: String, params: \[String\]\)\] = \[(.*?)\n    \]",
        text,
        re.DOTALL,
    )
    if catalog:
        for match in re.finditer(r'\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*\[', catalog.group(1)):
            keys.add(_unescape(match.group(1)))
    return keys - VERBATIM_KEYS


def _unescape(value: str) -> str:
    return value.replace('\\"', '"').replace("\\n", "\n")


def parse_strings(path: Path) -> dict[str, str]:
    """Parse a .strings file into a {key: value} mapping."""
    if not path.is_file():
        return {}
    pattern = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.DOTALL)
    content = path.read_text(encoding="utf-8")
    return {_unescape(key): value for key, value in pattern.findall(content)}


def localized_languages() -> list[str]:
    if not LOCALIZATIONS_DIR.is_dir():
        return []
    return sorted(
        path.name[: -len(".lproj")]
        for path in LOCALIZATIONS_DIR.iterdir()
        if path.is_dir() and path.name.endswith(".lproj")
    )


def format_specifiers(text: str) -> list[str]:
    return FORMAT_SPECIFIER_RE.findall(text)


def main() -> int:
    parser = argparse.ArgumentParser(description="Check AirCard localization coverage.")
    parser.add_argument("--strict", action="store_true", help="exit 1 when issues are found")
    args = parser.parse_args()

    code_keys = swift_source_keys()
    languages = localized_languages()
    if REFERENCE_LANG not in languages:
        print(f"ERROR: Localizations/{REFERENCE_LANG}.lproj is missing.")
        return 1

    reference = parse_strings(LOCALIZATIONS_DIR / f"{REFERENCE_LANG}.lproj" / "Localizable.strings")
    problems = 0

    missing_in_reference = sorted(key for key in code_keys if key not in reference)
    if missing_in_reference:
        problems += len(missing_in_reference)
        print(f"⚠️  {len(missing_in_reference)} key(s) used in code but missing from {REFERENCE_LANG}.lproj:")
        for key in missing_in_reference:
            print(f"    - {key}")

    unused = sorted(key for key in reference if key not in code_keys)
    if unused:
        print(f"ℹ️  {len(unused)} key(s) declared in {REFERENCE_LANG}.lproj but unused in code:")
        for key in unused:
            print(f"    - {key}")

    print(f"\nReference: {REFERENCE_LANG}.lproj ({len(reference)} keys), code references {len(code_keys)} keys\n")

    for lang in languages:
        if lang == REFERENCE_LANG:
            continue
        table = parse_strings(LOCALIZATIONS_DIR / f"{lang}.lproj" / "Localizable.strings")
        missing = sorted(key for key in reference if key not in table)
        extra = sorted(key for key in table if key not in reference)
        mismatched = []
        for key, value in table.items():
            if key not in reference:
                continue
            wanted = sorted(format_specifiers(reference[key]))
            got = sorted(format_specifiers(value))
            if wanted != got:
                mismatched.append(f"{key} → expected {wanted}, found {got}")

        translated = len(reference) - len(missing)
        percentage = (translated / len(reference) * 100) if reference else 100.0
        status = "OK" if not (missing or extra or mismatched) else "ISSUES"
        print(f"[{lang}] {status} — {translated}/{len(reference)} ({percentage:.0f}%) translated")

        for item in missing:
            problems += 1
            print(f"    missing: {item}")
        for item in extra:
            problems += 1
            print(f"    extra:   {item}")
        for item in mismatched:
            problems += 1
            print(f"    format:  {item}")

    print()
    if problems:
        print(f"❌ {problems} localization issue(s) found.")
        return 1 if args.strict else 0
    print("✅ All localization files are complete and consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
