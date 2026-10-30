---
name: pyqt6-packaging-decisions
description: Decide how to package a PyQt6/PySide6 desktop app - bundle layout, PyInstaller vs Nuitka, and the Linux package model - from evidence gathered across eight real projects. Use before writing any build script.
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

**What the evidence supports: on Windows, Nuitka is the safer default for an
unsigned application, and it is still not a guarantee.**

- The four third-party frozen projects (dikte, CustomKnight-Creator, pyzo, CARA)
  all use **PyInstaller**.
- Both of the owner's own applications use **Nuitka on Windows** and PyInstaller
  on Linux and macOS. Lucio IVA Calculator moved its Windows build to Nuitka
  *because* of antivirus results; TBO then measured the difference properly.
- The measurements are in section 4. They are two applications, Windows only,
  one of them self-reported. That is a lead with a consistent direction, not a
  law of nature.

So the defensible position, and the one to act on:

- **Windows: build with Nuitka** (`--standalone`, never `--onefile`), because the
  only measurements that exist point that way and it costs nothing extra if you
  were going to ship a directory anyway.
- **Linux and macOS: PyInstaller is fine.** Both owner applications keep it there,
  and TBO's AppImage, `.deb` and macOS artifacts each scanned 0 detections. Lucio's
  Linux and macOS artifacts were never scanned, so that half is precedent rather
  than measurement. The Linux glibc and macOS `.app` paths are also the
  better-documented ones in this repository.
- Still **measure your own build** rather than trusting the direction: a
  different application, dependencies or bundle contents can behave differently.
  The kit is `experiments/pyinstaller-vs-nuitka/`.

Costs of Nuitka, stated honestly: longer builds, a C toolchain dependency, and
per-module compilation quirks. Its practical traps are `--file-version` /
`--product-version` needing plain four-part numeric values (a `2.0.0.dev0`
aborts with `FATAL: Invalid version number`; sanitize to `2.0.0.0`) and
`--include-data-dir=SOURCE=DEST`, where `DEST` must match what the code resolves
at runtime. The full recipe is in `pyqt6-windows-installer-signing` section 1.

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

Note the evidence gap: **none of the six upstream case studies ships a `.deb`
at all**, and none even has a `debian/` directory. The validated `.deb`
experience here comes from TBO — see the `pyqt6-deb-packaging` skill.

## 4. What the evidence does and does not say about antivirus

This is the area where the honest answer changed in 2026-10, so state it
precisely instead of repeating the folklore in either direction.

**One controlled measurement exists, plus one reported pair.** The controlled one
is TBO: the same application, version and PE metadata, unsigned and with UPX
disabled in every arm, built four ways.

| Arm | VirusTotal |
|---|---|
| Nuitka standalone | **0 / 71** |
| PyInstaller onedir | **3 / 73** |
| PyInstaller onefile | **3 / 73** |
| PyInstaller onefile, bootloader compiled from source | **2 / 70** |

Read the detections, not just the count. They were `SecureAge → Malicious` (no
family named), `Skyhigh (SWG) → BehavesLike.…` (a behavioural rule),
`Zillya → Trojan.Script.2226` (no known family) and `Bkav Pro → W32.Malware…`
(generic). Two engines flagged both PyInstaller arms while the third differed
between them, and **every major engine reported clean** — Microsoft, Kaspersky,
BitDefender, ESET, Sophos, Avast, Google, Fortinet, CrowdStrike, Palo Alto,
Symantec, Trend Micro, SentinelOne. That shape is generic heuristic false
positives, not a signature match.

What the four arms establish, which is more than the headline:

- **`onedir` is not a remedy.** Both PyInstaller layouts scored 3/73 with the
  same engines, so the bundle layout is not what is being detected.
- **The bootloader is not the cause either.** The fourth arm rebuilt it from
  source — the remedy PyInstaller's own documentation suggests — and 3/73 became
  2/70: Zillya cleared, Bkav Pro and SecureAge flagged it anyway. Do not send
  anyone down that path expecting a fix.
- What every PyInstaller build shares and the developer does not control is the
  **embedded CPython runtime and PyInstaller's archive format**. That is where
  the remaining difference plausibly lives, and it is also why "switch freezer"
  is the only lever available.
- **The second data point.** Lucio IVA Calculator, 2026-06, recorded `0/68` for
  its NSIS installer and `0/65` for its portable ZIP after moving from
  PyInstaller to Nuitka for the same reason. Self-reported, no scan artifact
  preserved; the hashes are recoverable from its release and are recorded in
  `my-PyQt6-Apps/lucio-iva-calculator-resultados/PACKAGING_STUDY.md` §6.

What it does **not** support, and what you must not tell a user:

- that "PyInstaller causes detections" or "Nuitka avoids them" as general rules.
  It is **n = 2 applications**, one of them self-reported, and Windows only. Both
  are GPL applications with no download history;
- that UPX increases detections — correlational only, though disabling it is
  free, so disable it;
- that code signing guarantees a clean VirusTotal result. It does not; it is a
  reputation anchor, and an untrusted certificate does not even remove
  SmartScreen warnings (napari documented this about its own stopgap);
- that a 3/73 result warrants abandoning PyInstaller. With every major engine
  clean, the research-backed lever is **signing**, plus a vendor false-positive
  report. Switching freezer is defensible when you cannot sign and the artifact
  is Windows-only, which is exactly the position both of these applications were
  in — not a general rule.

If antivirus behaviour matters for the project in front of you, measure it rather
than argue it: `experiments/pyinstaller-vs-nuitka/` is the repeatable kit. Treat a
VirusTotal score as a point-in-time, engine-specific signal to investigate — never
as a verdict to optimise against, and never as a reason to obfuscate, pack or
mutate a binary.

## 5. Before you build

- Pin your dependencies. No case study except napari has real lock discipline,
  and that is the single biggest obstacle to comparing two builds.
- Write down the exact commit, Python version, PyQt6 version and tool versions
  for every artifact you compare.
- Skip UPX everywhere, consistently.
- Set application identity metadata (name, version, publisher, description) from
  the start; part of reputation is being a consistent, identifiable thing.

## Where to go next

For the common five-artifact release, this is the route:

| Artifact | Freezer / tool | Skill and section |
|---|---|---|
| AppImage (Ubuntu, Debian, any glibc ≥ your floor) | PyInstaller onedir + hand-built AppDir + pinned appimagetool | `pyqt6-appimage-packaging` |
| `.deb` (Ubuntu, Debian) | debhelper + pybuild, native `python3-pyqt6` | `pyqt6-deb-packaging` |
| macOS portable `.zip` containing the `.app` | PyInstaller `-D` + `ditto -c -k --sequesterRsrc` | `pyqt6-macos-signing-notarization` §1 and §8 |
| Windows portable `.zip`, unsigned | **Nuitka `--standalone`** + `make_portable_zip.py`-style archive | `pyqt6-windows-installer-signing` §1 and §4 |
| Windows `setup.exe` (NSIS or Inno) | same Nuitka payload + `makensis` / `iscc` | `pyqt6-windows-installer-signing` §3 and §4 |
| Checksums, pinning, provenance, artifact tests | — | `pyqt6-release-integrity` |

Two notes that apply to all five:

- **Windows uses Nuitka in this route; Linux and macOS use PyInstaller.** That
  split is what both owner applications do, and section 2 explains why it is
  defensible rather than dogmatic.
- Every one of those artifacts should be an **onedir/standalone payload**, never
  a `onefile`/self-extracting executable. Section 1 gives the reason.

Full reasoning and confidence labels:
`03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md` and
`03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md`.
Real packaging files, pinned to a commit: `<project>-resultados/_evidence/` and
`my-PyQt6-Apps/<app>-resultados/_evidence/`. What each Skill does and does not
cover is audited in `SKILLS-VERIFICATION.md`.
