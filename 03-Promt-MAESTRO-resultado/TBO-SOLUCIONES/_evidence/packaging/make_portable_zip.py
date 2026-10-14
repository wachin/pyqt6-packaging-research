#!/usr/bin/env python3
"""Create a ZIP archive whose entry names are conformant, forward-slash paths.

Why this exists
---------------
A Windows PowerShell 5.1 build script cannot be trusted to produce a conformant
archive with the obvious APIs:

* ``Compress-Archive`` writes the entry separator as a **backslash**.
* ``ZipFile::CreateFromDirectory`` writes backslashes too, unless the *host*
  application targets .NET Framework 4.6.1 or later. Windows PowerShell 5.1
  targets an older framework, so it keeps the old behaviour. Microsoft documents
  the switch at
  https://learn.microsoft.com/en-us/dotnet/framework/migration-guide/mitigation-ziparchiveentry-fullname-path-separator

The ZIP specification (APPNOTE.TXT section 4.4.17.1) requires a forward slash,
and archives that break the rule extract wrongly everywhere except Windows: on
Linux or macOS ``unzip`` treats ``\\`` as an ordinary character in the filename,
so a tree collapses into flat files literally named ``TBO\\python312.dll``.

CPython's :mod:`zipfile` normalises the separator itself, in ``ZipInfo.__init__``::

    if os.sep != "/" and os.sep in filename:
        filename = filename.replace(os.sep, "/")

so it is conformant on Windows by construction. This script builds the entry
name from ``Path.parts`` as well, so the result does not depend on that
implementation detail being preserved.

Usage
-----
    make_portable_zip.py <source-directory> <output.zip>

The archive contains the *contents* of the source directory: a file at
``<source>/TBO/TBO.exe`` becomes the entry ``TBO/TBO.exe``.
"""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path


def arcname_for(path: Path, root: Path) -> str:
    """Archive entry name for `path`, always joined with forward slashes.

    Built from ``Path.parts`` rather than from the string form, because on
    Windows ``str(Path)`` uses a backslash between components: joining the parts
    keeps "separator" and "character inside a filename" distinguishable.

    Raises ValueError if a path *component* itself contains a backslash. That
    cannot happen in a correct build on any platform, and turning such a name
    into a path separator would silently reshape the tree.
    """
    parts = path.relative_to(root).parts
    offenders = [p for p in parts if "\\" in p]
    if offenders:
        raise ValueError(
            f"path component contains a literal backslash: {offenders[0]!r} "
            f"(in {path})"
        )
    return "/".join(parts)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    source = Path(argv[1]).resolve()
    target = Path(argv[2]).resolve()

    if not source.is_dir():
        print(f"source directory not found: {source}", file=sys.stderr)
        return 1

    files = sorted(p for p in source.rglob("*") if p.is_file())
    if not files:
        print(f"source directory is empty: {source}", file=sys.stderr)
        return 1

    try:
        entries = [(p, arcname_for(p, source)) for p in files]
    except ValueError as error:
        print(f"refusing to archive: {error}", file=sys.stderr)
        return 1

    target.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path, arcname in entries:
            archive.write(path, arcname)

    # Post-condition: the archive that was actually written must be conformant.
    # This is a check on zipfile's behaviour, not on our own logic, so it stays
    # useful even though the names above are already correct by construction.
    with zipfile.ZipFile(target) as archive:
        names = archive.namelist()

    malformed = [n for n in names if "\\" in n]
    if malformed:
        print(
            f"refusing to ship a non-conformant archive: {len(malformed)} of "
            f"{len(names)} entries use a backslash, e.g. {malformed[0]!r}",
            file=sys.stderr,
        )
        target.unlink(missing_ok=True)
        return 1

    print(f"{target.name}: {len(names)} entries, all with forward-slash separators")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
