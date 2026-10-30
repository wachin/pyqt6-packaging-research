# PyQt6 Packaging Tutorial: Practical Guide for a New Open-Source Desktop Application

> A practical, reusable tutorial for packaging **PyQt6** desktop applications for
> Windows, Linux, and macOS — built from the lessons of the
> `napari/packaging` repository study (`PACKAGING_STUDY.md` in this folder) plus
> general packaging best practice.
>
> **How to read the labels**
> - **[FROM NAPARI]** = a technique taken directly from the napari repository.
> - **[GENERAL]** = general packaging knowledge / recommendation not sourced from
>   napari (and therefore not verified inside this repo).
> - Where napari and general advice conflict (e.g. Windows signing), I say so
>   explicitly.
>
> **Honesty disclaimer**: I do NOT claim any technique here guarantees zero
> VirusTotal detections or zero SmartScreen warnings. AV engines are opaque and
> change over time. Everything in this tutorial is about *legitimate, transparent
> distribution* that maximizes the chance of being treated as trustworthy software.

---

## Table of contents

1. [Decide your packaging strategy first](#1-decide-your-packaging-strategy-first)
2. [PyInstaller vs Nuitka — a realistic comparison](#2-pyinstaller-vs-nuitka--a-realistic-comparison)
3. [Windows](#3-windows)
4. [Antivirus false positives — legitimate mitigation](#4-antivirus-false-positives--legitimate-mitigation)
5. [Linux AppImage](#5-linux-appimage)
6. [Debian / Ubuntu `.deb`](#6-debian--ubuntu-deb)
7. [macOS](#7-macos)
8. [macOS code signing and notarization](#8-macos-code-signing-and-notarization)
9. [Qt translations and Qt plugins after freezing](#9-qt-translations-and-qt-plugins-after-freezing)
10. [Resources in PyQt6 applications](#10-resources-in-pyqt6-applications)
11. [GitHub Actions architecture](#11-github-actions-architecture)
12. [Security and release integrity](#12-security-and-release-integrity)
13. [The recommended end-to-end pipeline](#13-the-recommended-end-to-end-pipeline)
14. [Checklist before every release](#14-checklist-before-every-release)
15. [Command quick reference](#15-command-quick-reference)

---

## 1. Decide your packaging strategy first

Before writing any CI, decide the *category* of your app, because the right
tool depends on it.

| Your app… | Recommended path | Why |
|---|---|---|
| Plain desktop app, no plugin system, users just run it | **PyInstaller onedir or Nuitka standalone** + installers | Simple, well-trodden, small-ish bundles. |
| Scientific / has a plugin ecosystem that installs new Python packages at runtime | **conda/constructor installers** (napari's approach) | Frozen binaries are immutable; they cannot install new plugins. napari explicitly rejected Nuitka/PyOxidizer for this reason **[FROM NAPARI]** |
| You want users to install via their system package manager | `.deb`/rpm (Linux) + MSIX (Windows) + Homebrew (macOS) | Native integration; requires maintaining per-distro packaging. |

**The key napari lesson**: the packaging *technology* was chosen to fit the
*product requirements* (runtime plugin installs), not for convenience. Copy that
decision process, not the conclusion **[FROM NAPARI]**.

For the rest of this tutorial I assume the **first row** (plain PyQt6 desktop
app), which is the most common case and the one where PyInstaller/Nuitka shine.

---

## 2. PyInstaller vs Nuitka — a realistic comparison

Both tools are covered here. Neither is used by napari, so this section is
**[GENERAL]**, with the honest caveat that I have not benchmarked them inside this
repo. Verify with your own app.

### PyInstaller

- **Model**: bundles your bytecode + the Python interpreter + libraries into a
  directory (onedir) or a single executable (onefile). At runtime, onefile
  extracts everything to a temp dir (`sys._MEIPASS`).
- **Pros**:
  - Very mature, huge community, excellent PyQt6/PySide6 support via
    community hooks.
  - Fast builds (minutes).
  - Onedir mode is robust and debuggable (everything is on disk).
  - Widely documented; most tutorials online assume PyInstaller.
- **Cons**:
  - **Onefile** is slow to start (unpack every launch), triggers AV engines
    because of self-extracting behavior + lack of signature persistence.
  - Startup slower than Nuitka (bytecode + import overhead vs compiled).
  - Requires care with dynamic imports, data files, and Qt plugins (hooks help).
  - Onefile temp-dir extraction is a classic AV heuristic target.
- **Recommendation**: use **onedir**, not onefile. Then either ship the folder
  zipped, or wrap it in an installer.

### Nuitka

- **Model**: compiles Python to C, then to machine code; has `--standalone`
  (dir bundle) and `--onefile` modes.
- **Pros**:
  - Compiles to native code → faster startup and (sometimes) faster execution.
  - `--standalone` produces a self-contained folder; startup is fast because
    there is no per-launch unpacking.
  - Generally fewer "generic Python package" heuristics that AV engines flag.
  - Good PyQt6 support via `--enable-plugin=pyqt6`.
- **Cons**:
  - Builds are **slow** (compilation), especially the first time (cache helps).
  - Requires a C compiler toolchain on the build machine (MSVC on Windows,
    clang/Xcode CLT on macOS, gcc on Linux).
  - Binary larger than PyInstaller in many cases.
  - Slightly steeper learning curve; smaller community than PyInstaller.

### Decision guidance

- Prefer **PyInstaller onedir** when you value build speed, simplicity, and
  community support.
- Prefer **Nuitka standalone** when you value startup performance and want a
  different runtime profile that empirically (per your own VirusTotal testing)
  yields fewer false positives.
- **Test both on your actual app.** Measure: bundle size, startup time, build
  time, and — for your own information — upload result to VirusTotal and
  compare. Document the numbers.

> Important anti-pattern: **do not** pick onefile because it produces "one file".
> It is the worst of both worlds for AV reputation and startup performance.

---

## 3. Windows

### 3.1 The pipeline

```text
PyQt6 app source
    → venv + pinned deps
    → PyInstaller onedir (or Nuitka standalone)
    → metadata: version info (VS_VERSION_INFO), icon, manifest
    → (optional but recommended) sign the inner launcher exe
    → build installer (Inno Setup / NSIS) around the onedir
    → sign the installer
    → generate SHA256
    → GitHub Release
```

### 3.2 Virtual environment

```powershell
py -3.12 -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements.txt          # your app deps
pip install pyinstaller==<pinned>        # or nuitka==<pinned>
```

Pin **everything** (requirements with `==` or a lock file). Reproducible builds
matter for both trust and debugging **[FROM NAPARI: dependency hygiene]**.

### 3.3 PyInstaller onedir — minimal command

```powershell
pyinstaller `
  --noconfirm `
  --clean `
  --onedir `
  --windowed `                  # --noconsole: no console window for GUI app
  --name MyApp `
  --icon assets\app.ico `
  --version-file build\version_info.txt `
  --collect-all PyQt6 `
  --hidden-import PyQt6.QtNetwork `   # TLS/network plugins often missed
  myapp\__main__.py
```

- `--windowed`/`--noconsole`: GUI apps normally have no console window. On
  macOS this is implied. If you want console output for debugging, use console
  mode in dev, windowed in release.
- `--collect-all PyQt6` copies Qt's `platforms/`, `imageformats/`, `styles/`,
  `translations/`, `QtNetwork` support — a pragmatic hammer that avoids missing
  Qt plugins. Review the output size; trim later if you care about size.
- Better: write a **`.spec` file** (generated the first run with
  `pyinstaller --onedir --windowed myapp\__main__.py`), then edit it to add
  datas/binaries. The spec is your source of truth and goes in git.

### 3.4 A minimal `.spec` annotated

```python
# MyApp.spec  (generated by pyinstaller, hand-edited)
a = Analysis(
    ['myapp/__main__.py'],
    pathex=[],
    binaries=[],                          # extra native libs go here
    datas=[('assets', 'assets')],         # static files: (source, dest-in-bundle)
    hiddenimports=['PyQt6.QtNetwork'],    # modules PyInstaller can't see statically
    hookspath=[],
    excludes=['tkinter', 'numpy'],        # drop unused big modules
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz, a.scripts, a.binaries, a.datas,
    name='MyApp',
    console=False,                        # False = windowed
    icon='assets/app.ico',
    version='build/version_info.txt',     # VS_VERSION_INFO -> right-click Properties
    uac_admin=False,                      # leave False unless you truly need admin
    upx=False,                            # see section 4; keep UPX OFF
)
```

**Key points**:
- `console=False` ⇔ `--windowed`.
- `version=` gives the exe proper Windows file properties (company, version,
  description). A **consistent publisher identity + version metadata** is part
  of legitimate trust-building **[GENERAL + FROM NAPARI: they sign with a
  consistent org identity]**.
- `upx=False` is deliberate — see section 4.

### 3.5 Windows metadata (version_info.txt)

```text
VSVersionInfo(
  ffi=FixedFileInfo(filevers=(1, 2, 0, 0), prodvers=(1, 2, 0, 0),
    mask=0x3f, flags=0x0, OS=0x40004, fileType=0x1, subtype=0x0, date=(0, 0)),
  kids=[
    StringFileInfo([StringTable('040904B0', [
      StringStruct('CompanyName', 'Your Org'),
      StringStruct('FileDescription', 'MyApp'),
      StringStruct('FileVersion', '1.2.0'),
      StringStruct('InternalName', 'MyApp'),
      StringStruct('OriginalFilename', 'MyApp.exe'),
      StringStruct('ProductName', 'MyApp'),
      StringStruct('ProductVersion', '1.2.0')])]),
    VarFileInfo([VarStruct('Translation', [1033, 1200])])
  ])
```

### 3.6 Installer: Inno Setup (recommended) vs NSIS

Both are free, scriptable, and work from CI. Inno Setup is generally easier to
read/maintain; NSIS is what conda's `constructor` uses under the hood for its
Windows EXEs **[FROM NAPARI]**.

**Inno Setup example** (`installer.iss`):

```ini
[Setup]
AppId={{MY-GUID}
AppName=MyApp
AppVersion=1.2.0
DefaultDirName={localappdata}\MyApp
PrivilegesRequired=lowest           ; per-user install → no UAC, fewer AV flags
OutputDir=dist
OutputBaseFilename=MyApp-Setup-1.2.0
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SignTool=signtool $f

[Files]
Source: "dist\MyApp\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{autoprograms}\MyApp"; Filename: "{app}\MyApp.exe"
```

**NSIS** equivalent is possible with `makensis` and the `!include` macros.

### 3.7 Two signing moments

napari demonstrates **two distinct signing events** on Windows **[FROM NAPARI]**:
1. Signing applied *by the builder* (their Apple-cert PFX via constructor).
2. A *post-build* proper signature via Azure Code Signing, plus **verification**
   and **SHA256 generation** that **fail the job** if invalid
   (`Get-AuthenticodeSignature -ne 'Valid'` → exit 1).

For you:
- **Sign the installer only** is the minimum (most users see the installer).
- **Signing the inner launcher exe too** is better (if users bypass the
  installer / run the exe directly, it is also signed). Note: re-signing an
  already-signed exe invalidates prior signatures — sign inner exe during the
  PyInstaller/Nuitka step, then sign the installer last.
- Use `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f
  cert.pfx /p <pwd>` on the exe, then sign the installer.
- Add a **timestamp** — untimestamped signatures expire.

Sequence (correct order):

```text
PyInstaller onedir
   → MyApp.exe  (optional: sign now with inner-exe cert)
   → Inno Setup compiles installer.iss  (can sign inner exe itself too)
   → sign MyApp-Setup.exe
   → Get-AuthenticodeSignature verification
   → SHA256 checksum
   → upload
```

---

## 4. Antivirus false positives — legitimate mitigation

> Hard truth first: **no legitimate technique can guarantee zero detections**,
> and anyone who promises otherwise is wrong. Antivirus engines use heuristics,
> reputation, and signatures. New/unknown unsigned binaries from the internet are
> exactly what they are trained to suspect.

What *legitimately* helps, ordered roughly by impact **[GENERAL]**, with the
napari-supported ones marked:

1. **Code signing with a trusted certificate** — the single strongest signal of
   legitimacy. Windows SmartScreen specifically trusts signed binaries from
   publishers with reputation. **[FROM NAPARI: they sign macOS fully and Windows
   on releases precisely to get trust; they acknowledge the unsigned/Apple-signed
   nightlies keep the warnings.]**
2. **Consistent identity + version metadata** in every exe (publisher name,
   product, version, icon). Metadata that matches your public GitHub org is
   verifiable by users/analysts. **[GENERAL; aligns with napari's org-identity
   signing]**
3. **Build from clean, reproducible, public CI** (GitHub Actions) — provenance
   is publicly auditable. Publish source, build config, lockfiles, and
   checksums. **[FROM NAPARI: public source, public workflows, release
   lockfiles/checksums.]**
4. **Avoid UPX / extra compression on the exe.** UPX-packed PyInstaller
   executables are a notorious AV trigger because packing matches packer
   heuristics. Keep `upx=False` (PyInstaller default is on if UPX is on PATH —
   set it explicitly false). **[GENERAL, widely reported; napari uses no UPX at
   all]** — note: this is correlation, not proof, but avoiding it is free.
5. **Prefer onedir over onefile.** Onefile self-extracts to temp and then runs —
   behavior closely matching malicious droppers. Onedir is just files on disk.
   **[GENERAL; napari ships a full on-dir-style prefix, not a self-extracting
   bundle]**
6. **Use current stable packaging tools.** Old PyInstaller/Nuitka versions
   bundle old Python/bootloaders that engines have already fingerprinted.
7. **Submit false positives to vendors.** When a legitimate build is flagged,
   submit the file to the vendor (Microsoft, ESET, etc.) with source URL,
   checksums, and signing info. This builds reputation over time. This is a
   process, not a one-time fix.
8. **Build an install base / release frequently** — reputation comes from
   downloads + clean scans over time.

**What I explicitly do NOT recommend** (obfuscation/evasion): runtime packers
like VMProtect, crypters, binary scramblers, code obfuscators, signing with
"your own CA" (no trust chain), or buying cheap certs from gray-market CAs. These
either get flagged harder or are transparent fraud.

### Nuitka vs PyInstaller for AV

Your stated experience (fewer problems with Nuitka) is a **common** anecdote but
**not proven** in this repo (napari uses neither). Plausible mechanisms **[GENERAL
, REASONED NOT VERIFIED]**:
- Nuitka emits native code → fewer Python-interpreter/bootloader heuristics.
- Nuitka's `--standalone` has no onefile self-extract, and (by default) no UPX.

If AV reputation is a primary concern for you, **build with both tools, scan
both, keep the data**. Do not assume Nuitka is universally better.

---

## 5. Linux AppImage

### 5.1 Strategy

```text
Build on an OLD distro container (manylinux style)
   → PyInstaller onedir / Nuitka standalone
   → AppDir assembly (linuxdeploy or manual)
   → Qt plugins/icons/desktop file
   → appimagetool → MyApp.AppImage
   → test on fresh Ubuntu + Fedora + a rolling distro
```

### 5.2 The glibc problem (the #1 AppImage pitfall)

An AppImage only works on systems whose **glibc ≤ the glibc it was built with**
(and matching architecture). If you build on Ubuntu 24.04, users on Ubuntu 20.04
or Debian 10 may get "version `GLIBC_2.38' not found".

Best practices **[GENERAL]**:
- Build inside an old container, e.g.
  `quay.io/pypa/manylinux2014_x86_64` (CentOS 7 / glibc 2.17) or
  `quay.io/pypa/manylinux_2_28_x86_64` (AlmaLinux 8 / glibc 2.28), or an
  Ubuntu 20.04 Docker image.
- **Check your glibc floor explicitly**: `readelf --version-info
  dist/MyApp/MyApp | grep -o 'GLIBC_[0-9.]*' | sort -u | tail`. This shows the
  max glibc version your binary needs. Aim for 2.17-2.31.
- Note: **Qt/PyQt6 wheels are built for specific glibc/manylinux tags** — your
  floor is often set by the *wheels*, so inspect both the wheels and your own
  native deps.
- This is the exact problem conda avoids by shipping its own libraries with a
  declared `__glibc` minimum and refusing to install below it **[FROM NAPARI,
  analogous]**.

### 5.3 AppDir structure

```text
MyApp.AppDir/
├── AppRun                 # launcher script (finds AppDir, sets env)
├── MyApp.desktop          # desktop entry (Name, Exec=MyApp, Icon=myapp)
├── myapp.png (or .svg)    # icon referenced by .desktop
└── usr/
    ├── bin/MyApp          # the frozen app (PyInstaller onedir usually goes here)
    └── lib/               # libs not already in the bundle
```

**Assembling** (two common routes):

Route A — **linuxdeploy + linuxdeploy-plugin-qt** (auto Qt plugin bundling):

```bash
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
export OUTPUT=MyApp.AppImage
export VERSION=1.2.0
./linuxdeploy-x86_64.AppImage \
  --appdir MyApp.AppDir \
  --executable dist/MyApp/MyApp \
  --desktop-file MyApp.desktop \
  --icon-file assets/myapp.png \
  --plugin qt
```

`linuxdeploy-plugin-qt` finds the Qt libraries and copies `platforms/`,
`imageformats/`, `translations/`, etc. into the AppDir, and sets
`QT_PLUGIN_PATH` via AppRun. **[GENERAL]**

Route B — **manual AppDir** (full control, no plugin):

```text
MyApp.AppDir/usr/bin/ = contents of PyInstaller onedir (or symlink)
MyApp.AppDir/AppRun = script that does:
    APPDIR=$(dirname "$(readlink -f "$0")")
    export LD_LIBRARY_PATH="$APPDIR/usr/lib:$LD_LIBRARY_PATH"
    export QT_PLUGIN_PATH="$APPDIR/usr/plugins"
    exec "$APPDIR/usr/bin/MyApp" "$@"
```

**AppRun script** is essential — it sets the environment so the app finds Qt
and its own libs regardless of where the AppImage is mounted.

### 5.4 .desktop file

```ini
[Desktop Entry]
Type=Application
Name=MyApp
Exec=MyApp
Icon=myapp
Categories=Utility;
Comment=My PyQt6 application
Terminal=false
```

### 5.5 Build the AppImage

```bash
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
ARCH=x86_64 ./appimagetool-x86_64.AppImage MyApp.AppDir
```

### 5.6 Testing

- Test on at least: an old Ubuntu LTS, current Ubuntu, Fedora, and a rolling
  distro. Use a VM or container per distro: `docker run --rm -v
  $PWD:/app ubuntu:20.04 bash -c "/app/MyApp.AppImage --version"`.
- **Note**: AppImage in Docker requires `--appimage-extract-and-run` or FUSE
  setup.
- Verify the desktop file with `desktop-file-validate`, and AppStream with
  `appstreamcli validate` if you ship AppStream metadata.

**AppImage vs napari**: napari ships a conda `.sh` installer for Linux instead.
AppImage is the right choice for "portable double-clickable app"; a `.sh`/`.deb`
is better for "properly installed app with menu entry".

---

## 6. Debian / Ubuntu `.deb`

### 6.1 Two fundamentally different strategies

**A. Depend on distro packages** (thin `.deb`):

```text
Depends: python3, python3-pyqt6, python3-pyqt6.qtquick
```

- Tiny `.deb`, gets updates from distro, integrates with apt.
- **Problem**: `python3-pyqt6` is only packaged in newer distros (Ubuntu 22.04+,
  Debian 12+). You must build separate `.deb`s per distro/version, and you depend
  on distro Python versions. For an app distributed to many distros this is a
  maintenance burden.

**B. Bundle the runtime** (fat `.deb`, like napari bundles via conda **[FROM
NAPARI philosophy: ship Python+Qt yourself]**):

```text
/usr/lib/myapp/   ← PyInstaller onedir or Nuitka standalone (self-contained)
/usr/bin/myapp    ← wrapper script → exec /usr/lib/myapp/myapp "$@"
/usr/share/applications/myapp.desktop
/usr/share/icons/hicolor/512x512/apps/myapp.png  (or svg)
/usr/share/doc/myapp/copyright
```

- Works on any distro with glibc ≥ your build floor. No Python/Qt dependency on
  the system.
- Downside: bigger, and you own security updates for bundled Python/Qt.

For a new open-source PyQt6 app I recommend **B** (bundle) with the AppImage as
an alternative download.

### 6.2 Package layout

```text
myapp_1.2.0_amd64/
├── DEBIAN/control
├── DEBIAN/postinst        (optional: update icon cache, etc.)
├── usr/bin/myapp
├── usr/lib/myapp/**       (frozen app)
├── usr/share/applications/myapp.desktop
├── usr/share/icons/hicolor/512x512/apps/myapp.png
└── usr/share/doc/myapp/copyright
```

`DEBIAN/control` (thin variant shown; for fat variant drop the python Depends):

```text
Package: myapp
Version: 1.2.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Your Name <you@example.org>
Depends: libc6 (>= 2.31)
Description: My PyQt6 application
 Long description that fits on one line here and continues.
Homepage: https://github.com/you/myapp
```

`usr/bin/myapp` wrapper:

```bash
#!/bin/sh
exec /usr/lib/myapp/myapp "$@"
```

`usr/share/applications/myapp.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=MyApp
Exec=/usr/bin/myapp
Icon=myapp
Categories=Utility;
Terminal=false
```

### 6.3 Build, version, and test

```bash
# Build (fat .deb, no dpkg-buildpackage needed for simple case)
dpkg-deb --build --root-owner-group myapp_1.2.0_amd64

# Inspect
dpkg-deb --info myapp_1.2.0_amd64.deb
dpkg-deb --contents myapp_1.2.0_amd64.deb

# Lint (catch packaging errors)
lintian myapp_1.2.0_amd64.deb

# Install & test in a container to avoid polluting your host
docker run --rm -v "$PWD":/app ubuntu:24.04 bash -c "
  dpkg -i /app/myapp_1.2.0_amd64.deb || apt-get install -f -y
  myapp --version
  desktop-file-validate /usr/share/applications/myapp.desktop
"
```

Version policy: use strict `major.minor.patch` for `Version:`. For pre-releases,
Debian needs suffixes like `1.2.0~rc1` (tilde sorts before the release).

**Desktop integration**: the `.desktop` + icon in `/usr/share` gives you the app
launcher entry, icon, and (with proper `Categories`/`MimeType`) file associations.
Run `update-desktop-database` and `gtk-update-icon-cache` in `postinst` for
best behavior.

---

## 7. macOS

### 7.1 Strategy

napari does **not** produce an `.app`; it produces a signed+notarized `.pkg`
that installs a conda prefix and a `~/Applications/napari.app` shortcut
**[FROM NAPARI]**. For a plain PyQt6 app, the more standard route is a real
`.app` bundle + DMG:

```text
PyQt6 app
   → PyInstaller onedir (or Nuitka standalone)  → MyApp.app
   → Info.plist edits (CFBundle*, icons, high-res capable)
   → .icns icon
   → codesign (Developer ID Application, hardened runtime, entitlements)
   → notarize (notarytool) → staple
   → create DMG (hdiutil or create-dmg)
   → sign DMG (optional but recommended)
   → GitHub Release
```

### 7.2 Application bundle structure

PyInstaller/Nuitka generate this automatically:

```text
MyApp.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/MyApp            # the executable (launcher)
│   ├── Resources/             # icon.icns, translations, data
│   └── Frameworks/            # Qt + Python frameworks (in a frozen bundle)
```

Key `Info.plist` entries **[GENERAL + FROM NAPARI: they use reverse-domain ids,
e.g. `org.napari`]**:

```xml
<key>CFBundleIdentifier</key> <string>org.yourorg.MyApp</string>
<key>CFBundleName</key>       <string>MyApp</string>
<key>CFBundleDisplayName</key><string>MyApp</string>
<key>CFBundleVersion</key>    <string>1.2.0</string>
<key>CFBundleShortVersionString</key><string>1.2.0</string>
<key>CFBundleIconFile</key>   <string>icon</string>   <!-- icon.icns in Resources -->
<key>CFBundleExecutable</key> <string>MyApp</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>11.0</string>
```

For PyInstaller, put overrides in the spec via `info_plist=`. For Nuitka, use
`--macos-app-icon` and `--macos-app-version` and post-edit `Info.plist`.

### 7.3 .icns

```bash
# Create icon set
mkdir icon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s assets/app.png --out icon.iconset/icon_${s}x${s}.png
  s2=$((s*2))
  sips -z $s2 $s2 assets/app.png --out icon.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns icon.iconset -o icon.icns
```

### 7.4 DMG

```bash
hdiutil create -volname "MyApp" -srcfolder MyApp.app \
  -ov -format UDZO MyApp-1.2.0.dmg
```

Or use `create-dmg` for a nicer layout with symlink to /Applications. A DMG made
from a signed+notarized `.app` should be **notarized itself** (you can staple the
ticket to the DMG). Sign the DMG with `codesign -s "Developer ID Application"` as
well for best results.

---

## 8. macOS code signing and notarization

> Requires an **Apple Developer account** (paid, $99/yr) with Developer ID
> certificates. There is no free path to "no warning" on macOS.
> napari's exact sequence is reproduced below because it is a complete, working
> reference **[FROM NAPARI: make_bundle_conda.yml:416-455, 534-585]**.

### 8.1 Prerequisites (one-time, on your machine)

1. Create a **Developer ID Application** cert and a **Developer ID Installer**
   cert in the Apple Developer portal, export both as `.p12`.
2. Create an **App Store Connect API key** (Users & Access → Integrations) —
   gives you `issuer ID`, `key ID`, and a `.p8` file. This replaces the old
   `altool` username/password flow (napari migrated to `notarytool` for exactly
   this reason **[FROM NAPARI]**).

### 8.2 Sign the .app (Hardened Runtime recommended)

```bash
codesign --force --deep --options runtime \
  --entitlements build/entitlements.plist \
  --sign "Developer ID Application: Your Name (TEAMID)" MyApp.app
codesign --verify --deep --strict MyApp.app
spctl --assess --type execute MyApp.app   # must be accepted
```

`entitlements.plist` — keep minimal; add only what your app needs:

```xml
<dict>
  <key>com.apple.security.cs.allow-jit</key><true/>       <!-- PyInstaller/Nuitka JIT? usually not needed -->
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>  <!-- some apps need this; see notes -->
</dict>
```

> Note on `--deep`: it is discouraged by Apple for complex bundles but commonly
> used by frozen Python apps. PyInstaller docs recommend signing the framework
> dylibs first, then the whole app without `--deep` in newer setups. Test with
> `spctl`. If your PyInstaller app crashes on other Macs, it is usually a signing
> or notarization problem; check `codesign --verify --deep --strict` and the
> hardened-runtime flags.

### 8.3 Notarize + staple (CI or local)

```bash
# 1. Package the app for submission (zip or dmg; dmg preferred)
ditto -c -k --keepParent MyApp.app MyApp.zip

# 2. Submit (notarytool, API key)
xcrun notarytool submit MyApp.zip \
  --key AuthKey_XXXX.p8 --key-id KEYID --issuer ISSUERID \
  --wait --timeout 30m

# 3. Staple the ticket to the app
xcrun stapler staple MyApp.app

# 4. Verify
spctl --assess --type execute --verbose=4 MyApp.app   # should say "accepted"
```

napari additionally validates the PKG signature *before* notarizing
(`pkgutil --check-signature`) and greps `spctl` output for `accepted` so the CI
fails loudly if notarization didn't take **[FROM NAPARI]**.

### 8.4 Sequence for a DMG release

```text
build MyApp.app → sign .app → notarize .app → staple .app
→ hdiutil create DMG (from signed .app) → codesign DMG
→ notarytool submit DMG → stapler staple DMG → release
```

**What needs an Apple Developer account**: creating Developer ID certificates,
notarization (submission + API key). Signing itself (`codesign`) works without an
account but produces no trust.

---

## 9. Qt translations and Qt plugins after freezing

### 9.1 Qt plugins (the classic "why does my frozen app crash on other machines?")

With **PyInstaller**, `--collect-all PyQt6` (or the PyQt6 hooks) copies:
`PyQt6/Qt6/plugins/platforms/` (qwindows, qminimal, qoffscreen),
`imageformats/`, `styles/`, `tls/`, `networkinformation/`, `iconengines/`.
With **Nuitka**, `--enable-plugin=pyqt6` does the same.

Verify after freezing:

```bash
# Windows
dist/MyApp/MyApp.exe        # if it crashes with "could not find or load the Qt platform plugin"
#   → check dist/MyApp/PyQt6/Qt6/plugins/platforms/qwindows.dll exists
#   → ensure QT_PLUGIN_PATH or the PyInstaller _MEIPASS resolution works

# Linux
ldd dist/MyApp/MyApp | grep -iE 'qt|not found'        # look for "not found"

# macOS
otool -L MyApp.app/Contents/Frameworks/* | grep Qt
```

With PyInstaller onedir, plugins live in the bundle next to `PyQt6`; at runtime
`QtPluginLoader` searches relative to the Qt libs, which works because they're
all in the bundle. For AppImage/`.deb`/`.app`, the onedir travels inside the
container, so plugin discovery keeps working. **Keep the onedir layout intact** —
never flatten it.

### 9.2 Qt's own translations (Open/Save/Print dialogs, standard buttons)

Qt's standard dialogs are translated by `qtbase_<lang>.qm` files (and friends),
which live in the Qt `translations/` directory. **After freezing these are NOT
picked up automatically.**

- **PyInstaller**: `--collect-all PyQt6` includes `translations/qtbase_*.qm`.
  Set the search path if needed:
  ```python
  from PyQt6.QtCore import QLibraryInfo, QCoreApplication, QTranslator
  # In frozen apps QLibraryInfo.translationsPath() may point to a non-existent
  # path; resolve manually:
  base = Path(getattr(sys, '_MEIPASS', Path(__file__).parent))
  qm_dir = base / 'PyQt6' / 'Qt6' / 'translations'
  ```
- **Nuitka**: `--include-data-files=$QT_TRANSLATIONS_DIR=translations` or use
  `--enable-plugin=pyqt6` which usually covers it.
- AppImage / `.deb`: the translations folder must be shipped inside the AppDir /
  `/usr/lib/myapp`.

**Best practice**: bundle `qtbase_*.qm` for the locales you support, and install
a `QTranslator` at startup. If you have your own strings, use `.ts` → compiled
`.qm` (via `pylupdate6`/`lrelease`) and ship those too **[GENERAL; napari relies
on conda packages to carry Qt translations, so it has no such code]**.

---

## 10. Resources in PyQt6 applications

### 10.1 Two options

1. **Qt Resource System (`.qrc` → `_rc.py`)** — compile resources into Python:
   ```bash
   pyside6-rcc resources.qrc -o resources_rc.py   # PySide6
   pyrcc6 resources.qrc -o resources_rc.py        # PyQt6
   ```
   - Pros: single import, works identically frozen/unfrozen, no path handling.
   - Cons: everything in RAM, not lazy-loadable, rebuild step.

2. **Filesystem resources** — ship real files (PNG/SVG/JSON/.ui/fonts/.qm).
   - Development: resolve relative to a source folder.
   - Frozen: resolve relative to the bundle root:
     ```python
     import sys
     def resource_root() -> Path:
         if getattr(sys, 'frozen', False):
             return Path(getattr(sys, '_MEIPASS', Path(sys.executable).parent))
         return Path(__file__).parent.parent / 'assets'
     ```

For a frozen desktop app, **filesystem resources with a `resource_root()` helper**
are more maintainable and avoid huge `_rc.py` files. Use the Qt resource system
for tiny, always-needed assets (icons) only.

### 10.2 napari's approach (worth noting)

napari downloads its branding icons at build time and generates installer
graphics with Pillow; resources live in conda packages at runtime
**[FROM NAPARI, build_installers.py:124-134, 178-211]**. For a frozen app you
instead ship them inside the bundle at build time (PyInstaller `datas=`, Nuitka
`--include-data-dir=`).

---

## 11. GitHub Actions architecture

Reusable architecture (mirrors napari's workflow_call + matrix + gated signing
**[FROM NAPARI]**):

```text
                     git tag v1.2.0
                        │
             ┌──────────┴───────────┐
             │   release.yml (in app repo)  │
             └──────────┬───────────┘
                        │  calls packaging workflow (workflow_call)
        ┌───────────────┼───────────────┐
        │               │               │
   Windows           Linux            macOS
        │               │               │
   PyInstaller       build in old      PyInstaller
   onedir            container →       → MyApp.app
        │            AppDir → AppImage │
   installer(ISS)        + .deb        codesign
        │                               │
   sign + verify                     notarize + staple
        │               │               │
   SHA256 checksums   SHA256 checksums  SHA256 checksums
        └───────────────┼───────────────┘
                        │
                 GitHub Release
              (gh release create + upload assets)
```

### 11.1 Template — caller in your app repo

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']
  workflow_dispatch:

jobs:
  build:
    uses: yourorg/packaging/.github/workflows/build.yml@main
    secrets: inherit
    with:
      event_name: ${{ github.event_name }}
```

### 11.2 Template — reusable build workflow

```yaml
# .github/workflows/build.yml  (in a packaging repo, like napari/packaging)
on:
  workflow_call:
    inputs:
      event_name: {type: string, required: true}
      platforms: {type: string, required: false, default: "win-64,linux-x64,macos-arm64,macos-x64"}
    secrets:
      MACOS_CERT_BASE64:
      MACOS_CERT_PASSWORD:
      MACOS_NOTARIZATION_ISSUER_ID:
      MACOS_NOTARIZATION_KEY_ID:
      MACOS_NOTARIZATION_AUTHKEY_BASE64:
      WIN_SIGNING_CERT_BASE64:     # your own Windows cert, unlike napari's stopgap
      WIN_SIGNING_PASSWORD:

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.m.outputs.matrix }}
    steps:
      - id: m
        shell: python
        run: |
          import json, os
          all = {
            "win-64":      {"os": "windows-2025",    "python": "3.12"},
            "linux-x64":   {"os": "ubuntu-24.04",    "python": "3.12"},
            "macos-arm64": {"os": "macos-15",        "python": "3.12"},
            "macos-x64":   {"os": "macos-15-intel",  "python": "3.12"},
          }
          wanted = {p.strip() for p in "${{ inputs.platforms }}".split(",")}
          matrix = {"include": [v for k,v in all.items() if k in wanted]}
          with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write(f"matrix={json.dumps(matrix)}\n")

  build:
    needs: prepare
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.prepare.outputs.matrix) }}
    steps:
      - uses: actions/checkout@<sha>            # pin to SHA!
      - uses: actions/setup-python@<sha>
        with: {python-version: ${{ matrix.python }}}
      - run: pip install -r requirements.txt pyinstaller
      - run: pyinstaller --noconfirm --clean --onedir --windowed MyApp.spec
      # ... platform-specific installer/signing steps (below) ...

      - name: Test the artifact (Linux)
        if: runner.os == 'Linux'
        run: dist/MyApp/MyApp --version

      - name: Test the artifact (macOS)
        if: runner.os == 'macOS'
        run: dist/MyApp.app/Contents/MacOS/MyApp --version

      - name: Test the artifact (Windows)
        if: runner.os == 'Windows'
        run: dist/MyApp\MyApp.exe --version

      - name: Compute artifact name
        id: art
        run: |
          echo "name=MyApp-${{ github.ref_name }}-${{ runner.os }}-${{ matrix.os }}" >> "$GITHUB_OUTPUT"

      - uses: actions/upload-artifact@<sha>
        with:
          name: ${{ steps.art.outputs.name }}
          path: dist/

      - name: Upload to GitHub Release (tag only)
        if: inputs.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')
        uses: actions/upload-release-asset@<sha>
        with:
          upload_url: ${{ needs.release-info.outputs.upload_url }}  # from a release job
          asset_path: ...
```

> Important **[FROM NAPARI]**: gates like `if: inputs.event_name == 'push' &&
> startsWith(github.ref, 'refs/tags/v')` are how napari restricts signing and
> release-upload to final releases (they even documented a shared-certificate
> quota as the reason). Copy this pattern.

> **Untested disclaimer**: these YAML fragments are templates, not proven
> configurations. Adapt and test them against your own repo.

---

## 12. Security and release integrity

Practices worth adopting (napari-supported ones marked **[FROM NAPARI]**):

- **Pin every GitHub Action to a full commit SHA** + comment version. `[FROM NAPARI]`
- **Dependabot** for actions and pip, grouped updates. `[FROM NAPARI]`
- **zizmor** (or similar) to lint your workflows for insecure patterns;
  use least-privilege `permissions:`. `[FROM NAPARI]`
- **Lock files / pinned requirements** so builds are reproducible. `[FROM NAPARI (lockfiles); GENERAL for pip]`
- **Publish SHA256 checksums** per artifact and *attach them to the release*
  (napari generates them but doesn't attach them — attach yours). `[FROM NAPARI + fix its gap]`
- **Sign release artifacts** (macOS fully; Windows with a real cert). `[FROM NAPARI]`
- **GitHub artifact attestations** (`attest-build-provenance`) for your wheels /
  binaries where possible (napari uses it for the Python package). `[FROM NAPARI, partial]`
- **License collection**: gather third-party licenses into the release (napari
  builds a `licenses.zip`). For an AppImage/.deb you can embed a
  `THIRD_PARTY_LICENSES.txt` generated from `pip-licenses`. `[FROM NAPARI]`
- **SBOM**: generate one (e.g. `cyclonedx-py`) per release. Not done by napari;
  a good addition. `[GENERAL]`
- **Git tag signing**: sign your release tags (annotated + `-S`). Cheap and
  verifiable. `[GENERAL]`
- **No secrets in repo**: store certs as base64 in secrets; decode only in CI.
  Never print values. `[FROM NAPARI]`

---

## 13. The recommended end-to-end pipeline

Concrete, per platform, for a new open-source PyQt6 app:

```text
SOURCE (PyQt6 + QtPy optional)
  │
  ├─ Windows
  │    PyInstaller onedir --windowed (+version_info, icon, upx=False)
  │    → MyApp.exe  (optional sign inner exe)
  │    → Inno Setup installer.iss
  │    → signtool sign installer (real cert, SHA256, timestamp)
  │    → Get-AuthenticodeSignature verify (fail job on != Valid)
  │    → sha256sum
  │    → release asset
  │
  ├─ Linux
  │    build inside old-glibc container (manylinux2014 / Ubuntu 20.04)
  │    → PyInstaller onedir
  │    → linuxdeploy + linuxdeploy-plugin-qt → AppDir
  │    → appimagetool → MyApp-x86_64.AppImage
  │    → dpkg-deb fat .deb (usr/lib/myapp + .desktop + icons)
  │    → lintian + container install test
  │    → sha256sum ×2
  │    → release assets
  │
  └─ macOS
       PyInstaller onedir → MyApp.app (Info.plist, .icns)
       → codesign --options runtime (Developer ID Application)
       → ditto zip → notarytool submit → stapler staple
       → spctl verify (fail job on not accepted)
       → hdiutil DMG → codesign DMG → notarize DMG → staple DMG
       → sha256sum
       → release asset
```

**Windows signing decision — the honest version [FROM NAPARI + GENERAL]**:
napari signs Windows releases with an org-shared certificate but their nightlies
remain Apple-signed (untrusted). For a new project:
- Buy an **OV code-signing cert** (≈$200-300/yr, usually requires a USB token /
  hardware-key or cloud signing) or use a **free-for-OSS scheme** like
  **SignPath Foundation** or **Azure Trusted Signing for open source** where
  available. These are the legitimate routes to a SmartScreen-trusting
  signature.
- If you cannot get a cert, be transparent: unsigned binaries + public source +
  checksums + a false-positive-submission process. Do **not** sign with a
  mismatched certificate (napari's Apple-cert stopgap is explicitly a temporary
  hack, acknowledged in the workflow comment `make_bundle_conda.yml:470-472`).

---

## 14. Checklist before every release

- [ ] Clean CI build from pinned deps (no `latest`, no mutable refs).
- [ ] Windows exe has version info + icon; UPX disabled.
- [ ] Windows installer signed; signature verified in CI; SHA256 generated.
- [ ] macOS app codesigned (hardened runtime), notarized, stapled; `spctl`
      says accepted.
- [ ] Linux built on old-glibc container; AppImage runs on ≥2 distros; `.deb`
      passes `lintian`.
- [ ] Qt plugins present in each bundle (`platforms/`, `imageformats/`, `tls/`,
      `translations/qtbase_*.qm`).
- [ ] Resources resolve from frozen location (test `resource_root()`).
- [ ] Release assets: installers/AppImage/.deb/DMG + SHA256 files + lockfile +
      licenses + SBOM.
- [ ] GitHub Release created via `gh release create` with notes; attestations
      attached.
- [ ] Tag is signed and pushed; release workflow only ran for that tag.
- [ ] Secrets never appear in logs; verify with a scan of the workflow log.

---

## 15. Command quick reference

```bash
# PyInstaller onedir (once to generate spec, then edit spec)
pyinstaller --onedir --windowed --name MyApp myapp/__main__.py

# Nuitka standalone
python -m nuitka --standalone --enable-plugin=pyqt6 --windows-console-mode=disable \
  --output-dir=dist myapp/__main__.py

# Windows signing
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 \
  /f cert.pfx /p "$PW" dist/MyApp-Setup.exe
Get-AuthenticodeSignature dist/MyApp-Setup.exe | Format-List Status,StatusMessage

# macOS sign / notarize / staple
codesign --force --options runtime --sign "Developer ID Application: ..." MyApp.app
ditto -c -k --keepParent MyApp.app MyApp.zip
xcrun notarytool submit MyApp.zip --key AuthKey.p8 --key-id KID --issuer IID --wait
xcrun stapler staple MyApp.app
spctl --assess --type execute --verbose=4 MyApp.app

# DMG
hdiutil create -volname MyApp -srcfolder MyApp.app -ov -format UDZO MyApp.dmg

# AppImage (inside old container)
./linuxdeploy.AppImage --appdir AppDir --executable dist/MyApp/MyApp --plugin qt
ARCH=x86_64 ./appimagetool.AppImage AppDir

# .deb
dpkg-deb --build --root-owner-group myapp_1.2.0_amd64
lintian myapp_1.2.0_amd64.deb

# glibc floor check
readelf --version-info dist/MyApp/MyApp | grep -o 'GLIBC_[0-9.]*' | sort -u | tail

# checksums
sha256sum dist/MyApp-Setup.exe dist/MyApp.AppImage dist/MyApp.dmg > SHA256SUMS
```

---

## Final word

napari's real gift to you is not the installer format — it is the **process**:
test the artifact you ship, verify every signature in CI, gate signing by event,
pin your tools, collect licenses and lockfiles, and keep the packaging pipeline
reusable and visible. Apply that process to your own PyQt6 stack (PyInstaller
onedir or Nuitka standalone + native installers) and you will produce
professional, trustworthy releases.
