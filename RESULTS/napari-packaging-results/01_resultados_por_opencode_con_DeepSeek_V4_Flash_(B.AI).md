Investigation complete. Two documents created: PACKAGING_STUDY.md (931 lines) and PYQT6_PACKAGING_TUTORIAL.md (1121 lines).
Summary
Most important discovery: This is not a PyInstaller/Nuitka project at all. napari/packaging builds installers with conda constructor (NSIS .exe on Windows, .pkg on macOS, .sh on Linux) from conda packages, and bundles PySide6 (via QtPy; PyQt6 is supported but never bundled). NAP-2 documents that napari tried and rejected Nuitka and PyOxidizer because frozen binaries can't support runtime plugin installs.
Windows: conda/constructor NSIS installer; two signing mechanisms — a stopgap Apple-cert PFX (acknowledged untrusted, make_bundle_conda.yml:470-472) plus proper Azure Code Signing with NumFOCUS certs on final tags only, with signature verification + SHA256.
Antivirus: No AV/VirusTotal evidence exists in this repo. Only verifiable signal is that untrusted signatures keep SmartScreen warnings. I explicitly did not claim any magic solution.
Linux: No AppImage, no .deb. A self-extracting conda .sh installer (~637 MB) installed under ~/.local/napari-<ver>.
macOS: No .app/DMG. Signed (Developer ID Installer + Application certs) and notarized PKG via notarytool with App Store Connect API key, stapled, spctl-verified in CI.
GitHub Actions: 3 jobs — packages (Ubuntu builds conda pkgs via feedstock clone), prepare_matrix, installers (4-platform matrix). Called from napari/napari via workflow_call with secrets: inherit; signs/uploads only on tag pushes.
Top 5 techniques worth reusing:
1. Gated signing by event type + secret availability (don't burn cert quota on PRs)
2. Install-and-smoke-test the actual artifact in CI (headless launch + shortcut check)
3. Full modern macOS notarization sequence (notarytool + API key, stapler, spctl)
4. Post-build signature verification that fails the job + SHA256 generation
5. SHA-pinned actions, zizmor linting, least-privilege permissions
Key unresolved questions: whether Azure-signed v0.9.0 .exe still triggers SmartScreen; actual VirusTotal rates (unverifiable from repo); whether inner vs installer signing matters for their conda pipeline; and conda-standalone's own PyInstaller origin as an AV factor.
