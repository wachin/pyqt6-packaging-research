# Packaging Study: napari

## 1. Executive Summary

napari is a multi-dimensional image viewer for Python, built on Qt (via qtpy),
vispy (GPU rendering), and the scientific Python stack. It is published as a
regular Python package on PyPI and conda-forge, and additionally distributed as
**platform-specific installers** built with **conda constructor**.

The project's packaging is notable for its **conda-centric approach**:
instead of PyInstaller/Nuitka/freeze-based bundling, napari ships a full
conda environment (including Python, Qt, and all dependencies) inside an
installer. This is a fundamentally different approach from the typical
PyInstaller workflow.

**Key facts:**
- **No PyInstaller, Nuitka, cx_Freeze, or py2app in use.**
- **No AppImage, no DEB, no DMG.**
- **Windows:** NSIS-based `.exe` installer (conda constructor)
- **Linux:** Shell-based `.sh` installer (conda constructor)
- **macOS:** `.pkg` installer (conda constructor), signed and notarized
- **PyPI wheel + conda-forge** for advanced users
- **Docker images** on ghcr.io as a secondary channel
- Legacy Briefcase (AppImage/DMG/MSI) was removed in 2023

## 2. Project Architecture

| Attribute | Value |
|---|---|
| **Project name** | napari |
| **Repository** | https://github.com/napari/napari |
| **Language** | Python (>=3.11) |
| **Qt binding** | QtPy abstraction (supports PyQt5, PyQt6, PySide6) |
| **Qt version** | Qt6 >6.5 (PyQt6), Qt6 >6.7 (PySide6). Pins _against_ 6.11.0/6.11.1. |
| **Entry point** | `napari = napari._main:main` (pyproject.toml:335) |
| **Build system** | setuptools + setuptools_scm (version from git tags) |
| **Package structure** | src layout (`src/napari/`, `src/napari_builtins/`) |
| **Dependency management** | pyproject.toml, uv for dev, tox for testing |
| **Testing** | pytest + tox across Qt backends, pytest-qt |
| **CI/CD** | GitHub Actions |
| **Release packaging** | napari/packaging (separate repository) |

**Qt binding detection** (`src/napari/_qt/__init__.py:4`): Uses `from qtpy import API_NAME`.
Environment variable `QT_API` can override. The bundled installer hardcodes `QT_API=pyside6`
(see `build_installers.py:239` - `_get_conda_meta_state()`).

## 3. Packaging Overview

napari is distributed through **four channels**:

```
Source code (napari/napari)
    |
    +-- PyPI                                          (pip install napari)
    |     +-- wheel + sdist
    |     +-- via make_release.yml (trusted publishing)
    |
    +-- conda-forge                                   (conda install napari)
    |     +-- napari-base, napari, napari-menu packages
    |     +-- automated via conda-forge bot from PyPI
    |
    +-- napari channel (anaconda.org/napari)          (nightly/RC packages)
    |     +-- Built by CI, used by constructor installers
    |
    +-- Constructor installers (napari/packaging)     (end-user downloads)
    |     +-- Windows: .exe (NSIS)
    |     +-- Linux: .sh (shell installer)
    |     +-- macOS: .pkg (signed + notarized)
    |     +-- Attached to GitHub Releases
    |
    +-- Docker images (ghcr.io)                       (docker pull)
          +-- napari/napari, napari/napari-xpra
```

The **constructor installers** are the focus of this study. They are built by
the `napari/packaging` repository, which contains:
- `build_installers.py` (621 lines) - generates `construct.yaml` and runs `constructor`
- `conda-recipe/recipe.yaml` (235 lines) - conda recipe split into 3 outputs
- `.github/workflows/make_bundle_conda.yml` (727 lines) - the full CI pipeline
- `environments/` - CI environment files

## 4. Windows

**Packaging method:** conda constructor → NSIS-based `.exe` installer.

**Evidence:**
- `napari/packaging/build_installers.py:364-389` - Windows config section
- `napari/packaging/.github/workflows/make_bundle_conda.yml:274-278` - win-64 matrix entry
- `napari/packaging/.github/workflows/make_bundle_conda.yml:457-478` - Windows signing

**Process:**
1. conda packages are built (or downloaded from conda-forge/napari channel)
2. `build_installers.py` generates `construct.yaml` with Windows-specific keys:
   - `installer_type: exe` (NSIS)
   - `default_prefix: %LOCALAPPDATA%/napari-{version}`
   - `default_prefix_all_users: %ALLUSERSPROFILE%/napari-{version}`
   - `welcome_image`, `header_image`, `icon_image` (generated from logo)
   - `register_python: False`
   - `check_path_length: False`
3. `constructor` builds the NSIS `.exe` installer
4. On final releases: Azure Artifact Signing (Windows Authenticode)
5. On non-final: "signs" with Apple certificate (not trusted by Windows, for metadata only)
6. SHA256 hash generated
7. Attached to GitHub Release

**Released artifact example:** `napari-0.9.0-Windows-x86_64.exe` (~605 MB).

**The installer bundles:**
- A full conda installation (conda-standalone, a PyInstaller-frozen conda)
- A `base` environment with conda tools
- A `napari-{version}` environment with napari, PySide6, Python, and all deps
- `menuinst` for start menu shortcuts
- `_conda.exe` - the conda-standalone binary for post-install management

## 5. PyInstaller

**napari does NOT use PyInstaller for its own packaging.**

The `.gitignore` contains generic PyInstaller template lines (lines 37-41):
```
# PyInstaller
#  Usually these files are written by a python script from a template
#  before PyInstaller builds the exe, so as to inject date/other infos into it.
*.manifest
*.spec
```
This is likely a legacy artifact from the Briefcase era or a generic template.
No `.spec` files exist anywhere in the repository.

**However**, PyInstaller IS used indirectly by `conda-standalone`, which is a
dependency of the constructor toolchain. `conda-standalone` is a PyInstaller-frozen
version of conda that is bundled inside every constructor installer. This is
a dependency of the packaging toolchain, not of napari itself.

**NAP-2 (Section: Related Work)** explicitly states:
> Freezing napari directly with PyOxidizer and Nuitka. These experiments were
> not successful either and didn't allow for a good plugin installation story
> (the frozen executables are immutable).

This confirms that frozen-executable approaches (PyInstaller, Nuitka, PyOxidizer)
were evaluated and **rejected** for napari, primarily because of the plugin
ecosystem (which requires modifiable Python environments).

## 6. Nuitka

Not used. NAP-2 mentions Nuitka was evaluated and rejected for the same reasons
as PyInstaller: frozen executables would prevent the plugin ecosystem from
functioning (plugins are installed as Python packages at runtime).

## 7. Antivirus / VirusTotal Considerations

**Findings:**
- napari's Windows installer is ~605 MB, which is large enough to potentially
  avoid some heuristic-based detections (large files are less likely to be
  scanned heuristically).
- **No UPX** is used anywhere (confirmed: no UPX references in the entire repo).
- The installer is code-signed with Microsoft Authenticode (Azure Artifact Signing)
  on **final releases only**.
- The project explicitly states in docs: "users will still get the SmartScreen warning"
  when signing with Apple certificates on non-release builds.
- No obfuscation, no binary packing, no avoidance techniques.
- The installer is built from **entirely open-source** components on GitHub Actions.
- Source code is transparent, the build pipeline is public.
- SHA256 checksums are generated and published for every release.
- GitHub artifact attestations are used for the Python wheel.

**Evaluation:**
- The project does NOT use any techniques specifically designed to reduce
  antivirus false positives.
- Code signing is the primary legitimate technique used, but it's only applied
  on final tagged releases (not on nightlies/PRs).
- The project's approach (conda-based, not frozen) naturally avoids many of
  the PyInstaller-specific false-positive issues.
- **No evidence** that napari has ever tracked VirusTotal scores or optimized
  for them.

**Verdict:** This project provides no directly applicable lessons for reducing
PyInstaller-based AV false positives, because it does not use PyInstaller.

## 8. Windows Installer

**Technology:** NSIS (Nullsoft Scriptable Install System), via conda constructor.

**Evidence:**
- `napari/packaging/build_installers.py:364` - `installer_type: 'exe'`
- The actual NSIS template is part of conda constructor's source code, not
  in this repository.
- The installer is a standard constructor NSIS installer with napari branding.

**Features:**
- Per-user installation (default: `%LOCALAPPDATA%/napari-{version}`)
- Per-machine installation (default: `%ALLUSERSPROFILE%/napari-{version}`)
- Start menu and desktop shortcuts (via menuinst)
- Silent installation mode (`/S` flag) - used in CI testing
- Custom installation directory (`/D=` flag)
- Uninstaller support
- Python registration: disabled (`register_python: False`)

## 9. Windows Code Signing

**Two-tier approach:**

**A. Final releases (tag push):**
- Uses **Azure Artifact Signing** (Azure Code Signing, Microsoft Trusted Signing)
- `azure/artifact-signing-action` signs `.exe` files
- Signature: SHA256 digest, RFC3161 timestamp (http://timestamp.acs.microsoft.com)
- Verified with `Get-AuthenticodeSignature`
- SHA256 checksums generated
- Requires secrets: `WINDOWS_SIGNING_ENDPOINT`, `WINDOWS_SIGNING_ACCOUNT_NAME`,
  `WINDOWS_SIGNING_PROFILE_NAME`, `WINDOWS_SIGNING_AZURE_*` (Azure credentials)
- The Azure cert is shared with other NumFOCUS projects (quota-managed)

**B. Non-release builds (nightlies, PRs, schedule):**
- Signs with the **Apple Developer ID Application certificate** (PFX export)
- This is explicitly documented as "not recognized by Windows as a valid one"
- Purpose: "curious users will be able to check it's actually us if necessary"
- The signature metadata can be viewed but does NOT satisfy SmartScreen

**Sequence:**
```text
Source code → conda packages → constructor → .exe installer
                                                      ↓
                                     Azure Artifact Signing (final releases only)
                                                      ↓
                                                   SHA256
                                                      ↓
                                              GitHub Release
```

## 10. Linux

**Packaging method:** conda constructor → shell-based `.sh` installer.

**Process:**
- `napari/packaging/build_installers.py:325-332` - Linux config
- `installer_type: 'sh'` (shell script)
- `default_prefix: $HOME/.local/napari-{version}`
- License file: `bundle_license.txt` (plain text, no RTF on Linux)
- No graphical installer, runs in terminal

**Released artifact example:** `napari-0.9.0-Linux-x86_64.sh` (~637 MB).

**Testing in CI:**
- `make_bundle_conda.yml:674-690` - Linux testing:
  - Installs with `bash installer.sh -bfp ~/temp/napari-{version}`
  - Activates conda environment
  - Runs `conda info`, `conda list`, `napari --info`
  - Verifies `.desktop` shortcut created in `~/.local/share/applications/`

**Qt dependencies:** Installed in the bundled conda environment (PySide6 package
on conda-forge bundles Qt6 libraries). The CI runner installs additional X11
display libraries (`libdbus-1-3`, `libxkbcommon-x11-0`, `libxcb-*`, etc.) for
testing, but these are not bundled in the installer.

## 11. AppImage

**NOT used.** AppImage was used in the legacy Briefcase era (removed in 2023 via
commit `d4ba4a08`). The current approach uses the conda constructor `.sh` installer
instead.

**NAP-2 states:** "constructor does not support the AppImage format for Linux"
and "We don't see this as a problem though, given the small number of downloads
each format enjoyed in previous releases."

## 12. Debian Package

**NOT provided.** napari does not create `.deb` packages.

Linux distribution is via:
1. PyPI (`pip install napari`)
2. conda-forge (`conda install napari`)
3. Constructor `.sh` installer for end users

## 13. macOS

**Packaging method:** conda constructor → `.pkg` installer.

**Evidence:**
- `napari/packaging/build_installers.py:334-362` - macOS config section
- `napari/packaging/.github/workflows/make_bundle_conda.yml:266-272` - osx-64/osx-arm64 matrix entries
- `napari/packaging/.github/workflows/make_bundle_conda.yml:534-585` - notarization step
- `napari/resources/osx_pkg_welcome.rtf.tmpl` - welcome screen template

**Process:**
1. conda packages built for target platform (osx-64 or osx-arm64)
2. `build_installers.py` generates `construct.yaml` with macOS-specific keys:
   - `installer_type: pkg`
   - `pkg_name: napari-{version}`
   - `default_location_pkg: Library` → `~/Library/napari-{version}`
   - `welcome_image` (1227x600 generated from logo)
   - `welcome_file` (RTF, version-substituted from template)
   - `conclusion_text: ''` (empty = revert to system defaults)
   - `readme_text: ''` (same)
   - `signing_identity_name` (from Apple Installer Certificate)
   - `notarization_identity_name` (from Apple Application Certificate)
   - `progress_notifications: True`
3. `constructor` builds the `.pkg` file
4. Signing/notarization/stapling is done after build

**The `.app` bundle:** The macOS `.app` is created by **menuinst** at
**installation time** (not build time). The `conda_menu_config.json`
(`resources/conda_menu_config.json`) contains the macOS .app configuration:
- `CFBundleName`, `CFBundleDisplayName`, `CFBundleVersion`
- Entitlements (file access: user-selected, downloads, pictures, music, movies)
- Document type associations (hundreds of image formats)
- UTExportedTypeDeclarations
- `link_in_bundle: {python: Contents/Resources/python}` - Python is symlinked
  into the .app bundle
- `event_handler: python -m napari` - handles file open events

## 14. macOS Code Signing

**Two certificates are used:**
1. **Apple Developer ID Installer** certificate - signs the `.pkg` via `productsign`
   (handled by constructor with `signing_identity_name`)
2. **Apple Developer ID Application** certificate - signs the `_conda` binary
   (the conda-standalone executable inside the .pkg) via `codesign`
   (handled by constructor with `notarization_identity_name`)

**Certificate loading in CI:**
- `make_bundle_conda.yml:416-455` - "Load signing certificate (MacOS)"
- Both certificates are stored as base64-encoded secrets
- Imported into a temporary keychain
- Keychain is unlocked with `security unlock-keychain`
- Identity names are discovered via `security find-identity`
- Also: the conda environment's `codesign` is moved aside to avoid conflicts with
  Apple's system `codesign`

**Secrets required:**
- `APPLE_APPLICATION_CERTIFICATE_BASE64`
- `APPLE_INSTALLER_CERTIFICATE_BASE64`
- `APPLE_APPLICATION_CERTIFICATE_PASSWORD`
- `APPLE_INSTALLER_CERTIFICATE_PASSWORD`
- `TEMP_KEYCHAIN_PASSWORD` (any secret works)

## 15. macOS Notarization

**Full notarization pipeline** is implemented:

```text
.pkg creation
    ↓
sign `_conda` binary (Apple Developer ID Application cert)
    ↓
sign .pkg with productsign (Apple Developer ID Installer cert)
    ↓
notarytool submit (upload to Apple)
    ↓
wait for Apple approval (--wait, 30min timeout)
    ↓
stapler staple (attach ticket to .pkg)
    ↓
spctl --assess -vv --type install (verify)
    ↓
GitHub Release
```

**Evidence:** `make_bundle_conda.yml:534-585`

**Code:**
```bash
# Submit for notarization
xcrun notarytool submit "$INSTALLER_PATH" \
    --key "$APPLE_NOTARIZATION_AUTHKEY_PATH" \
    --key-id "$APPLE_NOTARIZATION_KEY_ID" \
    --issuer "$APPLE_NOTARIZATION_ISSUER_ID" \
    --output-format json --wait --timeout 30m

# Staple
xcrun stapler staple --verbose "$INSTALLER_PATH"

# Verify
spctl --assess -vv --type install "$INSTALLER_PATH"
```

**Authentication:** App Store Connect API key (`.p8` file), not Apple ID password.
Secrets required:
- `APPLE_NOTARIZATION_ISSUER_ID` (Issuer ID from App Store Connect)
- `APPLE_NOTARIZATION_KEY_ID` (Key ID)
- `APPLE_NOTARIZATION_AUTHKEY_BASE64` (base64-encoded .p8 file)

**Hardened Runtime:** The `_conda` binary is signed with the Application
certificate (which includes Hardened Runtime by default for Developer ID
certificates). No explicit entitlements file is passed.

## 16. GitHub Actions

**Workflows in napari/napari:**
- `make_release.yml` - Tag-pushed release: build wheel, PyPI publish, GitHub Release
- `make_bundle_conda.yml` (19 lines) - Delegates to `napari/packaging` reusable workflow
- `test_pull_requests.yml` - PR matrix testing (all platforms, Qt backends)
- `test_comprehensive.yml` - Post-merge comprehensive testing
- `test_prereleases.yml` - Pre-release dependency testing (including PyQt6 from Riverbank's index)
- `docker-publish.yml` - Docker images to ghcr.io
- `reusable_build_wheel.yml` - Wheel building (called by release and test workflows)
- `reusable_pip_test.yml` - pip install testing
- `reusable_run_tox_test.yml` - tox-based test runner
- `upgrade_test_constraints.yml` - Update pinned dependency files
- `test_vendored.yml` - Vendored module update checker

**Workflows in napari/packaging:**
- `make_bundle_conda.yml` (727 lines) - The actual installer-building pipeline

**Release pipeline (simplified):**
```text
git tag v1.2.3
    ↓
GitHub Actions (napari/napari)
    +-- make_release.yml
    |     +-- Build & inspect Python package
    |     +-- Extract release notes from napari/docs
    |     +-- Create GitHub Release
    |     +-- Publish to PyPI (trusted publishing)
    |
    +-- make_bundle_conda.yml (19 lines)
          +-- calls napari/packaging/.github/workflows/make_bundle_conda.yml@main
                +-- [packages job] Build conda packages on ubuntu
                |     +-- Checkout napari, packaging, feedstock
                |     +-- Micromamba setup
                |     +-- Build sdist, patch feedstock, conda-build
                |     +-- Upload packages to anaconda.org/napari
                |     +-- Upload packages as artifacts for next job
                |
                +-- [prepare_matrix job] Determine which platforms to build
                |
                +-- [installers job] Matrix: linux-64, win-64, osx-64, osx-arm64
                      +-- Checkout repos
                      +-- Download packages from previous job
                      +-- Build installer with `build_installers.py`
                      +-- macOS: sign, notarize, staple
                      +-- Windows: sign with Azure Code Signing (final releases)
                      +-- Generate SHA256 (Windows)
                      +-- Upload to GitHub Release
                      +-- Test installation on each OS
```

**Runners used:**
- `ubuntu-24.04` for Linux installers
- `macos-15-intel` for osx-64
- `macos-15` (Apple Silicon) for osx-arm64
- `windows-2025` for win-64

**Python version:** 3.13 (INSTALLER_PYTHON_VERSION, follows SPEC-0 recommendations)

## 17. Resource Handling

napari does NOT use the Qt Resource System (no `.qrc` files, no `pyrcc`).
Instead, resources are loaded from the filesystem.

**Three mechanisms used:**

1. **`Path(__file__).parent`** (most common):
   - `src/napari/resources/_icons.py:15-16` - Icons, loading GIF
   - `src/napari/_qt/qt_resources/__init__.py:9-10` - QSS stylesheets
   - All resolved at import time relative to the Python file

2. **`importlib.resources.files('napari')`** (modern approach):
   - `src/napari/utils/logo.py:9,53` - Logo SVGs
   - Only usage of `importlib.resources` in the codebase

3. **`QDir.addSearchPath`** (Qt search path):
   - `src/napari/_qt/qt_event_loop.py:271` - Theme SVGs registered as Qt search paths
   - QSS files reference icons via `url("theme_{{ id }}:/icon_name.svg")`

**Important:** There is NO `sys._MEIPASS` or `sys.frozen` handling for resources.
The only `sys.frozen` reference is:
- `src/napari/_qt/qt_event_loop.py:54` - Skips Windows app ID setting when frozen

**For PyInstaller/Nuitka users:** This is relevant because the `Path(__file__).parent`
approach works correctly with frozen executables (PyInstaller extracts files to
a temporary directory and `__file__` points there). However, `importlib.resources`
is the recommended approach for packager compatibility.

## 18. PyQt6 / Qt Plugins

napari does NOT bundle Qt plugins itself. Instead:

- **PyPI installs:** Qt plugins are shipped as part of the PyQt6/PySide6 wheel
  packages (e.g., `PyQt6-Qt6` provides Qt6 shared libraries + plugins).
- **conda installs:** Qt plugins are in the conda environment's `plugins/` directory,
  provided by the `qt6` or `pyside6` conda package.
- **Constructor installers:** The entire conda environment is bundled, so Qt
  plugins are included automatically through the conda package dependencies.

**Qt plugin types included automatically:**
- Platform plugins (windows, xcb, cocoa, minimal, offscreen)
- Image format plugins (png, jpeg, tiff, gif, webp, etc.)
- Styles (qt6gtk2, etc.)
- Icon engines (svg)
- TLS/network (via Qt Network module)
- Translations (Qt's own .qm files)

**No special handling is needed** because the entire dependency tree is resolved
by conda. The constructor installer includes the full conda environment.

## 19. Translations

**napari itself has NO internationalization.** No `QTranslator`, no `.ts`/`.qm` files.

**Qt's own dialog translations:** When using conda-based installers, Qt's own
translations (for Open, Save As, Print, etc.) are provided by the Qt conda
package (e.g., `qt6` or `pyside6` conda package includes `translations/` directory
with `.qm` files). These are automatically available because Qt loads them from
its library path at runtime.

For PyPI installs, Qt translations are included in the PyQt6/PySide6 wheels.

## 20. Security and Release Integrity

**Practices implemented:**

- **GitHub Artifact Attestations:** `make_release.yml:28` - `attest-build-provenance-github`
  for the Python wheel on tag pushes (SLSA-like provenance).
- **Release checksums:** SHA256 files generated for Windows `.exe` installers.
- **Lockfile artifacts:** Each installer has a corresponding `.lockfile.txt` published
  that records the exact conda package versions included.
- **zizmor security analysis:** `zizmor.yml` - GitHub Actions security scanner.
- **Dependabot:** `.github/dependabot.yml` - automated dependency updates.
- **Pinned test dependencies:** `resources/constraints/*.txt` - pinned dependency
  versions for reproducible CI testing.
- **Code signing:** Windows Authenticode (Azure) and macOS signing/notarization.
- **Trusted Publishing:** PyPI uses OpenID Connect (no manual API tokens).

**Not implemented:**
- SBOM (Software Bill of Materials) - not generated
- SLSA provenance beyond GitHub attestations
- Reproducible builds (not attempted)
- Git tag signing (-s option is recommended but not enforced)
- Release signing (GPG/OpenPGP)

## 21. Techniques Worth Reusing

| Technique | Classification | Notes |
|---|---|---|
| QtPy abstraction | [HIGHLY RECOMMENDED] | Supports multiple Qt bindings, simplifies packaging |
| `importlib.resources` for resource loading | [HIGHLY RECOMMENDED] | Compatible with all packaging tools |
| Constraint files for reproducible builds | [HIGHLY RECOMMENDED] | `resources/constraints/*.txt` via `uv pip compile` |
| Separate packaging repo | [USEFUL] | Keeps CI clean, reusable across projects |
| Code signing on final releases only | [USEFUL] | Balances cost (signing quotas) with security |
| macOS notarization with notarytool | [USEFUL] | Required for macOS Gatekeeper |
| GitHub artifact attestations | [USEFUL] | Improves supply chain security |
| Lockfile generation for installers | [USEFUL] | Reproducibility and debugging |
| Multi-environment conda setup | [PROJECT-SPECIFIC] | Plugin ecosystem requirement |
| constructor-based installers | [PROJECT-SPECIFIC] | Heavy (~600MB), not suitable for all apps |
| Azure Artifact Signing | [USEFUL] | Modern alternative to EV certs, but has quotas |
| matrix strategy for cross-platform | [HIGHLY RECOMMENDED] | `prepare_matrix` pattern in workflows |
| Trusted Publishing for PyPI | [HIGHLY RECOMMENDED] | No API tokens to manage |

## 22. Techniques Specific to This Project

| Technique | Why it's specific |
|---|---|
| conda constructor bundling | Only makes sense for applications with complex C/C++ dependencies and a plugin ecosystem that needs mutable environments |
| Multiple conda environments (base + napari-version) | Specifically designed for the napari plugin ecosystem |
| conda-based plugin manager | Not needed for simpler applications |
| Versioned installation paths | `~/Library/napari-{version}` - designed for side-by-side versions |
| Briefcase legacy (removed) | Historical, no longer relevant |
| conda-feedstock patching | Requires deep conda-forge knowledge |
| menuinst .app creation | macOS .app is created at install time, not build time |
| `_conda.exe` for management | The bundled conda-standalone for post-install operations |

## 23. Problems or Weaknesses Found

1. **Large installer size** (~600MB) due to bundling a full conda environment
   including Python, Qt, and all dependencies.
2. **No AppImage or DEB** for Linux users who prefer those formats.
3. **No DMG** for macOS (only PKG).
4. **Windows signing only on final releases** - nightlies and PRs raise
   SmartScreen warnings.
5. **No Windows signing on pre-release builds** (RCs, nightlies get Apple cert
   which is not trusted on Windows).
6. **No antivirus false-positive mitigation strategy** - the project doesn't
   track or optimize for VirusTotal scores.
7. **Fonts directory declared but empty** - `pyproject.toml` and `MANIFEST.in`
   reference `resources/fonts/*.ttf` but the directory doesn't exist.
8. **No `importlib.resources` usage for all resources** - `Path(__file__).parent`
   is used for most resources, which is less robust than `importlib.resources`
   for packaging.
9. **No i18n/translations** for the application itself.
10. **No SBOM or comprehensive supply chain security** beyond GitHub attestations.
11. **No `.deb`/`.rpm`** for Linux distribution through package managers.

## 24. Recommended Approach for My PyQt6 Projects

**This project's approach is NOT recommended for typical PyQt6 applications.**

The conda constructor approach is designed for a specific use case:
- Applications with complex C/C++ dependencies (scientific computing)
- Applications that need a plugin ecosystem (mutable Python environment)
- Large teams with conda-forge packaging expertise
- Applications that benefit from conda's dependency solving

**For a typical PyQt6 desktop application, I recommend:**
1. **PyInstaller** (onedir mode) for standalone executables
2. **Nuitka** (standalone mode) as an alternative for better AV reputation
3. **NSIS/Inno Setup** for Windows installers
4. **AppImage** for Linux
5. **DMG** for macOS
6. **Code signing** on all platforms for releases
7. **GitHub Actions** for CI/CD

**However, these techniques from napari are valuable:**
- QtPy for binding abstraction
- `importlib.resources` for resource loading
- Constraint files for reproducible builds
- GitHub artifact attestations
- Trusted Publishing for PyPI

## 25. Important Files to Study

| File | Purpose |
|---|---|
| `napari/packaging/build_installers.py` | Main installer builder (621 lines) |
| `napari/packaging/.github/workflows/make_bundle_conda.yml` | Full CI pipeline (727 lines) |
| `napari/packaging/conda-recipe/recipe.yaml` | Conda recipe (235 lines) |
| `napari/napari/.github/workflows/make_release.yml` | PyPI/GitHub release (139 lines) |
| `napari/napari/pyproject.toml` | Project metadata, dependencies (996 lines) |
| `napari/napari/resources/conda_menu_config.json` | Desktop integration config (long) |
| `napari/napari/resources/osx_pkg_welcome.rtf.tmpl` | macOS installer welcome screen |
| `napari/napari/resources/bundle_readme.md` | README bundled with installer |
| `napari/napari/resources/bundle_license.txt` | License bundled with installer |
| `napari/napari/src/napari/_qt/qt_event_loop.py` | Qt app setup, resource search paths |
| `napari/napari/src/napari/resources/_icons.py` | Resource loading mechanism |
| `napari/napari/src/napari/utils/logo.py` | `importlib.resources` usage example |
| `napari/napari/src/napari/_qt/__init__.py` | Qt binding detection |
| `napari/napari/.github/workflows/test_prereleases.yml` | PyQt6 pre-release testing |
| `napari/napari/MANIFEST.in` | Package file inclusion |

## 26. Commands Used by the Project

**Build commands (from Makefile):**
```makefile
dist: typestubs check-manifest
    pip install -U build
    python -m build
```

**Test commands (from tox.ini):**
```ini
envlist = py{311-315}-{pyqt5,pyqt6,pyside6,headless,...}
```

**Installer build (from README of napari/packaging):**
```bash
git clone https://github.com/napari/napari.git napari
git checkout <latest-tag>
cd ..
git clone https://github.com/napari/packaging.git napari-packaging
cd napari-packaging
conda env create -n napari-packaging-installers --file environments/ci_installers_environment.yml
conda activate napari-packaging-installers
pip install -e ../napari --no-deps
CONSTRUCTOR_PYTHON_VERSION="3.13" python build_installers.py --location ../napari
```

**Release tag command:**
```bash
git tag -s "vX.Y.Z" -F ../napari-docs/release/release_X_Y_Z.md
git push upstream --tags
```

## 27. Final Conclusions

**napari is NOT a representative example of how most PyQt6 applications are packaged.**

The project adopted a **conda-based packaging strategy** that is fundamentally
different from the PyInstaller/Nuitka approach used by most Python desktop
applications. This choice was driven by the project's scientific computing
ecosystem (complex C/C++ dependencies, plugin system, conda-forge community).

**Key lessons for a new PyQt6 project:**
1. **Use QtPy** - This is the single best practice from napari that applies to
   any PyQt6 project. It allows users to choose between PyQt6 and PySide6.
2. **Use `importlib.resources`** - More robust than relative paths for frozen
   executables, and works with all packaging tools.
3. **Code signing is essential** - napari's approach to signing (Azure for
   Windows, Apple Developer ID for macOS) is the standard approach.
4. **conda constructor is NOT a replacement for PyInstaller** - It's heavier,
   more complex, and only appropriate for applications with conda-ecosystem
   dependencies.
5. **The plugin ecosystem drives the packaging strategy** - napari's approach
   is designed around plugins, not around standalone distribution.
6. **Antivirus false positives are not addressed** - napari doesn't use
   PyInstaller, so it doesn't face the same AV issues. No lessons transfer.

**Unanswered questions:**
1. How would napari's resource loading work with PyInstaller freezing?
   (The `Path(__file__).parent` approach should work, but `importlib.resources`
   is preferred.)
2. How would Qt translations be handled if napari were frozen with PyInstaller?
   (Qt's bundled .qm files would need to be explicitly included.)
3. Whether the Azure Artifact Signing significantly reduces SmartScreen
   warnings compared to unsigned executables.
4. Whether the lack of UPX has any impact on the installer size (at ~600MB,
   UPX is unlikely to be beneficial).