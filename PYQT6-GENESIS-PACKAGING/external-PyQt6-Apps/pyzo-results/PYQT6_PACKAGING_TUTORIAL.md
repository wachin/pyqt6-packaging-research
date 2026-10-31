# Practical PyQt6 Packaging Tutorial

This is a reusable guide distilled from the Pyzo case study and current primary tool/vendor documentation. It is deliberately not a copy-paste promise: Qt plugin needs, native libraries, signing identities, installer policy, and licensing are application-specific. Build and test release candidates on each target platform.

## 1. Decide the Product Contract First

Write down the supported architectures, oldest supported OS releases, Python/Qt versions, update policy, and whether every platform needs a portable archive, native installer, or both. A practical open-source baseline is:

```text
tag vX.Y.Z
  ├─ Windows x64: signed onedir/standalone -> signed installer + ZIP
  ├─ Linux x86_64: AppImage + Debian/Ubuntu .deb
  └─ macOS arm64 + x86_64/universal: signed/notarized .app -> DMG + ZIP
```

Pyzo directly demonstrates native builds, onedir packaging, frozen-app smoke tests, GitHub release publishing, and macOS notarization. The Windows signing, AppImage, Debian, hashes, SBOM, and provenance recommendations below are **general recommendations**, because Pyzo does not implement them.

## 2. Shared Project Layout and Build Discipline

Prefer a small, explicit release surface:

```text
myapp/
├── pyproject.toml
├── src/myapp/__main__.py
├── src/myapp/resources/             # data shipped as files
├── packaging/
│   ├── pyinstaller/myapp.spec       # or Nuitka project options
│   ├── windows/myapp.iss
│   ├── linux/AppDir/
│   └── debian/
├── requirements-release.txt         # preferably generated from a lock
└── .github/workflows/release.yml
```

Use a clean virtual environment per target. Pin or constrain release dependencies, including Python, PyQt6, freezer, and installer tools; record their versions in build logs. Pyzo currently uses `pip install -U`, which is convenient but not reproducible. For release builds, prefer a reviewed lock file or a generated constraints file with hashes.

```bash
python -m venv .venv
. .venv/bin/activate                 # Windows PowerShell: .venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-release.txt
python -m pip check
python -m pytest -q
```

Keep application resources either as ordinary package files (easy to inspect/replace) or in a Qt `.qrc` resource collection (immutable assets embedded in code). Do not use `sys._MEIPASS` throughout application code: isolate resource discovery in one helper. `importlib.resources` is often appropriate for an installed Python package; freezer-specific resource paths belong in packaging adapters.

## 3. Choose PyInstaller or Nuitka by Evidence

### PyInstaller

PyInstaller is usually the fastest path to a reliable Qt bundle: it has mature hooks, clear `--collect-*`/hidden-import diagnostics, and produces a readable directory tree. Build Windows on Windows, Linux on Linux, and macOS on macOS—PyInstaller is not a cross-compiler ([PyInstaller manual](https://pyinstaller.org/en/stable/index.html)).

Start with **onedir**, not onefile:

```bash
pyinstaller --noconfirm --clean --onedir --windowed \
  --name MyApp --icon packaging/icons/myapp.ico \
  --add-data "src/myapp/resources:myapp/resources" \
  --collect-all PyQt6 \
  src/myapp/__main__.py
```

On Windows, `;` replaces `:` in `--add-data`. In a real app, replace broad collection with tested targeted collection where possible. Pyzo demonstrates explicit Qt module inclusion/exclusion to prevent unused modules from ballooning the bundle; its configuration is valuable, but its “almost all stdlib” inclusion is IDE-specific.

`--windowed` (also called `--noconsole`) removes the console for a GUI app. `--onefile` creates a single executable but introduces startup extraction and makes diagnosis/inspection harder. Use it only after testing, not merely because single files look convenient. PyInstaller documents `--onedir`, `--windowed`, UPX behavior, and `--noupx` ([PyInstaller usage](https://pyinstaller.org/en/stable/usage.html)).

Make a maintained `.spec` file once command complexity rises. Put data/binaries/hidden imports/excludes/version resources there and code-review it. Test clean output by launching the actual executable, not `python -m myapp`.

### Nuitka

Nuitka compiles Python modules and can make standalone/onefile builds. It is a sound option if measured release candidates show better startup, compatibility, or AV outcomes for your app and the compiler/toolchain burden is acceptable. Its Qt support is intentional, but you still must declare Qt plugin needs.

```bash
python -m nuitka --mode=standalone --enable-plugin=pyqt6 \
  --windows-console-mode=disable \
  --windows-icon-from-ico=packaging/icons/myapp.ico \
  --include-data-dir=src/myapp/resources=myapp/resources \
  --output-dir=build/nuitka src/myapp/__main__.py
```

The exact option names/features evolve; consult the installed Nuitka version’s help/manual and test on each OS. Nuitka documents PySide/PyQt plugin support and standalone/onefile/app modes ([Nuitka manual](https://nuitka.net/user-documentation/user-manual.html)). It needs a supported compiler toolchain and commonly builds more slowly than PyInstaller.

### Decision rule

Do a release-candidate comparison, ideally for two releases:

| Criterion | Measure |
| --- | --- |
| Functional behavior | startup, native file dialogs, printing, SVG/images, networking, update checks |
| Platform coverage | clean VMs/physical machines at the oldest supported OS baseline |
| Operations | build duration, diagnostics, developer familiarity, CI setup |
| Artifact behavior | size, cold start, install/uninstall, code-signing success |
| Security/reputation | signed samples, VT trend, vendor false-positive process—not a one-off score |

Choose one tool per product/target unless a documented platform exception is justified. Neither tool guarantees zero antivirus detections.

## 4. Windows: Professional Release Pipeline

### Target sequence

```text
PyQt6 source -> clean locked venv -> onedir/standalone bundle
  -> test bundle -> version/icon/manifest metadata
  -> Authenticode sign + timestamp application binaries
  -> build Inno Setup installer -> sign + timestamp installer
  -> clean-VM install test -> SHA256/SBOM/provenance -> GitHub Release
```

Pyzo supplies the onedir plus Inno Setup portion, but its tracked workflow contains no Windows signing. Treat signing as a separate mandatory design decision for public Windows distribution.

### Metadata

Give every release a stable product name, publisher, semantic version, copyright, icon, and application identifier. For PyInstaller, use a Windows version-information resource and test it with Explorer’s Properties dialog. Add a manifest only when you know the desired UAC/DPI/compatibility policy; do not request administrator elevation by default merely because an installer exists.

An Inno Setup skeleton:

```ini
[Setup]
AppId={{YOUR-STABLE-GUID-OR-ID}}
AppName=MyApp
AppVersion=1.2.3
AppPublisher=Your project
AppPublisherURL=https://example.org
DefaultDirName={autopf}\MyApp
PrivilegesRequired=lowest
OutputBaseFilename=MyApp-1.2.3-win64-setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "..\..\dist\MyApp\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\MyApp"; Filename: "{app}\MyApp.exe"
Name: "{autodesktop}\MyApp"; Filename: "{app}\MyApp.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; Flags: unchecked
```

Compile with `ISCC.exe packaging\windows\myapp.iss`. Use MSI/WiX or MSIX only when deployment management, Store integration, or enterprise policy requires them; they add complexity without automatically solving code-signing or AV reputation.

### Legitimate antivirus/SmartScreen hygiene

The goal is trustworthiness, never evasion.

- Build from a clean, controlled environment with pinned dependencies; retain build logs and source tag.
- Prefer onedir/standalone to onefile unless onefile has a product requirement. This is a troubleshooting/operational preference, not a proven universal AV cure.
- Use current supported freezer/Qt versions; avoid obfuscators, binary patching, and unnecessary packers.
- Make UPX policy explicit. If you do not need it, disable it (`--noupx`) or keep it unavailable. PyInstaller may use UPX if available; PyInstaller does not claim it prevents detection ([PyInstaller usage](https://pyinstaller.org/en/stable/usage.html)).
- Set proper icon/version/publisher metadata; sign with a real Authenticode identity and timestamp every distributed executable/installer.
- Maintain stable publisher identity and transparent GitHub Releases/source/release notes.
- Scan a release candidate with VirusTotal as a signal. A result is point-in-time and vendor-specific; it neither proves malware nor guarantees future results. Investigate unexpected detections, avoid shipping known suspicious artifacts, and submit demonstrable false positives to the relevant vendors.
- Publish SHA-256 hashes and build provenance. This helps users verify origin/integrity, but does not directly change heuristic detection.

### Authenticode sequence

Obtain a certificate from a suitable certificate authority and store it using your CI provider/HSM/cloud-signing mechanism. Never put PFX files or passwords in source control. Conceptual commands (replace provider-specific values):

```powershell
signtool sign /fd SHA256 /tr https://timestamp.example-ca.invalid /td SHA256 `
  /f $env:SIGNING_PFX /p $env:SIGNING_PFX_PASSWORD dist\MyApp\MyApp.exe

ISCC.exe packaging\windows\myapp.iss

signtool sign /fd SHA256 /tr https://timestamp.example-ca.invalid /td SHA256 `
  /f $env:SIGNING_PFX /p $env:SIGNING_PFX_PASSWORD dist\MyApp-1.2.3-win64-setup.exe

signtool verify /pa /all dist\MyApp\MyApp.exe
signtool verify /pa /all dist\MyApp-1.2.3-win64-setup.exe
```

Adapt this to the certificate vendor’s current tooling and hardware/cloud-key requirements. Sign the final application executable and relevant native DLLs as policy requires, then build/sign the installer. Timestamping keeps signatures valid after certificate expiry. Code signing and time/reputation can reduce warnings, but neither guarantees SmartScreen approval or a clean VirusTotal report.

### Hashes

```powershell
Get-FileHash dist\MyApp-1.2.3-win64-setup.exe -Algorithm SHA256
Get-FileHash dist\MyApp-1.2.3-win64.zip -Algorithm SHA256
```

Generate a `SHA256SUMS.txt` covering **all** release assets, then test it from a fresh download. Consider signing the checksum manifest too.

## 5. Linux AppImage: A Separate Portable Product

An AppImage is not a `.tar.gz`: it is a self-contained executable image with an AppDir layout. Pyzo does not implement AppImage, so this section is general guidance.

```text
PyQt6 application/runtime -> AppDir
  ├─ AppRun
  ├─ usr/bin/myapp
  ├─ usr/lib/...                  # only libraries you are allowed/need to bundle
  ├─ usr/plugins/...              # Qt platform/image/etc plugins as needed
  ├─ usr/share/applications/org.example.MyApp.desktop
  ├─ usr/share/icons/hicolor/.../apps/org.example.MyApp.png
  └─ usr/share/metainfo/org.example.MyApp.metainfo.xml
       -> appimagetool -> MyApp-x86_64.AppImage
```

### Build strategy

1. Choose an intentionally old supported Linux base/container for the target glibc baseline. Building on a newer distribution can create binaries requiring newer `GLIBC_*` symbols than an older user machine has.
2. Build an onedir/standalone app inside that environment.
3. Stage the app into `AppDir/usr/`; place desktop file, icon, and AppStream metadata in the standard locations.
4. Use `linuxdeploy` with its Qt plug-in, `appimage-builder`, or a carefully audited manual AppDir plus `appimagetool`. Pick one and version/pin it in CI.
5. Ensure `AppRun` supplies application-relative paths only where necessary (e.g., `QT_PLUGIN_PATH`, `QML2_IMPORT_PATH`, `LD_LIBRARY_PATH`). Prefer rpath/$ORIGIN over broad environment overrides where tooling supports it.
6. Run `appimagetool` and test the final `.AppImage` under a non-root user.

Example desktop entry:

```ini
[Desktop Entry]
Type=Application
Name=MyApp
Exec=myapp %F
Icon=org.example.MyApp
Categories=Utility;Development;
Terminal=false
StartupNotify=true
```

Qt deployment details are application-dependent. Test the `platforms` plugin (typically `libqxcb.so`), image format plugins if your app loads those formats, icon engines/styles if used, print support, QML if used, and any TLS/network backends if used. Do not blindly bundle system graphics drivers, glibc, or prohibited LGPL/GPL components; understand each dependency’s license and compatibility. Pyzo’s Linux archive needs host XCB/DBus libraries in CI, illustrating why a simple freeze is not automatically broadly portable.

### AppImage test matrix

- Run the file itself (`chmod +x` then launch), not the uncompressed AppDir only.
- Test an older Ubuntu/Debian baseline, a current Ubuntu/Fedora-like distribution, and an Arch-like rolling distribution if claimed.
- Test X11 and, where relevant, Wayland/XWayland; native dialogs, clipboard, high-DPI, OpenGL/graphics, icons/images, print, and language changes.
- Inspect `ldd`/`readelf`/`objdump` results and runtime logs; do not rely on one CI machine.
- Verify desktop integration after first launch and removal behavior.

## 6. Debian/Ubuntu `.deb`: A Native Package, Not an AppImage

For Debian-family users, default to a package that installs source/wheel files and **depends on distro Python/PyQt6 packages**. This integrates with OS updates and security maintenance. Do not normally duplicate a frozen Python/Qt runtime in a `.deb`; doing so fights the package manager and increases security update responsibility.

```text
packaging/debian/
├── DEBIAN/control
├── DEBIAN/copyright
├── DEBIAN/changelog
├── usr/bin/myapp
├── usr/lib/python3/dist-packages/myapp/...
├── usr/share/applications/org.example.MyApp.desktop
├── usr/share/icons/hicolor/256x256/apps/org.example.MyApp.png
└── usr/share/metainfo/org.example.MyApp.metainfo.xml
```

Minimal `DEBIAN/control` for a staged package:

```text
Package: myapp
Version: 1.2.3-1
Section: utils
Priority: optional
Architecture: all
Maintainer: Your Project <release@example.org>
Depends: ${misc:Depends}, python3 (>= 3.10), python3-pyqt6
Description: Short description
 Longer description.
```

The package’s launcher at `/usr/bin/myapp` can be a small executable script that imports the installed package, and the desktop file invokes `myapp %F`. Use `Architecture: all` only if no package-installed native architecture-specific files exist. In a real Debian-maintained package, use Debian tooling (`debian/control`, `debian/rules`, `dh`, `pybuild`) and the target distribution’s current Python/PyQt6 package names/policies rather than treating the above staging tree as universal.

Build/test a simple staging package:

```bash
dpkg-deb --build packaging/debian myapp_1.2.3-1_all.deb
dpkg-deb --info myapp_1.2.3-1_all.deb
dpkg-deb --contents myapp_1.2.3-1_all.deb
sudo dpkg -i myapp_1.2.3-1_all.deb
sudo apt -f install
lintian myapp_1.2.3-1_all.deb
sudo dpkg -r myapp
```

Test in a clean disposable VM/container; `dpkg -i` does not automatically resolve all dependencies, while `apt` can. Version Debian packages with a valid Debian version (`upstream-version-debian-revision`); use a changelog and release tags. If you need a self-contained Linux product, make it an AppImage/Flatpak rather than silently shipping an opaque frozen runtime inside a conventional `.deb`.

## 7. macOS: `.app`, Signing, Notarization, DMG

Pyzo is directly instructive here. Its CI does:

```text
PyInstaller .app -> code-sign/hardened runtime/timestamp
  -> ZIP app for notarization -> notarytool submit/wait -> staple .app
  -> create DMG and ZIP -> GitHub Release
```

PyInstaller example:

```bash
pyinstaller --noconfirm --clean --windowed --onedir \
  --name MyApp --icon packaging/icons/MyApp.icns \
  --osx-bundle-identifier org.example.MyApp \
  --add-data "src/myapp/resources:myapp/resources" \
  --collect-all PyQt6 src/myapp/__main__.py
```

Inspect the result before signing:

```text
MyApp.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/MyApp
    ├── Frameworks/ or _internal/   # freezer/version dependent
    └── Resources/                  # icons, application data, translations
```

Use an `.icns` icon and ensure `Info.plist` contains coherent bundle identifier, display name, version, and minimum OS policy. Test file-open events, document types, high-DPI, permission prompts, and any sandbox/entitlement needs. Most externally distributed apps are not sandboxed; do not add entitlements casually.

### Apple account boundary

Free/open-source tools can create the `.app` and DMG. Direct distribution that avoids Gatekeeper warnings requires an Apple Developer Program membership, a **Developer ID Application** certificate, and notarization credentials. Apple’s documented notarization requirements include Developer ID signing, hardened runtime, a secure timestamp, and valid signatures for executable code ([Apple notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution?changes=_9)).

Conceptual CI-safe sequence:

```bash
# Import certificate into a temporary CI keychain first; keep all inputs secret.
codesign --force --options runtime --timestamp \
  --sign "$MACOS_SIGNING_IDENTITY" "dist/MyApp.app/Contents/Frameworks/Some.framework"
codesign --force --options runtime --timestamp \
  --sign "$MACOS_SIGNING_IDENTITY" "dist/MyApp.app"
codesign --verify --deep --strict --verbose=2 "dist/MyApp.app"

ditto -c -k --keepParent "dist/MyApp.app" "notarization.zip"
xcrun notarytool submit notarization.zip --keychain-profile notarytool-profile --wait
xcrun stapler staple "dist/MyApp.app"
spctl --assess --type execute --verbose=4 "dist/MyApp.app"

hdiutil create -volname MyApp -srcfolder "dist/MyApp.app" \
  -ov -format UDZO "dist/MyApp-1.2.3.dmg"
```

Use explicit inside-out signing for frameworks, dylibs, helper tools, plugins, and finally the app; use `codesign --deep` for verification convenience, not as a substitute for understanding nested code. Decide whether to notarize/staple the final DMG as well; test the exact released artifact on a clean Mac. Apple documents `notarytool` and `stapler` for command-line workflows ([Apple documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution?changes=_9)).

Build arm64 and x86_64 separately or create/test a universal build. Never claim universal compatibility merely because an Intel app works through Rosetta.

## 8. Qt Resources, Plugins, and Translations

### Resource policy

For every format your UI uses, make a test that proves it works from the final artifact: PNG/SVG/image formats, fonts, templates, databases, JSON, `.ui`, QML, and optional backends. Record each inclusion in the spec/Nuitka config or package staging instructions. Do not discover missing plugins only after release.

### Qt translations

For your application strings, compile your `.ts` files to `.qm` and ship them. For Qt’s standard dialogs (Open, Save As, Print), load Qt’s own `qt_<locale>.qm` from the Qt translations location in addition to your `myapp_<locale>.qm`:

```python
qt_translations = QLibraryInfo.path(QLibraryInfo.LibraryPath.TranslationsPath)
app_translations = resource_path("translations")

for prefix, directory in (("qt", qt_translations), ("myapp", app_translations)):
    translator = QTranslator(app)
    if translator.load(f"{prefix}_{locale_name}.qm", directory):
        app.installTranslator(translator)
        translators.append(translator)  # retain references
```

Pyzo uses this exact conceptual pattern, but its PyInstaller configuration does not explicitly list Qt `.qm` files; validate them in emitted artifacts. With PyInstaller or Nuitka, ensure the relevant Qt translation directory is collected. With AppImage, put it in the AppDir Qt translation location and set/patch paths as needed. With a distro-dependency `.deb`, the system Qt package normally supplies Qt translations while your package supplies only its own.

## 9. GitHub Actions Release Architecture

```text
                         tag vX.Y.Z
                              |
          +-------------------+-------------------+
          |                   |                   |
       Windows              Linux               macOS
          |                   |                   |
   build/test/sign      AppImage + .deb       build/test/sign
          |                   |                   |
  installer/sign        VM/container test      notarize/staple
          |                   |                   |
          +-------------------+-------------------+
                              |
                 SHA256 + SBOM + provenance
                              |
                       GitHub Release
```

An intentionally incomplete YAML shape (adapt and test it):

```yaml
name: release
on:
  push:
    tags: ['v*']

jobs:
  windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: '3.12'}
      - run: python -m pip install -r requirements-release.txt
      - run: python -m PyInstaller packaging/pyinstaller/myapp.spec --noconfirm --clean
      - run: pytest -q
      # Import signing credentials from secrets/provider, sign, run installer, sign it.
      - uses: actions/upload-artifact@v4
        with: {name: windows, path: dist/**}

  linux:
    runs-on: ubuntu-22.04  # choose based on documented glibc baseline
    steps:
      - uses: actions/checkout@v4
      # Build AppImage and .deb in pinned tooling/container; test artifacts.
      - uses: actions/upload-artifact@v4
        with: {name: linux, path: dist/**}

  macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      # Build .app, import Developer ID certificate into temporary keychain,
      # sign/verify, notarize/staple, make and test DMG.
      - uses: actions/upload-artifact@v4
        with: {name: macos, path: dist/**}
```

Add a release aggregation job that downloads artifacts, regenerates and verifies `SHA256SUMS.txt`, creates a GitHub Release, and uploads every artifact. Keep release permissions minimal. For public GitHub repositories, `actions/attest` can attach build provenance; GitHub documents the required `id-token: write`, `attestations: write`, and `actions/attest@v4` pattern ([GitHub Docs](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)). Generate an SBOM in SPDX or CycloneDX format from the same locked environment and make its relationship to each artifact clear.

Never print certificates, P12 data, passwords, signing tokens, Apple IDs, app-specific passwords, or code-signing service tokens. Store secret names and their purpose in internal release documentation, and restrict tag/release permissions.

## 10. Release Checklist

### Before tagging

- [ ] Version, changelog, package metadata, icons, bundle IDs, desktop metadata, and translations updated.
- [ ] Release dependencies locked/recorded; clean virtual-environment build succeeds.
- [ ] Unit tests plus frozen/compiled application smoke test pass.
- [ ] Feature tests cover dialogs, plugins, resources, translations, fonts/images, printing/networking used by the app.
- [ ] Windows/macOS signing credentials and timestamp/notary configuration validated without exposing secrets.

### Before publishing

- [ ] Windows app and installer signatures/timestamps verify; clean Windows VM installation tested.
- [ ] AppImage launches on the declared older baseline and representative current distributions.
- [ ] `.deb` passes `dpkg-deb --info/--contents`, installs/uninstalls cleanly, and passes relevant linting.
- [ ] macOS app signatures verify; notarization accepted; app/DMG tested on a clean Mac.
- [ ] SHA-256 manifest covers final downloaded asset bytes; SBOM/provenance attached or linked.
- [ ] VirusTotal is reviewed as a non-guaranteed signal; unexpected detections are investigated and genuine false positives reported responsibly.
- [ ] GitHub Release notes state platform/architecture, requirements, verification instructions, and known limitations.

## 11. Classification of Lessons

- **[HIGHLY RECOMMENDED]** Native CI builds, locked inputs, final-artifact smoke tests, platform-appropriate signing, hashes, SBOM/provenance, and clean-machine testing.
- **[HIGHLY RECOMMENDED]** macOS Developer-ID signing + hardened runtime + timestamp + notarization + stapling for direct downloads.
- **[USEFUL]** PyInstaller onedir or Nuitka standalone as the default distributable shape; portable archive plus installer where appropriate.
- **[USEFUL]** An AppImage plus a distro-dependency `.deb` as distinct Linux products with clear support boundaries.
- **[PROJECT-SPECIFIC]** Pyzo’s full-source copy, broad stdlib inclusion, mixed Qt bindings, portable settings behavior, and `.py` association.
- **[LEGACY]** Maintaining 32-bit Windows/PyQt5 merely because an older project does; make a current evidence-based support decision.
- **[NOT RECOMMENDED]** Treating onefile, UPX, unsigned releases, obfuscation, or one VirusTotal result as an AV solution; shipping a tarball under the label “AppImage”.
- **[REQUIRES FURTHER RESEARCH]** Your exact Qt plugin closure, Linux ABI/license policy, certificate provider, Windows installer type, and Nuitka-vs-PyInstaller benchmark results.

## 12. Final Recommended Architecture

For a new open-source PyQt6 desktop application today: keep source package metadata simple, pin a dedicated release environment, choose PyInstaller onedir or Nuitka standalone after measurement, and build natively per OS. Ship Windows as signed portable ZIP plus signed Inno installer; Linux as tested AppImage plus a distro-integrated `.deb`; macOS as Developer-ID-signed, notarized, stapled `.app` in a tested DMG/ZIP. Trigger releases from protected signed tags, test every final artifact, publish SHA-256/SBOM/provenance, and state remaining compatibility/AV uncertainty honestly.
