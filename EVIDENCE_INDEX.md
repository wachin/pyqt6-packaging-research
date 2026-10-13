# EVIDENCE INDEX

Snapshot of the real packaging files behind each case study, copied next to the studies that cite them so that a reference such as `packaging/build-appimage.sh#L41-L49` can be resolved immediately.

**Do not edit the extracted files.** They are read-only evidence pinned to the commits below. Regenerate the whole pack with:

```bash
python3 tools/extract_evidence.py
```

## Projects

| Project | Source tree | Commit | Licence | Evidence | Files | Purpose |
|---|---|---|---|---|---|---|
| dikte - voice-dictation tray app | `dikte` | `3663c7fd5756` | GPL | `dikte-resultados/_evidence/` | 19 | Only implemented AppImage in the case set; onedir payload wrapped in Inno/DMG/AppImage. |
| CARA - chess analysis app | `CARA` | `6c9164c6616c` | GPL | `CARA-resultados/_evidence/` | 13 | Full macOS Developer ID signing + notarization from a local script; three separate platform specs. |
| pyzo - scientific Python IDE | `pyzo` | `7f9679625c8b` | BSD | `pyzo-resultados/_evidence/` | 17 | Mature onedir + Inno/DMG/ZIP wrappers; full macOS signing and notarization in CI; the only project that curates Qt modules explicitly. |
| CustomKnight-Creator - Hollow Knight mod tool | `CustomKnight-Creator` | `158ec2f259cb` | GPL | `CustomKnight-Creator-resultados/_evidence/` | 3 | The negative example: onefile on all platforms, ubuntu-latest GLIBC, no signing, no release automation. |
| napari - scientific image viewer | `napari` | `908b3ed80ccb` | BSD | `napari-resultados/_evidence/` | 14 | Freezing rejected in favour of conda constructor; delegates all packaging to napari/packaging. |
| napari/packaging - dedicated packaging + installer infrastructure | `napari-packaging` | `5befa97fdd90` | NO LICENCE FILE FOUND | `napari-packaging-resultados/_evidence/` | 12 | The most auditable installer pipeline in the set: conda constructor + NSIS/pkg, SHA-pinned actions, artifact smoke test. NO LICENCE FILE - evidence only, do not reuse. |
| TBO - own PyQt6 app (Nuitka on Windows, PyInstaller on macOS/Linux) | `PyQt6-Apps/TBO` *(independent clone)* | `0cdac5fd19a4` | GPL | `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/_evidence/` | 23 | Not a case study: this is the owner's own application, kept as an independent clone rather than a sub-module, and the only source of validated .deb evidence, plus a Flatpak manifest. Findings recorded in SOLUCIONES-TBO.md and DEBIAN-PACKAGE-AUDIT.md in this same folder. |

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

The extracted files keep their upstream licence. **CARA, CustomKnight-Creator, dikte and TBO are GPL**; napari and pyzo are BSD; `napari/packaging` has **no licence file**. Studying and quoting is one thing; copying GPL packaging code into your own application is another. Check before reuse.

## Totals

- Projects: 7
- Files: 101
- Total size: 739,094 bytes
- Generated: 2026-10-13
