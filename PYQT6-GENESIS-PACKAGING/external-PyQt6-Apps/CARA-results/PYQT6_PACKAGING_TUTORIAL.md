# Practical PyQt6 Packaging Tutorial

This tutorial turns CARA's verified lessons into a reusable strategy. “CARA
pattern” means directly evidenced in `PACKAGING_STUDY.md`; “general
recommendation” is guidance that you must adapt and test. Commands are
templates, not a promise that they work unchanged for every PyQt6 application.

## 1. Start with a Deliverable Model

Build separately on each target OS; neither PyInstaller nor Nuitka is a
reliable cross-compiler for GUI bundles.

```text
git tag vX.Y.Z
       |
       +-- Windows native runner -> standalone directory -> sign -> installer -> sign
       +-- Linux old baseline -> AppImage and/or native DEB -> test
       +-- macOS runner -> .app -> Developer ID sign -> notarize -> staple -> ZIP/DMG
       |
       +-- SHA-256 + SBOM/provenance + GitHub Release
```

Use a clean virtual environment and record exact resolved dependencies.

```bash
python -m venv .venv
# Linux/macOS:
. .venv/bin/activate
# Windows PowerShell: .\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m pip freeze > requirements-release-lock.txt
```

For genuine reproducibility, commit a reviewed lock/constraints file (and
hashes where your tool supports them), pin the Python/packager versions, set a
version from the tag, and preserve build logs. A timestamp embedded into the
binary is convenient but means byte-identical builds are unlikely.

## 2. Resources and User Data Before Freezing

Do not make assets depend on the working directory. CARA's useful pattern is
a single resolver that understands development, a frozen onedir directory,
and `Contents/Resources` in a `.app`. Avoid `sys._MEIPASS` unless you choose
PyInstaller onefile; it is not needed for onedir.

```python
from pathlib import Path
import sys

def resource_root() -> Path:
    if getattr(sys, "frozen", False):
        exe = Path(sys.executable)
        if sys.platform == "darwin" and exe.parent.name == "MacOS":
            return exe.parent.parent / "Resources"
        return exe.parent / "_internal"       # verify your packager layout
    return Path(__file__).resolve().parents[1]

def resource_path(relative: str) -> Path:
    return resource_root() / relative
```

Keep bundled resources read-only. Place preferences, logs, databases, and
downloads in platform user-data locations (for example with
`platformdirs`). In particular, never write inside a signed macOS `.app`:
doing so can invalidate its signature. CARA copies default settings into
`~/Library/Application Support/CARA` for that reason.

For resources, use one approach consistently:

* **Filesystem directory (CARA pattern):** easy for HTML, databases, assets,
  PyInstaller/Nuitka and native packages. Explicitly include the whole data
  directory and test it.
* **Qt Resource System (`.qrc`):** good for small immutable UI assets accessed
  as `:/icons/foo.svg`; compile it to Python and it becomes code. It does not
  remove the need to package large data files or Qt plugins.

## 3. Choose PyInstaller or Nuitka Intentionally

### PyInstaller

Start with `--onedir --windowed`. It is fast to iterate, has mature PyQt6
hooks, keeps executable and libraries inspectable, avoids onefile start-up
extraction, and is simple to debug. It still ships a Python runtime and Qt, so
bundles are substantial.

```bash
python -m PyInstaller --noconfirm --clean --onedir --windowed \
  --name MyApp --icon assets/MyApp.ico \
  --add-data 'app/resources:app/resources' \
  --collect-all PyQt6 \
  main.py
```

On Windows, use `;` rather than `:` in `--add-data`; prefer a `.spec` file as
the project grows. `--collect-all PyQt6` is deliberately broad and may be
unnecessary: begin with normal hooks, inspect output/warnings, and add only
the data/plugins actually required. Do not blindly ship all QML/WebEngine
content for a Widgets-only app.

### Nuitka

Nuitka is a legitimate alternative. It compiles Python modules through a C/C++
toolchain, so build time/toolchain setup are heavier but it can deliver strong
runtime performance for some applications. Try **standalone** first:

```bash
python -m nuitka --standalone --enable-plugin=pyqt6 \
  --windows-console-mode=disable \
  --include-data-dir=app/resources=app/resources \
  --output-dir=build/nuitka main.py
```

Option names and plugins evolve; verify against the
[official Nuitka manual](https://nuitka.net/doc/user-manual) for the installed
version. Use a Windows compiler supported by that version; test the output on
a clean VM. Nuitka `--onefile` is possible but also wraps/extracts a payload;
it is not intrinsically safer for antivirus or faster to start.

### Decision rule

Build a representative release of both on a clean runner, then compare: cold
startup, installed size, update behavior, crash reporting/debuggability,
license obligations, CI duration, and AV results over several releases. Do
not choose a packager solely from a single VirusTotal sample.

## 4. Windows

### 4.1 Recommended release pipeline

```text
PyQt6 source -> locked virtualenv -> PyInstaller onedir or Nuitka standalone
             -> version/icon/manifest metadata -> Authenticode sign all EXEs/DLLs
             -> Inno Setup installer -> sign installer -> test
             -> VirusTotal review -> SHA-256 -> GitHub Release
```

The CARA lesson is that onedir is a transparent portable baseline. CARA does
not implement the rest: the following is a general recommendation.

### 4.2 Version metadata and manifest

Give Windows release executables a real product name, semantic version,
publisher/copyright, original filename, and icon. In a PyInstaller spec,
pass a `version=` resource file to `EXE`; create an application manifest only
when you have a specific requirement (for example DPI awareness or requested
execution level). Do not ask for elevation just because an installer exists:
the installer can elevate while the application runs as a standard user.

### 4.3 Signing

Obtain an appropriate code-signing certificate from a trusted CA and protect
its private key (hardware/cloud signing is preferable to a plaintext PFX).
Your actual provider's signing command varies. Typical Windows SDK shape:

```powershell
signtool sign /fd SHA256 /tr <RFC3161-timestamp-URL> /td SHA256 `
  /a dist\MyApp\MyApp.exe
signtool verify /pa /all /v dist\MyApp\MyApp.exe
```

Sign executable files before packaging, then sign the final installer too.
Timestamping lets signatures remain valid after certificate expiry. An
organization-validated or EV certificate affects publisher identity and may
affect reputation experiences over time, but it does not guarantee SmartScreen
or AV acceptance. Never store certificate passwords or private keys in the
repository; CI should receive short-lived credentials through its secret store
or use a managed signing service.

### 4.4 Installer: Inno Setup template

Inno Setup is a good open-source-project default: mature, simple, familiar
EXE installer, uninstaller, Start menu/desktop shortcuts, and non-admin mode
options. Example skeleton:

```ini
#define MyAppName "MyApp"
#define MyAppVersion "1.2.3"
#define MyAppPublisher "Example Project"
#define MyAppExeName "MyApp.exe"

[Setup]
AppId={{YOUR-STABLE-GUID-HERE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputBaseFilename=MyApp-{#MyAppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "dist\MyApp\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
```

Use a persistent AppId GUID; changing it creates a separate installation.
Compile with `ISCC`, then Authenticode-sign the resulting setup EXE. Offer a
portable ZIP as well only if it is useful to your users.

### 4.5 Antivirus/VirusTotal: realistic practice

Legitimate steps that may improve confidence or reduce accidental heuristics:

1. Build from a clean, automated, pinned environment and retain logs.
2. Prefer onedir/standalone while validating onefile-specific behavior.
3. Avoid UPX or other executable compression unless necessary and tested.
4. Use stable application metadata, icon, publisher identity, and signed
   executable/installer with a secure timestamp.
5. Publish the source, signed release, release notes, SHA-256 checksums, and
   clear download URLs under a consistent project identity.
6. Scan before release, investigate detections, and submit confirmed false
   positives to the vendor through its official process.

Do **not** use obfuscation, polymorphic changes, disabling security products,
or “bypass” tactics. VirusTotal counts are not a quality metric and cannot be
guaranteed: engines differ, signatures change, and an unsigned build may look
different from a signed release. CARA itself uses onedir and requests UPX in
its Windows spec, but contains no measured AV outcome or Windows signing.

## 5. Linux AppImage

CARA does not use AppImage; its useful transferable lesson is the old-GLIBC
baseline. Build on the oldest distribution you intend to support. A newer
build can require a newer GLIBC symbol version and fail on an older system.

### 5.1 Target structure

```text
MyApp.AppDir/
├── AppRun
├── myapp.desktop
├── myapp.png                 # Icon name matches Icon=, no extension in desktop entry
└── usr/
    ├── bin/myapp
    ├── lib/                  # only libraries your portability analysis permits
    └── share/
        ├── applications/myapp.desktop
        ├── icons/hicolor/256x256/apps/myapp.png
        └── myapp/resources/...
```

An AppImage is made from an AppDir; its root needs an executable `AppRun`, a
desktop file, and matching icon. `appimagetool` turns that into a read-only
image with an embedded runtime. See the official
[AppDir specification](https://docs.appimage.org/reference/appdir.html) and
[AppImage packaging introduction](https://docs.appimage.org/packaging-guide/introduction.html).

### 5.2 Practical approach

1. First make a correct PyInstaller onedir Linux bundle on Ubuntu 22.04 (or
   another documented old baseline). Test it before adding AppImage layers.
2. Place the launcher under `usr/bin`, resources in a known location, and make
   `AppRun` set only needed variables before executing it. Example:

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
export APPDIR="$HERE"
exec "$HERE/usr/bin/myapp" "$@"
```

3. Create `myapp.desktop` with `Type=Application`, `Name=MyApp`,
   `Exec=myapp`, `Icon=myapp`, `Categories=Utility;`, and `Terminal=false`.
4. Use `linuxdeploy` plus its Qt plugin or construct/validate the AppDir
   manually; then run `appimagetool MyApp.AppDir MyApp-x86_64.AppImage`.
5. Do not indiscriminately bundle GLIBC, GPU drivers, or every system library.
   Follow the AppImage tool's exclusion rules and test actual targets. Qt
   platform/image-format plugins and needed Qt translations must be present.

### 5.3 Testing

Test launch, file dialogs, SVG/PNG loading, printing, network/TLS if used,
and external child processes on the oldest supported Ubuntu/Debian/Fedora/openSUSE
targets, X11 and Wayland where relevant, and both target architectures. Test a
non-writable mount-like location. Inspect `ldd`/runtime logs carefully.
CARA's `libxkbcommon` exclusion and GIO/Wayland workarounds demonstrate why
you should add Qt/Linux fixes only when reproduced and documented.

## 6. Debian/Ubuntu DEB

An AppImage is a self-contained portable artifact; a DEB is a native package
integrated with the distribution. Do not use one as a superficial rename of the
other.

### 6.1 Native dependency model (recommended for a distro-style DEB)

Prefer distribution packages for Python and Qt:

```text
Depends: python3 (>= 3.x), python3-pyqt6, python3-chess, python3-requests
```

Package names and versions differ by Debian/Ubuntu release; confirm in each
target distribution. Advantages: small package, OS security updates, normal
filesystem integration. Costs: lower-bound compatibility and backport work.
Do not bundle a random private Python/Qt runtime in a DEB without a clear
maintenance/security plan.

### 6.2 Minimal manual package layout

```text
pkgroot/
├── DEBIAN/control
├── usr/bin/myapp
├── usr/lib/myapp/             # application Python source/data if appropriate
├── usr/share/applications/org.example.MyApp.desktop
├── usr/share/icons/hicolor/256x256/apps/org.example.MyApp.png
└── usr/share/doc/myapp/copyright
```

`DEBIAN/control` example:

```text
Package: myapp
Version: 1.2.3-1
Section: utils
Priority: optional
Architecture: all
Maintainer: Example <maintainer@example.invalid>
Depends: python3 (>= 3.10), python3-pyqt6
Description: MyApp desktop application
 A longer description.
```

Use a launcher at `/usr/bin/myapp` that imports/runs your installed module.
Desktop integration belongs in `/usr/share/applications`; icons use
`/usr/share/icons/hicolor/<size>/apps`; documentation in `/usr/share/doc`.
Use a real Debian source package (`debian/control`, `rules`, `changelog`,
`copyright`, `install`) and `debhelper` for maintained distribution work rather
than hand-building forever.

```bash
dpkg-deb --build pkgroot myapp_1.2.3-1_all.deb
dpkg-deb --info myapp_1.2.3-1_all.deb
dpkg-deb --contents myapp_1.2.3-1_all.deb
sudo apt install ./myapp_1.2.3-1_all.deb
sudo dpkg -r myapp
lintian myapp_1.2.3-1_all.deb
```

Test install, upgrades, uninstall (including what happens to user settings),
desktop launcher, MIME/file associations if any, and missing dependency errors
inside a clean VM/container. CARA has no DEB implementation to copy.

## 7. macOS

### 7.1 Bundle

The CARA pattern is PyInstaller onedir plus `BUNDLE`, producing `MyApp.app`.
Set a stable bundle identifier, version fields, and an `.icns` icon. Confirm
the final tree contains executable, Python runtime, Qt frameworks/plugins, and
resources. Do not assume an arm64 build is universal: build/test arm64 and
x86_64 (or an explicitly configured universal2 workflow) according to your
support policy.

### 7.2 Sign, notarize, staple

```text
build .app -> sign nested code -> sign .app with Developer ID/runtime/timestamp
           -> verify -> archive (.zip or .dmg) -> notarytool submit
           -> staple ticket -> validate -> release
```

The exact order may depend on whether you notarize a ZIP/DMG/PKG, but the
shipped app must be the signed/notarized/stapled artifact you test.

```bash
# On a Mac with a Developer ID Application identity in Keychain:
codesign --force --deep --options runtime --timestamp \
  --entitlements packaging/macos/entitlements.plist \
  --sign 'Developer ID Application: Your Name (TEAMID)' dist/MyApp.app
codesign --verify --deep --strict --verbose=2 dist/MyApp.app
ditto -c -k --norsrc --noextattr --keepParent dist/MyApp.app MyApp-notary.zip
xcrun notarytool submit MyApp-notary.zip --keychain-profile MyAppNotary --wait
xcrun stapler staple dist/MyApp.app
xcrun stapler validate dist/MyApp.app
spctl --assess --type execute -vv dist/MyApp.app
```

This closely follows CARA's `scripts/build_macos_signed.sh`. Apple requires a
Developer ID application certificate, hardened runtime, secure timestamp, and
proper signatures for notarization; keep only narrowly justified runtime
exceptions in entitlements. See
[Apple's notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

An Apple Developer Program account/certificate/keychain credentials are
requirements; PyInstaller, `codesign`, `notarytool`, and `ditto` alone do not
replace them. CARA creates a ZIP rather than a DMG; a DMG is optional UX, not a
notarization substitute. If you make one, sign/notarize the appropriate final
deliverable and test the downloaded artifact.

## 8. Qt Plugins and Translations

For every packaging backend, smoke-test platform plugins (`platforms`), image
formats, icon engines, styles, TLS/network plugins if used, and WebEngine/QML
only if used. PyInstaller/Nuitka can discover much automatically, but discovery
is not a substitute for a clean-machine test.

For localized Qt standard dialogs, explicitly bundle the needed Qt `.qm`
files and install a translator before showing widgets:

```python
from PyQt6.QtCore import QLibraryInfo, QLocale, QTranslator

translator = QTranslator()
translations_dir = QLibraryInfo.path(QLibraryInfo.LibraryPath.TranslationsPath)
if translator.load(QLocale.system(), "qtbase", "_", translations_dir):
    app.installTranslator(translator)
```

The exact file names/path API and which Qt translations to ship need testing
against your PyQt6 version. CARA has no `QTranslator` or `.qm` implementation,
so do not infer its bundles localize standard Qt dialogs.

## 9. GitHub Actions Architecture

Use tags as the release boundary, keep test and release workflows separate,
and build natively per OS. CARA's useful pieces are matrix build structure,
old Linux baseline, pinned PyInstaller version, and artifact upload; its
current workflows are manual-only and do not publish signed releases.

```yaml
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write

jobs:
  build-windows:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with: {python-version: '3.12'}
      - run: python -m pip install -r requirements-release-lock.txt
      - run: python -m PyInstaller MyApp_windows.spec --noconfirm
      # Sign here using a provider-approved secret/managed signing service.
      # Build/sign installer, run a launch smoke test, then upload artifact.

  build-linux:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with: {python-version: '3.12'}
      - run: python -m pip install -r requirements-release-lock.txt
      # build/test AppImage and DEB; upload both

  build-macos:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with: {python-version: '3.12'}
      # Import a temporary Developer ID cert or use a managed signing runner;
      # build, sign, notarize, staple, validate, archive, upload artifact.

  release:
    needs: [build-windows, build-linux, build-macos]
    runs-on: ubuntu-latest
    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v7
      - name: Produce checksums
        run: sha256sum * > SHA256SUMS.txt
      # Create GitHub Release and attach reviewed artifacts/checksum/SBOM.
```

Treat this as an architecture fragment. You must select a trusted signing
provider and design its secret/identity lifecycle before adding CI signing.
Never echo certificate, token, private-key, app-specific-password, or
notarization credential values. Pin GitHub Actions by reviewed commit SHA in a
security-sensitive project, add artifact attestations/SBOM where appropriate,
and use least-privilege permissions.

## 10. Release Checklist

1. Run tests and static checks from a clean locked environment.
2. Build exact tagged source natively on each OS/architecture.
3. Run packaging smoke tests: launch, Qt dialogs/plugins/resources, settings,
   external process behavior, and upgrade/uninstall where relevant.
4. Sign Windows inner executables/DLLs and installer; verify Authenticode.
5. Sign/notarize/staple the macOS app; assess the final downloaded artifact.
6. Test Linux artifact on old and varied target distributions/desktops.
7. Produce SHA-256 hashes, SBOM/provenance where feasible, release notes, and
   source-link/license notices.
8. Publish only reviewed artifacts to a GitHub Release; retain CI artifacts and
   build logs for traceability.
9. Review AV results realistically and submit confirmed false positives to
   vendors; never delay security fixes to chase a transient score.

## 11. Classification of Recommendations

* **[HIGHLY RECOMMENDED]** Explicit resource/user-data paths, onedir/standalone
  first, clean-machine smoke tests, old Linux GLIBC baseline, hashes, and
  signing/notarization where platform ecosystems support it.
* **[USEFUL]** Inno Setup plus portable ZIP, AppImage plus native DEB when you
  can maintain both, CI matrix builds, SBOM/provenance, and package linting.
* **[PROJECT-SPECIFIC]** CARA's xkbcommon/GIO/Wayland/KDE workarounds, child
  engine environment sanitization, and macOS entitlement exceptions.
* **[LEGACY]** CARA's removed Flatpak implementation; study history only, do
  not call it a maintained channel.
* **[NOT RECOMMENDED]** AV evasion tricks, signing credentials in a repository,
  untested plugin overcollection, writing inside `.app`, and treating tar.gz
  as an AppImage or portable ZIP as an installer.
* **[REQUIRES FURTHER RESEARCH]** The correct package names/versions for each
  Debian release, Apple entitlements needed by your actual app, your code
  signing provider/CI integration, and the measured PyInstaller-vs-Nuitka
  trade-off for your workload.

## 12. Final Recommendation

For a new open-source PyQt6 desktop application today: use a locked,
native-per-OS CI build; begin with PyInstaller onedir or Nuitka standalone;
provide a signed Inno Setup installer and optional portable ZIP on Windows;
provide a carefully tested AppImage and a native dependency-based DEB on
Linux; provide a Developer-ID-signed, notarized/stapled `.app` as a ZIP or DMG
on macOS; and publish hashes, source, SBOM/provenance where feasible, release
notes, and clear verification instructions. Adopt CARA's clean onedir/path and
macOS-signing lessons, but do not copy its missing Windows signing, missing
installer, absent AppImage/DEB, loose dependency resolution, or Linux
workarounds without evidence from your own application.
