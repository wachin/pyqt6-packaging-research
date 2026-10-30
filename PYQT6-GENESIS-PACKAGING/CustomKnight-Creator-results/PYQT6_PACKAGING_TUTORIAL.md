# PyQt6 Cross-Platform Packaging Tutorial

> A practical, reusable guide for building and distributing PyQt6 desktop applications on **Windows**, **Linux**, and **macOS**.
>
> This tutorial is derived from a deep study of the open-source project **CustomKnight Creator** (github.com/cmot17/CustomKnight-Creator), which packages a small PyQt6 app with PyInstaller on GitHub Actions. Where a recommendation comes directly from that repository, it is marked **[from this repo]**. Everything else is **general industry guidance** from packaging-tool documentation and well-established practice, and is marked accordingly.
>
> **Key disclaimer:** This tutorial contains command examples and YAML fragments. Treat them as starting templates. Verify them in your own environment. The original repository uses PyInstaller 5.1 / PyQt6 6.3.1 / Python 3.10 — I recommend newer versions (PyInstaller ≥ 6, PyQt6 ≥ 6.7) for a new project.

---

## Table of Contents

1. [Understanding the Problem](#1-understanding-the-problem)
2. [Recommended High-Level Architecture](#2-recommended-high-level-architecture)
3. [Preparation That Solves Packaging Later](#3-preparation-that-solves-packaging-later)
4. [Windows: End-to-End Pipeline](#4-windows-end-to-end-pipeline)
5. [Antivirus False Positives: A Realistic Guide](#5-antivirus-false-positives-a-realistic-guide)
6. [PyInstaller Deep Guide](#6-pyinstaller-deep-guide)
7. [Nuitka as an Alternative](#7-nuitka-as-an-alternative)
8. [Linux: AppImage](#8-linux-appimage)
9. [Linux: Debian `.deb` Package](#9-linux-debian-deb-package)
10. [macOS: `.app`, Signing, Notarization, DMG](#10-macos-app-signing-notarization-dmg)
11. [Qt Plugins and Translations](#11-qt-plugins-and-translations)
12. [GitHub Actions Pipeline](#12-github-actions-pipeline)
13. [Checksums, Integrity, and Release Hygiene](#13-checksums-integrity-and-release-hygiene)
14. [Testing Your Packages](#14-testing-your-packages)
15. [Appendix: Reusable Templates](#appendix-reusable-templates)

---

## 1. Understanding the Problem

From studying CustomKnight Creator, the biggest lesson is what a *minimal* PyInstaller pipeline looks like and what it is missing:

- **[from this repo]** A GitHub Actions matrix (`windows-latest`, `ubuntu-latest`, `macos-latest`) running `pyinstaller main.py -F -w -n ... --add-data resources:resources` is enough to *produce* three platform artifacts.
- **[from this repo]** That alone is **not** a professional distribution: no signing, no installers, no AppImage/`.deb`/DMG, no checksums, no release automation, and (in the released versions) outdated dependencies.

The tutorial below upgrades that minimal pipeline into a complete one. Every section gives you: the target pipeline, real commands, and the reasons behind each step.

---

## 2. Recommended High-Level Architecture

```text
                         Git tag (v1.2.0)
                              │
                 ┌────────────┼─────────────┐
                 │            │             │
             Windows       Linux         macOS
                 │            │             │
      PyInstaller/Nuitka   Nuitka/PyI     Nuitka/PyI
                 │            │             │
      onedir or onefile   standalone     standalone
                 │            │             │
      version metadata  AppDir build     .app bundle
                 │            │             │
      code sign exe    AppImage + .deb     codesign (hardened runtime)
                 │            │             │
      Inno Setup installer                 notarization
                 │            │             │
      sign installer                       staple
                 │            │             │
                 │            │        DMG creation
                 └────────────┼─────────────┘
                              │
                     SHA256 checksums
                              │
                        GitHub Release
                              │
                   (attachments + release notes)
```

This is the target. The sections below walk through each branch.

---

## 3. Preparation That Solves Packaging Later

Before touching a packager, make these decisions — they are the most expensive to change later.

### 3.1 Project layout

Keep resources and data **separate from code**, and never rely on `cwd`:

```
myapp/
├── main.py                  # entry point
├── myapp/
│   ├── __init__.py
│   ├── gui.py
│   └── logic.py
├── resources/
│   ├── icons/*.png
│   ├── app.ico              # Windows
│   ├── app.icns             # macOS
│   └── data/*.json
├── requirements.txt         # or pyproject.toml
├── packaging/
│   ├── linux/myapp.desktop
│   └── windows/app.iss      # Inno Setup
└── .github/workflows/
    └── release.yml
```

**[from this repo]** CustomKnight Creator uses a flat layout with a `resources/` dir and resolves data with `os.path.join(os.path.dirname(__file__), "resources", ...)`. That works for PyInstaller because `__file__` points inside the bundle. It is a valid, simple pattern — but see 3.2 for the more explicit, tool-agnostic version.

### 3.2 Resource-finding helper (make it explicit)

Write one helper used everywhere:

```python
import sys, os

def resource_path(relative: str) -> str:
    """Return an absolute path to a bundled resource, works in dev AND frozen."""
    base = getattr(sys, "_MEIPASS", None)       # PyInstaller onefile temp dir
    if base is None:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root (dev)
    return os.path.join(base, relative)
```

Usage: `QPixmap(resource_path("resources/icons/check.png"))`, `open(resource_path("resources/data/map.json"))`.

- **[from this repo]** The studied project uses `os.path.dirname(__file__)` instead of `sys._MEIPASS`; both work under PyInstaller, but `_MEIPASS` is the documented, explicit mechanism and also composes with Nuitka's `__compiled__`/`sys.frozen` handling.
- **General**: For Nuitka, `sys.frozen` and `__compiled__` are also set; a helper checking `sys.frozen` covers both tools. Keep data *next to the executable* for onedir, or inside the bundle for onefile.

### 3.3 Choose and pin your versions

- Decide the **minimum Python** and the **oldest glibc / oldest distro** you support (see Linux section). For new work: Python 3.11–3.13, PyQt6 ≥ 6.7, PyInstaller ≥ 6.7 (or Nuitka ≥ 2.x).
- **Pin your toolchain** so a rebuild today == a rebuild next year:
  - `requirements.txt` with exact `==` pins **[from this repo]**, or better:
  - `pyproject.toml` with a lockfile (e.g. `uv lock`, `pip-tools` → `requirements.lock`, or `pdm.lock`).
  - Pin CI actions to commit SHAs (see §12).

### 3.4 Qt binding choice: PyQt6 vs PySide6

- **[from this repo]** The project uses **PyQt6** on the released branches; an abandoned `cleanup` branch tried **PySide6** and was never released — no conclusion can be drawn from the repository about which is better.
- **General**: Both are viable. PySide6 is the official Qt for Python binding (LGPL, permissive licensing — often easier for commercial apps); PyQt6 is GPL/commercial. Packaging-wise both have mature PyInstaller hooks. **Pick one and don't mix.** For an open-source GPL app either is fine.

---

## 4. Windows: End-to-End Pipeline

```text
PyQt6 source
    ↓
virtual environment
    ↓
pip install dependencies (pinned)
    ↓
PyInstaller (onedir recommended)  →  dist/MyApp/
    ↓
Windows version metadata (--version-file)
    ↓
Authenticode code sign the exe  (signtool / osslsigncode)
    ↓
Inno Setup installer (packages dist/MyApp/)
    ↓
sign the installer
    ↓
VirusTotal sanity check (informational)
    ↓
SHA256 checksum
    ↓
attach to GitHub Release
```

### 4.1 Virtual environment (per build)

```bash
python -m venv .venv-build
source .venv-build/bin/activate        # Windows: .venv-build\Scripts\activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller
```

### 4.2 Build

**Onedir (recommended for Windows)** — a folder of files; faster startup, fewer AV false positives, easier to sign individual DLLs if needed:

```bash
pyinstaller main.py \
  --name MyApp \
  --onedir \
  --windowed \
  --icon resources/app.ico \
  --add-data "resources;resources" \
  --version-file packaging/windows/version_info.txt \
  --clean --noconfirm
```

**Onefile** (single exe; convenient, but slower startup, more AV-false-positive-prone) — **[from this repo]** the studied project ships exactly this mode:

```bash
pyinstaller main.py -F -w -n MyApp -i resources/app.ico --add-data "resources;resources"
```

> Recommendation **[general]** : prefer **onedir** for Windows distribution unless you have a strong need for a single file. If you need single-file, prefer a signed **installer** around an onedir build — users get one file to download, and the app inside behaves like a normal onedir app.

**Generate a `.spec` file** once and commit it (rather than long CLI lines): run the command once, edit `MyApp.spec`, then build with `pyinstaller MyApp.spec`. This also lets you set `exclude`, `hiddenimports`, `binaries`, and UPX policy explicitly.

### 4.3 Windows version metadata

PyInstaller gives a default version resource. To embed *your* product name, version, company, copyright (helps AV engines and users identify the file), create `version_info.txt`:

```
VSVersionInfo(
  ffi=FixedFileInfo(filevers=(1, 2, 0, 0), prodvers=(1, 2, 0, 0),
    mask=0x3f, flags=0x0, OS=0x40004, fileType=0x1, subtype=0x0,
    date=(0, 0)),
  kids=[StringFileInfo([StringTable('040904B0', [
    StringStruct('CompanyName', 'Your Name or Org'),
    StringStruct('FileDescription', 'MyApp'),
    StringStruct('FileVersion', '1.2.0.0'),
    StringStruct('InternalName', 'MyApp'),
    StringStruct('LegalCopyright', '© 2026 You'),
    StringStruct('OriginalFilename', 'MyApp.exe'),
    StringStruct('ProductName', 'MyApp'),
    StringStruct('ProductVersion', '1.2.0')])]),
  VarFileInfo([VarStruct('Translation', [1033, 1200])])]
)
```

Pass with `--version-file packaging/windows/version_info.txt`.

### 4.4 Code signing (Windows)

> This is the single most effective legitimate measure for SmartScreen and AV reputation. It does **not** guarantee zero detections.

- **[from this repo]** The studied project does **no** signing. Nothing to copy — do the opposite.
- **General**:
  - Obtain an **OV code-signing certificate** (e.g., from a commercial CA). EV certificates are stronger (immediate SmartScreen reputation) but cost more and require a hardware token. For a hobby project OV is the practical choice.
  - Sign **both** the app executable and the installer.
  - Always **timestamp** so the signature stays valid after the cert expires.
  - On Windows you can sign with `signtool` (from the Windows SDK / Visual Studio Build Tools):
    ```bat
    signtool sign /fd SHA256 /a ^
      /f MyCert.pfx /p "PFX_PASSWORD" ^
      /tr http://timestamp.digicert.com /td SHA256 ^
      dist\MyApp\MyApp.exe
    ```
  - In CI, store the PFX (base64-encoded) in a GitHub Secret and decode it in the workflow (see §12). **Never commit the PFX.**
  - **Open-source note**: signing certs cost money. As a free alternative for open-source, consider **Azure Trusted Signing** (Microsoft's service for signing with identity validation; free tier exists for OSS), or document clearly that your binaries are unsigned and ship checksums. Be honest with users about what signing status means.

### 4.5 Installer: Inno Setup (recommended)

- **[from this repo]** No installer exists; the project ships a ZIP of the exe. For a professional result, add one.
- **General — Inno Setup** (free, scriptable, includes uninstaller, supports signing):

Create `packaging/windows/installer.iss`:

```ini
#define MyAppName "MyApp"
#define MyAppVersion "1.2.0"
#define MyAppExeName "MyApp.exe"

[Setup]
AppId={{8F1E2C3D-...-GUID}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\..\dist-installer
OutputBaseFilename=MyApp-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
; Signing happens in CI AFTER compilation with signtool
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "..\..\dist\MyApp\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
```

Build from a Windows shell:

```bat
ISCC.exe packaging\windows\installer.iss
signtool sign /fd SHA256 /f MyCert.pfx /p "PFX_PASSWORD" ^
  /tr http://timestamp.digicert.com /td SHA256 ^
  dist-installer\MyApp-Setup-1.2.0.exe
```

### 4.6 Alternatives

- **NSIS**: free, script-based, popular; fewer built-in niceties than Inno.
- **WiX Toolset / MSI**: enterprise-style; MSI is what "Install with a package manager" implies; higher learning curve. Suitable if you must provide `.msi`.
- **MSIX**: modern store format; needs signing identity and works best with the Microsoft Store / App Installer. More friction for a hobby OSS project.

**Recommendation [general]**: Inno Setup for OSS PyQt6 apps — free, reliable, produces a proper setup + uninstaller, easy to sign, and users understand `.exe` setup files.

---

## 5. Antivirus False Positives: A Realistic Guide

You asked specifically about false positives with PyInstaller (many) vs Nuitka (fewer). Here is the honest, evidence-based picture:

### 5.1 What is known / likely

1. **Unsigned, freshly-signed, or low-reputation executables get flagged** more often than signed ones with history. **Signing is the strongest controllable factor.**
2. **Onefile PyInstaller** executables embed the whole app (Python + Qt + bytecode) in an archive inside a bootloader that self-extracts at runtime. To heuristic AV engines this *looks* like a packer/crypter. **[from this repo]** the studied project ships exactly this (unsigned, onefile) and offers no mitigation data.
3. **UPX compression** (PyInstaller's optional UPX support) is associated with *more* detections and is commonly disabled in modern guidance. **[from this repo]** the project never configured UPX; on GitHub Actions runners UPX is absent, so CI builds were uncompressed — but that was **not a deliberate choice** (an early `.spec` had `upx=True`).
4. **Nuitka standalone output is compiled native code** with a different binary profile (no embedded bytecode blob, no runtime self-extraction in the same way). The community reports fewer detections. **Correlation, not causation** — some Nuitka builds also get flagged, and no tool guarantees 0 detections.
5. **Reputation takes time**: even a signed exe can be flagged early until it accumulates "clean" samples and downloads (SmartScreen reputation). VirusTotal results are snapshots, not a certification.

### 5.2 Legitimate mitigation stack (do all of these)

- Build in a **clean, reproducible environment** (CI with pinned versions) so binaries are predictable.
- Use **current, stable packaging tools** (avoid years-old PyInstaller like the studied project's 5.1 — use ≥6.x or current Nuitka).
- **Do not use UPX** (explicitly pass `--noupx` if you keep it on PATH, or just don't install UPX).
- Prefer **onedir** over onefile where UX allows.
- **Code sign** with a real certificate and **timestamp**.
- Set **correct version/product metadata** (see 4.3).
- **Transparent source**: keep the repo public, tag releases, reference the tag in release notes.
- Publish **SHA256 checksums** for every asset.
- Submit confirmed false positives to the specific vendor(s) via their portals (Microsoft Security Intelligence, Kaspersky, Malwarebytes, etc.) — include the detection hash and explain it's a PyInstaller/Nuitka PyQt6 app with a link to the repo.

### 5.3 Honest expectations

- VirusTotal **cannot** be zero-guaranteed. Treat a "2–4 detections, all heuristics, none behavioral" result as normal for unsigned PyInstaller; aim to reduce it, don't chase zero.
- The user's Nuitka-vs-PyInstaller experience is plausible; if detections persist after signing + onedir + current PyInstaller, **evaluating Nuitka standalone is a reasonable experiment** (see §7). If that also gets flagged, the issue is reputation/time, not the tool.

---

## 6. PyInstaller Deep Guide

### 6.1 Modes

| Mode | Flag | Behavior | Good for |
|---|---|---|---|
| onedir | `--onedir` (default) | Folder with exe + `_internal/` | Fast startup, easier AV profile, easy to add extra files |
| onefile | `--onefile` (`-F`) | Single exe, extracts to temp each run | Sharing one file; **[from this repo]** what the studied project uses |

### 6.2 Common options you'll actually use

```bash
pyinstaller MyApp.spec
# or
pyinstaller main.py \
  --name MyApp --onedir --windowed \
  --icon resources/app.ico \
  --add-data "resources;resources" \
  --version-file version_info.txt \
  --collect-data PyQt6.QtCore     # translations etc. if needed (see §11)
  --exclude-module PyQt6.QtWebEngineWidgets \
  --noupx
```

- `--add-data "src;dest"` (Windows separator `;`) / `"src:dest"` (POSIX) — bundle a file or directory. **[from this repo]** `--add-data resources:resources`.
- `--collect-data`, `--collect-submodules`, `--collect-binaries` — pull extra data from a package (used for Qt translations).
- `--hidden-import` / `--exclude-module` — fix dynamic imports / slim the bundle.
- `--windowed`/`--noconsole` — no console (Windows/macOS). **[from this repo]** the Linux build omits `-w`, keeping a console.
- `--noupx` — disable UPX explicitly (recommended, §5).
- `--clean --noconfirm` — clean rebuild without prompts (CI-friendly).
- `--log-level=WARN` — more insight during build.

### 6.3 The `.spec` file (onefile, PyInstaller 6.x)

Generated spec (`MyApp.spec`), annotated:

```python
# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['main.py'],                      # entry script(s)
    pathex=[],                        # extra import search paths
    binaries=[],                      # external binaries to bundle
    datas=[('resources', 'resources')],  # (source, dest) data files  <-- [from this repo]
    hiddenimports=[],                 # add modules PyInstaller can't see
    hookspath=[],                     # custom hook dirs
    hooksconfig={},
    runtime_hooks=[],                 # scripts run before your app (e.g. set QT_QPA_PLATFORM_PLUGIN_PATH)
    excludes=[],                      # drop modules: ['PyQt6.QtWebEngineWidgets']
    noarchive=False,                  # keep the PYZ archive (True = separate .pyz)
    optimize=0,
)
pyz = PYZ(a.pure)                     # compressed bytecode archive

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,                       # onedir would use exclude_binaries=True here
    a.datas,
    [],
    name='MyApp',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,                      # strip debug info (Unix)
    upx=False,                        # <-- deliberately disable UPX [general recommendation]
    upx_exclude=[],
    runtime_tmpdir=None,              # onefile: where the temp dir lives (None = default)
    console=False,                    # False = windowed  <-- [from this repo] windowed on Win/mac
    disable_windowed_traceback=False,
    argv_emulation=False,             # macOS: receive Finder Open events
    target_arch=None,                 # macOS: 'x86_64' | 'arm64' | 'universal2'
    codesign_identity=None,           # macOS: sign the bundle
    entitlements_file=None,           # macOS: hardened runtime entitlements
    icon=['resources/app.ico'],       # Windows icon; icns for macOS <-- [from this repo] uses icns/ico
)
```

For onefile, `EXE(...)` gets `a.binaries, a.datas` directly (everything embedded). For **onedir**, you instead pass `exclude_binaries=True` to `EXE` and feed them to `COLLECT`. For **macOS**, add:

```python
app = BUNDLE(
    exe,
    name='MyApp.app',
    icon='resources/app.icns',
    bundle_identifier='com.example.myapp',   # <-- set this [general recommendation]
)
```

### 6.4 Debugging a broken frozen app

- Build with `--log-level=WARN`; read the warnings for "hidden import" and missing modules.
- If the app crashes at startup, run the **console** build (`console=True`) to see the traceback — **[from this repo]** the Linux build keeps the console, which made user tracebacks visible in issues; that is a *debugging convenience*, but end users on Windows/macOS get `--windowed`.
- For missing Qt plugin errors (e.g., "could not find or load the Qt platform plugin 'windows'"): you forgot Qt platform plugins; re-run and verify `Qt6/plugins/platforms` is present. In rare cases set `QT_QPA_PLATFORM_PLUGIN_PATH` via a runtime hook.

---

## 7. Nuitka as an Alternative

### 7.1 When to consider it

- Persistent AV false positives with PyInstaller (your situation) **[general]**.
- You want compiled (harder-to-reverse) native code.
- Startup-time sensitivity.

### 7.2 Basic usage (standalone, onedir-like)

```bash
# Windows (needs MSVC Build Tools on PATH)
python -m pip install nuitka ordered-set
python -m nuitka --standalone --enable-plugin=pyqt6 --windows-console-mode=disable ^
  --include-data-dir=resources=resources --output-filename=MyApp.exe main.py

# Linux
python -m nuitka --standalone --enable-plugin=pyqt6 \
  --include-data-dir=resources=resources --output-filename=myapp main.py

# macOS
python -m nuitka --standalone --enable-plugin=pyqt6 --macos-create-app-bundle \
  --macos-app-icon=resources/app.icns --macos-app-name=MyApp \
  --include-data-dir=resources=resources main.py
```

- Onefile: add `--onefile` (Nuitka's onefile also self-extracts).
- Compilation needs a C compiler: MSVC on Windows (from Visual Studio Build Tools), `gcc`/`clang` on Linux/macOS.
- Builds are **slow** (full C compilation) — budget minutes, not seconds.
- PyQt6 support is via `--enable-plugin=pyqt6`; mature but less "just works" than PyInstaller's hooks.

### 7.3 Trade-off summary [general]

| | PyInstaller | Nuitka |
|---|---|---|
| Setup | pip only | pip + C compiler |
| Build time | fast | slow |
| Startup | onefile slow | faster in general |
| AV false positives | more (unsigned onefile) | generally fewer, not guaranteed |
| Debugging | easy | harder |
| Data bundling | `--add-data` | `--include-data-dir` |

**[from this repo]** The studied project uses only PyInstaller; no comparison data is available from it. The choice between them for a new project is **not** dictated by this repository. Try PyInstaller onedir first (simplest); if false positives hurt you, do an A/B VirusTotal comparison of the *same* app built both ways and choose based on your own data.

---

## 8. Linux: AppImage

### 8.1 Strategy

The key Linux problem: **glibc compatibility**. A binary built on a new distro needs a newer glibc and will fail on older distros. **[from this repo]** the studied project builds on `ubuntu-latest` (a recent distro) and ships a bare zipped ELF; a user hit a plugin/glibc-skew crash on an older system. Do the opposite: **build on the oldest distro you intend to support** (commonly Ubuntu 20.04/22.04, or use the `docker://` approach), or use an AppImage toolchain that is known to work there.

Recommended flow:

```text
PyQt6 app (PyInstaller onedir or Nuitka standalone)
        ↓
build inside a container: ubuntu:20.04 (old glibc)
        ↓
assemble AppDir:
  AppDir/AppRun
  AppDir/myapp.desktop
  AppDir/myapp.png
  AppDir/usr/bin/myapp        ← the bundled app (or its _internal dir)
  AppDir/usr/lib/...          ← bundled libs
  AppDir/usr/share/icons/...  ← themed icons
        ↓
appimagetool AppDir  →  MyApp-1.2.0-x86_64.AppImage
```

### 8.2 AppDir structure

```
MyApp.AppDir/
├── AppRun                       # executable entry point (symlink to usr/bin/myapp, or a script)
├── myapp.desktop
├── myapp.png                    # 256x256 icon (also under usr/share/icons/hicolor/256x256/apps/)
└── usr/
    ├── bin/myapp                # the PyInstaller onedir executable
    ├── lib/...                  # app's _internal/ bundled libs (PyInstaller onedir)
    └── share/icons/hicolor/256x256/apps/myapp.png
```

`.desktop` file:

```ini
[Desktop Entry]
Name=MyApp
Comment=Describe the app
Exec=myapp
Icon=myapp
Type=Application
Categories=Graphics;Utility;
Terminal=false
```

### 8.3 Simplest approach: AppImage from a PyInstaller onedir

1. Build on old distro: `docker run --rm -v $PWD:/app -w /app ubuntu:20.04 bash -c "pip install ... && pyinstaller MyApp.spec --onedir"`
2. Copy the onedir output into the AppDir skeleton (above).
3. Generate the AppImage:
   ```bash
   wget -O appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
   chmod +x appimagetool
   ARCH=x86_64 ./appimagetool MyApp.AppDir
   ```

### 8.4 More robust approach: linuxdeploy + linuxdeploy-plugin-qt

For PyQt6 apps, `linuxdeploy` with its Qt plugin auto-collects Qt libraries and plugins into the AppDir:

```bash
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
export DEPLOY_QT_QML_DIR=  # not needed for pure Widgets
./linuxdeploy-x86_64.AppImage \
  --appdir MyApp.AppDir \
  --executable dist/myapp/myapp \
  --desktop-file packaging/linux/myapp.desktop \
  --icon-file resources/myapp.png \
  --plugin qt
```

### 8.5 Environment and libraries

- PyInstaller/Nuitka standalone bundles Qt and most libs, so the AppImage mostly needs the AppRun to set nothing special. If you need env, add an `AppRun` script:
  ```bash
  #!/bin/bash
  HERE="$(dirname "$(readlink -f "$0")")"
  export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/usr/lib/.../platforms"
  exec "$HERE/usr/bin/myapp" "$@"
  ```
- **Test on several distros** (see §14). A VM/matrix of Ubuntu LTS, Fedora, and a rolling distro is the minimum.
- **[from this repo]** The studied project does **not** produce AppImages; the Linux artifact is a zipped ELF. Everything in this section is general guidance.

---

## 9. Linux: Debian `.deb` Package

### 9.1 The central decision: bundle or depend?

For a PyQt6 app you have two philosophies:

- **A. Depend on distro packages** (`Depends: python3, python3-pyqt6`): small `.deb`, relies on the system Python/Qt. Compatible with the distro's policies (Debian/Ubuntu prefer this for source-builds), but you can't control Qt version and users must have matching packages available.
- **B. Ship your own runtime** (PyInstaller/Nuitka standalone inside the `.deb`): self-contained, version-locked, works on minimal systems; larger `.deb` and it duplicates Python/Qt.

**Recommendation [general]**: For a PyQt6 app that you control, **B** (ship a PyInstaller/Nuitka standalone under `/usr/lib/<app>/`) gives the most reproducible result and avoids Python 3.10/3.12 transition pain (the studied repo's PyQt6 pins are a good example of how fast distro Python changes). If you want to follow distro conventions and don't need bleeding-edge Qt, **A** is fine and easier to build with `dpkg-buildpackage`.

### 9.2 Package layout (option B: self-contained)

```
mypackage/
├── DEBIAN/
│   └── control
├── usr/
│   ├── bin/mypkg                → symlink to ../lib/mypkg/mypkg
│   ├── lib/mypkg/               ← PyInstaller/Nuitka standalone output
│   ├── share/applications/mypkg.desktop
│   ├── share/icons/hicolor/256x256/apps/mypkg.png
│   └── share/doc/mypkg/copyright
```

`DEBIAN/control`:

```
Package: mypkg
Version: 1.2.0
Section: graphics
Priority: optional
Architecture: amd64
Maintainer: You <you@example.com>
Depends: libxcb-xinerama0, libxkbcommon-x11-0, libgl1, libegl1   # Qt runtime system libs
Description: A PyQt6 application
 MyApp is a cross-platform PyQt6 desktop application that does things.
```

(The `Depends` list above is the classic set of system libraries Qt needs on Debian/Ubuntu that the standalone bundle does NOT include. Adjust by running the app on a clean minimal system and checking `ldd`.)

`usr/share/applications/mypkg.desktop`:

```ini
[Desktop Entry]
Name=MyApp
Comment=...
Exec=/usr/lib/mypkg/mypkg
Icon=mypkg
Terminal=false
Type=Application
Categories=Utility;
```

### 9.3 Building and testing

```bash
# after assembling the tree above:
dpkg-deb --build --root-owner-group mypackage
# → mypackage_1.2.0_amd64.deb

# inspect
dpkg-deb --info mypackage_1.2.0_amd64.deb
dpkg-deb --contents mypackage_1.2.0_amd64.deb

# lint (catches policy issues)
lintian mypackage_1.2.0_amd64.deb

# install / uninstall in a disposable container or VM
dpkg -i mypackage_1.2.0_amd64.deb
```

### 9.4 Alternative: proper `debian/` source packaging

For distro-style source packages you'd add a `debian/` directory (control, rules, changelog, copyright, install, desktop) and build with `dpkg-buildpackage`. That path is primarily for getting your app into Debian/Ubuntu proper; for distributing your own `.deb` on GitHub Releases, the simple `dpkg-deb --build` approach above is enough.

---

## 10. macOS: `.app`, Signing, Notarization, DMG

### 10.1 Prerequisites (Apple requirements)

- **[from this repo]** The studied project does **no** macOS signing/notarization; its zipped `.app` triggers Gatekeeper warnings. Do the opposite.
- **Apple Developer account** (free tier gives you code-signing; **paid** membership required for **Developer ID** certificates and **notarization** — these are the pieces that make Gatekeeper quiet). You do NOT need a paid account to *build* a `.app` or a DMG.

### 10.2 Build the `.app`

PyInstaller (from `MyApp.spec`):

```bash
pyinstaller MyApp.spec    # spec ends with BUNDLE(...) → creates dist/MyApp.app
```

Nuitka:

```bash
python -m nuitka --standalone --enable-plugin=pyqt6 --macos-create-app-bundle \
  --macos-app-icon=resources/app.icns --macos-app-name=MyApp main.py
```

`Info.plist` is auto-generated by PyInstaller/Nuitka. Set a good `CFBundleIdentifier` (in the spec: `bundle_identifier='com.example.myapp'`). You can post-process `Info.plist` with `plutil` if you need extra keys (`CFBundleShortVersionString`, etc.).

### 10.3 Sign (ad-hoc or Developer ID)

Ad-hoc (silences nothing for others, but validates locally):

```bash
codesign --force --deep --sign - dist/MyApp.app
```

Developer ID (for distribution to others):

```bash
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  --entitlements packaging/macos/entitlements.plist \
  dist/MyApp.app
```

`entitlements.plist` (hardened runtime — required for notarization):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key><true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
    <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict>
</plist>
```

> `--deep` is discouraged by Apple in modern guidance; instead sign the *inner* binaries/frameworks first (PyInstaller can do this via `codesign_identity` + `entitlements_file` in the spec), then sign the bundle. For a first working pipeline, `--deep` on the app is acceptable for many PyQt6 apps.

### 10.4 Notarize and staple

```bash
# 1. Zip the app for submission
ditto -c -k --keepParent dist/MyApp.app dist/MyApp.zip

# 2. Submit (uses an app-specific password; team id optional)
xcrun notarytool submit dist/MyApp.zip \
  --apple-id "you@example.com" \
  --password "APP-SPECIFIC-PASSWORD" \
  --team-id "TEAMID" --wait

# 3. Staple the ticket onto the app (so offline users get "Verified")
xcrun stapler staple dist/MyApp.app
```

### 10.5 DMG

```bash
mkdir -p dist/dmgroot
cp -R dist/MyApp.app dist/dmgroot/
ln -s /Applications dist/dmgroot/Applications
hdiutil create -volname "MyApp 1.2.0" -srcfolder dist/dmgroot \
  -ov -format UDZO dist/MyApp-1.2.0.dmg
```

Optionally sign the DMG too (`codesign -s "Developer ID Application..." dist/MyApp-1.2.0.dmg`).

### 10.6 Sequence summary

```text
build .app → set bundle id → sign inner bits → sign .app (hardened runtime)
→ notarize (zip → notarytool → wait) → staple → create DMG → (sign DMG) → release
```

Requires Apple Developer **paid** account: Developer ID cert, notarization. Everything else (`.app`, DMG, ad-hoc sign) is free.

---

## 11. Qt Plugins and Translations

### 11.1 Plugins

- **[from this repo]** The studied app relies on PyInstaller's PyQt6 hook to bundle all platform plugins; a Linux Wayland plugin crash (issue #13) shows the danger of blindly bundling everything.
- **General**:
  - PyInstaller's `pyinstaller-hooks-contrib` includes hooks for `PyQt6`/`PySide6` that collect platform plugins (windows, xcb, wayland, cocoa, minimal, offscreen, ...), image format plugins (PNG/JPEG/GIF/SVG...), styles, and icon engines.
  - You normally do **nothing** — unless a plugin is missing at runtime. Then add: `--collect-data PyQt6.QtCore` (or the specific package) to force inclusion.
  - To **shrink** the bundle or avoid broken plugins on old systems, restrict with `--exclude-module` or edit the spec's `binaries`/`datas`. For Linux, consider `--exclude-module PyQt6.QtWebEngineWidgets`, `PyQt6.QtNetwork`, and review which `platforms/*` land in the bundle.
  - For Nuitka: `--enable-plugin=pyqt6` handles the same job; verify `platforms`/`imageformats` dirs exist in the output.

### 11.2 Translations (Qt's own dialogs)

Qt's built-in dialogs (Open/Save, Print, standard QMessageBox buttons) are translated **only if** the Qt translation catalogs (`qtbase_<lang>.qm` or `qt_<lang>.qm`) are loaded via `QTranslator`. These `.qm` files ship inside the PyQt6 wheel (`PyQt6/Qt6/translations`) and are **not** in your frozen app unless you add them:

```python
from PyQt6.QtCore import QTranslator, QLibraryInfo, QLocale
from PyQt6.QtWidgets import QApplication

app = QApplication([])
translator = QTranslator()
# Find the bundled translations. PyInstaller must have bundled them.
base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
qm = os.path.join(base, "PyQt6", "Qt6", "translations")
if translator.load(QLocale.system(), "qtbase", "_", qm):
    app.installTranslator(translator)
```

And bundle the translations in your spec/command:

```bash
pyinstaller MyApp.spec   # with, in the spec:
# datas=[('resources','resources'),
#        ('/path/to/venv/Lib/site-packages/PyQt6/Qt6/translations', 'PyQt6/Qt6/translations')]
# or simply use: --collect-data PyQt6.QtCore
```

Your own app strings are translated separately (Qt Linguist → `.ts` → `.qm`), and those `.qm` go into `resources/` and are bundled like any data file. **[from this repo]** The studied app has **no** translations and does none of this.

---

## 12. GitHub Actions Pipeline

### 12.1 The pattern

Keep the matrix idea **[from this repo]** (the studied project's `package.yml` matrix with per-OS `CMD_BUILD`), but modernize and complete it:

```text
git tag v1.2.0 (push tag)
        ↓
on: push tags 'v*'
        ↓
Matrix: [windows-latest, ubuntu-20.04 (or ubuntu-latest + docker), macos-latest]
        ↓
per OS: setup python → install deps → build → sign (secrets) → checksum
        ↓
upload artifact → download all → create GitHub Release (tag, assets, notes, checksums)
```

### 12.2 Example workflow (structure, not guaranteed-working YAML)

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write   # to create the release

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: windows-latest
            TARGET: windows
            ARTIFACT: MyApp-Windows-x64
            CMD_BUILD: |
              pyinstaller MyApp.spec --onedir
              iscc packaging/windows/installer.iss
              signtool sign /fd SHA256 /f cert.pfx /p "${{ secrets.WINDOWS_PFX_PASSWORD }}" /tr http://timestamp.digicert.com /td SHA256 "dist-installer\MyApp-Setup-1.2.0.exe"
          - os: ubuntu-20.04
            TARGET: linux
            ARTIFACT: MyApp-Linux-x86_64.AppImage
            CMD_BUILD: |
              pyinstaller MyApp.spec --onedir
              linuxdeploy --appdir MyApp.AppDir --executable dist/MyApp/MyApp --desktop-file packaging/linux/MyApp.desktop --icon-file resources/MyApp.png --plugin qt
              ./appimagetool MyApp.AppDir
          - os: macos-latest
            TARGET: macos
            ARTIFACT: MyApp-macOS.dmg
            CMD_BUILD: |
              pyinstaller MyApp.spec        # BUNDLE → MyApp.app
              codesign --force --options runtime --timestamp --sign "${{ secrets.APPLE_IDENTITY }}" --entitlements packaging/macos/entitlements.plist dist/MyApp.app
              ditto -c -k --keepParent dist/MyApp.app dist/MyApp.zip
              xcrun notarytool submit dist/MyApp.zip --apple-id "${{ secrets.APPLE_ID }}" --password "${{ secrets.APPLE_APP_PASSWORD }}" --team-id "${{ secrets.APPLE_TEAM_ID }}" --wait
              xcrun stapler staple dist/MyApp.app
              hdiutil create -volname "MyApp 1.2.0" -srcfolder dist -ov -format UDZO dist/MyApp.dmg
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - name: Install dependencies
        run: python -m pip install -r requirements.txt
      - name: Build
        shell: bash
        run: ${{ matrix.CMD_BUILD }}
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.TARGET }}
          path: ${{ matrix.OUT }}

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: artifacts
      - name: Create checksums
        run: |
          cd artifacts
          find . -type f -exec sha256sum {} \; > SHA256SUMS.txt
      - name: Publish Release
        uses: softprops/action-gh-release@v2
        with:
          files: artifacts/**/*
          generate_release_notes: true
```

### 12.3 GitHub Secrets used

Only names — never values:

| Secret | Purpose |
|---|---|
| `WINDOWS_PFX` (base64 PFX) | Windows Authenticode certificate |
| `WINDOWS_PFX_PASSWORD` | PFX password |
| `APPLE_IDENTITY` | `Developer ID Application: ...` certificate name |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_APP_PASSWORD` | App-specific password (created at appleid.apple.com) |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

Secrets are stored at repo/org settings and referenced only as `${{ secrets.X }}`.

### 12.4 Modernization tips

- Use **tag-triggered** releases (the studied repo uses manual `workflow_dispatch` **[from this repo]**; automatic tag builds are more reproducible).
- Pin actions to SHAs (e.g. `actions/checkout@4e5a...`) or at least major tags; the studied repo uses mutable `@v3/@v4` **[from this repo]**.
- Add `permissions: contents: write` only on the job that needs it; enable OIDC attestations (see §13) for free.
- Use `actions/setup-python` with `cache: pip` to speed up builds (the studied repo caches nothing **[from this repo]**).
- On Linux, build the AppImage inside a container of your **oldest supported distro** to guarantee glibc compatibility.

---

## 13. Checksums, Integrity, and Release Hygiene

For every release, publish a `SHA256SUMS.txt`:

```bash
sha256sum MyApp-Setup-1.2.0.exe MyApp-1.2.0-x86_64.AppImage MyApp-1.2.0.dmg > SHA256SUMS.txt
```

Additional cheap wins:

- **Git tag signing**: sign release tags with your GPG key (`git tag -s v1.2.0`).
- **GitHub attestations**: enable OIDC and `actions/attest-build-provenance@v2` — free SLSA-style provenance that links the artifact to the build.
- **Dependabot** for `requirements.txt`/`pyproject.toml` (and actions) — free automated dependency bump PRs.
- **Lockfile with hashes**: `pip install --require-hashes` or use `uv`/`pip-tools` to pin transitive dependencies.
- **[from this repo]** The studied project has *none* of these (no checksums — GitHub API shows `digest: null` on all release assets — no lockfile, no Dependabot config). Copying its omissions is **not recommended**.

---

## 14. Testing Your Packages

Before uploading a release, actually run the artifacts:

- **Windows**: run the exe on a clean VM (or `windows-latest` in CI) and smoke-test; test on the oldest Windows you support. Verify no console window for `--windowed`.
- **Linux**: run the AppImage and `.deb` on a matrix of distros — at minimum Ubuntu LTS (old and new) and Fedora, in Docker/VMs:
  ```bash
  docker run --rm -v $PWD:/app ubuntu:20.04 bash -c "/app/MyApp.AppImage --version"
  ```
  Check `ldd dist/myapp/MyApp` for missing system libs on a minimal distro.
- **macOS**: open the `.app` from a *quarantined* download (drag to another Mac or download via curl) to confirm Gatekeeper behavior; verify `spctl -a -vv dist/MyApp.app` shows the expected result after notarization.
- **CI smoke test**: add a step that launches the built binary with `--help`/`--version` (add such a flag to your app) to catch "silently broken" builds — a failure mode this study observed in the original project's issues **[from this repo]**.

---

## Appendix: Reusable Templates

### Minimal `requirements.txt`

```text
# runtime
PyQt6==6.7.1
Pillow==10.4.0

# build tools (usually installed separately or via a build requirements file)
pyinstaller==6.11.1
```

### `requirements-build.txt`

```text
-r requirements.txt
pyinstaller==6.11.1
```

### Windows `version_info.txt` — see §4.3.

### Inno Setup `installer.iss` — see §4.5.

### PyInstaller onefile spec — see §6.3.

### `.desktop` file — see §8.2.

### `DEBIAN/control` — see §9.2.

### `entitlements.plist` — see §10.3.

### GitHub Actions workflow — see §12.2.

### Resource path helper — see §3.2.

---

## Final Word

The CustomKnight Creator repository proves that **a working cross-platform build is easy** (PyInstaller + a matrix), and that **a professional distribution is a separate, larger job** (signing, notarization, installers, AppImage/`.deb`/DMG, checksums, release automation). Use the first half as your starting scaffold and the second half as your checklist. Test everything on real machines, publish checksums, keep dependencies current, and accept — honestly — that antivirus results cannot be guaranteed.

*This tutorial's repository-derived items are marked **[from this repo]**; everything else is general guidance. Commands are templates, not warranties.*
