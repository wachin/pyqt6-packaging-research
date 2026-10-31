# Practical PyQt6 Packaging Tutorial

Derived from Lucio IVA Calculator, pinned at `4db15fa`. Every command and file
reference below was read from that tree or measured on its published artifacts.
Where a snippet is adapted rather than copied, it is marked
`[TEMPLATE — MUST BE TESTED]`, because this repository forbids presenting an
untested recipe as a working one.

The order is deliberate: the build contract comes first, the freezers second,
the installer third, and verification last — because verification is what
decides whether any of the rest is true.

---

## 1. Establish a Reproducible Build Contract

Before writing a build script, decide four things and write them down.

**One version, one file.**

```
VERSION          # exactly one line: 0.1.1
```

Everything reads it: artifact names, the PE resource, the installer, the release
tag. Lucio does this (`build/build_windows.ps1:10-12`,
`build/build_linux.sh:13`, `build/build_macos.sh:6`) and it is the reason its
artifacts agree with each other. What it does **not** do is enforce that the tag
equals `VERSION`; section 13 shows the check that closes that hole.

**A per-platform build dependency file, not a shared one.** The three platforms
need different freezers, so they get three files:

```
build/requirements-windows.txt    # PyQt6 + nuitka
build/requirements-linux.txt      # PyQt6 + pyinstaller
build/requirements-macos.txt      # PyQt6 + pyinstaller
```

Lucio uses `>=` in all of them except a hard `PyQt6==6.5.3` on macOS. That is
the mistake to avoid: `>=` means two builds a month apart can differ without a
commit, and a cross-platform version skew nobody notices. Pin with `==` and
record why any platform deviates.

**A decision about signing, made now rather than later.** If the answer is "not
yet", write that down too, in the README, with the consequence
(SmartScreen/Gatekeeper warnings). An undocumented unsigned release reads as an
oversight rather than a decision.

**A decision about the glibc floor** (Linux) and the minimum macOS version. Both
are set by the *builder*, not the code, so they belong in the contract.

---

## 2. Prepare the Application for Freezing

Three things must be true before any freezer will behave.

**Resources resolve the same way frozen and unfrozen.** Every resource access
should go through one function that answers "where is my data directory", so
that a change of freeze layout is one edit. Lucio's `main.py` resolves relative
paths (`assets/`, `translations/`, `docs/`) and the build scripts put those
directories at the program root on all three platforms. That coherence is what
makes one `--add-data` destination work everywhere.

**A non-interactive entry point exists.** A CI smoke test has no display and no
user, so the program needs a mode that starts and exits:

```python
def main() -> int:
    if "--smoke-test" in sys.argv:
        return 0
    ...
```

Lucio puts those two lines **before** `QApplication` is created
(`main.py:2070-2072`). That is the mistake to avoid: the test then proves only
that Python started. Put the flag *after* the application object exists:

```python
def main() -> int:
    app = QApplication(sys.argv)
    if "--smoke-test" in sys.argv:
        # Prove the parts that actually break in a frozen bundle: the Qt
        # platform plugin, a shipped icon, and a shipped translation.
        app.setWindowIcon(load_app_icon())
        load_translation(app, "en")
        return 0
    ...
```

`[TEMPLATE — MUST BE TESTED]` — the specific calls depend on your own resource
helpers, but the placement is the point.

**Translations are compiled at build time.** Keep `.ts` in the repository and
generate `.qm` with `lrelease` during the build, so a translation fix does not
require committing a binary. Lucio does this on all three platforms
(`build/build_windows.ps1:18`, `build/build_linux.sh:25-32`,
`build/build_macos.sh:19-26`).

Note what it costs: `lrelease` comes from a Qt SDK. Lucio installs a full Qt
6.7.3 SDK on Windows just for that one executable, gets it from a distro package
on Linux, and from Homebrew on macOS. Three mechanisms for one tool is a
maintenance cost worth knowing about in advance.

---

## 3. Inventory Qt Features Before Choosing Plugins

Nuitka's `--enable-plugin=pyqt6` and PyInstaller's hooks both solve the same
problem: Qt is a set of modules plus a set of plugins, and only the ones you use
should ship.

What goes wrong when this is skipped:

- no `qwindows.dll` → `This application failed to start because no Qt platform
  plugin could be initialized`;
- no `imageformats/` → PNG icons work, SVG icons do not;
- no `platformthemes/` → the app ignores the desktop's dark theme.

Lucio's answer is the blunt one: depend on `PyQt6.QtCore`, `QtGui`, `QtWidgets`
and `QtSvg`, declare them as PyInstaller `--hidden-import`s, and let Nuitka's
plugin do the equivalent. It works, and it ships more Qt than a
`--onefile` user needs.

If size matters, Pyzo's approach in `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/pyzo-results/` (explicit module
selection, everything else excluded) is the opposite trade and is worth reading
before copying either.

---

## 4. Nuitka Strategy (Windows)

Lucio's invocation, verbatim (`build/build_windows.ps1:20-39`):

```powershell
& python -m nuitka `
  --standalone `
  --assume-yes-for-downloads `
  --remove-output `
  --msvc=latest `
  --enable-plugin=pyqt6 `
  --windows-console-mode=disable `
  --windows-icon-from-ico="$workspaceRoot\assets\app-icon.ico" `
  --company-name="Lucio" `
  --product-name="Lucio IVA Calculator" `
  --file-description="Lucio IVA Calculator" `
  --file-version="$windowsVersion" `
  --product-version="$windowsVersion" `
  --copyright="Copyright (c) 2026 ..." `
  --include-data-dir="$workspaceRoot\assets=assets" `
  --include-data-dir="$workspaceRoot\translations=translations" `
  --include-data-dir="$workspaceRoot\docs=docs" `
  --output-filename="LucioIVACalculator.exe" `
  --output-dir="$nuitkaOutputDir" `
  "$workspaceRoot\main.py"
```

### Non-obvious rules

**`--standalone`, not `--onefile`.** The installer owns the directory. A
self-extracting executable would unpack into `%TEMP%` at every launch, which is
both slower and the shape most often associated with false positives.

**Versions must be four numeric parts.** `0.1.1` makes the version resource
invalid and the build fail; `0.1.1.0` works. Derive it:

```powershell
$version = (Get-Content "$workspaceRoot\VERSION" -Raw).Trim()   # 0.1.1
$windowsVersion = "$version.0"                                   # 0.1.1.0
```

**`--include-data-dir=SOURCE=DEST`**: the destination is relative to the program
root at runtime, not to the source path. Get it wrong and the build succeeds
while the program ships without its assets.

**Nuitka needs helpers.** `ordered-set` and `zstandard` are Nuitka dependencies
for standalone/onefile work; Lucio lists them explicitly in
`build/requirements-windows.txt`, which is why its Windows job does not fail on a
fresh runner.

### What Nuitka does not buy you

A clean antivirus score is not a property of the freezer. See section 7.

---

## 5. Windows End-to-End Pipeline

```text
VERSION
  |
  v
compile translations (lrelease)
  |
  v
nuitka --standalone  ->  build/tmp/nuitka/output/*.dist/
  |
  v
copy *.dist  ->  build/dist/<AppName>/          (the payload)
copy LICENSE, icon, bitmaps alongside it
  |
  +--> Compress-Archive  ->  <AppName>-<ver>-Windows-x64-portable.zip
  |
  +--> rewrite .nsi version defines -> makensis -> <AppName>-<ver>-setup.exe
```

Two details in that diagram are worth copying and one is worth replacing.

**Copy the `.dist` tree, then locate the executable by pattern, not by name.**
Lucio searches for a `*.dist\<AppName>.exe` path (lines 41-47) rather than
hard-coding Nuitka's output directory name, which changes between versions.

**Fail if the installer was not built.** Lucio only warns (lines 67-75). In CI
NSIS is always installed via `choco install nsis -y`, but a local build can
produce a portable ZIP and exit 0 with no installer. Make it `Write-Error`.

**Replace the `.nsi` string surgery with `/D`.** See section 6.

---

## 6. Windows Installer (NSIS)

`build/LucioIVACalculator.nsi` is a good template. The parts that make it a
*correct per-user* installer:

```nsi
RequestExecutionLevel user                                   ; no UAC
InstallDir "$LOCALAPPDATA\Programs\${APP_DIR}"               ; user-writable
...
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" ...
```

Three places must agree on the install scope — execution level, install
directory, registry hive — and this script has all three consistent. A
`RequestExecutionLevel user` installer that writes `HKLM` is a classic and
confusing bug.

### Metadata on the installer itself

```nsi
VIFileVersion "${VERSION}"
VIProductVersion "${VERSION}"
VIAddVersionKey "ProductName"      "${APP_NAME}"
VIAddVersionKey "CompanyName"      "Lucio"
VIAddVersionKey "LegalCopyright"   "${COPYRIGHT}"
VIAddVersionKey "FileDescription"  "${DESCRIPTION}"
VIAddVersionKey "FileVersion"      "${VERSION}"
VIAddVersionKey "ProductVersion"   "${VERSION}"
VIAddVersionKey "InternalName"     "${APP_NAME} Installer"
VIAddVersionKey "OriginalFilename" "${INSTALLER_NAME}"
```

`VIProductVersion` needs the four-part numeric form; the display strings can be
anything. Both the application `.exe` and the installer should carry this — an
installer with no publisher and no version looks like a repack.

### Do not inject the version by replacing literals

Lucio does this (`build/build_windows.ps1:61-65`) and it is the one part of the
installer worth replacing:

```powershell
# Fragile: silently does nothing if the literal changes.
$nsiContent.Replace('!define VERSION "0.1.0.0"', "!define VERSION `"$windowsVersion`"")
```

If anyone edits that line in the `.nsi`, the replacement stops matching, the
build still succeeds, and the installer ships with the old version — including a
`DisplayVersion` in Add/Remove Programs that disagrees with the file metadata.

Pass it on the command line instead:

```nsi
; [TEMPLATE — MUST BE TESTED]
!ifndef VERSION
  !define VERSION "0.0.0.0"
!endif
!ifndef INSTALLER_NAME
  !define INSTALLER_NAME "Setup.exe"
!endif
```

```powershell
& makensis "/DVERSION=$windowsVersion" "/DINSTALLER_NAME=LucioIVACalculator-$version-setup.exe" "$nsiPath"
```

`makensis /D` defines the symbol before the script runs, so the script has no
stale defaults to keep in sync and no text to match.

### The uninstall section must remove what the install section created

Every `WriteRegStr`, `CreateShortCut` and `CreateDirectory` needs a matching
`Delete`/`RmDir` under `Section Uninstall`. Lucio's section (lines 122-130) is
complete, which is rarer than it should be.

### Keep the whole layout, not just the settings

The page count, the components page, the header and welcome bitmaps and
`XPStyle on` are not decoration. Section 6 of
`PACKAGING_STUDY.md` measures what happens when they are dropped: the same
payload, wrapped by a minimal five-page, one-section script, drew a heuristic
detection, and the faithful port of this layout did not.

Port the shape, and pin makensis to a version that has been the package default
for a while rather than to the newest release.

---

## 7. Antivirus and VirusTotal: Legitimate Practice

This section exists because the project exists because of this problem. Read it
as a checklist of what you can control, not as a technique for beating a
scanner — that is out of scope here and in the rest of this repository.

### What the evidence actually shows

Lucio records, for version 0.1.1, `0/68` for the installer and `0/65` for the
portable ZIP, and states that the previous PyInstaller builds drew generic
heuristic hits. TBO, measured in
`03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` §B.1, found Nuitka
clean and PyInstaller flagged on Windows with identical source and metadata.

Two independent signs pointing the same way, and still **not proof that the
freezer causes it**: n = 2, self-reported in one case, Windows-only, and no
vendor has said why its heuristic changed. Report it as a lead.

A third measurement, made on a sibling application on 2026-10-31 and written up
in `PACKAGING_STUDY.md` section 6, narrows the question further. Four installers
were built from one identical Nuitka payload: the three with a minimal NSIS
script were flagged by one engine, the one built with this project's layout was
not, and the portable ZIP of that payload was clean every time. That does not
make Nuitka the cause; it says the installer wrapping the payload is a variable
of its own, and it is the one this script controls.

### Things you control that plausibly matter

- **Do not pack.** No UPX, no self-extracting wrapper. Lucio has no UPX at all
  (verified by search: the string appears only in prose saying it is unused).
- **Fill in every metadata field.** Company, product, description, file version,
  product version, copyright, icon — on the application `.exe` *and* on the
  installer. Empty metadata is a weak signal; complete metadata is a strong one.
- **Sign, when you can.** The only durable fix for reputation. Lucio does not,
  and says so (`windows-exe-fixes.md:63`).
- **Ship a readable installer.** Per-user, no admin prompt, no unexpected
  network access, a visible licence page.
- **Build it like a mainstream installer.** Measured in `PACKAGING_STUDY.md`
  section 6: the same payload wrapped in a minimal NSIS script was flagged, and
  wrapped in this project's full layout it was not. Page count, components page,
  bitmaps and `XPStyle` are part of that result.
- **Publish checksums next to the files**, so a user can confirm they have what
  you built (`SHA256SUMS.txt` at release).
- **Keep the source buildable in public**, so "rebuild it yourself" is a real
  answer rather than a slogan.
- **Record the hash of what you scanned.** This is the step Lucio missed: a
  "0/68" with no hash cannot be re-checked six months later. Paste the SHA-256
  into the release notes.

### Things that do not help, or that you should not do

- Rebuilding until a specific engine stops complaining. Tuning a binary in a loop
  against a scanner's output is evasion, it is temporary, and it fixes nothing.
  There is a real difference between that and deciding once that your installer
  should look like a mainstream installer; the test is whether the change
  survives a reviewer asking "why is it like this?" without mentioning
  antivirus.
- Claiming a clean score is permanent. Engines and heuristics change; the same
  bytes can be clean today and flagged next month.
- Treating VirusTotal as an authority. It is an aggregator of third-party
  engines and issues no verdict of its own.

If you believe a result is wrong, the response is a false-positive report to the
vendor that flagged it, through their published channel.

---

## 8. Linux: PyInstaller onefile plus a Resource Gate

Lucio's Linux build is a PyInstaller `-F` (onefile) binary plus a tarball. Two
things in it are worth taking.

### The resource gate

`build/build_linux.sh:67-86` is the best idea in the project:

```bash
if command -v pyi-archive_viewer >/dev/null 2>&1; then
    pyi-archive_viewer -l "$dist_binary" > "$archive_listing"
    required_resources=(
      "assets/app-icon.svg"
      "assets/app-icon.ico"
      "docs/help_es.html"
      "docs/help_en.html"
      "translations/iva_calculator_en.qm"
    )
    for resource in "${required_resources[@]}"; do
        if ! grep -Fq "$resource" "$archive_listing"; then
            echo "Missing packaged resource in PyInstaller archive: $resource" >&2
            exit 1
        fi
    done
fi
```

It checks the **artifact that was produced**, not the command line that produced
it. That distinction is what makes it useful: a `--add-data` with the wrong
destination still builds, still runs, and silently ships without its icons.

Two improvements to make before adopting it:

1. Fail, do not skip, when `pyi-archive_viewer` is missing — otherwise the check
   disappears on exactly the machine that needs it.
2. Add the Qt platform plugin to the required list
   (`PyQt6/Qt6/plugins/platforms/qwindows.dll` on Windows, the Linux equivalent
   `libqxcb.so`), because that is the resource whose absence produces the
   `no Qt platform plugin could be initialized` crash.

### What the tarball contains

```bash
tar -C "$dist_dir" -czf "$linux_archive" \
    "LucioIVACalculator" "LucioIVACalculator.desktop" "app-icon.svg"
```

Three loose entries, no top-level folder, no `install.sh`, no `AppRun`. Extracting
it drops a binary into whatever directory the user was in — the same
"scatter" shape the Windows ZIP had. A single top-level folder and an
`install.sh` that copies the binary, the `.desktop` file and the icon into the
right places would make this a release rather than a pile of files.

---

## 9. The GLIBC Baseline Rule

A PyInstaller or Nuitka Linux binary requires at least the glibc of the machine
that built it. Build on Ubuntu 24.04 and the binary will not start on Debian 12
or on any older LTS.

Lucio knows this — `README.md:181-196` says to build on Debian 12 for exactly
this reason — and then builds on `ubuntu-latest`
(`.github/workflows/build.yml:40`), which is the failure the README warns about.

Do it deliberately:

```yaml
# [TEMPLATE — MUST BE TESTED]
build_linux:
  runs-on: ubuntu-22.04        # pin the OLDEST glibc you intend to support
```

or run the build inside a `debian:12` container. Then say which floor you chose
in the release notes, because "works on Linux" is not a specification.

---

## 10. macOS Application Bundle

```bash
pyinstaller -w -D -y \
  --name LucioIVACalculator \
  --icon "$icon_path" \
  --osx-bundle-identifier org.lucio.iva-calculator \
  --add-data "$workspace_root/assets:assets" \
  ...
ditto -c -k --sequesterRsrc "$package_dir" "$output_dir/App-macOS-x64.zip"
```

- `-D` (onedir) is what produces a `.app`. `-F` would produce a bare executable
  and no bundle.
- `ditto --sequesterRsrc` is the correct archiver for a bundle; `zip` loses
  extended attributes and resource forks.
- `iconutil -c icns` is the only supported `.icns` builder; generate the whole
  `.iconset` from your SVG first (Lucio does, in
  `scripts/create_macos_icon.py`).
- `MACOSX_DEPLOYMENT_TARGET` must be set **before** PyInstaller runs, so the
  Mach-O load commands record the right minimum.

What Lucio does **not** do — sign, harden, notarize or staple — is what decides
whether a normal user can open the app at all. That is section 11.

---

## 11. macOS Signing and Notarization

Out of scope for this project: it signs nothing. For the real procedure — the
inside-out `codesign` order, hardened runtime, entitlements, `notarytool` in CI
and `stapler` — use the `pyqt6-macos-signing-notarization` Skill and the pyzo
case study (`PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/pyzo-results/`), which implements it in CI.

The one thing to carry away from Lucio here is negative evidence: an unsigned,
unnotarized `.app` is blocked by Gatekeeper on first launch, so a release that
ships one needs to say so in the release notes.

---

## 12. Translations

```bash
# every platform, from .ts sources
for ts in translations/*.ts; do lrelease "$ts" -qm "${ts%.ts}.qm"; done
```

- Keep `.ts` in version control, generate `.qm` at build time.
- Use the same `--add-data` destination (`translations`) on every platform; a
  destination that differs per platform is a bug waiting for the one platform
  nobody tests.
- Degrade gracefully if `lrelease` is missing (`else echo "using existing .qm
  files"`), but do not let that path run in CI — install the toolchain and be
  sure.
- The Qt SDK used to *compile* translations does not have to match the Qt the app
  *ships*, but the shipped Qt must be the same on all platforms or you are
  testing a different product per platform.

---

## 13. CI Architecture: Build, Then Run What You Built

The shape worth copying, from `.github/workflows/build.yml`:

```text
unit_tests (matrix)
build_linux    -> test_linux    (download artifact, run it)
build_windows  -> test_windows  (download, silent-install, run installed; unzip, run portable)
build_macos    -> test_macos    (download, unzip, run the bundle executable)
                              -> release   (tags v* only)
```

The split matters: the `test_*` job has none of the build environment, so a
bundle that only works because of something on the builder's `PATH` fails there.

### Silent install, tested

```powershell
$process = Start-Process -FilePath $installer -ArgumentList "/S", "/D=$installDir" -Wait -PassThru
if ($process.ExitCode -ne 0) { exit $process.ExitCode }
& "$installDir\LucioIVACalculator\LucioIVACalculator.exe" --smoke-test
```

This is the single most valuable Windows check in the project: it proves the NSIS
script installs, not merely compiles.

### The version/tag check Lucio lacks

The release job derives the version from the tag (`sed 's/^v//'`) while the
artifacts are named from `VERSION`. If they disagree, the release job cannot find
its inputs and fails late. Add the check:

```yaml
# [TEMPLATE — MUST BE TESTED]
- name: Tag must match VERSION
  run: |
    test "v$(cat VERSION)" = "${{ github.ref_name }}" || {
      echo "tag ${{ github.ref_name }} does not match VERSION $(cat VERSION)" >&2
      exit 1
    }
```

### Keep the workflow cheap

`on: push:` with no filters runs seven jobs, four full platform builds and three
smoke tests on every push to every branch. Add a path filter or restrict to
`main` plus `workflow_dispatch`.

### Give write permission only where it is needed

```yaml
permissions:
  contents: read            # workflow default
jobs:
  release:
    permissions:
      contents: write       # only here
```

---

## 14. Artifact-Level Verification Checklist

Run this before publishing anything.

```text
[ ] The version in VERSION, the artifact filenames, the PE/installer metadata
    and the git tag all agree.
[ ] The workspace ZIP/tarball extracts to ONE top-level folder, or is an
    installer that installs to one. Nothing loose beside it — not even LICENSE.
[ ] Entry separators in every ZIP are forward slashes.
[ ] The application starts on a clean machine with no Python installed.
[ ] The Qt platform plugin is present: no "could not be initialized" dialog.
[ ] Every resource the app loads at startup is inside the bundle, proven by a
    check on the produced artifact (pyi-archive_viewer, or a runtime smoke test
    that actually loads one).
[ ] The installer installs silently with /S, and the installed program runs.
[ ] The uninstaller removes the files, the shortcuts and the registry key.
[ ] The portable copy runs on its own, without the installed one.
[ ] SHA256SUMS is generated from the final files and published next to them.
[ ] If you scanned anything, the SHA-256 is recorded with the result.
[ ] The release notes state the signing status and the minimum OS/glibc.
```

Two of those are worth automating because they fail silently: the ZIP layout
(`make_portable_zip.py`-style post-conditions) and the resource check.

---

## 15. Classification of Techniques

**Adopt, verified in this project**

- build → download → run, per platform;
- silent install + run in CI;
- `pyi-archive_viewer` resource gate (Linux);
- one `VERSION` file;
- per-user NSIS with `HKCU` keys;
- `ditto --sequesterRsrc`;
- keeping the rejected freezer on a branch.

**Adopt with the fix noted**

- `--smoke-test` — but after `QApplication` construction;
- `--standalone` + installer — but fail the build when NSIS is missing;
- version injection — but via `makensis /D`, not string replacement.

**Avoid**

- `>=` ranges in build requirements;
- a `.desktop` whose `Icon=` does not match the shipped file name;
- `on: push:` with no filters;
- workflow-wide write permissions;
- publishing by hand while the automated release path goes untested;
- per-platform Qt version skew with no recorded reason.

**Out of scope here**

- code signing and notarization — see the `pyqt6-windows-installer-signing` and
  `pyqt6-macos-signing-notarization` Skills;
- Debian packaging — see `my-PyQt6-Apps/TBO-resultados/`;
- AppImage — see `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/dikte-results/`.

---

## 16. Recommended Starting Architecture

```text
VERSION                          one line
main.py                          entry point with --smoke-test AFTER QApplication
build/
  requirements-windows.txt       PyQt6==X, nuitka==Y     (pinned)
  requirements-linux.txt         PyQt6==X, pyinstaller==Y
  requirements-macos.txt         PyQt6==X, pyinstaller==Y
  build_windows.ps1              nuitka --standalone -> payload -> NSIS (/DVERSION=)
  build_linux.sh                 pyinstaller -F -> resource gate -> tar.gz (one folder)
  build_macos.sh                 pyinstaller -D -> .app -> ditto
  MyApp.nsi                      per-user, HKCU, full metadata, /D inputs
  MyApp.desktop                  Icon= must equal the installed icon filename
.github/workflows/build.yml
  build_*  -> test_*  -> release (tags only)
  Jenkins-less: no secrets needed unless signing
```

Adopt the Lucio pipeline and add the five things it lacks: pinned dependencies, a
glibc-floor runner, a smoke test that reaches `QApplication`, `makensis /D`, and
a release that is only ever produced by CI.

---

## 17. What Is NOT Verified Here

Stated explicitly, because this repository requires it:

- **That Nuitka reduces antivirus detections.** Two applications, two
  self-reported scans, Windows only. A lead, not a property.
- **That this project's `0/68` and `0/65` are reproducible.** The scan artifacts
  themselves were not preserved. The SHA-256 of both files is recorded in
  `PACKAGING_STUDY.md` §6 so the claim can be re-queried — that is not the same
  as having verified it.
- **That the smoke test as written here catches a missing Qt plugin.** It would,
  if the flag were placed after `QApplication`; the placement shown in section 2
  is a template and has not been run against this project.
- **That any NSIS `/D` snippet in section 6 compiles.** It is a template.
- **The exact packaging of the 0.1.1 release.** The published assets are wrapper
  archives that no branch's script produces.
