# Packaging Study: Lucio IVA Calculator

## 1. Executive Summary

This report studies repository revision `4db15fa` (`v0.1.1-22-g4db15fa`) as
inspected on 2026-10-30. Lucio IVA Calculator is a GPL-3.0 VAT calculator
written in Python with PyQt6, by the same owner as TBO, and it is the only
project in this research set that changed its Windows freezer **because of
antivirus results** and then wrote the result down.

The release architecture is unusual in one specific way: it does not use the
same freezer on every platform.

```text
Python + PyQt6 source
        |
        +-- Windows (windows-2025, x64)
        |     Nuitka --standalone -> build/dist/LucioIVACalculator/
        |     -> Compress-Archive portable ZIP
        |     -> NSIS makensis -> setup.exe
        |
        +-- Linux (ubuntu-latest, x86_64)
        |     PyInstaller -F -w (onefile) -> binary
        |     -> pyi-archive_viewer resource gate
        |     -> tar.gz with the binary + .desktop + icon
        |
        +-- macOS (macos-15-intel)
              PyInstaller -D -w -> LucioIVACalculator.app
              -> ditto -c -k --sequesterRsrc -> zip
```

Each platform is built in its own job, then a second job downloads the artifact
and **runs it** (`--smoke-test`) before anything is allowed to reach a release.
On Windows that means installing the NSIS installer silently with `/S /D=` and
executing the installed program, and separately extracting the portable ZIP and
executing that.

The project does **not** use code signing, Authenticode, an Apple Developer ID,
hardened runtime, entitlements, notarization, stapling, UPX, a Debian package, a
Flatpak, an AppImage, build provenance attestations, or an SBOM. Those absences
were verified by recursive source search across the pinned tree (excluding
`venv/` and `translations/`), not inferred from silence in the README:

| Search term | Files matched | Reading |
|---|---|---|
| `codesign`, `signtool`, `authenticode` | 0 | no signing code anywhere |
| `notariz` | 0 | no notarization |
| `hardened`, `entitlements` | 0 | no hardened runtime |
| `attestation`, `provenance`, `sbom` | 0 | no provenance or SBOM |
| `flatpak`, `appimage` | 0 | neither is produced |
| `upx` | 3 | only prose in `docs/nuitka-windows-build.md:511` and `windows-exe-fixes.md:41` saying it is *not* used |
| `dpkg`, `debian` | 2 files | `README.md` advice about *building on* Debian, not about producing a `.deb` |

The strongest reusable ideas are:

1. **Test the artifact, not the build.** Every platform has a job that downloads
   what CI produced and runs it. This is the single practice most of the other
   case studies lack.
2. **A silent-install test of the installer.** `Start-Process -ArgumentList "/S",
   "/D=$installDir"` proves the NSIS script actually installs, not just compiles.
3. **Gate the build on the archive's contents.** `build/build_linux.sh:67-86`
   greps the output of `pyi-archive_viewer -l` for five required resources and
   fails the build if any is missing. That is a direct, automated answer to the
   "bundled without its icons and translations" class of bug documented in
   `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md`.
4. **The version lives in one file.** `VERSION` feeds the artifact names, the PE
   resource and the installer, rather than being repeated in four places.
5. **Per-user installation by construction.** `RequestExecutionLevel user` plus
   `$LOCALAPPDATA\Programs` plus `HKCU` uninstall keys is a coherent choice, and
   it is consistent in all three places.

The largest weaknesses are that the antivirus result is recorded as a number
without the artifact hashes it belongs to; that the CI smoke test exits before
`QApplication` is constructed, so it cannot catch a missing Qt plugin or a
missing resource; that the release assets do not match what the release job
produces, so `v0.1.1` was assembled by hand; that dependencies are unpinned
across the board except on macOS, where one package is pinned two minor versions
behind the others; that the workflow runs on every push with no path filter; and
that there is no signing of any kind on any platform.

Evidence terminology in this report:

- **Implemented** means a current script or workflow performs it.
- **Documented** means project documentation claims it.
- **Measured here** means this study observed it in a released artifact or by
  searching the pinned tree.
- **Not verified** means the available evidence does not establish it.

## 2. Project Architecture

### Identity and purpose

A desktop VAT ("IVA") calculator. Single-window PyQt6 application with a help
system, translations and a theme. The `README.md` describes it as a simple,
modern, cross-platform calculator; `VERSION` reads `0.1.1`.

### Languages and frameworks

Python 3.11 (all three build jobs), PyQt6 (6.5.3 pinned on macOS, `>=6.7`
elsewhere), NSIS for the Windows installer, shell plus PyInstaller for Linux and
macOS, PowerShell plus Nuitka for Windows.

The unit test matrix also runs on Python 3.13 (`.github/workflows/build.yml:17`),
so the *source* is tested on a newer interpreter than the *build* uses.

### Supported systems

| Platform | Runner image | Artifact | Format |
|---|---|---|---|
| Windows 10/11 x64 | `windows-2025` | installer + portable ZIP | NSIS `.exe`, `.zip` |
| Linux x86_64 | `ubuntu-latest` | tarball | `.tar.gz` |
| macOS Intel | `macos-15-intel` | `.app` in a zip | `.zip` |

`MACOSX_DEPLOYMENT_TARGET` defaults to `11.0`
(`build/build_macos.sh:15`, `.github/workflows/build.yml:206`).

### Entry points and structure

`main.py` is both the application and the freeze entry point. It is 2092 lines
and contains the window, the business logic and the argument handling. There is
no `src/` layout and no packaged module hierarchy: the build scripts point
Nuitka and PyInstaller straight at `main.py`.

### Dependency and build metadata

| File | Contents | Pinned? |
|---|---|---|
| `build/requirements-windows.txt` | `PyQt6>=6.7`, `nuitka>=2.6`, `ordered-set>=4.1.0`, `zstandard>=0.23.0` | no |
| `build/requirements-linux.txt` | `PyQt6>=6.7`, `pyinstaller>=6.0` | no |
| `build/requirements-macos.txt` | `PyQt6==6.5.3`, `PyQt6-Qt6==6.5.3`, `pyinstaller>=6.0` | PyQt6 only |
| `requirements.txt` | `PyQt6>=6.7` | no |

There is no `pyproject.toml`, no lock file and no constraints file.

The macOS pin is the interesting entry: two minor versions **behind** the other
two platforms, with no explanation recorded anywhere in the tree. The recursive
search for `6.5.3` finds it only in that file. The consequence is that the
macOS artifact ships a different Qt from the Linux and Windows ones — a real
difference in behaviour surface between platforms that the release notes do not
mention.

### Testing

`tests/` holds `unittest` files, run as `python -m unittest discover -s tests` in
four of the six build jobs. There is no `pytest` configuration and no coverage
configuration.

## 3. Packaging Overview

### Actual map and responsible files

| Concern | File | Notes |
|---|---|---|
| Windows build | `build/build_windows.ps1` | Nuitka, then NSIS |
| Windows installer | `build/LucioIVACalculator.nsi` | MUI, per-user, bilingual |
| Linux build | `build/build_linux.sh` | PyInstaller onefile + resource gate |
| macOS build | `build/build_macos.sh` | PyInstaller `.app` + `ditto` |
| Icon (macOS) | `scripts/create_macos_icon.py` | SVG to `.iconset` for `iconutil` |
| Translations | `scripts/compile_translations.ps1`, `lrelease` in both shell scripts | |
| Desktop entry | `build/LucioIVACalculator.desktop` | |
| Orchestration | `.github/workflows/build.yml` | 7 jobs, tag-gated release |
| Release checklist | `docs/github_release_checklist.md` | manual, Spanish |
| Nuitka reference | `docs/nuitka-windows-build.md` | 534 lines, the project's best document |

### Current versus alternative infrastructure

Present: Nuitka (Windows only), PyInstaller (Linux and macOS), NSIS, per-user
install, artifact smoke tests, `SHA256SUMS.txt` at release, translations
compiled at build time from `.ts` sources.

Absent: signing of any kind, notarization, `.deb`, Flatpak, AppImage, onedir on
Linux, lock files, SHA-pinned actions, provenance attestations, an installer
that can update in place.

The two `pyinstaller-old` and `test-nuitka` branches still exist on the remote,
which preserves the comparison the project made before switching. That is a
cheap and effective way to keep a rejected approach auditable, and it is worth
copying.

## 4. Windows

### Actual build

`build/build_windows.ps1`:

1. Reads `VERSION`, derives a four-part numeric version by appending `.0`
   (line 12). `VERSION` is `0.1.1`, so the PE resource gets `0.1.1.0`.
2. Compiles translations through `scripts/compile_translations.ps1` (line 18),
   which requires `lrelease.exe` on `PATH`. CI supplies it with
   `jurplel/install-qt-action@v4` pinned to Qt `6.7.3`.
3. Runs Nuitka `--standalone` (lines 20-39).
4. Locates the built `.exe` inside a `*.dist` directory (lines 41-47).
5. Copies the `.dist` tree to `build/dist/LucioIVACalculator/` and copies the
   licence, icon and the two NSIS bitmaps next to it (lines 49-53).
6. Writes the portable ZIP with `Compress-Archive` (lines 55-59).
7. Rewrites three `!define` lines in the `.nsi` by exact string replacement,
   writes the result into `build/dist/`, and runs `makensis` if it is installed
   (lines 61-75).

Step 7 is the fragile part and is treated in section 7.

### Architecture and installation scope

Per-user, no elevation: `RequestExecutionLevel user` and
`InstallDir "$LOCALAPPDATA\Programs\${APP_DIR}"`
(`build/LucioIVACalculator.nsi:28-29`). Uninstall data is written to `HKCU`
(lines 95-100), which matches the install scope — a detail that per-machine
installs routinely get wrong.

### Portable versus installer

The project ships both, built from the same `.dist` tree. The portable ZIP is
documented as containing a folder **and a loose licence file**
(`docs/nuitka-windows-build.md:272-277`):

```text
LucioIVACalculator/
LICENSE
```

This study measured the released artifact and confirms exactly that shape: 133
entries, top level `LucioIVACalculator/` and `LICENSE`, with the licence at the
archive root rather than inside the folder (see section 6).

## 5. Nuitka

### Invocation

`build/build_windows.ps1:20-39`, in full:

```text
--standalone --assume-yes-for-downloads --remove-output --msvc=latest
--enable-plugin=pyqt6 --windows-console-mode=disable
--windows-icon-from-ico=assets\app-icon.ico
--company-name=Lucio --product-name="Lucio IVA Calculator"
--file-description="Lucio IVA Calculator"
--file-version=0.1.1.0 --product-version=0.1.1.0
--copyright="Copyright (c) 2026 Washington Indacochea Delgado and Joseph Lucio Guerrero"
--include-data-dir=assets=assets
--include-data-dir=translations=translations
--include-data-dir=docs=docs
--output-filename=LucioIVACalculator.exe
--output-dir=build\tmp\nuitka\output
main.py
```

### What each option buys

| Option | Why it matters |
|---|---|
| `--standalone` | A directory tree, not a self-extracting single file. The installer wraps the directory; nothing unpacks itself at launch into `%TEMP%`. |
| `--enable-plugin=pyqt6` | Lets Nuitka find and place Qt modules, plugins and the platform plugin. Without it the build succeeds and the program fails to start. |
| `--windows-console-mode=disable` | No stray console window on a GUI app. |
| `--msvc=latest` | Uses the MSVC toolchain already on the runner instead of downloading MinGW. |
| `--include-data-dir=X=X` | Destination is **relative to the program directory**, which is what the code resolves at runtime. A wrong destination builds green and ships without assets. |
| `--windows-icon-from-ico` | Icon in the PE resource. |
| `--file-version` / `--product-version` | Four-part numeric only. `0.1.1` is invalid; `0.1.1.0` is not. |

The `git`-independent `--include-data-dir=docs=docs` deserves a note: the help
HTML is shipped inside the frozen tree, so a documentation fix reaches users only
through a rebuild. That is documented practice here, not an accident, but it
couples docs to the release cycle.

### Is Nuitka reasonable here?

For this project, yes on the terms the project states: it is ~30 MB of
standalone tree for a small Qt app, it produces a directory that an installer can
own, and the recorded antivirus figures improved. It is **not** established that
Nuitka is what produced the improvement — see section 6.

## 6. Antivirus / VirusTotal Considerations

This is the section the project exists for in this research, so it is worth
being unusually precise about what is and is not established.

### What the project records

`docs/nuitka-windows-build.md:438-455` and `windows-exe-fixes.md:32-34` both
state, for version `0.1.1`:

```text
installer:    0/68
portable ZIP: 0/65
```

attributed to these files:

```text
LucioIVACalculator-0.1.1-nuitka-setup.exe
LucioIVACalculator-0.1.1-Windows-x64-nuitka-portable.zip
```

`windows-exe-fixes.md:22-30` adds that the earlier PyInstaller builds "were
legitimate, open source, and generated by GitHub Actions, but a few antivirus
engines reported heuristic false positives. The detections were generic and most
major vendors reported the files as clean."

### What this study measured, and can add

The release `v0.1.1` publishes a wrapper archive,
`lucio-iva-windows-nuitka.zip`, containing exactly those two files. Extracting it
and hashing them recovers the identity of the scanned artifacts, which the
project did not record at the time:

| Artifact | Bytes | SHA-256 |
|---|---|---|
| `LucioIVACalculator-0.1.1-nuitka-setup.exe` | 30,666,770 | `4d8cda498ff6c6b9745c5b86e9f81af9951c7d5f919ff4be1cd078cf10f55c12` |
| `LucioIVACalculator-0.1.1-Windows-x64-nuitka-portable.zip` | 30,315,218 | `6ce9487b14cf7a40085692dae68610ee651de3d1d1887f4420bc8d9ac89b8ec6` |

Those hashes make the claim re-checkable: anyone can submit either hash to
VirusTotal and compare the engine list against what the project recorded. That is
the missing half of the record, and it is worth adding to the project itself.

Also measured, for the portable ZIP: 133 entries, top-level
`LucioIVACalculator/` and `LICENSE`, and **zero entries containing a backslash**.

### The wrapper experiment: one payload, four installers

The record above says what the project measured, not why. On 2026-10-31 the
question was put to a controlled test on a second application, `ksnip-pyqt6`,
packaged with this project's recipe: Nuitka `--standalone` on `windows-2025`, a
portable ZIP, and an NSIS installer built in CI.

Four installers were built from **one identical Nuitka payload** - 662 files,
92 MB on disk. Only the wrapper changed, and the portable ZIP of that payload
was clean in every round.

| Round | makensis | Script shape | Installer | VirusTotal |
|---|---|---|---|---|
| A | 3.13.0 | minimal: MUI2, 5 pages, 1 section, no bitmaps, solid LZMA | 34.8 MB | 1/70 Trapmine `high` |
| B | 3.13.0 | same as A, `ZLIB` | 43.6 MB | 1/69 Trapmine `high` |
| C | 3.10.0 | same as A, `ZLIB` | 43.6 MB | 1/69 Trapmine `moderate` |
| D | 3.12.0 | this project's layout: MUI v1, 6 pages, 4 sections, bitmaps, `XPStyle` | 43.8 MB | **0/67** |

Round D is the only clean one, and it is the only one whose compiled installer
has this project's proportions:

| makensis statistic | Lucio IVA Calculator 0.1.1 | Round D |
|---|---|---|
| Pages / sections | 6 pages, 4 sections (1 required) | 6 pages, 4 sections (1 required) |
| Section table | 8,288 bytes | 8,288 bytes |
| Uninstall instructions | 280 | 280 |
| Compressed EXE header | 39,936 bytes | 39,936 bytes |

Hashes, VirusTotal links, compile statistics for all four rounds, and the two
builds that would separate the variables are in
`INSTALLER_WRAPPER_EXPERIMENT.md` next to this file.

### Why that is the answer

Three statements are supported by the table.

**The payload is not what is being scored.** The same 92 MB sits inside all four
installers, and the ZIP that carries it unchanged is clean every time. Whatever
the engine dislikes is in the wrapper.

**Compression is not the lever.** Round A to round B changed LZMA to ZLIB, moved
the installer by 8.8 MB, and changed nothing: same engine, same label.

**The wrapper's shape moves the score.** Three wrappers of one payload produced
`high`, `moderate` and `undetected` from the same engine, and the only clean
one is the one that looks like a mainstream installer. That is a continuous
score responding to the binary - what an ML verdict looks like, and what a
signature match does not.

One statement is not supported. Round C to round D changed two things at once,
the stub (3.10.0 to 3.12.0) and the script (minimal MUI2 to this layout), so the
data cannot say which half did the work.

### The mechanism that fits

An ML verdict of the form `Malicious.<severity>.ml.score` is a score on a
feature vector, and such models behave like density estimators: shapes that are
common in the training population score low, shapes that are rare score high,
intent is not an input.

- A **minimal NSIS installer** - five pages, one section, no bitmaps, a
  single-resolution icon, a 49 KB header - is rare among published desktop
  software and common among small custom NSIS droppers. Sparse region.
- **This project's installer** - six pages including a components page, four
  sections, header and welcome bitmaps, `XPStyle`, a full version resource - is what commercial Windows software looks like. Dense
  region.
- A **stub released weeks ago** has produced almost none of the installers in
  circulation; the stub that has been the Chocolatey default for years has
  produced a large share of them.

The same reading explains why the portable ZIP is never flagged: a ZIP is not an
executable, and the model is not asked the same question about it.

This is inference from four data points on one application, not a vendor
statement. Confidence: **MEDIUM-HIGH** that the wrapper is the variable,
**LOW** on the split between stub version and script shape.

### What is NOT established

- **The scores are the project's own statement.** No VirusTotal URL, no scan
  screenshot and no hash was stored with them. Confidence: **MEDIUM** —
  plausible and internally consistent, unverified by this study.
- **The producing revision is not identifiable.** The measured filenames carry a
  `-nuitka-` infix. Neither `main` (`build/build_windows.ps1:55`) nor
  `origin/test-nuitka` (line 79) produces that name — both write
  `LucioIVACalculator-<version>-Windows-x64-portable.zip`. So the scanned files
  were renamed, or produced by a revision that no longer exists. The bytes are
  recoverable; the recipe for those exact bytes is not.
- **Zero detections is not a property of Nuitka.** Two builds of two different
  applications is not evidence about a freezer. TBO's measurement in
  `03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` §B.1 found Nuitka
  clean and PyInstaller flagged on Windows; the honest reading of the pair is
  "consistent, n = 2, Windows only", not "Nuitka avoids detections".
- **The scores may have drifted since 2026-06-16.** Engine sets and heuristics
  change. Re-querying the hashes above today is the only way to know the current
  state, and a different result would not mean either build changed.
- **The wrapper experiment is one application.** It isolates the installer as the
  variable, which is the missing half of this record, but four installers of one
  application do not make the recipe portable to another project. It says what
  separated these four binaries, not what will separate anyone else's.

### What this replaces in the project's own account

`docs/nuitka-windows-build.md:505-520` lists what it calls helpful practices: no
UPX, complete Windows product metadata, a visible icon, clean installer
behaviour, reproducible Actions builds, a portable ZIP alongside the installer,
SHA256 checksums, and public source. It then adds, correctly, that code signing
is still recommended.

The experiment narrows that list. "No UPX" was never tested here and remains
unproven; none of the installers above contains UPX. "Complete metadata" is
present in all four rounds, including the three that were flagged, so it is not
what made the difference. "Clean installer behaviour" and "reproducible Actions
builds" are the same in all four. What separated them was the shape of the
installer binary itself.

None of this is a licence to mutate a binary until a scanner goes quiet. The
practices on that list are worth keeping because they are correct, and the
response to a suspected false positive is still a report to the vendor. What the
experiment adds is a reason to build the installer like a mainstream installer
rather than like a minimal one, which is a design decision, not an evasion
technique.

### The one thing this project does that is better than TBO's record

It kept the rejected approach alive. `origin/pyinstaller-old` still holds the
PyInstaller build scripts, including a `build/windows_app.manifest` that `main`
no longer has. A reader can therefore compare the two eras instead of trusting a
sentence about them.

## 7. Windows Installer

`build/LucioIVACalculator.nsi` is a modern-UI NSIS script worth reading in full.
The parts that matter:

| Line | What it does | Why it is right |
|---|---|---|
| 11-20 | `VIFileVersion`, `VIProductVersion`, seven `VIAddVersionKey` entries | The installer `.exe` carries real PE metadata, which is what Explorer's Properties dialog and most reputation heuristics read. |
| 22 | `SetCompressor ZLIB` | Correct but conservative. Section 6 shows the compressor is not what moves a scanner's verdict: switching it on a sibling project grew the installer by 8.8 MB and changed nothing. |
| 28 | `RequestExecutionLevel user` | No UAC prompt; installs where the user can write. |
| 29 | `InstallDir "$LOCALAPPDATA\Programs\LucioIVACalculator"` | Consistent with line 28. |
| 38-41 | Header and welcome bitmaps | Two `.bmp` files, 24-bit BMP3, 164x314 and 150x57, shipped in `assets/`. |
| 44-53 | Welcome, Licence, Components, Directory, InstFiles, Finish, plus three uninstall pages | The Components page is what makes the shortcut sections optional. |
| 54-55 | Spanish and English | |
| 70-77 | `GetUserDefaultUILanguage`, mask `0x3ff`, compare with 9 and 10 | Selects English or Spanish from the system UI language. |
| 89-101 | Main section, `SectionIn RO`, files, uninstaller, five `HKCU` keys | Complete Add/Remove Programs registration for a per-user install. |
| 122-130 | Uninstall section | Removes the tree, the shortcuts, the registry key and the Start Menu folder. |

### Why the layout matters, not only the options

Section 6 measures what happens when this layout is replaced by a minimal one:
the installer is flagged, and the same payload in a portable ZIP is not. The page
count, the components page, the two bitmaps and `XPStyle` are therefore not
decoration in that result. Together they are what makes
the compiled binary resemble the population of installers that scanners have
seen in bulk, and the compile statistics of a faithful port land on this
project's numbers exactly: 6 pages, 4 sections, an 8,288-byte section table, 280
uninstall instructions and a 39,936-byte compressed header.

Anyone porting this script should port the shape, not only the compression
setting and the registry keys.

### The fragility worth fixing

The version is not a build parameter. It is injected at build time by rewriting
exact literals (`build/build_windows.ps1:61-65`):

```powershell
$nsiContent.Replace('!define VERSION "0.1.0.0"', "!define VERSION `"$windowsVersion`"")
$nsiContent.Replace('!define INSTALLER_NAME "LucioIVACalculator-0.1.0-setup.exe"', ...)
$nsiContent.Replace('WriteRegStr HKCU ... "DisplayVersion" "0.1.0"', ...)
```

Three consequences, all of them silent:

1. If someone edits `VERSION` inside the `.nsi` file, the replacement simply
   does not match and the installer keeps the old version.
2. If someone reformats the `WriteRegStr` line — line breaks, quoting, an
   added key — the `DisplayVersion` in Add/Remove Programs keeps saying `0.1.0`
   while the file metadata says something else. Nothing fails.
3. The default value in the template must be left at a *stale* value for the
   replacement to work, so the template can never be "correct on its own".

A build that can silently produce a mislabelled installer is a real defect, and
it is invisible in CI because nothing checks the installed version. The fix is
cheap: pass the version with `/DVERSION=$windowsVersion` on the `makensis`
command line and read it from `${VERSION}` in the script, which removes the
string surgery entirely.

Related: `build/build_windows.ps1:67-75` treats a missing NSIS as a warning, not
a failure. The CI installs NSIS with `choco install nsis -y`, so in CI it is
always present — but a local build can quietly produce only the portable ZIP and
still exit 0.

## 8. Windows Code Signing

None. There is no certificate, no `signtool`, no signing step, no secret and no
mention of Authenticode in the entire tree (recursive search: 0 hits).

Consequences, stated plainly because they are the project's main distribution
problem:

- SmartScreen will warn on first run until enough reputation accumulates.
- Antivirus engines weight unsigned binaries more harshly.
- The 0/68 recorded for 0.1.1 says nothing about what the same bytes would score
  after a signature is added, and vice versa.

The project's own conclusion in `windows-exe-fixes.md:63` is correct and should
be quoted rather than paraphrased: Nuitka eliminated the *observed* detections
for the tested artifacts, but code signing remains the strongest long-term
improvement.

## 9. Linux

`build/build_linux.sh`:

1. Compiles `.ts` to `.qm` with `lrelease` if it exists, otherwise reuses
   whatever `.qm` files are already in the tree (lines 25-32). In CI it exists.
2. Runs PyInstaller `-w -F -y` with four `--hidden-import`s and three
   `--add-data` entries (lines 34-60).
3. **Verifies the archive contents** (lines 67-86).
4. Copies the `.desktop` file and the SVG icon next to the binary (lines 88-94).
5. Tars the binary, the `.desktop` file and `app-icon.svg` from `build/dist`
   (lines 96-100).

### The resource gate

This is the best single idea in the project and it is worth quoting in any
tutorial:

```bash
pyi-archive_viewer -l "$dist_binary" > "$archive_listing"
required_resources=(
  "assets/app-icon.svg" "assets/app-icon.ico"
  "docs/help_es.html" "docs/help_en.html"
  "translations/iva_calculator_en.qm"
)
for resource in "${required_resources[@]}"; do
    if ! grep -Fq "$resource" "$archive_listing"; then
        echo "Missing packaged resource in PyInstaller archive: $resource" >&2
        exit 1
    fi
done
```

Two properties make it good: it verifies the **produced artifact** rather than
the command line, and it names the specific resources that must be present
instead of asserting "the build succeeded". `-F` (onefile) is exactly the mode
where a missing `--add-data` destination is hardest to notice, because the bundle
still runs — it just ships without its icons and translations.

The gate degrades quietly: if `pyi-archive_viewer` is not on `PATH` it prints
"skipping archive resource verification" and continues (lines 84-86). That is a
soft failure inside a check whose whole purpose is to be hard.

### The GLIBC contradiction

`README.md:181-196` recommends building Linux releases on Debian 12 because it
"ships with GLIBC 2.36, which is compatible with many current Linux
distributions", and warns that building on a newer distribution raises the
minimum glibc for every user.

The workflow builds on `ubuntu-latest` (`.github/workflows/build.yml:40`), which
at the time of writing is Ubuntu 24.04 with GLIBC 2.39. **CI does not follow the
project's own documented rule**, and the result is a PyInstaller binary that will
refuse to start on any distribution older than that baseline. This is the same
failure the research records for CARA's `build-linux-appbundles.yml` and the
reason dikte pins `ubuntu-22.04`.

Building on `ubuntu-22.04` (or a `debian:12` container) would fix it.

### Desktop entry mismatch

`build/LucioIVACalculator.desktop:7` declares `Icon=LucioIVACalculator`, but
`build/build_linux.sh:100` ships the icon as `app-icon.svg`. A theme lookup for
`LucioIVACalculator` will not find `app-icon.svg`. For the icon to resolve the
file has to be installed as
`~/.local/share/icons/hicolor/scalable/apps/LucioIVACalculator.svg`, and nothing
in the tarball does that.

`Exec=LucioIVACalculator` assumes the binary is on `PATH`; extracting the tarball
into a directory does not put it there. The `.desktop` file is therefore
decoration unless the user installs the pieces by hand — there is no
`install.sh` and no `AppRun`.

## 10. Debian Package

None. The recursive search finds `dpkg`/`debian` only in `README.md` prose about
where to build. There is no `debian/` directory, no `control`, no `rules`, and no
job that produces a `.deb`.

The TBO case study in `my-PyQt6-Apps/TBO-resultados/` is the only source of
validated `.deb` evidence in this research.

## 11. macOS

`build/build_macos.sh`:

1. Compiles translations the same way as Linux (lines 19-26).
2. Builds the `.icns` from the SVG through `scripts/create_macos_icon.py` and
   `iconutil` (lines 28-29).
3. Runs PyInstaller `-w -D` with
   `--osx-bundle-identifier org.lucio.iva-calculator` (lines 31-45).
4. Copies the `.app` and the licence into a staging directory, then archives it
   with `ditto -c -k --sequesterRsrc` (lines 52-57).

### What is right

- `-D` (onedir) inside a `.app` bundle, not onefile.
- `iconutil` is the only supported way to build an `.icns`; the project generates
  the full `.iconset` rather than shipping a prebuilt icon.
- `ditto --sequesterRsrc` is the correct archiver for a bundle. `zip` would drop
  extended attributes and resource forks; `ditto` preserves them.

### What is missing

The app is **unsigned and unnotarized**. On any Mac running macOS 10.15 or later,
Gatekeeper will refuse it on first launch until the user right-closes and picks
Open, or clears the quarantine attribute. The project does not document this
workaround in the build script, and the release notes do not mention it.

There is no `codesign` call, no entitlements file, no `notarytool`, no `stapler`.
The `Info.plist` is whatever PyInstaller generates from the `--osx-bundle-identifier`
and `--name` alone: no `NSHighResolutionCapable`, no `LSMinimumSystemVersion`
beyond the deployment target, no `CFBundleVersion` override.

`macos-15-intel` builds an x86_64 app only. Apple silicon users will run it under
Rosetta 2, which works but is not a universal binary.

## 12. macOS Code Signing and Notarization

None, as in section 8 for Windows. For the full treatment of what a correct
inside-out signing order, hardened runtime, `notarytool` submission and stapling
look like, see
`PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/pyzo-results/PACKAGING_STUDY.md` and the `pyqt6-macos-signing-notarization`
Skill; this project contributes nothing to that subject and should not be cited
for it.

## 13. GitHub Actions

### Shape

`.github/workflows/build.yml` has seven jobs:

```text
unit_tests        3.11, 3.13
build_linux  -> test_linux      (downloads the artifact, runs --smoke-test)
build_windows-> test_windows    (installs silently, runs installed + portable)
build_macos  -> test_macos      (unzips, runs the bundle executable)
                              -> release   (only on refs/tags/v*)
```

The `build_*` → `test_*` split is deliberate and is the strongest part of the
pipeline: the test job has none of the build environment, so a bundle that only
works because of something on the builder's `PATH` fails there.

### Windows smoke test, in detail

`.github/workflows/build.yml:150-200`:

1. `Start-Process -FilePath $installer -ArgumentList "/S", "/D=$installDir" -Wait -PassThru`,
   then check the exit code. This validates the NSIS script end to end.
2. Run `installed\LucioIVACalculator\LucioIVACalculator.exe --smoke-test`.
3. `Expand-Archive` the portable ZIP and run
   `portable\LucioIVACalculator\LucioIVACalculator.exe --smoke-test`.

Testing the *portable* copy as well as the installed one is unusual and correct:
they are produced by different code paths and only the ZIP path involves
`Compress-Archive`.

### The bound on what that proves

`main.py:2070-2072`:

```python
def main() -> int:
    if "--smoke-test" in sys.argv:
        return 0
    QApplication.setOrganizationName(APP_ORG)
    ...
    app = QApplication(sys.argv)
```

The flag returns **before `QApplication` exists**. So the smoke test proves:

- the executable starts,
- the embedded Python runtime loads,
- `main.py` is importable and `main()` is reached.

It does **not** prove:

- that Qt's platform plugin (`qwindows.dll`) is present or loadable,
- that `assets/`, `translations/` and `docs/` made it into the bundle,
- that a window can be created at all.

Moving the check two lines lower — construct `QApplication`, load the translator,
then return — would cost milliseconds and cover the whole class of "the bundle is
missing its Qt plugins" failures. As it stands, the Windows job's green tick is
weaker than it looks, and the only real content check in the project is the Linux
`pyi-archive_viewer` gate.

### Release

`.github/workflows/build.yml:263-324`:

- gated on `startsWith(github.ref, 'refs/tags/v')`,
- derives `APP_VERSION` from the tag with `sed 's/^v//'`,
- writes `SHA256SUMS.txt` over the four artifacts,
- publishes with `softprops/action-gh-release@v2`, `draft: false`,
  `prerelease: false`.

Because `APP_VERSION` comes from the tag while the artifacts are named from
`VERSION`, **the tag must equal `VERSION` or the release job fails** to resolve
its inputs. `docs/github_release_checklist.md:5,27` does say to keep them in
sync, so the coupling is known — it is just enforced by a checklist rather than
by a check.

### Permissions and cost

`permissions: contents: write` is granted to the whole workflow
(lines 7-8), including the four jobs that only need to read. Only `release` needs
it.

`on: push:` has no branch filter and no path filter (lines 3-5), so every push
to every branch runs seven jobs, including four full platform builds and three
smoke tests. The TBO workflow limits itself to `workflow_dispatch` for exactly
this reason.

All six actions are referenced by floating major tag (`@v6`, `@v7`, `@v2`), not
by commit SHA. That is the norm in most projects and is a supply-chain risk: a
retagged or compromised action changes what runs here without any commit to this
repository.

## 14. Resource Handling

`--add-data`/`--include-data-dir` destinations are `assets`, `translations` and
`docs` on all three platforms, and `main.py` resolves them by plain relative
path from the program directory. Because the destinations are identical
everywhere, a resource present in one build is present in all three.

The Linux gate (section 9) is the only automated proof that the destination was
right. Windows and macOS rely on the smoke test, which as shown does not read a
resource at all. A missing `translations/` on Windows would therefore ship green.

## 15. Translations

`.ts` sources live in `translations/`, `.qm` files are generated at build time by
`lrelease`, and the Windows path uses a PowerShell driver
(`scripts/compile_translations.ps1`) while the shell scripts inline the loop.
The `--add-data/--include-data-dir` destination is `translations` on all three
platforms.

The Windows job installs a full Qt SDK (`jurplel/install-qt-action@v4`, Qt 6.7.3)
purely to get `lrelease.exe`; the Linux job gets it from `qt6-tools-dev-tools`
(which supplies `lrelease`) and the macOS job from `brew install qt`. Three
different mechanisms for one tool, and the Qt SDK version used to *compile*
translations (6.7.3) is deliberately unrelated to the Qt version the app *ships*
(`>=6.7` on Windows and Linux, 6.5.3 on macOS).

## 16. Security and Release Integrity

| Concern | State | Evidence |
|---|---|---|
| Artifact checksums | Implemented | `build.yml:301-309`, `SHA256SUMS.txt` attached to the release |
| Checksums published for 0.1.1 | Not matched | the published release contains three wrapper archives and no `SHA256SUMS.txt` |
| Build provenance attestation | Absent | recursive search: 0 hits |
| SHA-pinned actions | Absent | six `uses:` all floating |
| Dependency locking | Absent | `>=` ranges except `PyQt6==6.5.3` on macOS |
| Signing | Absent | recursive search: 0 hits |
| Least-privilege workflow permissions | Absent | `contents: write` workflow-wide |
| Secrets | None needed | nothing to leak, but also nothing to verify |

The integrity story is therefore "checksums, when the automated release path is
used". The 0.1.1 release shows what happens when it is not: the three assets are
`lucio-iva-linux.zip`, `lucio-iva-macos.zip` and `lucio-iva-windows-nuitka.zip`
— none of which any job in `build.yml` produces — and there is no `SHA256SUMS.txt`
among them.

This study's recommendation is to attach the checksums **to the artifacts
themselves** as well as to the release: a `SHA256SUMS.txt` that is not next to
the file it describes cannot be used by someone who downloaded one file months
later.

## 17. Techniques Worth Reusing

1. **A test job per platform that runs the artifact.** Copy this shape.
2. **Silent-install the installer in CI.** `/S /D=` plus an exit-code check
   catches more NSIS mistakes than any amount of reviewing the `.nsi`.
3. **The `pyi-archive_viewer` resource gate.** Cheap, specific, and it fails the
   build rather than the user.
4. **`--smoke-test` as an entry-point flag** — but place it *after*
   `QApplication` construction (this project's placement is the lesson, not the
   example).
5. **One `VERSION` file** feeding artifact names, PE resource and installer.
6. **Per-user install done consistently** in all three places: execution level,
   install directory, registry hive.
7. **Keeping the rejected approach on a branch** (`pyinstaller-old`), so the
   comparison stays auditable.
8. **`ditto --sequesterRsrc`** for macOS bundles.
9. **Recording the freezer migration reason in the repository**
   (`windows-exe-fixes.md`), not only in commit messages.

## 18. Techniques Specific to This Project

- The three-literal `.nsi` rewrite (section 7). The intent — a single source of
  version truth — is right; the implementation is fragile.
- `SetCompressor ZLIB` for speed at the cost of size.
- Three separate mechanisms to obtain `lrelease`.
- Building documentation *into* the bundle, so docs need a release to reach
  users.
- Publishing by hand and then leaving the automated path untested in production.

## 19. Problems or Weaknesses Found

Ordered by how much damage they can do:

1. **Hand-assembled release assets.** `v0.1.1` was published with three wrapper
   archives that no workflow produces, and without `SHA256SUMS.txt`. The
   automated path has therefore never been exercised end to end.
2. **The Linux binary is built on `ubuntu-latest`** while the README says to
   build on Debian 12. The shipped binary's glibc floor is far higher than
   intended.
3. **The Windows smoke test exits before `QApplication`**, so a bundle missing
   its Qt platform plugin passes CI.
4. **The installer version can silently go stale** because it is injected by
   exact-literal string replacement.
5. **No signing on any platform.** The macOS app is blocked by Gatekeeper and the
   Windows installer trips SmartScreen.
6. **macOS pins PyQt6 6.5.3** while Windows and Linux use `>=6.7`, with no
   recorded reason — three artifacts with three different Qt versions.
7. **The `.desktop` icon name does not match the shipped icon filename**, and
   `Exec=` assumes a `PATH` entry that no install step creates.
8. **`on: push:` with no filters** builds and smoke-tests everything on every
   push.
9. **Workflow-wide `contents: write`.**
10. **The resource gate degrades to a warning** when `pyi-archive_viewer` is
    missing.
11. **`docs/github_release_checklist.md` is stale**: it describes release assets
    that the workflow no longer produces (lines 47-52).
12. **No lock file**: two builds a month apart can differ with no repository
    change, which is also why the measured artifacts cannot be rebuilt today.

## 20. Recommended Approach for My PyQt6 Projects

Take from this project:

- the build → artifact-download → run split, on every platform;
- the silent-install test and the separate portable-executable test;
- the archive content gate;
- one version file, read by every script;
- per-user NSIS done consistently;
- `ditto --sequesterRsrc` on macOS;
- a branch that preserves the freezer you rejected.

Reject or fix:

- do not inject version strings by replacing literals — pass `/DVERSION=`;
- put `--smoke-test` **after** `QApplication` construction and load a
  translation and an icon before exiting;
- build Linux on the oldest glibc you intend to support (`ubuntu-22.04` or
  `debian:12`), and say which one in the release notes;
- pin dependencies in a lock file, and pin the same Qt on every platform or
  document why not;
- sign at least the Windows installer before asking strangers to run it;
- let the tag *and* the workflow both derive the version, and assert they match
  before building;
- publish only through CI, so the release job is exercised every time.

## 21. Important Files to Study

In the evidence pack, `my-PyQt6-Apps/lucio-iva-calculator-resultados/_evidence/`:

| File | Read it for |
|---|---|
| `build/build_windows.ps1` | Nuitka flags and the NSIS string surgery |
| `build/LucioIVACalculator.nsi` | A complete per-user, bilingual MUI installer |
| `build/build_linux.sh` | The resource gate (lines 67-86) and the GLIBC decision |
| `build/build_macos.sh` | `iconutil` and `ditto` |
| `.github/workflows/build.yml` | The build → test → release split |
| `docs/nuitka-windows-build.md` | The project's own Nuitka reference; section "VirusTotal Notes" |
| `windows-exe-fixes.md` | The freezer migration and the practices kept alongside it |
| `main.py` | `--smoke-test` placement and resource resolution |
| `build/requirements-*.txt` | The pinning asymmetry |
| `VERSION` | The single source of the version string |

## 22. Commands Used by the Project

```bash
# tests
python -m unittest discover -s tests

# Linux
pip install -r build/requirements-linux.txt
bash build/build_linux.sh
build/dist/LucioIVACalculator --smoke-test

# macOS
pip install -r build/requirements-macos.txt
bash build/build_macos.sh
"macos_app/LucioIVACalculator.app/Contents/MacOS/LucioIVACalculator" --smoke-test

# Windows (PowerShell)
pip install -r build/requirements-windows.txt
.\build\build_windows.ps1
Start-Process .\build\output\LucioIVACalculator-*-setup.exe -ArgumentList "/S", "/D=$PWD\installed" -Wait
.\installed\LucioIVACalculator\LucioIVACalculator.exe --smoke-test
```

## 23. Final Conclusions

### Direct answers to the questions this research asks

| Question | Answer for this project |
|---|---|
| Does it build for all three platforms? | Yes, with a different freezer per platform. |
| Does it test the artifacts it ships? | Yes — and this is its best practice, with the caveat in section 13. |
| Does it sign anything? | No. |
| Does it handle Qt resources correctly? | It verifies them on Linux only, and by archive listing rather than at runtime. |
| Does it pin its build environment? | Only the macOS PyQt6 version. |
| Does it produce reproducible artifacts? | No: no lock file, no pinned actions, and the published assets were assembled by hand. |
| Does it record antivirus results? | Yes — as counts, without hashes. This study recovers the hashes. |
| Is the Nuitka claim established? | **No.** Two self-reported scans of two applications is a lead, not a property of the freezer. |
| Is the installer wrapper a variable? | **Yes**, measured on a second application: four installers from one payload, three flagged, the one built like this project clean (section 6). |

### What this project changes about the research

It supplies the second Windows data point for the Nuitka-versus-PyInstaller
question, and it supplies it independently of TBO: the owner reached Nuitka here
first, for a small application, and then applied the same choice to TBO. That
strengthens the *pattern* while leaving the *cause* unproven, and it is exactly
the kind of evidence the matrix in
`03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` is designed to hold
without over-claiming.

It also contributes a practice the other seven projects do not have: an automated
check that the frozen artifact actually contains its resources. That idea, not
the antivirus anecdote, is the most portable thing in this repository.

The 2026-10-31 experiment in section 6 is the strongest contribution, and it is
a correction as much as an addition. It moves the question from "which freezer"
to "which wrapper", and it does so with one payload held constant across four
installers. The recipe in `_evidence/build/LucioIVACalculator.nsi` is no longer
just a well-written script; it is the specific layout that measured clean while
a minimal one did not. What it still cannot say is which part of that layout did
the work, and that gap is written down rather than papered over.

### Confidence summary

| Claim | Confidence |
|---|---|
| Freezers per platform, as described in section 1 | **HIGH** — read from the scripts at the pinned commit |
| Absences in section 1 | **HIGH** — recursive search over the pinned tree |
| Portable ZIP shape of 0.1.1 (133 entries, loose `LICENSE`, no backslashes) | **HIGH** — measured on the published artifact |
| SHA-256 of the two 0.1.1 artifacts | **HIGH** — computed from the published release |
| `0/68` and `0/65` VirusTotal figures | **MEDIUM** — project's own record, no scan artifact preserved |
| "Nuitka caused the improvement" | **NOT ESTABLISHED** — n = 2, self-reported, Windows only |
| "The installer wrapper, not the payload, is what gets scored" | **MEDIUM-HIGH** — four installers, one payload, one engine that answered, one application |
| "Which part of the wrapper layout matters" | **NOT ESTABLISHED** — stub version and script shape changed together |
| Which revision produced the scanned files | **NOT ESTABLISHED** — the `-nuitka-` names match no script on any branch |
| CI-built Linux binary requires a recent glibc | **HIGH** — `runs-on: ubuntu-latest` plus the README's own warning |
