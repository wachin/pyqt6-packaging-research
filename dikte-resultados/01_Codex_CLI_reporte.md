• Created the two requested documents:

  - PACKAGING_STUDY.md
  - PYQT6_PACKAGING_TUTORIAL.md

  No existing project files were modified. All 1,212 source tests passed; release
  binaries were not executed.

  ## Concise findings

  - Most important discovery: Dikte uses one shared PyInstaller onedir payload
    across all three platforms, then wraps it in a platform-specific outer package.
    The runtime integration is thoughtful, but signing and release-integrity
    controls remain immature.

  - Windows: PyInstaller onedir creates Dikte.exe and dikte-cli.exe; a pinned,
    SHA256-verified FFmpeg is added; Inno Setup 6 creates a per-user installer. No
    portable ZIP is published.

  - Antivirus: No VirusTotal evidence or guaranteed mitigation exists. Useful
    present characteristics include onedir, no demonstrated UPX use, public source,
    and stable release distribution. Strong missing controls include Authenticode
    signing, timestamping, complete PE version metadata, published checksums, and
    vendor false-positive submission procedures.

  - Linux AppImage: PyInstaller onedir is copied into a manually assembled AppDir
    and converted with appimagetool. It does not use linuxdeploy or appimage-
    builder. CI deliberately builds on Ubuntu 22.04 for a more conservative GLIBC
    baseline.

  - Linux DEB: No .deb package exists. README apt commands install source
    dependencies; they do not install Dikte itself.

  - macOS: PyInstaller creates Dikte.app; FFmpeg is inserted; hdiutil creates Intel
    and Apple Silicon DMGs.

  - Signing/notarization: macOS uses only ad-hoc signing. Windows executables and
    installer are unsigned. There is no Developer ID signing, hardened runtime
    configuration, notarization, stapling, or signed DMG.

  - GitHub Actions: Separate test, reusable build-matrix, and release workflows
    cover Windows, Ubuntu, Intel macOS, and Apple Silicon macOS. Releases use the
    built-in github.token; no repository signing secrets are referenced.

  ## Top five techniques worth reusing

  1. PyInstaller onedir inside a single-file outer installer/container.
  2. A reusable native-runner build matrix with pull-request builds.
  3. Pinned, SHA256-verified external runtime tools.
  4. Building AppImages on an older supported Linux baseline.
  5. Restoring host loader paths and CA trust before invoking system programs.

  ## Important unresolved questions

  - The exact Qt libraries, plugins, and Qt translations present in published
    artifacts cannot be verified without inspecting a build artifact.

  - No explicit historical record explains why PyInstaller was chosen over Nuitka.
  - The actual antivirus detection history is undocumented.
  - Published artifacts are not smoke-tested in the visible workflows.
  - Reproducibility cannot be established because Python dependencies, PyInstaller,
    PyQt6, actions, and appimagetool are not fully pinned.

  - Current PyQt6 support under the exact Nuitka/macOS versions chosen for a future
    project requires a practical proof build.

─ Worked for 27m 51s ──────────────────────────────────
