# Packaging Study: Dikte

## 1. Executive Summary

This report studies repository revision `3663c7f` (`v1.0.2`) as inspected on
2026-08-25. Dikte is a GPL-3.0 voice-dictation desktop application written in
Python 3.11+ with PyQt6. It is Linux-first, but it has source-install paths and
downloadable artifacts for Linux, macOS, and Windows.

The release architecture is deliberately simple:

```text
Python + PyQt6 source
        |
        +-- Linux (ubuntu-22.04, x86_64)
        |     PyInstaller onedir -> hand-built AppDir -> appimagetool -> AppImage
        |
        +-- Windows (windows-latest, x64)
        |     PyInstaller onedir -> add ffmpeg -> Inno Setup -> setup.exe
        |
        +-- macOS (Apple silicon and Intel runners)
              PyInstaller onedir/BUNDLE -> Dikte.app -> add ffmpeg
              -> ad-hoc codesign -> hdiutil -> architecture-specific DMG
```

The project does **not** use Nuitka, a PyInstaller onefile executable, UPX by
explicit configuration, custom PyInstaller bootloaders, Debian packages,
Authenticode, an Apple Developer ID, hardened runtime, notarization, stapling,
final-artifact checksums, SBOMs, or build provenance attestations. Absence was
verified by recursive source search; it is not inferred from silence in the
README.

The strongest reusable ideas are:

1. Use `onedir` inside an installer/container rather than nesting onefile
   extraction inside an AppImage, DMG, or setup.
2. Build Linux artifacts on an intentionally old runner to limit the GLIBC
   floor.
3. Pin and SHA-256-check downloaded helper binaries before embedding them.
4. Restore the host's loader environment before invoking host tools from a
   frozen application.
5. Keep packaging in one reusable matrix workflow and run it for
   packaging-related pull requests, not only releases.

The largest weaknesses are unpinned Python/build dependencies, a continuously
moving and unchecked `appimagetool` download, no signing on Windows, only ad-hoc
signing on macOS, no notarization, and no smoke tests of the produced artifacts.

Evidence terminology in this report:

- **Implemented** means a current script or workflow performs it.
- **Documented** means project documentation claims it.
- **Not verified from the available evidence** means the repository and public
  project evidence do not establish it.
- “Ad-hoc signed” on macOS is not equivalent to “Developer ID signed.”

## 2. Project Architecture

### Identity and purpose

- Project: **Dikte** ([README.md lines 1-11](README.md#L1-L11)).
- Purpose: global-hotkey voice dictation; record speech, transcribe it locally or
  through a provider, optionally clean it up, then copy/paste it into the active
  application ([README.md lines 3-6](README.md#L3-L6)).
- License: GPL-3.0 ([README.md lines 263-265](README.md#L263-L265)).
- Current inspected version: `1.0.2`
  ([dikte/__init__.py lines 8-13](dikte/__init__.py#L8-L13)).

### Languages and frameworks

- Application: Python.
- Build/release automation: Bash, PowerShell, Inno Setup Pascal scripting, YAML.
- GUI binding: direct **PyQt6**, not PySide6 and not QtPy. Imports cover
  `QtCore`, `QtGui`, `QtWidgets`, and `QtNetwork`; representative evidence is
  [dikte/app.py lines 36-40](dikte/app.py#L36-L40).
- Python support claimed by the application: **3.11 or newer**
  ([README.md lines 8-11](README.md#L8-L11)). CI tests 3.11, 3.12, and 3.13 on
  Linux and subsets on macOS/Windows
  ([tests workflow lines 9-15, 55-61, 96-102](.github/workflows/tests.yml#L9-L15)).
- Release builds use Python 3.12, with the patch release not pinned
  ([build workflow lines 61-64](.github/workflows/build.yml#L61-L64)).
- Qt/PyQt requirement: no minimum or maximum PyQt6 or Qt version is declared.
  CI installs whatever `pip install PyQt6` resolves at build time
  ([build workflow lines 77-78](.github/workflows/build.yml#L77-L78)). Therefore
  the exact Qt version inside a historical artifact is **not verified from the
  available evidence** unless the artifact or its build log is inspected. The
  local analysis environment happened to contain PyQt 6.9.0 with Qt 6.8.2; that
  is not a repository requirement.

### Supported systems

- Linux: KDE Plasma 6/Wayland is the primary target; GNOME X11 and other Linux
  desktops are supported subject to keyboard access and external tools
  ([README.md lines 8-11](README.md#L8-L11)).
- Windows: Windows 10 and 11; release artifact is x64, with ARM running it under
  emulation ([README.windows.md lines 6-13](README.windows.md#L6-L13)).
- macOS: both arm64 and x86_64 release artifacts are built. `Info.plist` declares
  macOS 11.0 minimum ([packaging/dikte.spec lines 117-136](packaging/dikte.spec#L117-L136)).
- Platform feature parity is not complete. Windows meeting capture is explicitly
  unsupported ([README.windows.md lines 54-59](README.windows.md#L54-L59)).

### Entry points and structure

- Checkout entry: `python -m dikte` ->
  [dikte/__main__.py](dikte/__main__.py) -> `dikte.app.main()`.
- Frozen entry: [packaging/entry.py](packaging/entry.py). It first repairs the
  inherited loader path, trust-store selection, and bundled-tool `PATH`, removes
  Finder's `-psn_...` argument, then calls `main()`
  ([lines 16-26](packaging/entry.py#L16-L26)).
- `dikte/`: application package; `tests/`: module-oriented `unittest` suite;
  `packaging/`: the shared PyInstaller spec and OS wrappers; `scripts/`: source
  install/update/uninstall and version/tag release script; `.github/workflows/`:
  tests, reusable builds, and publication.

### Dependency and build metadata

There is no `pyproject.toml`, `setup.py`, `setup.cfg`, requirements file, lock
file, tox/nox configuration, or Makefile. The application intentionally depends
only on the standard library plus PyQt6 at the Python layer
([CONTRIBUTING.md lines 3-14](CONTRIBUTING.md#L3-L14)). Platform commands such as
ffmpeg, PipeWire/PulseAudio, clipboard helpers, and hotkey helpers are managed
by scripts or downloaded at runtime.

Consequences:

- This is an application repository, not a conventional installable Python
  distribution.
- Dependency resolution is not repeatable. PyQt6, PyInstaller, pip's transitive
  packages, runner images, and actions may change between identical source tags.
- The source installer uses distribution packages/Homebrew/pip rather than a
  project virtual environment by default.

### Testing result

The inspected source suite ran successfully with `QT_QPA_PLATFORM=offscreen`:
`Ran 1212 tests ... OK`. It required loopback sockets for a small group of server
tests. This validates source behavior in the analysis environment; it does not
validate frozen artifact contents or installation on clean target VMs.

## 3. Packaging Overview

### Actual map and responsible files

```text
dikte Python package + packaging/entry.py
                  |
                  +-- packaging/dikte.spec (shared PyInstaller onedir recipe)
                  |             |
                  |             +-- Qt hooks collect detected PyQt6 runtime
                  |             +-- selected Qt modules explicitly excluded
                  |             +-- windowed executable on every OS
                  |             +-- extra console executable on Windows
                  |
      +-----------+----------------------+----------------------+
      |                                  |                      |
Windows                            Linux                 macOS arm64/x86_64
packaging/build-windows.ps1        build-appimage.sh     build-dmg.sh
      |                                  |                      |
draw .ico                          copy onedir into       BUNDLE creates .app
PyInstaller onedir                AppDir/usr/bin         add pinned ffmpeg
verify PE subsystems              draw PNG icon theme    ad-hoc sign .app
add pinned ffmpeg                 write AppRun/.desktop  hdiutil UDZO
Inno Setup dikte.iss              fetch appimagetool     |
      |                           build AppImage          +-- two .dmg files
      +-- x64 setup.exe                 |
                                      +-- x86_64 AppImage

All matrix outputs -> Actions artifacts -> release.yml -> GitHub Release
```

### Current versus alternative infrastructure

- **Current release infrastructure:** the three `packaging/build-*` scripts,
  `dikte.spec`, `.github/workflows/build.yml`, `.github/workflows/release.yml`,
  and `scripts/release.sh`.
- **Current source-install infrastructure:** `install.sh`, `install.ps1`, and
  `scripts/install-mac.sh`. These install a checkout and should not be confused
  with building release artifacts.
- **No obvious legacy release system:** git history shows the artifact pipeline
  was introduced in August 2026 and then consolidated. A compatibility branch
  in `scripts/install-mac.sh` lines 36-43 is explicitly described as removable
  after old updates disappear; that branch is legacy compatibility, not the
  packaging pipeline.

## 4. Windows

### Actual build

Evidence:

- [packaging/build-windows.ps1](packaging/build-windows.ps1)
- [packaging/dikte.spec](packaging/dikte.spec)
- [packaging/dikte.iss](packaging/dikte.iss)
- Windows matrix entry in
  [.github/workflows/build.yml lines 49-53](.github/workflows/build.yml#L49-L53)

Process:

```text
Python 3.12 + unpinned PyQt6/PyInstaller
    -> generate build/Dikte.ico with PyQt6 offscreen rendering
    -> PyInstaller COLLECT/onedir build/dist/dikte/
         Dikte.exe       GUI subsystem, no console
         dikte-cli.exe   console subsystem, for CLI output
         Python/Qt DLLs and plugins
    -> verify PE subsystem values (2 GUI, 3 console)
    -> download pinned ffmpeg b6.1.1 archive
    -> verify embedded SHA-256 and expand to bin/ffmpeg.exe
    -> compile packaging/dikte.iss with Inno Setup 6
    -> dist/Dikte-<version>-x64-setup.exe
```

The two-executable arrangement is project-relevant: a GUI executable cannot
print CLI replies to an existing console. The build checks the PE subsystem to
prevent a previously encountered case-insensitive filename collision
([build-windows.ps1 lines 46-73](packaging/build-windows.ps1#L46-L73)). This is
excellent defensive packaging, but copying it only makes sense for applications
that expose both a GUI launcher and a terminal CLI.

### Architecture and installation scope

- x64 only; Windows ARM uses emulation
  ([build-windows.ps1 lines 5-8](packaging/build-windows.ps1#L5-L8)).
- Per-user install under `%LOCALAPPDATA%\Programs\Dikte`; no elevation because
  `PrivilegesRequired=lowest`
  ([dikte.iss lines 21-38](packaging/dikte.iss#L21-L38)).
- Start Menu entry points to `Dikte.exe`
  ([dikte.iss lines 59-64](packaging/dikte.iss#L59-L64)).
- Optional-on-by-default autostart is an HKCU Run value
  ([dikte.iss lines 54-77](packaging/dikte.iss#L54-L77)).
- A `dikte.cmd` shim in the user's existing WindowsApps directory points to
  `dikte-cli.exe` ([dikte.iss lines 83-116](packaging/dikte.iss#L83-L116)).
- Inno Setup supplies Add/Remove Programs registration and uninstall behavior.

### Portable versus installer

The pipeline publishes only the installer. The intermediate onedir tree is
technically portable but is uploaded only as part of the setup, not as a ZIP or
separate release asset. A public portable Windows distribution is therefore
**not implemented**.

## 5. PyInstaller

### Mode

This is **onedir**, not onefile. The decisive evidence is the `COLLECT` call in
[dikte.spec lines 103-109](packaging/dikte.spec#L103-L109); PyInstaller's spec
format uses `COLLECT` for a one-folder bundle. The spec's own rationale is even
more explicit ([lines 6-11](packaging/dikte.spec#L6-L11)):

- onefile extracts to a temporary directory on every start;
- that delays a global-hotkey application;
- it would create nested extraction inside AppImage;
- the end-user already receives a single AppImage, DMG, or setup program.

`console=False` is the spec equivalent of `--windowed`/`--noconsole` for the
primary executable ([lines 61-79](packaging/dikte.spec#L61-L79)). Windows alone
also gets `console=True` for `dikte-cli.exe` ([lines 81-101](packaging/dikte.spec#L81-L101)).

### Spec walkthrough

1. Lines 13-17 import only build-time helpers.
2. Line 18 obtains the repository root from PyInstaller's `SPECPATH`.
3. Lines 20-26 parse `__version__` without importing the checkout, avoiding a
   collision between the local `packaging/` directory and the Python
   `packaging` library.
4. Lines 28-30 select macOS/Windows behavior and establish one stable bundle ID.
5. Lines 32-47 enumerate unused PyQt6 modules such as WebEngine, QML, Quick,
   Multimedia, 3D, SQL, and Bluetooth. This targets bundle size.
6. `Analysis` at lines 49-57 starts from `packaging/entry.py`, adds the repository
   root to analysis paths, explicitly adds `PyQt6.QtNetwork`, excludes unused Qt,
   Tkinter, and tests, and keeps pure modules in an archive.
7. `PYZ` at line 59 stores analyzed pure-Python modules.
8. `EXE` at lines 61-79 creates the GUI bootloader executable but leaves binaries
   for the later collection. Its name and ad-hoc macOS identity are conditional;
   its icon arrives via `DIKTE_ICO` on Windows.
9. Lines 81-101 create the optional Windows console bootloader using the same
   script/archive analysis.
10. `COLLECT` at lines 103-109 builds the onedir tree from executables, binaries,
    and data discovered by analysis/hooks.
11. `BUNDLE` at lines 111-137 wraps the macOS collection in `Dikte.app` and
    supplies icon, bundle ID, version, minimum OS, menu-bar-only behavior, and
    privacy usage descriptions.

### Hooks, imports, data, and resources

- No project-specific PyInstaller hook or runtime hook exists.
- `PyQt6.QtNetwork` is a hidden import even though the current source directly
  imports it. It is harmless defensive configuration, but the repository does
  not document the exact failure that required it.
- Qt's standard PyInstaller hooks and `pyi_rth_pyqt6` runtime hook are relied on
  implicitly. They analyze imported Qt modules and collect matching Qt shared
  libraries and plugin families. [PyInstaller's hook documentation](https://pyinstaller.org/en/latest/hooks.html)
  explains this mechanism.
- Exact plugin files in v1.0.2 are **not verified from the available evidence**:
  no frozen tree or PyInstaller build log is committed, and PyInstaller/PyQt6 are
  unpinned. Based on imports and standard hooks, the platform plugin and required
  GUI/network dependencies should be collected, and modern PyInstaller's
  QtNetwork hook collects Qt TLS plugins. This is an inference, not an artifact
  inventory.
- No `datas=`, `binaries=`, or manual Qt plugin tuple is provided in the spec.
  Application imagery is generated outside/around PyInstaller; ffmpeg is added
  after PyInstaller.
- No `sys._MEIPASS` is used. `sys.frozen` distinguishes frozen builds
  ([dikte/integrate.py lines 54-57](dikte/integrate.py#L54-L57)); `APPIMAGE`,
  `sys.executable`, and `.app` ancestors locate the durable outer artifact
  ([lines 59-80](dikte/integrate.py#L59-L80)).

### UPX and compression

There is no `upx=`, `--upx-dir`, or `--noupx` setting. Thus UPX is not
deliberately enabled or disabled. PyInstaller can automatically use UPX on
Windows if it is found on `PATH`; the repository does not install UPX, and
GitHub's runner availability is not established here. Therefore:

> Whether the published Windows bundle was UPX-processed is not verified from
> the available evidence. There is no evidence that the project intentionally
> uses UPX.

The Inno Setup container definitely uses `lzma2/max` plus solid compression
([dikte.iss lines 41-45](packaging/dikte.iss#L41-L45)). This is installer payload
compression, not UPX or executable packing.

## 6. Nuitka

Dikte contains no Nuitka code or configuration. The following is comparative
guidance, not a description of this repository.

### PyInstaller characteristics

- Fast builds and mature freezing support, including first-party PyQt6 hooks.
- Easy `onedir` debugging and straightforward spec customization.
- Ships Python bytecode and a bootloader rather than translating application
  modules to C.
- Onefile has extraction/startup cost; onedir avoids it.
- Bundle size is driven mainly by Python, Qt, included Qt modules/plugins, and
  helper binaries. Dikte reduces it by excluding unused Qt modules.
- Antivirus false positives occur in practice. They are heuristic and cannot be
  reduced to “PyInstaller always bad” or “onefile always bad.”

### Nuitka characteristics

- Translates Python modules into C and builds native extension/executable code;
  it still needs a compatible Python runtime and collected dependencies in
  standalone mode.
- Requires a C11 compiler and a longer, more resource-intensive build. Current
  requirements and supported compilers are in the
  [Nuitka user manual](https://nuitka.net/user-documentation/user-manual.html).
- `--mode=standalone` is the relevant comparison with this project's onedir
  layout; `--mode=onefile` adds an outer bootstrap/extraction tradeoff.
- The `pyqt6` plugin can select Qt plugin families; current plugin documentation
  describes `--include-qt-plugins`. Historical Nuitka 2.1 release notes say
  PyQt6 support on macOS was discontinued because framework packaging was not
  adequately supported. Current development source again contains generic
  PyQt6 handling, so macOS PyQt6 support must be proven with the exact Nuitka and
  PyQt6 versions before adopting it. It is not safe to assume three-platform
  parity from a successful Windows build.
- Compilation may improve startup/performance for Python-heavy code, but this
  application's latency and size are likely dominated by Qt and external speech
  tools/models. Benchmarking is required.
- Fewer VirusTotal detections in one developer's tests are useful empirical
  evidence for that application/version, not a guarantee for another release.

### Is Nuitka reasonable here?

Yes, as an experiment—especially for Windows standalone distribution and the
user's reported antivirus experience. A disciplined comparison should build the
same clean source with pinned PyInstaller and pinned Nuitka, no UPX, equivalent
Qt plugin sets and metadata, then compare startup, size, cold-machine behavior,
and vendor-specific detections over multiple releases. For Dikte specifically,
the current PyInstaller pipeline already works across all three systems and its
onedir choice avoids its most obvious onefile drawback. Replacing it is not an
automatic improvement.

## 7. Antivirus / VirusTotal Considerations

### What Dikte actually does

Supported by repository evidence:

- Uses PyInstaller onedir inside an installer, not a onefile application.
- Embeds a stable app name, publisher string, version, support URL, and icon in
  Inno Setup ([dikte.iss lines 21-40](packaging/dikte.iss#L21-L40)).
- Embeds an icon in both GUI and CLI application executables
  ([dikte.spec lines 75-78, 92-101](packaging/dikte.spec#L75-L78)).
- Uses a per-user installer without a UAC request.
- Publishes source and artifacts through public GitHub Releases.
- Pins and checksums the bundled ffmpeg input.
- Does **not** obfuscate or apply repository-configured executable packers.

Missing:

- No Windows version-resource file is passed to PyInstaller. Inno metadata does
  not prove that `Dikte.exe` itself has ProductName, CompanyName, FileVersion,
  and ProductVersion resources.
- No explicit Windows application manifest or requested-execution-level is
  supplied to PyInstaller. PyInstaller's default manifest behavior applies, but
  exact output is not inventoried.
- No Authenticode command, certificate, RFC 3161 timestamp, or signing secret.
- Neither inner application executable nor outer setup is signed. README and
  release notes explicitly warn that the setup is unsigned
  ([README.windows.md lines 18-26](README.windows.md#L18-L26)).
- No VirusTotal scan, Defender submission, false-positive tracking, checksum
  file, or provenance attestation.
- No custom/recompiled PyInstaller bootloader.
- No reproducible-build claim or configuration such as a fixed
  `SOURCE_DATE_EPOCH` across all inputs.

### What can legitimately help

- **Code-sign every release with one stable, publicly trusted identity.** This
  establishes publisher identity and lets publisher reputation accumulate, but
  Microsoft states that even valid OV/EV-signed new binaries can initially show
  SmartScreen warnings. EV no longer automatically bypasses SmartScreen. See
  [Microsoft's SmartScreen reputation documentation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation).
- **Sign the inner application executables, then build and sign the installer.**
  Otherwise the installed files remain unsigned even if only the setup is signed.
  Verify both layers with `signtool verify`.
- **Timestamp signatures** so their validity can be evaluated after certificate
  expiry/revocation. SignTool supports RFC 3161 `/tr` and `/td`; see the
  [SignTool reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/signtool).
- **Avoid unnecessary UPX/packers and obfuscation.** This is conservative supply
  hygiene, not proof of lower detection rates.
- **Use clean, pinned CI inputs and publish checksums/provenance.** These do not
  change antivirus heuristics directly, but make investigation and user
  verification credible.
- **Submit false positives to the detecting vendors.** Microsoft provides a
  software-developer submission route at its
  [malware-analysis portal](https://www.microsoft.com/en-us/wdsi/filesubmission).
- **Test onedir and Nuitka standalone empirically.** PyInstaller maintainers have
  suggested avoiding onefile when possible in false-positive discussions, but
  this is not a universal causal law.

PyInstaller documents rebuilding its bootloader as one possible response to
widespread precompiled-bootloader false positives
([official bootloader-building documentation](https://pyinstaller.org/en/stable/bootloader-building.html)).
Dikte does not do this. A custom bootloader can merely change heuristic similarity;
it has no guaranteed effect and can lose the benefit of a stock bootloader's
vendor allowlisting.

No evidence was found that Dikte's artifacts were submitted to VirusTotal or
that any specific detection count improved because of onedir, Inno Setup,
metadata, or GitHub Releases. Claims of causation would be fabricated.

## 8. Windows Installer

Technology: **Inno Setup 6**. The build locates `iscc` on `PATH` or under Program
Files and suggests `winget install JRSoftware.InnoSetup` if absent
([build-windows.ps1 lines 95-107](packaging/build-windows.ps1#L95-L107)).

Noteworthy details:

- Stable `AppId` lets upgrades recognize an existing install.
- Per-user scope avoids elevation.
- x64-compatible architecture mode.
- Maximum solid LZMA2 compression.
- Restart Manager closes/restarts a running Dikte during upgrade.
- Optional autostart task is checked by default.
- Uninstaller removes the HKCU Run value and CLI shim.

There is no MSI, MSIX, NSIS, WiX, or portable ZIP. For a new open-source PyQt6
project, Inno Setup remains a practical classic-desktop choice when a flexible,
small per-user EXE installer is wanted. MSIX/Store distribution is attractive
for Windows trust and managed deployment but imposes packaging/identity and app
behavior constraints. An MSI is usually justified by enterprise deployment
requirements, not professionalism by itself.

## 9. Windows Code Signing

Current sequence:

```text
PyInstaller Dikte.exe + dikte-cli.exe (unsigned)
    -> add ffmpeg
    -> Inno Setup setup.exe (unsigned)
    -> GitHub Release
```

Answers:

- Application executable signed? **No evidence; effectively no.**
- Installer signed? **No; explicitly documented as unsigned.**
- Certificate type/timestamp service? None.
- SmartScreen reputation strategy? Public GitHub delivery plus user instructions
  to click More info; no cryptographic publisher reputation.

The professional improvement is:

```text
build onedir
 -> add final resources/helpers
 -> sign and verify Dikte.exe and dikte-cli.exe
 -> compile installer (and a signed uninstaller if supported/configured)
 -> sign and verify setup.exe with RFC 3161 timestamp
 -> hash/attest/publish
```

Third-party files should retain their upstream signatures where possible; do not
casually re-sign another publisher's binary as your own.

## 10. Linux

Dikte offers two Linux distribution modes:

1. Source checkout installed into the user's XDG directories by `install.sh`.
   This depends on system Python, system PyQt6, ffmpeg, audio, clipboard, and
   hotkey tools.
2. A release AppImage. This bundles Python, PyQt6/Qt, and the application through
   PyInstaller, but deliberately continues to use system audio/clipboard/hotkey
   tools and system ffmpeg.

There is no Flatpak, Snap, RPM, Debian package, repository, or AppStream metadata.

## 11. AppImage

### Tool and directory layout

The project creates the AppDir manually and invokes `appimagetool` directly. It
does not use linuxdeploy, linuxdeploy-plugin-qt, or appimage-builder.

Actual logical layout from [build-appimage.sh](packaging/build-appimage.sh):

```text
AppDir/
├── AppRun                         # resolves mount path, execs usr/bin/dikte
├── dikte.desktop
├── dikte.png                      # 256px top-level icon for appimagetool
└── usr/
    ├── bin/
    │   ├── dikte                  # PyInstaller GUI executable
    │   └── _internal/...          # Python, PyQt6, Qt libs/plugins, stdlib
    └── share/icons/hicolor/
        ├── 16x16/apps/dikte.png
        ├── ...
        └── 256x256/apps/dikte.png
```

The exact PyInstaller `_internal` spelling/layout depends on the unpinned
PyInstaller version and is therefore illustrative. The outer paths are fixed by
the script.

Stages:

1. Clean `build/` and `dist/`; make `AppDir/usr/bin`.
2. Run the shared onedir spec and copy its whole `dikte/` collection into
   `usr/bin` ([lines 23-26](packaging/build-appimage.sh#L23-L26)).
3. Render hicolor PNGs with the application's PyQt drawing code offscreen and
   copy them into the AppDir ([lines 28-39](packaging/build-appimage.sh#L28-L39)).
4. Generate a relative, mount-safe `AppRun` ([lines 41-49](packaging/build-appimage.sh#L41-L49)).
5. Generate the desktop file ([lines 51-64](packaging/build-appimage.sh#L51-L64)).
6. Download the architecture-matched continuously published appimagetool and run
   it with `--appimage-extract-and-run` because CI has no FUSE
   ([lines 66-75](packaging/build-appimage.sh#L66-L75)).

### Portability choices

- Build host is `ubuntu-22.04`, explicitly selected as the oldest GitHub-hosted
  Ubuntu runner currently used by the project
  ([build.yml lines 38-42](.github/workflows/build.yml#L38-L42)). This sets a
  GLIBC compatibility floor; binaries built against newer symbol versions will
  not run on older GLIBC.
- PyInstaller bundles the active Python interpreter, PyQt6 wheel's Qt libraries,
  and detected plugins.
- Linux still needs host audio/clipboard/keyboard tools and ffmpeg; the AppImage
  is not hermetic ([dikte/integrate.py lines 173-181](dikte/integrate.py#L173-L181)).
- `restore_library_path()` removes PyInstaller's inherited `LD_LIBRARY_PATH`
  before starting host commands so they do not load the bundle's incompatible
  `libstdc++` ([dikte/integrate.py lines 83-117](dikte/integrate.py#L83-L117)).
- `use_system_certificates()` detects a broken compiled-in OpenSSL CA location
  and selects the host trust store without overriding an explicit user choice
  ([lines 120-170](dikte/integrate.py#L120-L170)).
- Qt plugins are expected to be located by their own RPATH after the loader
  environment is restored ([lines 89-104](dikte/integrate.py#L89-L104)).

The official AppImage guidance likewise recommends “build on old systems, run
on newer systems” and testing the oldest target systems; see
[AppImage concepts](https://docs.appimage.org/introduction/concepts.html) and
[best practices](https://docs.appimage.org/reference/best-practices.html).

### Desktop integration

At first frozen start, `integrate.ensure()` writes a user menu entry, autostart
entry, hicolor icons, and `~/.local/bin/dikte` symlink to the durable AppImage
path ([dikte/integrate.py lines 204-237, 350-377](dikte/integrate.py#L204-L237)).
It detects another working Dikte or AppImageLauncher entry and avoids taking it
over silently ([lines 325-347](dikte/integrate.py#L325-L347)).

### Testing and gaps

There are detailed unit tests for target path, loader restoration, certificate
fallback, integration files, moves, spaces in paths, and AppImageLauncher
coexistence ([tests/test_integrate.py](tests/test_integrate.py)). CI also executes
the build on packaging pull requests. However:

- CI does not launch the finished AppImage.
- No cross-distribution runtime matrix exists (Ubuntu, Debian, Fedora, Arch,
  openSUSE, old GLIBC).
- No AppStream metainfo is included.
- `appimagetool` uses the mutable `continuous` asset without a version pin or
  checksum. This is a supply-chain and reproducibility gap.
- The final AppImage has no published project-generated SHA-256 or signature.

## 12. Debian Package

**Dikte does not produce a `.deb`.** No `debian/`, `DEBIAN/control`, `control`,
`rules`, `changelog`, `copyright`, or `.install` packaging exists. README apt
commands install external runtime tools for a checkout; they are not evidence
of a Dikte Debian package.

Accordingly:

- Bundle-versus-system dependency policy: not applicable to a Dikte `.deb`.
- Install paths and maintainer scripts: not implemented.
- Desktop integration for `.deb`: not implemented.
- `lintian`, `dpkg-buildpackage`, and package-install CI: not implemented.

For a future native Debian package, the natural policy-compliant design is a
small architecture-independent application depending on distribution
`python3`, `python3-pyqt6`, ffmpeg, and desktop-specific helpers, with private
modules under `/usr/lib/dikte` or `/usr/share/dikte`, a launcher under
`/usr/bin`, desktop entry under `/usr/share/applications`, icons under
`/usr/share/icons/hicolor`, and documentation/copyright under `/usr/share/doc`.
Exact dependency names vary by Debian/Ubuntu release and must be verified. Debian
Python policy favors distribution-managed dependencies rather than embedding a
venv; see [Debian Python Policy](https://www.debian.org/doc/packaging-manuals/python-policy/).

A bundled PyInstaller-onedir payload inside a `.deb` is possible but is not a
normal Debian archive package: it duplicates Python/Qt, increases size, receives
security fixes only when upstream rebuilds it, and may be rejected from a
distribution archive. It can still be reasonable for an upstream-only `.deb`
when consistent runtime versions matter; label that tradeoff honestly.

## 13. macOS

### Release DMG path

The release path uses PyInstaller, not `scripts/install-mac.sh`:

```text
macOS runner + Python 3.12 + PyQt6/PyInstaller
  -> trayicon.py renders Dikte.iconset
  -> iconutil creates Dikte.icns
  -> PyInstaller COLLECT + BUNDLE creates Dikte.app
  -> download architecture-specific ffmpeg b6.1.1
  -> SHA-256 verify and place at Contents/Resources/bin/ffmpeg
  -> ad-hoc codesign --deep the complete app
  -> verify ad-hoc signature
  -> stage Dikte.app + Applications symlink
  -> hdiutil UDZO -> Dikte-<version>-<arch>.dmg
```

`macos-latest` produces the Apple-silicon build and `macos-15-intel` the Intel
build ([build.yml lines 43-48](.github/workflows/build.yml#L43-L48)). There is no
universal wheel, so there is no universal application
([build-dmg.sh lines 5-8](packaging/build-dmg.sh#L5-L8)).

### Application bundle

PyInstaller's `BUNDLE` constructs the bundle. Configured `Info.plist` values are:

- `CFBundleName`/`CFBundleDisplayName`: Dikte.
- Stable identifier `io.github.yusufipk.dikte`.
- short/build version from `dikte.__version__`.
- minimum macOS 11.0.
- `LSUIElement=true` for a menu-bar application.
- high-resolution capable.
- microphone and Apple Events usage descriptions.

Evidence: [dikte.spec lines 111-137](packaging/dikte.spec#L111-L137).

Python, Qt frameworks/libraries, PyQt6 extension modules, plugins, and analyzed
Python code come from PyInstaller. ffmpeg is an explicit post-build resource.
The generated `.icns` is supplied to `BUNDLE`. Exact framework/plugin inventory
is not committed and is **not verified from the available evidence**.

### Separate checkout installer

`scripts/install-mac.sh` also creates a `~/Applications/Dikte.app`, but it is a
source-checkout launcher, not the release DMG app. It copies a Homebrew/venv
Python executable, points `PYTHONHOME`/`PYTHONPATH` at its external installation,
writes its own `Info.plist`, generates an icon, ad-hoc signs, and installs a
LaunchAgent and command wrapper. It is less self-contained and can break after a
Homebrew Python upgrade ([scripts/install-mac.sh lines 128-170](scripts/install-mac.sh#L128-L170)).
Copying this mechanism into a distributable product would be inappropriate.

## 14. macOS Code Signing

The release `.app` is ad-hoc signed with identity `-` twice in effect:

- PyInstaller is asked to use `codesign_identity="-"` for its executable
  ([dikte.spec lines 68-74](packaging/dikte.spec#L68-L74)).
- After adding ffmpeg, the script runs
  `codesign --force --deep --sign - --identifier ... Dikte.app` and verifies it
  ([build-dmg.sh lines 64-75](packaging/build-dmg.sh#L64-L75)).

This is necessary for arm64 execution and gives macOS a code-signature identity
for privacy permissions, but it does not establish a verified publisher and does
not satisfy Gatekeeper's normal Developer ID distribution path. The project
explicitly says `--deep` is suitable for this ad-hoc case but wrong for a proper
nested-code signing strategy.

The DMG itself is not signed. No entitlements file, `--options runtime`, secure
timestamp, keychain import, Developer ID identity, or certificate secret exists.

## 15. macOS Notarization

Not implemented:

- no Developer ID Application signature;
- no hardened runtime;
- no `xcrun notarytool`;
- no notarization credentials;
- no `stapler`;
- no Gatekeeper `spctl` verification;
- no signed DMG.

Actual sequence:

```text
.app -> add ffmpeg -> ad-hoc sign/verify -> create unsigned, unstapled DMG
```

The README and generated release notes correctly disclose first-launch refusal
and repeated permissions after updates
([release.yml lines 149-157](.github/workflows/release.yml#L149-L157)). There is
no documentation/implementation discrepancy here.

Apple's professional path requires a paid Apple Developer Program membership for
Developer ID certificates and notarization access. Xcode command-line tools,
`codesign`, `hdiutil`, and local ad-hoc signing are free. Apple requires Developer
ID signing, hardened runtime, valid signatures for nested code, and secure
timestamps before notarization; see
[Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 16. GitHub Actions

### Test workflow

Triggers: all pull requests and pushes to `master`. Jobs:

- Linux matrix: Python 3.11/3.12/3.13, apt Qt runtime libraries, unpinned PyQt6,
  full verbose unittest suite.
- macOS matrix: Python 3.11/3.13, PyQt6, suite, Bash syntax checks for install and
  packaging scripts.
- Windows matrix: Python 3.11/3.13, PyQt6, suite, PowerShell parser checks.

Evidence: [.github/workflows/tests.yml](.github/workflows/tests.yml).

### Reusable build workflow

Triggers/callers:

- called by the release workflow with a ref/version;
- pull requests touching `packaging/**`, the build workflow, integration code,
  or icon code;
- manual dispatch.

Matrix:

| Runner | Kind | Output |
|---|---|---|
| `ubuntu-22.04` | appimage | x86_64 AppImage |
| `macos-latest` | dmg | arm64 DMG (runner architecture) |
| `macos-15-intel` | dmg | x86_64 DMG |
| `windows-latest` | windows | x64 Inno setup EXE |

Each uses Python 3.12, installs unpinned PyQt6/PyInstaller, optionally rewrites
the version for rolling builds, invokes the platform script, then uploads
`dist/*` ([build.yml lines 55-114](.github/workflows/build.yml#L55-L114)).

### Release workflow

```text
push master / push v* tag / manual version bump
                      |
                 Linux tests
                      |
          decide version/ref/release type
                      |
              call reusable build matrix
                      |
          download and merge all artifacts
                      |
        gh release create latest or v<version>
```

- Master pushes replace a rolling `latest` prerelease and tag.
- `v*` pushes create permanent releases.
- Manual dispatch runs `scripts/release.sh`, which updates the sole version,
  commits, creates an **annotated but not cryptographically signed** tag, and
  pushes it ([scripts/release.sh lines 55-68](scripts/release.sh#L55-L68)).
- The release job retests rather than depending on the independent tests workflow.
- Concurrency cancels stale rolling releases but preserves tagged releases.
- `gh release create` publishes all merged downloads
  ([release.yml lines 123-182](.github/workflows/release.yml#L123-L182)).

### Permissions and secrets

- Build workflow: `contents: read`.
- Release workflow: `contents: write`.
- Publication exposes `GH_TOKEN=${{ github.token }}` to `gh`; this is the
  ephemeral built-in token, not a repository secret
  ([release.yml lines 136-140](.github/workflows/release.yml#L136-L140)).
- No user-defined GitHub Actions secrets are referenced. Therefore no signing
  secrets are currently required.

### CI gaps

- Actions are version-tagged (`@v4`, `@v5`), not pinned to immutable commit SHAs.
- No pip cache or dependency cache is configured.
- No build input lock.
- No artifact execution/smoke install.
- No signing jobs or protected signing environment.
- No artifact SHA-256 manifest, SBOM, attestation, or immutable-release setting
  visible in the workflow.

## 17. Resource Handling

Dikte does not use `.qrc`, generated Qt resource modules, `.ui`, fonts, JSON
templates, bundled databases, sound files, or committed PNG/ICO/ICNS application
assets. Documentation screenshots under `docs/*.webp` are README assets, not
runtime resources.

Application and tray icons are drawn programmatically in
[dikte/trayicon.py](dikte/trayicon.py):

- state icon sizes 22/44;
- hicolor PNG sizes 16 through 256;
- Windows ICO contains 16 through 256;
- macOS iconset supplies 16 through 1024 variants.

Packaging calls this code before or after freezing:

- Windows: render `.ico`, embed in PyInstaller executables and Inno setup.
- Linux: render hicolor PNG tree and top-level AppImage PNG.
- macOS: render iconset and convert to `.icns` before `BUNDLE`.

This eliminates duplicated binary assets but makes build-time PyQt6/offscreen
rendering a hard dependency. For most projects, committed source SVG/PNG plus a
deterministic conversion step is easier for designers and can be audited without
executing GUI code.

## 18. PyQt6 / Qt Plugins

Directly imported Qt modules are Core, Gui, Widgets, and Network. The spec
excludes broad unused feature modules to reduce size. Qt plugins are not copied
by shell code; PyInstaller's standard PyQt6 hooks do the work.

Likely required families include each OS's `platforms` plugin and GUI image/icon
support. QtNetwork TLS plugins matter for HTTPS. Modern PyInstaller release notes
state that the QtNetwork PyQt6 hook collects Qt 6 TLS plugins, but because the
build tool is unpinned and artifacts were not unpacked, the exact v1.0.2 plugin
list remains **not verified from the available evidence**.

Recommended verification for this project:

```text
build tree inventory
  -> launch with QT_DEBUG_PLUGINS=1 on clean VM
  -> exercise GUI, PNG/SVG, native dialogs, HTTPS/TLS
  -> assert no plugin is loaded from a developer/system Qt installation
```

## 19. Translations

Application localization is an in-code English-to-Turkish dictionary in
[dikte/i18n.py lines 1-55](dikte/i18n.py#L1-L55). There are no `.ts`, `.qm`,
gettext catalogs, `QTranslator`, or `QLibraryInfo.TranslationsPath` calls.

Consequences:

- Dikte's own strings freeze naturally as Python code.
- Dikte does not explicitly install a translator for Qt's own `qtbase_*.qm`
  strings.
- Standard/native dialogs may obtain OS-native text where a native dialog is
  used, but non-native Qt standard button/dialog strings are not guaranteed to
  follow Dikte's Turkish setting.
- PyInstaller may collect Qt translation data through its hooks; collection
  alone does not call `QApplication.installTranslator()`.

Therefore the answer to “how are Qt's own dialogs translated after packaging?” is:

> Dikte contains no explicit mechanism. Correct translation of Qt-provided
> strings is not verified from the available evidence.

A reusable project should load both its application `.qm` and the relevant
`qtbase_<locale>.qm` using `QTranslator`, locating Qt translations through
`QLibraryInfo` before freezing and verifying their packaged path afterward.

## 20. Security and Release Integrity

Implemented:

- Pinned ffmpeg release plus architecture-specific SHA-256 before embedding on
  Windows/macOS.
- Runtime model/program downloads require available upstream digests and verify
  SHA-256 ([README.md lines 154-161](README.md#L154-L161)); this is runtime update
  security, not release-artifact integrity.
- Minimal workflow permissions are declared.
- Tests precede release builds; packaging changes build on PRs.
- Stable public source/tag/release relationship.
- Annotated version tags.

Not implemented:

- Python dependency pins/hashes or lock file.
- appimagetool pin/checksum.
- immutable action SHA pins.
- final-artifact SHA-256 file.
- signed release manifest, signed git tags, Windows Authenticode, Developer ID.
- SBOM or license inventory for frozen dependencies.
- SLSA provenance or GitHub artifact attestation.
- reproducible build verification.
- dependency scanning/Dependabot configuration visible in the tree.

[GitHub artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
can bind an artifact digest to repository, workflow, commit, and event. They do
not prove the binary is safe; they prove provenance when verified.

## 21. Techniques Worth Reusing

- **[HIGHLY RECOMMENDED]** One shared spec and one reusable matrix build workflow;
  reduces platform/release drift.
- **[HIGHLY RECOMMENDED]** Build packaging on relevant PRs, not only after tagging.
- **[HIGHLY RECOMMENDED]** Pin and hash every externally downloaded binary before
  embedding it.
- **[HIGHLY RECOMMENDED]** Use onedir beneath an outer installer/container when
  single-file extraction adds no user benefit.
- **[HIGHLY RECOMMENDED]** Build Linux payloads on the oldest supported base and
  test that base plus different distribution families.
- **[HIGHLY RECOMMENDED]** Restore host loader variables before invoking system
  tools from frozen apps.
- **[HIGHLY RECOMMENDED]** Validate frozen trust-store behavior across distro
  layouts.
- **[USEFUL]** Produce separate Windows GUI and CLI-subsystem launchers when the
  same app genuinely needs both.
- **[USEFUL]** Read back PE subsystem fields to catch case-insensitive output
  collisions.
- **[USEFUL]** Use a stable application/bundle ID across platforms.
- **[USEFUL]** Generate prerelease artifacts continuously while preserving tagged
  releases.

## 22. Techniques Specific to This Project

- **[PROJECT-SPECIFIC]** Programmatic icon drawing from tray glyph geometry.
- **[PROJECT-SPECIFIC]** Self-installing AppImage menu/autostart/command integration.
  Many applications should leave this to the desktop/AppImage integration tool.
- **[PROJECT-SPECIFIC]** Bundling ffmpeg on Windows/macOS but using system ffmpeg
  on Linux.
- **[PROJECT-SPECIFIC]** Excluding the exact long list of Qt modules. Copy only
  after measuring the imports/features of another app.
- **[PROJECT-SPECIFIC]** `LSUIElement`, microphone/Apple Events descriptions, and
  global-hotkey startup behavior.
- **[PROJECT-SPECIFIC]** `QT_QPA_PLATFORM=xcb` on Wayland to place an overlay in a
  screen corner ([dikte/app.py lines 22-25](dikte/app.py#L22-L25)).
- **[PROJECT-SPECIFIC]** CA-path fallback: the problem is broadly relevant, but
  the hard-coded distro list and stdlib HTTPS stack must match the new app.

## 23. Problems or Weaknesses Found

- **[NOT RECOMMENDED]** Installing unpinned PyQt6 and PyInstaller for releases.
- **[NOT RECOMMENDED]** Downloading mutable `continuous` appimagetool without a
  checksum.
- **[NOT RECOMMENDED]** Publishing unsigned Windows executables/setup as the
  primary end-user path when a signing budget/service is available.
- **[NOT RECOMMENDED]** Treating ad-hoc signing as adequate macOS distribution.
  The project does not make that mistake in documentation, but the user
  experience remains poor.
- **[NOT RECOMMENDED]** Release notes suggesting `xattr -dr
  com.apple.quarantine` as an alternative. It is transparent, not hidden, but a
  professional pipeline should use Developer ID/notarization rather than train
  users to remove quarantine.
- **[USEFUL, INCOMPLETE]** Unit tests cover integration helpers, but artifact
  launch/install tests are absent.
- **[REQUIRES FURTHER RESEARCH]** Exact Qt plugins/translations in each artifact.
- **[REQUIRES FURTHER RESEARCH]** Minimum GLIBC actually required by the bundled
  Python/PyQt wheel and compatibility beyond Ubuntu 22.04.
- **[REQUIRES FURTHER RESEARCH]** VirusTotal/vendor results; none are recorded.
- **[REQUIRES FURTHER RESEARCH]** Whether GitHub-hosted Windows runner happens to
  expose UPX; repository intent is no explicit UPX.
- **[LEGACY]** Compatibility handling for an older macOS updater in
  `scripts/install-mac.sh` lines 36-43, explicitly marked removable later.

## 24. Recommended Approach for My PyQt6 Projects

For a new application today:

1. Put metadata and pinned build dependencies in `pyproject.toml` plus a lock or
   hashed requirements export.
2. Prototype both PyInstaller onedir and Nuitka standalone on Windows. Choose from
   measured cold startup, size, compatibility, maintenance, and repeated AV
   results—not ideology.
3. Wrap the standalone directory in Inno Setup or MSIX. Embed Windows version
   metadata and an `asInvoker` manifest; avoid elevation unless required.
4. Sign application-owned PE executables and the installer with a consistent
   trusted identity and RFC 3161 timestamps. Verify after each stage.
5. Build an AppImage on the oldest supported GLIBC base. Use a pinned/checksummed
   appimagetool or linuxdeploy chain; smoke-test on old Ubuntu/Debian plus Fedora
   and Arch/openSUSE families.
6. Build a separate native `.deb` that uses distro Python/PyQt6 dependencies when
   targeting Debian repositories. Do not assume the AppImage payload and Debian
   policy package should be identical.
7. On macOS, create the `.app`, add all resources, sign nested code from inside
   out with Developer ID and hardened runtime, sign the app, create/sign the DMG,
   submit with `notarytool`, staple, and verify Gatekeeper on a clean Mac.
8. Generate SHA-256 manifests, SBOMs, and artifact attestations; publish them with
   source and release notes.
9. Test installed/frozen artifacts, not only source tests.

Recommended topology:

```text
signed tag
   -> source tests + locked dependency resolution
   -> native OS/architecture builds
      -> Windows standalone -> metadata -> inner signing -> installer -> signing
      -> Linux standalone -> AppDir/AppImage; source package -> native DEB
      -> macOS .app -> nested signing -> hardened app -> DMG -> notarize/staple
   -> artifact smoke tests
   -> SHA-256 + SBOM + provenance
   -> protected GitHub Release
```

## 25. Important Files to Study

| File | Why |
|---|---|
| [packaging/dikte.spec](packaging/dikte.spec) | Shared onedir analysis, Qt exclusions, Windows dual EXE, macOS BUNDLE |
| [packaging/build-windows.ps1](packaging/build-windows.ps1) | Icon, PyInstaller, PE checks, ffmpeg verification, Inno invocation |
| [packaging/dikte.iss](packaging/dikte.iss) | Per-user installer, compression, autostart, CLI shim |
| [packaging/build-appimage.sh](packaging/build-appimage.sh) | Manual AppDir and appimagetool pipeline |
| [packaging/build-dmg.sh](packaging/build-dmg.sh) | `.app`, ffmpeg, ad-hoc signing, DMG |
| [packaging/entry.py](packaging/entry.py) | Frozen-runtime environment preparation |
| [dikte/integrate.py](dikte/integrate.py) | Durable outer-artifact paths, loader/trust store, desktop integration |
| [dikte/trayicon.py](dikte/trayicon.py) | Deterministic PNG/ICO/iconset generation |
| [.github/workflows/build.yml](.github/workflows/build.yml) | Native build matrix and artifact collection |
| [.github/workflows/release.yml](.github/workflows/release.yml) | version decision, rolling/tagged releases, publication |
| [.github/workflows/tests.yml](.github/workflows/tests.yml) | cross-platform source tests and script parse checks |
| [scripts/release.sh](scripts/release.sh) | version commit and annotated tag creation |
| [README.windows.md](README.windows.md) | accurate Windows installation/signing disclosure |

## 26. Commands Used by the Project

Core commands, reproduced from current scripts:

```bash
python3 -m PyInstaller packaging/dikte.spec \
  --distpath build/dist --workpath build/work --noconfirm --clean

QT_QPA_PLATFORM=offscreen PYTHONPATH=. \
  python3 -m dikte.trayicon --hicolor build/icons

build/appimagetool --appimage-extract-and-run \
  build/AppDir dist/Dikte-<version>-<arch>.AppImage

QT_QPA_PLATFORM=offscreen PYTHONPATH=. \
  python3 -m dikte.trayicon build/Dikte.iconset
iconutil -c icns build/Dikte.iconset -o build/Dikte.icns
codesign --force --deep --sign - --identifier io.github.yusufipk.dikte \
  build/dist/Dikte.app
codesign --verify --deep build/dist/Dikte.app
hdiutil create -volname "Dikte <version>" -srcfolder build/stage \
  -ov -format UDZO -quiet dist/Dikte-<version>-<arch>.dmg

python -m unittest discover --verbose
./scripts/release.sh patch
gh release create <tag> downloads/* ...
```

Windows PowerShell/Inno invocation:

```powershell
python -m PyInstaller packaging\dikte.spec `
  --distpath build\dist --workpath build\work --noconfirm --clean

iscc /DVersion=<version> /DSource=<onedir> /DIcon=<ico> packaging\dikte.iss
```

These are descriptions of the current project, not guaranteed copy/paste commands
outside its tree.

## 27. Final Conclusions

### Direct answers to the required questions

1. **Windows packaging:** PyInstaller onedir, two launch executables, bundled
   checked ffmpeg, wrapped in per-user Inno Setup.
2. **Tool:** PyInstaller, not Nuitka.
3. **Why apparently chosen:** the commit/spec emphasize fast onedir startup,
   avoiding nested extraction, one shared cross-platform recipe, and mature
   collection. No explicit PyInstaller-versus-Nuitka decision record exists.
4. **onefile or onedir:** onedir (`COLLECT`).
5. **UPX:** no explicit use or disable; published-use status not verified.
6. **Windows EXE signed:** no.
7. **Windows installer signed:** no.
8. **Installer:** Inno Setup 6.
9. **Potential AV mitigations:** onedir, no unnecessary packers, stable metadata,
   trusted consistent signing, timestamps, transparent releases/checksums, and
   vendor false-positive submissions. Only the first three/public releases are
   partly present; signing/checksums/submission are not.
10. **Evidence strength:** no repository VirusTotal data proves detection impact.
11. **Nuitka alternative:** reasonable to benchmark on Windows/Linux; validate
    exact PyQt6/macOS support before making it the only cross-platform tool.
12. **Linux distribution:** source installer plus AppImage.
13. **AppImage:** yes.
14. **Creation:** PyInstaller onedir copied into manual AppDir, then appimagetool.
15. **DEB:** no.
16. **DEB creation:** not applicable/not implemented.
17. **Linux Qt dependencies:** AppImage bundles Python/PyQt6/Qt; checkout uses
    distro PyQt6. External desktop/audio/ffmpeg tools remain system dependencies.
18. **macOS `.app`:** PyInstaller `BUNDLE` in the release path.
19. **DMG:** yes, compressed UDZO via `hdiutil`.
20. **Apple signing:** ad-hoc only, no Developer ID.
21. **Notarization:** no.
22. **Qt plugins:** standard PyInstaller PyQt6 hooks; exact inventory unverified.
23. **Translations:** app strings are in Python; no explicit Qt translator.
24. **Icons/resources:** icons drawn at build/runtime; ffmpeg added after freeze;
    no Qt resource system.
25. **Actions:** source test workflow plus reusable four-entry native build matrix,
    called by rolling/tagged/manual release workflow.
26. **Secrets:** no repository secrets; only built-in `github.token`/`GH_TOKEN`.
27. **Reuse:** shared matrix workflow, PR builds, onedir-under-container, pinned
    helper checksums, old Linux base, host loader/trust-store repairs.
28. **Avoid copying:** unpinned tools, unchecked continuous appimagetool,
    unsigned releases, ad-hoc-only Mac distribution, exact Qt exclusion list,
    and self-integration without product need.
29. **Change today:** pin inputs, sign both Windows layers, Developer ID/notarize
    Mac, add native DEB, artifact smoke tests, checksums/SBOM/attestations.
30. **End-to-end architecture:** native locked builds, standalone payloads,
    platform-native outer packages and signatures, smoke tests, integrity
    metadata, then protected GitHub publication.

### Public primary-source cross-check

The [Dikte releases page](https://github.com/yusufipk/dikte/releases) shows the
current releases and repeats the repository's unsigned Windows/ad-hoc macOS user
warnings. No packaging-related public issue or PR evidence contradicted the
checked-in implementation. The relevant packaging history is also present in the
local git repository: commits `7e510f8` (AppImage/DMG), `4cec05f` (system CA
store), `23d56ac` (Windows setup), and `29643f2` (dual-EXE collision fix).

Overall classification: Dikte has a compact and unusually well-commented young
release pipeline with excellent project-specific runtime integration. It is a
valuable pattern for build topology and frozen Linux environment handling, but
not yet a model for professional signing, release integrity, native Debian
packaging, or artifact-level compatibility testing.
