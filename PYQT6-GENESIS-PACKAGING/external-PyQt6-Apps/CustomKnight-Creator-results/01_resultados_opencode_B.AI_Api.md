Investigation complete. Both documents created (existing project files untouched):
- PACKAGING_STUDY.md — evidence-based study of the repository
- PYQT6_PACKAGING_TUTORIAL.md — practical tutorial for your own PyQt6 apps
Summary
Most important discovery: This is a study of minimum viable packaging, not professional distribution. It proves a working cross-platform build is easy (PyInstaller + one matrix workflow) and that everything "professional" is missing.
Windows: PyInstaller 5.1 onefile (-F -w), unsigned, zipped exe on GitHub Releases. No installer, no metadata, no signing.
Antivirus findings: Zero mitigation in the repo — no signing, no UPX policy (UPX absent on CI runners by accident, not choice), no checksums. It's a textbook case of the problem (unsigned onefile PyInstaller). No evidence supports a "magic solution"; signing + onedir + current tools + Nuitka-as-fallback is the legitimate stack, and 0 detections can't be guaranteed.
Linux AppImage: Not implemented. Artifact is a bare zipped ELF built on ubuntu-latest (glibc risk); a real Wayland-plugin crash was reported (issue #13).
Linux DEB: Not implemented — no debian/ directory anywhere.
macOS: PyInstaller .app zipped with zip -r9; no DMG, no codesign, no notarization. Releases contain separate x64/ARM64 zips whose production mechanism isn't in the repo.
Signing/notarization: None on any platform; no signtool, codesign, or notarytool anywhere; no secrets used.
GitHub Actions: package.yml — manual workflow_dispatch trigger, 3-OS matrix with per-entry CMD_BUILD, Python 3.10.5, uploads artifacts only (release created manually). No secrets, no caching, no release step.
Top 5 techniques worth reusing:
1. Clean 3-OS matrix with per-entry build commands + artifact path
2. --add-data resources:resources + __file__-relative resource loading (works frozen)
3. Platform-specific icons (.icns/.ico)
4. Exact == pins in requirements.txt
5. Git history as documentation of CI evolution (push→manual trigger; abandoned PySide6/universal2 experiments)
Important unresolved questions:
- How the released macOS x64+ARM64 zips were produced (workflow builds one arch; split logic undocumented)
- Why -w is omitted on Linux (undocumented; likely console output for a technical audience)
- Whether the author used Nuitka anywhere — no (repo uses PyInstaller exclusively)
- The abandoned cleanup branch (PySide6 + PyInstaller 6.x + universal2) was never validated in a release
Notable caveats: main is frozen at mid-2022 versions (PyQt6 6.3.1, PyInstaller 5.1, Python 3.10.5); a broken :/main/SheoIcon.ico Qt-resource reference means the window icon silently never shows.
