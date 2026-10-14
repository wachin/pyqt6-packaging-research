---
name: pyqt6-windows-installer-signing
description: Produce a Windows build of a PyQt6 application - onedir + Inno Setup installer, PE version metadata, and the correct Authenticode signing order including nested binaries and RFC 3161 timestamping.
whenToUse: Use when creating or fixing a Windows build or installer for a Python/PyQt6 application, or when setting up Authenticode signing / SmartScreen reputation work.
---

# Windows packaging and signing for a PyQt6 application

Observed implementations: dikte and pyzo (Inno Setup installers), napari (the
only project doing real Windows Authenticode signing). Reference files, pinned
to commits:

- `dikte-resultados/_evidence/packaging/dikte.iss`
- `dikte-resultados/_evidence/packaging/build-windows.ps1`
- `pyzo-resultados/_evidence/freeze/installerBuilderScript.iss`
- `napari-packaging-resultados/_evidence/.github/workflows/make_bundle_conda.yml`

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

Inno Setup is the demonstrated installer path (dikte, pyzo). A per-user
installer avoids requiring administrator rights:

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

Alternatives: NSIS and MSI/MSIX exist and are used elsewhere (napari's conda
toolchain produces NSIS installers), but Inno is the one with real precedent for
a PyQt6 application here.

## 4. Signing order

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

## 5. What signing does and does not do

Established by napari's own workflow comments:

- Signing is **the** legitimate reputation mechanism, and the reason serious
  projects sign.
- Signing does **not** guarantee a clean VirusTotal result.
- An **untrusted** signature does not even remove SmartScreen warnings. napari's
  documented stopgap — signing with an Apple certificate while a proper Windows
  certificate was unavailable — still produced warnings. Do not treat any
  signature as better than none.

Windows signing is the **largest shared gap** in the case studies: CARA,
CustomKnight-Creator, dikte and pyzo ship unsigned Windows artifacts.

## 6. What is and is not verified here

**Measured (2026-10, one application):** the same code, version and PE metadata,
unsigned, UPX disabled in every arm. Both PyInstaller builds — onedir *and*
onefile — were flagged by VirusTotal; the Nuitka build was not. So for that
application the freezer was the differentiator, and **`onedir` was no protection
at all**. It is n = 1 with no detection counts recorded: report it as a lead, not
a rule.

**Not verified:**

- Detection *rates*, or which engines and categories were involved.
- That signing reduces detection counts.
- That this transfers to another application. Bundle contents drive heuristics.

If antivirus behaviour matters for your application, measure it rather than argue
it: `experiments/pyinstaller-vs-nuitka/` in this repository. Interpret VirusTotal
as a point-in-time signal to investigate, never as a verdict — and never respond
to a false positive with obfuscation, packing or binary mutation.

## 7. Checklist

- [ ] onedir bundle, `upx=False`.
- [ ] PE version metadata present and consistent with the installer and the tag.
- [ ] Installer compiles, installs, launches, and uninstalls cleanly on a clean
      Windows VM with no Python or Qt installed.
- [ ] Every nested binary signed, then the installer, with SHA-256 and RFC 3161.
- [ ] Published SHA-256 matches the **signed** bytes.
- [ ] Source URL published for false-positive reports.

## Related

- Model choice: `pyqt6-packaging-decisions`
- Publish hashes and provenance: `pyqt6-release-integrity`
