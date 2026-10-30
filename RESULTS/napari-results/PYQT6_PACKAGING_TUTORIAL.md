# PyQt6 Packaging Tutorial

## Practical Lessons from the napari Project

This tutorial distills lessons from studying the napari project's packaging
infrastructure into a practical guide for packaging your own PyQt6 applications.

**Important caveats:**
- napari does NOT use PyInstaller or Nuitka. It uses conda constructor, a
  fundamentally different approach. The techniques that translate are:
  resource handling, Qt binding abstraction, CI strategies, and signing.
- For PyInstaller/Nuitka-specific advice, I supplement from general knowledge
  and the napari team's documented evaluations (they tried PyInstaller-adjacent
  tools and rejected them for their use case).
- Recommendations from napari are marked with `[napari]`. General recommendations
  are marked with `[general]`.

---

## 1. Start with QtPy

napari uses `qtpy>=2.4.0` as a Qt binding abstraction layer. This is the single
most impactful practice you can adopt.

**Why:** Your users might prefer PyQt6 or PySide6. QtPy provides a unified API
that works with both. This also means you can test with both bindings.

**How:**
```python
# Instead of:
from PyQt6.QtWidgets import QApplication, QMainWindow

# Use:
from qtpy.QtWidgets import QApplication, QMainWindow
```

**In pyproject.toml:**
```toml
[project.optional-dependencies]
pyside6 = ["PySide6 > 6.7"]
pyqt6 = ["PyQt6 > 6.5"]
qt = ["napari[pyqt6]"]  # or your project's equivalent
```

**Evidence from napari:**
- `pyproject.toml:69` - `qtpy>=2.4.0`
- `pyproject.toml:96-113` - PySide6 and PyQt6 extras
- `pyproject.toml:568-569` - mypy configuration with `always_true=['PYQT6']`

---

## 2. Use `importlib.resources` for Resource Loading

napari mostly uses `Path(__file__).parent` for resource loading, but does use
`importlib.resources` for logos. The latter is the recommended approach for
packaging compatibility.

**Why:** `importlib.resources` works correctly with:
- Regular Python packages (pip install)
- Zipped packages (zip-safe mode)
- Frozen executables (PyInstaller, Nuitka)
- Conda environments

**How:**
```python
# Recommended: works with all packaging tools
from importlib import resources
from pathlib import Path

def get_icon_path(name: str) -> Path:
    return Path(resources.files('myapp').joinpath('resources', 'icons', f'{name}.svg'))

# Also works with most tools, but less robust:
from pathlib import Path
ICON_DIR = Path(__file__).parent / 'resources' / 'icons'
```

**Evidence from napari:**
- `src/napari/utils/logo.py:9` - `resources.files('napari').joinpath('resources', 'logos')`
- `src/napari/resources/_icons.py:15` - `Path(__file__).parent / 'icons'` (less recommended pattern)

---

## 3. Avoid the Qt Resource System for Frozen Executables

napari does NOT use `.qrc` files or `pyrcc`. All resources are filesystem-based.

**Why:** The Qt Resource System (`.qrc` → compiled into the binary) has issues
with PyInstaller and Nuitka. The compiled resources increase binary size and
cannot be easily updated. Filesystem resources are simpler and more compatible.

**Evidence from napari:**
- No `.qrc` files exist in the repository.
- `.gitignore:149` has `res.qrc` - suggesting it was considered but not adopted.
- Icons are loaded via `QIcon(str(path))` with SVG files.
- QSS stylesheets are loaded from `.qss` files and processed with `template()`.

---

## 4. Structure Your Resources for Easy Packaging

napari's `MANIFEST.in` and `pyproject.toml` declare which resource files to
include in the package:

```toml
# pyproject.toml
[tool.setuptools.package-data]
"*" = ["*.pyi"]
napari = ["resources/fonts/*.ttf"]
```

```ini
# MANIFEST.in
recursive-include src/napari *.png *.svg *.qss *.gif *.ico *.icns
recursive-include src/napari *.yaml
recursive-include src/napari/resources/fonts *.ttf *.txt
```

**Recommendation:** Declare ALL resource patterns explicitly. This ensures they
are included in the source distribution and wheel, which means PyInstaller/Nuitka
can find them during freezing.

---

## 5. Choose Your Packaging Tool

### PyInstaller (recommended for most projects)

**Type:** Freezer (bundles Python interpreter + code + dependencies)

**Advantages:**
- Most mature and widely used
- Excellent Qt support (PyQt6, PySide6)
- Large community, extensive documentation
- Onefile and onedir modes
- Good hooks system for common packages

**Disadvantages:**
- Antivirus false positives are a known issue (especially onefile mode)
- Startup time is slower (extraction in onefile mode)
- Bundle size can be large
- Sometimes requires manual hook creation for unusual dependencies

**Recommendation:** Use `--onedir` (not `--onefile`) to reduce AV false positives.
The onefile mode extracts to a temp directory, which many AV heuristics flag as
suspicious.

### Nuitka (alternative)

**Type:** Compiler (compiles Python to C++, then to native code)

**Advantages:**
- Generally fewer AV false positives (native binary, not extracted)
- Better startup performance
- Can produce smaller binaries with proper configuration
- Standalone mode bundles dependencies

**Disadvantages:**
- Longer build times (compilation can be slow)
- Less mature Qt support (though PyQt6 works)
- Smaller community, less documentation
- Requires a C compiler toolchain

**Recommendation:** Consider Nuitka if you have significant AV false positive
issues with PyInstaller. The longer build time is a one-time cost per release.

### conda constructor (napari's choice)

**Type:** Environment bundler (bundles entire conda environment)

**Advantages:**
- Handles complex C/C++ dependencies flawlessly
- Supports plugin ecosystems (mutable environments)
- conda-forge provides binary compatibility

**Disadvantages:**
- Very large bundle size (~600MB for napari)
- Requires conda-forge packaging expertise
- Overkill for simple applications
- No onefile option

**Recommendation:** Only use this if your application has complex native
dependencies that are difficult to handle with PyInstaller/Nuitka.

---

## 6. Windows: Build Process

**napari's approach:** conda constructor → NSIS installer (not applicable)

**General recommended approach for PyQt6:**

```text
PyQt6 application
    ↓
Virtual environment (venv/conda)
    ↓
pip install -r requirements.txt
    ↓
PyInstaller (onedir) or Nuitka (standalone)
    ↓
Standalone application directory
    ↓
Version metadata (VERSIONINFO, manifest)
    ↓
Code signing (Authenticode)
    ↓
Installer (NSIS/Inno Setup)
    ↓
Installer signing
    ↓
SHA256 checksum
    ↓
GitHub Release
```

### PyInstaller command example:
```bash
# Onedir (recommended)
pyinstaller --onedir --windowed --name "MyApp" --add-data "src/myapp/resources:resources" --icon "icon.ico" src/myapp/__main__.py

# Avoid onefile to reduce AV false positives
# pyinstaller --onefile --windowed ...  # NOT recommended
```

### Nuitka command example:
```bash
# Standalone mode
nuitka --standalone --enable-plugin=pyqt6 --windows-console-mode=disable --output-dir=build --output-filename=MyApp.exe src/myapp/__main__.py
```

### Inno Setup script example:
```iss
; MyApp.iss
[Setup]
AppName=MyApp
AppVersion=1.0.0
DefaultDirName={autopf}\MyApp
DefaultGroupName=MyApp
OutputDir=installer
OutputBaseFilename=MyApp-1.0.0-Windows-x86_64
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\MyApp.exe
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\MyApp\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MyApp"; Filename: "{app}\MyApp.exe"
Name: "{commondesktop}\MyApp"; Filename: "{app}\MyApp.exe"
```

---

## 7. Windows: Antivirus False Positives

**This is the most important Windows packaging issue.** napari does not use
PyInstaller, so it doesn't face this problem. However, the napari project's
approach offers some indirect lessons.

### What napari does (relevant to AV):
- **Code signing** on final releases (Azure Artifact Signing)
- **Transparent build process** on GitHub Actions
- **SHA256 checksums** published
- **No UPX** (confirmed: no UPX references anywhere)
- **Large installer size** (~600MB) - this may help avoid heuristic detection

### What napari does NOT do (and you shouldn't either):
- No obfuscation
- No binary packing
- No encryption of the executable
- No evasion techniques

### Recommendations for PyInstaller users:

**Supported by evidence:**
1. **Use onedir mode** - Multiple sources confirm onefile causes more AV detections
   because the extraction process resembles malware behavior.
2. **Code sign** - Authenticode signing is the single most effective legitimate
   technique. napari uses Azure Artifact Signing (Microsoft's modern signing service),
   which is available to open-source projects through various sponsorships.
3. **No UPX** - UPX-packed executables are frequently flagged by AV heuristics.
   napari does not use UPX.
4. **Build on a clean CI** - napari builds on GitHub Actions runners. This ensures
   no build artifacts from previous runs contaminate the build.
5. **Use current PyInstaller** - Older versions have more false positives.

**Not supported by napari (but generally recommended):**
6. **Submit false positives** to antivirus vendors (Microsoft Defender Portal,
   VirusTotal, etc.)
7. **Build reputation** through consistent signing, version metadata, and
   transparent releases.
8. **Consider Nuitka** if PyInstaller false positives are unacceptable.

**What cannot be guaranteed:**
- Zero VirusTotal detections is NOT achievable.
- Code signing does NOT guarantee no detections (but reduces them significantly).
- The specific impact of each technique varies by AV vendor and over time.

---

## 8. Linux: AppImage

napari does NOT use AppImage (it was removed in 2023). However, for a PyQt6
application, AppImage is an excellent distribution format.

### When to use AppImage:
- You want a single-file distribution
- You want to support multiple Linux distributions
- You don't want to create distribution-specific packages (.deb, .rpm)

### When to use DEB:
- Your users are primarily Ubuntu/Debian users
- You want system integration (apt, desktop menus)
- You want to distribute through package repositories

### Recommended AppImage approach:

```text
PyQt6 application
    ↓
PyInstaller or Nuitka
    ↓
AppDir structure
    ↓
AppImage
```

### AppDir structure:
```
MyApp.AppDir/
├── AppRun                  # Entry point script
├── myapp.desktop           # Desktop entry file
├── myapp.png               # Icon (256x256 or larger)
├── myapp.svg               # Vector icon (optional)
└── usr/
    ├── bin/
    │   └── myapp           # Symlink to the AppRun or the frozen binary
    └── lib/
        └── myapp/          # The frozen application directory
            ├── myapp       # Main executable
            ├── _internal/  # PyInstaller/Nuitka internal files
            └── ...         # Dependencies
```

### linuxdeploy + PyInstaller example:
```bash
# Build the frozen application
pyinstaller --onedir --windowed --name "MyApp" src/myapp/__main__.py

# Create AppDir structure
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps
cp -r dist/MyApp/* AppDir/usr/lib/myapp/
cp myapp.desktop AppDir/usr/share/applications/
cp myapp.png AppDir/usr/share/icons/hicolor/256x256/apps/

# Create AppRun
cat > AppDir/AppRun << 'EOF'
#!/bin/bash
APPDIR="$(dirname "$(readlink -f "$0")")"
exec "$APPDIR/usr/lib/myapp/MyApp" "$@"
EOF
chmod +x AppDir/AppRun

# Build AppImage
# Using linuxdeploy:
linuxdeploy --appdir AppDir --output appimage

# Or using appimagetool:
appimagetool AppDir MyApp-x86_64.AppImage
```

### .desktop file example:
```ini
[Desktop Entry]
Type=Application
Name=MyApp
Comment=My PyQt6 Application
Exec=MyApp
Icon=myapp
Categories=Graphics;Science;
Terminal=false
StartupNotify=true
```

### GLIBC compatibility:
- Build on the **oldest Linux distribution you want to support** (e.g., Ubuntu 20.04
  for GLIBC 2.31).
- The AppImage will run on newer distributions but NOT on older ones.
- napari builds on `ubuntu-24.04` for their `.sh` installer.
- For AppImages, consider building on Ubuntu 20.04 or using `manylinux` Docker images.

---

## 9. Linux: Debian Package

napari does NOT provide `.deb` packages. The following is general guidance.

### When to use:
- Your users are primarily Debian/Ubuntu users
- You want system integration
- You want to distribute through a PPA or Debian repository

### Approach A: Bundled application (recommended for PyQt6 apps)
The `.deb` contains the PyInstaller/Nuitka frozen application plus all dependencies.
No external package dependencies beyond the base system.

### Approach B: Dependency-based (napari's conda-forge approach)
The `.deb` depends on distribution packages (python3, python3-pyqt6, etc.).
This is harder to maintain due to version differences across distributions.

### DEB package structure:
```
myapp_1.0.0-1_amd64.deb
├── DEBIAN/
│   ├── control
│   ├── copyright
│   └── desktop
└── usr/
    ├── bin/
    │   └── myapp
    ├── lib/
    │   └── myapp/
    │       └── (frozen application files)
    └── share/
        ├── applications/
        │   └── myapp.desktop
        ├── icons/
        │   └── hicolor/
        │       └── 256x256/
        │           └── apps/
        │               └── myapp.png
        └── doc/
            └── myapp/
                ├── copyright
                └── changelog.gz
```

### control file (bundled approach):
```
Package: myapp
Version: 1.0.0-1
Section: graphics
Priority: optional
Architecture: amd64
Maintainer: Your Name <you@example.com>
Description: My PyQt6 Application
 A description of my amazing PyQt6 application.
```

### Build command:
```bash
# Create the package directory structure
mkdir -p myapp_1.0.0-1_amd64/DEBIAN
mkdir -p myapp_1.0.0-1_amd64/usr/bin
mkdir -p myapp_1.0.0-1_amd64/usr/lib/myapp
mkdir -p myapp_1.0.0-1_amd64/usr/share/applications
mkdir -p myapp_1.0.0-1_amd64/usr/share/icons/hicolor/256x256/apps
mkdir -p myapp_1.0.0-1_amd64/usr/share/doc/myapp

# Copy the frozen application
cp -r dist/MyApp/* myapp_1.0.0-1_amd64/usr/lib/myapp/

# Create launcher script
cat > myapp_1.0.0-1_amd64/usr/bin/myapp << 'EOF'
#!/bin/sh
exec /usr/lib/myapp/MyApp "$@"
EOF
chmod +x myapp_1.0.0-1_amd64/usr/bin/myapp

# Copy desktop files
cp myapp.desktop myapp_1.0.0-1_amd64/usr/share/applications/
cp myapp.png myapp_1.0.0-1_amd64/usr/share/icons/hicolor/256x256/apps/

# Copy doc files
cp copyright myapp_1.0.0-1_amd64/usr/share/doc/myapp/
gzip -n -9 -c changelog > myapp_1.0.0-1_amd64/usr/share/doc/myapp/changelog.gz

# Build the .deb
dpkg-deb --build --root-owner-group myapp_1.0.0-1_amd64

# Verify with lintian (optional, but recommended)
lintian myapp_1.0.0-1_amd64.deb
```

---

## 10. macOS: Application Bundle

napari creates a `.pkg` installer, not a `.dmg`. The `.app` bundle is created
by menuinst at installation time. For a PyQt6 project, you generally want to
create the `.app` yourself and optionally wrap it in a `.dmg`.

### .app bundle structure:
```
MyApp.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── MyApp           # The executable (or wrapper script)
│   ├── Resources/
│   │   ├── icon.icns       # Application icon
│   │   ├── myapp.icns      # Document icon (optional)
│   │   └── MainMenu.nib    # If using XIB (not applicable for PyQt)
│   └── Frameworks/
│       └── (bundled Qt/Python frameworks if not using PyInstaller)
```

### Info.plist:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>MyApp</string>
    <key>CFBundleExecutable</key>
    <string>MyApp</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.myapp</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MyApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024, Your Name</string>
</dict>
</plist>
```

### Creating the .app with PyInstaller:
```bash
# PyInstaller creates the .app structure automatically when using --windowed
pyinstaller --onedir --windowed --name "MyApp" --icon "icon.icns" --osx-bundle-identifier "com.example.myapp" src/myapp/__main__.py
```

### Creating a DMG (napari doesn't do this; general guidance):
```bash
# Create a temporary directory for the DMG contents
mkdir -p dmg_temp
cp -r "dist/MyApp.app" dmg_temp/
ln -s /Applications dmg_temp/Applications  # Drag-to-install shortcut

# Create the DMG
hdiutil create -volname "MyApp 1.0.0" -srcfolder dmg_temp -ov -format UDZO "MyApp-1.0.0-macOS-x86_64.dmg"
```

---

## 11. macOS: Code Signing and Notarization

napari implements the **complete signing and notarization pipeline** for macOS.
This is the model to follow.

### Requirements:
- **Apple Developer account** (paid, $99/year)
- **Developer ID Application certificate** (for signing the `.app`)
- **Developer ID Installer certificate** (for signing `.pkg`, if using PKG)
- **App Store Connect API key** (for notarization, avoids 2FA)

### Signing sequence:
```bash
# 1. Sign all bundled frameworks and libraries (recursive)
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name (TEAMID)" --options runtime "MyApp.app"

# 2. Sign the .app itself
codesign --force --verify --verbose --sign "Developer ID Application: Your Name (TEAMID)" --options runtime "MyApp.app"

# 3. Verify the signature
codesign -dv --verbose=4 "MyApp.app"
spctl --assess -vv --type execute "MyApp.app"
```

### Notarization:
```bash
# 1. Compress the .app for notarization
ditto -c -k --keepParent "MyApp.app" "MyApp.zip"

# 2. Submit to Apple (using App Store Connect API key)
xcrun notarytool submit "MyApp.zip" \
    --key "AuthKey.p8" \
    --key-id "KEY_ID" \
    --issuer "ISSUER_ID" \
    --wait --timeout 30m

# 3. Staple the ticket to the .app
xcrun stapler staple "MyApp.app"

# 4. Verify notarization
spctl --assess -vv --type execute "MyApp.app"
```

### For DMG:
```bash
# 1. Create the DMG (unsigned)
# 2. Sign the DMG
codesign --force --verify --verbose --sign "Developer ID Application: Your Name (TEAMID)" "MyApp.dmg"

# 3. Notarize the DMG (same procedure as for .app)
# 4. Staple
xcrun stapler staple "MyApp.dmg"
```

### napari's approach to secrets:
- Certificates are stored **base64-encoded** as GitHub secrets
- Imported into a **temporary keychain** at build time
- The keychain is unlocked with `security unlock-keychain`
- The `.p8` notarization key is also base64-encoded
- napari uses `notarytool` (not the deprecated `altool`)

---

## 12. GitHub Actions: Cross-Platform Workflow

napari uses a **matrix strategy** with `prepare_matrix` to dynamically determine
which platforms to build for. This is a solid pattern to follow.

### YAML structure:
```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  prepare_matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Prepare matrix
        id: set-matrix
        shell: python
        run: |
          import os, json
          elements = [
            {"os": "ubuntu-24.04", "target": "Linux", "python": "3.12"},
            {"os": "windows-2025", "target": "Windows", "python": "3.12"},
            {"os": "macos-15", "target": "macOS", "python": "3.12"},
          ]
          matrix = {"include": elements}
          with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write(f"matrix={json.dumps(matrix)}\n")

  build:
    needs: [prepare_matrix]
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.prepare_matrix.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Build with PyInstaller
        run: |
          pip install pyinstaller
          pyinstaller --onedir --windowed --name "MyApp" src/myapp/__main__.py
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: MyApp-${{ matrix.target }}
          path: dist/MyApp/

  release:
    needs: [build]
    permissions:
      contents: write
    runs-on: ubuntu-latest
    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v4
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            MyApp-Windows/*
            MyApp-Linux/*
            MyApp-macOS/*
```

### Named secrets typically needed:
- `WINDOWS_SIGNING_CERTIFICATE` (base64 PFX) or Azure signing credentials
- `WINDOWS_SIGNING_PASSWORD` (PFX password)
- `APPLE_APPLICATION_CERTIFICATE_BASE64`
- `APPLE_APPLICATION_CERTIFICATE_PASSWORD`
- `APPLE_INSTALLER_CERTIFICATE_BASE64` (if using PKG)
- `APPLE_NOTARIZATION_ISSUER_ID`
- `APPLE_NOTARIZATION_KEY_ID`
- `APPLE_NOTARIZATION_AUTHKEY_BASE64`
- `TEMP_KEYCHAIN_PASSWORD` (any secret works for macOS temporary keychain)

---

## 13. Qt Plugin Handling

napari does NOT bundle Qt plugins manually. The conda/PyPI packages handle this.

For PyInstaller/Nuitka, you need to explicitly include Qt plugins.

### PyInstaller:
```bash
# PyInstaller automatically detects Qt plugins when using PyQt6/PySide6
# You can also specify them manually:
pyinstaller --onedir --windowed \
    --add-data "path/to/site-packages/PyQt6/Qt6/plugins:Qt6/plugins" \
    --name "MyApp" src/myapp/__main__.py
```

### Qt plugins that should be included:
- `platforms/` - `qwindows.dll`, `qcocoa.dylib`, `qxcb.so` (platform-specific)
- `imageformats/` - `qjpeg.dll`, `qtiff.dll`, `qgif.dll`, `qsvg.dll`, etc.
- `styles/` - `qmodernstyle.dll` (optional)
- `iconengines/` - `qsvgicon.dll` (needed for SVG icon support)
- `tls/` - `qcertonlybackend.dll`, `qopensslbackend.dll` (if using HTTPS)
- `multimedia/` - if using audio/video

### Using PyInstaller hooks:
```python
# hook-myapp.py (PyInstaller hook)
from PyInstaller.utils.hooks import collect_all

# Automatically collect all PyQt6 data
datas, binaries, hiddenimports = collect_all('PyQt6')
```

---

## 14. Resource Handling in Frozen Executables

napari uses `Path(__file__).parent` for most resources. This works with
frozen executables because `__file__` points to the extraction directory.

### sys._MEIPASS (PyInstaller):
```python
import sys
from pathlib import Path

def resource_path() -> Path:
    """Return the path to the resources directory, works for dev and frozen."""
    if getattr(sys, 'frozen', False):
        # PyInstaller stores extracted files in sys._MEIPASS
        return Path(sys._MEIPASS) / 'resources'
    else:
        return Path(__file__).parent / 'resources'
```

### Nuitka equivalent:
```python
import sys
from pathlib import Path

def resource_path() -> Path:
    """Return the path to the resources directory, works for dev and frozen."""
    if getattr(sys, 'frozen', False):
        # Nuitka stores files relative to the executable
        return Path(sys.executable).parent / 'resources'
    else:
        return Path(__file__).parent / 'resources'
```

### Best practice (using importlib.resources):
```python
from importlib import resources
from pathlib import Path

def get_icon_path(name: str) -> Path:
    """Works with pip install, frozen executables, and conda."""
    return Path(resources.files('myapp').joinpath('resources', 'icons', f'{name}.svg'))
```

---

## 15. Translations

napari has NO i18n. For Qt translations in a PyQt6 application:

### Bundling Qt's own translations:
Qt provides `.qm` files for standard dialogs (Open, Save, Print, etc.).
These must be explicitly included in your frozen application.

### PyInstaller:
```bash
# Qt translations are typically in site-packages/PyQt6/Qt6/translations/
# or site-packages/PySide6/Qt/translations/
pyinstaller --onedir --windowed \
    --add-data "path/to/translations:translations" \
    --name "MyApp" src/myapp/__main__.py
```

### In your code:
```python
from qtpy.QtCore import QTranslator, QLibraryInfo
from qtpy.QtWidgets import QApplication

app = QApplication([])

# Load Qt's own translations
qt_translator = QTranslator()
qt_translations_path = QLibraryInfo.location(QLibraryInfo.LibraryPath.TranslationsPath)
if qt_translator.load(f'qtbase_{locale}', qt_translations_path):
    app.installTranslator(qt_translator)

# Load your application translations
app_translator = QTranslator()
if app_translator.load(f'myapp_{locale}', 'translations/'):
    app.installTranslator(app_translator)
```

---

## 16. Versioning and Metadata

napari uses `setuptools_scm` to derive the version from git tags.

### For PyInstaller:
```python
# myapp/__init__.py
from importlib import metadata

try:
    __version__ = metadata.version('myapp')
except metadata.PackageNotFoundError:
    # Frozen executable
    __version__ = '1.0.0'  # or read from a version file
```

### VERSIONINFO resource (Windows):
```bash
# PyInstaller can embed version info:
pyinstaller --onedir --windowed \
    --version-file version_info.txt \
    --name "MyApp" src/myapp/__main__.py
```

### version_info.txt:
```
VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=(1, 0, 0, 0),
    prodvers=(1, 0, 0, 0),
    mask=0x3f,
    flags=0x0,
    OS=0x40004,
    fileType=0x1,
    subtype=0x0,
    date=(0, 0)
  ),
  kids=[
    StringFileInfo(
      [
        StringTable(
          '040904B0',
          [StringStruct('CompanyName', 'Your Company'),
           StringStruct('FileDescription', 'MyApp'),
           StringStruct('FileVersion', '1.0.0.0'),
           StringStruct('InternalName', 'MyApp'),
           StringStruct('LegalCopyright', 'Copyright 2024'),
           StringStruct('OriginalFilename', 'MyApp.exe'),
           StringStruct('ProductName', 'MyApp'),
           StringStruct('ProductVersion', '1.0.0.0')])
      ]),
    VarFileInfo([VarStruct('Translation', [1033, 1200])])
  ])
```

---

## 17. Checksums and Release Integrity

napari generates SHA256 checksums for Windows installers and publishes
lockfiles for all installer artifacts.

### Recommended approach:
```bash
# Generate SHA256
sha256sum MyApp-1.0.0-Windows-x86_64.exe > MyApp-1.0.0-Windows-x86_64.exe.sha256

# Or on Windows
Get-FileHash MyApp-1.0.0-Windows-x86_64.exe -Algorithm SHA256 | \
    Format-List > MyApp-1.0.0-Windows-x86_64.exe.sha256
```

### GitHub Release:
Attach checksums and lockfiles alongside the installer artifacts.

---

## 18. End-to-End Workflow

```text
                         Git tag v1.0.0
                              │
                              ▼
                     GitHub Actions
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
         Windows            Linux            macOS
              │               │               │
     PyInstaller/Nuitka  PyInstaller/Nuitka  PyInstaller/Nuitka
              │               │               │
         Version info     AppDir/.deb        .app bundle
              │               │               │
         Code signing        │               Code signing
              │               │               │
         NSIS/Inno Setup  AppImage/DEB       Notarization
              │               │               │
         Installer sign      │               Staple (optional)
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                     GitHub Release
                              │
                     SHA256, lockfiles
```

---

## 19. Summary of Recommendations

| Practice | Source | Classification |
---|---|---|
| Use QtPy for binding abstraction | napari | [HIGHLY RECOMMENDED] |
| Use `importlib.resources` for resources | napari | [HIGHLY RECOMMENDED] |
| Use PyInstaller onedir (not onefile) | [general] | [HIGHLY RECOMMENDED] |
| Code sign Windows executables | napari | [HIGHLY RECOMMENDED] |
| Code sign and notarize macOS apps | napari | [HIGHLY RECOMMENDED] |
| No UPX | napari | [HIGHLY RECOMMENDED] |
| GitHub Actions matrix strategy | napari | [HIGHLY RECOMMENDED] |
| SHA256 checksums for releases | napari | [HIGHLY RECOMMENDED] |
| Submit false positives to AV vendors | [general] | [HIGHLY RECOMMENDED] |
| Use Nuitka if PyInstaller AV issues persist | [general] | [USEFUL] |
| Inno Setup for Windows installer | [general] | [USEFUL] |
| AppImage for Linux | [general] | [USEFUL] |
| DMG for macOS | [general] | [USEFUL] |
| PyPI publishing (trusted publishing) | napari | [USEFUL] |
| conda constructor for complex deps | napari | [PROJECT-SPECIFIC] |
| Azure Artifact Signing | napari | [USEFUL if available] |
| Lockfile generation for installers | napari | [USEFUL] |
| Avoiding Qt Resource System | napari | [USEFUL] |

---

## 20. What napari Cannot Teach Us

- **PyInstaller .spec file writing** - napari doesn't use PyInstaller
- **PyInstaller hooks** - napari doesn't use PyInstaller
- **Reducing PyInstaller AV false positives** - napari doesn't face this issue
- **AppImage creation** - napari removed AppImage support
- **DEB package creation** - napari doesn't provide .deb packages
- **DMG creation** - napari uses .pkg instead
- **Qt Resource System** - napari doesn't use .qrc files
- **Translations/i18n** - napari has no internationalization

For these topics, consult:
- PyInstaller documentation: https://pyinstaller.org/
- Nuitka documentation: https://nuitka.net/
- AppImage documentation: https://appimage.org/
- Debian packaging guide: https://www.debian.org/doc/debian-policy/
- Apple Developer documentation: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution