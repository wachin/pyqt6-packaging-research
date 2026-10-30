#!/usr/bin/env python3
"""Build the distributable bundle of the six PyQt6 packaging Skills.

Why this exists
---------------
The Skills are useful outside this repository, and the way to move them is a
single archive that drops straight into a harness's skill root. A ZIP of the
`.dsh/skills` directory would almost work and would fail for three reasons worth
naming:

* a harness discovers a skill from a directory that contains ``SKILL.md``, one
  level below its skill root. A wrapper directory in the archive means the user
  extracts ``skills/pyqt6-.../SKILL.md`` and nothing is found;
* the bundle needs its licence next to the content it covers, and a loose
  ``README.md`` in a skill root is treated as a skill candidate;
* two builds of the same commit should be the same bytes, so the digest in
  ``SHA256SUMS`` means something.

So the layout is the six skill directories at the top level, plus one ``_meta/``
directory for everything that is not a skill. A directory without a ``SKILL.md``
is skipped by the filesystem provider, silently, which is why ``_meta/`` is safe.

Usage
-----
    python3 tools/build_skills_bundle.py --version 1.0.0
    python3 tools/build_skills_bundle.py --version 1.0.0 --output-dir dist

Produces::

    dist/pyqt6-packaging-skills-<version>.tar.gz
    dist/SHA256SUMS                     # one line, for the tarball

Install (see SKILLS.md for the alternatives)::

    curl -fsSL .../pyqt6-packaging-skills-<version>.tar.gz | tar -xz -C ~/.dsh/skills

Exit codes: 0 on success, 1 on any refusal. A refusal never leaves a partial
archive behind.

One consequence worth knowing before comparing digests: ``_meta/README.md`` records
the source commit, so the digest identifies *this commit's bundle*. Build after
committing and it matches what CI published for the same commit, byte for byte;
build from an uncommitted tree and it records the previous commit instead, which
changes the digest for a reason that is not a bug.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import os
import re

import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / ".dsh" / "skills"
META_NAME = "_meta"

#: Files copied into ``_meta/``. Order matters only for documentation purposes;
#: the archive itself is written in sorted order.
META_FILES = [
    "LICENSE",
    "SKILLS.md",
    "SKILLS-VERIFICATION.md",
]

#: Reproducible-builds convention: honour SOURCE_DATE_EPOCH, otherwise pin the
#: epoch. Git does not preserve mtimes, so using the files' own timestamps would
#: make the digest depend on the machine that built the bundle.
DEFAULT_MTIME = 0


def fail(message: str) -> int:
    print(f"refusing to build: {message}", file=sys.stderr)
    return 1


def frontmatter(text: str) -> dict[str, str] | None:
    """Minimal, dependency-free read of a SKILL.md frontmatter block.

    Deliberately not a YAML parser: the bundle build must not need PyYAML, and
    the only fields that decide whether a harness can load the skill are
    ``name`` and ``description``. Anything more elaborate belongs in the
    verification step, which parses real YAML.
    """
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    block = text[4:end]
    fields: dict[str, str] = {}
    for line in block.splitlines():
        match = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):\s*(.+?)\s*$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip("'\"")
    return fields


def collect_skills() -> list[Path]:
    """Skill directories to ship, sorted, validated."""
    if not SKILLS_DIR.is_dir():
        raise SystemExit(fail(f"no skill directory at {SKILLS_DIR}"))
    skills: list[Path] = []
    for entry in sorted(SKILLS_DIR.iterdir()):
        if not entry.is_dir():
            continue
        skill_file = entry / "SKILL.md"
        if not skill_file.is_file():
            raise SystemExit(fail(f"{entry.name}/ has no SKILL.md"))
        fields = frontmatter(skill_file.read_text(encoding="utf-8"))
        if fields is None:
            raise SystemExit(fail(f"{entry.name}/SKILL.md has no frontmatter"))
        for required in ("name", "description"):
            if not fields.get(required):
                raise SystemExit(fail(f"{entry.name}/SKILL.md frontmatter lacks {required}"))
        if fields["name"] != entry.name:
            raise SystemExit(
                fail(
                    f"{entry.name}/SKILL.md declares name {fields['name']!r}; "
                    "the directory name and the skill name must agree"
                )
            )
        skills.append(entry)
    if not skills:
        raise SystemExit(fail(f"no skills found in {SKILLS_DIR}"))
    return skills


def source_commit() -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, check=True,
        )
        return out.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def meta_readme(version: str, names: list[str], commit: str) -> str:
    listing = "\n".join(f"| `{name}` | see its SKILL.md |" for name in names)
    return f"""# PyQt6 packaging skills

Bundle version **{version}**, built from `pyqt6-packaging-research` at
`{commit}`.

Six agent Skills for packaging a Python/PyQt6 desktop application, derived from
eight real projects and from one controlled build-tool experiment:

| Skill | Purpose |
|---|---|
{listing}

## What they produce

AppImage, Debian `.deb`, macOS portable `.zip`, Windows portable `.zip` and a
Windows NSIS `setup.exe` — with Windows built by Nuitka and Linux/macOS by
PyInstaller, which is the split the evidence supports.

## Install

Into your user-scope skill root, available in every project:

```bash
curl -fsSL <release-url>/pyqt6-packaging-skills-{version}.tar.gz |
  tar -xz -C ~/.dsh/skills
```

Or per project, which wins over the user scope:

```bash
mkdir -p .dsh/skills
curl -fsSL <release-url>/pyqt6-packaging-skills-{version}.tar.gz |
  tar -xz -C .dsh/skills
```

Verify the download first:

```bash
sha256sum -c SHA256SUMS
```

## What is in `_meta/`

`LICENSE`, `SKILLS.md` and `SKILLS-VERIFICATION.md`. `LICENSE` opens with a short scope
notice and then carries the complete GPL-3.0 text. A harness
looks for a `SKILL.md` inside each top-level directory, so `_meta/` is skipped —
it is here for the human, not for the agent.

## Read the verification page before trusting a Skill

`_meta/SKILLS-VERIFICATION.md` records what each Skill covers, the defects an
audit found in them, and what is deliberately **not** verified. The short version
of the last part: nothing here has been executed end to end on a new application,
the signing paths were never run, and the antivirus measurement is two
applications on Windows only.

## Licence

GPL-3.0-or-later for the Skills themselves; see `_meta/LICENSE`, whose opening
notice explains what that does and does not cover. They quote and summarise other
projects' packaging files, and that material keeps its own licence. In particular,
copying a code snippet from a Skill into your project brings your project under
the GPL.
"""


def build(version: str, target: Path, skills: list[Path], meta_sources: dict[str, Path],
          readme: str, commit: str) -> None:
    mtime = int(os.environ.get("SOURCE_DATE_EPOCH", DEFAULT_MTIME))
    bufsize = 1024 * 1024

    def add_path(tar: tarfile.TarFile, path: Path, arcname: str) -> None:
        info = tar.gettarinfo(str(path), arcname=arcname)
        info.uid = info.gid = 0
        info.uname = info.gname = ""
        info.mtime = mtime
        info.mode = 0o755 if info.isdir() else 0o644
        if info.isdir():
            tar.addfile(info)
            return
        with open(path, "rb") as handle:
            tar.addfile(info, handle)

    with open(target, "wb") as raw:
        # mtime=0 in the gzip header too, or two builds differ in bytes alone.
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=mtime, compresslevel=9) as gz:
            with tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as tar:
                for skill in skills:
                    add_path(tar, skill, skill.name)
                    for child in sorted(skill.rglob("*")):
                        add_path(tar, child, str(child.relative_to(ROOT / ".dsh" / "skills")))

                meta_info = tarfile.TarInfo(META_NAME)
                meta_info.type = tarfile.DIRTYPE
                meta_info.mode = 0o755
                meta_info.uid = meta_info.gid = 0
                meta_info.uname = meta_info.gname = ""
                meta_info.mtime = mtime
                tar.addfile(meta_info)

                readme_bytes = readme.encode("utf-8")
                readme_info = tarfile.TarInfo(f"{META_NAME}/README.md")
                readme_info.size = len(readme_bytes)
                readme_info.mode = 0o644
                readme_info.uid = readme_info.gid = 0
                readme_info.uname = readme_info.gname = ""
                readme_info.mtime = mtime
                tar.addfile(readme_info, io.BytesIO(readme_bytes))

                for name, path in sorted(meta_sources.items()):
                    add_path(tar, path, f"{META_NAME}/{name}")


def post_conditions(target: Path, skills: list[Path], version: str) -> None:
    """Read the archive back and assert the shape a harness needs."""
    with tarfile.open(target, "r:gz") as tar:
        names = tar.getnames()

    problems: list[str] = []
    if any(n.startswith("/") or ".." in Path(n).parts for n in names):
        problems.append("an entry has an absolute path or a parent reference")

    top = {n.split("/")[0] for n in names}
    expected = {s.name for s in skills} | {META_NAME}
    if top != expected:
        problems.append(f"top level is {sorted(top)}, expected {sorted(expected)}")

    for skill in skills:
        if f"{skill.name}/SKILL.md" not in names:
            problems.append(f"{skill.name}/SKILL.md missing from the archive")
    if any(n == f"{META_NAME}/SKILL.md" for n in names):
        problems.append("_meta/SKILL.md exists, which would make _meta a skill")
    for required in ("README.md", "LICENSE", "SKILLS.md",
                     "SKILLS-VERIFICATION.md"):
        if f"{META_NAME}/{required}" not in names:
            problems.append(f"_meta/{required} missing")

    if problems:
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        raise SystemExit(fail(f"{target.name} does not have the shape a harness needs"))

    print(f"{target.name}: {len(names)} entries, top level {sorted(top)}")


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def release_notes(version: str, repository: str) -> str:
    """Markdown for the GitHub release body.

    Generated here rather than inside a workflow heredoc so it can be built and
    read locally: nested quoting inside a YAML block scalar is exactly the kind of
    thing that silently produces a mangled release page.
    """
    base = f"https://github.com/{repository}/releases/download/skills-v{version}"
    archive = f"pyqt6-packaging-skills-{version}.tar.gz"
    return f"""Six agent Skills for packaging a Python/PyQt6 desktop application, derived
from eight real projects and one controlled build-tool experiment.

They cover the five artifacts this research actually validates: AppImage,
Debian `.deb`, macOS portable `.zip`, Windows portable `.zip` and a Windows NSIS
`setup.exe` — with Windows built by Nuitka and Linux/macOS by PyInstaller.

## Install

```bash
curl -fsSL {base}/{archive} | tar -xz -C ~/.dsh/skills
```

Verify first if you prefer:

```bash
curl -fsSLO {base}/{archive}
curl -fsSLO {base}/SHA256SUMS
sha256sum -c SHA256SUMS
```

The archive holds the six skill directories at its top level plus a `_meta/`
directory with the licence, the install notes and `SKILLS-VERIFICATION.md` — the
audit of what these Skills do and do not cover. Read that last one before
trusting a procedure: nothing here has been executed end to end on a new
application, the signing paths were never run, and the antivirus measurement is
two applications on Windows only.

## Licence

GPL-3.0-or-later. `_meta/LICENSE` opens with a short scope notice, then the
complete GPL-3.0 text. The Skills quote and summarise other projects' packaging
files, and that material keeps its own licence. Copying a code snippet from a
Skill into your project brings your project under the GPL.
"""


def repository_slug() -> str:
    """`owner/name` from the git remote, with a visible placeholder as fallback."""
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "remote", "get-url", "origin"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "OWNER/REPO"
    match = re.search(r"[:/]([^/:]+/[^/:]+?)(?:\.git)?$", out)
    return match.group(1) if match else "OWNER/REPO"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Build the Skills release bundle.")
    parser.add_argument("--version", required=True, help="bundle version, e.g. 1.0.0")
    parser.add_argument("--output-dir", default="dist", help="where to write the archive")
    parser.add_argument("--no-reproducibility-check", action="store_true",
                        help="skip the second build and its digest comparison")
    args = parser.parse_args(argv[1:])

    if not re.fullmatch(r"\d+\.\d+\.\d+([0-9A-Za-z.+-]*)?", args.version):
        raise SystemExit(fail(f"{args.version!r} is not a semantic version"))

    skills = collect_skills()
    commit = source_commit()

    meta_sources: dict[str, Path] = {}
    for name in META_FILES:
        path = ROOT / name
        if not path.is_file():
            raise SystemExit(fail(f"{name} is missing; the bundle must carry it"))
        meta_sources[name] = path

    out_dir = (ROOT / args.output_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"pyqt6-packaging-skills-{args.version}.tar.gz"

    names = [s.name for s in skills]
    readme = meta_readme(args.version, names, commit)

    build(args.version, target, skills, meta_sources, readme, commit)
    post_conditions(target, skills, args.version)

    digest = sha256_of(target)
    sums = out_dir / "SHA256SUMS"
    sums.write_text(f"{digest}  {target.name}\n", encoding="utf-8")
    print(f"sha256 {digest}")

    notes_path = out_dir / "RELEASE-NOTES.md"
    notes_path.write_text(
        release_notes(args.version, repository_slug()), encoding="utf-8"
    )

    if not args.no_reproducibility_check:
        with tempfile.TemporaryDirectory() as tmp:
            second = Path(tmp) / target.name
            build(args.version, second, skills, meta_sources, readme, commit)
            if sha256_of(second) != digest:
                raise SystemExit(
                    fail("two builds of the same tree differ; the digest is not a "
                         "stable identity. Check that SOURCE_DATE_EPOCH and file "
                         "ordering are respected.")
                )
            print("reproducible: a second build produced the same digest")

    print(f"wrote {target.relative_to(ROOT)}, {sums.relative_to(ROOT)} and {notes_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
