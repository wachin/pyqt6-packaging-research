# Packaging Study: CustomKnight Creator

> Personal technical study of the packaging, building, testing, and distribution infrastructure of the **CustomKnight Creator** repository (github.com/cmot17/CustomKnight-Creator).
>
> This document is a deep technical investigation intended for educational purposes: to learn how a small, real, open-source PyQt6 project packages and distributes its application, and to extract reusable lessons for other PyQt6 projects.
>
> Method: Static inspection of the repository (working tree + full git history + all branches), plus inspection of the public GitHub repository metadata, releases, and issue tracker. No release binaries were executed. No credentials are reproduced.

---

## 1. Executive Summary

CustomKnight Creator is a **small, single-developer, hobbyist open-source PyQt6 desktop application** for managing Hollow Knight skin sprites. Its distribution strategy is the absolute minimum viable one:

- **One packaging tool**: PyInstaller (onefile mode `-F`).
- **Three platforms**: built on GitHub Actions with a simple OS matrix (`windows-latest`, `ubuntu-latest`, `macos-latest`).
- **Artifacts**: raw PyInstaller outputs wrapped in ZIP files and attached **manually** to GitHub Releases.
- **No code signing anywhere** (neither Windows Authenticode nor macOS codesign/notarization).
- **No installers** (no NSIS/Inno/WiX/MSI on Windows).
- **No AppImage, no `.deb`, no DMG**.
- **No antivirus/VirusTotal management**, no UPX policy, no executable metadata beyond what PyInstaller provides by default.
- **No release automation**: the workflow only uploads build artifacts; the GitHub Release itself is created manually by the developer.

The most important finding for a developer studying PyQt6 distribution is therefore **not** what this project does well, but **everything a professional distribution pipeline needs that this project does not have**. The project is nevertheless valuable as a case study because:

1. It demonstrates the *minimum viable* PyInstaller + GitHub Actions cross-platform build, with a clear evolution of the workflow visible in git history.
2. It shows exactly how a `.spec`-free, one-line-command packaging approach behaves (including its limitations).
3. Its issue tracker documents real-world user problems that are directly attributable to packaging choices (onefile extraction failures, platform plugin problems on Linux, and macOS startup issues) — these are teaching material.
4. An abandoned `cleanup` branch documents a PyQt6 → PySide6 migration attempt and PyInstaller 6.x + universal2 macOS experiments that were never released — showing both what was tried and what was reverted.

**Bottom line**: This is a case study of "packaging as an afterthought." It works for a small modding tool distributed to a technically-literate niche audience. It is NOT a model to copy for professional distribution of a general-audience PyQt6 application.

---

## 2. Project Architecture

| Aspect | Finding | Evidence |
|---|---|---|
| Project name | CustomKnight Creator | `readme.md:1` |
| Main purpose | Track, deduplicate, and pack sprites for the Hollow Knight mod "CustomKnight" | `readme.md:5` |
| Programming language | Python (100% Python, plus Qt Designer `.ui` files) | GitHub API `language: Python` |
| Python version | 3.10 (README), pinned to `3.10.5` in current workflow | `readme.md:21`, `.github/workflows/package.yml:34` |
| Qt binding | **PyQt6** (main branch) | `requirements.txt:2`, `main.py:6` |
| Qt version | Qt 6.3.1 (bundled inside the `PyQt6==6.3.1` wheel) | `requirements.txt:2` |
| Qt abstraction | None (direct PyQt6 imports) | `main.py:6-7` |
| Supported OS | Windows, Linux, macOS (all built on GitHub Actions) | `.github/workflows/package.yml:12-28` |
| Entry point | `main.py` (module-level `QApplication` + `exec()`) | `main.py:448-452` |
| Project structure | Flat, single directory: 6 `.py` files + 2 `.ui` + `resources/` + docs | repo root listing |
| Dependency management | `requirements.txt` with exact pins (`==`) | `requirements.txt:1-3` |
| Build system | None (no `pyproject.toml`, `setup.py`, `Makefile`, `tox.ini`, `noxfile.py`) | repo listing |
| Packaging system | PyInstaller, invoked directly via CLI flags (no committed `.spec` on main) | `readme.md:26-41`, workflow |
| Release system | GitHub Releases, attached manually; workflow only uploads CI artifacts | releases API data |

### Repository contents (current `main`)

```
CustomKnight-Creator/
├── .github/workflows/package.yml   # the ONLY CI file
├── docs/readme_example.png
├── duplicatewizard.ui              # Qt Designer dialog UI (XML)
├── duplicatewizard_ui.py           # pyuic6-generated Python for the dialog
├── finddupes.py                    # dev-only tool that generated duplicatedata.json
├── LICENSE.md                      # GNU GPLv3
├── main.py                         # entry point + all window logic (452 lines)
├── readme.md
├── requirements.txt                # Pillow, PyQt6, pyinstaller (exact pins)
├── resources/                      # bundled data (icons, JSON)
│   ├── checkicon.png
│   ├── duplicatedata.json          # 281 KB precomputed duplicate map
│   ├── SheoIcon.icns               # macOS icon (480 KB)
│   ├── SheoIcon.ico                # Windows icon
│   ├── SheoIcon.png
│   └── xicon.png
├── spritehandler.py                # core logic (323 lines)
├── spritepacker.ui                 # Qt Designer main window UI (XML)
└── spritepacker_ui.py              # pyuic6-generated Python for main window
```

Note: `.gitignore` excludes `build/`, `dist/`, `venv`, `__pycache__` — the PyInstaller output dirs are never committed.

### Git history / branches (packaging-relevant)

- `main` / `origin/main` — frozen at commit `158ec2f` (2022-06-26). PyInstaller 5.1 + PyQt6 6.3.1 + Python 3.10.5.
- `origin/ci-testing` — 2022 experiments: `--target-arch universal2` for macOS builds (commits `3fffa9d`, `6d8b891`, 2022-06-25), never merged.
- `origin/cleanup` — 2024 experiments (commits `855b55a` … `625d930`, 2024-10-28): **switched to PySide6 6.8.0**, PyInstaller 6.11.0, Pillow 11.0.0, Python 3.12/3.13, `--no-binary :all: --compile` installs for macOS, split install steps per-OS, a `CustomKnight Creator.spec` file and a `resources.qrc` + generated `resources_rc.py`. Never merged (abandoned).

These branches are **legacy / unused infrastructure** — none of them was ever released.

---

## 3. Packaging Overview

### Actual packaging map

```text
Source code (main.py, spritehandler.py, _ui.py, resources/)
    │
    ├── GitHub Actions workflow (package.yml), matrix:
    │
    ├── Windows (windows-latest)
    │     └── PyInstaller --onefile --windowed
    │         └── "CustomKnight Creator.exe"  (uploaded as artifact, zipped manually into release)
    │
    ├── Linux (ubuntu-latest)
    │     └── PyInstaller --onefile (console kept)
    │         └── "CustomKnight Creator"  (ELF binary, uploaded as artifact, zipped manually)
    │
    └── macOS (macos-latest)
          └── PyInstaller --onefile --windowed (creates .app bundle)
              └── zip -r9 "CustomKnight Creator.app/"
                  └── "CustomKnight Creator.zip"  (uploaded as artifact)
```

### The one packaging mechanism that ACTUALLY exists

Everything is PyInstaller. The exact commands (from `readme.md:28-41` and the workflow):

```text
macOS:  pyinstaller main.py -F -w -n "CustomKnight Creator" -i resources/SheoIcon.icns --add-data resources:resources
Windows:pyinstaller main.py -F -w -n "CustomKnight Creator" -i resources/SheoIcon.ico --add-data "resources;resources"
Linux:  pyinstaller main.py -F -n "CustomKnight Creator" --add-data "resources:resources"
```

Flag meaning (PyInstaller 5.1 semantics):

| Flag | Meaning | Notes |
|---|---|---|
| `-F` / `--onefile` | single self-extracting executable | every run extracts to a temp dir (`_MEIPASS`) |
| `-w` / `--windowed` | suppress console | used on Windows + macOS; **deliberately NOT used on Linux** (see below) |
| `-n "CustomKnight Creator"` | output name | name with spaces (works, but see caveats) |
| `-i resources/SheoIcon.icns/.ico` | bundle as app/exe icon | Windows needs `.ico`, macOS uses `.icns`; Linux has **no icon flag** (PyInstaller doesn't support `-i` on Linux) |
| `--add-data resources:resources` | bundle the resources dir into the archive | separator is `;` on Windows, `:` on POSIX |

**Why onefile was chosen**: This is the classic "share a single file with a Discord community / upload one attachment to GitHub" use case. The author distributes to Hollow Knight modders via GitHub Releases; a onefile executable is trivially downloadable, and the README/tutorial flow is "download the exe, run it." There is no evidence in the repository that startup time, antivirus reputation, or extraction issues were weighed against onefile. It is the default choice for this style of small tool.

**Why `-w` is omitted on Linux**: Not documented explicitly. Most plausible reasons: (a) PyInstaller's windowed mode on Linux historically caused issues with no window manager; (b) the author wants console output / tracebacks visible for a tool used by a technical audience; (c) `-i` (icon) is unsupported on Linux anyway, so the "GUI polish" flags were simply skipped for Linux. From the evidence available, (b)/(c) are the most consistent explanations. Not verified from the repository.

### What is NOT present (complete list, all verified absent from the repo)

- No `.spec` file on `main` (one existed historically and was deleted in commit `ed32f0d`, 2021-11-16).
- No PyInstaller hooks, runtime hooks, hidden imports, or `excludes` anywhere.
- No `sys._MEIPASS` usage (resources are located via `os.path.dirname(__file__)` — see §17).
- No Nuitka, cx_Freeze, Briefcase, py2app, or any other packager.
- No UPX configuration (PyInstaller's default behavior applies — see §7).
- No AppImage / appimage-builder / linuxdeploy / AppDir.
- No Debian/`deb` packaging (`debian/` directory, `dpkg`, `fpm` — none).
- No NSIS / Inno Setup / WiX / MSI / MSIX.
- No DMG tooling.
- No code signing anywhere (no `signtool`, no `codesign`, no `xcrun notarytool`, no certificates in repo).
- No `.docker` / Dockerfiles.
- No `pyproject.toml`, `setup.py`, `setup.cfg`, `tox.ini`, `noxfile.py`, `Makefile`.
- No `CONTRIBUTING.md`, no CI test step, no linter in CI.
- No checksums/SHA256 files in releases; release `digest` fields are null in the GitHub API.
- No SBOM, no SLSA, no dependency scanning, no attestations.

---

## 4. Windows

### How Windows builds happen

`.github/workflows/package.yml` (current `main`, lines 19-23):

```yaml
- os: windows-latest
  TARGET: windows
  CMD_BUILD: >
    pyinstaller main.py -F -w -n "CustomKnight Creator" -i resources/SheoIcon.ico --add-data "resources;resources"
  OUT_FILE_PATH: "dist/CustomKnight Creator.exe"
```

Full pipeline per release (from workflow + release assets):

```text
push to main (originally) / manual workflow_dispatch (current)
    ↓
windows-latest runner, Python 3.10.5 (setup-python@v4)
    ↓
pip install -r requirements.txt  (Pillow==9.1.1, PyQt6==6.3.1, pyinstaller==5.1)
    ↓
pyinstaller main.py -F -w -n "CustomKnight Creator" -i resources/SheoIcon.ico --add-data "resources;resources"
    ↓
dist/CustomKnight Creator.exe   (single-file onefile executable)
    ↓
actions/upload-artifact@v3.1.0  →  artifact named "windows"
    ↓
(developer manually downloads artifact, zips as "CustomKnight.Creator.Windows.x64.zip", attaches to GitHub Release)
```

### Observed artifact

- Release asset `CustomKnight.Creator.Windows.x64.zip` ≈ **30.4 MB** (v1.0.2), downloaded **16,754** times. This is the project's dominant platform.
- The asset name contains "x64" but there is no explicit x64 targeting in the workflow — it is just whatever architecture the `windows-latest` runner happens to be (x64), and the "x64" label is only in the manually-chosen filename.

### Observations / weaknesses (Windows)

1. **The executable is unsigned.** No Authenticode signature, no publisher name, no timestamping. This means: SmartScreen shows "Unknown publisher", Windows Defender SmartScreen warns, and antivirus engines have no certificate reputation to lean on. Combined with PyInstaller onefile (which is structurally similar to a packer), this is exactly the recipe for false positives the user asked about.
2. **No installer.** Users download a ZIP, extract, and run the exe. There is no Start Menu shortcut, no uninstaller, no file association.
3. **Name with spaces** (`CustomKnight Creator.exe`): works, but is a recurring source of quoting bugs in scripts and is discouraged.
4. **No version metadata.** PyInstaller embeds a generic version resource. There is no custom `--version-file`, so the PE's FileVersion/ProductVersion are PyInstaller defaults — no reliable version fingerprint for AV vendors or users.
5. **No manifest / UAC configuration** beyond PyInstaller's default (which requests `asInvoker`).

---

## 5. PyInstaller

### How it is used (summary)

- Version: `pyinstaller==5.1` (main). The cleanup branch later used `pyinstaller==6.11.0` (never released).
- Invocation: **CLI flags only** (one-line command), no `.spec` file on main.
- Mode: **`--onefile` (`-F`)**, **`--windowed` (`-w`)** on Windows/macOS, onefile **console** on Linux.
- Data: `--add-data resources:resources`.
- No custom hooks, no hidden imports, no excludes.

### Historical `.spec` file

The initial version of the repo *did* commit a spec file (`CustomKnight Creator.spec`, present until commit `ed32f0d`). It was a **onedir-style spec generated by PyInstaller** (COLLECT + BUNDLE) with:

```python
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, ... upx=True, console=False, icon='resources/SheoIcon.icns')
coll = COLLECT(exe, a.binaries, a.zipfiles, a.datas, strip=False, upx=True, upx_exclude=[], name='CustomKnight Creator')
app = BUNDLE(coll, name='CustomKnight Creator.app', icon='resources/SheoIcon.icns', bundle_identifier=None)
```

Observations about this historical spec:
- It had `upx=True` (PyInstaller 4.x default when UPX is on PATH).
- `datas=[('resources', 'resources')]` — same data bundling as the later `--add-data`.
- It was deleted in favor of the pure-CLI approach. The cleanup branch (2024) re-added a **onefile-style** spec (`EXE(...)` without COLLECT, with `upx=True`, `console=False`, `icon=['resources/SheoIcon.icns']`, plus `BUNDLE` for macOS). Neither spec is in `main`.

### How PyQt6 is handled by PyInstaller (inference)

There is **no custom hook configuration** in this project. PyInstaller ships `pyinstaller-hooks-contrib` hooks for PyQt6 that automatically:
- Detect `PyQt6.QtWidgets` (and sibling modules) and collect the relevant Qt libraries.
- Collect Qt platform plugins (e.g., `qwindows.dll`, `qminimal`, `libqxcb.so`), image format plugins, styles, and (with PyQt6) the required `Qt6` shared libraries and translations.
- Add PyQt6's `Qt6/plugins` tree.

Evidence that Qt plugins are handled purely by the automatic hook: the only Qt-related data entry is `--add-data resources:resources` (the app's own resources). Nothing in the repo references plugins, `QT_QPA_PLATFORM_PLUGIN_PATH`, `QLibraryInfo`, or translation paths. The Linux startup failure reported by a user (issue #13, undefined symbol `wl_proxy_marshal_flags` in `libQt6WaylandClient.so.6`) shows that the Wayland platform plugin was bundled and attempted to load, which only happens when the hook collects all platform plugins. That is a real-world example of a Qt-plugin-related packaging failure that the project never fixed in the released version.

### Resource location after freezing

The app locates its bundled resources with:

```python
os.path.join(os.path.dirname(__file__), "resources/checkicon.png")   # main.py:112-116
os.path.join(os.path.dirname(__file__), "resources/duplicatedata.json")  # spritehandler.py:196-198
```

There is **no `sys._MEIPASS`** anywhere in the code. In a PyInstaller onefile app, `__file__` of the frozen main module resolves inside the `_MEIPASS` temp extraction directory, so `os.path.dirname(__file__) + "/resources/..."` happens to work in both development and frozen mode. This is a pragmatic shortcut that works, but it relies on PyInstaller internals (data files extracted next to the "script") rather than the canonical `sys._MEIPASS` idiom. For onedir mode this also works (data sits next to the executable). Worth noting: because resources are resolved relative to `__file__` rather than an absolute anchor like `sys.executable` or `os.getcwd()`, the app also works when launched from any working directory — good behavior.

### Qt Resource System (broken reference on main)

The pyuic6-generated files reference a compiled Qt resource:

```python
icon.addPixmap(QtGui.QPixmap(":/main/SheoIcon.ico"), ...)   # spritepacker_ui.py:17, duplicatewizard_ui.py:17
```

This `:/main/...` path only resolves if a Qt Resource System bundle (`.qrc` compiled to `_rc.py`, or an `.rcc` binary) is present. On `main` there is **no** `resources.qrc`/`resources_rc.py` (the cleanup branch added one but it was never merged). Result: **the window icon silently fails to display** when running from source and in the shipped binaries. This is a live example of a stale `.ui`-generated resource reference and of the difference between the Qt Resource System (`:/`) and filesystem resources.

### PyInstaller pros/cons as demonstrated by this repo

**Pros**
- Dead simple: one command, no spec needed for a small app.
- Cross-platform from one set of commands.
- Automatic PyQt6 hook coverage for a typical Widgets app.
- Onefile output makes distribution trivial for small tools.

**Cons / risks shown here**
- Onefile startup time (extraction each run) — increased by the 480 KB icns + 281 KB JSON + Qt libs bundled.
- Antivirus false-positive exposure (unsigned onefile exe) — see §7.
- Onefile extraction failures on end-user machines: issue #22 "Failed to extract MSVCP140.dll: decompression resulted in return code -1" is exactly the kind of onefile corruption/AV-blocking failure users hit.
- The Windows exe kept the default PyInstaller console? No — `-w` was used; but the Linux build kept a console, meaning console output appears for Linux users.
- No way to control Qt plugin selection without a spec/hooks, so unnecessary Wayland/XCB plugins get bundled and can break on distros with older Wayland (issue #13).
- Builds are not reproducible (unpinned transitive deps, non-deterministic timestamps in PyInstaller archives).

---

## 6. Nuitka

**This repository does not use Nuitka anywhere** (no references in any file, commit, or branch). All conclusions in this section are therefore general knowledge about the tools, clearly labeled as such, to inform the "should I use Nuitka instead?" question. (See the tutorial `PYQT6_PACKAGING_TUTORIAL.md` for a practical Nuitka-based pipeline.)

General comparison (not from this repo):

| Aspect | PyInstaller | Nuitka |
|---|---|---|
| Mechanism | Bundles bytecode + interpreter + libs; app is a bootloader extracting to temp | Compiles Python to C, then to native code; standalone bundles a runtime |
| Onefile | `--onefile` (extract to `_MEIPASS` each launch) | `--onefile` (also extracts; supports a "onefile" with a similar temp mechanism) |
| Startup | Slower for onefile (extraction) | Generally faster startup; smaller onefile extraction in recent versions |
| Bundle size | Moderate-large | Similar or smaller in standalone; the app itself is compiled (harder to unpack) |
| Build speed | Fast (packaging only) | Slow (full C compilation, needs a C compiler on PATH) |
| Antivirus reputation | Onefile bootloader pattern is widely flagged; unsigned builds are common false positives | Anecdotally fewer detections because output is a native exe with no embedded bytecode blob; **NOT guaranteed, correlation not causation** |
| Qt/PyQt6 | Hooks in pyinstaller-hooks-contrib; mature | Needs `--enable-plugin=pyqt6`; works but less turnkey |
| Debugging | Tracebacks work; bytecode is unpackable | Compiled code; tracebacks work but less introspectable; build errors are more cryptic |
| Cross-compile | None (build per-OS) | None (build per-OS) |
| Compiler requirement | None | MSVC (Windows) / gcc or clang (Linux/macOS) |

The single most relevant, honest takeaway for the user's false-positive concern: **the codebase provides no evidence either way.** It uses PyInstaller and never addresses antivirus. The user's own experience (fewer detections with Nuitka) is consistent with the widely-reported *anecdotal* pattern, but no repository evidence supports or refutes it, and no tool guarantees 0 detections. Nuitka is a legitimate, actively-maintained alternative; if false positives are a major pain point, evaluating Nuitka standalone mode on the same app is a reasonable experiment. See §7 and the tutorial for the legitimate mitigation stack.

---

## 7. Antivirus / VirusTotal Considerations

### What this repository actually does about antivirus

**Nothing.** There is no evidence of any deliberate strategy. Specifically (all verified absent):

- No code signing / Authenticode / signtool / certificates / timestamping — absent.
- No UPX control: PyInstaller 5.1's default is `upx=False` unless UPX is on `PATH`. On GitHub Actions runners, UPX is **not** installed by default, so builds are effectively uncompressed. This is a *de facto* "UPX disabled" outcome, but it is **not a deliberate choice** — there is no `--noupx` and no documentation. On a developer machine with UPX installed, local builds would compress with UPX (the historical `.spec` even had `upx=True`).
- No version-info file, no custom PE metadata, no icon beyond `-i`.
- No SmartScreen/reputation management, no checksums published.
- No VirusTotal submission or false-positive remediation workflow.
- No deterministic/reproducible build configuration.

### Evidence-based assessment

Because the repository does nothing, the only evidence-based statements are:

1. **Unsigned PyInstaller onefile executables are a well-known false-positive population.** This is corroborated by the user's own experience and by the general, well-documented behavior of AV engines flagging packed/self-extracting unsigned executables. The project ships exactly such an executable.
2. **Absence of signing is the single biggest controllable factor** — a valid Authenticode signature with an established identity changes SmartScreen behavior and gives AV engines a reputation anchor. This is strongly evidenced across the industry (Microsoft docs on SmartScreen reputation, AV vendor guidance). Note: for open-source projects, code-signing certs cost money (EV/OV) and SmartScreen reputation still requires download-volume building over time — there is **no free magic bullet**.
3. **UPX is known to increase false positives** and is generally discouraged in modern packaging; this project effectively ships without UPX (in CI), which is the *better* outcome — but unintentional.
4. **Onefile vs onedir**: onefile is structurally more similar to a packer (embedded archive + bootloader + runtime extraction), and is associated with more detections; onedir is a folder of "normal-looking" files. This is a frequently-cited, plausible correlation. Not proven by this repo (no data), and it is *correlation, not causation* — onedir unsigned apps can also be flagged.
5. **Nuitka vs PyInstaller**: same caveat — anecdotal reports only. Compiled native code has a different (less packer-like) profile, but detection depends on dozens of engine heuristics.

### Honest bottom line (no magic solution)

- No technique guarantees 0 detections.
- The *legitimate* mitigation stack is: sign with a real certificate, keep UPX off, prefer onedir or Nuitka if detections are persistent, embed correct version/company metadata, ship from a transparent public repo with checksums, build in a clean reproducible environment, and submit false positives to vendors. Details and realistic expectations are in `PYQT6_PACKAGING_TUTORIAL.md` §Windows.

---

## 8. Windows Installer

**This repository creates no installer of any kind** (no NSIS, Inno Setup, WiX, MSI, MSIX, no batch/PowerShell installer script). Distribution is a ZIP containing a single unsigned `.exe`.

Implication: no Start Menu entry, no uninstaller, no per-machine/per-user install logic, no update mechanism.

Recommendation for a PyQt6 project (see tutorial): if you want professional Windows distribution, add an installer. For open source, **Inno Setup** (free, scriptable, handles unsigned+signing of both the app and the installer, uninstaller included) is the most practical; **WiX/MSI** is more complex and suits enterprise distribution; **MSIX** is the modern store-oriented format but adds signing/identity friction. The repository gives no guidance here because it has none.

---

## 9. Windows Code Signing

**Not implemented, anywhere.** No `signtool`, no certificate files, no GitHub Secrets for a PFX/Base64 certificate, no timestamping server, no workflow step. The Windows release pipeline is:

```text
exe → (unsigned) → zip → GitHub Release
```

Nothing is signed — neither the inner executable nor any installer (there is no installer). For the tutorial's target pipeline (sign exe → build installer → sign installer → checksums → release), this repository implements **zero** of those steps.

---

## 10. Linux

### How Linux builds happen

`.github/workflows/package.yml` (lines 24-28):

```yaml
- os: ubuntu-latest
  TARGET: linux
  CMD_BUILD: >
    pyinstaller main.py -F -n "CustomKnight Creator" --add-data "resources:resources"
  OUT_FILE_PATH: "dist/CustomKnight Creator"
```

Observations:
- The Linux artifact is a **single ELF onefile binary**, no console suppression (`-w` omitted), no icon.
- It is distributed as a **ZIP** (`CustomKnight.Creator.Linux.x64.zip`), not an AppImage, not a `.deb`.
- **No desktop integration** (no `.desktop` file, no icon install, no AppStream metadata).
- The binary depends on the host's glibc and system libraries present on the `ubuntu-latest` runner at build time. Because it's a PyInstaller binary, it is *mostly* self-contained for Python + Qt (which PyInstaller bundles), but **glibc and a handful of system libs are not bundled**, so it will fail to run on older distributions with an older glibc than the build host. `ubuntu-latest` tracks a recent release, which narrows compatibility. This is the classic Linux portability problem; the repository does not address it (no "build on oldest supported distro" strategy, no AppImage).
- A user-reported issue (#13) documents a real Linux packaging failure: the bundled Wayland platform plugin crashed with an undefined symbol (`wl_proxy_marshal_flags`) on the user's older system — evidence that Qt plugins were bundled wholesale by the PyQt6 hook and not curated, and that system-library version skew broke the result.

### Conclusion on Linux

This is **not** professional Linux distribution. It's a zip of an ELF binary. No AppImage, no `.deb`, no Flatpak/Snap. For the user's goals (AppImage and `.deb`), this repository offers nothing to copy — see the tutorial for both.

---

## 11. AppImage

**Not implemented.** No AppImage tooling, no AppDir, no `AppRun`, no `linuxdeploy`/`appimagetool`/`appimage-builder`, no `.desktop` for Linux, no build-on-old-distro strategy. The Linux artifact is a plain zipped PyInstaller onefile binary. All AppImage content in the tutorial is general guidance, not derived from this repo.

---

## 12. Debian Package

**Not implemented.** No `DEBIAN/` or `debian/` directory, no `control`, `rules`, `changelog`, `copyright`, `install`, or `desktop` files; no `dpkg`/`debhelper`/`fpm` references. All `.deb` guidance is general.

---

## 13. macOS

### How macOS builds happen

`.github/workflows/package.yml` (lines 12-18):

```yaml
- os: macos-latest
  TARGET: macos
  CMD_BUILD: >
    pyinstaller main.py -F -w -n "CustomKnight Creator" -i resources/SheoIcon.icns --add-data resources:resources &&
    cd dist/ &&
    zip -r9 "CustomKnight Creator" "CustomKnight Creator.app/"
  OUT_FILE_PATH: "dist/CustomKnight Creator.zip"
```

- PyInstaller `--onefile --windowed` on macOS produces a `.app` bundle (`CustomKnight Creator.app`). In onefile mode the bundle contains a single binary plus `Info.plist`; the executable self-extracts at launch.
- The `.app` is zipped (`zip -r9`) and that ZIP is the release artifact. There is **no DMG**.
- macOS 2022-era runner was x86_64; released assets split into `MacOS.x64.zip` and `MacOS.ARM64.zip` (from GitHub API). **The mechanism that produced separate x64/ARM64 zips is not recorded in the repository.** The current workflow produces a single universal `.app`... actually, on `main` there is no `--target-arch` flag, so a single-arch build. The dual-arch release assets most plausibly came from the author's *manual* post-processing (e.g., `lipo` extracting slices from a universal2 experiment) — **not verified from the available evidence**; the repo does not contain that logic.
- The 2024 cleanup branch experimented with `--target-arch universal2` + `--no-binary :all: --compile` dependency installs (to get universal2 wheels) and a macOS-specific install step, but it was never merged or released.

### macOS packaging weaknesses

1. **Unsigned and unnotarized.** A zip of an unsigned `.app` triggers Gatekeeper ("cannot verify developer", "damaged and can't be opened" when quarantined) on modern macOS. A user issue (#14, "Program not Loading on Mac") is consistent with such Gatekeeper problems.
2. No hardened runtime, no entitlements.
3. No DMG.

### The `.app` / Info.plist / icons

- Icon: `-i resources/SheoIcon.icns` (a real `.icns`, 480 KB) — PyInstaller embeds it and sets `CFBundleIconFile`.
- `Info.plist`: auto-generated by PyInstaller with defaults (`CFBundleIdentifier` from `-n`, version from PyInstaller). No custom `Info.plist` is supplied; no `bundle_identifier` in the CLI.
- Frameworks/plugins: bundled automatically by the PyQt6 hook (PyInstaller on macOS also collects `QtCore`/`QtGui`/`QtWidgets` frameworks).

---

## 14. macOS Code Signing

**Not implemented.** No `codesign`, no `--codesign-identity`, no `entitlements_file`, no Developer ID, no keychain handling. The only "signing-adjacent" data is the `codesign_identity=None`/`entitlements_file=None` defaults in the historical `.spec` files (PyInstaller defaults), which were never populated. All macOS signing guidance in the tutorial is general.

---

## 15. macOS Notarization

**Not implemented.** No `xcrun notarytool`, no `stapler`, no `Developer ID Application` certificate references, no `APPLE_*` secrets anywhere in the workflows. The repository performs **none** of: signing internal binaries, signing the bundle, notarization, stapling, DMG signing.

---

## 16. GitHub Actions

### The complete current workflow (package.yml, 44 lines)

Reconstructed in human-readable form:

```text
[Manual trigger: workflow_dispatch]
        ↓
Job "Build packages" (runs on a 3-entry matrix)
        ↓
 ┌───────────────┬────────────────┬───────────────┐
 │  macos-latest │ windows-latest │ ubuntu-latest │
 │   TARGET=macos│ TARGET=windows │  TARGET=linux │
 └───────┬───────┴───────┬────────┴───────┬───────┘
         │               │               │
  actions/checkout@v3 (all three)
         │               │               │
  actions/setup-python@v4, python-version: 3.10.5
         │               │               │
  python -m pip install --upgrade pip
  python -m pip install -r requirements.txt
  (Pillow==9.1.1, PyQt6==6.3.1, pyinstaller==5.1)
         │               │               │
  run: pyinstaller ... (per-matrix CMD_BUILD)
         │               │               │
  actions/upload-artifact@v3.1.0
  name: ${{matrix.TARGET}}, path: dist/...
         │               │               │
  [artifacts: macos / windows / linux]
         ↓
  (NO release step — developer manually creates GitHub Release and uploads)
```

### Line-by-line of key sections

- `line 3` — `on: workflow_dispatch`: builds are **manual only**; there is no push/tag/release trigger. (Historically `build.yml` triggered `on: [push]`, see commit `7d36564` which renamed it and switched to manual.)
- `lines 8-28` — `strategy.matrix.include` with three explicit entries, each carrying `os`, `TARGET`, `CMD_BUILD`, `OUT_FILE_PATH`. This is the standard cross-platform matrix pattern.
- `lines 30-34` — checkout + Python 3.10.5.
- `lines 35-38` — single install step, `pip install -r requirements.txt`. (The 2024 cleanup branch split this into per-OS steps and used `--no-binary :all: --compile` for macOS universal2 — never merged.)
- `lines 39-40` — run the pre-encoded build command.
- `lines 41-44` — upload artifact named by `TARGET`.

### What the workflow does NOT do

- No release creation, no `softprops/action-gh-release` or `gh release create`.
- No secrets, no certificates, no signing credentials (nothing to sign).
- No caching (no `actions/cache`), so each run re-downloads all wheels.
- No tests, no lint.
- No commit SHA pinning of actions (`actions/checkout@v3` etc. are mutable tags).
- No artifact retention policy; no checksums generated.
- No matrix for macOS architectures (single `macos-latest` entry).
- No `permissions:` block, no OIDC/attestations.

### GitHub Secrets

**None required, none used.** The workflow references no `${{ secrets.* }}`. Documented as: no secrets present. (If signing were added later, typical names would be `WINDOWS_CERTIFICATE`, `WINDOWS_CERTIFICATE_PASSWORD`, `APPLE_CERTIFICATE`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_NOTARIZATION_APPLE_ID`/`APPLE_ID` + `APPLE_APP_SPECIFIC_PASSWORD` + `APPLE_TEAM_ID`, `GITHUB_TOKEN` for release creation.)

---

## 17. Resource Handling

Two resource strategies coexist:

1. **Qt Resource System (`:/` prefix)** — used only in the *generated* `spritepacker_ui.py:17` and `duplicatewizard_ui.py:17` for the window icon (`:/main/SheoIcon.ico`). The compiled resource is **not present on main**, so this reference is broken (icon silently missing). The cleanup branch added `resources.qrc` + a 37k-line generated `resources_rc.py` to fix this, but it was never merged.

2. **Filesystem resources** — the actual runtime data:
   - `resources/checkicon.png`, `resources/xicon.png` (loaded via `os.path.join(os.path.dirname(__file__), "resources/...")` — `main.py:112-116`, `128-131`, `428-433`, `440-444`).
   - `resources/duplicatedata.json` (loaded the same way — `spritehandler.py:196-198`).
   - Bundled into the frozen app via `--add-data resources:resources`.
   - A Qt search path is registered at startup: `QtCore.QDir.addSearchPath("resources", "resources")` (`main.py:15`), though the code mostly uses absolute filesystem paths rather than the search path.

Resource inventory in `resources/`: `checkicon.png`, `xicon.png`, `duplicatedata.json` (281 KB), `SheoIcon.png`, `SheoIcon.ico`, `SheoIcon.icns`. No `.qrc` on main. No fonts, no translations (`.qm`), no `.ui` bundled at runtime (the `.ui` XML files are only used at dev time by `pyuic6`; the generated `_ui.py` files are what run).

### Implications for packaging systems

- **PyInstaller**: filesystem resources + `--add-data` works for both onefile and onedir because `__file__` resolves to the bundle/temp location. It works, but `sys._MEIPASS` is the canonical, explicit approach (see tutorial).
- **Nuitka**: `--include-data-dir=resources=resources` (or `--include-data-files`).
- **AppImage**: resources must land inside the AppDir `usr/lib`/`usr/share` (with the bundle in `usr/bin`), with `PYTHONPATH`/env set by `AppRun` so the app finds them.
- **`.deb`**: resources belong in `/usr/share/<app>/` (or `/usr/lib/<app>/`), installed via `debian/install`; the app must locate them by a stable path (e.g., based on `sys.executable`/`__file__` or an env var like `CUSTOMKNIGHT_RESOURCE_DIR`).
- **macOS `.app`**: resources belong in `Contents/Resources`, and the app must resolve them relative to the bundle (`sys._MEIPASS`/`PyInstaller` handles this automatically when using `--add-data`).

---

## 18. PyQt6 / Qt Plugins

- PyQt6 is imported as `from PyQt6 import QtGui, QtCore`, `from PyQt6.QtWidgets import *` (`main.py:6-7`); Pillow used for image processing.
- **No plugin configuration exists in the project.** Qt platform plugins, image format plugins, styles, and the Qt libraries are all collected automatically by PyInstaller's PyQt6 hook (`pyinstaller-hooks-contrib`). This is both the convenience and the weakness: the hook bundles *all* platform plugins (xcb, wayland, windows, cocoa, minimal, offscreen, etc.), enlarging the binary and, as issue #13 showed on Linux, can pull in plugins that fail on older systems.
- No `--collect-all`, `--collect-submodules`, `--exclude-module`, `--copy-metadata` on `main`. (The cleanup branch briefly used `--collect-all PyQt6` for macOS and later removed it — evidence the author was fighting PyQt6 hook issues, but it was never shipped.)
- TLS/network plugins, translations, and icon engines: not used by this app (no network, no icons from Qt), so not addressed.

### Practical takeaway

For a typical Widgets app, the automatic PyQt6 hook is usually enough, but consider excluding unused Qt modules/plugins (`--exclude-module PyQt6.QtNetwork` etc.) and, for Linux, being aware that bundled Wayland/XCB plugins can break on old systems. Test on the oldest distro you intend to support.

---

## 19. Translations

**No localization infrastructure at all** — no `QTranslator`, no `QLibraryInfo`, no `TranslationsPath`, no `.qm` files, no `locale`/`i18n`. All strings are hardcoded English in code/`.ui`.

Implication for the user's learning goals: Qt's own built-in dialogs (Open/Save/Print, standard message boxes) are translated by Qt only if the corresponding `qtbase_<lang>.qm` (a.k.a. `qt_<lang>.qm`) translation files are present **and** a `QTranslator` loads them. With PyInstaller, those `.qm` files live inside the `PyQt6/Qt6/translations` wheel directory and are **not** automatically bundled into the executable by default; you must add them explicitly (e.g., `--collect-data PyQt6.QtCore` or `--add-data` of the translations dir) and load them at runtime. This project does none of that, so even if a user set `LANG`, Qt's internal dialogs would remain English. See tutorial for the exact mechanism.

---

## 20. Security and Release Integrity

Current state (all verified absent):

| Practice | Present? |
|---|---|
| Pinned top-level deps (`requirements.txt` with `==`) | Yes (3 packages) |
| Lock file with full transitive pinning + hashes | No |
| SHA256 checksums published for release assets | No (GitHub API `digest: null`) |
| Release signing (detached GPG) | No |
| Git tag/commit signing | Tags are GitHub-created; some commits show GitHub's "verified" web-commit signature, but that's GitHub's auto webhook signing, not a deliberate release-signing policy |
| SBOM / SLSA / attestations | No |
| Dependency vulnerability scanning (Dependabot) | No (no dependabot config) |
| Reproducible builds | No |

Worth copying for a small project (see tutorial): pin all transitive deps or use a lockfile/hashes; generate SHA256 for every release asset and publish them in the release notes; consider SLSA/attestations (free on GitHub); keep actions pinned to commit SHAs; add Dependabot for the requirements file.

---

## 21. Techniques Worth Reusing

- **[USEFUL]** Cross-platform GitHub Actions matrix with per-entry `CMD_BUILD`/`OUT_FILE_PATH` — compact, readable, easy to extend (`package.yml:8-28`).
- **[USEFUL]** `--add-data resources:resources` + resolve resources via `os.path.dirname(__file__)` — a working (if implicit) frozen-resource strategy that also works from source.
- **[USEFUL]** Separate icon per platform (`SheoIcon.icns` for macOS, `.ico` for Windows) — required by the packagers.
- **[USEFUL]** Exact `==` pins in `requirements.txt` — reduces surprise upgrades during builds (though not a full lockfile).
- **[USEFUL]** Manual `workflow_dispatch` for release builds — simple, safe, avoids accidental rebuilds on every push (though it loses automation).
- **[USEFUL]** zipping the macOS `.app` with `zip -r9` — the correct way to hand out a macOS app when you can't sign/notarize (still triggers Gatekeeper warnings).
- **[PROJECT-SPECIFIC]** Precomputing a large `duplicatedata.json` data file and shipping it as app data — a valid pattern (data vs code separation), but the data is specific to this mod.

## 22. Techniques Specific to This Project (do NOT copy blindly)

- **[PROJECT-SPECIFIC]** Hollow Knight mod sprite data and the `finddupes.py` offline pre-processing tool.
- **[PROJECT-SPECIFIC]** The exact icon set / app naming with spaces.
- **[PROJECT-SPECIFIC]** Resolving resources via `os.path.dirname(__file__)` — works here but the explicit `sys._MEIPASS`/`sys.frozen` idiom is more robust and portable across tools (Nuitka, onedir, etc.).
- **[LEGACY]** The `cleanup` branch's PySide6 + PyInstaller 6.x + universal2 configuration — interesting to read, but it was abandoned and never validated in a release.
- **[LEGACY]** The historical onedir `.spec` file (deleted in `ed32f0d`).
- **[LEGACY]** The `build.yml` push-triggered workflow (superseded by manual dispatch).

## 23. Problems or Weaknesses Found

1. **No signing / notarization** on any platform — the #1 professional-distribution gap; SmartScreen + Gatekeeper friction and AV false-positive exposure.
2. **Onefile on Windows/macOS** with a ~30 MB Qt bundle: slow startup (extraction), and onefile extraction is fragile to AV interference (issue #22 `MSVCP140.dll` extraction failure).
3. **No installers** — no Start Menu, no uninstall, no MSI/NSIS.
4. **Linux artifact is a bare zipped ELF** with no AppImage/`.deb`/desktop integration, and glibc/`ubuntu-latest`-freshness compatibility risk; real failure observed (issue #13 Wayland).
5. **Broken Qt resource reference** `:/main/SheoIcon.ico` on main (window icon silently missing).
6. **macOS architecture story is murky** — releases contain separate x64/ARM64 zips but the current workflow builds one arch; the split logic is undocumented. Also the app is unsigned → Gatekeeper warnings (issue #14).
7. **Dependencies frozen in time** (PyQt6 6.3.1, Pillow 9.1.1, PyInstaller 5.1 from mid-2022) — no security/maintenance updates; a crash bug fix (`b4c507d`) and version bump went into the *cleanup* branch only, never released; main is effectively unmaintained for packaging.
8. **No release automation** — everything manual; releases have no checksums, no build provenance.
9. **No tests, no lint, no runtime smoke test** in CI — a binary can be uploaded that fails at launch (several issues show users getting unhandled-exception crashes on startup, e.g., issues #18, #19, #21, #26 — tracebacks from `main.py` prove the frozen code is the same as source, but there is no CI gate to catch regressions before release).
10. **Mutable action tags** (`@v2/@v3/@v4`, `upload-artifact@v3.1.0`) — supply-chain hygiene gap.

## 24. Recommended Approach for My PyQt6 Projects

This repository's core lesson: **PyInstaller + a matrix workflow gets you a build; it does not get you a professional distribution.** For a new PyQt6 app, the study's "what's missing" list is the roadmap:

- Windows: onefile/onedir PyInstaller (or Nuitka), then Inno Setup installer, Authenticode-sign the exe AND the installer, publish SHA256, upload to a GitHub Release.
- Linux: PyInstaller/Nuitka standalone → AppDir → AppImage (build on an old-enough distro for glibc); optionally a `.deb` depending on distro packages (recommended for PyQt6 apps: depend on `python3-pyqt6` or ship bundled — see tutorial §Debian).
- macOS: build `.app` → ad-hoc-or-Developer-ID sign → hardened runtime → notarize → staple → DMG; requires an Apple Developer account only for notarization/Developer ID.
- CI: keep the matrix pattern, but add tag-triggered builds, artifact aggregation, a release job, secrets for signing, and checksums.
- Address AV false positives with the legitimate stack (§7), accept that 0 detections is not guaranteed, and prefer Nuitka as a fallback if PyInstaller detections persist.

The complete, actionable pipeline is in `PYQT6_PACKAGING_TUTORIAL.md`.

## 25. Important Files to Study

| File | Why |
|---|---|
| `.github/workflows/package.yml` | The only CI; the entire cross-platform build logic |
| `readme.md` | Documents the packaging commands (lines 26-41); compare with the workflow |
| `requirements.txt` | The dependency pins used at build time |
| `main.py` (esp. lines 15, 112-131, 428-444, 448-452) | Entry point, resource loading, `QDir.addSearchPath` |
| `spritehandler.py` (lines 196-198) | Data-file loading pattern |
| `spritepacker_ui.py` / `duplicatewizard_ui.py` (line 17) | Generated Qt resource reference (`:/main/...`) |
| `resources/` | All bundled data |
| `resources.qrc` + `resources_rc.py` + `CustomKnight Creator.spec` (on `cleanup` branch) | The never-merged "proper" resource + spec attempt |
| `.gitignore` | Confirms build outputs are not tracked |

## 26. Commands Used by the Project

From `readme.md` and the workflow (PyInstaller 5.1):

```bash
# macOS
pyinstaller main.py -F -w -n "CustomKnight Creator" -i resources/SheoIcon.icns --add-data resources:resources

# Windows
pyinstaller main.py -F -w -n "CustomKnight Creator" -i resources/SheoIcon.ico --add-data "resources;resources"

# Linux
pyinstaller main.py -F -n "CustomKnight Creator" --add-data "resources:resources"

# Dependency install (workflow)
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

(Historical/deleted: `pyinstaller main.py` with a generated onedir spec; cleanup-branch experiments added `--target-arch universal2`, `--collect-all PyQt6`, and `python -m pip install --no-binary :all: --compile -r requirements.txt`.)

## 27. Final Conclusions

1. **Packaging mechanism**: PyInstaller, onefile mode, pure CLI flags — identical commands in README and CI (documentation and implementation agree).
2. **Everything "professional" is missing**: signing, notarization, installers, AppImage, `.deb`, DMG, release automation, checksums.
3. **The Git history is the most interesting artifact**: it shows the author iterating on CI (push → manual trigger; universal2 experiments; a PySide6 + PyInstaller 6 migration that was abandoned), and then abandoning maintenance entirely (main frozen at 2022 versions).
4. **For the user's antivirus question**: the repository offers no solutions and no data; it is a textbook example of the *problem* (unsigned onefile PyInstaller exe). The lesson is negative but valuable: don't copy this aspect; apply the legitimate mitigation stack instead.
5. **Reusability verdict**: reuse the simple matrix workflow pattern and the filesystem-resource approach; do **not** reuse the packaging omissions. Use the tutorial for the actual professional pipeline.

---

*End of study. All claims are based on static inspection of the repository (working tree, all git history, all branches) and public GitHub API data (repository metadata, releases with asset sizes/download counts, issues, PRs). Release binaries were not executed. No secrets are disclosed (the project uses none).*
