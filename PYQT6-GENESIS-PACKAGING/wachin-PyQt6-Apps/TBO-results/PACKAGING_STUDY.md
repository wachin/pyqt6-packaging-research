# Packaging Study: TBO

## 1. Executive Summary

This report studies repository revision `797011a` (`v2.0.0-11-g797011a`) as
inspected on 2026-10-30. TBO is a GPL-3.0 comic editor written in Python and
PyQt6, and it is the repository owner's own application. It is not a third-party
case study: it is here because it is the only project in this research that has
been **measured** rather than described.

Its release architecture is the widest in the set. Four platforms, three
different packaging technologies, five CI jobs:

```text
Python + PyQt6 source
        |
        +-- Windows (Nuitka --standalone)
        |     payload -> build/output/TBO-<ver>-Windows-x64-portable/
        |     -> make_portable_zip.py -> portable ZIP   (no installer)
        |
        +-- Linux AppImage (ubuntu-22.04, GLIBC 2.35 baseline)
        |     PyInstaller onedir -> hand-built AppDir -> pinned appimagetool 1.9.1
        |
        +-- Linux .deb (debhelper + pybuild)
        |     native dependency model: python3-pyqt6 from the distribution
        |
        +-- macOS (PyInstaller .app)
              .app -> zip   (unsigned, unnotarized)
```

What makes this project worth studying is not that it is exemplary. It is that
every claim in it can be checked twice over: the build scripts are pinned in the
evidence pack next to this report, and the released artifacts were scanned and
their hashes published. Two things follow that no other project in this set can
support:

- **A controlled freezer comparison exists.** The same application, same version,
  same PE metadata, all unsigned, UPX disabled: Nuitka scored **0/71** and both
  PyInstaller layouts scored **3/73**. A fourth arm with a bootloader compiled
  from source scored **2/70**, which refuted the bootloader hypothesis. This is
  recorded in `03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` §B.1 with
  the hashes and the screenshots.
- **A real Debian package exists.** It is built in CI, it installs, and it is
  audited in `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/DEBIAN-PACKAGE-AUDIT.md`.
  No upstream case study in this research ships a `.deb` at all.

The project does **not** use code signing, Authenticode, an Apple Developer ID,
hardened runtime, entitlements, notarization, a Windows installer (NSIS or Inno
Setup), an SBOM, or a Flatpak that still builds. The Flatpak manifest is present
but its CI job is commented out with a stated reason
(`.github/workflows/build.yml:53-55`).

The strongest reusable ideas are:

1. **Measure instead of assuming, and publish the hashes with the scores.**
   `docs/virustotal/` holds the four report links, the four SHA-256 values and the
   screenshots, so the claim can be audited months later.
2. **Build the portable ZIP from Python, not PowerShell.** `Compress-Archive`
   and `ZipFile::CreateFromDirectory` both write backslash separators from
   Windows PowerShell 5.1, which the ZIP specification forbids and which collapses
   the tree on Linux and macOS. `packaging/make_portable_zip.py` writes the
   entries itself and re-reads the archive as a post-condition.
3. **Verify the shape of the archive, not just that it was created.** The same
   helper now takes `--prefix` and `--require`, so a nested or misnamed tree
   aborts the build instead of shipping.
4. **Pin the AppImage tool by version and SHA-256.** The `continuous` tag is
   mutable and its checksum changed under this project once already; 1.9.1 is
   pinned instead (`packaging/build_appimage.sh:28-36`).
5. **Choose the native-dependency model for the `.deb`.** `python3-pyqt6` comes
   from the distribution, so the package is 366 KB instead of 70 MB.
6. **Leave tombstones.** Disabled jobs and removed arms are commented out with
   the reason and the date, not deleted silently.

The largest weaknesses are that nothing is signed on any platform; that the
published release assets were assembled by hand and therefore do not match what
CI produces; that no Windows installer exists, so the portable ZIP is the only
Windows artifact; that the Flatpak story is dead; and that a commit in this
project's history truncated thirteen binary files to zero bytes, which broke the
Windows build without any signal from Git.

Evidence terminology in this report:

- **Implemented** means a current script or workflow performs it.
- **Measured** means an artifact was scanned and the result recorded with its
  hash.
- **Not verified** means the available evidence does not establish it.

## 2. Project Architecture

### Identity and purpose

A comic and cartoon editor compatible with the legacy `.tbo` document format of
a 2013 C/GTK application, reimplemented in Python and PyQt6. The legacy code is
kept under `legacy/` as a behavioural reference, not migrated.

### Languages and frameworks

Python 3.11–3.12, PyQt6 6.6+, Nuitka (Windows), PyInstaller (Linux AppImage and
macOS), debhelper/pybuild (Debian), appimagetool (AppImage), Flatpak manifest
(unbuilt).

### Supported systems

| Platform | Runner | Artifact | Technology |
|---|---|---|---|
| Windows 10/11 x64 | `windows-latest` | portable ZIP | Nuitka standalone |
| Linux (any) | `ubuntu-22.04` | AppImage | PyInstaller onedir + appimagetool |
| Debian/Ubuntu | `ubuntu-latest` | `.deb` | debhelper, pybuild |
| macOS Intel | `macos-latest` | zip of `.app` | PyInstaller |

The AppImage is deliberately built on `ubuntu-22.04` so the binary's glibc floor
is 2.35 rather than the runner's default. That is the single most important
cross-distribution decision in the project, and it is documented in the script's
own header (`packaging/build_appimage.sh:12-17`).

### Entry points

`src/tbo/__main__.py` is the freeze entry point; the Debian package installs a
console script and a `.desktop` entry instead of freezing. The frozen builds and
the Debian package therefore exercise two different launch paths, which is why
the AppImage and the `.deb` can fail independently.

### Dependency and build metadata

| File | Purpose | Pinned? |
|---|---|---|
| `packaging/requirements-windows.txt` | Nuitka toolchain | yes (`==`) |
| `packaging/requirements-linux.txt` | PyInstaller toolchain | yes |
| `packaging/requirements-macos.txt` | PyInstaller toolchain | yes |
| `packaging/requirements-windows-pyinstaller.txt` | PyInstaller comparison arm | yes |
| `pyproject.toml` | Version source for the `.deb` and for `--file-version` | n/a |

Unlike most projects in this set, the build dependencies are pinned with `==`.
The runtime dependencies are the distribution's own Qt when installed as a
`.deb`, and the frozen tree when installed from a ZIP.

## 3. Packaging Overview

| Concern | File | Notes |
|---|---|---|
| Windows | `packaging/build_windows_nuitka.ps1` | Nuitka + `make_portable_zip.py` |
| Windows comparison arm | `packaging/build_windows_pyinstaller.ps1` | local-only, not in CI |
| AppImage | `packaging/build_appimage.sh` | AppDir, AppRun, pinned appimagetool |
| Debian | `debian/` (5 files) | native dependency model |
| macOS | `packaging/build_macos.sh` | PyInstaller `.app` |
| Flatpak | `packaging/org.tbo.TBO.json` | manifest only; job disabled |
| Portable ZIP | `packaging/make_portable_zip.py` | conformant separators + shape checks |
| Icons | `packaging/generate_icon.py` | `.ico`, `.iconset`, 256 px PNG |
| Orchestration | `.github/workflows/build.yml` | 5 active jobs, manual dispatch |
| Measurement record | `docs/virustotal/` | 4 report links, 4 hashes, 4 screenshots |
| Fix log | `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md` | 12 numbered sections |

## 4. Windows

No installer. The Windows artifact is a portable ZIP, and the reason is worth
stating because it is a real trade: an installer would give a Start Menu entry, a
per-user install path and an uninstaller, and this project has none of those on
Windows. The cost is invisible to the developer and visible to the user, who has
to choose a directory and keep it.

`packaging/build_windows_nuitka.ps1` stages the payload and hands the packaging
to Python (lines 97-122):

```powershell
$stagingDir = Join-Path $outputDir "TBO-$version-Windows-x64-portable"
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

Copy-Item "$appDistDir\*" $stagingDir -Recurse -Force
Copy-Item "$workspaceRoot\COPYING" $stagingDir -Force

python "...\make_portable_zip.py" $stagingRoot $portableZipPath `
    --prefix "TBO-$version-Windows-x64-portable" --require TBO.exe --require COPYING
```

Two lines there are the residue of two separate bugs, both documented in
`SOLUCIONES-TBO.md`:

- **`"$appDistDir\*"`, not `$appDistDir`.** `Copy-Item <dir> <existing-dir>
  -Recurse` copies the *folder* into the destination, producing
  `staging\TBO\<files>`. The wildcard form copies the *contents*. The original
  version of this script shipped a nested `TBO/` inside the archive because of
  that, and nobody noticed until a user extracted it.
- **`COPYING` goes into `$stagingDir`, not beside it.** The first version put the
  licence at the archive root, so extracting gave the user a folder *and* a loose
  file. Section 8 covers the whole ZIP story.

The `--require` flags are the guard against both regressions: if the staging step
ever nests the tree again, `TBO-<ver>-Windows-x64-portable/TBO.exe` does not
exist, and the helper refuses to ship and deletes the archive.

### PE metadata

The Nuitka invocation carries the full set (`build_windows_nuitka.ps1:44-49`):
company, product, description, four-part file and product versions, copyright,
icon. The version is derived from `src/tbo/__init__.py`'s `__version__` and
stripped to four numeric parts, because a string like `2.0.0.dev0` makes the
resource invalid. That failure is recorded in `SOLUCIONES-TBO.md` §4.

## 5. The PyInstaller Arms (Added, Measured, Removed)

This is the most methodologically interesting thing in the project.

`packaging/build_windows_pyinstaller.ps1` is a full PyInstaller build driver,
deliberately holding everything constant against the Nuitka build except the
freezer: same source, same `__version__`, same PE identity metadata, same bundled
data, UPX disabled in both. It builds two layouts, `onedir` and `onefile`, and
each arm was scanned.

The arms were then **removed from CI**, and the workflow keeps a tombstone
explaining why. That is the correct outcome when a hypothesis is refuted: the
comparison stays reproducible locally, and the pipeline stops paying for it.

## 6. Antivirus: The Measurement

This is the centre of the whole research, so the numbers are given in full and
the limits are stated as carefully as the results.

### The controlled comparison

Same commit, same version, same PE metadata, all unsigned, UPX disabled. Only the
freezer and the bundle layout differ. Recorded in
`03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` §B.1.

| Artifact | Freezer | Layout | Size | VirusTotal |
|---|---|---|---|---|
| `TBO.exe` | Nuitka | standalone | 7,117,824 B | **0 / 71** |
| `tbo-pyinstaller-onedir.exe` | PyInstaller | onedir | 2,019,109 B | **3 / 73** |
| `tbo-pyinstaller-onefile.exe` | PyInstaller | onefile | 38,802,576 B | **3 / 73** |
| `tbo-pyinstaller-rebuilt-onefile.exe` | PyInstaller, bootloader from source | onefile | 38,803,385 B | **2 / 70** |

The engines that flagged, and with what:

| Arm | Engine | Detection |
|---|---|---|
| onedir | SecureAge | `Malicious` |
| onedir | Zillya | `Trojan.Script.2226` |
| onedir | Skyhigh | `BehavesLike.Win32.Backdoor.rc` |
| onefile | Bkav Pro | `W32.Malware.7730AFD` |
| onefile | Zillya | `Trojan.Script.2226` |
| onefile | SecureAge | `Malicious` |
| rebuilt bootloader | Bkav Pro | `W32.Malware.7730AFD` |
| rebuilt bootloader | SecureAge | `Malicious` |

### What the shape means

- **Every major engine reports clean.** Microsoft, Kaspersky, BitDefender, ESET,
  Sophos, Avast, AVG, Google, Fortinet, CrowdStrike, Palo Alto, Symantec, Trend
  Micro, McAfee, SentinelOne and the rest.
- **The detections are generic or behavioural.** `SecureAge → Malicious` names no
  family; `Skyhigh → BehavesLike.…` is explicitly a behavioural rule;
  `Trojan.Script.2226` names no real family.
- **Related builds disagree with each other.** Bkav Pro flags onefile but not
  onedir; Skyhigh flags onedir but not onefile. A signature that matched real
  malware would follow the bytes and flag both.
- **`onedir` does not help.** Both layouts scored 3/73 with the same two engines,
  which refutes the most common advice in this area.
- **Rebuilding the bootloader does not help.** 3/73 became 2/70: Zillya cleared,
  Bkav Pro and SecureAge flagged it anyway. New bootloader bytes would have
  cleared it if the shared stub were the cause.
- **What is left is the embedded CPython runtime and PyInstaller's archive
  format**, neither of which the developer controls.

### The per-platform artifacts

All unsigned, all scanned at the same time, recorded in `docs/virustotal/`:

| Artifact | VirusTotal | SHA-256 |
|---|---|---|
| AppImage | **0 / 64** | `c065c1c3…` |
| `.deb` | **0 / 61** | `444c47fd…` |
| macOS zip | **0 / 73** | `22d5d093…` |
| Windows portable ZIP | **0 / 66** | `1dc53738…` |

Three of the four flagging engines scanned the AppImage and reported it clean.
That is the strongest evidence in the whole research for reading these detections
as a Windows-PE phenomenon rather than a property of the application: same code,
same version, different packaging, no detections.

### The variable this measurement did not cover: the installer

TBO ships no Windows installer, so every number above is a statement about a
frozen executable or an archive. The next variable - the NSIS wrapper around a
payload - was measured separately, on a sibling application, on 2026-10-31, and
it belongs here because it changes what "0/71 for Nuitka" can be used to claim.

`ksnip-pyqt6` was built four times from **one identical Nuitka payload** (662
files, 92 MB). Only the wrapper changed:

| NSIS | Script shape | Installer | VirusTotal |
|---|---|---|---|
| 3.13.0 | minimal: MUI2, 5 pages, 1 section, no bitmaps, solid LZMA | 34.8 MB | 1/70 Trapmine `high.ml.score` |
| 3.13.0 | same, `ZLIB` | 43.6 MB | 1/69 Trapmine `high.ml.score` |
| 3.10.0 | same, `ZLIB` | 43.6 MB | 1/69 Trapmine `moderate.ml.score` |
| 3.12.0 | reference layout: MUI v1, 6 pages, 4 sections, bitmaps, `XPStyle` | 43.8 MB | **0/67** |

The portable ZIP of that same payload was clean in every round.

Three consequences for this project:

1. **The freezer is not the last variable.** A clean `TBO.exe` says nothing
   about an installer wrapped around it. TBO's 0/71 is a statement about the
   frozen executable, which is exactly what TBO ships - the claim is narrower
   than "Nuitka produces clean Windows software".
2. **Compression is not a lever.** LZMA to ZLIB moved the installer by 8.8 MB
   and left the verdict untouched.
3. **If TBO ever gains an installer**, port the shape from
   `my-PyQt6-Apps/lucio-iva-calculator-resultados/_evidence/build/LucioIVACalculator.nsi`
   - six pages including a components page, four sections, header and welcome
   bitmaps, `XPStyle on`, a complete version resource -
   and pin makensis to a version that has been the package default for a while.
   The minimal script is the one that gets flagged.

The full record, with hashes, VirusTotal links and the two builds that would
separate stub version from script shape, is
`my-PyQt6-Apps/lucio-iva-calculator-resultados/INSTALLER_WRAPPER_EXPERIMENT.md`.

### What is NOT established

- **n = 1 application.** One build of each arm, one point in time. The matrix's
  own rule applies: one sample is noise.
- **The installer variable is measured elsewhere.** The wrapper experiment above
  was run on a different application; it says nothing about how a TBO installer
  would score, only that the wrapper is a variable worth controlling.
- **Unsigned, and versioned `2.0.0.dev0`.** Both are weak negative signals
  independent of the freezer.
- **Submission history is uncontrolled.** A hash VirusTotal has never seen is
  treated differently from one with a track record.
- **Scores drift.** The screenshots are a moment, not a standing fact.
- **No vendor has explained its heuristic.** The mechanism is inferred from the
  shape of the data, not from any engine's statement.

The correct response remains procedural — report to the vendors involved — and
never obfuscation, packing or binary mutation.

## 7. Windows Code Signing

None. No certificate, no `signtool`, no secret, no signing job. The consequences
are the same as for every unsigned Windows artifact: SmartScreen warnings until
reputation accumulates, and heavier weighting from heuristic engines.

The project's own planning note is that code signing for one program may follow
later; the research's finding is that OV certificates usually arrive on a
hardware token and therefore cannot be automated in CI, so the CI-compatible
option is a cloud HSM or a service such as SignPath, which is not guaranteed for
low-reputation open-source projects.

## 8. The Portable ZIP: Three Attempts and a Shape Check

This is the most transferable engineering story in the project, and it is
recorded in `SOLUCIONES-TBO.md` §12. Summarised:

**Attempt 1 — `Compress-Archive`.** Wrote backslash separators. The ZIP
specification (APPNOTE.TXT §4.4.17.1) requires `/`. On Linux and macOS, `unzip`
treats `\` as an ordinary character, so 277 of 278 entries unpacked as files
literally named `TBO\python312.dll`.

**Attempt 2 — `ZipFile::CreateFromDirectory`.** Also wrote backslashes. The
behaviour is governed by an AppContext switch that defaults to the old behaviour
unless the *host* application targets .NET Framework 4.6.1 or later; Windows
PowerShell 5.1 does not. CI failed at that step.

**Attempt 3 — build the names in Python.** `packaging/make_portable_zip.py`
constructs each entry from `Path.parts`, joins with `/`, and then **re-reads the
archive it just wrote** and fails if any entry still contains a backslash. The
post-condition is a check on `zipfile`'s behaviour, not on the script's own
logic.

That fix was necessary but not sufficient, because the *shape* was still wrong in
two ways that a separator check cannot see:

| Symptom | Cause | Fix |
|---|---|---|
| Archive contained a nested `TBO/` folder | `Copy-Item <dir> <existing-dir> -Recurse` copies the folder, not its contents | `Copy-Item "$dir\*"` |
| `COPYING` loose at the archive root | the licence was copied next to the staging folder, and nothing named the folder | copy `COPYING` into the staging directory; `--prefix` names the single top-level folder |

The helper now takes `--prefix NAME` and `--require FILE`, and the build calls it
as:

```powershell
python make_portable_zip.py $stagingRoot $zipPath `
    --prefix "TBO-$version-Windows-x64-portable" --require TBO.exe --require COPYING
```

`--require` is the part that matters: the same nested tree that once shipped
silently now aborts the build. It was tested against a synthetic tree reproducing
the old layout before being trusted.

**The general lesson**, and it is not specific to Python: a packaging step that
only checks "the file was created" will happily publish an archive whose internal
layout is wrong. Check the layout, by reading the artifact back.

## 9. Linux AppImage

`packaging/build_appimage.sh` builds a PyInstaller `onedir` payload, hand-builds
the AppDir, writes an `AppRun`, and calls a pinned `appimagetool`.

Worth noting:

- **The tool is pinned by version and SHA-256** (lines 28-38). The `continuous`
  tag is mutable; this project was burned by it once when the asset was
  republished and the checksum changed, and repinned to `1.9.1` with
  `ed4ce84f…`.
- **Built on `ubuntu-22.04`** for a 2.35 glibc baseline, not on the default
  runner.
- **Desktop integration is complete**: `packaging/tbo.desktop` and
  `packaging/org.tbo.TBO.appdata.xml`, with the icon shipped under the
  `org.tbo.TBO` name so the desktop entry's `Icon=` resolves.
- **Bundled data must be added explicitly.** The first working AppImage was
  missing 14 UI icons and the translations, which produced a stream of `qt.svg`
  errors at runtime. `--add-data ".../src/tbo/resources:tbo/resources"` and
  `--add-data ".../translations:tbo/translations"` fixed it. This is the same
  destination-must-match-runtime-resolution rule that decides every
  `--add-data` argument in every freezer.

The AppImage is 71 MB and scored **0/64**.

## 10. Debian Package

The only real `.deb` in this research, and it uses the **native dependency
model**: `debian/control` depends on `python3-pyqt6` and `python3-pyqt6.qtsvg`
from the distribution rather than bundling Qt.

```text
Depends: ${python3:Depends}, ${misc:Depends},
         python3-pyqt6, python3-pyqt6.qtsvg
Recommends: python3-pyqt6.qtpdf
Architecture: all
```

The consequences are exactly what theory predicts: the package is **366 KB**
against 71 MB for the AppImage, and it will not install on a distribution without
`python3-pyqt6` (or an older Qt that lacks the QtSvg bindings). `Architecture:
all` is correct here *because* the Qt is not bundled — the package contains only
Python.

Other details worth copying:

- `debian/rules` overrides `dh_auto_test` to skip the Qt GUI tests, which abort
  headless in CI. That is the pragmatic answer; the better one is an `xvfb-run`
  wrapper, which is still on the roadmap.
- `debian/copyright` and `debian/source/format` (`3.0 (quilt)`) are present, not
  omitted as "not needed yet".
- The package was audited after building, not just built. The audit is
  `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/DEBIAN-PACKAGE-AUDIT.md` and covers
  `dpkg -c`, `dpkg -I`, the installed file list and the desktop entry.

The `.deb` scored **0/61**.

## 11. Flatpak

`packaging/org.tbo.TBO.json` is a complete manifest: `org.kde.Platform` runtime
6.8, `org.kde.Sdk` SDK, `command: ["python3", "-m", "tbo"]`, finish-args and
build commands.

The CI job is **disabled**, and the reason is written in the workflow rather than
left to be rediscovered (`.github/workflows/build.yml:53-55`):

```yaml
# build-flatpak is DISABLED: the Docker image ghcr.io/flathub/flathub-infra:latest
# is no longer publicly accessible. Re-enable only when a working image is identified.
```

This is the pattern to copy: a disabled job that names the external cause. A job
deleted silently looks like a project that never tried.

## 12. macOS

`packaging/build_macos.sh` produces a PyInstaller `.app` and zips it. The app is
**unsigned and unnotarized**, so Gatekeeper blocks it on first launch on any
recent macOS.

Two packaging details are wrong in a way that is worth documenting because they
are invisible on Linux:

- The released asset, `tbo-macos.zip`, contains **one entry: another zip**
  (`TBO-2.0.0.dev0-macOS-x64.zip`). CI produces the inner zip correctly, with 598
  entries under `TBO.app/`; the outer one was added by hand when publishing. A
  user has to extract twice.
- The release notes describe it as "Unzip to get `TBO.app`", which is not what
  the artifact does.

Neither breaks anything, and both are the kind of thing that is obvious only to
someone who has downloaded their own release.

## 13. macOS Signing and Notarization

None. For the correct procedure see
`.dsh/skills/pyqt6-macos-signing-notarization/` and the pyzo case study, which
implements inside-out signing, hardened runtime, `notarytool` and `stapler` in CI.

## 14. GitHub Actions

Five active jobs, triggered only by `workflow_dispatch`:

```text
build-wheel      wheel + sdist
build-deb        dpkg-buildpackage -b -uc -us
build-appimage   ubuntu-22.04, PyInstaller onedir + appimagetool
build-windows    Nuitka + make_portable_zip.py
build-macos      PyInstaller .app -> zip
```

Plus a commented-out `build-flatpak` with its reason.

What is right:

- **Manual dispatch only.** Packaging builds are expensive and produce artifacts
  that expire; running them on every push would be waste. The trade is that CI
  does not continuously prove the packaging still works, which is exactly how the
  thirteen truncated binaries (section 17) went unnoticed.
- **Each job installs its own toolchain** from a pinned requirements file, so a
  change to one platform cannot break another.
- **Artifacts are uploaded per job** with `upload-artifact@v5`.

What is missing:

- **No artifact smoke test.** Nothing downloads the produced `.deb`, AppImage or
  ZIP and runs it, so a bundle missing its Qt plugins still produces a green tick.
  TBO ships a `--smoke-test`-style path only in the measurement kit, not in the
  release pipeline.
- **No signing step**, so no secrets are exercised and none can be verified.

## 15. Resource Handling

TBO is the origin of the resource-collection bug documented in
`docs/GitHub-Actions-Solutions/PACKAGING-RESOURCE-COLLECTION-BUG.md`, and the
lesson is in `SOLUCIONES-TBO.md` §9: builds that went green and shipped bundles
without their icons and translations.

The rule that came out of it is the one this research repeats everywhere:

> Every `--add-data` and `--include-data-dir` destination must match the path the
> code resolves **at runtime inside the frozen tree**, not the path the resource
> has in the repository.

The AppImage needed `src/tbo/resources` to land at `tbo/resources` and
`translations` to land at `tbo/translations`; anything else builds "successfully"
and fails at the first `qt.svg` icon lookup.

The Debian package sidesteps the whole class of problem: it installs real files
under `/usr/lib/python3/dist-packages` and the distribution owns Qt.

## 16. Translations

`.ts` sources live in `translations/`, and `packaging/update_translations.sh`
compiles them with `lrelease`. The frozen builds must then *ship* the resulting
`.qm` files, which is the failure mode in section 15: the sources were in the
repository, the build did not include them, and the application came up in
English regardless of locale.

The evidence pack includes both the script and the two `.qm` files it produces,
so the compilation step can be inspected next to its inputs.

## 17. Problems and Weaknesses Found

Ordered by how much damage they can do:

1. **Nothing is signed on any platform.** Windows trips SmartScreen, macOS is
   blocked by Gatekeeper, Linux users get no signature either.
2. **Released assets are assembled by hand.** The published
   `TBO-2.0.0.dev0-Windows-x64-portable.zip` is not the file CI produced for the
   same commit: CI emits 263 entries under a folder named after the version, the
   published one has 319 and came from a manual re-zip. The macOS asset is a
   zip-inside-a-zip. So "reproducible from the repository" is not true for the
   published artifacts even though the recipe is public.
3. **A commit truncated thirteen binary files to zero bytes.** Commit `1a9f5fb`
   emptied `icon.png`, the tutorial PDF, the four VirusTotal screenshots, the
   demo GIF and four `.qm` catalogues. Nothing in Git signalled it: an empty blob
   is a valid blob, `git status` was clean, and the diff only shows
   `Bin 0 -> N bytes` once the files are restored. The Windows build broke on the
   empty icon (`PIL.UnidentifiedImageError`) and that was the only symptom. They
   were restored byte-for-byte from `bca59c3` in `d126beb`. The lesson is not
   "commit more carefully"; it is that binary assets need a checksum manifest in
   the repository, which this project does not have.
4. **No Windows installer.** The portable ZIP is the only Windows artifact.
5. **No artifact smoke test in CI**, so packaging regressions are found by users.
6. **The Flatpak story is dead** with the manifest still in the tree.
7. **`build_windows_pyinstaller.ps1` is dead weight** kept for reproducibility —
   a defensible choice, but it is never run.
8. **`on: workflow_dispatch` only** means packaging is proven when someone
   remembers to press the button.

## 18. Techniques Worth Reusing

1. **Publish the hash next to the score.** `docs/virustotal/` is the model: four
   links, four digests, four screenshots. It is what makes an antivirus claim
   auditable a year later.
2. **Measure a freezer change instead of asserting it**, and hold everything else
   constant while doing it.
3. **Build archives from a language that can be tested**, then verify the archive
   you produced, not the one you intended.
4. **`--prefix` and `--require` as archive post-conditions.**
5. **Pin third-party build tools by version and checksum**, never by a mutable
   tag.
6. **Pick the glibc floor on purpose** by choosing the runner.
7. **Native dependency model for distribution packages** when the distro already
   ships Qt.
8. **Tombstones for disabled work**, with the reason and the condition to
   re-enable.
9. **Audit the `.deb` after building it**, not just build it.

## 19. Recommended Approach for My PyQt6 Projects

Take from TBO:

- the measurement discipline and the hash-with-score record;
- the Python-built, post-condition-checked archive;
- the pinned AppImage tool;
- the `ubuntu-22.04` floor;
- the native-dependency `.deb` with a real audit;
- the tombstone habit.

Do not take:

- hand-assembled release assets;
- a repository without a checksum manifest for its binary assets;
- an unsigned pipeline on any platform, if the audience is anyone other than
  yourself;
- a packaging workflow that only runs when manually dispatched, unless you also
  run it on a schedule.

## 20. Important Files to Study

In `my-PyQt6-Apps/TBO-resultados/_evidence/`:

| File | Read it for |
|---|---|
| `packaging/build_windows_nuitka.ps1` | The staging fix and the `--prefix`/`--require` call |
| `packaging/make_portable_zip.py` | Conformant entry names plus shape post-conditions |
| `packaging/build_appimage.sh` | Pinned tool, AppDir layout, `--add-data` destinations |
| `packaging/build_macos.sh` | PyInstaller `.app` zipping |
| `debian/control`, `debian/rules` | Native dependency model, test override |
| `.github/workflows/build.yml` | Five jobs, tombstones, pinned requirements |
| `packaging/org.tbo.TBO.json` | A complete Flatpak manifest, unbuilt |
| `packaging/org.tbo.TBO.appdata.xml` | AppStream metadata |
| `docs/GitHub-Actions-Solutions/PACKAGING-RESOURCE-COLLECTION-BUG.md` | The resource bug in full |
| `pyproject.toml` | The version source used by the `.deb` and by Nuitka |

Outside the pack, and worth reading in the same folder:

- `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md` — the fix log, 12
  numbered sections, including the ZIP saga (§12) and the measurement (§11).
- `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/DEBIAN-PACKAGE-AUDIT.md` — the `.deb`
  audit.
- `03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` §B.1 — the full
  measurement with hashes and per-engine lists.
- `experiments/pyinstaller-vs-nuitka/` — the repeatable kit, including the
  evidence screenshots and the measurement script.

## 21. Commands Used by the Project

```bash
# from source
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
./tbo.sh data/tut.tbo
python -m pytest tests/unit -q

# Debian package
dpkg-buildpackage -b -uc -us
sudo apt install ./tbo_*.deb

# AppImage (in CI, ubuntu-22.04)
bash packaging/build_appimage.sh

# Windows (PowerShell, in CI)
.\packaging\build_windows_nuitka.ps1
```

## 22. Final Conclusions

### Direct answers to the questions this research asks

| Question | Answer for this project |
|---|---|
| Does it build for all three desktop platforms? | Yes, four artifacts, three technologies. |
| Does it test the artifacts it ships? | No. It has a working local measurement kit and a `--smoke-test` path, but the release pipeline does not run the produced artifacts. |
| Does it sign anything? | No. |
| Does it handle Qt resources correctly? | Yes now; the rule came from getting it wrong and shipping broken bundles. |
| Does it pin its build environment? | Build dependencies yes (`==`); the runner images no. |
| Does it produce reproducible artifacts? | The recipe is public and the ZIP is now deterministic in shape; the *published* assets were hand-assembled, so they are not the CI output. |
| Does it record antivirus results? | Yes, and better than any other project here: hashes, report links and screenshots. |
| Is the Nuitka-versus-PyInstaller question settled? | For this application, on this evidence: yes, the PyInstaller arms were flagged and the Nuitka arm was not. As a general rule: no. |

### What this project contributes to the research

Three things no other project in this set supplies:

1. **A controlled measurement** with four arms, published hashes, per-engine
   lists and screenshots — and one refuted hypothesis (the bootloader).
2. **A real, audited Debian package**, which is the only ground truth for the
   `.deb` Skill.
3. **A worked example of an archive bug that three plausible fixes failed to
   solve**, and the shape check that finally made it un-reintroducible.

It also contributes a cautionary tale that has nothing to do with packaging and
everything to do with maintaining evidence: thirteen binary assets were silently
emptied by a normal-looking commit, and only a broken build revealed it.

And it marks the edge of what a freezer measurement can claim. Section 6 records
a later experiment on a sibling application which shows that the installer
wrapping a payload is its own variable, capable of turning a clean payload into a
flagged artifact. TBO's own numbers remain valid for what TBO ships - a frozen
executable and a portable ZIP - and no wider.

### Confidence summary

| Claim | Confidence |
|---|---|
| The four-platform pipeline as described in section 1 | **HIGH** — read from the pinned scripts |
| Nuitka 0/71, PyInstaller 3/73 in both layouts | **HIGH** for the observation, **LOW** as a generalisation |
| Rebuilt bootloader 2/70 refutes the bootloader hypothesis | **HIGH** for this application |
| AppImage 0/64, `.deb` 0/61, macOS 0/73, Windows ZIP 0/66 | **HIGH** — hashes and screenshots checked in |
| Detections are a Windows-PE phenomenon, not application-specific | **MEDIUM-HIGH** — three flagging engines reported the AppImage clean, n = 1 application |
| The installer wrapper is a separate variable from the freezer | **MEDIUM-HIGH** — four installers of one payload on a sibling application, section 6 |
| The ZIP conformance and shape fixes work | **HIGH** — verified in a CI build and by extracting the artifact |
| Published assets are not the CI output | **HIGH** — sizes, entry counts and hashes differ |
| Nothing is signed | **HIGH** — no signing code, secret or job exists |
