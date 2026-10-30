
• Created the requested reports:

  - PACKAGING_STUDY.md:1 — evidence-based Pyzo case study with paths, line
    references, legacy findings, and unresolved items.

  - PYQT6_PACKAGING_TUTORIAL.md:1 — reusable Windows/AppImage/DEB/macOS/GitHub
    Actions guidance.

  Key findings:

  - Windows: PyInstaller --onedir --windowed; Win64 ships ZIP plus Inno Setup EXE,
    Win32 ZIP only.

  - Antivirus: no UPX policy, VirusTotal process, custom bootloader, or Windows
    Authenticode signing is tracked. Onedir is factual; lower detection is not
    proven.

  - Linux: PyInstaller directory bundle archived as ZIP/tar.gz, built on Ubuntu
    22.04. No AppImage and no .deb.

  - macOS: PyInstaller .app, then hardened-runtime timestamped signing, notarytool
    notarization, app stapling, ZIP/DMG packaging for Intel and Apple Silicon.

  - GitHub Actions: native platform build jobs, frozen-app smoke tests, tag-gated
    GitHub Release publication. No hashes, SBOM, lockfile, or provenance
    attestations.

  - Top reuse ideas: native CI builds, frozen-artifact tests, explicit Qt collection
    control, macOS notarization workflow, lower-baseline Linux builds.

  - Important unresolved questions: exact released Qt plugin/translation contents,
    whether Windows files are manually signed outside the repository, and exact
    Linux compatibility of released archives.

  git diff --check passes.

─ Worked for 6m 45s ──────────────────────
