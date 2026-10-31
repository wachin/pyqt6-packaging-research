# PYQT6-GENESIS-PACKAGING

Reader-facing copy of every packaging study in this repository, in one folder, so
that a person — or an AI agent — can be pointed here and find what they need
without knowing how the rest of the repository is arranged.

Point your agent at this folder and ask it to build installers. Do not start it in
the repository root; there is a lot of research infrastructure here that will only
distract it.

## What is in here

| Folder | Project | Why it is worth reading |
|---|---|---|
| `wachin-PyQt6-Apps/` | the owner's own two applications | **Start here.** The only projects here whose packaging was built, published and scanned by the person telling you about it, and the only ones packaged with VirusTotal in mind. |
| `external-PyQt6-Apps/` | six other projects | The fallback shelf: how other people solved the same problems. None of them was packaged for a clean scan, so read it for technique, not for the Windows recipe. |

### Inside `wachin-PyQt6-Apps/`

| Folder | Project | What it settles |
|---|---|---|
| `TBO-results/` | [wachin/TBO](https://github.com/wachin/TBO) | The only validated `.deb` in the research, and the only **controlled** Nuitka-vs-PyInstaller comparison: four build arms, four VirusTotal scores, published hashes. |
| `lucio-iva-calculator-results/` | [wachin/lucio-iva-calculator](https://github.com/wachin/lucio-iva-calculator) | The project that switched its Windows build to **Nuitka** because of antivirus results, and the only one that **verifies its frozen archive's contents** before publishing. Ships an **NSIS** installer. **This is the Windows reference.** |

### Inside `external-PyQt6-Apps/`

Six projects packaged by other people, studied the same way. They answer
"how did someone else solve this?", not "how do I pass VirusTotal?" — that
question is only answered by the two above.

| Folder | Project | Why it is worth reading |
|---|---|---|
| `dikte-results/` | [yusufipk/dikte](https://github.com/yusufipk/dikte) | A small PyQt6 app. The only implemented **AppImage** in the set. |
| `pyzo-results/` | [pyzo/pyzo](https://github.com/pyzo/pyzo) | A mature desktop app: onedir builds, **Inno Setup** on Windows, full macOS signing and notarization in CI. |
| `CARA-results/` | [pguntermann/CARA](https://github.com/pguntermann/CARA) | A real-world PyQt6 app with local macOS signing and notarization scripts. |
| `CustomKnight-Creator-results/` | [cmot17/CustomKnight-Creator](https://github.com/cmot17/CustomKnight-Creator) | The **negative example**: onefile, unsigned, no release automation. Useful to see what not to copy, and why. |
| `napari-results/` | [napari/napari](https://github.com/napari/napari) | A large scientific Python/Qt app that **rejected freezing** in favour of conda. Read it before assuming freezing is the only answer. |
| `napari-packaging-results/` | [napari/packaging](https://github.com/napari/packaging) | The most auditable installer pipeline in the set. **No licence is granted** for this one; read it, do not reuse it. |

## What is in each folder

Every project folder has the same three things:

| File | What it is |
|---|---|
| `PACKAGING_STUDY.md` | What that project actually does, read from its own files, with line-number citations and confidence labels. The *evidence* view. |
| `PYQT6_PACKAGING_TUTORIAL.md` | The same material turned into something you can act on. The *practical* view. |
| `_evidence/` | The real packaging files copied out of the project and **pinned to a commit**, so any claim can be checked without trusting the prose. |

Every folder also carries the raw first-level report that started the analysis:
`01_Codex_CLI_reporte.md` in `external-PyQt6-Apps/dikte-results/`,
`01_resultado_de_Codex_CLI.md` in `external-PyQt6-Apps/CARA-results/`, and the
Codex, opencode and DeepSeek equivalents in the other four.

## The artifacts

This folder is organised by *project*, not by artifact. If you are looking for how
to produce one specific thing, this is the map:

| Artifact | Look at |
|---|---|
| **AppImage** (Ubuntu, Debian) | `external-PyQt6-Apps/dikte-results/` — the only implemented one. `packaging/build-appimage.sh` in its `_evidence/`. |
| **.deb** (Ubuntu, Debian) | `wachin-PyQt6-Apps/TBO-results/` — the only validated one. `debian/` in its `_evidence/`. |
| **macOS portable .zip** (PyInstaller) | `external-PyQt6-Apps/pyzo-results/` and `.../CARA-results/` for the signed path; `wachin-PyQt6-Apps/lucio-iva-calculator-results/` for the plain unsigned `.zip`. |
| **Windows portable .zip** (Nuitka) | `wachin-PyQt6-Apps/TBO-results/` and `.../lucio-iva-calculator-results/` — both build the payload with Nuitka `--standalone`. |
| **Windows `setup.exe`** (NSIS) | `wachin-PyQt6-Apps/lucio-iva-calculator-results/` — `build/LucioIVACalculator.nsi` in its `_evidence/`. **The reference**, and the one measured clean. |
| **Windows `setup.exe`** (Inno Setup) | `external-PyQt6-Apps/pyzo-results/` — `freeze/installerBuilderScript.iss`, and `.../dikte-results/` — `packaging/dikte.iss`. Working, never measured against VirusTotal. |
| **Installer artwork** | `wachin-PyQt6-Apps/lucio-iva-calculator-results/` — `assets/nsis-header.bmp` (150x57), `assets/nsis-welcome.bmp` (164x314), `assets/app-icon.ico`. |

## Read this before believing any antivirus claim

Two measurements exist, and both are Windows-only:

| Build | VirusTotal |
|---|---|
| Nuitka standalone (TBO) | **0 / 71** |
| PyInstaller onedir (TBO) | **3 / 73** |
| PyInstaller onefile (TBO) | **3 / 73** |
| PyInstaller onefile, bootloader rebuilt from source (TBO) | **2 / 70** |
| Nuitka NSIS installer + portable ZIP (Lucio, self-reported) | **0 / 68**, **0 / 65** |

That is **two applications**, one of them self-reported, on one platform. It is a
consistent direction and it is not a guarantee. The detections in the PyInstaller
arms were generic or behavioural (`Malicious` with no family, `BehavesLike.…`), and
every major engine reported clean — the shape of a heuristic false positive.

What follows from it: prefer Nuitka on Windows, which is what both applications
here do. Do not promise anyone a clean scan, do not generalise to other
applications, and never respond to a false positive with obfuscation, packing or
binary mutation — report it to the vendor.

## One copy, two groups

The six folders under `external-PyQt6-Apps/` exist only here. Their original
Spanish-named source folders were removed so the repository would not carry the
same bytes twice, and the English-named copy is now the only one. There is nothing
to reconcile and nothing to regenerate them from.

The two folders under `wachin-PyQt6-Apps/` are still maintained as a source
plus a mirror: the source lives at the repository root, at
`my-PyQt6-Apps/<app>-resultados/`, and `tools/check_genesis_pack.py` checks
that this copy matches it.

If you received this folder on its own, you have everything needed to build: the
studies are self-contained and the evidence is beside them.

## Licence

The studies and tutorials here are **GPL-3.0-or-later**, like the rest of this
repository — see `LICENSE` at the repository root. The `_evidence/` files are
verbatim copies from the projects listed above and stay under **their own**
licences: GPL for dikte, CARA, CustomKnight-Creator, TBO and Lucio; BSD for pyzo and
napari; and `napari/packaging` grants no licence at all.

The practical consequence: the tutorials contain code, so copying a snippet into
your project brings your project under the GPL. Reading a procedure and
implementing it yourself does not.
