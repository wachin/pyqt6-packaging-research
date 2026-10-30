# Licensing of this repository

This repository mixes content with **different owners and different licences**.
A bare `LICENSE` file at the root cannot describe that honestly, so this page
does.

## What this repository owns, and licenses as GPL-3.0-or-later

`LICENSE` (the canonical GNU GPL version 3 text) applies to the content the
repository owner wrote:

| Path | What it is |
|---|---|
| `.dsh/skills/` | the six agent Skills |
| `*/PACKAGING_STUDY.md`, `*/PYQT6_PACKAGING_TUTORIAL.md` | the case studies |
| `03-Promt-MAESTRO-resultado/` | master guide, master tutorial, evidence matrix, fix log |
| `tools/` | `extract_evidence.py`, `build_skills_bundle.py` |
| `experiments/` | the PyInstaller-vs-Nuitka kit |
| `SKILLS.md`, `SKILLS-VERIFICATION.md`, `EVIDENCE_INDEX.md`, `AGENTS.md`, `README.md` | documentation |
| `LICENSING.md` (this file) | |

`GPL-3.0-**or-later**` — you may use any later version of the GPL if you prefer.
If you want `only`, that is a one-word change, and it is the owner's call.

**Read the consequence before copying a recipe.** The Skills contain shell,
Python, PowerShell and NSIS code. That code is part of this GPL-covered work, so
copying it into your project makes your project subject to the GPL. Reading the
procedure and implementing it yourself does not. If you are building a
proprietary application, this matters — it is the main practical cost of a
copyleft licence on packaging recipes, and it is deliberate here.

## What this repository does NOT own and does NOT relicense

### The eight submodules

`dikte/`, `CustomKnight-Creator/`, `pyzo/`, `CARA/`, `napari/`,
`napari-packaging/`, and the two owner applications under `my-PyQt6-Apps/` are
separate repositories. Each stays under its own licence:

| Project | Licence |
|---|---|
| CARA, CustomKnight-Creator, dikte, TBO, lucio-iva-calculator | GPL |
| napari, pyzo | BSD |
| napari/packaging | **no licence file** |

The GPL-3.0 in this repository does not, and cannot, apply to any of them.

### The evidence packs

`<project>-resultados/_evidence/` and `my-PyQt6-Apps/<app>-resultados/_evidence/`
are **verbatim copies** of files from those upstream projects, extracted by
`tools/extract_evidence.py` and pinned to a commit. They are evidence, not this
repository's work, and they remain under the upstream licence recorded in each
pack's `PROVENANCE.md`. Where that licence is BSD, the BSD terms apply. Where
`napari/packaging` is concerned there is **no licence granted at all** — quote it
for study, do not reuse it.

If you redistribute an evidence pack, carry its `PROVENANCE.md` and
`SHA256SUMS` with it.

### The GPL text itself

`LICENSE` is the standard GNU GPL version 3 text. It is not copyrighted by this
repository and you may copy it freely, as the FSF intends.

## Source code in this repository

There is almost none: the two scripts in `tools/` are GPL-3.0-or-later like the
rest. Nothing here is a library, an application or a package, and nothing in this
repository is installed as a dependency by anything.

## Questions

If you want to reuse something and the answer is not clear from this page, open
an issue. The answer is more likely to be "yes, with attribution" than "no", but
it depends on which of the four categories above you are looking at.
