#!/usr/bin/env python3
"""Normalize easy_localization placeholders: ${...} and $var → {} / {var}."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fix_string(s: str) -> str:
    if not isinstance(s, str):
        return s
    # Dart-style ${ ... } → positional {}
    s = re.sub(r"\$\{[^}]+\}", "{}", s)
    # $word → {word} (named / positional for easy_localization)
    s = re.sub(r"\$([a-zA-Z_][a-zA-Z0-9_]*)", r"{\1}", s)
    return s


def patch_file(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    for k, v in list(data.items()):
        if not isinstance(v, str):
            continue
        new = fix_string(v)
        if new != v:
            data[k] = new
            changed += 1
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return changed


def main():
    for name in ("en.json", "uk.json"):
        p = ROOT / "assets" / "translations" / name
        n = patch_file(p)
        print(f"{name}: updated {n} entries")


if __name__ == "__main__":
    main()
