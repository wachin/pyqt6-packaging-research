---
name: pyqt6-windows-installer-signing
description: Produce a Windows build of a PyQt6 application - onedir payload, an NSIS installer built with the layout that measured clean on VirusTotal, PE version metadata, and the correct Authenticode signing order including nested binaries and RFC 3161 timestamping.
whenToUse: Use when creating or fixing a Windows build or installer for a Python/PyQt6 application, when a Windows .exe is being flagged by antivirus engines, or when setting up Authenticode signing / SmartScreen reputation work.
---

# Windows packaging and signing for a PyQt6 application

Observed implementations: dikte and pyzo (Inno Setup installers), Lucio IVA
Calculator (NSIS installer, per-user, bilingual, with a silent-install test in
CI), napari (the only project doing real Windows Authenticode signing). Reference
files, pinned to commits:

- `dikte-resultados/_evidence/packaging/dikte.iss`
- `dikte-resultados/_evidence/packaging/build-windows.ps1`
- `pyzo-resultados/_evidence/freeze/installerBuilderScript.iss`
- `my-PyQt6-Apps/lucio-iva-calculator-resultados/_evidence/build/LucioIVACalculator.nsi`
- `my-PyQt6-Apps/lucio-iva-calculator-resultados/_evidence/build/build_windows.ps1`
- `my-PyQt6-Apps/lucio-iva-calculator-resultados/_evidence/.github/workflows/build.yml`
- `napari-packaging-resultados/_evidence/.github/workflows/make_bundle_conda.yml`

**Where this runs:** in GitHub Actions, as jobs on `windows-2025`. Nothing in this
Skill should be done on a Linux or macOS machine — Nuitka, MSVC and the installer
compiler all need Windows, and cross-building them is not a thing that works.
Workflow shape and the build/test split: `pyqt6-packaging-decisions` §6. The real
jobs: `my-PyQt6-Apps/lucio-iva-calculator-resultados/_evidence/.github/workflows/build.yml`
(`build_windows`, `test_windows`).

**Why this Skill copies Lucio's NSIS script instead of inventing one.** A
controlled test on 2026-10-31 built four installers from one identical Nuitka
payload and changed only the wrapper: the three built with a minimal script drew
a heuristic detection from one engine, and the one built with Lucio's layout was
clean. Installer size and compression did not move the verdict; the shape of the
installer did. The record is
`my-PyQt6-Apps/lucio-iva-calculator-resultados/INSTALLER_WRAPPER_EXPERIMENT.md`,
and section 4 lists what to copy.

## 1. Bundle: onedir

Ship `onedir`, not `onefile`. All three mature frozen projects do, and onefile
pays an extraction cost on every launch and hides bundle failures until runtime.
(Full reasoning: `pyqt6-packaging-decisions`.)

```python
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name='MyApp',
          console=False, upx=False, version='packaging/version_info.txt')
coll = COLLECT(exe, a.binaries, a.datas, name='MyApp', upx=False)
```

**`upx=False` everywhere.** UPX is discouraged in all modern guidance and no
project here measures any benefit. Disabling it is free; leave it disabled
consistently across every build you compare.

**Bundle size is not a constraint here.** A scanner scores the shape of the
binary, not its weight. In the controlled test of section 4 the largest installer
of the four - 43.8 MB, carrying a 92 MB payload - was the only clean one. Do not
drop assets, translations or features to chase a smaller download; it does not
address the problem.

### If you freeze with Nuitka instead

**Use Nuitka on Windows.** Both of the owner's applications do, and the only
measurements that exist point that way (`pyqt6-packaging-decisions` §4). The
observed invocation, from TBO and Lucio:

```powershell
& python -m nuitka `
  --standalone `
  --assume-yes-for-downloads `
  --remove-output `
  --msvc=latest `
  --enable-plugin=pyqt6 `
  --windows-console-mode=disable `
  --windows-icon-from-ico="assets\app-icon.ico" `
  --company-name="Your Name" `
  --product-name="MyApp" `
  --file-description="MyApp" `
  --file-version="$windowsVersion" `
  --product-version="$windowsVersion" `
  --copyright="Copyright (c) 2026 Your Name" `
  --include-package=myapp `
  --include-data-dir="assets=assets" `
  --include-data-dir="translations=translations" `
  --output-filename="MyApp.exe" `
  --output-dir="build\tmp\nuitka\output" `
  "main.py"
```

Points that decide whether this works:

- **`--standalone`, never `--onefile`.** The installer or the ZIP owns the
  directory; nothing should unpack itself into `%TEMP%` at launch.
- **`--enable-plugin=pyqt6` is not optional.** Without it the build succeeds and
  the program dies at start with *"could not find or load the Qt platform plugin
  windows"*.
- **`--include-data-dir=SOURCE=DEST`**: `DEST` is relative to the program
  directory at runtime and must match what your code resolves. A wrong `DEST`
  builds green and ships without assets — the single most common freezing bug in
  this whole research.
- **Four-part numeric versions only.** `1.2.3.dev0` aborts with `FATAL: Invalid
  version number`; sanitize to `1.2.3.0`.
- **Nuitka needs `ordered-set` and `zstandard`.** Put them in the pinned Windows
  requirements file or a bare runner fails.
- **Do not hardcode the output directory name.** Nuitka's `.dist` folder name
  changes between versions; locate the executable by pattern:

  ```powershell
  $builtExe = Get-ChildItem -Path $nuitkaOutputDir -Recurse -Filter "MyApp.exe" |
      Where-Object { $_.FullName -like "*.dist\MyApp.exe" } |
      Select-Object -First 1
  if (-not $builtExe) { throw "Nuitka output executable was not found." }
  ```

### Portable ZIP: one folder, forward slashes, verified shape

The portable artifact is a ZIP of that onedir payload. Three rules, all of which
have been broken and had to be fixed in this research:

**1. Exactly one top-level folder, named after the archive, with the licence
inside it.**

```text
BAD                          GOOD
MyApp/                       MyApp-1.2.3-Windows-x64-portable/
COPYING                        COPYING
MyApp.exe                      MyApp.exe
_internal/                     _internal/
```

An archive that unpacks a folder *and* a loose licence file reads as a
half-built download, and a folder called `MyApp` tells a user with three versions
on disk nothing.

**2. Forward-slash entry separators, or the tree collapses off Windows.**
`APPNOTE.TXT` §4.4.17.1 requires `/`. `Compress-Archive` and
`ZipFile::CreateFromDirectory` write `\` from Windows PowerShell 5.1, the
failure is invisible on Windows, and on Linux or macOS `unzip` treats `\` as an
ordinary character — 277 of 278 entries unpacked as files literally named
`MyApp\python312.dll` in the release that shipped this bug. Do not try to fix it
with a .NET API: the behaviour is behind an AppContext switch that depends on
what the *host* targets.

Build the archive somewhere you can test it, and re-read what you wrote:

```python
# [TEMPLATE — MUST BE TESTED]
def arcname(path, root, prefix=""):
    parts = path.relative_to(root).parts
    if any("\\" in p for p in parts):
        raise ValueError(f"literal backslash in a path component: {parts}")
    name = "/".join(parts)
    return f"{prefix}/{name}" if prefix else name

with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(root.rglob("*")):
        if p.is_file():
            z.write(p, arcname(p, root, prefix))

with zipfile.ZipFile(target) as z:            # post-condition, not bookkeeping
    names = z.namelist()
assert not [n for n in names if "\\" in n]
assert {n.split("/")[0] for n in names} == {prefix}
assert f"{prefix}/MyApp.exe" in names and f"{prefix}/COPYING" in names
```

The assertions are the point. A packaging step that only checks "the file was
created" will publish a nested or flat archive happily; one that reads the
archive back cannot. TBO's helper takes `--prefix` and `--require FILE` for
exactly this and refuses to ship otherwise — copy the idea even if you do not
copy the script.

**3. Stage the payload with a contents copy.** In PowerShell,
`Copy-Item $dir $dest -Recurse` with an existing `$dest` copies the *folder
into* it, producing `dest\MyApp\<files>` and, once zipped, a nested `MyApp/MyApp/`.
`Copy-Item "$dir\*" $dest -Recurse` copies the contents and is almost always what
you meant.

**Test the portable copy, not just the installer.** It is produced by a different
code path; extract it and run the executable (see section 4).

## 2. PE version metadata, from the first build

Set application identity in `version_info.txt` and mirror the same values in any
other packaging path (Nuitka flags, installer metadata):

```python
VSVersionInfo(
  ffi=FixedFileInfo(filevers=(1,0,0,0), prodvers=(1,0,0,0),
                    mask=0x3F, flags=0x0, OS=0x40004, fileType=0x1,
                    subtype=0x0, date=(0,0)),
  kids=[StringFileInfo([StringTable("040904B0", [
      StringStruct("CompanyName", "Your Name"),
      StringStruct("FileDescription", "MyApp"),
      StringStruct("FileVersion", "1.0.0.0"),
      StringStruct("ProductName", "MyApp"),
      StringStruct("ProductVersion", "1.0.0.0"),
      StringStruct("OriginalFilename", "MyApp.exe"),
  ])]), VarFileInfo([VarStruct("Translation", [0x0409, 1200])])]
)
```

Nuitka equivalent: `--file-version` and `--product-version` must be **four-part
numeric**. `1.0.0.dev0` aborts with `FATAL: Invalid version number`. Sanitize to
`1.0.0.0`, and keep the value identical across tools.

Consistent identity is part of reputation. Version numbers that disagree between
the executable, the installer and the release tag look like a repackaged binary.

## 3. Installer: Inno Setup

Inno Setup is a demonstrated installer path (dikte, pyzo): both publish working
installers, and neither publishes a VirusTotal number for one. Treat it as
"known to work", not as "known to scan clean". The path that was measured clean
is NSIS with the layout in section 4.

A per-user installer avoids requiring administrator rights:

```ini
[Setup]
AppId={{YOUR-STABLE-GUID}}
AppName=MyApp
AppVersion=1.0.0
DefaultDirName={autopf}\MyApp
PrivilegesRequired=lowest          ; per-user: no UAC prompt
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
OutputBaseFilename=MyApp-1.0.0-windows-x64-setup
LicenseFile=COPYING
SetupIconFile=packaging\windows\MyApp.ico
UninstallDisplayIcon={app}\MyApp.exe

[Files]
Source: "dist\MyApp\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\MyApp"; Filename: "{app}\MyApp.exe"
Name: "{autodesktop}\MyApp";  Filename: "{app}\MyApp.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
```

Compile with `iscc packaging\MyApp.iss`. Keep the `AppId` GUID stable forever —
changing it makes upgrades install side by side instead of replacing.

If you need a licence page, a components page and per-language UI, NSIS gives you
that with less code — and it is the path that was measured clean. Section 4.
MSI/MSIX exist but no project here produces one.

## 4. Installer: NSIS

Demonstrated and measured clean by Lucio IVA Calculator, whose installer is
published: `LucioIVACalculator-0.1.1-nuitka-setup.exe`, 30,666,770 bytes, SHA-256
`4d8cda49…f55c12`. Its `.nsi` is the reference
(`my-PyQt6-Apps/lucio-iva-calculator-resultados/_evidence/build/LucioIVACalculator.nsi`).

### The layout is the part that was measured

The directives below make the installer *correct*. They are not what made it
*clean*. A controlled test on 2026-10-31 wrapped one identical Nuitka payload in
four installers and changed nothing but the wrapper:

| makensis | Script | VirusTotal |
|---|---|---|
| 3.13.0 | minimal: MUI2, 5 pages, 1 section, no bitmaps | 1/70 `high.ml.score` |
| 3.13.0 | same, ZLIB | 1/69 `high.ml.score` |
| 3.10.0 | same, ZLIB | 1/69 `moderate.ml.score` |
| 3.12.0 | Lucio's layout: MUI v1, 6 pages, 4 sections, bitmaps, `XPStyle` | **0/67** |

The portable ZIP of that same payload was clean in every round, and the
compressor change moved the file by 8.8 MB without moving the verdict. So copy
the shape, not only the settings:

- **`!include "MUI.nsh"`**, the MUI v1 macros, not `MUI2.nsh`.
- **Six pages**: welcome, licence, components, directory, instfiles, finish. The
  components page is what makes the shortcut sections optional.
- **Four sections**: main (`SectionIn RO`), start menu, desktop, website - plus
  `Section Uninstall`.
- **Header and welcome bitmaps**: `MUI_HEADERIMAGE`, `MUI_HEADERIMAGE_RIGHT`,
  `MUI_HEADERIMAGE_BITMAP` and `MUI_WELCOMEFINISHPAGE_BITMAP`, pointing at real
  files. 24-bit BMP3, 164x314 for the welcome page and 150x57 for the header.
- **`XPStyle on`**, plus `Icon` and `UninstallIcon`.
- **The full `VIFileVersion` / `VIProductVersion` / `VIAddVersionKey` block.**

A minimal five-page, one-section installer with no bitmaps compiles, installs and
runs - and it is the one that was flagged. What the test does **not** establish is
which element did the work: the stub version and the layout changed together in
the clean round. Build the whole shape rather than picking one item from the
list.

### Per-user install: three places must agree

```nsi
RequestExecutionLevel user                                    ; 28: no UAC prompt
InstallDir "$LOCALAPPDATA\Programs\${APP_DIR}"                ; 29: user-writable
...
WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" ...  ; 95-100
```

Execution level, install directory and registry hive are one decision written
three times. An installer with `RequestExecutionLevel user` that writes `HKLM`
is a classic and confusing bug: it half-works, and then the uninstall entry is
invisible to the user who installed it.

### Installer PE metadata

NSIS has its own directives, separate from whatever the frozen `.exe` carries:

```nsi
VIFileVersion "${VERSION}"
VIProductVersion "${VERSION}"        ; four numeric parts, like Nuitka's flags
VIAddVersionKey "ProductName"      "${APP_NAME}"
VIAddVersionKey "CompanyName"      "Your Name"
VIAddVersionKey "LegalCopyright"   "${COPYRIGHT}"
VIAddVersionKey "FileDescription"  "${DESCRIPTION}"
VIAddVersionKey "FileVersion"      "${VERSION}"
VIAddVersionKey "ProductVersion"   "${VERSION}"
VIAddVersionKey "InternalName"     "${APP_NAME} Installer"
VIAddVersionKey "OriginalFilename" "${INSTALLER_NAME}"
```

**Verified on the published artifact**, by parsing the installer's
`RT_VERSION` resource: `VS_FIXEDFILEINFO` reads `FileVersion=0.1.1.0` and
`ProductVersion=0.1.1.0`, and all eight string keys above are present, with
`OriginalFilename = LucioIVACalculator-0.1.1-nuitka-setup.exe`. So these
directives are not decoration — they are what Explorer's Properties dialog and
the reputation heuristics read.

The same artifact is **unsigned**: its Authenticode security directory is empty
(offset 0, size 0). Metadata is not a signature, and section 5 still applies.

### Do not inject the version by replacing literals

Lucio's build driver does this (`build_windows.ps1:61-65`):

```powershell
# Fragile: silently does nothing if the literal in the .nsi changes.
$nsiContent.Replace('!define VERSION "0.1.0.0"', "!define VERSION `"$windowsVersion`"")
```

Three such replacements cover `VERSION`, `INSTALLER_NAME` and the
`DisplayVersion` registry line. If anyone edits the template, the replacement
stops matching, the build still succeeds, and the installer ships carrying the
old version — with a `DisplayVersion` in Add/Remove Programs that disagrees with
the file metadata. The template can never be correct on its own, because it has
to keep a stale default for the replacement to match.

Pass the values on the command line instead:

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
& makensis "/DVERSION=$windowsVersion" "/DINSTALLER_NAME=MyApp-$version-setup.exe" "$nsiPath"
if ($LASTEXITCODE -ne 0) { throw "makensis failed with exit code $LASTEXITCODE" }
```

`makensis /D` defines the symbol before the script is read, so there is no text
to match and no stale default to keep in sync.

### Fail loudly when the compiler is missing

Lucio warns and continues (`build_windows.ps1:67-75`): a local build with no
NSIS on `PATH` produces only the portable ZIP and exits 0. In CI it is always
present (`choco install nsis -y`), but a local release can quietly ship without
its installer. Make the missing compiler an error.

### The uninstall section mirrors the install section

Every `WriteRegStr`, `CreateShortCut` and `CreateDirectory` needs a matching
`Delete` / `RmDir`. Lucio's `Section Uninstall` removes the tree, three
shortcuts, the Start Menu folder and the registry key. Half-done uninstallers are
common and they are what leaves entries pointing at deleted files.

### Language selection

```nsi
Function .onInit
  System::Call "kernel32::GetUserDefaultUILanguage() i .r0"
  IntOp $1 $0 & 0x3ff          ; strip the sub-language bits
  IntCmp $1 9 0 +2 +2          ; 9 = English
    StrCpy $LANGUAGE ${LANG_ENGLISH}
  IntCmp $1 10 0 +2 +2         ; 10 = Spanish
    StrCpy $LANGUAGE ${LANG_SPANISH}
FunctionEnd
```

The mask is the important part: `GetUserDefaultUILanguage` returns a LANGID
where the low 10 bits are the primary language. Compare the masked value, not
the raw one. Note the limitation — only the two languages are handled, so any
other locale keeps whatever `$LANGUAGE` was left at. That is acceptable for two
languages and wrong for twelve.

### Compressor: ZLIB, and it is not the lever

`SetCompressor ZLIB` (line 22). Keep it, because it is what the reference used,
but do not expect a compressor change to fix a detection: the same payload built
with solid `LZMA` and with `ZLIB` scored identically, and the difference was
8.8 MB of installer size and nothing else. Installer size is not what a scanner
scores.

### Pin the compiler version

The stub that `makensis` embeds is part of the binary a scanner sees, and its
version is not neutral. Measured on one payload: 3.13.0 produced
`Malicious.high.ml.score`, 3.10.0 the same installer at `moderate`, and 3.12.0
with this script's layout was clean. `choco install nsis -y` installs whatever
is current, so pin it and print the version in the CI log:

```powershell
choco install nsis --version=3.12.0 -y --no-progress
& "C:\Program Files (x86)\NSIS\makensis.exe" /VERSION
```

Prefer a release that has been the package default for a while over the newest
one. This is a measured difference, not a guarantee.

### Test the installer, not just the compile

This is the part worth copying from Lucio, in CI
(`.github/workflows/build.yml:150-200`):

```powershell
$process = Start-Process -FilePath $installer -ArgumentList "/S", "/D=$installDir" -Wait -PassThru
if ($process.ExitCode -ne 0) { exit $process.ExitCode }
& "$installDir\LucioIVACalculator\LucioIVACalculator.exe" --smoke-test
```

`/S` is silent; `/D=` sets the destination, and NSIS requires that value to be
**the last parameter and unquoted** — the installer takes the rest of the command
line literally. Lucio's CI passes a runner path with no spaces, so the
combination with PowerShell's own argument quoting is not exercised there: if
your destination can contain a space, test it before believing it.

Running the installed executable afterwards is what proves the payload arrived
intact; a compile-only check proves none of that, and neither does a nonzero-exit
check on the installer itself.

Test the portable archive as its own case — it is produced by a different code
path:

```powershell
Expand-Archive -Path $portableZip -DestinationPath $portableDir
& "$portableDir\LucioIVACalculator\LucioIVACalculator.exe" --smoke-test
```

A note on what `--smoke-test` proves: in Lucio it returns **before**
`QApplication` is constructed (`main.py:2070-2072`), so it verifies that the
executable starts and the Python runtime loads — not that Qt's platform plugin
or the shipped resources are present. Put the flag after `QApplication` and load
one icon and one translation before returning, or the test will pass on a bundle
that cannot open a window.

## 5. Signing order

Sign **after** building, and sign the installer **after** compiling it. The
order matters and skipping it produces a partially signed tree that still
triggers warnings.

| Step | Command |
|---|---|
| 1. Sign nested binaries first | `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f cert.pfx /p "$PASS" MyApp.dll` |
| 2. Sign the main executable | same, for `MyApp.exe` |
| 3. Verify every signature | `signtool verify /pa /v MyApp.exe` |
| 4. Compile the installer | `iscc packaging\MyApp.iss` |
| 5. Sign the installer | same sign command, on `MyApp-...-setup.exe` |
| 6. Verify again | `signtool verify /pa /v MyApp-...-setup.exe` |

Points that are easy to get wrong:

- Use `/fd SHA256` (file digest) and `/td SHA256` (timestamp digest). The legacy
  defaults produce weak or rejected signatures.
- `/tr` with an RFC 3161 timestamp server is required. Without a timestamp the
  signature becomes invalid when the certificate expires — including for
  already-released binaries.
- Sign **before** you hash and publish. If you publish a SHA-256 and then sign,
  the hash is wrong.
- Never hardcode the certificate or its password. Use CI secrets and a temporary
  file that you delete afterwards.

## 6. What signing does and does not do

Established by napari's own workflow comments:

- Signing is **the** legitimate reputation mechanism, and the reason serious
  projects sign.
- Signing does **not** guarantee a clean VirusTotal result.
- An **untrusted** signature does not even remove SmartScreen warnings. napari's
  documented stopgap — signing with an Apple certificate while a proper Windows
  certificate was unavailable — still produced warnings. Do not treat any
  signature as better than none.

Windows signing is the **largest shared gap** in the case studies: CARA,
CustomKnight-Creator, dikte, pyzo and Lucio IVA Calculator all ship unsigned
Windows artifacts. Lucio's is measurable rather than asserted — the published
installer's Authenticode security directory is empty — and it is the clearest
example in this research of a project that did everything else right (complete
metadata, no packing, a per-user installer, a tested silent install) and still
had to switch freezer to get a clean scan.

## 7. What is and is not verified here

**Measured (2026-10, one application):** the same code, version and PE metadata,
unsigned, UPX disabled in every arm. **Nuitka 0/71. PyInstaller 3/73 in *both*
onedir and onefile**, so `onedir` was no protection at all.

Read the detections rather than the count. They were a generic `Malicious` with no
family named, a behavioural `BehavesLike.…`, and script-trojan names with no known
family; two engines flagged both PyInstaller arms while the third differed; and
**every major engine reported clean** — Microsoft, Kaspersky, BitDefender, ESET,
Sophos, Avast, Google, Fortinet, CrowdStrike, Palo Alto, Symantec, Trend Micro,
SentinelOne. That shape is generic heuristic false positives.

So for that application the freezer was the differentiator, and 3/73 with the
majors clean does **not** by itself justify abandoning PyInstaller. It is n = 1.

**Measured on Lucio IVA Calculator's NSIS installer:** the `RT_VERSION` resource
carries `FileVersion`/`ProductVersion` `0.1.1.0` and the eight string keys listed
in section 4; the Authenticode directory is empty, so it is unsigned. Those two
facts are read from the published bytes, not from the project's prose.

**Not verified:**

- Any trend over time, or behaviour for another application. Bundle contents
  drive heuristics.
- That signing reduces detection counts — but signing is the reputation lever the
  research does support, and none of these arms was signed, so it remains the
  first thing to try.
- **That the NSIS uninstaller removes everything.** Lucio's `Section Uninstall`
  looks complete and was read, but no CI job runs an uninstall and checks the
  result. Verify it by hand on a VM.
- **The `makensis /D` recipe in section 4.** It has been compiled and run since
  this audit, in a port of Lucio's script to another application, but not in the
  exact template form printed here.
- **Which element of the installer layout did the work.** The stub version and
  the script shape changed together in the round that came back clean. The
  experiment that would separate them is written down in
  `my-PyQt6-Apps/lucio-iva-calculator-resultados/INSTALLER_WRAPPER_EXPERIMENT.md`
  and has not been run.
- **That a clean result survives a rebuild or a new NSIS release.** Scores are
  point-in-time. Re-scan before publishing a claim.
- **The `.onInit` language fallback for locales other than English and Spanish.**
  Untested.

If antivirus behaviour matters for your application, measure it rather than argue
it: `experiments/pyinstaller-vs-nuitka/` in this repository. Interpret a
VirusTotal score as a point-in-time signal to investigate, never as a verdict —
and never respond to a false positive with obfuscation, packing or binary
mutation. Submit a vendor report instead.

## 8. Checklist

- [ ] onedir bundle, `upx=False`.
- [ ] PE version metadata present and consistent with the installer and the tag.
- [ ] Installer PE metadata present too — Inno writes it from `[Setup]`, NSIS from
      `VIFileVersion`/`VIAddVersionKey`, and neither inherits the frozen `.exe`'s.
- [ ] The installer uses the reference layout (6 pages, 4 sections, header and
      welcome bitmaps, `XPStyle on`), not a minimal script.
- [ ] `makensis` is pinned to a release that has been the package default for a
      while, and its version is printed in the CI log.
- [ ] Installer compiles, installs, launches, and uninstalls cleanly on a clean
      Windows VM with no Python or Qt installed.
- [ ] CI installs silently (`/S` for NSIS, `/SILENT` for Inno) and then runs the
      installed executable.
- [ ] The portable archive, if you ship one, is tested separately from the
      installed copy.
- [ ] The version is passed to the installer compiler as a parameter
      (`/DVERSION=`, `iscc /D…`), not by rewriting the script.
- [ ] Every nested binary signed, then the installer, with SHA-256 and RFC 3161.
- [ ] Published SHA-256 matches the **signed** bytes.
- [ ] The **installer** was scanned on VirusTotal and its hash recorded. A clean
      portable ZIP says nothing about the installer, and the payload is not what
      is being scored.
- [ ] Source URL published for false-positive reports.

## Related

- Model choice: `pyqt6-packaging-decisions`
- Publish hashes and provenance: `pyqt6-release-integrity`
