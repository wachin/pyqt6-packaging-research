Both documents are written:
PACKAGING_STUDY.md — detailed evidence-based analysis of napari's packaging
PYQT6_PACKAGING_TUTORIAL.md — practical tutorial for your own PyQt6 projects
Summary
Most important discovery: napari does not use PyInstaller, Nuitka, or any freezer. It bundles the app as a conda environment using conda constructor, producing installers that ship a full Python+Qt runtime (~600 MB). The actual packaging logic lives in a separate repo (napari/packaging) — the main repo only holds a 19-line workflow that calls it, plus bundle assets (licenses, menu config, macOS welcome screen).
Windows: NSIS .exe (conda constructor), signed only on final releases via Azure Artifact Signing (SHA256 + RFC3161 timestamp); nightlies get a dummy Apple-cert signature (explicitly documented as not trusted by Windows).
Linux: .sh shell installer (no AppImage, no DEB — legacy Briefcase AppImage/DMG/MSI was removed in 2023).
macOS: .pkg signed with Developer ID Installer cert, _conda binary codesigned with Developer ID Application cert, notarized + stapled via notarytool (full pipeline at make_bundle_conda.yml:534-585).
Antivirus findings: no UPX, no obfuscation, no VirusTotal tracking; the only legitimate techniques are signing, transparent CI builds, and published SHA256 checksums. NAP-2 confirms PyInstaller/Nuitka/PyOxidizer were all tried and rejected (frozen executables break the plugin ecosystem).
GitHub Actions: tag-pushed releases → wheel build + PyPI (trusted publishing) + GitHub Release in napari/napari; a dynamic prepare_matrix builds 4 installer platforms (linux-64, win-64, osx-64, osx-arm64) on ubuntu-24.04/macos-15/macos-15-intel/windows-2025. Secrets: ANACONDA_TOKEN, APPLE_*_CERTIFICATE_*, APPLE_NOTARIZATION_*, TEMP_KEYCHAIN_PASSWORD, WINDOWS_SIGNING_* (Azure).
Top 5 techniques worth reusing: (1) QtPy binding abstraction, (2) importlib.resources for resource loading, (3) constraint files + lockfile artifacts for reproducibility, (4) GitHub Actions prepare_matrix pattern, (5) full macOS notarization sequence.
Unresolved questions: no evidence on how frozen-executable resource handling would behave (no sys._MEIPASS code exists); whether Azure signing materially reduces SmartScreen warnings (napari still signs only releases); Qt translation bundling is untested because the project has no i18n and never freezes.
