#!/usr/bin/env python3
"""
Check PYQT6-GENESIS-PACKAGING/ for stale directory names and, if any, drift.

`PYQT6-GENESIS-PACKAGING/` holds every evidence pack with the directory names
translated from Spanish to English. The Spanish-named source folders were
removed, so for all eight packs this is now the only copy and there is nothing
to compare their bytes against.

What remains checkable is the failure the split used to cause: a study that sends
a reader to a directory name which no longer exists. That is silent - the reader
follows the citation, finds nothing, and cannot tell whether the research is
wrong or the path is stale - so it is checked on every run.

If a source pack ever reappears at `<project>-resultados/` or
`my-PyQt6-Apps/<app>-resultados/`, the script goes back to comparing that pair
byte for byte, applying the two documented rewrites:

  * `<project>-resultados/`            -> `PYQT6-GENESIS-PACKAGING/<project>-results/`
  * `my-PyQt6-Apps/<app>-resultados/`  -> `PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/<app>-results/`

Two transformations are expected inside Markdown files, and only those two: a
reference to a results directory becomes the translated name, and the owner's
application directory becomes `wachin-PyQt6-Apps/`. Everything else - including
the `_evidence/` bytes - must be identical.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "PYQT6-GENESIS-PACKAGING"

OWNER_PREFIX = "my-PyQt6-Apps"
BUNDLE_OWNER_PREFIX = "wachin-PyQt6-Apps"


def translate(text: str) -> str:
    """Apply the two documented rewrites, in the order they must be applied."""
    text = re.sub(
        rf"{OWNER_PREFIX}/([a-z0-9-]+)-resultados\b",
        rf"{BUNDLE_OWNER_PREFIX}/\1-results",
        text,
    )
    return re.sub(r"\b([A-Za-z0-9-]+)-resultados\b", r"\1-results", text)


def pairs() -> list[tuple[Path, Path]]:
    """(canonical directory, bundle directory) for every pack."""
    found: list[tuple[Path, Path]] = []
    for canonical in sorted(ROOT.glob("*-resultados")):
        bundle = TARGET / f"{canonical.name.removesuffix('-resultados')}-results"
        found.append((canonical, bundle))
    owner_root = ROOT / OWNER_PREFIX
    for canonical in sorted(owner_root.glob("*-resultados")):
        bundle = TARGET / BUNDLE_OWNER_PREFIX / f"{canonical.name.removesuffix('-resultados')}-results"
        found.append((canonical, bundle))
    return found


def expected_bytes(source: Path) -> bytes:
    raw = source.read_bytes()
    if source.suffix != ".md":
        return raw
    return translate(raw.decode("utf-8")).encode("utf-8")


def check(list_pairs: bool) -> int:
    if not TARGET.is_dir():
        print(f"missing: {TARGET.relative_to(ROOT)}", file=sys.stderr)
        return 1

    problems: list[str] = []
    checked = 0

    for canonical, bundle in pairs():
        if list_pairs:
            print(f"  {canonical.name} -> {bundle.relative_to(TARGET)}")
        if not bundle.is_dir():
            problems.append(f"{bundle.relative_to(ROOT)}: missing (source {canonical.name})")
            continue

        sources = {
            p.relative_to(canonical).as_posix(): p
            for p in canonical.rglob("*")
            if p.is_file()
        }
        copies = {
            p.relative_to(bundle).as_posix(): p
            for p in bundle.rglob("*")
            if p.is_file()
        }

        for name, source in sorted(sources.items()):
            if name not in copies:
                problems.append(f"{bundle.relative_to(ROOT)}/{name}: missing")
                continue
            if copies[name].read_bytes() != expected_bytes(source):
                problems.append(
                    f"{bundle.relative_to(ROOT)}/{name}: differs from "
                    f"{canonical.name}/{name}"
                )
            checked += 1

        for name in sorted(set(copies) - set(sources)):
            problems.append(f"{bundle.relative_to(ROOT)}/{name}: not present in the source pack")

    # The bundle must not send a reader to a directory name that exists only in
    # the canonical layout. Its own README is the exception: it exists precisely to
    # explain both layouts, so it has to name the canonical directories.
    index = TARGET / "README.md"
    for p in sorted(TARGET.rglob("*.md")):
        if p == index:
            continue
        text = p.read_text(encoding="utf-8")
        for match in re.finditer(r"[A-Za-z0-9_/-]*-resultados\b", text):
            problems.append(f"{p.relative_to(ROOT)}: stale path {match.group(0)!r}")

    if problems:
        print("the reader-facing copy is out of sync:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print(
            "\nFix by copying the canonical file and re-applying the two rewrites, "
            "or regenerate the folder from the packs.",
            file=sys.stderr,
        )
        return 1

    if checked:
        print(f"in sync: {checked} files compared across {len(pairs())} packs")
    else:
        print(
            "no source packs remain: every pack is single-copy, so only stale "
            "directory names were checked"
        )
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--list", action="store_true", help="print every pair checked")
    return check(parser.parse_args(argv[1:]).list)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
