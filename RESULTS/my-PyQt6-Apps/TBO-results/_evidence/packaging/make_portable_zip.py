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
                          [--prefix NAME] [--require FILE]...

By default the archive contains the *contents* of the source directory: a file
at ``<source>/TBO/TBO.exe`` becomes the entry ``TBO/TBO.exe``.

``--prefix NAME`` puts every entry under a single top-level folder: the same
file becomes ``NAME/TBO/TBO.exe``. That is what a portable archive should look
like - an archive that unpacks a folder plus a stray license file beside it, or
that scatters its DLLs into whatever directory the user happened to be in, is
the kind of thing that gets reported as a broken download.

``--require FILE`` asserts that the finished archive really does contain
``<prefix>/FILE``, and the run fails (removing the archive) if it does not.
This is what catches a staging mistake upstream: ``Copy-Item -Destination
<existing directory> -Recurse`` in PowerShell copies the *folder* into the
destination rather than its contents, so a staging step that looked right
produces a nested ``NAME/TBO/TBO.exe`` and no ``NAME/TBO.exe`` at all. Without
this check that ships silently. Repeat the flag once per required file.
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path


def arcname_for(path: Path, root: Path, prefix: str = "") -> str:
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
    name = "/".join(parts)
    return f"{prefix}/{name}" if prefix else name


def validate_prefix(prefix: str) -> None:
    """Reject a prefix that would not produce exactly one top-level folder."""
    if not prefix:
        return
    if "/" in prefix or "\\" in prefix:
        raise ValueError(
            f"--prefix must be a single path component, got {prefix!r}"
        )
    if prefix in (".", ".."):
        raise ValueError(f"--prefix cannot be {prefix!r}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="make_portable_zip.py",
        description="Create a ZIP archive with conformant, forward-slash entries.",
    )
    parser.add_argument("source", help="directory whose contents are archived")
    parser.add_argument("target", help="path of the .zip to write")
    parser.add_argument(
        "--prefix",
        default="",
        metavar="NAME",
        help="put every entry inside a single top-level folder called NAME",
    )
    parser.add_argument(
        "--require",
        action="append",
        default=[],
        metavar="FILE",
        help="fail unless the archive contains FILE (repeatable)",
    )
    args = parser.parse_args(argv[1:])

    source = Path(args.source).resolve()
    target = Path(args.target).resolve()
    prefix = args.prefix

    try:
        validate_prefix(prefix)
    except ValueError as error:
        print(f"refusing to archive: {error}", file=sys.stderr)
        return 1

    if not source.is_dir():
        print(f"source directory not found: {source}", file=sys.stderr)
        return 1

    files = sorted(p for p in source.rglob("*") if p.is_file())
    if not files:
        print(f"source directory is empty: {source}", file=sys.stderr)
        return 1

    try:
        entries = [(p, arcname_for(p, source, prefix)) for p in files]
    except ValueError as error:
        print(f"refusing to archive: {error}", file=sys.stderr)
        return 1

    target.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path, arcname in entries:
            archive.write(path, arcname)

    # Post-conditions. These check the archive that was actually written rather
    # than our own bookkeeping, so they stay useful even though the names above
    # are correct by construction.
    with zipfile.ZipFile(target) as archive:
        names = archive.namelist()

    problems: list[str] = []

    malformed = [n for n in names if "\\" in n]
    if malformed:
        problems.append(
            f"{len(malformed)} of {len(names)} entries use a backslash, "
            f"e.g. {malformed[0]!r}"
        )

    if prefix:
        top_level = {n.split("/")[0] for n in names}
        if top_level != {prefix}:
            problems.append(
                f"expected every entry under {prefix!r}, found top-level "
                f"entries {sorted(top_level)}"
            )

    wanted = [f"{prefix}/{name}" if prefix else name for name in args.require]
    missing = [name for name in wanted if name not in names]
    if missing:
        problems.append(f"required entries missing from the archive: {missing}")

    if problems:
        print("refusing to ship this archive:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        target.unlink(missing_ok=True)
        return 1

    described = (
        f"{len(names)} entries under {prefix!r}"
        if prefix
        else f"{len(names)} entries"
    )
    print(f"{target.name}: {described}, all with forward-slash separators")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))


