# EVIDENCE INDEX

Snapshot of the real packaging files behind each case study, copied next to the studies that cite them so that a reference such as `packaging/build-appimage.sh#L41-L49` can be resolved immediately.

**Do not edit the extracted files.** They are read-only evidence pinned to the commits below. Regenerate the whole pack with:

```bash
python3 tools/extract_evidence.py
```

## Projects

| Project | Source tree | Commit | Licence | Evidence | Files | Purpose |
|---|---|---|---|---|---|---|
| dikte - voice-dictation tray app | `dikte` | `3663c7fd5756` | GPL | `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/dikte-results/_evidence/` | 19 | Only implemented AppImage in the case set; onedir payload wrapped in Inno/DMG/AppImage. |
| CARA - chess analysis app | `CARA` | `6c9164c6616c` | GPL | `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/CARA-results/_evidence/` | 13 | Full macOS Developer ID signing + notarization from a local script; three separate platform specs. |
| pyzo - scientific Python IDE | `pyzo` | `7f9679625c8b` | BSD | `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/pyzo-results/_evidence/` | 17 | Mature onedir + Inno/DMG/ZIP wrappers; full macOS signing and notarization in CI; the only project that curates Qt modules explicitly. |
| CustomKnight-Creator - Hollow Knight mod tool | `CustomKnight-Creator` | `158ec2f259cb` | GPL | `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/CustomKnight-Creator-results/_evidence/` | 3 | The negative example: onefile on all platforms, ubuntu-latest GLIBC, no signing, no release automation. |
| napari - scientific image viewer | `napari` | `908b3ed80ccb` | BSD | `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/napari-results/_evidence/` | 14 | Freezing rejected in favour of conda constructor; delegates all packaging to napari/packaging. |
| napari/packaging - dedicated packaging + installer infrastructure | `napari-packaging` | `5befa97fdd90` | NO LICENCE FILE FOUND | `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/napari-packaging-results/_evidence/` | 12 | The most auditable installer pipeline in the set: conda constructor + NSIS/pkg, SHA-pinned actions, artifact smoke test. NO LICENCE FILE - evidence only, do not reuse. |
| Lucio IVA Calculator - own PyQt6 app (Nuitka on Windows, PyInstaller elsewhere) | `my-PyQt6-Apps/lucio-iva-calculator` | `4db15fa99622` | GPL | `PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/lucio-iva-calculator-results/_evidence/` | 17 | One of the owner's own applications, pinned as a sub-module. The only project in the set whose Windows freezer was changed from PyInstaller to Nuitka on the strength of antivirus results, and the only one that verifies its Linux onefile archive's contents before publishing. Recorded VirusTotal figures are 0/68 for the installer and 0/65 for the portable ZIP at 0.1.1; PACKAGING_STUDY.md section 6 states exactly what that record does and does not establish, and now also carries the 2026-10-31 installer-wrapper experiment recorded in INSTALLER_WRAPPER_EXPERIMENT.md. |
| TBO - own PyQt6 app (Nuitka on Windows, PyInstaller on macOS/Linux) | `my-PyQt6-Apps/TBO` | `797011a584ff` | GPL | `PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/TBO-results/_evidence/` | 25 | Not a case study in the same sense: this is the owner's own application, pinned as a sub-module like the rest. It is the only source of validated .deb evidence and the only project here with a Flatpak manifest and a controlled freezer measurement. The fix log lives in 03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md; the packaging study is the one in this folder. |

## How to read an evidence pack

Each `<results>/_evidence/` directory mirrors the original repository layout and contains:

```text
_evidence/
├── PROVENANCE.md   upstream URL, exact commit, licence, per-file rationale
├── SHA256SUMS      integrity check for every extracted file
└── <original/relative/paths...>
```

Line numbers quoted in the studies refer to the file at the pinned commit recorded in `PROVENANCE.md`, not to the current upstream `main`.

## Licence warning

The extracted files keep their upstream licence. **CARA, CustomKnight-Creator, dikte, TBO and lucio-iva-calculator are GPL**; napari and pyzo are BSD; `napari/packaging` has **no licence file**. Studying and quoting is one thing; copying GPL packaging code into your own application is another. Check before reuse.

## Totals

- Projects: 8
- Files: 120
- Total size: 876,785 bytes
- Generated: 2026-10-30
