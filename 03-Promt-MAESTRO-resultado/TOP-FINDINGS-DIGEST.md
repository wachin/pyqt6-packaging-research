```
Three new documents created in /home/wachin/Dev3/pyqt6-packaging-research/ (original studies untouched):


1. Strongest technique: PyInstaller onedir as a transparent, container-ready payload built natively per OS (CARA, dikte, pyzo independently; [REPEATED + STRONG]).
2. Strongest Windows strategy: onedir → PE metadata → sign inner EXEs → signed Inno Setup per-user installer → verify → SHA256. Only napari actually signs Windows (Azure, final tags); the rest is recommended.
3. PyInstaller vs Nuitka: no winner — 4/5 use PyInstaller, 0 use Nuitka; Nuitka's AV advantage is anecdote only, plus a macOS PyQt6 history caveat. Start PyInstaller onedir, benchmark with the controlled experiment.
4. Antivirus reality: zero measurements exist anywhere. Only supported facts: untrusted/absent Windows signatures keep SmartScreen warnings (napari's own comment), and signing is the intended trust mechanism. No claims about onedir/UPX/Nuitka detection rates are supported.
5. AppImage: only dikte implements one (manual AppDir + appimagetool, Ubuntu 22.04). linuxdeploy is unverified recommendation.
6. DEB: no project ships one; native-deps vs bundled-runtime is a genuine tutorial disagreement — both are legitimate tradeoffs, nothing verified.
7. macOS: .app → Developer ID + hardened runtime → notarytool → staple → spctl → DMG; implemented by CARA, pyzo, napari (napari most auditable, in CI).
8. Signing: macOS full in 3/5; Windows real only in napari (managed cloud signing, quota-gated); recommended sequence defined, OBSERVED vs RECOMMENDED kept separate.
9. GitHub Actions: napari's shape (workflow_call + prepare_matrix + gated signing + artifact smoke tests + SHA-pinned actions + zizmor) combined with dikte's PR-builds and pyzo's --verify-tag release.
10. Five most reusable: onedir-under-container; central resource resolver + platform user-data; old-GLIBC Linux base; macOS sign/notarize/staple in CI; native matrix CI with artifact smoke tests and tag-gated release.
11. Five things NOT to copy: unsigned onefile Windows; conda/constructor for a plain app; Apple-cert-for-Windows signing; unpinned/floating release deps; calling tar.gz/zip "AppImage" or ad-hoc signing "production macOS".
12. Biggest unresolved: actual AV/SmartScreen behavior of signed PyInstaller vs Nuitka artifacts; exact Qt plugin/translation inventories; correct DEB model; notarized-DMG flow.
13. Experiments before finalizing: the §31 four-arm PyInstaller/Nuitka × onedir/onefile comparison over several releases; cross-distro AppImage/GLIBC matrix; artifact smoke-test suite; signed-vs-unsigned VirusTotal; a Nuitka-macOS-PyQt6 proof build.
```
