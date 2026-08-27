# PYQT6 MASTER PACKAGING TUTORIAL

A practical, step-by-step guide to packaging a **PyQt6** desktop application for
**Windows, Linux, and macOS**, built from the comparative analysis of five
real-world projects (CARA, CustomKnight-Creator, dikte, napari, pyzo).

**How to use this document**
- Every example that is not proven by the case studies is labelled
  `[TEMPLATE — MUST BE TESTED]`. Commands are starting points, not guarantees.
- Replace all placeholders (`MyApp`, `org.example.MyApp`, `YOUR-...`) with real
  values. **No real credentials, private keys, or secret values appear in this
  document.**
- Techniques marked `[OBSERVED]` were actually implemented by a studied
  project; `[RECOMMENDED]` are evidence-based recommendations.

**Evidence/classification legend (short form):**
- `[OBSERVED — <project>]` — implemented by that project.
- `[REPEATED]` — implemented by multiple projects.
- `[RECOMMENDED]` — recommendation derived from the comparison, must be tested.
- `[NOT VERIFIED]` — no case-study evidence; verify yourself.

---

## Table of contents

1. [Before you start: product decisions](#1-before-you-start-product-decisions)
2. [Project layout and resource strategy](#2-project-layout-and-resource-strategy)
3. [Dependency control](#3-dependency-control)
4. [PyInstaller strategy](#4-pyinstaller-strategy)
5. [Nuitka strategy](#5-nuitka-strategy)
6. [PyInstaller vs Nuitka — how to decide](#6-pyinstaller-vs-nuitka--how-to-decide)
7. [Windows: onedir + signing + Inno Setup](#7-windows-onedir--signing--inno-setup)
8. [Windows: antivirus/SmartScreen practice](#8-windows-antivirussmartscreen-practice)
9. [Linux AppImage](#9-linux-appimage)
10. [Linux GLIBC compatibility](#10-linux-glibc-compatibility)
11. [Linux DEB](#11-linux-deb)
12. [macOS: .app, signing, notarization, DMG](#12-macos-app-signing-notarization-dmg)
13. [Qt plugins, resources, translations](#13-qt-plugins-resources-translations)
14. [External binaries](#14-external-binaries)
15. [GitHub Actions](#15-github-actions)
16. [Checksums, SBOM, provenance](#16-checksums-sbom-provenance)
17. [Testing procedures](#17-testing-procedures)
18. [Release checklist](#18-release-checklist)
19. [Controlled PyInstaller/Nuitka experiment](#19-controlled-pyinstallernuitka-experiment)

---

## 1. Before you start: product decisions

Decide these before writing any packaging code; they are expensive to change
later.

1. **Qt binding:** PyQt6 directly, or QtPy for multi-binding flexibility
   (napari uses QtPy). Pick one and don't mix.
   `[OBSERVED — napari]` `[RECOMMENDED]`
2. **Supported platforms/architectures:** e.g. Windows x64, Linux x86_64,
   macOS arm64 + x86_64. Do not assume universal2 works until proven.
3. **Oldest supported OS for each platform** — drives the GLIBC floor on Linux
   and the macOS minimum OS version.
4. **Distribution model per platform:**
   - Windows: installer? portable ZIP? both?
   - Linux: AppImage? `.deb`? both?
   - macOS: ZIP? DMG? both?
5. **Signing budget:** Windows code-signing certificates cost money (or use
   OSS programs like SignPath Foundation / Azure Trusted Signing for OSS);
   Apple Developer Program is ~$99/year. Decide this early.
   `[RECOMMENDED]`

---

## 2. Project layout and resource strategy

### Directory structure `[RECOMMENDED — assembled from CARA/dikte/pyzo]`

```text
myapp/
├── pyproject.toml              # metadata, dependencies, entry point
├── src/myapp/
│   ├── __init__.py
│   ├── __main__.py             # thin entry: from myapp.app import main
│   ├── app.py
│   └── resources/              # data shipped as files (not .qrc by default)
├── packaging/
│   ├── pyinstaller/
│   │   ├── myapp_windows.spec
│   │   ├── myapp_linux.spec
│   │   └── myapp_macos.spec
│   ├── windows/
│   │   ├── version_info.txt
│   │   └── myapp.iss           # Inno Setup
│   ├── linux/
│   │   ├── AppRun
│   │   ├── org.example.MyApp.desktop
│   │   ├── myapp.png
│   │   └── org.example.MyApp.metainfo.xml
│   ├── debian/                 # native source packaging (see §11)
│   └── macos/
│       └── entitlements.plist
├── requirements/
│   ├── base.txt
│   ├── build-win.txt
│   ├── build-linux.txt
│   └── build-mac.txt           # hashed locks generated from these
├── scripts/
│   ├── build-windows.ps1
│   ├── build-appimage.sh
│   ├── build-deb.sh
│   └── build-dmg.sh
└── .github/workflows/
    ├── ci.yml
    ├── build.yml               # reusable matrix
    └── release.yml
```

### Resource resolver `[OBSERVED — CARA]` `[RECOMMENDED]`

Never depend on the current working directory. Centralize resource discovery in
one helper that understands development, PyInstaller onedir, and the macOS
`.app` layout:

```python
# src/myapp/resources.py
from pathlib import Path
import sys

def resource_root() -> Path:
    if getattr(sys, "frozen", False):
        exe = Path(sys.executable)
        if sys.platform == "darwin" and exe.parent.name == "MacOS":
            return exe.parent.parent / "Resources"     # CARA pattern
        return exe.parent / "_internal"                # verify your layout
    return Path(__file__).resolve().parents[1]

def resource_path(relative: str) -> Path:
    return resource_root() / relative
```

- Keep bundled resources read-only.
- Write user data to platform locations (`platformdirs`):
  - Windows: `%APPDATA%/MyApp`
  - Linux: `$XDG_DATA_HOME/MyApp` / `~/.local/share/MyApp`
  - macOS: `~/Library/Application Support/MyApp`
- **Never write inside a signed macOS `.app`** — it invalidates the signature.
  `[OBSERVED — CARA]`
- Use `importlib.resources` for package data where convenient (works with all
  packaging tools). `[OBSERVED — napari]` `[RECOMMENDED]`

---

## 3. Dependency control

`[RECOMMENDED — only napari does this properly in the case studies]`

```bash
# Create and lock the build environment (per OS)
python -m venv .venv
# Linux/macOS:
source .venv/bin/activate
# Windows PowerShell:
.venv\Scripts\activate
python -m pip install --upgrade pip

# With pip-tools / uv:
pip-compile requirements/build-win.in -o requirements/build-win.txt
pip install -r requirements/build-win.txt
```

- Pin **exactly**: Python version, PyQt6, PyInstaller (or Nuitka), installer
  tools, and appimagetool/linuxdeploy (version + SHA256).
- Commit the lockfiles; record resolved versions and build logs with each
  release.
- For AppImage: download a **pinned, checksummed** appimagetool — do not use
  the mutable `continuous` URL. `[OBSERVED — dikte weak point]`

---

## 4. PyInstaller strategy

### Start with onedir `[REPEATED — CARA, dikte, pyzo]`

```bash
# Generate the initial spec, then commit and edit it
pyinstaller --noconfirm --clean --onedir --windowed \
  --name MyApp --icon packaging/windows/myapp.ico \
  --add-data "src/myapp/resources:myapp/resources" \
  src/myapp/__main__.py
```

- On Windows use `;` as the `--add-data` separator: `"src;dest"`.
- `--windowed` / `--noconsole` removes the console for a GUI app.
- **Avoid `--onefile`** unless a single naked executable is a real user
  benefit; an installer/AppImage/DMG already gives users one file, and onedir
  avoids per-launch extraction. `[REPEATED]`
- **PyInstaller 6.x removed the `--verbose` flag.** `pyinstaller --verbose`
  fails with `unrecognized arguments: --verbose`. Use `--log-level=DEBUG` or
  remove it. `[OBSERVED — TBO, 2026]`

### A committed onedir spec `[OBSERVED — CARA/dikte shape]`

```python
# packaging/pyinstaller/myapp_windows.spec  — [TEMPLATE — MUST BE TESTED]
# -*- mode: python ; coding: utf-8 -*-
from pathlib import Path

ROOT = Path(SPECPATH).parent.parent          # repo root

a = Analysis(
    [str(ROOT / "src/myapp/__main__.py")],
    pathex=[str(ROOT / "src")],
    binaries=[],
    datas=[
        (str(ROOT / "src/myapp/resources"), "myapp/resources"),
        # add Qt translations if needed, e.g.:
        # ("<venv>/Lib/site-packages/PyQt6/Qt6/translations", "PyQt6/Qt6/translations"),
    ],
    hiddenimports=["PyQt6.QtNetwork"],       # TLS/network if used
    excludes=["tkinter", "PyQt6.QtWebEngineWidgets", "PyQt6.QtQml"],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz, a.scripts, [], exclude_binaries=True,
    name="MyApp",
    console=False,                            # windowed
    icon=str(ROOT / "packaging/windows/myapp.ico"),
    version=str(ROOT / "packaging/windows/version_info.txt"),  # PE metadata
    upx=False,                                # deliberate: no UPX
)
coll = COLLECT(exe, a.binaries, a.datas, name="MyApp")
```

Build with:

```bash
python -m PyInstaller packaging/pyinstaller/myapp_windows.spec \
  --distpath build/dist --workpath build/work --noconfirm --clean
```

### Windows PE version metadata `[RECOMMENDED — CustomKnight/pyzo studies]`

Create `packaging/windows/version_info.txt` (see `pyi-grab_version` for the
format) with at least: `CompanyName`, `FileDescription`, `FileVersion`,
`ProductName`, `ProductVersion`, `LegalCopyright`, `OriginalFilename`. Point
`version=` at it in the spec. This gives AV engines and users a stable
identity fingerprint.

### UPX policy `[RECOMMENDED — all tutorials]`

Keep UPX off unless you deliberately measure a size benefit:
- Set `upx=False` in the spec, or pass `--noupx`.
- Do not install UPX on CI.
- UPX-packed executables are widely reported as AV triggers; no case study
  measures the effect, but avoiding it is free.

---

## 5. Nuitka strategy

No studied project uses Nuitka, so everything here is
`[RECOMMENDED — TEMPLATE — MUST BE TESTED]`. Nuitka compiles Python to C and
needs a compiler (MSVC on Windows, gcc/clang on Linux/macOS); builds are
slower.

```bash
# Windows
python -m nuitka --mode=standalone --enable-plugin=pyqt6 \
  --windows-console-mode=disable \
  --windows-icon-from-ico=packaging/windows/myapp.ico \
  --company-name="Example Publisher" --product-name="MyApp" \
  --file-version="1.2.3.0" --product-version="1.2.3.0" \
  --include-data-dir=src/myapp/resources=myapp/resources \
  src/myapp/__main__.py

# Linux
python -m nuitka --mode=standalone --enable-plugin=pyqt6 \
  --include-data-dir=src/myapp/resources=myapp/resources \
  src/myapp/__main__.py

# macOS (app bundle)
python -m nuitka --mode=standalone --enable-plugin=pyqt6 \
  --macos-create-app-bundle --macos-app-name=MyApp \
  --macos-app-icon=packaging/macos/myapp.icns \
  --include-data-dir=src/myapp/resources=myapp/resources \
  src/myapp/__main__.py
```

- **`--file-version` / `--product-version` require a 4-part numeric version**
  (`major.minor.build.revision`, e.g. `2.0.0.0`). A PEP 440 version such as
  `2.0.0.dev0` (or `2.0.0.dev0.0`) makes Nuitka fail with
  `FATAL: Invalid version number`. Sanitize it before passing:
  `2.0.0.dev0` → `2.0.0.0`. [OBSERVED — TBO, 2026]


- Select only the Qt plugins you need (`--include-qt-plugins=platforms;imageformats`
  style; check your Nuitka version's docs).
- **macOS caveat:** Nuitka 2.1 historically dropped PyQt6 on macOS; current
  versions again support it, but prove a PyQt6 `.app` on your exact versions
  before standardizing on it. `[RECOMMENDED — from dikte study]`

---

## 6. PyInstaller vs Nuitka — how to decide

The case studies provide **no** comparison data (4 projects use PyInstaller,
none use Nuitka, and napari rejected all freezers for its plugin use case).
So:

1. Start with PyInstaller onedir. `[REPEATED]`
2. If antivirus reputation or startup is a real concern, run the controlled
   experiment in §19 **over several releases** before switching.
3. Do not pick Nuitka solely on anecdotes, and do not assume either tool
   "prevents" detections. `[NOT VERIFIED]`

---

## 7. Windows: onedir + signing + Inno Setup

### Pipeline `[RECOMMENDED — strongest observed combination]`

```text
PyInstaller onedir (or Nuitka standalone)
  -> PE version metadata + icon
  -> smoke-test the payload
  -> sign inner executables (Authenticode + RFC 3161 timestamp)
  -> verify inner signatures
  -> compile Inno Setup installer (per-user)
  -> sign + timestamp the installer (and uninstaller if supported)
  -> verify installer signature
  -> SHA256
  -> GitHub Release
```

### Signing commands `[TEMPLATE — MUST BE TESTED; placeholder CA URL]`

```powershell
# Sign the inner executable(s)
signtool sign /fd SHA256 /tr https://YOUR-CA-RFC3161-ENDPOINT /td SHA256 /a `
  build\dist\MyApp\MyApp.exe

# Verify
signtool verify /pa /all /v build\dist\MyApp\MyApp.exe

# Compile installer
iscc /DVersion=1.2.3 /DSource=build\dist\MyApp packaging\windows\myapp.iss

# Sign + verify installer
signtool sign /fd SHA256 /tr https://YOUR-CA-RFC3161-ENDPOINT /td SHA256 /a `
  dist\MyApp-1.2.3-setup.exe
signtool verify /pa /all /v dist\MyApp-1.2.3-setup.exe
```

- `/a` only when the signing context exposes exactly the intended certificate;
  a cloud-signing service uses its own tooling.
- **Do not re-sign third-party DLLs**; keep upstream signatures and licenses.
  `[RECOMMENDED — dikte study]`
- Store certificates/keys in CI secrets or a managed signing service; **never**
  in the repository. `[REPEATED]`

### Inno Setup skeleton `[OBSERVED — dikte/pyzo; TEMPLATE — MUST BE TESTED]`

```ini
; packaging/windows/myapp.iss
#define MyAppName "MyApp"
#define MyAppVersion "1.2.3"
#define MyAppExeName "MyApp.exe"

[Setup]
AppId={{YOUR-STABLE-GUID-HERE}      ; keep stable for clean upgrades
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Example Publisher
AppPublisherURL=https://github.com/example/myapp
DefaultDirName={localappdata}\Programs\{#MyAppName}
PrivilegesRequired=lowest           ; per-user, no UAC (dikte pattern)
OutputDir=..\..\dist
OutputBaseFilename=MyApp-{#MyAppVersion}-x64-setup
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\..\build\dist\MyApp\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
```

- Optional portable ZIP: zip the whole onedir tree (document where settings
  live; "portable archive" is not "portable settings" unless the app
  implements it).

---

## 8. Windows: antivirus/SmartScreen practice

`[RECOMMENDED — no case study measures detection rates; treat all of this as
risk reduction, never a guarantee]`

1. Build from a clean, reproducible CI environment; keep logs.
2. Use current stable freezer/Qt versions (not years-old ones).
3. Prefer onedir/standalone over onefile.
4. Keep UPX off.
5. Embed consistent version/product/publisher metadata + icon.
6. Sign with one stable trusted identity and timestamp every distributed
   executable/installer.
7. Sign both inner executables and the installer.
8. Publish source, workflows, release notes, SHA256, SBOM/provenance.
9. Scan the **final signed artifact**; record per-version results; investigate
   engine names, not just the total count.
10. Submit confirmed false positives to the vendor's official portal (e.g.,
    Microsoft's security-intelligence submission) with the file hash and a
    source link.

**Interpretation rules `[RECOMMENDED — dikte/napari studies]`:**
- One or two heuristic detections ≠ malware; zero ≠ safe.
- SmartScreen "unrecognized app" is a reputation decision, distinct from a
  malware-family detection.
- Signing proves publisher identity and integrity, not benign behavior.
- A non-Windows-trusted signature (e.g., an Apple cert) does **not** remove
  SmartScreen warnings — napari's own workflow says so. `[OBSERVED — napari]`
- Never ask users to disable antivirus or remove quarantine.

---

## 9. Linux AppImage

### Pipeline `[OBSERVED — dikte, adapted]`

```text
build on old base (ubuntu-22.04 or older container)
  -> PyInstaller onedir
  -> assemble AppDir:
       AppRun
       org.example.MyApp.desktop
       myapp.png
       usr/bin/<onedir contents>
       usr/share/icons/hicolor/<size>/apps/myapp.png
       usr/share/metainfo/org.example.MyApp.metainfo.xml
  -> appimagetool (pinned + checksummed) -> MyApp-x86_64.AppImage
```

### AppDir template

```text
MyApp.AppDir/
├── AppRun
├── org.example.MyApp.desktop
├── myapp.png                       # 256px top-level icon
└── usr/
    ├── bin/
    │   ├── myapp                   # the PyInstaller GUI executable
    │   └── _internal/...           # onedir payload
    └── share/
        ├── applications/org.example.MyApp.desktop
        ├── icons/hicolor/.../apps/myapp.png
        └── metainfo/org.example.MyApp.metainfo.xml
```

`AppRun` (mount-safe) `[TEMPLATE — MUST BE TESTED]`:

```sh
#!/bin/sh
set -eu
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/myapp" "$@"
```

Desktop file `[TEMPLATE — MUST BE TESTED]`:

```ini
[Desktop Entry]
Type=Application
Name=MyApp
Comment=Describe the application
Exec=myapp
Icon=myapp
Categories=Utility;
Terminal=false
StartupNotify=true
```

Build `[TEMPLATE — MUST BE TESTED]`:

```bash
#!/usr/bin/env bash
set -euo pipefail
appdir="$PWD/build/MyApp.AppDir"
out="$PWD/dist/MyApp-1.2.3-x86_64.AppImage"

python -m PyInstaller packaging/pyinstaller/myapp_linux.spec \
  --distpath build/dist --workpath build/work --noconfirm --clean

install -d "$appdir/usr/bin" "$appdir/usr/share/icons/hicolor/256x256/apps"
cp -a build/dist/MyApp/. "$appdir/usr/bin/"
install -m 0755 packaging/linux/AppRun "$appdir/AppRun"
install -m 0644 packaging/linux/org.example.MyApp.desktop "$appdir/"
install -m 0644 packaging/linux/myapp.png "$appdir/myapp.png"
install -m 0644 packaging/linux/myapp.png "$appdir/usr/share/icons/hicolor/256x256/apps/myapp.png"

# pinned + checksummed appimagetool
build/appimagetool-x86_64.AppImage --appimage-extract-and-run "$appdir" "$out"
```

- CI has no FUSE: use `--appimage-extract-and-run`.
- **Do not** download `continuous` appimagetool without a version pin + SHA256.
  `[OBSERVED — dikte weak point]`
- Optionally evaluate linuxdeploy + linuxdeploy-plugin-qt for automatic Qt
  plugin collection `[RECOMMENDED — NOT VERIFIED]`.

### Desktop integration (dikte pattern, use with judgment)

dikte self-installs a menu entry, autostart, hicolor icons and a
`~/.local/bin/dikte` symlink at first launch. Copy this only if your product
genuinely needs autostart/CLI integration; otherwise leave integration to the
desktop/AppImage integration tools. `[OBSERVED — dikte, project-specific]`

---

## 10. Linux GLIBC compatibility

`[REPEATED — CARA, dikte, pyzo]`

- Build on the **oldest distribution you support**. Ubuntu 22.04 (GLIBC ~2.35)
  is the oldest convenient GitHub-hosted runner these projects used. Newer
  bases raise the floor (CARA's 24.04 build needed GLIBC 2.38 and failed on
  Debian 12).
- Verify the real floor, don't assume it:

```bash
readelf --version-info build/dist/MyApp/myapp | grep -o 'GLIBC_[0-9.]*' | sort -u | tail
```

- The floor is often set by the Python/PyQt6 **wheels**, not just your code.
- GLIBC compatibility does not cover system graphics/audio libraries: test on
  real target distros and desktop sessions (X11 and Wayland).

---

## 11. Linux DEB

No studied project ships a `.deb`; this section is
`[RECOMMENDED — TEMPLATE — MUST BE TESTED]`. Two models exist; choose
deliberately.

### Model A — native distro-dependency package `[RECOMMENDED by CARA/pyzo/dikte tutorials]`

Small package, distro security updates, Debian-policy-compliant; needs
`python3-pyqt6` in the target distro.

```text
packaging/debian/
├── changelog
├── control
├── copyright
├── rules
├── source/format
├── myapp.install
└── myapp.desktop
```

`debian/control` (illustrative; verify names per release):

```debcontrol
Source: myapp
Section: utils
Priority: optional
Maintainer: Your Name <maintainer@example.org>
Build-Depends: debhelper-compat (= 13), dh-sequence-python3,
 pybuild-plugin-pyproject, python3-all, python3-build, python3-pyqt6
Standards-Version: 4.7.2
Rules-Requires-Root: no

Package: myapp
Architecture: all
Depends: ${misc:Depends}, ${python3:Depends}, python3-pyqt6
Description: short description
  Longer description of the application.
```

`debian/rules`:

```make
#!/usr/bin/make -f
%:
	dh $@ --buildsystem=pybuild
```

Build/test:

```bash
dpkg-buildpackage -us -uc -b
lintian ../myapp_1.2.3-1_all.deb
dpkg-deb --info ../myapp_1.2.3-1_all.deb
dpkg-deb --contents ../myapp_1.2.3-1_all.deb
# test in a clean container/VM:
sudo apt install ./myapp_1.2.3-1_all.deb
myapp --version
sudo apt remove myapp
sudo apt purge myapp
```

### Model B — bundled-runtime `.deb` `[RECOMMENDED by CustomKnight/napari tutorials]`

Consistent upstream runtime; large; upstream owns every security rebuild.
Disclose it as a bundled-runtime package, not a "normal Debian archive
package".

```text
mypackage/
├── DEBIAN/control
├── usr/bin/myapp                  # wrapper: exec /usr/lib/myapp/myapp "$@"
├── usr/lib/myapp/...              # PyInstaller/Nuitka standalone tree
├── usr/share/applications/myapp.desktop
├── usr/share/icons/hicolor/.../apps/myapp.png
└── usr/share/doc/myapp/copyright
```

`DEBIAN/control` (fat variant; depend only on system libs Qt needs):

```debcontrol
Package: myapp
Version: 1.2.3
Architecture: amd64
Maintainer: Your Name <maintainer@example.org>
Depends: libc6 (>= 2.35), libxcb-xinerama0, libxkbcommon-x11-0, libgl1, libegl1
Description: My PyQt6 application
  ...
```

```bash
dpkg-deb --build --root-owner-group mypackage   # -> myapp_1.2.3_amd64.deb
lintian myapp_1.2.3_amd64.deb
```

- Do not install a pip-created venv under system paths during `postinst`;
  build deterministic payloads before assembly. `[RECOMMENDED — dikte study]`
- Do not treat the AppImage payload as a drop-in `.deb` — different
  integration/dependency semantics.

### CI gotchas (observed on TBO, 2026) `[OBSERVED — TBO]`

1. **`dpkg-buildpackage` writes the artifacts (`.deb`, `.buildinfo`,
   `.changes`) to the PARENT directory** of the source tree, not to the
   workspace. A green job can silently upload nothing. Move them into the
   workspace before `actions/upload-artifact`:
   ```bash
   dpkg-buildpackage -b -uc -us
   mv ../myapp_*.deb ../myapp_*.buildinfo ../myapp_*.changes ./
   ```
2. **`dh_auto_test` fails for a Qt GUI package** because pybuild runs
   `python3.12 -m unittest discover` and the tests import `PyQt6`, which is a
   runtime dependency, not a build dependency. Skip tests during the package
   build (run them separately in CI):
   ```makefile
   override_dh_auto_test:
       @echo "Skipping dh_auto_test (Qt GUI tests need a display and PyQt6 at build time)"
   ```
 3. **`python3.12: No module named build`** — if you use
    `actions/setup-python`, the wheel build runs with the toolcache Python
    (which lacks `build`), not the system Python where the apt
    `python3-build` was installed. Add `python3 -m pip install build setuptools
    wheel` before `dpkg-buildpackage`.

### Audit the `.deb` before installing `[RECOMMENDED — TBO DEBIAN-PACKAGE-AUDIT.md]`

A green `dpkg-buildpackage` is not enough; audit the built `.deb` before
installing it with `gdebi`/`apt install`:

```bash
# 1. Static analysis (also run at the end of dpkg-buildpackage)
lintian myapp_1.2.3-1_all.deb

# 2. Inspect metadata (Architecture, Depends, Recommends)
dpkg-deb --info myapp_1.2.3-1_all.deb

# 3. Inspect contents (entry point, modules, assets, .desktop, metainfo,
#    icons, translations .qm)
dpkg-deb --contents myapp_1.2.3-1_all.deb

# 4. Verify dependencies without changing anything
apt install --dry-run ./myapp_1.2.3-1_all.deb

# 5. Install + smoke test, then verify checksums on disk
sudo apt install ./myapp_1.2.3-1_all.deb
myapp --help
sudo apt install debsums && debsums myapp    # empty output = files intact
```

Common harmless Lintian warnings for a GUI app: `initial-upload-closes-no-bugs`,
`no-manual-page`, `icon-size-and-directory-name-mismatch` (all exit 0). Stop and
fix any check that fails before moving to the next step.

---

## 12. macOS: .app, signing, notarization, DMG

### Pipeline `[REPEATED — CARA/pyzo/napari; RECOMMENDED sequence]`

```text
build .app (PyInstaller BUNDLE / Nuitka app bundle)
  -> add ALL resources and external helpers BEFORE signing
  -> sign nested code (inside-out), then the .app:
       Developer ID Application + --options runtime + --timestamp
  -> codesign --verify --deep --strict
  -> archive for submission (ditto zip or the DMG)
  -> xcrun notarytool submit ... --wait
  -> xcrun stapler staple <deliverable>
  -> spctl --assess (gate the release on "accepted")
  -> create DMG (sign/notarize if it is the final deliverable)
  -> test the exact downloaded artifact on a clean Mac
```

### Build the `.app`

```bash
pyinstaller --noconfirm --clean --windowed --onedir \
  --name MyApp --icon packaging/macos/myapp.icns \
  --osx-bundle-identifier org.example.MyApp \
  --add-data "src/myapp/resources:myapp/resources" \
  src/myapp/__main__.py
```

Set a stable `CFBundleIdentifier`, version fields, minimum OS, and `.icns` in
the spec's `BUNDLE` (or edit `Info.plist`). Add privacy usage descriptions
(microphone, camera, Apple Events) when used. `[OBSERVED — dikte]`

### Signing `[TEMPLATE — MUST BE TESTED; identity from a protected variable]`

```bash
identity="Developer ID Application: Example Publisher (TEAMID)"
app="build/dist/MyApp.app"

# Inside-out: sign nested helpers/dylibs/frameworks first, then the app.
codesign --force --options runtime --timestamp \
  --entitlements packaging/macos/entitlements.plist \
  --sign "$identity" "$app"

codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=4 "$app"
```

Minimal entitlements `[TEMPLATE — MUST BE TESTED; keep only what your app
needs]`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Add entries only if required by your app (e.g., some PyQt/JIT stacks). -->
</dict>
</plist>
```

- Prefer explicit inside-out signing over `codesign --deep` as the primary
  strategy; `--deep` is a convenience. `[RECOMMENDED — CARA/pyzo studies]`

### Notarization + stapling (API-key method, like napari)

```bash
ditto -c -k --keepParent build/dist/MyApp.app build/dist/MyApp-notary.zip

xcrun notarytool submit build/dist/MyApp-notary.zip \
  --key "$APPLE_NOTARIZATION_AUTHKEY" --key-id "$APPLE_NOTARIZATION_KEY_ID" \
  --issuer "$APPLE_NOTARIZATION_ISSUER_ID" --output-format json --wait --timeout 30m

xcrun stapler staple build/dist/MyApp.app
xcrun stapler validate build/dist/MyApp.app
spctl --assess --type execute --verbose=4 build/dist/MyApp.app   # must be accepted
```

CI-safe credential handling `[REPEATED — pyzo/napari]`:
- Store the base64 P12 (Developer ID) and the base64 `.p8` (notary API key) in
  GitHub secrets; decode and import into a **temporary keychain**; unlock,
  sign, discard.
- Never print certificate/password/key values.

### DMG `[OBSERVED — pyzo/dikte; RECOMMENDED flow]`

```bash
stage="build/dmg-stage"
mkdir -p "$stage"
cp -R build/dist/MyApp.app "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "MyApp 1.2.3" -srcfolder "$stage" -ov -format UDZO \
  build/dist/MyApp-1.2.3.dmg
```

If the DMG is the final deliverable, sign it, then notarize + staple the DMG
and test the exact downloaded DMG on a clean Mac. `[RECOMMENDED — NOT VERIFIED
in case studies]`

- Architecture: build arm64 and x86_64 separately unless you prove a universal2
  dependency stack. `[OBSERVED — dikte/pyzo]`

---

## 13. Qt plugins, resources, translations

### Plugins `[REPEATED — inspect output; never assume]`

PyInstaller hooks collect Qt plugins, but **every** study says the exact
inventory must be verified. Verify on a clean machine:

```bash
# Windows
dist\MyApp\MyApp.exe        # if "could not find platform plugin":
dir dist\MyApp\PyQt6\Qt6\plugins\platforms   # qwindows.dll must exist

# Linux
ldd dist/MyApp/myapp | grep -iE 'qt|not found'

# macOS
otool -L MyApp.app/Contents/Frameworks/* | grep Qt
```

Debug run with `QT_DEBUG_PLUGINS=1`. Exercise: GUI startup, PNG/SVG loading,
native file dialogs, printing, HTTPS/TLS if used, multimedia/SQL/QML/WebEngine
only if used. Keep the onedir layout intact inside AppImage/`.deb`/`.app`.

For Qt module curation, measure your app's real imports; do not copy dikte's or
pyzo's exclusion lists blindly. `[OBSERVED — project-specific]`

### Qt translations `[RECOMMENDED — the recurring gap; NOT VERIFIED in any
frozen project]`

Qt's own standard dialogs are translated only if `qtbase_<locale>.qm` files are
bundled AND a `QTranslator` is installed:

```python
from PyQt6.QtCore import QLibraryInfo, QLocale, QTranslator
from PyQt6.QtWidgets import QApplication

app = QApplication([])
translator = QTranslator(app)
translations_dir = QLibraryInfo.path(QLibraryInfo.LibraryPath.TranslationsPath)
if translator.load(QLocale.system(), "qtbase", "_", translations_dir):
    app.installTranslator(translator)
```

Bundle them: in the PyInstaller spec add the PyQt6 `translations` directory as
data (or `--collect-data PyQt6.QtCore`), and verify the frozen artifact.

### Resources

- Filesystem resources + the `resource_root()` helper (CARA pattern) for
  large/data files.
- Qt `.qrc` for small immutable UI assets if convenient; beware stale
  `:/...` references (CustomKnight's broken icon reference is the cautionary
  tale). `[OBSERVED]`

---

## 14. External binaries

When a frozen app launches host programs (ffmpeg, helper executables, engines),
the freezer's `LD_LIBRARY_PATH`/loader variables can leak into child processes
and make them load the bundle's incompatible libraries. `[OBSERVED — CARA,
dikte]`

- Pin + SHA-256-verify downloaded helpers before embedding (dikte pins FFmpeg).
- Restore the host loader environment and host CA trust store before invoking
  system programs, narrowly, around the child-process call.
- Add external helpers to a macOS `.app` **before** the final signature.

Example (conceptual, adapted from dikte) `[TEMPLATE — MUST BE TESTED]`:

```python
import os

def run_host_command(argv, env=None):
    env = dict(os.environ if env is None else env)
    # Remove freezer-injected loader variables so the child uses system libs:
    for var in ("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH"):
        env.pop(var, None)
    # Optionally point at the host trust store when the bundled CA path is broken.
    return subprocess.run(argv, env=env)
```

---

## 15. GitHub Actions

### Architecture `[REPEATED — dikte/pyzo/napari patterns combined]`

```text
tag v1.2.3
   -> tests (source, multi-version matrix)
   -> prepare_matrix (compute platforms)
   -> build (native matrix)
        windows:    onedir -> metadata -> sign inner -> Inno -> sign installer -> verify
        ubuntu-22.04: onedir -> AppDir -> appimagetool -> AppImage  (+ .deb)
        macos-arm64 / macos-x86_64: .app -> sign -> notarize -> staple -> spctl -> DMG
   -> artifact smoke tests (launch + log check)
   -> aggregate: SHA256SUMS (+ SBOM/attestations)
   -> GitHub Release (signed tag), upload all artifacts
```

### Reusable build workflow (fragment) `[TEMPLATE — MUST BE TESTED]`

```yaml
# .github/workflows/build.yml — reusable, like napari's workflow_call / dikte's matrix
name: build-artifacts

on:
  workflow_call:
    inputs:
      ref:
        required: true
        type: string
  pull_request:
    paths: ["packaging/**", ".github/workflows/build.yml"]

permissions:
  contents: read

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: windows-2022
            kind: windows
          - os: ubuntu-22.04
            kind: appimage
          - os: ubuntu-22.04
            kind: deb
          - os: macos-14
            kind: macos-arm64
          - os: macos-14-large
            kind: macos-x86_64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@<sha>          # pin to a reviewed commit SHA
        with: { ref: "${{ inputs.ref || github.sha }}" }
      - uses: actions/setup-python@<sha>
        with: { python-version: "3.12.10", cache: pip }   # choose your exact version
      - run: python -m pip install --require-hashes -r requirements/build-${{ matrix.kind }}.txt
      - run: python -m unittest discover      # or pytest
      - name: Build
        shell: bash
        run: ./scripts/build-${{ matrix.kind }}.sh
      - uses: actions/upload-artifact@<sha>
        with:
          name: myapp-${{ matrix.kind }}
          path: dist/*
          if-no-files-found: error
```

### Release workflow (fragment) `[TEMPLATE — MUST BE TESTED]`

```yaml
# .github/workflows/release.yml
name: release
on:
  push:
    tags: ["v*"]
permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@<sha>
        with: { path: artifacts }
      - name: Checksums
        run: |
          cd artifacts
          find . -type f -exec sha256sum {} \; > SHA256SUMS.txt
      - name: Create Release
        run: gh release create "$GITHUB_REF_NAME" artifacts/**/* --generate-notes
        env:
          GH_TOKEN: ${{ github.token }}
```

### Gating rules to copy

- Sign only on tag events **and** only when the required secrets are present
  (napari). `[OBSERVED — napari]`
- Build packaging on PRs touching `packaging/**` (dikte). `[OBSERVED — dikte]`
- Publish only from tags; verify the tag (`gh release create --verify-tag` —
  pyzo). `[OBSERVED — pyzo]`
- Pin actions to commit SHAs; add dependabot; consider zizmor; use
  least-privilege `permissions:`. `[OBSERVED — napari]`
- **Keep GitHub Actions on current major versions.** `checkout@v4`,
  `setup-python@v5`, `upload-artifact@v4` target Node.js 20, which is
  deprecated on GitHub runners (2025-09). Upgrade to `checkout@v5`,
  `setup-python@v6`, `upload-artifact@v5` to eliminate the warnings.
  `[OBSERVED — TBO, 2026]`
- Never expose signing secrets to untrusted PRs; use protected environments for
  release signing. `[RECOMMENDED]`

---

## 16. Checksums, SBOM, provenance

```bash
# After all signing/stapling is final (signing changes hashes):
cd dist
sha256sum MyApp-* > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt
```

- macOS: use `shasum -a 256` if GNU `sha256sum` is unavailable.
- Attach the SHA256SUMS file to the release (napari generates but doesn't attach
  its `.sha256` files — attach yours). `[RECOMMENDED — napari gap]`
- Add GitHub artifact attestations (`attest-build-provenance`) for free
  Sigstore-backed provenance. `[OBSERVED — napari for wheels]`
- Optionally generate an SBOM (`cyclonedx-py`, `pip-licenses`) and publish it;
  for a small project treat this as a "nice to have", not a gate.
  `[RECOMMENDED]`
- Distinguish what each control answers: SHA256 = "these bytes are expected";
  signature = "which identity approved them"; timestamp = "when";
  SBOM = "what is inside"; attestation = "which workflow produced this".

---

## 17. Testing procedures

### Every platform
- Install/launch on a clean supported machine with no dev Python/Qt on PATH.
- Test non-ASCII usernames and spaces in install paths.
- Test first run, second run, upgrade, uninstall/purge; settings preservation.
- Exercise every dynamically loaded Qt feature.
- Verify final hash and signature.

### Windows
- Inspect PE version info + manifest; confirm no console for `--windowed`.
- `signtool verify /pa /all /v` on inner EXEs, setup, and uninstaller.
- Install as a standard user; record Defender/SmartScreen behavior on the
  **final signed installer**.
- `[RECOMMENDED — dikte study]` Scan the final signed artifact, not an earlier
  unsigned build.

### AppImage
- `chmod +x MyApp.AppImage && ./MyApp.AppImage --version`
- Test on: oldest supported Ubuntu/Debian, current Ubuntu, Fedora-like, and a
  rolling distro; X11 and Wayland.
- `QT_DEBUG_PLUGINS=1`; `ldd`/`readelf` checks; host child tools must not
  inherit bundle libraries; CA store must work on Debian/Fedora/openSUSE/Arch
  layouts.

### DEB
- `dpkg-deb --info/--contents`; `lintian` without unexplained overrides.
- `sudo apt install ./myapp_1.2.3-1_all.deb`; `myapp --version`;
  `desktop-file-validate`; clean upgrade/remove/purge.

### macOS
- `codesign --verify --deep --strict --verbose=2`; `spctl` acceptance;
  `stapler validate`.
- Download through a browser so quarantine is present; test first launch,
  permissions (microphone/Accessibility/Apple Events), and an update.
- Mount/copy/launch the DMG on a clean supported Mac.

---

## 18. Release checklist

### WINDOWS
- [ ] Version updated
- [ ] Dependencies controlled (hashed lockfile)
- [ ] Build environment controlled (pinned Python/PyInstaller/Qt)
- [ ] Application built (onedir or standalone)
- [ ] Qt plugins verified
- [ ] Resources verified
- [ ] PE metadata + icon verified
- [ ] Antivirus scan performed (final signed artifact)
- [ ] Inner executables signed + timestamped
- [ ] Signatures verified
- [ ] Installer created
- [ ] Installer signed + timestamped
- [ ] Installer signature verified
- [ ] SHA256 generated
- [ ] Tested on clean Windows system

### LINUX APPIMAGE
- [ ] Build distribution selected (old GLIBC base)
- [ ] GLIBC floor verified (`readelf`)
- [ ] AppDir verified (AppRun, `.desktop`, icon, metainfo)
- [ ] Qt plugins verified
- [ ] appimagetool pinned + checksummed
- [ ] AppImage created
- [ ] AppImage tested on target distributions
- [ ] SHA256 generated

### LINUX DEB
- [ ] Debian metadata verified
- [ ] Dependencies verified
- [ ] Architecture verified
- [ ] Desktop integration verified
- [ ] `lintian` checked
- [ ] Installation tested
- [ ] Upgrade tested
- [ ] Removal/purge tested

### MACOS
- [ ] `.app` created (native per-architecture)
- [ ] Resources verified (no post-sign mutation)
- [ ] Qt frameworks/plugins verified
- [ ] External helpers added before signing
- [ ] Signing performed (Developer ID + hardened runtime + timestamp)
- [ ] Signature verified
- [ ] Notarization performed
- [ ] Stapling performed + validated
- [ ] `spctl` accepted
- [ ] DMG created (+ `/Applications` link)
- [ ] DMG tested on clean Mac
- [ ] SHA256 generated

### RELEASE
- [ ] Version consistent
- [ ] License file present in repo and bundled (Windows/macOS scripts copy it
      into the artifact)
- [ ] Changelog updated
- [ ] Artifacts smoke-tested in CI
- [ ] Checksums published (attached)
- [ ] Source code available
- [ ] Git tag created (signed/annotated)
- [ ] GitHub Release created
- [ ] Secrets never appear in logs

---

## 19. Controlled PyInstaller/Nuitka experiment

Goal: decide for **your app** whether PyInstaller vs Nuitka and onedir vs
onefile differ in antivirus/SmartScreen behavior, startup, size, and build
time — over several releases.

1. **Hold variables constant:** same source, Python, PyQt6, dependencies
   (same lockfile), metadata, icon, build environment, signing identity.
   No UPX.
2. **Build four arms:** PyInstaller onedir, PyInstaller onefile, Nuitka
   standalone, Nuitka onefile — each unsigned and signed.
3. **Record per arm:** artifact size, installed size, cold/warm startup (N
   runs), build time + log, PE/mach-O metadata, signature + verification,
   VirusTotal JSON (engines, categories, SHA-256), date.
4. **VirusTotal interpretation:** point-in-time heuristic signal, not a
   verdict; resubmit over releases; investigate engine names; never optimize
   to zero blindly.
5. **False positives:** submit to the vendor's official portal with the hash
   and source link; track responses.
6. **Signing:** run the protocol signed and unsigned; conclusions for signed
   artifacts do not transfer to unsigned ones.
7. **Reproducibility:** record hashes and logs so results are traceable.
8. **Decision:** keep the tool/mode only if it wins repeatably on your data.

---

*End of tutorial. All templates must be validated on your own environment and
targets. No credentials or private values are included in this document.*
