---
name: pyqt6-packaging-decisions
description: Decide how to package a PyQt6/PySide6 desktop app - bundle layout, PyInstaller vs Nuitka, and the Linux package model - from evidence gathered across six real projects. Use before writing any build script.
whenToUse: Use when starting to package a PyQt6 desktop application, or when asked whether to use PyInstaller or Nuitka, onedir or onefile, or a native vs bundled .deb.
---

# Packaging decisions for a PyQt6 application

Settle these four questions before writing a build script. Changing them later
invalidates the work that depends on them.

## 0. The rule that overrides everything

**Let product requirements choose the mechanism, not preference.** The clearest
example in the evidence: napari rejected frozen executables entirely, because a
frozen bundle is immutable and napari's value is a large third-party plugin
ecosystem. It ships conda-based installers instead. That is not a better or
worse choice than PyInstaller — it is the only choice that fits the product.

Ask first: does anything need to be installed, imported or updated *after*
packaging? If yes, a frozen bundle is probably the wrong container.

## 1. Bundle layout: onedir or onefile?

**Default to `onedir`.**

Observed: CARA, dikte and pyzo all use onedir, each for its own operational
reasons, and dikte wraps the onedir payload inside Inno/DMG/AppImage rather than
shipping a naked executable. CustomKnight-Creator uses onefile on every platform
and is the documented negative example: unsigned, no checksums, no release
automation, an artifact matching the classic false-positive profile.

Choose `onefile` only when "a single file the user can double-click" is an
actual requirement. Then accept the trade:

- onefile **extracts to a temporary directory on every launch**. On Linux that
  was measurable: same application, onefile 79 MB, onedir 207 MB on disk, yet
  onefile has to unpack before the window can appear.
- onefile hides the bundle from the user, which also hides missing-plugin and
  missing-data failures until runtime.

Do not choose onefile because it sounds tidier. And do not believe either layout
is an antivirus cure — see §4.

## 2. Build tool: PyInstaller or Nuitka?

**The honest position: this repository has no evidence that Nuitka is better,
and none that it is worse.**

- All four frozen projects use **PyInstaller**.
- **No case study uses Nuitka at all.**
- The often-repeated claim that Nuitka avoids antivirus false positives is, in
  the evidence matrix, `NOT VERIFIED` — "no project uses Nuitka, anecdote only".

So: PyInstaller is the choice with observed, working precedent across four
projects and three platforms. Nuitka is a legitimate alternative with a real
advantage (compiled output, no self-extracting bootloader) and a real cost
(longer builds, a C toolchain dependency, per-module compilation quirks).

If the choice matters for your project, **measure it** rather than decide by
reputation. A ready-to-run controlled experiment exists in this repository:
`experiments/pyinstaller-vs-nuitka/`.

Practical Nuitka note learned the hard way: `--file-version` and
`--product-version` must be plain four-part numeric values. A value like
`2.0.0.dev0` aborts the build with `FATAL: Invalid version number`. Sanitize to
`2.0.0.0`.

## 3. Linux package model

Two incompatible models, both recommended by different tutorials in this
research. Pick one deliberately and disclose it.

**Model A — native distro dependencies.** The `.deb` declares
`Depends: python3, python3-pyqt6` and ships only your application code. Smaller,
integrates with distro security updates, and is what the CARA/pyzo/dikte
tutorials recommend. Requires a `python3-pyqt6` compatible with your code on
every target release.

**Model B — bundled runtime.** A PyInstaller/Nuitka standalone payload inside
the `.deb`. Works identically everywhere, no distro Qt dependency, but
duplicates the interpreter and Qt, and needs disclosure. Recommended by the
CustomKnight/napari tutorials.

Decide by asking: do you control the target distros? If yes, Model A. If your
users are "anyone on any Debian derivative", Model B fails less often.

Note the evidence gap: **none of the five upstream case studies ships a `.deb`
at all.** The validated `.deb` experience here comes from TBO — see the
`pyqt6-deb-packaging` skill.

## 4. What is NOT established (do not repeat these as fact)

- That PyInstaller causes antivirus detections. No project measured it.
- That Nuitka avoids them. No project uses Nuitka.
- That onedir eliminates false positives. Plausible, unmeasured.
- That UPX increases detections. Correlational only — but disabling UPX is free,
  so disable it.
- That code signing guarantees a clean VirusTotal result. It does not; it is a
  reputation anchor, and an untrusted certificate does not even remove
  SmartScreen warnings (napari documented this about its own stopgap).

Treat a VirusTotal count as a point-in-time, engine-specific signal to
investigate — never as a verdict or a score to optimise. This is distribution
and reputation work, not evasion.

## 5. Before you build

- Pin your dependencies. No case study except napari has real lock discipline,
  and that is the single biggest obstacle to comparing two builds.
- Write down the exact commit, Python version, PyQt6 version and tool versions
  for every artifact you compare.
- Skip UPX everywhere, consistently.
- Set application identity metadata (name, version, publisher, description) from
  the start; part of reputation is being a consistent, identifiable thing.

## Where to go next

| Question | Skill |
|---|---|
| Build the `.deb` | `pyqt6-deb-packaging` |
| Build the AppImage | `pyqt6-appimage-packaging` |
| macOS `.app`, signing, notarization | `pyqt6-macos-signing-notarization` |
| Windows installer and signing | `pyqt6-windows-installer-signing` |
| Checksums, pinning, provenance | `pyqt6-release-integrity` |

Full reasoning and confidence labels:
`03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md` and
`03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md`.
Real packaging files, pinned to a commit: `*-resultados/_evidence/`.
