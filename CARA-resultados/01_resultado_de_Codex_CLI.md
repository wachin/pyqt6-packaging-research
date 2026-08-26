• Created the two requested reports:

  - PACKAGING_STUDY.md
  - PYQT6_PACKAGING_TUTORIAL.md

  Key discovery: CARA uses PyInstaller onedir bundles on all platforms—not Nuitka,
  AppImage, DEB, or Windows installers.

  - Windows: PyInstaller GUI onedir bundle with ICO, distributed as a portable ZIP.
    No tracked Authenticode signing, installer technology, PE version metadata, or
    signing automation.

  - Antivirus: onedir avoids onefile extraction, but CARA has no AV/VirusTotal
    evidence. Windows requests UPX, though Windows CI does not install it, so actual
    compression is unverified. The tutorial recommends legitimate mitigations only;
    no guarantees.

  - Linux: PyInstaller onedir bundle archived as .tar.gz for amd64 and arm64. Built
    on Ubuntu 22.04 deliberately for GLIBC compatibility. No AppImage or DEB.

  - Linux compatibility: excludes bundled libxkbcommon due to a documented Qt/xcb
    crash and contains targeted GNOME/KDE/GIO workarounds.

  - macOS: PyInstaller .app, then local Developer ID signing, hardened runtime,
    notarization, stapling, and ditto ZIP creation. No DMG.

  - GitHub Actions: manual artifact builds for Windows/macOS/Linux plus separate
    unit-test CI. No tag-triggered release publishing, signing secrets, checksums,
    SBOM, or attestations.

  - Top reusable techniques: onedir bundles, frozen resource resolver, platform
    user-data paths, old Linux GLIBC build baseline, macOS sign/notarize/staple
    workflow.

  - Unresolved: exact final Qt plugin inventory, actual Windows ZIP creation/signing
    outside tracked files, whether Windows UPX is actually applied, release
    checksum/provenance process, and real clean-machine cross-distribution testing.

─ Worked for 7m 03s ────────────────────────────────────────────────────────────────
