# MASTER GUIDE: Professional PyQt6 Packaging

**Second-level comparative analysis of five real-world case studies**
(CARA, CustomKnight-Creator, dikte, napari, pyzo)

**Date of analysis:** 2026-08-25
**Evidence base:** the fifteen files in the `*-resultados/` directories (the `01_*.md` investigation reports, the `PACKAGING_STUDY.md` technical studies, and the `PYQT6_PACKAGING_TUTORIAL.md` recommendation documents) produced during the first research phase. No release binary was executed during this analysis, and no original study file was modified.

---

## Knowledge-level labels used throughout

- **[OBSERVED]** = a technique is actually implemented by a project (Level 1).
- **[REPEATED]** = a technique is independently used by several projects (Level 2).
- **[RECOMMENDED]** = a previous agent recommends the technique, but the case studies do not necessarily demonstrate it (Level 3).
- **[INFERENCE]** = a technical conclusion of this analysis derived from comparing evidence (Level 4).
- **[NOT VERIFIED]** = cannot be established from the available studies.
- **[CONFLICT]** = two studies disagree; the disagreement is classified explicitly.

Final recommendations are additionally classified with one of:
`[REPEATED + STRONG EVIDENCE]`, `[REPEATED + MODERATE EVIDENCE]`,
`[OBSERVED BUT PROJECT-SPECIFIC]`, `[RECOMMENDED FROM TECHNICAL REASONING]`,
`[EXPERIMENTAL]`, `[NOT VERIFIED]`, `[NOT RECOMMENDED]`.

---

## 1. Executive Summary

Five real open-source Python/Qt desktop projects were studied in depth in the
first phase. A second-level comparison of those studies yields the following
headline conclusions:

1. **PyInstaller is the de-facto standard freezer.** Four of the five projects
   build with PyInstaller directly (CARA, CustomKnight-Creator, dikte, pyzo).
   The fifth (napari) uses conda `constructor`, and explicitly documents that
   PyInstaller, Nuitka and PyOxidizer were tried and rejected because frozen
   binaries cannot support its runtime plugin ecosystem. **No project uses
   Nuitka.** [REPEATED + STRONG EVIDENCE]

2. **The dominant bundle shape is PyInstaller `onedir`.** CARA, dikte and pyzo
   all use onedir. Only CustomKnight-Creator uses `onefile`. The onedir
   rationale is repeated almost identically (avoid per-launch extraction;
   easier debugging; onedir travels inside installers/AppImages/DMGs).
   [REPEATED + STRONG EVIDENCE]

3. **No project has any antivirus/VirusTotal measurement.** None of the studies
   contains a detection count, a VirusTotal result, a SmartScreen outcome, or a
   false-positive submission record. Claims about which tool or mode "causes"
   or "avoids" detections are therefore **not supported by any case-study
   evidence** and must remain hypotheses to be tested. [NOT VERIFIED]

4. **Code signing is the one reputation mechanism all serious pipelines treat
   as essential — but only macOS is consistently done well.** Three projects
   implement full Developer ID signing + notarization + stapling on macOS
   (CARA, pyzo, napari). **No frozen-app project signs its Windows binaries or
   installers**; only napari signs Windows (Azure Artifact Signing on final
   releases, plus an explicitly untrusted Apple-cert stopgap otherwise).
   [REPEATED + STRONG EVIDENCE for macOS; OBSERVED for Windows]

5. **Only one project ships an AppImage** (dikte: manual AppDir + appimagetool
   on Ubuntu 22.04). **No project ships a `.deb`.** All `.deb` guidance in the
   tutorials is unverified recommendation, and the tutorials disagree about
   bundled-runtime vs distro-dependency packages. [OBSERVED for AppImage;
   NOT VERIFIED for DEB]

6. **The single most repeated "professional" gap is release integrity:**
   checksums, dependency locks, artifact smoke tests, SBOM and provenance are
   absent from every PyInstaller-based project. napari is the exception and is
   the best model for CI hygiene (gated signing, signature verification,
   install-and-smoke-test of artifacts, SHA-pinned actions, zizmor,
   least-privilege permissions). [REPEATED + MODERATE EVIDENCE]

7. **The strongest reusable techniques across the five projects:** onedir under
   a platform-native outer container; a central frozen/development resource
   resolver; building Linux payloads on an old GLIBC baseline; macOS
   sign/notarize/staple; native per-OS CI builds with tag-gated release and
   artifact smoke tests. [REPEATED + STRONG EVIDENCE]

8. **The biggest unresolved question for a new project** is the real-world
   Windows antivirus/SmartScreen behavior of *your specific signed artifacts*.
   It cannot be answered from these studies and requires the controlled
   experiment designed in §31.

---

## 2. The Five Case Studies

### 2.1 CARA (chess analysis app)
- **Binding:** PyQt6, direct imports (no QtPy).
- **Tool:** PyInstaller 6.17.0, one `.spec` per OS, **onedir** everywhere.
- **Distribution:** Windows portable ZIP; Linux amd64/arm64 `.tar.gz` built on
  Ubuntu 22.04; macOS `.app` in a ZIP, signed/notarized/stabled **by a local
  script, not CI**.
- **Windows:** onedir GUI bundle with ICO; **no Authenticode, no installer, no
  version metadata tracked**; `upx=True` in the spec but UPX is not installed on
  the Windows CI runner, so actual compression is unverified.
- **Linux:** deliberate GLIBC-baseline choice; removes bundled `libxkbcommon*`
  (crash on openSUSE Tumbleweed); GIO/`QT_QPA_PLATFORM`/`QT_QPA_PLATFORMTHEME`
  workarounds; sanitizes loader variables before launching external UCI engines.
- **macOS:** `BUNDLE` .app; Developer ID + hardened runtime + notarytool +
  stapler + `ditto` ZIP. UPX disabled when signing (compressed binaries fail
  notarization).
- **CI:** manual artifact builds only; separate unit-test workflow. No release
  automation, no secrets, no checksums.
- **Key source references (from the study):** `CARA_windows.spec`,
  `CARA_linux.spec`, `CARA_macos.spec`, `scripts/build_macos_signed.sh`,
  `app/utils/path_resolver.py`, `cara.py`.
- **Study:** `CARA-resultados/PACKAGING_STUDY.md`; report
  `CARA-resultados/01_resultado_de_Codex_CLI.md`.

### 2.2 CustomKnight-Creator (Hollow Knight mod tool)
- **Binding:** PyQt6 6.3.1, direct imports.
- **Tool:** PyInstaller **5.1, onefile** (`-F -w` Windows/macOS, onefile console
  on Linux), pure CLI flags, no committed spec on `main`.
- **Distribution:** ZIPs of raw onefile outputs attached manually to GitHub
  Releases. No signing, no installers, no AppImage, no `.deb`, no DMG.
- **Python 3.10.5**; mid-2022 dependency set frozen; effectively unmaintained
  for packaging (a `cleanup` branch with PySide6 + PyInstaller 6.11 +
  universal2 experiments was abandoned, never merged).
- **Key real failures documented:** Linux Wayland plugin crash (issue #13);
  onefile extraction failure `MSVCP140.dll` (issue #22); macOS Gatekeeper
  startup issues (issue #14); a broken `:/main/SheoIcon.ico` Qt-resource
  reference so the window icon silently never shows.
- **Reusable:** clean 3-OS matrix with per-entry build command; `--add-data
  resources:resources` + `__file__`-relative resolution; per-platform icons;
  exact `==` pins; `zip -r9` of a `.app`.
- **Study:** `CustomKnight-Creator-resultados/PACKAGING_STUDY.md`; report
  `CustomKnight-Creator-resultados/01_resultados_opencode_B.AI_Api.md`.

### 2.3 dikte (voice-dictation tray app)
- **Binding:** PyQt6 (Core/Gui/Widgets/Network), direct imports.
- **Tool:** PyInstaller, one shared `packaging/dikte.spec`, **onedir**, wrapped
  in platform-native outer packages.
- **Windows:** onedir with two executables (`Dikte.exe` GUI + `dikte-cli.exe`
  console), pinned SHA-256-verified FFmpeg added, **Inno Setup 6 per-user
  installer**; unsigned.
- **Linux:** **the only AppImage in the set** — PyInstaller onedir copied into a
  hand-built AppDir + `appimagetool` (no linuxdeploy), built on Ubuntu 22.04 for
  GLIBC; self-installs desktop integration; not hermetic (uses system audio/
  clipboard/hotkey tools and system FFmpeg); restores loader paths and host CA
  store before invoking system programs.
- **macOS:** `BUNDLE` .app + FFmpeg + **ad-hoc** codesign + `hdiutil` DMGs
  (Intel and Apple Silicon). No Developer ID, no notarization.
- **CI:** test workflow + reusable build matrix (4 platforms) + rolling/tagged
  release workflow using `github.token` only. No secrets.
- **Strong points:** onedir-under-container rationale; PR-triggered packaging
  builds; pinned+hashed helper binaries; old Linux baseline; loader/trust-store
  repair; Qt-module exclusions.
- **Weaknesses:** unpinned PyQt6/PyInstaller, mutable `continuous` appimagetool
  download, unsigned Windows, ad-hoc-only macOS, no artifact smoke tests.
- **Study:** `dikte-resultados/PACKAGING_STUDY.md`; report
  `dikte-resultados/01_Codex_CLI_reporte.md`.

### 2.4 napari + napari/packaging (scientific image viewer)
- **Binding:** QtPy abstraction; installers bundle **PySide6** (PyQt6 supported
  but never bundled).
- **Tool:** **conda `constructor`**, not a freezer. Ships a full conda env
  (~600 MB): NSIS `.exe` (Windows), `.sh` (Linux), `.pkg` (macOS).
- **Rationale (NAP-2):** PyInstaller, Nuitka, PyOxidizer tried and **rejected**
  because frozen executables are immutable and cannot install plugins at
  runtime.
- **Windows:** NSIS per-user installer; stopgap **Apple-cert PFX** signature on
  all signed runs (explicitly not trusted by Windows, SmartScreen still warns);
  **Azure Artifact Signing** (NumFOCUS shared certs) on final tags only, with
  SHA256 digest, RFC 3161 timestamp, `Get-AuthenticodeSignature` verification
  that fails the job, and SHA256 checksums.
- **Linux:** `.sh` self-extracting conda installer; no AppImage (removed after
  Briefcase), no `.deb`. `__glibc` pseudo-package handles the compatibility
  floor instead of the runner OS.
- **macOS:** `.pkg` signed with Developer ID Installer, internal `_conda`
  binary codesigned with Developer ID Application, **notarized + stapled via
  `notarytool` (App Store Connect API key) and `spctl`-verified in CI**
  (`make_bundle_conda.yml:534-585`).
- **CI:** 3 jobs (`packages` → `prepare_matrix` → `installers` 4-platform
  matrix); called from the app repo via `workflow_call` with `secrets: inherit`;
  signing gated by event type + secret availability; installers installed and
  smoke-tested in CI; SHA-pinned actions, zizmor, dependabot, least-privilege
  permissions; per-installer lockfile artifacts.
- **Study:** `napari-resultados/PACKAGING_STUDY.md` +
  `napari-packaging-resultados/PACKAGING_STUDY.md`; reports
  `napari-resultados/01_opencode_B.AI_API_resultado.md` and
  `napari-packaging-resultados/01_resultados_por_opencode_con_DeepSeek_V4_Flash_(B.AI).md`.

### 2.5 pyzo (scientific Python IDE)
- **Binding:** multi-binding (PySide6 on Win64/macOS, PyQt5 on Win32/Linux;
  source supports PyQt5/6, PySide2/6). Not a pure PyQt6 example.
- **Tool:** PyInstaller `--onedir --windowed`; the spec is generated by
  `freeze/pyzo_freeze.py` (not committed).
- **Distribution:** Windows portable ZIP + **Inno Setup** EXE (Win64 only);
  Linux ZIP + tar.gz (Ubuntu 22.04); macOS `.app` + ZIP + **DMG**, Developer ID
  + hardened runtime + notarytool + stapler in **CI**.
- **Windows:** no signing; per-user Inno installer; LZMA solid compression;
  optional `.py` association; no version resource.
- **Linux:** onedir archives; README actually recommends source execution
  because of Qt library incompatibility risk.
- **Qt handling:** exactly `QtCore/QtGui/QtWidgets/QtPrintSupport` as hidden
  imports; broad Qt-module exclusions (~120 MB vs ~300 MB); nearly the whole
  stdlib included (IDE need); full source copied into the bundle (IDE need).
- **CI/CD:** `ci.yml` (multi-binding matrix) + `cd.yml` (native build jobs,
  frozen-app smoke tests via xvfb/log check, tag-gated `gh release create
  --verify-tag`).
- **Reusable:** native CI builds; frozen-app smoke tests; explicit Qt module
  include/exclude; macOS signing/notarization in CI; old Linux baseline;
  tag-gated publishing.
- **Study:** `pyzo-resultados/PACKAGING_STUDY.md`; report
  `pyzo-resultados/01_resultados_de_Codex_CLI.md`.

---

## 3. Comparative Matrix

Legend: `YES` = implemented/evidenced · `NO` = not present in tracked evidence ·
`PARTIAL` = some evidence but incomplete/inconsistent · `UNKNOWN` = cannot be
determined · `N/A` = not applicable to the project's approach.

| Dimension | CARA | CustomKnight | dikte | napari | pyzo |
|---|---|---|---|---|---|
| Qt binding | PyQt6 direct | PyQt6 direct | PyQt6 direct | QtPy (PySide6 bundled) | multi-binding |
| Python (build) | 3.11 | 3.10.5 | 3.12 | 3.13 | 3.14 / 3.9 (legacy) |
| Python supported (claims) | 3.8+ | 3.10 | 3.11+ | >=3.11 | >=3.6 |
| Windows packaging tool | PyInstaller | PyInstaller | PyInstaller | conda constructor | PyInstaller |
| Windows build mode | onedir | onefile | onedir (dual EXE) | N/A (conda prefix) | onedir |
| Windows installer | NO (ZIP) | NO (ZIP) | YES (Inno 6, per-user) | YES (NSIS) | YES (Inno, Win64) |
| Windows signing (Authenticode) | NO | NO | NO | YES (Azure, final tags; Apple-cert stopgap) | NO |
| Windows notarization/reputation | N/A | N/A | N/A | PARTIAL (SmartScreen acknowledged) | N/A |
| UPX | PARTIAL (requested, unprovisioned) | NO (absent by accident) | NO (absent; unverified) | NO | NO (unverified) |
| Antivirus/VirusTotal discussion | NO (no data) | NO (no data) | NO (no data) | NO (no data) | NO (no data) |
| Linux packaging tool | PyInstaller | PyInstaller | PyInstaller | conda constructor | PyInstaller |
| AppImage | NO (tar.gz) | NO (ELF zip) | YES | NO (removed) | NO (zip/tar.gz) |
| AppImage construction | N/A | N/A | manual AppDir + appimagetool | N/A | N/A |
| Linux `.deb` | NO | NO | NO | NO | NO |
| Debian packaging method | N/A | N/A | N/A | N/A | N/A |
| Linux dependency strategy | bundled + host XCB/GIO | bundled (fresh glibc) | bundled + system tools (not hermetic) | full conda env | bundled + host XCB/DBus |
| macOS packaging tool | PyInstaller | PyInstaller | PyInstaller | conda constructor | PyInstaller |
| `.app` | YES (BUNDLE) | YES (onefile .app) | YES (BUNDLE) | PARTIAL (menuinst at install) | YES |
| `.dmg` | NO (ZIP) | NO (ZIP) | YES (UDZO, per-arch) | NO (PKG) | YES (UDZO/HFSX) |
| macOS code signing | YES (Developer ID, local) | NO | PARTIAL (ad-hoc) | YES (Dev ID App + Installer) | YES (Developer ID, CI) |
| Hardened Runtime | YES | NO | NO | PARTIAL (implicit) | YES |
| Notarization | YES (local) | NO | NO | YES (CI) | YES (CI) |
| Stapling | YES | NO | NO | YES | YES |
| GitHub Actions | YES | YES | YES | YES | YES |
| Build matrix | YES | YES (3 OS) | YES (4 entries) | YES (prepare_matrix, 4) | YES |
| Tag-gated release automation | NO | NO | YES (rolling+tags) | YES (tags+nightly) | YES (tags) |
| Dependency pinning | NO | PARTIAL (top-level `==`) | NO (ffmpeg pinned) | YES (conda bounds + constraints) | NO |
| Reproducibility | NO | NO | NO | PARTIAL (post-hoc lockfiles) | NO |
| Release checksums (SHA256) | NO | NO | NO | PARTIAL (generated; not attached) | NO |
| Artifact smoke test | NO | NO | NO | YES (install+launch) | YES (xvfb + log) |
| Qt plugin curation | NO | NO | YES (exclusions) | N/A (conda) | YES (include/exclude) |
| Qt translations bundled | NO | NO | NO | PARTIAL (via conda pkg) | PARTIAL (own .qm; Qt untested) |
| Resource approach | filesystem + resolver | filesystem + `__file__` | programmatic icons; no .qrc | filesystem + importlib.resources | filesystem + source tree |
| `sys._MEIPASS` | NO (avoids) | NO | NO | NO | YES (boot.py) |
| External binaries | YES (UCI engines; path sanitize) | NO | YES (ffmpeg; loader/CA repair) | PARTIAL (conda-standalone) | YES (kernel interpreters) |
| QtPy abstraction | NO | NO | NO | YES | NO |
| multiprocessing.freeze_support | YES | NO | NO | NO | NO |
| Old-Linux GLIBC baseline | YES (22.04) | NO (ubuntu-latest) | YES (22.04) | N/A (conda `__glibc`) | YES (22.04) |
| Lint/security scanning of CI | NO | NO | NO | YES (zizmor, dependabot) | NO |
| Actions pinned to SHA | NO | NO | NO | YES | NO |

**Notes on this matrix:**
- "Windows signing" for napari is real Authenticode via Azure Artifact Signing
  but only on final tagged releases; this is the only Windows signing evidence in
  the entire set.
- UPX status is treated conservatively: even where a project "requests" UPX
  (CARA) the study itself states the Windows compression is **not verified**
  because UPX is not provisioned there.
- "Antivirus/VirusTotal discussion" is NO for every project because none records
  any measurement; the studies repeatedly state this explicitly.

---

## 4. Technique Frequency Matrix

Based strictly on evidence in the studies.

| Technique | CARA | CustomKnight | dikte | napari | pyzo | Count |
|---|---|---|---|---|---|---|
| PyInstaller (direct) | YES | YES | YES | (indirect only) | YES | 4/5 |
| Nuitka | NO | NO | NO | evaluated + rejected | NO | 0/5 |
| conda constructor | NO | NO | NO | YES | NO | 1/5 |
| onedir / standalone | YES | NO | YES | N/A | YES | 3/5 |
| onefile | NO | YES | NO | N/A | NO | 1/5 |
| Inno Setup | NO | NO | YES | NO | YES | 2/5 |
| NSIS | NO | NO | NO | YES | NO | 1/5 |
| Windows Authenticode signing | NO | NO | NO | YES (final tags) | NO | 1/5 |
| AppImage | NO | NO | YES | NO (legacy removed) | NO | 1/5 |
| `.deb` | NO | NO | NO | NO | NO | 0/5 |
| macOS `.app` | YES | YES | YES | PARTIAL | YES | 4/5 (3 real + 1 partial) |
| macOS Developer ID signing | YES | NO | NO | YES | YES | 3/5 |
| macOS hardened runtime | YES | NO | NO | PARTIAL | YES | 3/5 |
| macOS notarization | YES | NO | NO | YES | YES | 3/5 |
| macOS stapling | YES | NO | NO | YES | YES | 3/5 |
| `.dmg` | NO | NO | YES | NO | YES | 2/5 |
| `.pkg` | NO | NO | NO | YES | NO | 1/5 |
| GitHub Actions | YES | YES | YES | YES | YES | 5/5 |
| Cross-platform build matrix | YES | YES | YES | YES | YES | 5/5 |
| Tag-gated release automation | NO | NO | YES | YES | YES | 3/5 |
| Native build per OS | YES | YES | YES | YES | YES | 5/5 |
| Release checksums | NO | NO | NO | PARTIAL | NO | ~0.5/5 |
| Dependency lock/pins | NO | PARTIAL | NO | YES | NO | 1/5 (full) + 1/5 (partial) |
| Reproducible-build claims | NO | NO | NO | NO | NO | 0/5 |
| Artifact (frozen) smoke test | NO | NO | NO | YES | YES | 2/5 |
| Old-GLIBC Linux build base | YES | NO | YES | N/A | YES | 3/5 |
| Explicit Qt module curation | NO | NO | YES | N/A | YES | 2/5 |
| Qt translations (app-level) | NO | NO | NO | NO | PARTIAL | ~0.5/5 |
| `importlib.resources` | NO | NO | NO | YES | NO | 1/5 |
| QtPy abstraction | NO | NO | NO | YES | NO | 1/5 |
| Central frozen/development path resolver | YES | NO | YES | NO | YES | 3/5 |
| External-binary environment repair | YES | NO | YES | N/A | NO | 2/5 |
| UPX explicitly disabled | NO | NO | NO | N/A | NO | 0/5 (CARA requests it; others absent) |
| CI security lint (zizmor) / SHA-pinned actions | NO | NO | NO | YES | NO | 1/5 |
| GitHub artifact attestations | NO | NO | NO | YES (wheels) | NO | 1/5 |
| Secrets used in CI | NO | NO | NO | YES | YES (macOS) | 2/5 |

---

## 5. What Multiple Projects Have in Common

1. **PyInstaller with an onedir-shaped bundle** is the shared baseline
   (CARA, dikte, pyzo; CustomKnight is the onefile outlier; napari is not a
   freezer). [REPEATED + STRONG EVIDENCE]
2. **Native build per OS** on GitHub Actions, never cross-compilation.
   [REPEATED + STRONG EVIDENCE]
3. **Build Linux payloads on an older Ubuntu (22.04)** to control the GLIBC
   floor (CARA, dikte, pyzo; CustomKnight's `ubuntu-latest` is the counter-
   example and its failure is documented). [REPEATED + STRONG EVIDENCE]
4. **PyInstaller hooks are trusted for Qt plugin/collection**; no project
   hand-maintains a Qt plugin inventory, and every study flags the exact
   inventory as "not verified". [REPEATED + MODERATE EVIDENCE]
5. **Resources are filesystem files, not Qt `.qrc`**; a path resolver or
   `__file__`-relative approach is used (CARA resolver, CustomKnight `__file__`,
   dikte programmatic assets, pyzo source tree, napari `__file__`/importlib).
   [REPEATED + STRONG EVIDENCE]
6. **macOS is the platform where full signing discipline is applied**
   (CARA, pyzo, napari all sign + notarize + staple), while Windows signing is
   essentially absent. [REPEATED + STRONG EVIDENCE]
7. **No AppImage, no DEB** for most; AppImage is implemented only by dikte.
   [REPEATED]
8. **No release checksums, no SBOM, no dependency lockfile** in any
   PyInstaller project. [REPEATED + MODERATE EVIDENCE] (negative finding)
9. **A cross-platform GitHub Actions matrix** with per-OS build steps exists in
   all five projects, though its completeness varies. [REPEATED + STRONG
   EVIDENCE]
10. **An intentional onedir-over-onefile reasoning** appears in CARA, dikte and
    pyzo and is echoed by the napari/pyzo/CARA tutorials. [REPEATED + MODERATE
    EVIDENCE]

---

## 6. Important Differences

1. **Packaging philosophy:** freezers (4 projects) vs package-manager installers
   (napari). This is the largest structural difference and is driven by the
   plugin ecosystem, not by preference. [OBSERVED BUT PROJECT-SPECIFIC]
2. **Bundle mode:** onedir (CARA/dikte/pyzo) vs onefile (CustomKnight).
   [CONFLICT — see §7.1]
3. **Windows delivery:** portable ZIP (CARA, CustomKnight) vs Inno Setup
   (dikte, pyzo) vs NSIS (napari). No project produces MSI/MSIX/WiX.
   [OBSERVED]
4. **Linux delivery:** tar.gz/ZIP (CARA, pyzo), bare ELF zip (CustomKnight),
   AppImage (dikte), conda `.sh` (napari). Only dikte has desktop integration.
   [OBSERVED]
5. **macOS delivery:** signed/notarized ZIP (CARA), signed/notarized DMG
   (pyzo), ad-hoc DMG (dikte), signed/notarized PKG (napari), unsigned ZIP
   (CustomKnight). [OBSERVED]
6. **Where signing runs:** local developer script (CARA) vs CI (pyzo, napari).
   [OBSERVED]
7. **CI maturity:** napari is far ahead (workflow_call, gated signing, artifact
   smoke tests, SHA-pinned actions, zizmor); CARA and CustomKnight are manual;
   dikte and pyzo are in between. [OBSERVED]
8. **Qt-binding strategy:** direct PyQt6 (CARA, CustomKnight, dikte),
   multi-binding (pyzo), QtPy abstraction (napari). [OBSERVED]
9. **Dependency control:** napari pins with conda bounds + constraints; others
   are loose or only top-level pinned. [OBSERVED]

---

## 7. Contradictions and Tradeoffs

### 7.1 onefile vs onedir [CONFLICT]

- **Project A (CustomKnight-Creator): PyInstaller onefile.** Rationale: single
  file is trivially shareable with a Discord-style audience; no evidence that
  startup/AV were weighed. Result: slow startup, fragile extraction (issue #22),
  more AV-false-positive exposure per its own study.
- **Projects B/C/D (CARA, dikte, pyzo): PyInstaller onedir.** Rationale
  (dikte spec, explicit): onefile extracts to a temp dir every launch, delays a
  hotkey app, and would nest extraction inside AppImage/DMG/setup; onedir is
  inspectable and debuggable. CARA and pyzo studies independently reach the same
  conclusion.
- **Evidence:** three of four freezing projects independently chose onedir and
  wrote the same reasoning; the onefile project is also the one whose issues
  document onefile-specific failures and whose study describes it as a
  textbook negative case.
- **Conclusion:** onedir/standalone is the better default for any app that will
  be wrapped in an installer/AppImage/DMG or that cares about startup and
  debuggability. Onefile is only justified when a single naked executable is a
  genuine user benefit with no outer container.
- **Confidence:** HIGH (for the choice); the AV correlation is NOT VERIFIED.

### 7.2 `.deb`: bundled runtime vs distro dependencies [CONFLICT — between the tutorials]

- **Tutorials A (CARA, pyzo, dikte): native dependency model.**
  `Depends: python3, python3-pyqt6`; small package; distro security updates;
  aligns with Debian Python Policy.
- **Tutorials B (CustomKnight, napari): bundled runtime.**
  Ship a PyInstaller/Nuitka standalone under `/usr/lib/<app>`; reproducible
  runtime; avoids distro Python/PyQt6 version churn.
- **Evidence available:** zero projects ship a `.deb`, so neither side is
  demonstrated. The disagreement is about tradeoffs, not facts.
- **Conclusion:** both are legitimate but answer different goals. For a distro
  that packages `python3-pyqt6` and wants policy-compliant integration, the
  native model is correct. For a project that must control its exact runtime
  across distros and cannot depend on `python3-pyqt6` availability, the bundled
  model is correct — but it must be labeled as a bundled-runtime upstream
  package, not a normal Debian archive package (dikte study makes this point
  strongly).
- **Confidence:** HIGH on the tradeoff analysis; the "best" answer for a new
  project cannot be determined from the case studies (which use neither).

### 7.3 AppImage construction: manual vs linuxdeploy [CONFLICT]

- **Observed (dikte):** manual AppDir assembly + raw `appimagetool` (no
  linuxdeploy, no appimage-builder). It works, but downloads the mutable
  `continuous` appimagetool without a pin/checksum (a weakness the study flags).
- **Recommended (CustomKnight, napari, CARA, pyzo tutorials):** linuxdeploy +
  linuxdeploy-plugin-qt (auto Qt plugin collection) or appimage-builder, pinned
  and checksummed.
- **Conclusion:** only the manual+appimagetool route is observed; linuxdeploy is
  an unverified recommendation. Both are plausible; pin and checksum whichever
  tool you use. [OBSERVED vs RECOMMENDED; neither is "wrong"]

### 7.4 Freezing vs conda constructor [CONFLICT — structural]

- **napari:** freezing rejected because frozen binaries are immutable and break
  runtime plugin installation (NAP-2).
- **Everyone else:** freezing accepted because they have no plugin ecosystem.
- **Conclusion:** the packaging technology must follow the product's runtime
  requirements. napari's choice is not evidence against PyInstaller/Nuitka for a
  plain desktop app, and the other projects are not evidence against conda for a
  plugin app. [REPEATED + MODERATE EVIDENCE]

### 7.5 `sys._MEIPASS` usage [CONFLICT]

- **pyzo** uses `sys._MEIPASS` (via `freeze/boot.py`) to locate the shipped
  source tree.
- **CARA** deliberately avoids it (the onedir spec layout means resources sit
  next to the executable; `_MEIPASS` is onefile-centric).
- **Tutorials** split: several recommend a `sys._MEIPASS`-aware helper, while
  CARA's tutorial warns `_MEIPASS` is "not needed for onedir".
- **Conclusion:** both work under PyInstaller onedir; the robust pattern is a
  single resource helper that checks `sys.frozen` and resolves onedir /
  macOS `Resources` / dev root (CARA's resolver), optionally falling back to
  `_MEIPASS` for onefile. [INFERENCE]

### 7.6 `--collect-all PyQt6` (broad) vs targeted Qt selection [CONFLICT]

- **Broad:** several tutorials recommend `--collect-all PyQt6` as a pragmatic
  hammer to avoid missing plugins/translations (napari, pyzo tutorials).
- **Targeted:** pyzo and dikte implement explicit Qt module inclusion/exclusion
  to control size and plugin risk; CustomKnight's Wayland crash (issue #13)
  shows the danger of blindly bundling every platform plugin.
- **Conclusion:** start with hooks, inspect the collected output, and exclude
  only what you have measured your app does not need. The targeted approach is
  the one actually implemented by the two projects that ship curated Qt sets.
  [OBSERVED + RECOMMENDED]

### 7.7 macOS signing: local vs CI; `--deep` vs inside-out [CONFLICT]

- **CARA** signs locally (script), explicitly signs with entitlements and
  `codesign --verify --deep --strict`.
- **pyzo** signs in CI with `codesign --force ... --deep --options runtime
  --timestamp` (uses `--deep` as an automation shortcut; its study says explicit
  inside-out signing is more auditable).
- **dikte** uses ad-hoc `--deep` signing (explicitly noted as wrong for
  production).
- **napari** signs internal `_conda` binary + PKG via constructor.
- **Conclusion:** Developer ID + hardened runtime + notarization is agreed by
  all who distribute; the `--deep` shortcut is discouraged in favor of
  inside-out nested signing but is the pragmatic observed default. [REPEATED +
  MODERATE EVIDENCE]

### 7.8 GLIBC floor: Ubuntu 22.04 vs `ubuntu-latest` [CONFLICT]

- **Good practice (CARA, dikte, pyzo):** fixed old base (22.04, GLIBC ~2.35) to
  broaden compatibility; CARA's study documents a 24.04 build needing GLIBC
  2.38 that failed on Debian 12.
- **Bad practice (CustomKnight):** `ubuntu-latest` (fresh), narrowing
  compatibility; real failure documented (issue #13).
- **napari** sidesteps via conda `__glibc` minimum.
- **Conclusion:** build Linux payloads on the oldest supported base and verify
  the actual floor with `readelf --version-info`. [REPEATED + STRONG EVIDENCE]

---

## 8. Windows Packaging

### What the case studies show [OBSERVED]

| Aspect | Observed pattern |
|---|---|
| Freezer | PyInstaller (4/4 freezer projects) |
| Bundle shape | onedir (3/4); onefile (1/4, the negative case) |
| Installer | Inno Setup (dikte, pyzo); NSIS (napari, via constructor); none (CARA, CustomKnight) |
| Signing | Only napari (Azure Artifact Signing, final tags; Apple-cert stopgap otherwise) |
| Version metadata | Only Inno publisher/version strings (dikte, pyzo); no PE version resources |
| UPX | Requested by CARA spec but unprovisioned on Windows CI; absent elsewhere |
| SmartScreen/VirusTotal | No measurements anywhere |

### Analytical conclusions

- **PyInstaller onedir is the demonstrated Windows baseline.** [REPEATED +
  STRONG EVIDENCE]
- **Inno Setup is the only classic installer actually used by a frozen-app
  project** (dikte per-user, pyzo per-user default). Both are per-user /
  non-elevated. NSIS is used only via conda constructor. [OBSERVED]
- **Windows signing is the single largest gap** in every frozen-app project.
  Only napari demonstrates real Authenticode (via a managed/cloud service), and
  even napari signs only final releases. [REPEATED + STRONG EVIDENCE — negative
  finding]
- **No project demonstrates MSI/MSIX/WiX.** The MSIX/MSI recommendations in the
  tutorials are unverified recommendations. [NOT VERIFIED]
- **Recommendation for a new project:** PyInstaller onedir (or Nuitka
  standalone after the §31 experiment) → PE version metadata → sign inner
  executables → build signed Inno Setup installer → verify signatures → SHA256.
  [RECOMMENDED FROM TECHNICAL REASONING, based on the strongest observed
  combination]

---

## 9. PyInstaller

### Observed usage across projects [REPEATED + STRONG EVIDENCE]

- **Modes:** onedir is the dominant mode (CARA, dikte, pyzo via `COLLECT`);
  onefile only in CustomKnight.
- **Spec vs CLI:** CARA maintains one `.spec` per OS; dikte maintains one shared
  `.spec`; pyzo generates the spec programmatically; CustomKnight uses CLI flags
  only. All studies converge on: keep a committed `.spec` once the build is
  non-trivial.
- **Version:** projects use 5.1 (CustomKnight, frozen mid-2022) and 6.x
  (CARA 6.17.0, dikte unpinned modern, pyzo unpinned modern). The studies and
  tutorials agree that current stable PyInstaller is preferable to the frozen
  5.1.
- **Qt handling:** all rely on `pyinstaller-hooks-contrib` PyQt6 hooks; none
  hand-maintains plugin inventories; two (dikte, pyzo) add Qt module exclusions.
- **Runtime path handling:** pyzo uses `sys._MEIPASS`; CARA avoids it;
  CustomKnight relies on `__file__`; dikte uses `sys.frozen` +
  `sys.executable`/`.app` ancestors.

### Demonstrated strengths

- Fast builds, mature hooks, transparent onedir tree, easy debugging
  (all four freezer projects independently rely on these). [REPEATED]

### Demonstrated weaknesses

- Qt plugin/translation collection completeness is never verified by any
  project (every study states this). [REPEATED + MODERATE EVIDENCE]
- Onefile mode shows startup/extraction fragility and is associated with the
  negative case study. [OBSERVED BUT PROJECT-SPECIFIC]
- No project demonstrates reproducible PyInstaller output. [NOT VERIFIED]

---

## 10. Nuitka

**No case study uses Nuitka.** The only direct evidence is negative: napari
tried Nuitka (and PyOxidizer) and rejected both for its plugin-ecosystem use
case (NAP-2). Everything else in the studies is comparative guidance written by
the agents, explicitly labelled as not from the repositories:

- Requires a C/C++ compiler and longer builds. [RECOMMENDED — general]
- `--standalone` is the onedir-equivalent; `--onefile` also extracts.
  [RECOMMENDED — general]
- PyQt6 support is via `--enable-plugin=pyqt6`; dikte's study specifically
  flags that Nuitka 2.1 historically dropped PyQt6 on macOS and that current
  PyQt6/macOS support must be proven with the exact versions before standardizing
  on it. [RECOMMENDED — general; NOT VERIFIED for the current toolchain]
- The common claim "Nuitka causes fewer antivirus detections" appears in
  several tutorials as an anecdote, explicitly marked "correlation, not
  causation" and "NOT guaranteed". **No case study supplies data.**
  [NOT VERIFIED]

**Verdict:** Nuitka remains a legitimate alternative worth benchmarking (§31),
but there is zero case-study evidence that it is superior for any of the five
projects' needs, and it carries a real toolchain/macOS-support caveat.

---

## 11. PyInstaller vs Nuitka

| Criterion | Case-study evidence | Conclusion |
|---|---|---|
| Frequency | PyInstaller: 4/5 direct. Nuitka: 0/5. | PyInstaller is the demonstrated default. [REPEATED] |
| Ease of use | All PyInstaller projects build on CI without compilers. | PyInstaller has lower friction. [REPEATED] |
| Qt support | PyInstaller hooks are used by all; Nuitka Qt path is untested here. | PyInstaller Qt support is demonstrated; Nuitka is not. [REPEATED] |
| Startup/size | onedir vs standalone not compared on the same app anywhere. | NOT VERIFIED. |
| Antivirus reputation | No data on either tool. | NOT VERIFIED — requires the controlled experiment. |
| macOS | PyInstaller `.app` proven by CARA/dikte/pyzo. Nuitka macOS PyQt6 history is a caveat. | PyInstaller safer default on macOS. [REPEATED] |
| Build time | PyInstaller fast; Nuitka slow (all tutorials agree). | PyInstaller cheaper to iterate. [REPEATED] |

**Conclusion:** do NOT declare a winner from these studies. The evidence
supports "start with PyInstaller onedir; benchmark Nuitka standalone on the same
app if AV results or startup matter; make the choice from measured data over
several releases." This is exactly the recommendation all five tutorials
converge on. [REPEATED + MODERATE EVIDENCE]

---

## 12. Windows Antivirus / VirusTotal

### What the evidence actually supports

**No project records any antivirus/VirusTotal/SmartScreen measurement.** The
studies repeatedly and explicitly say so (CARA §7, CustomKnight §7, dikte §7,
napari §7, pyzo §7, napari-packaging §7). Therefore:

- **NOT supported:** "PyInstaller causes antivirus detections."
- **NOT supported:** "Nuitka does not cause antivirus detections."
- **NOT supported:** "onedir eliminates false positives."
- **Supported (weakly, as correlations people report, not measurements):**
  - Unsigned onefile self-extracting executables are a well-documented
    false-positive population (CustomKnight study describes its own artifact as
    the textbook case). This is presented as widely-reported correlation, and
    the CustomKnight study's own "digest: null" release data shows zero
    checksum/provenance work.
  - Signing is treated as the primary legitimate reputation mechanism
    (napari signs precisely for this; napari-packaging study §7 documents that
    the untrusted Apple-cert signature keeps SmartScreen warnings — i.e., a
    signature that is not Windows-trusted does NOT remove warnings).
  - UPX is generally discouraged in modern guidance (repeated in all
    tutorials), but no project measures its effect.
  - napari's ~600 MB installer "may avoid some heuristic scans" is stated as
    speculation even by the study that mentions it. [NOT VERIFIED]

### Technique → evidence → possible impact table

| Technique | Evidence from projects | Evidence strength | Possible antivirus impact |
|---|---|---|---|
| Unsigned onefile | CustomKnight (artifact is exactly this; issues #22) | Correlational, widely reported; no VT data | Likely increases heuristic detections; NOT proven |
| Unsigned onedir | CARA, dikte, pyzo (all unsigned on Windows) | No measurements | Unknown; onedir avoids self-extraction heuristics (plausible) but unmeasured |
| Authenticode signing | napari (Azure on final tags; untrusted stopgap otherwise) | Signing shown to be the intended trust mechanism; no detection counts | Reputation anchor for SmartScreen/AV; does NOT guarantee clean results; untrusted sigs keep warnings |
| Timestamping | napari (RFC 3161); recommended everywhere | Documented practice, no AV data | Keeps signature validity; not an AV factor per se |
| UPX avoided | CARA requests it (unprovisioned); others absent | No measurements; tutorials discourage UPX | Correlational; avoiding it is cheap and conservative |
| Onefile avoided | CARA/dikte/pyzo choose onedir for operational reasons | Operational rationale observed | No measured AV link |
| Nuitka compiled output | None (no project uses it) | Anecdotal only | Unknown; NOT VERIFIED |
| Version/metadata consistency | dikte/pyzo Inno metadata; CARA icon only | Present but unmeasured | Consistent identity is part of reputation; unmeasured |
| Public source + transparent CI + checksums | napari strongest; others partial | Documented transparency practices | Reputation/trust; does not directly change heuristics |
| False-positive submission | None implements it | Recommended by all tutorials | A process to clear real detections; no project data |

### Bottom line

The only evidence-backed statements are: (a) an untrusted/absent signature keeps
Windows warnings (napari), and (b) signing is the legitimate mechanism the
serious project relies on. Everything about detection *rates* is unmeasured.
Treat any number of VirusTotal detections as a point-in-time, engine-specific
signal, never an absolute security verdict. [INFERENCE]

---

## 13. Windows Code Signing

### Observed behavior in case studies

| Project | Signs EXE? | Signs installer? | Certificate | CI secrets | Timestamp |
|---|---|---|---|---|---|
| CARA | NO | N/A | none | none | — |
| CustomKnight | NO | N/A | none | none | — |
| dikte | NO | NO (explicitly documented unsigned) | none | none | — |
| napari | N/A (no inner frozen exe) | YES on final tags (Azure Artifact Signing); Apple-cert stopgap otherwise | NumFOCUS-shared Azure cert; Apple Developer cert exported as PFX | `WINDOWS_SIGNING_*`, `CONSTRUCTOR_SIGNING_CERTIFICATE` | RFC 3161 (Microsoft TS server) |
| pyzo | NO | NO | none | none | — |

**Only napari signs Windows, and it is a post-build step on the installer via a
managed cloud signing service, with `Get-AuthenticodeSignature` verification
that fails the job and SHA256 generation.** [OBSERVED — the only example]

### Recommended signing sequence for a new project [RECOMMENDED FROM TECHNICAL
REASONING, assembled from the strongest observed pieces]

```text
1. Build the final standalone payload (PyInstaller onedir / Nuitka standalone).
2. Add PE version metadata (version_info / pyi-grab_version), icon, manifest.
3. Sign application-owned inner executables (+ relevant DLLs) with a real
   certificate: signtool sign /fd SHA256 /tr <RFC3161-URL> /td SHA256 ...
4. Verify inner signatures (signtool verify /pa /all /v).
5. Compile the Inno Setup installer from the signed payload.
6. Sign + timestamp the installer (and the uninstaller if supported).
7. Verify installer signature.
8. Generate SHA256.
```

- **Distinguish OBSERVED vs RECOMMENDED:** steps 1–2 are observed across
  dikte/pyzo (metadata) and all projects (payload); steps 3–8 are the
  recommended sequence that no frozen-app project implements; only the
  napari-equivalent of "sign installer + verify + SHA256" is observed (via
  Azure).
- **Certificate reality for open source:** the napari case shows a free/
  sponsored managed signing path (Azure/NumFOCUS). Tutorials also mention
  SignPath Foundation and Azure Trusted Signing as OSS routes. None of this is
  "free signing for everyone"; budgets and quotas exist. [RECOMMENDED — general]
- **Never** store PFX/passwords in the repo; use secrets with least privilege.
  [REPEATED + STRONG EVIDENCE]

---

## 14. Windows Installers

| Project | Installer | Scope | Key details |
|---|---|---|---|
| dikte | Inno Setup 6 | per-user (`%LOCALAPPDATA%\Programs\Dikte`, `PrivilegesRequired=lowest`) | stable AppId, solid LZMA2/max, optional HKCU autostart, CLI shim, dual GUI/CLI executables |
| pyzo | Inno Setup 5/6 | per-user default (`PrivilegesRequired=none`) | LZMA solid, shortcuts, optional `.py` association; Win32 installer broken, only Win64 ships one |
| napari | NSIS (via constructor) | per-user / all-users | menuinst shortcuts, silent `/S`, custom dir `/D=` |
| CARA | none (portable ZIP) | — | no uninstaller/shortcuts |
| CustomKnight | none (ZIP of exe) | — | no uninstaller/shortcuts |

**Analytical conclusion:** for a classic open-source PyQt6 desktop app, the
observed and tutorial-recommended default is **Inno Setup around a signed onedir
payload, per-user, with a stable AppId for upgrades, plus an optional portable
ZIP**. NSIS is viable (used by napari via constructor) but its use here is tied
to the conda toolchain. MSI/MSIX are unverified recommendations only.
[REPEATED + MODERATE EVIDENCE for Inno; NOT VERIFIED for MSIX/MSI]

---

## 15. Linux AppImage

### The one observed implementation (dikte)

- **Approach:** PyInstaller onedir → copy whole bundle into `AppDir/usr/bin/` →
  hand-write `AppRun`, `.desktop`, hicolor PNG icons → run `appimagetool` with
  `--appimage-extract-and-run` (CI has no FUSE).
- **No linuxdeploy / linuxdeploy-plugin-qt / appimage-builder** were used.
- **Build host:** Ubuntu 22.04 explicitly chosen as the oldest practical GitHub
  runner for the GLIBC floor.
- **Portability choices:** bundles Python/PyQt6/Qt via PyInstaller but
  intentionally uses *system* audio/clipboard/hotkey tools and system FFmpeg
  (not hermetic); restores `LD_LIBRARY_PATH` before invoking host tools; selects
  the host CA store when the bundled OpenSSL CA path is broken.
- **Weaknesses (flagged by the study):** mutable `continuous` appimagetool
  download without pin/checksum; no AppStream metainfo; no cross-distribution
  runtime matrix; no final SHA256; CI never launches the finished AppImage.

### Other projects

- CARA/pyzo ship tar.gz (explicitly NOT AppImage — the studies warn against
  mislabeling). [OBSERVED]
- CustomKnight ships a bare zipped ELF with no desktop integration and a
  documented Wayland crash. [OBSERVED — negative case]
- napari removed AppImage after the Briefcase era. [OBSERVED]

### Approach classification

| Approach | Status |
|---|---|
| PyInstaller onedir → manual AppDir → appimagetool | [OBSERVED — dikte] |
| linuxdeploy + linuxdeploy-plugin-qt | [RECOMMENDED — tutorials only, NOT VERIFIED] |
| appimage-builder | [RECOMMENDED — tutorials only, NOT VERIFIED] |
| Build on old GLIBC baseline | [REPEATED — CARA/dikte/pyzo (archives), dikte (AppImage)] |
| AppRun env (QT_PLUGIN_PATH, LD_LIBRARY_PATH) | [RECOMMENDED — tutorials; dikte writes a minimal mount-safe AppRun] |
| Loader-path/CA repair for host tools | [OBSERVED — dikte; highly reusable] |

### Recommendation for a new project

Use onedir → AppDir → pinned, checksummed `appimagetool` (or evaluate
linuxdeploy-plugin-qt); build on an old base; write a mount-safe `AppRun`;
include `.desktop`, icon, AppStream metainfo; test on an old Ubuntu/Debian +
Fedora + rolling distro, X11 and Wayland. [REPEATED + MODERATE EVIDENCE /
RECOMMENDED FROM TECHNICAL REASONING]

---

## 16. Linux GLIBC Compatibility

### The mechanism (agreed by CARA, dikte, pyzo studies and all tutorials)

Native binaries link against `GLIBC_*` symbol versions from the build system.
glibc is backward-compatible, so building against an **older** glibc produces a
binary that runs on newer systems, while building against a newer glibc produces
`GLIBC_2.38 not found` errors on older systems. CARA's study documents exactly
this: an Ubuntu 24.04 build required GLIBC 2.38 and failed on Debian 12; the
22.04 baseline (GLIBC ~2.35) targets Debian 12, Ubuntu 22.04+ and newer.

### Observed baselines

| Project | Build distro | GLIBC implication |
|---|---|---|
| CARA | Ubuntu 22.04 (amd64/arm64) | ~2.35 floor, deliberate |
| dikte | Ubuntu 22.04 | ~2.35 floor, deliberate |
| pyzo | Ubuntu 22.04 | ~2.35 floor, deliberate |
| CustomKnight | ubuntu-latest | fresh floor → narrow compatibility (negative case) |
| napari | Ubuntu 24.04 runner, but conda `__glibc` min | compatibility from conda packages, not runner OS |

### Analytical conclusions

- Build Linux payloads on the **oldest distribution you intend to support**
  (Ubuntu 22.04 is the oldest convenient GitHub-hosted option for these
  projects). [REPEATED + STRONG EVIDENCE]
- **Verify, don't assume:** use `readelf --version-info <binary>` to read the
  actual required `GLIBC_*` symbols; the floor is often set by the Python/PyQt6
  *wheels*, not just your code. [RECOMMENDED FROM TECHNICAL REASONING]
- GLIBC compatibility does **not** guarantee compatibility with all system
  libraries/graphics stacks (xcb/Wayland issues in CustomKnight, CARA's
  libxkbcommon crash). Test on real target distributions. [REPEATED +
  MODERATE EVIDENCE]
- napari's `__glibc` approach is a conda-specific alternative, not applicable to
  frozen PyInstaller/Nuitka payloads. [OBSERVED BUT PROJECT-SPECIFIC]

---

## 17. Linux DEB

### Observed: zero `.deb` packages

No project ships a `.deb` (CARA, CustomKnight, dikte, pyzo, napari all have no
`debian/`/`DEBIAN/control` packaging in their studies). All `.deb` content in
the tutorials is **recommendation**, and it splits into two models (§7.2):

1. **Native / distro-dependency package** — `Depends: python3, python3-pyqt6`
   (+ optional `ffmpeg`); installs source/private modules + desktop files;
   small; distro security updates; recommended by the CARA, pyzo and dikte
   tutorials; aligns with Debian Python Policy.
2. **Bundled-runtime `.deb`** — installs a PyInstaller/Nuitka standalone tree
   under `/usr/lib/<app>` or `/opt`; consistent upstream runtime; large;
   upstream owns security rebuilds; recommended by the CustomKnight and napari
   tutorials; the dikte study warns this is "not a normal Debian archive
   package."

### Recommended `.deb` architecture for a new PyQt6 app

The analysis recommends treating them as separate products:

- **For an upstream downloadable `.deb`** when distro `python3-pyqt6` is
  available and you accept distro versioning: use the **native model** with a
  proper Debian source package (`debian/control`, `rules` via `dh`/`pybuild`,
  `changelog`, `copyright`, `install`), `Architecture: all` where appropriate,
  and `lintian`-clean output.
- **If you must control the exact runtime** (or target distros without
  `python3-pyqt6`): use the **bundled model** and *disclose* it as such; depend
  only on the system libraries Qt needs (`libxcb-*`, `libxkbcommon-x11-0`,
  `libgl1`, `libegl1`), place the standalone tree under `/usr/lib/<app>`, a
  launcher in `/usr/bin`, and desktop/icon/metainfo under `/usr/share`.
- **Do not** assume the AppImage payload can simply be re-labeled as a `.deb`;
  they have different integration, dependency and update semantics.
  [RECOMMENDED FROM TECHNICAL REASONING; NOT VERIFIED BY ANY CASE STUDY]

---

## 18. PyQt6 and Qt Plugins

### Observed behaviors

- All freezer projects rely on **PyInstaller PyQt6 hooks** for Qt libraries,
  platform plugins, image formats, styles, icon engines, TLS. None maintains a
  manual plugin inventory; every study states the exact final plugin list is
  **not verified** without inspecting a build artifact.
- **Linux plugin fragility is the most-repeated real failure:**
  - CustomKnight: bundled Wayland plugin crashed with undefined symbol
    `wl_proxy_marshal_flags` on an older system (issue #13).
  - CARA: bundled `libxkbcommon*` caused a SIGSEGV on openSUSE Tumbleweed;
    removed it and added `QT_QPA_PLATFORM`/`QT_QPA_PLATFORMTHEME` workarounds.
  - dikte/pyzo: xcb/DBus are host concerns on Linux even in "bundled" output.
- **Qt module curation:** dikte excludes WebEngine/QML/Quick/Multimedia/3D/SQL/
  Bluetooth; pyzo includes exactly Core/Gui/Widgets/PrintSupport and excludes
  the rest, cutting the bundle from ~300 MB to ~120 MB. [OBSERVED — 2/5]
- **QtNetwork/TLS:** dikte forces `PyQt6.QtNetwork` as a hidden import and
  relies on the modern PyQt6 hook to collect Qt TLS plugins; not verified in the
  artifact.
- napari gets plugins implicitly from the conda `pyside6` package (the opposite
  of the freezer problem). [OBSERVED]

### Qt/PyQt6 packaging lessons that appear repeatedly

1. **Trust but verify hooks.** Collection by hooks is the default, but every
   study insists on inspecting the emitted bundle and running a clean-machine
   smoke test (`QT_DEBUG_PLUGINS=1`, exercise dialogs/images/HTTPS/printing).
   [REPEATED + MODERATE EVIDENCE]
2. **Curation beats `--collect-all`.** The two projects that control bundle
   size explicitly select Qt modules; broad collection increases size and can
   pull broken plugins. [OBSERVED — 2/5]
3. **Linux xcb/Wayland is the #1 platform-plugin failure surface.** Build on an
   old base and test on real distros/desktops. [REPEATED + MODERATE EVIDENCE]
4. **TLS/network plugins are a common silent omission.** Bundle
   `PyQt6.QtNetwork`/TLS plugins if you use HTTPS and test certificate
   validation. [RECOMMENDED — general; dikte is the example]
5. **Keep the onedir layout intact** inside AppImage/`.deb`/`.app`; don't
   flatten it (napari tutorial; dikte's `_internal` handling).
   [RECOMMENDED FROM TECHNICAL REASONING]

---

## 19. Resources and Translations

### Resources [REPEATED + STRONG EVIDENCE]

- All projects use **filesystem resources**, not Qt `.qrc`:
  - CARA: whole `app/resources` copied; centralized `path_resolver.py` handling
    dev root / macOS `Contents/Resources` / `_internal`; user data moved to
    platform locations (never written inside the signed `.app`).
  - CustomKnight: `--add-data resources:resources` + `__file__`-relative
    resolution; a broken `:/main/SheoIcon.ico` reference demonstrates why
    filesystem paths are less fragile than stale `.qrc` references.
  - dikte: icons drawn programmatically at build time (no committed binary
    assets).
  - pyzo: whole `pyzo` source tree shipped as resources (IDE need).
  - napari: `Path(__file__).parent` + `importlib.resources` (logo) +
    `QDir.addSearchPath`.
- **The recommended pattern** (converging from CARA + napari): a single
  resource helper that checks `sys.frozen` and resolves the correct bundle root;
  prefer `importlib.resources` for package data where possible. [REPEATED +
  MODERATE EVIDENCE]

### Qt translations [NOT VERIFIED — the recurring gap]

- pyzo ships its own `pyzo_*.qm` and attempts to load Qt's `qt_<locale>.qm` via
  `QLibraryInfo`, but the study says whether PyInstaller collected the Qt `.qm`
  files is **not verified**.
- CARA, CustomKnight, dikte, napari(app) have no explicit Qt translation
  handling; dikte uses an in-code string dictionary.
- napari gets Qt translations implicitly from the conda Qt packages.
- **Lesson:** for a localized frozen app you must explicitly bundle Qt's
  `qtbase_<locale>.qm` (e.g., `--collect-data PyQt6.QtCore` or `--add-data` of
  the translations dir) **and** install a `QTranslator` at startup. No case
  study demonstrates a fully verified frozen Qt-translation setup.
  [RECOMMENDED FROM TECHNICAL REASONING]

---

## 20. External Binaries

| Project | External program(s) | Handling | Reusable lesson |
|---|---|---|---|
| CARA | UCI chess engines (user-selected) | Sanitizes bundled loader/Qt/Python path variables before launching the engine so it uses system libraries | Frozen apps that launch host binaries must clean the environment they inherited |
| dikte | FFmpeg; audio/clipboard/hotkey helpers | Pins + SHA-256 verifies FFmpeg (Windows/macOS); uses system FFmpeg on Linux; restores `LD_LIBRARY_PATH` and selects host CA store before host commands | Pin+hash downloaded helpers; restore loader/trust-store env for host tools |
| pyzo | Kernel Python interpreters (user-chosen, may be 2.7+/PyPy) | Multi-interpreter support by design | — |
| napari | conda-standalone `_conda.exe`/`_conda` for post-install management | Bundled by constructor | — |
| CustomKnight | none | — | — |

**Analytical conclusion:** the pattern that repeats when a frozen app must
invoke system programs is: **the freezer (PyInstaller onedir / AppImage / etc.)
sets `LD_LIBRARY_PATH`/loader variables that leak into child processes and can
force the child to load the bundle's `libstdc++`/OpenSSL/etc., breaking it. Save
and restore the host loader environment (and trust store) narrowly around host
subprocess calls.** This is observed in both CARA and dikte. [REPEATED +
MODERATE EVIDENCE]

---

## 21. macOS `.app`

### Observed

- **CARA, dikte, pyzo** build real `.app` bundles with PyInstaller `BUNDLE`
  (onedir inside `Contents/`); CustomKnight builds a onefile `.app`; napari
  does not build an `.app` at build time (menuinst creates one at install).
- Info.plist content: stable bundle identifier (dikte `io.github.yusufipk.dikte`,
  CARA `com.pguntermann.cara`, pyzo `org.pyzo.app`), version fields, `.icns`
  icon, minimum OS, `LSUIElement` for tray apps, privacy usage descriptions
  (dikte).
- CARA's resource resolver explicitly expects `Contents/Resources`; pyzo ships
  source under `Contents/Resources/source`.
- **Architecture:** no project proves a universal2 build; dikte and pyzo build
  separate Intel + Apple Silicon artifacts; CARA advertises Apple Silicon only
  (target_arch unset); CustomKnight's dual-arch release production is
  undocumented.

### Recommendation

Build native `.app` per architecture (or prove a universal2 dependency stack);
set a stable bundle ID, version, `.icns`; inspect the bundle; add external
helpers **before** final signing (dikte's ffmpeg-after-signing problem is a
caution: adding files after signing invalidates the seal). [OBSERVED + MODERATE
EVIDENCE]

---

## 22. macOS Signing

### Observed implementations

| Project | Identity | Hardened runtime | Entitlements | Where | Verification |
|---|---|---|---|---|---|
| CARA | Developer ID Application | YES | YES (`allow-unsigned-executable-memory`, `disable-library-validation`) | local script | `codesign --verify --deep --strict` |
| pyzo | Developer ID Application (P12 in temp CI keychain) | YES (`--options runtime`) | none tracked | CI | none shown (no `spctl`) |
| napari | Developer ID Application (codesign `_conda`) + Developer ID Installer (productsign PKG) | PARTIAL (implicit) | none explicit | CI | `pkgutil --check-signature` before notarization; `spctl` after |
| dikte | ad-hoc (`-`) | NO | none | build script | `codesign --verify --deep` |
| CustomKnight | none | NO | none | — | — |

### Analytical conclusions

- **Developer ID + hardened runtime + secure timestamp is the agreed
  professional baseline** (CARA, pyzo, napari). [REPEATED + STRONG EVIDENCE]
- `codesign --deep` is used by pyzo and dikte as an automation shortcut; Apple
  and the studies discourage it in favor of explicit inside-out signing (sign
  nested helpers/dylibs/frameworks, then the app). CARA's entitlements-based
  approach is the more auditable example, but its two broad runtime exceptions
  are flagged as "justify and minimize". [OBSERVED + RECOMMENDED]
- **Temporary CI keychain pattern** (pyzo, napari): import base64 P12 into an
  ephemeral keychain, unlock, sign, discard. This is the observed-safe CI
  method. [REPEATED + MODERATE EVIDENCE]
- ad-hoc signing (dikte) is explicitly not adequate for distribution; it exists
  to satisfy local execution/arm64 needs only. [OBSERVED]

### Ideal modern sequence (from evidence)

```text
build .app -> add all resources/helpers -> sign nested code (inside-out)
  -> sign .app with Developer ID --options runtime --timestamp
  -> codesign --verify --deep --strict
  -> archive (zip or dmg) -> xcrun notarytool submit --wait
  -> xcrun stapler staple -> spctl --assess
  -> package final deliverable -> release
```

---

## 23. macOS Notarization

### Observed implementations

| Project | Tool | Credentials | Staple | Verify | DMG/artifact |
|---|---|---|---|---|---|
| CARA | `notarytool submit --wait` | keychain profile (`CARA_NOTARY_PROFILE`) | YES | staple validate | ZIP (not notarized separately) |
| pyzo | `notarytool submit --wait` | `notarytool-profile` in temp keychain (Apple ID + app password or accepted credential) | YES | none shown | ZIP + DMG (DMG not notarized separately) |
| napari | `notarytool submit --key .p8 --key-id --issuer --wait --timeout 30m` | App Store Connect API key (base64 `.p8`) | YES | `spctl --assess --type install` must match "accepted" | PKG |
| dikte | NO | — | NO | — | DMG (ad-hoc only) |
| CustomKnight | NO | — | NO | — | ZIP |

### Analytical conclusions

- **Three projects implement full notarization**; two use CI (pyzo, napari),
  one locally (CARA). [REPEATED + STRONG EVIDENCE]
- napari's is the most rigorous and auditable: checks the PKG signature before
  submission, uses the modern API-key auth, staples, and **fails the job if
  `spctl` does not return accepted**. [OBSERVED]
- Apple Developer Program membership (paid) and Developer ID certificates are
  unavoidable requirements; the studies state this repeatedly. [REPEATED +
  STRONG EVIDENCE]
- **Recommendation:** use `notarytool` with an App Store Connect API key
  (avoid 2FA), staple the ticket, and gate the release on `spctl` acceptance.
  [REPEATED + MODERATE EVIDENCE]

---

## 24. DMG

### Observed

- **pyzo** creates a read-only compressed UDZO/HFSX DMG with
  `hdiutil create -srcfolder pyzo.app`; no drag-to-Applications layout; not
  separately notarized/stabled in tracked code.
- **dikte** stages `Dikte.app` + `Applications` symlink and creates UDZO DMGs
  per architecture; DMG not signed.
- **CARA** and **CustomKnight** use ZIPs, no DMG.
- **napari** uses PKG, no DMG.
- **No project demonstrates a signed, notarized, stapled DMG.** [NOT VERIFIED]

### Recommendation

The tutorials converge on: build the DMG from the signed+notarized `.app`,
add a `/Applications` symlink, optionally sign the DMG, then notarize/staple the
DMG if it is the final deliverable, and test the exact downloaded artifact on a
clean Mac. DMG is optional UX; it is not a substitute for notarization.
[RECOMMENDED FROM TECHNICAL REASONING; the exact notarize-DMG flow is NOT
VERIFIED in the case studies]

---

## 25. GitHub Actions

### Comparison of the five CI systems

| Dimension | CARA | CustomKnight | dikte | napari | pyzo |
|---|---|---|---|---|---|
| Runner OS | win/mac/linux (manual) | 3-OS matrix | 4-entry matrix | prepare_matrix (4) | native matrix |
| Python versions | 3.11 build / 3.12 test | 3.10.5 | 3.11/12/13 tests, 3.12 build | 3.13 | 3.14 / 3.9 |
| Trigger | manual only | manual only | tags + PRs(packaging) + manual + master | tags + nightly + PR | tags + manual + branches |
| Dependency install | `pip install -r requirements.txt` | `pip install -r requirements.txt` | unpinned PyQt6/PyInstaller | conda envs (version-pinned) | `pip install -U` |
| Cache | NO | NO | NO | (micromamba caches) | NO |
| Artifacts | yes (upload) | yes (upload) | yes | yes (+ release) | yes (+ release) |
| Signing | NO | NO | NO | YES (gated) | YES (macOS only) |
| Notarization | NO (local) | NO | NO | YES | YES |
| Release creation | NO | NO | `gh release create` | `gh release create` (app repo) | `gh release create --verify-tag` |
| Checksums | NO | NO | NO | PARTIAL (Windows) | NO |
| Versioning | timestamp-based | — | rolling + tags | tags + setuptools_scm | tags |
| Secrets | none | none | none (github.token) | many (names only) | macOS cert secrets |
| Action pinning | no | no | no (v4/v5 tags) | YES (SHA) | no |
| Security lint | NO | NO | NO | YES (zizmor) | NO |
| Artifact smoke test | NO | NO | NO | YES | YES (xvfb/log) |
| Least-privilege perms | NO | NO | contents:read/write | YES | contents:write (publish) |

### Recommended architecture for a new PyQt6 project

Do not blindly copy any single workflow. The analysis recommends combining the
strongest observed pieces (dikte's reusable matrix + PR builds; napari's
`workflow_call` + `prepare_matrix` + gated signing + artifact smoke tests +
SHA-pinned actions + zizmor + least privilege; pyzo's tag-gated `gh release
create --verify-tag`):

```text
tag vX.Y.Z (and optional nightly)
   -> test job (source tests, multi-version matrix)
   -> prepare_matrix job (compute platforms)
   -> build job (native matrix):
        Windows: PyInstaller onedir -> metadata -> sign inner -> Inno -> sign installer -> verify
        Linux(ubuntu-22.04): onedir -> AppDir -> appimagetool -> AppImage  (+ .deb)
        macOS arm64/x86_64: onedir -> .app -> sign -> notarytool -> staple -> spctl -> DMG
   -> artifact smoke-test each built artifact in CI
   -> aggregate job: SHA256SUMS + SBOM/attestations
   -> create GitHub Release (signed tag), upload all artifacts
```

Gating rules to copy: signing only on tag events when secrets are available
(napari); build packaging on PRs touching `packaging/**` (dikte); publish only
from tags with `--verify-tag` (pyzo). [REPEATED + MODERATE EVIDENCE]

---

## 26. Dependency Pinning

### Observed

| Project | Python deps | PyInstaller/Nuitka | appimagetool/linuxdeploy | Installer tool | Qt/PyQt6 |
|---|---|---|---|---|---|
| CARA | min versions, no upper pins | PyInstaller 6.17.0 (pinned in CI) | N/A | N/A | PyQt6 >=6.6; 6.7.1 Linux / 6.10 Win/mac (not uniform) |
| CustomKnight | `==` top-level pins | PyInstaller 5.1 `==` | N/A | N/A | PyQt6 6.3.1 `==` |
| dikte | unpinned | unpinned | `continuous` (unpinned, no hash) | Inno (winget suggestion) | unpinned |
| napari | conda bounds + constraint files (`uv pip compile`) | N/A | N/A | constructor (versioned env) | PySide6 >=6.7.1,<6.11 (6.11 blocked) |
| pyzo | `pip install -U` (floating) | unpinned | N/A | Inno (ISCC on PATH) | binding wheel decides |

### Effect on reproducibility

- Only napari has real pinning discipline (bounds + constraints + lockfile
  artifacts), and even napari's lockfiles are generated post-hoc, not used to
  rebuild — the study calls this a reproducibility gap.
- All PyInstaller projects are effectively non-reproducible: CARA's
  timestamp-based CI version mode is explicitly non-reproducible; dikte and pyzo
  use floating/`-U` installs; CustomKnight pins top-level only.

### Recommendation for release builds

- Pin **exactly** the Python version, PyQt6/PySide6, PyInstaller/Nuitka,
  installer tools, and (for AppImage) a versioned + checksummed appimagetool.
- Use a lock/constraints file with hashes (`uv lock`, `pip-tools`, or hashed
  `requirements-*.txt`) committed per release branch.
- Record resolved versions + build logs as artifacts.
- For a small OSS project this is achievable and cheap; the barrier is
  discipline, not cost. [RECOMMENDED FROM TECHNICAL REASONING; OBSERVED only
  partially in napari]

---

## 27. Reproducible Builds

### What is actually used

- **No project achieves reproducible (byte-identical) builds.** None sets
  `SOURCE_DATE_EPOCH`, none produces deterministic PyInstaller output, none
  rebuilds from lockfiles. [OBSERVED — negative finding]
- napari's lockfile artifacts document what was built but are not used to
  rebuild. [OBSERVED — partial]
- CustomKnight pins top-level deps only. [OBSERVED — partial]

### Recommendation (realistic for a small OSS PyQt6 project)

Do not aim for full SLSA-level reproducible builds initially. A realistic
progression:

1. Pin the toolchain and use a committed lockfile with hashes.
2. Use fixed runner OS versions (e.g., `ubuntu-22.04`, `windows-2022`,
   `macos-14`) and record the resolved versions in build logs.
3. Publish per-artifact SHA256 so users can verify integrity.
4. Later, optionally add GitHub artifact attestations (free, Sigstore-backed)
   to link each artifact to repo/workflow/commit.
5. Treat byte-identical reproducibility as an aspirational goal, not a release
   gate for a small project. [RECOMMENDED FROM TECHNICAL REASONING]

---

## 28. Supply Chain Security

### Observed

| Practice | CARA | CustomKnight | dikte | napari | pyzo |
|---|---|---|---|---|---|
| Source transparency | YES (GPL, public) | YES | YES | YES | YES |
| Signed releases (macOS) | YES | NO | NO | YES | YES |
| Signed releases (Windows) | NO | NO | NO | YES (final tags) | NO |
| Checksums published | NO | NO | NO | PARTIAL | NO |
| Dependency pinning | NO | PARTIAL | NO | YES | NO |
| Actions pinned to SHA | NO | NO | NO | YES | NO |
| CI security lint (zizmor) | NO | NO | NO | YES | NO |
| Dependabot | NO | NO | NO | YES | NO |
| Least-privilege permissions | NO | NO | partial | YES | partial |
| SBOM | NO | NO | NO | NO | NO |
| Artifact attestations | NO | NO | NO | YES (wheels) | NO |
| License collection | NO | NO | NO | YES (licenses.zip) | NO |
| Tag signing | NO | NO | annotated (not signed) | recommended, not enforced | verified tag (GitHub) |

### Recommended progression for a small open-source project

**BASIC (do this first, ~zero cost):**
- Public source; pinned top-level deps; `==` or a simple lock.
- Publish SHA256 for every artifact; attach them to the release.
- Never commit secrets; reference secret *names* only.

**BETTER (low cost):**
- Commit a hashed lockfile; pin CI actions to commit SHAs.
- Sign release tags; add Dependabot.
- Add GitHub artifact attestations (`attest-build-provenance`) — free on
  GitHub and Sigstore-backed.
- Add a false-positive submission note in release docs.

**PROFESSIONAL (budget/org-level):**
- Real Windows code signing (managed/cloud service) and full macOS
  Developer ID + notarization in CI.
- SBOM generation (e.g., `cyclonedx-py`) per release.
- zizmor workflow linting + least-privilege permissions; license collection
  (`licenses.zip` / `THIRD_PARTY_LICENSES.txt`).
- Signed release manifests.

For a hobby project, BASIC + most of BETTER is the realistic target; do not
adopt enterprise SBOM/attestation tooling if it creates more maintenance than
value. [RECOMMENDED FROM TECHNICAL REASONING]

---

## 29. Recommended Architecture

A modern packaging architecture for a new open-source PyQt6 application,
constructed from the strongest evidence across the five projects.

### Repository layout

```text
myapp/
├── pyproject.toml                  # metadata + dependency groups (uv/pip-tools)
├── src/myapp/
│   ├── __main__.py                 # thin entry point
│   ├── app.py
│   └── resources/                  # packaged filesystem assets
├── packaging/
│   ├── pyinstaller/                # per-OS .spec (onedir) — CARA/dikte pattern
│   ├── windows/myapp.iss           # Inno Setup — dikte/pyzo pattern
│   ├── linux/AppRun, .desktop, .png, metainfo.xml
│   ├── debian/                     # native-source packaging (or bundled staging)
│   └── macos/entitlements.plist
├── requirements/*.lock             # hashed lockfiles per platform
├── scripts/build-*.sh / .ps1       # native build + packaging logic (dikte pattern)
└── .github/workflows/
    ├── ci.yml                      # source tests (multi-version matrix)
    ├── build.yml                   # reusable matrix (workflow_call; napari/dikte pattern)
    └── release.yml                 # tag-gated, aggregated release (pyzo/napari pattern)
```

### Build environment

- One clean virtualenv per OS; pinned Python + PyQt6 + PyInstaller (or Nuitka)
  + installer tools, from the hashed lockfiles.
- Linux builds (AppImage + `.deb`) on `ubuntu-22.04` (or an older container) for
  the GLIBC floor; verify with `readelf --version-info`.
- macOS builds on `macos-14` (arm64) and `macos-14-large`/Intel (or `macos-15`,
  `macos-15-intel` as napari does) — separate architectures, no universal2 until
  proven.

### Packaging

- **Windows:** PyInstaller onedir → PE version metadata/icon → sign inner EXEs →
  Inno Setup per-user installer → sign+timestamp installer → verify → SHA256.
- **Linux AppImage:** onedir → AppDir (AppRun, `.desktop`, icon, metainfo) →
  pinned+checksummed appimagetool → cross-distro test.
- **Linux DEB:** native dependency model (or disclosed bundled model) with
  `lintian`-clean build.
- **macOS:** `.app` → inside-out Developer ID + hardened runtime + timestamp →
  notarytool (ASC API key) → staple → spctl gate → DMG (sign/notarize if final).

### Release pipeline

- Tag-triggered; `prepare_matrix`; per-OS native build; **smoke-test each
  artifact** (launch + log check); sign/verify in CI; aggregate SHA256SUMS +
  SBOM/attestations; create GitHub Release; keep `workflow_call` reusable.

This architecture deliberately uses no single project's full stack: it takes
dikte's shared matrix + PR builds, napari's CI shape + gated signing + smoke
tests, pyzo's tag-gated release + macOS CI signing, CARA's onedir specs +
resource resolver, and CustomKnight's simple matrix as the starting scaffold.
[RECOMMENDED FROM TECHNICAL REASONING]

---

## 30. Decision Tree

```
START: NEW PyQt6 APPLICATION
  |
  +-- Does the app need to install Python packages at runtime (plugin system)?
  |     |
  |     +-- YES -> evaluate conda constructor (napari path); freezing conflicts
  |     |         with mutable environments. [OBSERVED — napari]
  |     |
  |     +-- NO  -> continue below (freezers fine)
  |
  +-- Choose the freezer
  |     +-- Default: PyInstaller, onedir. [REPEATED + STRONG EVIDENCE]
  |     +-- If AV reputation or startup is a major concern:
  |     |     benchmark PyInstaller onedir vs Nuitka standalone on YOUR app
  |     |     (§31) before committing. [RECOMMENDED]
  |     +-- Avoid onefile unless a single naked exe is a real requirement.
  |
  +-- WINDOWS?
  |     +-- Add PE version metadata + icon.
  |     +-- Can you sign (cert budget / OSS program)?
  |     |     +-- YES -> sign inner exe -> Inno Setup installer -> sign+timestamp
  |     |     +-- NO  -> portable ZIP + disclose unsigned status + checksums
  |     +-- Test on clean Windows VM.
  |
  +-- LINUX?
  |     +-- Need single-file portable? -> AppImage (onedir->AppDir->appimagetool)
  |     +-- Need apt integration?      -> native .deb (distro deps) or disclosed
  |     |                                bundled .deb
  |     +-- Both? -> ship AppImage + .deb as separate products.
  |     +-- Build on oldest supported base (ubuntu-22.04 / older container).
  |     +-- Test on old Ubuntu/Debian + Fedora + rolling distro, X11 + Wayland.
  |
  +-- MACOS?
  |     +-- Build .app (native per-architecture).
  |     +-- Apple Developer account?
  |     |     +-- YES -> Developer ID + hardened runtime -> notarytool -> staple
  |     |     |        -> spctl gate -> DMG (sign/notarize if final).
  |     |     +-- NO  -> .app ZIP, disclose Gatekeeper behavior; ad-hoc sign only
  |     |              for local use.
  |
  +-- RELEASE INFRASTRUCTURE?
        +-- GitHub Actions: tag-triggered; prepare_matrix; native matrix;
        +-- artifact smoke tests; gated signing; SHA256SUMS; GitHub Release.
        +-- Pin deps/actions; publish checksums; never store secrets in repo.
```

---

## 31. Controlled PyInstaller/Nuitka Experiment

Purpose: determine, for **your specific PyQt6 application**, whether PyInstaller
vs Nuitka and onedir vs onefile differ in antivirus/SmartScreen behavior,
startup time, size, and reliability. This is a legitimate quality/trust
evaluation; it is not evasion research.

### Variables to keep identical

- Same source commit; same Python version; same PyQt6 version; same third-party
  dependency set (from the same lockfile).
- Same application metadata (name, version, publisher, icon, description).
- Same build environment (same OS image/runner, same toolchain).
- Same signing identity (all builds signed with the same certificate, or all
  unsigned — do not mix).
- **No UPX** unless UPX is the variable under test.
- Same installer technology when the installer is part of the comparison
  (otherwise compare the standalone payloads directly).

### The four build arms

A. PyInstaller **onedir** (unsigned then signed)
B. PyInstaller **onefile** (unsigned then signed)
C. Nuitka **standalone** (unsigned then signed)
D. Nuitka **onefile** (unsigned then signed)

For each arm record:

- artifact size (download bytes) and installed tree size;
- cold startup time (first window visible) and warm startup time, N runs each;
- build time and build log;
- PE/mach-O metadata present;
- signature status and verification result;
- VirusTotal result per artifact (see below).

### What to measure and record

- Launchability on a clean VM (no dev Python/Qt on PATH).
- `QT_DEBUG_PLUGINS=1` output; missing-plugin errors.
- The exact VirusTotal JSON per artifact: total detections, engine names,
  categories (malware vs PUA vs heuristic), and the SHA-256 of the submitted
  file. Keep all results by version and date.
- SmartScreen behavior only where you can observe it (e.g., downloaded through a
  browser on a clean Windows VM).

### What VirusTotal can and cannot tell us

- **Can:** a point-in-time, multi-engine heuristic scan of one file; engine
  names and claimed categories; trends over time if resubmitted.
- **Cannot:** an absolute security verdict; behavior in a real runtime; what an
  engine will do tomorrow; whether a detection is "true" — a single-engine
  heuristic hit on an unsigned PyInstaller bootloader is not evidence of
  malware. Engines differ, and a signed build may scan differently from an
  unsigned one.
- Therefore interpret a VirusTotal result as a **release-quality signal to
  investigate**, never as proof of safety or a score to optimize blindly.

### How to report legitimate false positives

- Capture the detection engine name, its "malware name", the file SHA-256, and
  your source/release link.
- Submit through the vendor's official portal (e.g., Microsoft's
  security-intelligence submission) explaining it is a PyInstaller/Nuitka
  PyQt6 application, with source URL and checksum.
- Track submissions and responses in the release notes. Do not use obfuscation,
  packers, or binary mutation as a "fix".

### How code signing changes the experiment

- Run the full protocol twice: once unsigned, once signed with your real
  certificate. Signing changes heuristics and SmartScreen reputation behavior,
  so an "unsigned-only" conclusion does not transfer to signed releases.
- Sign after building, verify each signature, and scan the **final signed
  artifact** (rescan after any mutation).

### How reproducible builds affect interpretation

- If the build is not reproducible, two builds of "the same" source can differ,
  so a VirusTotal result applies only to the exact bytes scanned. Record the
  artifact hash and build log so the result is traceable; prefer hashed
  lockfiles so future comparisons are meaningful.

### Expected outcome

The experiment produces per-arm data on size, startup, build time, and VT
detections over **several releases** (a single sample is noise). Only then decide
whether Nuitka earns a permanent place or whether signing + onedir already
satisfy your requirements. [EXPERIMENTAL]

---

## 32. Common Mistakes to Avoid

1. **Ship an unsigned onefile executable as the primary Windows artifact.**
   The CustomKnight case is the documented negative example (no signing, no
   checksums, extraction failures, AV exposure). [OBSERVED — negative]
2. **Treat onedir or Nuitka as a guaranteed antivirus cure.** No case study
   supports this. [NOT VERIFIED]
3. **Trust PyInstaller hook collection without inspecting the bundle.** Every
   study flags plugin/translation inventories as unverified. [REPEATED]
4. **Blindly copy another project's Qt module exclusion list or
   `--collect-all`.** Dikte's exclusions fit its feature set; yours differ.
   [OBSERVED]
5. **Write inside a signed macOS `.app`.** CARA moves user data to
   `~/Library/Application Support` specifically to preserve the signature.
   [OBSERVED]
6. **Build Linux on `ubuntu-latest` and expect broad glibc compatibility.**
   CustomKnight's failure and CARA's 24.04→GLIBC 2.38 problem are the evidence.
   [REPEATED]
7. **Call a `.tar.gz`/ZIP of a directory an "AppImage".** The studies
   explicitly warn against this. [REPEATED]
8. **Use a mutable `continuous` download of appimagetool/linuxdeploy without a
   pin or checksum.** Dikte's own study flags this. [OBSERVED — negative]
9. **Ship a frozen runtime inside a `.deb` and call it a native Debian
   package without disclosure.** [RECOMMENDED — from dikte study]
10. **Add external binaries to a macOS app after signing** (breaks the seal).
    [OBSERVED — dikte]
11. **Use ad-hoc signing and treat it as production macOS distribution.**
    [OBSERVED — dikte contrast]
12. **Sign Windows with a non-Windows-trusted certificate and expect
    SmartScreen to stop.** napari's stopgap is explicitly documented as still
    warning. [OBSERVED]
13. **Skip artifact smoke tests.** CARA, CustomKnight, dikte never launch their
    artifacts in CI; napari and pyzo do, and only they can catch broken builds.
    [REPEATED]
14. **Keep unpinned/`-U` dependency installs for release builds.** All four
    freezer projects do this and none is reproducible. [REPEATED — negative]
15. **Forget to include the license file (`LICENSE`/`COPYING`) in the repo
    before building.** TBO's macOS build reached "Build complete!" and then
    failed with `cp: .../LICENSE: No such file or directory` because the
    packaging scripts embed the license inside the final `.app`/ZIP and the
    repository only had `COPYING`. Include the license file from the first
    commit (or make the scripts reference the actual filename). [OBSERVED —
    TBO, 2026]

---

## 33. What NOT to Copy From the Case Studies

1. **CustomKnight's packaging omissions** (unsigned onefile, no installer, no
   checksums, `ubuntu-latest` Linux, no tests). Copy only its simple matrix
   scaffold.
2. **napari's conda/constructor installers** for a plain PyQt6 app (600 MB,
   conda expertise required); copy its *process*, not its technology.
3. **napari's Apple-cert-for-Windows stopgap** — acknowledged as untrusted;
   do real Windows signing instead.
4. **napari's feedstock cloning + shared Azure signing arrangement** — an
   organizational setup, not a template.
5. **CARA's Linux runtime workarounds verbatim** (libxkbcommon exclusion,
   GIO/KDE specifics) — reproduce the failure before copying.
6. **CARA's two broad macOS entitlement exceptions** without justification —
   minimize entitlements per application.
7. **dikte's programmatic icon-drawing pipeline** and its exact Qt exclusion
   list — application-specific.
8. **dikte's self-installing AppImage integration** unless your product needs
   autostart/menu integration; otherwise leave integration to desktop tools.
9. **pyzo's full-source shipping, whole-stdlib inclusion, and multi-binding
   matrix** — IDE-specific, unnecessary for a plain app.
10. **pyzo's `pip install -U` release dependencies** and its stale `*.msi`
    glob / broken Win32 installer.
11. **dikte's suggestion of `xattr -dr com.apple.quarantine` in release notes**
    — prefer Developer ID/notarization over training users to remove
    quarantine.
12. **Any tutorial's claim of a guaranteed antivirus outcome** — none is
    supported by evidence.

---

## 34. Recommended Release Checklist

### WINDOWS
- [ ] Version updated
- [ ] Dependencies controlled (lockfile with hashes)
- [ ] Build environment controlled (pinned Python/PyInstaller/Qt)
- [ ] Application built (PyInstaller onedir or Nuitka standalone)
- [ ] Qt plugins verified (platforms, imageformats, TLS if used)
- [ ] Resources verified (frozen path resolver test)
- [ ] PE version metadata + icon present
- [ ] Antivirus scan performed (final signed artifact; record result)
- [ ] Inner executables signed + timestamped
- [ ] Signature verified (`signtool verify /pa /all /v`)
- [ ] Installer created (Inno Setup)
- [ ] Installer signed + timestamped
- [ ] Installer signature verified
- [ ] SHA256 generated
- [ ] Tested on clean Windows system

### LINUX APPIMAGE
- [ ] Build distribution selected (old GLIBC base; `readelf` floor checked)
- [ ] AppDir verified (AppRun, `.desktop`, icon, metainfo)
- [ ] Qt plugins verified
- [ ] appimagetool pinned + checksummed
- [ ] AppImage created
- [ ] AppImage tested on target distributions (old Ubuntu/Debian + Fedora +
      rolling; X11 + Wayland)
- [ ] SHA256 generated

### LINUX DEB
- [ ] Debian metadata verified (`control`, `rules`, `changelog`, `copyright`)
- [ ] Dependencies verified (native or disclosed bundled)
- [ ] Architecture verified (`all` vs `amd64`)
- [ ] Desktop integration verified
- [ ] `lintian` checked
- [ ] Installation tested (clean container/VM)
- [ ] Upgrade tested
- [ ] Removal/purge tested

### MACOS
- [ ] `.app` created (native per-architecture)
- [ ] Resources verified (inside `Contents/Resources`; no post-sign mutation)
- [ ] Qt frameworks/plugins verified
- [ ] External helpers added BEFORE signing
- [ ] Developer ID signing performed (hardened runtime + timestamp)
- [ ] `codesign --verify --deep --strict` passes
- [ ] Notarization performed (`notarytool --wait`)
- [ ] Stapling performed + validated
- [ ] `spctl` assessment accepted
- [ ] DMG created (with `/Applications` link; sign/notarize if final)
- [ ] DMG tested on clean Mac (quarantined download)
- [ ] SHA256 generated

### RELEASE
- [ ] Version consistent across metadata
- [ ] License file (`LICENSE`/`COPYING`) present in repo and bundled in all
      artifacts
- [ ] Changelog updated
- [ ] Artifacts smoke-tested (launch + log check in CI)
- [ ] Checksums published (SHA256SUMS attached)
- [ ] Source code available
- [ ] Git tag created (signed/annotated)
- [ ] GitHub Release created with all artifacts + notes
- [ ] (Optional) SBOM/attestations attached
- [ ] Secrets never appear in logs

---

## 35. Final Conclusions

1. **Strongest technique across the studies:** PyInstaller **onedir** as a
   transparent, debuggable, container-ready payload, built natively per OS.
   [REPEATED + STRONG EVIDENCE]
2. **Strongest Windows strategy:** onedir + PE metadata + signed Inno Setup
   installer + SHA256; the signing portion is recommended (only napari
   demonstrates real Windows signing). [REPEATED + MODERATE EVIDENCE]
3. **PyInstaller vs Nuitka:** no winner can be declared from the case studies
   (Nuitka is used by none, and its AV advantage is unverified). Start with
   PyInstaller onedir; benchmark Nuitka standalone with the §31 experiment.
4. **Antivirus false positives:** the only evidence-backed facts are that an
   untrusted/absent Windows signature keeps SmartScreen warnings, and that
   signing is the legitimate trust mechanism the mature project relies on.
   Detection *rates* are unmeasured everywhere; treat VirusTotal as a
   point-in-time signal.
5. **Strongest AppImage strategy:** onedir → manual AppDir → pinned
   appimagetool on an old GLIBC base, with loader/CA repair for host tools
   (dikte is the only implementation). [OBSERVED]
6. **Strongest DEB strategy:** cannot be determined from the case studies (none
   ships one); the two models (native vs bundled) are tradeoffs, with native
   recommended when distro `python3-pyqt6` exists and bundled when runtime
   control is required. [NOT VERIFIED]
7. **Strongest macOS strategy:** `.app` → inside-out Developer ID + hardened
   runtime + timestamp → notarytool → staple → spctl gate → DMG, in CI
   (CARA/pyzo/napari each demonstrate parts; napari has the most auditable CI
   flow). [REPEATED + STRONG EVIDENCE]
8. **Strongest signing strategy:** macOS: Developer ID + notarization (agreed by
   3/5). Windows: managed/cloud Authenticode on final releases with in-CI
   signature verification (only napari). Gate signing by event + secret
   availability. [REPEATED + MODERATE EVIDENCE]
9. **Strongest GitHub Actions architecture:** `workflow_call` reusable build +
   `prepare_matrix` + native matrix + gated signing + artifact smoke tests +
   SHA-pinned actions + zizmor + least privilege + tag-gated release (napari
   shape, dikte PR-builds, pyzo tag verification). [REPEATED + MODERATE
   EVIDENCE]
10. **Five most reusable techniques:** (1) onedir under a native outer
    container; (2) central frozen/development resource resolver + platform
    user-data paths; (3) old-GLIBC Linux build base; (4) macOS
    sign/notarize/staple with in-CI verification; (5) native per-OS matrix CI
    with artifact smoke tests and tag-gated release. [REPEATED + MODERATE/
    STRONG EVIDENCE]
11. **Five most important things NOT to copy:** (1) unsigned onefile Windows
    distribution; (2) conda/constructor for a plain app; (3) Apple-cert-for-
    Windows signing; (4) unpinned/floating release dependencies; (5) treating
    tar.gz/zip as AppImage or ad-hoc signing as production macOS. [REPEATED +
    MODERATE EVIDENCE]
12. **Biggest unresolved questions:** (a) real antivirus/SmartScreen behavior
    of signed PyInstaller vs Nuitka artifacts; (b) whether signing materially
    reduces SmartScreen warnings (napari raises but cannot answer); (c) exact
    Qt plugin/translation inventories in frozen artifacts (unverified in every
    study); (d) the correct DEB model for a new app; (e) whether a notarized
    DMG flow works as well as notarized ZIP/PKG (not demonstrated).
13. **Experiments to perform before finalizing an architecture:** the §31
    controlled PyInstaller/Nuitka comparison over several releases; a
    cross-distribution AppImage/GLIBC test matrix; a clean-machine artifact
    smoke-test suite; a signed-vs-unsigned VirusTotal comparison; and a
    Nuitka-macOS-PyQt6 proof build (given the historical macOS caveat).

**Final principle:** the value of these five case studies is not "who packages
best" but which techniques have enough independent evidence to become a
reusable methodology. The techniques with the strongest support are
PyInstaller onedir, native per-OS CI with artifact testing, old-GLIBC Linux
baselines, and the macOS sign/notarize/staple chain. Everything about Windows
antivirus reputation remains to be measured on your own signed artifacts.
