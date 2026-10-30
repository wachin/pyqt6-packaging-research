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
| `wachin-PyQt6-Apps/` | the owner's own two applications | **Start here.** These are the only projects here whose packaging was built, published and scanned by the person telling you about it. |
| `dikte-results/` | [yusufipk/dikte](https://github.com/yusufipk/dikte) | A small PyQt6 app. The only implemented **AppImage** in the set. |
| `pyzo-results/` | [pyzo/pyzo](https://github.com/pyzo/pyzo) | A mature desktop app: onedir builds, **Inno Setup** on Windows, full macOS signing and notarization in CI. |
| `CARA-results/` | [pguntermann/CARA](https://github.com/pguntermann/CARA) | A real-world PyQt6 app with local macOS signing and notarization scripts. |
| `CustomKnight-Creator-results/` | [cmot17/CustomKnight-Creator](https://github.com/cmot17/CustomKnight-Creator) | The **negative example**: onefile, unsigned, no release automation. Useful to see what not to copy, and why. |
| `napari-results/` | [napari/napari](https://github.com/napari/napari) | A large scientific Python/Qt app that **rejected freezing** in favour of conda. Read it before assuming freezing is the only answer. |
| `napari-packaging-results/` | [napari/packaging](https://github.com/napari/packaging) | The most auditable installer pipeline in the set. **No licence is granted** for this one; read it, do not reuse it. |

### Inside `wachin-PyQt6-Apps/`

| Folder | Project | What it settles |
|---|---|---|
| `TBO-results/` | [wachin/TBO](https://github.com/wachin/TBO) | The only validated `.deb` in the research, and the only **controlled** Nuitka-vs-PyInstaller comparison: four build arms, four VirusTotal scores, published hashes. |
| `lucio-iva-calculator-results/` | [wachin/lucio-iva-calculator](https://github.com/wachin/lucio-iva-calculator) | The project that switched its Windows build to **Nuitka** because of antivirus results, and the only one that **verifies its frozen archive's contents** before publishing. Ships an **NSIS** installer. |

## What is in each folder

Every project folder has the same three things:

| File | What it is |
|---|---|
| `PACKAGING_STUDY.md` | What that project actually does, read from its own files, with line-number citations and confidence labels. The *evidence* view. |
| `PYQT6_PACKAGING_TUTORIAL.md` | The same material turned into something you can act on. The *practical* view. |
| `_evidence/` | The real packaging files copied out of the project and **pinned to a commit**, so any claim can be checked without trusting the prose. |

Two folders also carry the raw first-level report that started the analysis
(`01_Codex_CLI_reporte.md` in `dikte-results/`). CARA's equivalent is not copied
here, which is the only known difference from the repository's canonical packs.

## The five artifacts

This folder is organised by *project*, not by artifact. If you are looking for how
to produce one specific thing, this is the map:

| Artifact | Look at |
|---|---|
| **AppImage** (Ubuntu, Debian) | `dikte-results/` — the only implemented one. `/packaging/build-appimage.sh` in its `_evidence/`. |
| **`.deb`** (Ubuntu, Debian) | `wachin-PyQt6-Apps/TBO-results/` — the only validated one. `debian/` in its `_evidence/`. |
| **macOS portable `.zip`** (PyInstaller) | `pyzo-results/` and `CARA-results/` for the signed path; `wachin-PyQt6-Apps/lucio-iva-calculator-results/` for the plain unsigned `.zip`. |
| **Windows portable `.zip`** (Nuitka) | `wachin-PyQt6-Apps/TBO-results/` and `.../lucio-iva-calculator-results/` — both build the payload with Nuitka `--standalone`. |
| **Windows `setup.exe`** (NSIS) | `wachin-PyQt6-Apps/lucio-iva-calculator-results/` — `build/LucioIVACalculator.nsi` in its `_evidence/`. |
| **Windows `setup.exe`** (Inno Setup) | `pyzo-results/` — `freeze/installerBuilderScript.iss`, and `dikte-results/` — `packaging/dikte.iss`. |

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

## The canonical packs are elsewhere

These folders are a **copy** with the directory names translated
(`-resultados` → `-results`). The originals, and the citations that resolve against
them, live at the repository root:

```text
<project>-resultados/                       # canonical, what the Skills cite
my-PyQt6-Apps/<app>-resultados/
```

If you are reading this folder inside the research repository, both exist and the
copies are checked against the originals by
`tools/check_genesis_pack.py`. If you received this folder on its own, you have
everything needed to build: the studies are self-contained and the evidence is
beside them.

## Licence

The studies and tutorials here are **GPL-3.0-or-later**, like the rest of this
repository — see `LICENSE` at the repository root. The `_evidence/` files are
verbatim copies from the projects listed above and stay under **their own**
licences: GPL for dikte, CARA, CustomKnight-Creator, TBO and Lucio; BSD for pyzo and
napari; and `napari/packaging` grants no licence at all.

The practical consequence: the tutorials contain code, so copying a snippet into
your project brings your project under the GPL. Reading a procedure and
implementing it yourself does not.
