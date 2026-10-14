# PyQt6 Packaging Research

Research repository for studying how real-world Python/Qt desktop applications are packaged and distributed on **Windows, Linux, and macOS**.

The goal is not to develop a new application in this repository. Instead, it collects selected open-source projects as **Git submodules** so their build, packaging, release, signing, and CI/CD infrastructure can be studied side by side.

## Goals

The main objective is to create a practical, evidence-based guide for packaging my own **PyQt6 desktop applications**.

The research focuses on:

### Windows

- PyInstaller
- Nuitka
- `onefile` vs `onedir` / standalone builds
- Windows executables
- Portable distributions
- Installers
- Inno Setup, NSIS, MSI/MSIX, or other installer systems
- Application metadata and manifests
- Code signing / Authenticode
- SmartScreen reputation
- VirusTotal and antivirus false positives
- Legitimate techniques for reducing false-positive detections
- Release checksums and provenance

A particularly important research question is whether PyInstaller can be configured and used in ways that reduce antivirus false positives. I have previously experienced false positives with PyInstaller-built executables while having better results with Nuitka, so both approaches are studied rather than assuming one is universally better.

There is **no assumption that zero VirusTotal detections can be guaranteed**. The goal is to identify legitimate professional distribution practices, not antivirus evasion techniques.

### Linux

The research focuses on two different distribution formats:

#### AppImage

- Standalone application bundling
- AppDir structure
- AppRun
- `.desktop` integration
- Icons
- Qt plugins
- PyQt6 libraries
- Python runtime
- AppImage creation tools
- GLIBC compatibility
- Portability between Linux distributions

#### Debian packages

- `.deb` package structure
- Debian metadata
- Dependency management
- System Python/PyQt6 vs bundled runtimes
- Installation paths
- Desktop integration
- Icons and application metadata
- Package validation and testing

### macOS

- `.app` bundles
- PyInstaller and Nuitka on macOS
- `Info.plist`
- `.icns` icons
- Qt frameworks and plugins
- Python runtime
- Code signing
- Hardened Runtime
- Apple notarization
- Stapling
- `.dmg` creation
- GitHub Actions macOS runners

### Automation

Another major objective is to understand how mature projects automate releases with **GitHub Actions**, ideally reaching a workflow conceptually similar to:

```text
                         Git tag
                            |
                +-----------+-----------+
                |           |           |
             Windows      Linux       macOS
                |           |           |
             Build       AppImage      Build
                |           |           |
             Sign          DEB          Sign
                |                       |
            Installer                 Notarize
                |                       |
                +-----------+-----------+
                            |
                     GitHub Release
```

## Projects under study

The following upstream projects are included as Git submodules:

| Submodule | Purpose in this research |
| --- | --- |
| `dikte` | Study a relatively small PyQt6 application with multiplatform distribution. |
| `CustomKnight-Creator` | Study a smaller project and its executable/packaging approach. |
| `pyzo` | Study packaging practices from a mature Python/Qt desktop application. |
| `CARA` | Study another real-world PyQt6 desktop application and its multiplatform builds. |
| `napari` | Study a large, mature scientific Python/Qt application and its release architecture. |
| `napari-packaging` | Study napari's dedicated packaging and installer infrastructure. |
| `PyQt6-Apps/TBO` | Own PyQt6 application. Not a case study: it is the *validation ground* for this repository, and the only source of real, working `.deb` and AppImage evidence. **Not a submodule** — an independent clone that this repository ignores. |

The six studied projects remain independent upstream repositories, recorded here through Git submodules. `PyQt6-Apps/TBO` is treated differently: it is the owner's own application, kept as an ordinary clone so it can be edited and pushed to its own remote without this repository pinning a commit.

## Repository structure

```text
pyqt6-packaging-research/
├── 01-GENESIS/                     # origin of the research, Debian/Termux notes
├── 02-Promt-MAESTRO/               # the master prompt used for second-level analysis
├── 03-Promt-MAESTRO-resultado/     # consolidated, cross-project results
│   ├── MASTER_PYQT6_PACKAGING_GUIDE.md
│   ├── PYQT6_MASTER_PACKAGING_TUTORIAL.md
│   ├── PACKAGING_EVIDENCE_MATRIX.md
│   ├── PROMPT-01-FIX-TBO-PACKAGING.md      # prompt to repair TBO's build jobs
│   ├── PROMPT-02-NUEVO-PROYECTO-PYQT6.md   # prompt to start a new project correctly
│   ├── PROMPTS-README.md                   # how to use the two prompts
│   ├── TOP-FINDINGS-DIGEST.md              # one-page digest of the headline findings
│   └── TBO-SOLUCIONES/             # validated fixes found while packaging TBO
├── PyQt6-Apps/
│   ├── TBO/                        # independent clone, NOT a submodule (git-ignored)
│   └── TBO-GitHub-Actions-Executables/   # build outputs (git-ignored)
├── CARA/                           # submodule
├── CustomKnight-Creator/           # submodule
├── dikte/                          # submodule
├── napari/                         # submodule
├── napari-packaging/               # submodule
├── pyzo/                           # submodule
├── CARA-resultados/                # per-project outputs (one per case study)
│   ├── PACKAGING_STUDY.md
│   ├── PYQT6_PACKAGING_TUTORIAL.md
│   ├── 01_<agent>_report.md        # how the study was produced
│   └── _evidence/                  # real packaging files, pinned to a commit
├── CustomKnight-Creator-resultados/
├── dikte-resultados/
├── napari-packaging-resultados/
├── napari-resultados/
├── pyzo-resultados/
├── tools/
│   └── extract_evidence.py         # regenerates every _evidence/ pack
├── experiments/
│   └── pyinstaller-vs-nuitka/      # controlled build-tool experiment (kit + CI workflow)
├── .dsh/skills/                    # agent Skills built from the verified findings
├── EVIDENCE_INDEX.md               # index of every evidence pack
├── SKILLS.md                       # what the Skills cover and what they refuse to
├── AGENTS.md                       # hard rules for AI agents: submodules are not libraries
├── .gitmodules
└── README.md
```

### Case-study outputs

Every case study produces two documents in its `*-resultados/` directory:

- `PACKAGING_STUDY.md` — what the upstream project actually does, with evidence.
- `PYQT6_PACKAGING_TUTORIAL.md` — the reusable lessons derived from that case.

### Evidence packs

The studies cite real files by path and line number (for example
`packaging/build-appimage.sh` lines 41-49). Those files live inside submodules
pinned to a commit, so the citation would break the moment a submodule is
updated. Each `*-resultados/_evidence/` directory therefore contains a copy of
the packaging, build, installer and release-CI files that a study relies on,
**mirroring their original repository layout** so that a citation resolves
immediately.

Each pack records its own provenance:

```text
_evidence/
├── PROVENANCE.md   upstream URL, exact commit, licence, and why each file is here
├── SHA256SUMS      integrity check for every extracted file
└── <original/relative/paths...>
```

`EVIDENCE_INDEX.md` lists every pack, its pinned commit and its licence.

Regenerate all packs with:

```bash
python3 tools/extract_evidence.py          # write
python3 tools/extract_evidence.py --dry-run  # preview
```

The extracted files are **evidence, not templates**, and they are not
relicensed. Licences differ sharply across the set — CARA, CustomKnight-Creator,
dikte and TBO are GPL, napari and pyzo are BSD, and `napari/packaging` ships no
licence file at all. Studying and quoting is one thing; copying GPL packaging
code into your own application is another.

### Second-level analysis

`03-Promt-MAESTRO-resultado/` consolidates the six case studies:

| Document | Role |
| --- | --- |
| `MASTER_PYQT6_PACKAGING_GUIDE.md` | Cross-project conclusions, contradictions, decision tree, release checklist. |
| `PYQT6_MASTER_PACKAGING_TUTORIAL.md` | End-to-end tutorial assembled from all case studies. |
| `PACKAGING_EVIDENCE_MATRIX.md` | Compact evidence table with a HIGH / MEDIUM / LOW / NOT VERIFIED confidence label per claim, plus an explicit list of what could **not** be verified. |
| `TBO-SOLUCIONES/` | Fixes validated on a real application, with `_evidence/` for its packaging files. |

### Controlled experiment

Reading repositories cannot answer the antivirus question, because no project in
the case set publishes any detection data. `experiments/pyinstaller-vs-nuitka/`
is a runnable controlled experiment that can:

```text
arm A  PyInstaller  onedir      arm C  Nuitka  standalone
arm B  PyInstaller  onefile     arm D  Nuitka  onefile
```

It holds the application, PyQt6 pin, PE identity metadata, OS image and C
toolchain constant, disables UPX in every arm, and produces per-arm artifacts,
SHA-256 hashes, sizes, start-up timings and build logs, plus an opt-in
VirusTotal submission step.

The PyInstaller arms of the kit have been built and launched; the Nuitka arms and
the CI workflow are written but **not yet executed**. See that directory's
`README.md` for the exact validation status before trusting any of it.

### Agent Skills

`.dsh/skills/` contains six Skills that turn the verified findings into
procedure: packaging decisions, DEB, AppImage, macOS signing/notarization,
Windows installer/signing, and release integrity.

There is deliberately **no antivirus Skill**: there is no verified evidence to
put in one, and a Skill that guesses is worse than no Skill, because an agent
follows it confidently. `SKILLS.md` explains the rule and how to install the
Skills in another project.

## Why Git submodules?

Git submodules make it possible to:

- preserve the original upstream repositories;
- keep their Git history separate;
- record the exact upstream commit used during an investigation;
- update individual projects independently;
- avoid copying third-party source code directly into this repository;
- compare packaging implementations from several projects in one workspace.

## Clone this repository

Because the projects are submodules, the recommended way to clone this repository is:

```bash
git clone --recurse-submodules https://github.com/wachin/pyqt6-packaging-research.git
cd pyqt6-packaging-research
```

If the repository was cloned without its submodules:

```bash
git submodule update --init --recursive
```

Check their current state with:

```bash
git submodule status
```

When you clone with submodules you will get six complete third-party source
trees on disk. **They are not libraries and they are not dependencies of this
repository.** They are exhibits, cloned to be read:

- do not import them, and do not add them to any dependency manifest;
- do not modify them, and do not run their build or release workflows;
- do not treat their age or state as a defect in this repository.

`PyQt6-Apps/TBO` is not among them: it is not a submodule, so a fork does not
fetch it. It is a separate clone of the owner's own application, ignored by this
repository through `.gitignore`.

If you use an AI agent here, `AGENTS.md` states this as a hard rule. To inspect
what a studied project actually did, read its evidence pack under
`<project>-resultados/_evidence/` rather than the submodule tree — the pack is
pinned to the exact commit the studies describe.

## Update the submodules

To fetch newer upstream commits:

```bash
git submodule update --remote
```

Then inspect the changes:

```bash
git status
git diff --submodule
```

If the updates are intentional, record the new submodule commits in this repository:

```bash
git add .
git commit -m "Update research submodules"
git push
```

Updating a submodule can change the code being studied, so research results should ideally record the exact commit or version analyzed.

> **Warning.** Studies cite files by path and line number at a pinned commit. After
> `git submodule update --remote`, those citations point at different code until the
> affected evidence packs are regenerated:
>
> ```bash
> python3 tools/extract_evidence.py
> ```
>
> Regenerate the packs in the same change as the submodule bump, and review the
> diff. Never update a submodule without regenerating its evidence.

## Research methodology

Each project should be analyzed independently using the same investigation criteria.

The analysis should inspect, when available:

```text
README.md
CONTRIBUTING.md
pyproject.toml
setup.py
setup.cfg
requirements*.txt

.github/workflows/

*.spec

scripts/
build/
packaging/
installer/

Debian packaging files
AppImage configuration
Windows installer configuration
macOS packaging scripts
```

Important technologies and terms to search for include:

```text
PyQt6
PySide6
QtPy

PyInstaller
Nuitka
cx_Freeze
py2app

AppImage
AppDir
appimagetool
linuxdeploy

dpkg
debhelper

Inno Setup
NSIS
WiX
MSI
MSIX

codesign
signtool
Authenticode
notarytool
notarization

GitHub Actions
GitHub Releases
```

The investigation should trace the complete path from source code to the final downloadable artifact rather than merely identifying which packaging tool is installed.

## Research documents

Each case study has produced both documents:

```text
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md
```

### `PACKAGING_STUDY.md`

Describes what the specific upstream project actually does.

It distinguishes between:

- verified implementation;
- project-specific techniques;
- legacy infrastructure;
- reusable ideas;
- assumptions;
- things that could not be verified.

Important conclusions should reference the actual source files, build scripts, configuration, and GitHub Actions workflows that support them.

### `PYQT6_PACKAGING_TUTORIAL.md`

This document should transform useful findings from the project into practical lessons for packaging other PyQt6 applications.

It should cover, where evidence is available:

```text
Windows
├── PyInstaller
├── Nuitka
├── portable builds
├── installers
├── code signing
└── antivirus / VirusTotal considerations

Linux
├── AppImage
└── DEB

macOS
├── .app
├── signing
├── notarization
└── DMG

Automation
└── GitHub Actions
```

## Final objective

The case studies have been compared to produce the consolidated guide:

```text
03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md
03-Promt-MAESTRO-resultado/PYQT6_MASTER_PACKAGING_TUTORIAL.md
```

The guide does not simply copy one project's build system.

Instead, it compares multiple real-world implementations and identifies practices that are:

- highly recommended;
- useful;
- project-specific;
- legacy;
- not recommended;
- or in need of further research.

The desired end result is a reusable packaging strategy for open-source PyQt6 desktop applications:

```text
                         PyQt6 project
                               |
             +-----------------+-----------------+
             |                 |                 |
          Windows            Linux             macOS
             |                 |                 |
     PyInstaller/Nuitka   standalone build  PyInstaller/Nuitka
             |                 |                 |
        executable       +-----+-----+          .app
             |           |           |            |
          signing     AppImage      DEB        signing
             |                                  |
         installer                            notarization
             |                                  |
     installer signing                          DMG
             |                 |                 |
             +-----------------+-----------------+
                               |
                         GitHub Actions
                               |
                         GitHub Release
```

## Research principles

This repository is intended for legitimate open-source software packaging research.

The investigation should:

- prefer primary sources and actual repository evidence;
- distinguish verified facts from assumptions;
- avoid blindly copying project-specific build systems;
- compare PyInstaller and Nuitka objectively;
- treat antivirus false positives as a software distribution and reputation problem, not as something to bypass through evasion;
- never expose credentials, signing certificates, private keys, or CI secrets;
- document secret variable names only when necessary to understand a workflow;
- prefer reproducible and transparent release processes;
- consider code signing, checksums, provenance, and public source code as part of professional software distribution.

## License and third-party projects

The source code contained in each submodule belongs to its respective upstream project and remains subject to that project's own license.

This repository does not relicense the submodules.

Before reusing code, scripts, configuration, icons, or other assets from an upstream project, check its license and attribution requirements.

## Status

The **descriptive phase is complete**: six case studies, six tutorials, a
confidence-labelled evidence matrix, and a consolidated master guide plus master
tutorial. Each case study is backed by an `_evidence/` pack pinned to an exact
commit.

The **validation phase is no longer empty**, and the first real measurement has
changed one of the headline conclusions.

**Measured in 2026-10 (TBO):** the same application, version and PE metadata,
unsigned, UPX disabled, built three ways. **Nuitka 0/71. PyInstaller 3/73 in
*both* layouts** — flagged by a handful of engines whose detections are generic or
behavioural, while every major engine reports clean. That confirms the direction
of the long-standing claim and refutes the assumption that `onedir` avoids
detection. It is **n = 1**, so it is a lead and not a rule. Full record:
`PACKAGING_EVIDENCE_MATRIX.md` §B.1,
`03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md` §11, and the
screenshots in `experiments/pyinstaller-vs-nuitka/evidence/`.

Still unverified:

- **Antivirus behaviour beyond one application, and any trend over time.** The
  counts are known for one release; no case-study project publishes detection data
  at all, and the result must be reproduced before it is generalised.
- **Nuitka at scale.** None of the five case studies uses it. There is now one
  measurement on TBO, and nothing more.
- **`.deb` in upstream projects.** None of the five ships one, and no project
  even has a `debian/` directory. The only working `.deb` evidence is TBO's.
- **Exact Qt plugin and translation inventories** inside any frozen artifact.
- **A notarized, stapled `.dmg`** — no case study demonstrates the flow.
- **Reproducible builds** — no project claims them, and none was achieved here.

Next steps, in order:

1. **Capture the detection detail and repeat.** Record the detection count, the
   engine names and the categories for each artifact, and repeat across several
   releases — one build pair does not separate a property of the tool from a
   coincidence of that build. The generic kit for this is
   `experiments/pyinstaller-vs-nuitka/`.
2. Finish the TBO `.deb` and AppImage cycle end to end.
3. Replace the `[TEMPLATE — MUST BE TESTED]` blocks in the tutorials with
   instructions that have actually been executed.
4. Extend the Skills in `.dsh/skills/` once (1) and (3) produce verified
   material. In particular, an antivirus Skill should only exist after real
   measurements exist.
