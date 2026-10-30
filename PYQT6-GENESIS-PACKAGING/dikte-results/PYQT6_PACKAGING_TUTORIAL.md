# Practical PyQt6 Packaging Tutorial

This is a reusable design guide derived from the Dikte case study plus current
official packaging documentation. It is not a claim that one set of commands
works unchanged for every PyQt6 application.

Labels used throughout:

- **[FROM DIKTE]** directly demonstrated by this repository.
- **[GENERAL RECOMMENDATION]** broader guidance supported by tool/platform
  documentation, not implemented by Dikte.
- **[TEMPLATE — TEST BEFORE USE]** illustrative configuration that needs product,
  dependency, identity, and CI adaptation.

Assumed example application:

```text
project/
├── pyproject.toml
├── src/myapp/
│   ├── __init__.py
│   ├── __main__.py
│   ├── app.py
│   └── resources/
├── packaging/
├── tests/
└── .github/workflows/
```

The recommended high-level outcome is:

```text
                         signed release tag
                                  |
             source tests + locked build dependencies
                                  |
               +------------------+------------------+
               |                  |                  |
            Windows             Linux              macOS
               |                  |                  |
        standalone dir      standalone dir          .app
               |            / native source          |
       metadata + sign       |          |       sign nested code
               |          AppDir      Debian      sign hardened app
            installer         |        package         |
               |           AppImage      |           DMG
        sign installer        |          |       notarize + staple
               +------------------+------------------+
                                  |
                   smoke tests + SHA-256 + SBOM
                       + provenance attestation
                                  |
                           GitHub Release
```

## 1. Establish a Reproducible Build Contract

**[GENERAL RECOMMENDATION]** Packaging starts with controlled inputs, not with a
freezer command.

1. Declare application metadata and Python compatibility in `pyproject.toml`.
2. Separate runtime, development, and packaging dependencies.
3. Lock exact packaging versions per release branch or export a hashed
   requirements file.
4. Build from a clean virtual environment on each native OS.
5. Record Python, PyQt6, Qt, freezer, compiler, installer, and runner versions in
   build logs.

Example setup:

```bash
python -m venv .venv
. .venv/bin/activate              # Windows PowerShell: .venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install --require-hashes -r packaging/requirements-build.txt
python -m pytest                  # or your actual test command
```

Do not blindly generate `requirements-build.txt` from a development workstation.
Review licenses and hashes; keep platform markers where wheels differ.

**[FROM DIKTE]** Dikte's single source of version truth and reusable matrix are
good structural ideas. Its unpinned `pip install PyQt6 pyinstaller` is not a
reproducible build model.

## 2. Prepare the Application for Freezing

### Stable entry point

Keep startup thin and deterministic:

```python
# src/myapp/__main__.py
from myapp.app import main

if __name__ == "__main__":
    raise SystemExit(main())
```

Perform environment repair before importing libraries that initialize Qt,
OpenSSL, or subprocesses. **[FROM DIKTE]** A separate frozen entry file can do
this without complicating checkout startup.

### Resource paths

Prefer Qt Resource System for immutable interface assets or
`importlib.resources` for package data:

```python
from importlib.resources import files

template = files("myapp.resources").joinpath("default.json").read_text("utf-8")
```

Avoid `os.getcwd()` and assumptions that the user launches from the source
directory. PyInstaller documents runtime resource behavior in its
[runtime information](https://pyinstaller.org/en/stable/runtime-information.html),
and Nuitka recommends paths relative to `__file__`/package resources in its
[user manual](https://nuitka.net/user-documentation/user-manual.html).

### Qt resources versus filesystem data

Use `.qrc`/compiled resource modules when:

- assets are immutable and used only by Qt;
- a `:/icons/name.svg` path is convenient;
- one internal namespace across all packages is desirable.

Use packaged filesystem resources when:

- non-Qt libraries need actual paths;
- users replace or inspect files;
- the OS needs the asset outside the process (`.desktop` icon, `.icns`, `.ico`);
- large files should remain outside a Python resource module.

Even with Qt resources, keep OS-level ICO/ICNS/PNG assets for executable and
desktop integration.

## 3. Inventory Qt Features Before Choosing Plugins

Create a feature table for the real application:

| Feature | Python module | Likely plugin/data family |
|---|---|---|
| Widgets | `PyQt6.QtWidgets` | platform, styles, image formats |
| HTTPS | `PyQt6.QtNetwork` | TLS plugins/backends |
| SVG | `PyQt6.QtSvg` | SVG/icon engine |
| Printing | `PyQt6.QtPrintSupport` | print support/platform integration |
| SQL | `PyQt6.QtSql` | selected SQL driver only |
| Multimedia | `PyQt6.QtMultimedia` | multimedia plugins/codecs |
| QML/Quick | `PyQt6.QtQml`, `QtQuick` | QML tree and imports |
| WebEngine | `PyQt6.QtWebEngineWidgets` | helper process, locales, resources |

Do not copy another project's exclusions. **[FROM DIKTE]** Dikte can exclude QML,
Quick, WebEngine, Multimedia, SQL, and 3D because its own imports/features do not
need them. Your app may fail silently or at runtime if you repeat that list.

Artifact tests should run with `QT_DEBUG_PLUGINS=1` at least once and exercise:

- cold GUI startup;
- PNG/JPEG/SVG loading actually used by the app;
- file open/save dialogs;
- HTTPS and certificate validation;
- printing, multimedia, SQL, QML, or WebEngine if present;
- the native platform plugin on each OS.

## 4. PyInstaller Strategy

PyInstaller bundles an interpreter, analyzed modules, extension modules, shared
libraries, and data. It is not a cross-compiler; build separately on Windows,
Linux, and macOS. See the
[official manual](https://pyinstaller.org/en/stable/).

### Start with onedir

```bash
pyinstaller --noconfirm --clean --onedir --windowed \
  --name MyApplication src/myapp/__main__.py
```

Use a spec once the build has nontrivial data, exclusions, metadata, or multiple
executables:

```python
# packaging/myapp.spec — TEMPLATE, TEST BEFORE USE
from pathlib import Path

# SPECPATH is the directory containing packaging/myapp.spec.
ROOT = Path(SPECPATH).parent

a = Analysis(
    [str(ROOT / "src/myapp/__main__.py")],
    pathex=[str(ROOT / "src")],
    datas=[(str(ROOT / "src/myapp/resources"), "myapp/resources")],
    hiddenimports=[],
    excludes=["tkinter"],
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="MyApplication",
    console=False,
    icon=str(ROOT / "packaging/windows/MyApplication.ico"),
)
app = COLLECT(exe, a.binaries, a.datas, name="MyApplication")
```

Run a spec with only build-layout flags at the command line:

```bash
python -m PyInstaller packaging/myapp.spec \
  --distpath build/dist --workpath build/work --noconfirm --clean
```

When a spec is supplied, most ordinary command-line options are ignored because
the spec is executable build configuration. See
[Using Spec Files](https://pyinstaller.org/en/stable/spec-files.html).

### onedir versus onefile

Choose **onedir** when:

- it will be wrapped by an installer, AppImage, DMG, ZIP, or package manager;
- fast and predictable startup matters;
- debugging and inspecting dependencies matters;
- security software behavior is a concern worth testing;
- the application starts external child programs or updates parts separately.

Choose **onefile** only when its single naked executable is a real user benefit.
It extracts support files to a temporary location and normally starts more
slowly. Do not add onefile merely because the final download should be one file;
an installer/AppImage/DMG already provides that. This is one of the clearest
**[FROM DIKTE]** lessons.

### UPX

For a conservative Windows release, explicitly disable it unless measured size
requirements justify it:

```bash
pyinstaller --noupx ...
```

PyInstaller may automatically use UPX on Windows when it finds it. Its
[usage documentation](https://pyinstaller.org/en/stable/usage.html#using-upx)
also notes plugin/library compatibility concerns. “No UPX” is not a guarantee of
zero antivirus detections; it removes an unnecessary variable.

### Custom bootloader

PyInstaller documents compiling a bootloader for toolchain control and as a
possible response to false positives:
[Building the Bootloader](https://pyinstaller.org/en/stable/bootloader-building.html).
Treat this as an experiment, not a magic switch. A unique bootloader may avoid a
particular heuristic today, lose an allowlist benefit tomorrow, and adds compiler
and provenance responsibilities.

## 5. Nuitka Strategy

Nuitka translates Python modules to C and builds them with a native compiler. It
can produce standalone directories and onefile containers. It requires a C11
compiler; current platform requirements are in the
[Nuitka user manual](https://nuitka.net/user-documentation/user-manual.html).

### Initial PyQt6 experiment

**[TEMPLATE — TEST BEFORE USE]** Option names should be checked against the exact
pinned Nuitka release:

```bash
python -m nuitka \
  --mode=standalone \
  --enable-plugin=pyqt6 \
  --windows-console-mode=disable \
  --windows-icon-from-ico=packaging/windows/MyApplication.ico \
  --company-name="Example Publisher" \
  --product-name="MyApplication" \
  --file-version="1.2.3.0" \
  --product-version="1.2.3.0" \
  --file-description="Example desktop application" \
  src/myapp/__main__.py
```

Select only Qt plugins the application proves it needs. Nuitka's current standard
plugin documentation describes `--include-qt-plugins`; a broad `all` increases
size and dependency risk.

### When Nuitka may win

- better measured cold/warm startup for the specific application;
- smaller or cleaner measured dependency tree after tuning;
- compiled Python modules are desirable;
- repeated signed Windows releases show materially better vendor behavior;
- the team can afford compiler time and more complex troubleshooting.

### Costs and cautions

- much longer builds and compiler/toolchain dependencies;
- different debugging behavior because compiled functions are not ordinary
  CPython bytecode;
- package plugins and data inclusion still require work;
- onefile still has bootstrap/payload tradeoffs;
- native artifacts remain OS/architecture specific;
- current exact PyQt6 support must be verified on all three target platforms.

Nuitka 2.1 historically discontinued PyQt6 on macOS due to framework packaging.
Current development code again contains PyQt6 plugin handling, but that history
is a reason to run a real signed/notarized `.app` proof before standardizing on a
single Nuitka pipeline. PySide6 has traditionally received stronger Nuitka/Qt
Company integration. Changing bindings is a product decision, not a packaging
flag.

### A fair comparison protocol

Build from the same commit and dependency lock:

```text
PyInstaller onedir, --noupx
Nuitka standalone, equivalent Qt plugins/data
    |
    +-- size of installed tree and download
    +-- clean VM launch and first-window time
    +-- warm launch time
    +-- CPU/RAM under representative work
    +-- installer behavior and updates
    +-- signature verification
    +-- VirusTotal/vendor results over several releases
    +-- engineering/build minutes
```

Do not conclude “Nuitka prevents false positives.” At most conclude that an exact
signed artifact set performed better in a documented test window.

# Windows

## 6. Windows End-to-End Pipeline

```text
PyQt6 source
    -> clean venv + locked dependencies
    -> source tests
    -> PyInstaller onedir or Nuitka standalone
    -> artifact smoke test
    -> PE manifest/version/icon metadata
    -> sign application-owned EXE/DLL files
    -> verify inner signatures
    -> Inno Setup / MSIX / MSI
    -> sign installer and timestamp
    -> verify outer signature + install/uninstall test
    -> SHA-256 + SBOM + provenance
    -> GitHub Release
```

### Metadata

For PyInstaller, generate a version resource with `pyi-grab_version` from a
known executable or write a `VSVersionInfo` file and pass it as `version=` to
`EXE`/`--version-file`. Include at least:

- CompanyName/publisher;
- FileDescription;
- FileVersion;
- ProductName;
- ProductVersion;
- copyright;
- stable icon;
- support URL in the installer.

Use the default `asInvoker` behavior unless the application truly requires
elevation. An unexplained admin request damages trust and deployability.

**[FROM DIKTE]** A per-user installation under LocalAppData is a good fit for a
single-user tray utility and avoids UAC. It is not right for shared-machine or
enterprise-wide requirements.

## 7. Windows Code Signing

### Requirements

Obtain one of:

- a publicly trusted organization-validation code-signing certificate;
- Microsoft Artifact Signing/Trusted Signing when eligible and suitable;
- Store/MSIX signing through the Microsoft Store path.

A self-signed certificate is useful for internal testing but does not establish
public trust. Microsoft's current
[SmartScreen documentation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)
states that publisher and file-hash reputation both matter, valid OV/EV files
may initially warn, and EV no longer automatically bypasses SmartScreen.

Keep the private key out of repository files and ordinary build logs. Prefer a
hardware-backed or cloud signing service. If CI imports a PFX, use a protected
environment, least-privilege secret access, an ephemeral certificate store, and
cleanup; never echo the password or encode the certificate into a checked-in
file.

### Correct ordering

```text
finalize standalone payload
    -> sign application-owned inner executables
    -> verify them
    -> build installer without changing inner payload
    -> sign installer
    -> verify installer and timestamp
```

**[TEMPLATE — TEST BEFORE USE]** With a certificate already available through a
secure provider/store:

```powershell
$timeServer = "https://YOUR-CA-RFC3161-ENDPOINT"

signtool sign /fd SHA256 /td SHA256 /tr $timeServer /a `
  build\dist\MyApplication\MyApplication.exe

signtool verify /pa /all /v `
  build\dist\MyApplication\MyApplication.exe

iscc packaging\windows\MyApplication.iss

signtool sign /fd SHA256 /td SHA256 /tr $timeServer /a `
  dist\MyApplication-1.2.3-setup.exe

signtool verify /pa /all /v `
  dist\MyApplication-1.2.3-setup.exe
```

`/a` is only appropriate when the secure signing context exposes the intended
certificate unambiguously. A cloud-signing service will use its own action/tool.
The [SignTool reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/signtool)
documents signing, RFC 3161 timestamps, and verification.

If Inno Setup creates an uninstaller, investigate its `SignTool` and
`SignedUninstaller` support so the installed uninstaller is signed too. Verify
the actual installed files rather than assuming the outer setup signature covers
them.

Do not re-sign third-party libraries or helper executables by default. Preserve
their upstream signatures and licenses; sign the code your project publishes as
its own.

## 8. Windows Installer Choices

### Inno Setup

Good for classic open-source desktop applications:

- mature EXE installer;
- flexible per-user/per-machine installs;
- shortcuts, file associations, tasks, upgrades, uninstaller;
- simple CI compilation.

Minimal skeleton:

```ini
; TEMPLATE — TEST BEFORE USE
#define AppVersion "1.2.3"

[Setup]
AppId=org.example.myapplication
AppName=MyApplication
AppVersion={#AppVersion}
AppPublisher=Example Publisher
AppPublisherURL=https://github.com/example/myapplication
DefaultDirName={localappdata}\Programs\MyApplication
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=MyApplication-{#AppVersion}-x64-setup
SetupIconFile=MyApplication.ico
Compression=lzma2/max
SolidCompression=yes

[Files]
Source: "..\..\build\dist\MyApplication\*"; DestDir: "{app}"; \
  Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\MyApplication"; Filename: "{app}\MyApplication.exe"
```

Give upgrades a stable AppId. Test upgrade over a running app, repair, uninstall,
settings/data preservation, path quoting, non-ASCII usernames, and standard user
accounts.

### MSIX / Microsoft Store

Prefer when Store trust, automatic updates, clean uninstall, enterprise policy,
or managed deployment outweighs restrictions around app identity, file-system
writes, startup tasks, and integration behavior. Store distribution is the most
reliable way to avoid SmartScreen download warnings according to Microsoft; it
does not mean every desktop application can be moved there without adaptation.

### MSI / WiX

Use when enterprise administrators require MSI semantics, Group Policy/software
deployment, transforms, or machine-wide component management. WiX has a steeper
learning curve and is not automatically more professional than a well-built,
signed Inno installer.

### Portable ZIP

Offer it in addition to an installer when users need no-install/removable usage.
Zip the onedir/standalone tree, not a random subset. Clearly document where
settings are stored; “portable archive” is not a portable-settings mode unless
the app implements that.

## 9. Antivirus and VirusTotal: Legitimate Practice

There is no guaranteed zero-detection recipe.

### Recommended controls

1. Build in a clean, reviewable CI environment.
2. Pin current stable freezer/compiler versions and record them.
3. Use onedir/standalone under the installer unless onefile has a demonstrated
   requirement.
4. Disable unnecessary UPX, packers, obfuscators, and binary mutation.
5. Embed consistent version, product, publisher, icon, and manifest metadata.
6. Sign every application release with one stable trusted publisher identity and
   timestamp it.
7. Sign both the inner executables and outer installer.
8. Publish source, build workflows, release notes, SHA-256, SBOM, and provenance.
9. Scan the exact final artifacts, keep results by version, and investigate
   engine names rather than treating an aggregate number as a verdict.
10. Submit confirmed false positives to each vendor. Microsoft's official
    [software-developer submission portal](https://www.microsoft.com/en-us/wdsi/filesubmission)
    accepts incorrectly classified files.

### Interpretation rules

- One or two heuristic detections do not prove malware; zero does not prove
  safety.
- SmartScreen “unrecognized app” is a reputation decision, not the same thing as
  a Defender malware family detection.
- Signing proves publisher identity and post-signing integrity. It does not prove
  benign behavior and does not guarantee no warnings.
- Checksums detect mismatch but do not establish who published the expected
  checksum unless the manifest is signed/attested.
- Recompiling a PyInstaller bootloader can change detections but is correlation,
  not a permanent fix.
- Do not instruct users to disable antivirus. Do not use evasion or obfuscation
  tricks. Fix real detections and use vendor dispute channels for false ones.

# Linux AppImage

## 10. AppImage Architecture

An AppImage is an outer filesystem/runtime format, not a Python freezer. A robust
PyQt6 design is:

```text
Python + PyQt6
   -> PyInstaller onedir or Nuitka standalone
   -> AppDir
      AppRun
      .desktop
      icon
      usr/bin/application + runtime
      usr/share/icons
      usr/share/metainfo
   -> pinned appimagetool/linuxdeploy
   -> AppImage
```

The AppImage project's
[concepts](https://docs.appimage.org/introduction/concepts.html) recommend
bundling what cannot reasonably be expected on target systems and building on an
old supported system. Its
[best practices](https://docs.appimage.org/reference/best-practices.html) stress
old-enough binaries, relative paths, and testing target bases.

### Base image and GLIBC

Build on the oldest GLIBC-based distribution you promise to support. A binary
built on a newer GLIBC may reference symbols unavailable on older systems;
bundling a second glibc is not a simple cure. The Python and PyQt6 wheels also
carry compatibility floors, so inspect the complete payload, not only your code.

**[FROM DIKTE]** `ubuntu-22.04` is intentionally fixed rather than
`ubuntu-latest`. Improve this further with a versioned container image digest or
an explicit runner image whose lifecycle you track.

### AppDir template

```text
MyApplication.AppDir/
├── AppRun
├── myapplication.desktop
├── myapplication.png
└── usr/
    ├── bin/
    │   ├── myapplication
    │   └── _internal/...
    └── share/
        ├── applications/myapplication.desktop   # optional duplicate/integration
        ├── icons/hicolor/256x256/apps/myapplication.png
        └── metainfo/org.example.MyApplication.metainfo.xml
```

**[TEMPLATE — TEST BEFORE USE]** `AppRun`:

```sh
#!/bin/sh
set -eu
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/myapplication" "$@"
```

Desktop file:

```ini
[Desktop Entry]
Type=Application
Name=MyApplication
Comment=What the application does
Exec=myapplication
Icon=myapplication
Categories=Utility;
Terminal=false
StartupNotify=true
```

AppStream metainfo is worth adding for software centers and richer metadata.
Validate the desktop and metainfo files with the distribution tools available in
the build image.

### Build template

```bash
#!/usr/bin/env bash
# TEMPLATE — TEST BEFORE USE
set -euo pipefail

appdir="$PWD/build/MyApplication.AppDir"
standalone="$PWD/build/dist/MyApplication"
out="$PWD/dist/MyApplication-1.2.3-x86_64.AppImage"

python -m PyInstaller packaging/myapp.spec \
  --distpath build/dist --workpath build/work --noconfirm --clean

install -d "$appdir/usr/bin" "$appdir/usr/share/icons/hicolor/256x256/apps"
cp -a "$standalone/." "$appdir/usr/bin/"
install -m 0755 packaging/linux/AppRun "$appdir/AppRun"
install -m 0644 packaging/linux/myapplication.desktop "$appdir/myapplication.desktop"
install -m 0644 packaging/linux/myapplication.png "$appdir/myapplication.png"
install -m 0644 packaging/linux/myapplication.png \
  "$appdir/usr/share/icons/hicolor/256x256/apps/myapplication.png"

packaging/tools/appimagetool "$appdir" "$out"
```

Pin appimagetool/linuxdeploy to a reviewed release and verify its digest before
execution. **[FROM DIKTE]** Direct `continuous` downloads without hashes should
not be copied.

### Loader and child-process environment

Frozen apps often modify `LD_LIBRARY_PATH`. A child host binary may then load the
bundle's `libstdc++`, OpenSSL, or other libraries and fail. **[FROM DIKTE]** Save
and restore the original loader path before starting host tools. Do this narrowly:

- understand which environment variables the freezer sets;
- restore them only for external host processes or before process-wide child
  launching if the frozen program already loaded its own libraries;
- verify Qt's late-loaded plugins still resolve through RPATH/library paths;
- test AppImageLauncher and desktop integration.

TLS trust stores vary across distro families. Prefer the host's current trust
store rather than a stale copied CA bundle when using host trust is the product
policy. Respect explicit `SSL_CERT_FILE`/`SSL_CERT_DIR` and test Debian, Fedora,
openSUSE, and Arch layouts. This is another strong **[FROM DIKTE]** lesson.

### AppImage test matrix

At minimum:

| Family | Purpose |
|---|---|
| oldest supported Ubuntu/Debian | GLIBC floor and baseline |
| current Ubuntu/Debian | common desktop integration |
| Fedora/RHEL-like | trust store, newer system libs, SELinux context |
| Arch/openSUSE | non-Debian paths and fast-moving libraries |
| X11 and Wayland sessions | Qt platform/plugin behavior |

Tests:

```bash
chmod +x MyApplication.AppImage
./MyApplication.AppImage --version
QT_DEBUG_PLUGINS=1 ./MyApplication.AppImage
```

Also exercise HTTPS, native dialogs, icons, system themes, child processes,
audio/video, desktop entry, autostart if applicable, filename paths containing
spaces, and relocation after first run. CI containers without a display need
Xvfb/offscreen tests, but they do not replace a real desktop smoke test.

# Debian/Ubuntu `.deb`

## 11. Choose Native Dependencies or Bundled Runtime

These are different products:

### Native policy-style package

```text
Depends: python3, python3-pyqt6, ffmpeg, ...
Installs source/private modules and desktop files
Uses distro security updates for Python/Qt
Small package; release-specific dependency availability
```

Advantages:

- integrates with apt and distribution security updates;
- small downloads and no duplicated Qt;
- aligns with Debian Python Policy.

Disadvantages:

- exact PyQt6/Qt version varies by distro release;
- dependency package names/features differ;
- old releases may not have the required PyQt6;
- maintainer work across Debian/Ubuntu series.

### Bundled upstream `.deb`

```text
Depends: basic system libraries/tools
Installs a PyInstaller/Nuitka standalone tree under /opt or /usr/lib
Consistent upstream runtime
Large package; upstream owns every Python/Qt security rebuild
```

This can be practical for a project's own download, but do not present it as a
normal Debian archive package. Never install a pip-created venv under system
paths during `postinst`; build deterministic payloads before package assembly.

For a native package, follow
[Debian Python Policy](https://www.debian.org/doc/packaging-manuals/python-policy/)
and current debhelper/pybuild guidance. Exact control fields must be tested on
each target release.

## 12. Reusable Native Debian Skeleton

```text
debian/
├── changelog
├── control
├── copyright
├── rules
├── source/format
├── myapplication.install
└── myapplication.lintian-overrides    # only justified exceptions, if any
```

`debian/control`:

```debcontrol
Source: myapplication
Section: utils
Priority: optional
Maintainer: Your Name <maintainer@example.org>
Build-Depends:
 debhelper-compat (= 13),
 dh-sequence-python3,
 pybuild-plugin-pyproject,
 python3-all,
 python3-build,
 python3-pyqt6
Standards-Version: 4.7.2
Rules-Requires-Root: no
Homepage: https://github.com/example/myapplication

Package: myapplication
Architecture: all
Depends:
 ${misc:Depends},
 ${python3:Depends},
 python3-pyqt6,
 ffmpeg
Description: short description
 Long description of the application.
```

Package names and Standards-Version above are illustrative and temporally
sensitive. Verify with the target distribution; `pybuild-plugin-pyproject` may
not exist or have that name in every supported Ubuntu release.

`debian/rules`:

```make
#!/usr/bin/make -f
%:
	dh $@ --buildsystem=pybuild
```

`debian/source/format`:

```text
3.0 (quilt)
```

Example install map:

```text
src/myapp/                           usr/lib/myapplication/myapp/
packaging/linux/myapplication        usr/bin/
packaging/linux/myapplication.desktop usr/share/applications/
packaging/linux/icons/               usr/share/icons/hicolor/
README.md                            usr/share/doc/myapplication/
```

For a proper `pyproject.toml` application, let pybuild install through the build
backend instead of manually copying source when possible. Use `debian/*.install`
for desktop integration files not handled by the Python backend.

### Paths

- `/usr/bin/myapplication`: small launcher/entry command.
- `/usr/lib/myapplication` or `/usr/share/myapplication`: private application
  modules depending on architecture-specific content.
- `/usr/share/applications/*.desktop`: menu integration.
- `/usr/share/icons/hicolor/<size>x<size>/apps/*.png`: icons.
- `/usr/share/metainfo/*.metainfo.xml`: AppStream.
- `/usr/share/doc/myapplication`: changelog/copyright/docs.

Do not install application state or user configuration into home directories
from maintainer scripts. The application creates XDG user state when run.

## 13. Debian Versioning and Tests

Debian version examples:

```text
1.2.3-1            upstream 1.2.3, Debian packaging revision 1
1.2.3-1~ubuntu1    sorts before 1.2.3-1; use only with a defined policy
```

Build/test sequence:

```bash
dpkg-buildpackage -us -uc -b
dpkg-deb --info ../myapplication_1.2.3-1_all.deb
dpkg-deb --contents ../myapplication_1.2.3-1_all.deb
lintian ../myapplication_1.2.3-1_all.deb
```

Test installation in a disposable clean VM/container, not the development host:

```bash
sudo apt install ./myapplication_1.2.3-1_all.deb
myapplication --version
sudo apt remove myapplication
sudo apt purge myapplication
```

`dpkg -i file.deb` does not resolve dependencies by itself; `apt install
./file.deb` normally does. If testing the failure/recovery path intentionally:

```bash
sudo dpkg -i ./myapplication.deb
sudo apt --fix-broken install
```

Verify dependency closure, desktop entry validation, icons, AppStream metadata,
upgrade/downgrade behavior, purge behavior, file ownership, and that no private
venv downloads occur during install.

**[FROM DIKTE]** There is no Dikte `.deb`; this whole section is general guidance.

# macOS

## 14. macOS Application Bundle

```text
MyApplication.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/MyApplication
    ├── Resources/MyApplication.icns
    ├── Resources/... application data
    ├── Frameworks/... Python/Qt/frameworks
    └── PlugIns/... Qt plugins (layout tool-dependent)
```

PyInstaller can create the bundle with `BUNDLE`; Nuitka offers app-bundle mode,
subject to the exact binding/tool support. Build natively for arm64 and x86_64,
or prove every Python/PyQt/native dependency supports a universal2 build before
promising one artifact.

Essential `Info.plist` concepts:

- stable reverse-DNS `CFBundleIdentifier`;
- `CFBundleName`, display name, executable;
- short marketing version and monotonically suitable bundle version;
- minimum system version based on tested compatibility;
- icon;
- category/document types if applicable;
- privacy usage descriptions for microphone, camera, contacts, etc.;
- `LSUIElement` only for a true menu-bar/background UI.

**[FROM DIKTE]** Add external helpers before the final signature. Adding ffmpeg
after signing invalidates the bundle seal.

## 15. Developer ID Signing

### Free tools versus Apple account

Free/open tooling:

- Xcode command-line tools, `codesign`, `hdiutil`, `security`, `spctl`, `stapler`;
- ad-hoc signature with identity `-` for local structural needs;
- DMG creation.

Requires Apple Developer Program credentials:

- Developer ID Application certificate for direct app distribution;
- access to Apple's notary service;
- optionally Developer ID Installer for `.pkg` distribution.

Ad-hoc signing is not a substitute for Developer ID. **[FROM DIKTE]** Dikte uses
ad-hoc signing and transparently documents Gatekeeper refusal; this is useful as
an educational contrast, not the recommended professional endpoint.

### Hardened signing sequence

Apple requires valid Developer ID signatures, hardened runtime, and secure
timestamps for notarization. See
[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime).

Use an explicit inside-out signing order rather than relying on `--deep` to make
decisions:

```text
finish .app contents
 -> sign nested helper executables
 -> sign dylibs/framework binaries and nested bundles
 -> sign frameworks/bundles
 -> sign outer .app with --options runtime --timestamp
 -> codesign --verify --deep --strict
 -> spctl assessment
```

Entitlements must be the minimum the application actually needs. Python/JIT
behavior and third-party native libraries may require carefully justified
runtime entitlements; do not paste `allow-unsigned-executable-memory` or disable
library validation merely to make errors disappear. Test microphone,
Accessibility, Apple Events, updates, and helper processes under the hardened
signature.

**[TEMPLATE — TEST BEFORE USE]** The identity stays in a protected CI variable;
no certificate material belongs in YAML:

```bash
identity="Developer ID Application: Example Publisher (TEAMID)"
app="dist/MyApplication.app"

# Sign nested code explicitly here, deepest first.

codesign --force --options runtime --timestamp \
  --entitlements packaging/macos/entitlements.plist \
  --sign "$identity" "$app"

codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=4 "$app"
```

Do not expose the identity's private key or keychain password in logs.

## 16. DMG, Notarization, and Stapling

One robust sequence is:

```text
Developer ID-signed hardened .app
  -> create DMG containing app + /Applications link
  -> sign DMG
  -> submit DMG with notarytool --wait
  -> inspect log/result
  -> staple ticket to DMG
  -> validate staple
  -> mount on clean Mac and verify installed app/Gatekeeper
```

Apple can notarize apps, ZIPs, DMGs, and flat packages. Pick one documented
deliverable and staple where supported. **[TEMPLATE — TEST BEFORE USE]** With a
notary profile securely stored in the runner keychain:

```bash
app="dist/MyApplication.app"
dmg="dist/MyApplication-1.2.3-arm64.dmg"
identity="Developer ID Application: Example Publisher (TEAMID)"

stage="build/dmg-stage"
mkdir -p "$stage"
cp -a "$app" "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "MyApplication 1.2.3" \
  -srcfolder "$stage" -ov -format UDZO "$dmg"

codesign --force --timestamp --sign "$identity" "$dmg"
codesign --verify --verbose=2 "$dmg"

xcrun notarytool submit "$dmg" \
  --keychain-profile "NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg"
```

The exact `spctl` assessment mode can vary by deliverable and OS version; test on
the supported macOS range. Never treat a successful upload alone as success:
check the notary result/log, staple, validate, and launch a quarantined download
on a separate clean machine.

### CI credentials

Typical protected values (names are examples, not Dikte secrets):

- base64-encoded Developer ID certificate only if a secure cloud/HSM signing
  route is unavailable;
- certificate import password;
- temporary keychain password;
- Apple issuer ID, key ID, and App Store Connect API private key, or an app-
  specific password/team ID route supported by `notarytool`;
- signing identity/team ID.

Prefer a GitHub Environment requiring approval for release signing. Import into
an ephemeral keychain, restrict access, and delete it after the job. Avoid pull
request access to signing secrets.

# GitHub Actions

## 17. Reusable CI Architecture

**[FROM DIKTE]** Put platform build logic in scripts and invoke one reusable
matrix workflow from both packaging PRs and releases. Keep release decisions and
artifact construction separate.

```text
                         Git tag
                            |
                +-----------+-----------+
                |           |           |
             Windows      Linux       macOS
                |           |           |
          standalone     AppImage       .app
                |           + DEB        |
          sign inner                   sign app
                |                       |
            installer                 DMG
                |                       |
          sign installer             notarize
                +-----------+-----------+
                            |
                   smoke-test artifacts
                            |
                 SHA-256/SBOM/attestation
                            |
                      GitHub Release
```

## 18. Build Workflow Fragment

**[TEMPLATE — TEST BEFORE USE]** Pin actions to reviewed commit SHAs in a real
supply-chain-sensitive workflow; version tags below are readable placeholders.

```yaml
name: build-artifacts

on:
  workflow_call:
    inputs:
      ref:
        required: true
        type: string
  pull_request:
    paths:
      - "packaging/**"
      - ".github/workflows/build.yml"

permissions:
  contents: read

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: windows-latest
            kind: windows
          - os: ubuntu-22.04
            kind: appimage
          - os: ubuntu-24.04
            kind: deb
          - os: macos-latest
            kind: macos-arm64
          - os: macos-15-intel
            kind: macos-x86_64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.ref || github.sha }}
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12.10"  # example; choose a supported exact version
          cache: pip
      - run: python -m pip install --require-hashes -r packaging/requirements-build.txt
      - run: python -m unittest discover
      - name: Build
        shell: bash
        run: ./packaging/build-${{ matrix.kind }}.sh
      - uses: actions/upload-artifact@v4
        with:
          name: myapplication-${{ matrix.kind }}
          path: dist/*
          if-no-files-found: error
```

Do not build a Debian package on a newer base than the distribution it targets.
The two Linux matrix rows above illustrate different products; their exact
runners/containers require deliberate selection.

## 19. Signing Workflow Boundaries

Never expose signing credentials to untrusted pull requests. A common pattern:

```text
PR build: unsigned, fully tested artifacts
tag build: protected environment approval
    -> rebuild from tag in trusted job
    -> sign/notarize
    -> verify
    -> publish
```

For stronger assurance, build once, attest the unsigned payload, promote the
same immutable payload into a signing job, and ensure the signing job changes
only signature-bearing containers. The correct design depends on signing service
interfaces and whether signing modifies the artifact in place.

Use environment-scoped secrets and minimal permissions. Example secret purposes:

| Secret | Purpose |
|---|---|
| `WINDOWS_SIGNING_*` | cloud-signing identity/client credentials or protected certificate material |
| `MACOS_CERTIFICATE_*` | Developer ID import material when cloud signing is unavailable |
| `MACOS_NOTARY_*` | notarytool API credentials/profile inputs |
| `MACOS_TEAM_ID` | public team identifier used by signing/notarization commands |

These are suggested names only. Dikte currently uses none of them.

## 20. Integrity, Checksums, SBOM, and Provenance

After all signing/stapling is final, generate hashes:

```bash
cd dist
sha256sum MyApplication-* > SHA256SUMS
sha256sum -c SHA256SUMS
```

On macOS use `shasum -a 256` if GNU `sha256sum` is unavailable. Generate the
manifest from final bytes; signing afterward changes hashes.

An SBOM tool can inventory the locked Python environment and packaged native
components, but validate that it sees embedded/freezer dependencies. Publish the
SBOM next to artifacts and update it every release.

GitHub's
[artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
use Sigstore-backed claims connecting artifact digests to workflow/source
identity. A typical action needs `id-token: write` and `attestations: write` plus
the documented subject path. Consult the current
[GitHub attestation guide](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
instead of copying a stale YAML block.

Checksums, signatures, SBOMs, and provenance answer different questions:

| Control | Answers |
|---|---|
| SHA-256 | Are these bytes the expected bytes? |
| Code signature | Which signing identity approved these bytes; were they changed? |
| Timestamp | Was the signature made while its certificate was valid? |
| SBOM | What components are reported inside? |
| Provenance attestation | Which repository/workflow/event produced this digest? |
| Reproducible build | Can independent builders recreate identical/equivalent output? |

None proves the software has no vulnerabilities or malicious behavior.

## 21. Artifact-Level Verification Checklist

### Every platform

- install/launch on a clean supported machine;
- launch without developer Python, Qt, compilers, or PATH entries;
- test non-ASCII username and spaces in install path;
- test first run, second run, upgrade, downgrade policy, uninstall;
- verify settings/user data preservation and purge behavior;
- exercise all dynamically loaded Qt features;
- exercise HTTPS/TLS and proxy/custom enterprise CA behavior;
- inventory licenses and included binaries;
- verify final hash and provenance.

### Windows

- inspect PE version info and manifest;
- verify GUI does not open a console;
- verify CLI output if supplied;
- `signtool verify /pa /all /v` inner EXEs, setup, and uninstaller;
- install as standard user;
- test Defender/SmartScreen and record exact distinction/results;
- scan final signed installer, not an earlier unsigned build.

### AppImage

- oldest supported GLIBC distro plus different families;
- X11 and Wayland;
- FUSE and `--appimage-extract-and-run`/fallback expectations;
- host child tools do not inherit incompatible bundle libraries;
- CA store works across Debian/Fedora/openSUSE/Arch layouts;
- desktop file/icon/AppStream validation;
- move/rename AppImage after integration.

### Debian

- `dpkg-deb --info` and `--contents`;
- `lintian` with no unexplained overrides;
- dependency resolution through `apt install ./...deb`;
- no network in package build/install unless explicitly permitted by policy;
- clean upgrade/remove/purge and correct file ownership.

### macOS

- both architectures or a verified universal bundle;
- `codesign --verify --deep --strict --verbose=2`;
- `spctl` acceptance;
- `stapler validate`;
- download through a browser so quarantine is present;
- microphone/Accessibility/Apple Events permissions across an update;
- no post-sign mutation;
- mount/copy/launch DMG on a clean supported Mac.

## 22. Classification of Techniques

- **[HIGHLY RECOMMENDED]** onedir/standalone under installer/AppImage/DMG: avoids
  redundant extraction and is easier to test.
- **[HIGHLY RECOMMENDED]** exact dependency locks/hashes: makes release inputs
  reviewable and repeatable.
- **[HIGHLY RECOMMENDED]** native builds for each OS/architecture: Python freezers
  are not general cross-compilers.
- **[HIGHLY RECOMMENDED]** sign inner Windows executables and outer installer,
  with timestamps: establishes publisher/integrity at both layers.
- **[HIGHLY RECOMMENDED]** Developer ID + hardened runtime + notarization +
  stapling: normal direct macOS distribution path.
- **[HIGHLY RECOMMENDED]** old Linux build base plus cross-distro smoke tests:
  manages the GLIBC floor and host integration risk.
- **[HIGHLY RECOMMENDED]** pin/checksum every downloaded build tool/helper.
- **[HIGHLY RECOMMENDED]** final SHA-256, SBOM, and provenance attestation.
- **[USEFUL]** PyInstaller: fastest path to a mature PyQt6 freezer and easiest
  onedir debugging.
- **[USEFUL]** Nuitka standalone: serious alternative when measured build/runtime
  and security-tool behavior justify compiler complexity.
- **[USEFUL]** Inno Setup per-user install: practical classic desktop delivery.
- **[USEFUL]** native Debian package alongside AppImage: serves apt integration
  and universal upstream download as separate use cases.
- **[USEFUL]** separate GUI and CLI Windows launchers: only when both interfaces
  are real product requirements.
- **[PROJECT-SPECIFIC]** Dikte's self-drawn icons, self-integrating AppImage,
  autostart defaults, ffmpeg selection, and Qt exclusion list.
- **[LEGACY]** unsigned/ad-hoc distribution as a long-term release strategy. It
  may be an unavoidable early-project state, not a target architecture.
- **[NOT RECOMMENDED]** mutable continuous tool downloads without verification.
- **[NOT RECOMMENDED]** UPX/obfuscation/evasion experiments presented as AV fixes.
- **[NOT RECOMMENDED]** teaching users to disable antivirus or remove macOS
  quarantine instead of improving distribution trust.
- **[NOT RECOMMENDED]** calling a PyInstaller payload in a `.deb` a native Debian
  package without explaining bundled-runtime consequences.
- **[REQUIRES FURTHER RESEARCH]** current PyQt6/Nuitka macOS support for the exact
  chosen releases.
- **[REQUIRES FURTHER RESEARCH]** which freezer has better antivirus reputation
  for your signed application over multiple releases.
- **[REQUIRES FURTHER RESEARCH]** the exact oldest distro/macOS/Windows versions
  supported by all selected Python, PyQt6, Qt, and native-wheel inputs.

## 23. Recommended Starting Architecture

For a small open-source PyQt6 project today, start here:

1. PyInstaller onedir across all three platforms for the first reliable baseline.
2. In parallel, benchmark Nuitka standalone on Windows; adopt it there if it wins
   repeatably and keeping two freezer configurations is acceptable.
3. Inno Setup per-user installer plus optional portable ZIP on Windows.
4. A manually controlled or linuxdeploy-created AppImage on an old pinned Linux
   base, plus a separate native `.deb` for supported Debian/Ubuntu releases.
5. PyInstaller `.app` inside architecture-specific DMGs on macOS unless a fully
   tested universal2 dependency stack exists.
6. Budget for Windows signing and Apple Developer membership early; they are user
   trust/distribution infrastructure, not cosmetic extras.
7. Make artifact smoke tests, signing verification, checksums, SBOM, and
   provenance release gates.

That architecture keeps the first implementation understandable, leaves room for
Nuitka where it provides demonstrated value, and treats AppImage, Debian, and
macOS trust as distinct engineering problems rather than file extensions added
after freezing.
