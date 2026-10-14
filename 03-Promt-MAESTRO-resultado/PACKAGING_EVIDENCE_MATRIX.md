# PACKAGING EVIDENCE MATRIX

Compact, evidence-oriented reference for the major conclusions in
`MASTER_PYQT6_PACKAGING_GUIDE.md`.

**How to read this table**
- **Evidence file** = which first-phase document(s) support the claim
  (abbreviations below).
- **Evidence location** = the relevant section of that document, as the study
  itself reports it (file paths/line numbers quoted inside the studies are
  included where the study provides them; line numbers were not independently
  re-verified in this second-level analysis).
- **Observed behavior** = what the project actually does.
- **Conclusion** = the second-level conclusion and its classification.
- **Confidence** = HIGH / MEDIUM / LOW based on the strength and
  independence of the evidence.

**Evidence file abbreviations**
- `CARAhd` = `CARA-resultados/01_resultado_de_Codex_CLI.md`
- `CARAS` = `CARA-resultados/PACKAGING_STUDY.md`
- `CARAT` = `CARA-resultados/PYQT6_PACKAGING_TUTORIAL.md`
- `CKhd` = `CustomKnight-Creator-resultados/01_resultados_opencode_B.AI_Api.md`
- `CKS` = `CustomKnight-Creator-resultados/PACKAGING_STUDY.md`
- `CKT` = `CustomKnight-Creator-resultados/PYQT6_PACKAGING_TUTORIAL.md`
- `DIKhd` = `dikte-resultados/01_Codex_CLI_reporte.md`
- `DIKS` = `dikte-resultados/PACKAGING_STUDY.md`
- `DIKT` = `dikte-resultados/PYQT6_PACKAGING_TUTORIAL.md`
- `NAPhd` = `napari-resultados/01_opencode_B.AI_API_resultado.md`
- `NAPS` = `napari-resultados/PACKAGING_STUDY.md`
- `NAPT` = `napari-resultados/PYQT6_PACKAGING_TUTORIAL.md`
- `PAPhd` = `napari-packaging-resultados/01_resultados_por_opencode_con_DeepSeek_V4_Flash_(B.AI).md`
- `PAPS` = `napari-packaging-resultados/PACKAGING_STUDY.md`
- `PAPT` = `napari-packaging-resultados/PYQT6_PACKAGING_TUTORIAL.md`
- `PZOhd` = `pyzo-resultados/01_resultados_de_Codex_CLI.md`
- `PZOS` = `pyzo-resultados/PACKAGING_STUDY.md`
- `PZOT` = `pyzo-resultados/PYQT6_PACKAGING_TUTORIAL.md`

---

## A. Core technique matrix

| Technique | Project | Evidence file(s) | Evidence location | Observed behavior | Conclusion | Confidence |
|---|---|---|---|---|---|---|
| PyInstaller onedir | CARA | CARAhd; CARAS | §1, §5 (specs use `EXE(exclude_binaries=True)` + `COLLECT`) | onedir bundles on all platforms | onedir is the demonstrated default | HIGH |
| PyInstaller onedir | dikte | DIKhd; DIKS | §5 (`COLLECT` at spec lines 103-109; explicit onefile rationale) | shared onedir payload wrapped in outer packages | onedir-under-container is deliberate and reasoned | HIGH |
| PyInstaller onedir | pyzo | PZOhd; PZOS | §5 (`--onedir --windowed`; generated spec) | onedir + Inno/DMG/ZIP wrappers | onedir + native wrappers | HIGH |
| PyInstaller onefile | CustomKnight | CKhd; CKS | §3, §4 (CLI `-F -w`; `--add-data`) | onefile on all OS | onefile is the outlier; associated with the negative case | HIGH (for the fact) |
| Nuitka | none of the 5 | all studies | each study's "Nuitka" section | no project uses Nuitka | Nuitka is unverified in all case studies | HIGH (for the fact) |
| Nuitka/PyInstaller/PyOxidizer rejected | napari | NAPS; PAPS | NAPS §5/§6; PAPS §6 (NAP-2 "Related Work") | frozen executables rejected because immutable → plugin ecosystem | freezing choice must follow product requirements | HIGH |
| conda constructor | napari | NAPS; PAPS | NAPS §1/§4/§8/§13; PAPS §1-§3 | NSIS/.sh/.pkg installers from conda packages (~600 MB) | package-manager installers, not freezers | HIGH |
| Windows Inno Setup installer | dikte | DIKS | §4, §8 (`dikte.iss`, per-user, `PrivilegesRequired=lowest`) | per-user Inno installer with FFmpeg | Inno is the demonstrated classic-installer path | HIGH |
| Windows Inno Setup installer | pyzo | PZOS | §4 (`installerBuilderScript.iss`, Win64 only) | Inno 5/6, per-user default | Inno confirmed by second project | HIGH |
| Windows NSIS installer | napari | NAPS; PAPS | NAPS §8; PAPS §8 | NSIS via constructor | NSIS observed only via conda toolchain | MEDIUM |
| Windows Authenticode signing | napari | NAPS; PAPS | NAPS §9 (Azure Artifact Signing, final tags); PAPS §9 | signs only final tagged releases; Apple-cert stopgap otherwise | real Windows signing observed only in napari | HIGH |
| Windows signing absent | CARA/CustomKnight/dikte/pyzo | CARAS §9; CKS §9; DIKS §9; PZOS §9 | each "Windows Code Signing" section | no signtool/Authenticode tracked | Windows signing is the largest shared gap | HIGH |
| UPX | CARA | CARAS §7 | `CARA_windows.spec:34-59`; UPX not installed on Windows CI | `upx=True` requested; actual Windows compression unverified | UPX status must not be inferred; treat as unverified | HIGH (unverified) |
| UPX | CustomKnight | CKS §7 | PyInstaller 5.1 default; UPX absent on GH runners by accident | no deliberate UPX policy | "no UPX" is incidental, not deliberate | MEDIUM |
| UPX | napari | NAPS §7 | "no UPX references" | no UPX anywhere | no UPX is the napari norm | HIGH |
| Old-GLIBC Linux base (Ubuntu 22.04) | CARA | CARAS §10 | `build-linux-appbundles.yml` comments (GLIBC 2.38/24.04 failure) | Ubuntu 22.04 for tar.gz amd64/arm64 | build on oldest supported base | HIGH |
| Old-GLIBC Linux base (Ubuntu 22.04) | dikte | DIKS §11 | `build.yml` lines 38-42 | AppImage built on ubuntu-22.04 | same principle, observed for AppImage | HIGH |
| Old-GLIBC Linux base (Ubuntu 22.04) | pyzo | PZOS §10 | `cd.yml` (Ubuntu 22.04) | onedir archives on 22.04 | principle repeated | HIGH |
| GLIBC NOT controlled | CustomKnight | CKS §10 | `ubuntu-latest` | fresh glibc, narrow compatibility, issue #13 crash | negative example | HIGH |
| AppImage | dikte | DIKhd; DIKS | §11 (manual AppDir + appimagetool; `build-appimage.sh`) | only implemented AppImage in the set | manual AppDir + appimagetool is the only observed method | HIGH |
| AppImage absent | CARA/CustomKnight/pyzo | CARAS §11; CKS §11; PZOS §11 | each "AppImage" section | no AppDir/appimagetool | AppImage is not universal | HIGH |
| AppImage removed (legacy) | napari | NAPS §11; PAPS §11 | NAP-2 (Briefcase era) | AppImage/DMG dropped after Briefcase | AppImage has been tried and dropped by napari | HIGH |
| `.deb` absent | all 5 | CARAS §12; CKS §12; DIKS §12; NAPS §12; PZOS §12 | each "Debian Package" section | no `debian/`/`DEBIAN/control` anywhere | zero case-study `.deb` evidence | HIGH |
| DEB model — native deps | (tutorials only) | CARAT §6.1; PZOT §6; DIKT §11 | recommendation sections | recommend `Depends: python3, python3-pyqt6` | native model recommended by 3 tutorials | MEDIUM (recommendation) |
| DEB model — bundled runtime | (tutorials only) | CKT §9.1; NAPT §9; PAPT §6 | recommendation sections | recommend PyInstaller/Nuitka standalone inside the `.deb` | bundled model recommended by 2 tutorials | MEDIUM (recommendation) |
| macOS `.app` | CARA/dikte/pyzo | CARAS §13; DIKS §13; PZOS §13 | each macOS section (`BUNDLE`) | PyInstaller BUNDLE .app | `.app` via PyInstaller is the observed norm | HIGH |
| macOS `.app` (onefile) | CustomKnight | CKS §13 | §13 (`-F -w` creates onefile .app) | onefile .app, zip -r9 | onefile .app is the outlier | HIGH |
| macOS `.pkg` | napari | NAPS §13; PAPS §13 | §13 (constructor pkg; menuinst creates app at install) | .pkg installer; no build-time .app/DMG | package installer route | HIGH |
| macOS Developer ID signing | CARA | CARAS §14 | `build_macos_signed.sh`; entitlements | Developer ID + hardened runtime + timestamp (local) | full macOS signing observed | HIGH |
| macOS Developer ID signing | pyzo | PZOS §14 | `cd.yml` (P12 → temp keychain; `codesign --deep --options runtime --timestamp`) | Developer ID + hardened runtime in CI | full macOS signing in CI | HIGH |
| macOS Developer ID signing | napari | NAPS §14; PAPS §14 | `make_bundle_conda.yml:416-455,534-585` | Developer ID App + Installer certs in CI | full macOS signing in CI | HIGH |
| macOS ad-hoc signing only | dikte | DIKS §14 | `build-dmg.sh` (`codesign --force --deep --sign -`) | ad-hoc only; explicitly not production-grade | ad-hoc is a documented contrast | HIGH |
| macOS signing absent | CustomKnight | CKS §14-15 | §14-15 | no codesign/notarytool | negative example | HIGH |
| Hardened Runtime | CARA/pyzo/napari | CARAS §14; PZOS §14; NAPS §14 | sign commands with `--options runtime` (pyzo); implicit (napari) | hardened runtime used | hardened runtime is part of the professional baseline | HIGH |
| macOS notarization | CARA | CARAS §15 | `build_macos_signed.sh` (notarytool submit --wait, staple) | notarize + staple, local | full notarization observed | HIGH |
| macOS notarization | pyzo | PZOS §15 | `cd.yml` (notarytool keychain-profile, staple) | notarize + staple in CI | full notarization observed | HIGH |
| macOS notarization | napari | NAPS §15; PAPS §15 | `make_bundle_conda.yml:534-585` (API key, staple, spctl) | notarize + staple + spctl in CI | most auditable notarization flow | HIGH |
| macOS notarization absent | dikte/CustomKnight | DIKS §15; CKS §15 | §15 | none | gap in 2 projects | HIGH |
| DMG | pyzo | PZOS §13/§24 | `hdiutil create ... UDZO/HFSX` | DMG created, not separately notarized | DMG observed; DMG notarization NOT verified | MEDIUM |
| DMG | dikte | DIKS §13 | `hdiutil UDZO` per arch | DMG created, unsigned | DMG observed | MEDIUM |
| DMG absent | CARA/CustomKnight/napari | CARAS §13; CKS §13; NAPS §13 | §13 | ZIP / ZIP / PKG | DMG not universal | HIGH |
| GitHub Actions | all 5 | all studies | each CI section | all use GitHub Actions | GHA is universal | HIGH |
| Tag-gated release automation | dikte | DIKS §16 | `release.yml` (rolling + v* tags; `gh release create`) | automated releases | tag-gated release observed | HIGH |
| Tag-gated release automation | pyzo | PZOS §16 | `cd.yml` (`gh release create --verify-tag`) | automated tag release | tag-gated release observed | HIGH |
| Tag-gated release automation | napari | NAPS §16; PAPS §16 | `make_bundle_conda.yml` + caller | tag + nightly release | tag-gated release observed | HIGH |
| Release automation absent | CARA/CustomKnight | CARAS §16; CKS §16 | §16 (manual builds/artifacts) | no release step | gap in 2 projects | HIGH |
| Artifact smoke test | napari | NAPS §16; PAPS §16 | `make_bundle_conda.yml:674-727` | installs and launches artifact in CI | strongest artifact testing | HIGH |
| Artifact smoke test | pyzo | PZOS §16 | `cd.yml` (frozen EXE test; xvfb + log check) | launches frozen app + checks log | artifact testing observed | HIGH |
| Artifact smoke test absent | CARA/CustomKnight/dikte | CARAS §16/§20; CKS §16; DIKS §16 | §16/§20 | no artifact launch in CI | gap in 3 projects | HIGH |
| Dependency pinning | napari | NAPS §16/§20; PAPS §20 | constraints files (`uv pip compile`), conda bounds, PySide6 `<6.11` | real pinning | strongest pinning in the set | HIGH |
| Dependency pinning (top-level `==`) | CustomKnight | CKS §2/§20 | `requirements.txt` (PyQt6==6.3.1, pyinstaller==5.1) | exact top-level pins only | partial pinning | MEDIUM |
| Dependency pinning absent | CARA/dikte/pyzo | CARAS §20; DIKS §20; PZOS §20 | §20 | min versions / unpinned / `pip -U` | no lock discipline | HIGH |
| Reproducible builds | none | all studies | each "Security/Release Integrity" section | no project claims reproducible builds | reproducibility unachieved everywhere | HIGH (negative) |
| Lockfile artifacts | napari | PAPS §3/§20 | `build_outputs: lockfile` | lockfiles generated post-hoc, not used to rebuild | lockfile-as-artifact (documentation, not rebuild) | MEDIUM |
| Release checksums | napari | NAPS §20; PAPS §9/§20 | Windows SHA256 generated; `.sha256` not attached | partial checksums | partial only; attach yours | MEDIUM |
| Release checksums absent | CARA/CustomKnight/dikte/pyzo | CARAS §20; CKS §20; DIKS §20; PZOS §20 | §20 | no SHA256 published | checksums are a universal gap | HIGH |
| Qt plugin curation (excludes) | dikte | DIKS §5/§18 | spec lines 32-47 | excludes unused Qt modules | targeted Qt selection observed | HIGH |
| Qt plugin curation (include/exclude) | pyzo | PZOS §5/§18 | `pyzo_freeze.py` lines 140-200 | exactly Core/Gui/Widgets/PrintSupport; big exclusions | targeted Qt selection observed | HIGH |
| Qt plugin inventory verified | none | all studies | each "Qt Plugins" section | every study says exact inventory is NOT verified | plugin inventories unverified everywhere | HIGH (negative) |
| Qt translations (app) | pyzo | PZOS §19 | `_locale.py` (QTranslator; QLibraryInfo) | ships pyzo_*.qm; tries Qt's | partial; Qt collection unverified | MEDIUM |
| Qt translations absent | CARA/CustomKnight/dikte/napari | CARAS §19; CKS §19; DIKS §19; NAPS §19 | §19 | no QTranslator/.qm | the recurring Qt-translation gap | HIGH |
| Resource resolver (dev/frozen) | CARA | CARAS §17 | `path_resolver.py` (dev / Resources / _internal) | central resolver; no sys._MEIPASS | resolver pattern is highly reusable | HIGH |
| Resource via `__file__` | CustomKnight | CKS §17 | `main.py:112-116` etc. | `os.path.dirname(__file__)` + broken qrc ref | fragile but works by luck | MEDIUM |
| `importlib.resources` | napari | NAPS §17; NAPT §2 | `src/napari/utils/logo.py:9` | used for logos | recommended modern pattern | HIGH |
| `sys._MEIPASS` | pyzo | PZOS §5/§17 | `freeze/boot.py:86` | used to locate shipped source | `_MEIPASS` usage observed (onedir) | MEDIUM |
| External binary env repair | CARA | CARAS §10/§15/§20 | `uci_communication_service.py:60-81` | strips loader vars before engine launch | host-binary environment repair observed | HIGH |
| External binary env repair | dikte | DIKS §11/§20 | `integrate.py:83-117,120-170` | restores LD_LIBRARY_PATH + CA store | host-binary environment repair observed | HIGH |
| External binary pin+hash | dikte | DIKS §4/§11/§20 | `build-windows.ps1` (ffmpeg SHA256) | pinned+hashed FFmpeg | pin+hash downloaded helpers | HIGH |
| CI security lint (zizmor) | napari | PAPS §16/§20 | `zimor.yml` | zizmor workflow linting | supply-chain linting observed | HIGH |
| Actions pinned to SHA | napari | PAPS §16/§20 | `make_bundle_conda.yml` (SHA pins + dependabot) | every action SHA-pinned | SHA pinning observed | HIGH |
| GitHub attestations | napari | NAPS §16/§20 | `make_release.yml:28` (wheels) | attest-build-provenance for wheels | attestations observed (partial) | HIGH |
| QtPy abstraction | napari | NAPS §2 | `src/napari/_qt/__init__.py:4` | QtPy binding abstraction | QtPy is a napari best practice | HIGH |
| multiprocessing.freeze_support | CARA | CARAS §2 | `cara.py:122-206` | guards entry for PyInstaller workers | freeze_support observed | HIGH |

---

## B. Antivirus / VirusTotal evidence (special table)

### B.1 First measurement in this research (TBO, 2026-10)

Until now this section said "no data" throughout: no case-study project had ever
published a detection count. TBO has now been scanned in three builds produced
from the same commit, the same version and the same PE metadata, all unsigned and
all with UPX disabled. The only differences are the freezer and the bundle
layout. Screenshots of the three report pages are kept as primary evidence in
`experiments/pyinstaller-vs-nuitka/evidence/`.

| Artifact | Freezer | Layout | SHA-256 | Size | VirusTotal |
|---|---|---|---|---|---|
| `TBO.exe` | Nuitka | standalone | `9f8a79c1c6cf55cf6700334f585a2e9a61f04ce15eb723bacc0a1c7c20a1818b` | 7,117,824 B | **0 / 71** |
| `tbo-pyinstaller-onedir.exe` | PyInstaller | onedir | `e4fd50350ca15e6f456dd746f04332849db31714375174122275e970e96d840a` | 2,019,109 B | **3 / 73** |
| `tbo-pyinstaller-onefile.exe` | PyInstaller | onefile | `94ba578707ebc5c90591520c8f6c3ce392aa3d1c76bc2100b53413f887acd5f1` | 38,802,576 B | **3 / 73** |

Which engines flagged, and with what:

| Arm | Engine | Detection |
|---|---|---|
| onedir | SecureAge | `Malicious` |
| onedir | Zillya | `Trojan.Script.2226` |
| onedir | Skyhigh (SWG) | `BehavesLike.Win32.Backdoor.rc` |
| onefile | Bkav Pro | `W32.Malware.7730AFD` |
| onefile | Zillya | `Trojan.Script.2226` |
| onefile | SecureAge | `Malicious` |

Both PyInstaller pages aggregate to the popular threat label
`trojan.script/wacatac`, category and family label `trojan`.

**Verified here:** the SHA-256 values were recomputed from the build artifacts on
disk and match the hashes in the VirusTotal links, so the files under discussion
are exactly the ones this repository's CI produced. The per-engine lists are read
from screenshots of the report pages, which are checked in.

**Scale of the result.** Three engines out of 73 — about 4% — and every major
engine reports clean: Microsoft, Kaspersky, BitDefender, ESET, Sophos, Avast,
AVG, Google, Fortinet, CrowdStrike, Palo Alto, Symantec, Trend Micro, McAfee,
SentinelOne and the rest.

**The detections are generic or behavioural, not signature matches.**
`SecureAge → Malicious` names no family; `Skyhigh (SWG) → BehavesLike.…` is
explicitly a behavioural rule; `Trojan.Script.2226` names no real family. And two
of the three flagging engines are shared between the arms while the third differs
(Bkav Pro on onefile, Skyhigh on onedir) — closely related builds disagreeing is
the signature of an unstable heuristic rather than of a signature matching real
malware, which would follow the bytes.

**What this changes.** The most common assumption in this area — that `onedir`
avoids the self-extraction heuristics which make `onefile` look suspicious — is
**not supported**: both PyInstaller layouts scored 3/73 with the same two engines.
The differentiator is PyInstaller's bootloader, not the bundle layout.

**What this does not establish.** A single application, a single build of each
arm, at a single point in time. Conditions to keep in view:

- **n = 1.** The evidence matrix's own rule applies: one sample is noise.
- Unsigned, and versioned `2.0.0.dev0`. Both the absent signature and a
  development version string are themselves weak negative signals.
- Submission history is uncontrolled. A hash VirusTotal has never seen before is
  treated differently from one with a track record.
- TBO is GPL software with a small user base and no download history.
- Scores drift. These screenshots record one moment and must be reproduced, not
  quoted as current.

**Reading.** The pattern that fits all of the above is **generic false positives
from heuristic engines**, not evidence of malware. The correct response is
procedural — submit reports to the vendors involved and carry on — never
obfuscation, packing or binary mutation.

### B.2 Claims table

| Claim | Evidence from projects | Evidence strength | Conclusion | Confidence |
|---|---|---|---|---|
| "PyInstaller causes AV detections" | case studies: none measured. TBO (2026-10): both PyInstaller arms flagged, see B.1 | one controlled measurement, same application as the clean Nuitka arm | **Supported for this application**; not yet evidence of a general rule | MEDIUM (observation HIGH, generalisation LOW) |
| "Nuitka avoids AV detections" | case studies: no project uses Nuitka. TBO (2026-10): the Nuitka arm scored **0 / 71** | one controlled measurement | **Supported for this application**; still anecdote for the general claim | MEDIUM (observation HIGH, generalisation LOW) |
| "onedir eliminates false positives" | TBO (2026-10) directly contradicts it: onedir scored **3 / 73**, identical to onefile, flagged by the same two engines | one controlled measurement, and it is the arm that refutes the claim | **Not supported.** The differentiator appears to be the bootloader, not the layout | MEDIUM |
| Generic engines flag unsigned PyInstaller builds | TBO (2026-10): the 6 detections are `Malicious` (no family), `BehavesLike.…` (behavioural), and unnamed script trojans; two engines shared, the third differs between arms; all major engines clean | one controlled measurement with the per-engine list | Detections of this shape read as heuristic **false positives**; the honest response is a vendor report, not a rebuild | MEDIUM |
| Rebuilding the bootloader avoids the shared-stub detections | PyInstaller's own documentation recommends building the bootloader to "avoid anti-virus false positives that result from the wide-spread use of pre-compiled bootloaders" | primary source (tool documentation), **not measured here** | Plausible and documented, and now implemented as a CI arm in TBO so it can be measured; do not state it as a cure | MEDIUM (documented) / NOT VERIFIED (effect) |
| False-positive reports are what clear the report page | no project in the case set implements the process; the TBO measurement identifies the four engines to contact | recommendation with a concrete target list | Vendors do remove generic detections, and a clean page removes the accusers' evidence; keep a record of submissions and outcomes | MEDIUM |
| Untrusted Windows signature keeps SmartScreen warnings | napari stopgap Apple-cert signature | direct workflow comment (PAPS §7, `make_bundle_conda.yml:470-472`) | Supported: a non-Windows-trusted signature does not remove warnings | HIGH |
| Signing is the intended reputation mechanism | napari (Azure on releases; otherwise warnings) | direct implementation + docs | Supported as a practice | HIGH |
| UPX increases detections | no project measures it; TBO disabled UPX in **all three** arms, so the measurement above says nothing about UPX | general guidance repeated in tutorials | NOT VERIFIED (plausible correlation; avoid it) | LOW |
| Large installer (~600 MB) avoids heuristics | napari | speculation in the study itself | NOT VERIFIED | LOW |
| VirusTotal result = absolute security verdict | none | — | Rejected: VT is a point-in-time, engine-specific signal | HIGH (as a methodological statement) |

---

## C. Contradiction log (short form)

| Contradiction | Side A | Side B | Classification / resolution | Confidence |
|---|---|---|---|---|
| Bundle mode | onefile (CustomKnight) | onedir (CARA/dikte/pyzo) | onedir is the better default; onefile only when a single naked exe is the requirement | HIGH (choice), **refuted as an AV remedy** by TBO B.1 (both layouts flagged) |
| DEB model | native deps (CARA/pyzo/dikte tutorials) | bundled runtime (CustomKnight/napari tutorials) | tradeoff; native preferred when distro `python3-pyqt6` exists; bundled must be disclosed | MEDIUM |
| AppImage construction | manual AppDir + appimagetool (dikte, OBSERVED) | linuxdeploy-plugin-qt (tutorials, RECOMMENDED) | only manual is observed; pin/checksum whichever tool | MEDIUM |
| Freezing vs conda | freezers (4 projects) | conda constructor (napari) | driven by plugin-ecosystem requirement, not preference | HIGH |
| `sys._MEIPASS` | pyzo uses it | CARA avoids it | both work in onedir; centralize in a resolver | MEDIUM |
| Qt collection | `--collect-all PyQt6` (some tutorials) | targeted Qt module selection (dikte/pyzo, OBSERVED) | start with hooks; curate based on measured imports | HIGH (for curating) |
| macOS signing location | local script (CARA) | CI (pyzo/napari) | CI with temp keychain is the repeatable model | MEDIUM |
| `--deep` signing | pyzo/dikte use `--deep` | CARA + tutorials prefer inside-out | inside-out is more auditable; `--deep` is a shortcut | MEDIUM |
| GLIBC base | ubuntu-22.04 (CARA/dikte/pyzo) | ubuntu-latest (CustomKnight) | old base wins; verified failure on the negative side | HIGH |

---

## D. Confidence rules used

- **HIGH** = directly observed in the project's own files/workflows per the
  study, or a negative fact verified by the study (e.g., "no .deb exists").
- **MEDIUM** = observed but with unverified details (e.g., exact Qt plugin
  inventory), or recommendation with partial support, or a single project.
- **LOW** = correlation/anecdote only (e.g., UPX or Nuitka AV claims).
- **NOT VERIFIED** = explicitly unmeasurable from the available studies (most
  antivirus claims).

---

## E. Items that could not be verified from the studies (explicitly)

These were flagged as NOT VERIFIED and must not be treated as facts. Items 1-3
and 6 have since been partially addressed by the TBO measurement in section B.1;
the rest stand unchanged.

1. ~~VirusTotal detection counts / rates for any project.~~ **Partially
   addressed** for exactly one application: the counts and per-engine lists are
   known for three TBO builds (B.1) — Nuitka 0/71, both PyInstaller arms 3/73.
   Rates over time, and behaviour for any other application, remain unknown.
2. SmartScreen behavior of any project's Windows artifact (including napari's
   Azure-signed `.exe`). Still unverified; the TBO measurement did not test
   SmartScreen.
3. ~~Whether onedir vs onefile or PyInstaller vs Nuitka changes detection
   rates.~~ **Addressed for one application** (B.1): PyInstaller flagged in both
   layouts, Nuitka not flagged. Rates remain unknown and n = 1.
4. Whether Azure Artifact Signing materially reduces SmartScreen warnings.
5. The exact Qt plugin/translation inventories inside any frozen artifact.
6. The performance/startup/size tradeoff of PyInstaller vs Nuitka on the same
   application. **Size is now known** for one application (B.1); start-up and
   eventual runtime behaviour are not.
7. Whether CARA's Windows ZIPs are signed outside the repository.
8. The mechanism that produced CustomKnight's separate x64/ARM64 macOS zips.
9. Whether a signed, notarized, stapled DMG flow works as well as
   ZIP/PKG notarization (not demonstrated by any project).
10. The correct `.deb` model for a new project (no project ships one).
11. Actual GLIBC minimum required by bundled Python/PyQt6 wheels beyond the
    Ubuntu 22.04 baseline.
12. Whether UPX is applied to any released Windows artifact.

---

## F. TBO follow-up evidence (2026-08 onwards)

Real fixes applied while packaging **TBO** (github.com/wachin/TBO), a PyQt6 app
built with Nuitka (Windows) and PyInstaller (macOS/Linux) on GitHub Actions.
Recorded in `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md`.

Sections 1-8 are 2026-08; sections 9-11 (the resource-collection defect, the
toolchain pin, and this measurement) are 2026-10.

| Technique | Project | Evidence | Observed behavior | Conclusion | Confidence |
|---|---|---|---|---|---|
| `python3 -m build` module missing in `.deb` CI | TBO | SOLUCIONES §1 | `setup-python` toolcache Python lacks `build`; apt `python3-build` only helps system Python | pip-install `build setuptools wheel` into the active interpreter before `dpkg-buildpackage` | HIGH |
| Skip tests in Qt GUI `.deb` build | TBO | SOLUCIONES §1 | `dh_auto_test` runs `unittest`, tests import `PyQt6` (runtime dep) → fails | `override_dh_auto_test:` to skip; run tests separately in CI | HIGH |
| Nuitka `--file-version` format | TBO | SOLUCIONES §4 | `2.0.0.dev0.0` → `FATAL: Invalid version number` | sanitize to 4-part numeric `2.0.0.0` | HIGH |
| Icons for macOS/PyInstaller | TBO | SOLUCIONES §3 | script expected `build/tmp/TBO.iconset`, generator wrote next to source | pass an explicit output dir to the icon generator | HIGH |
| PyInstaller `--verbose` removed in 6.x | TBO | SOLUCIONES §3 | `unrecognized arguments: --verbose` | remove or use `--log-level=DEBUG` | HIGH |
| License file required by packaging scripts | TBO | SOLUCIONES §2 | `cp: LICENSE: No such file` at end of macOS build | commit `LICENSE` (or point scripts to `COPYING`) from the first commit | HIGH |
| `dpkg-buildpackage` writes to parent dir | TBO | SOLUCIONES §6 | `.deb` built but `upload-artifact` found nothing | `mv ../tbo_*.deb ... ./` before upload | HIGH |
| Node.js 20 action deprecation | TBO | SOLUCIONES §7 | `checkout@v4`/`setup-python@v5`/`upload-artifact@v4` warnings | upgrade to `@v5`/`@v6`/`@v5` | HIGH |
| `.gitignore` cannot hide submodule dirt | pyqt6-packaging-research | `AGENTS.md` §5; `.gitignore` header comment (re-verified — see note below) | untracked files inside submodules still reported | use `ignore = dirty` in `.gitmodules` + `git submodule sync` | HIGH |
| `.deb` audit before install | TBO | `DEBIAN-PACKAGE-AUDIT.md` | lintian + dpkg-deb --info/--contents + apt --dry-run + debsums checklist | audit a built `.deb` before `gdebi`/`apt install`; stop on any failing check | HIGH |
| Bundles build green but ship without the app's own resources | TBO | SOLUCIONES §9 | `--add-data` destinations pointed at loose top-level directories; the code resolves relative to `__file__` (`_internal/tbo/...`) | collect package data to the path the code actually reads, then verify by running the artifact | HIGH |
| One application, three resource-collection mechanisms | TBO | SOLUCIONES §9.4 | Nuitka `--include-package-data` collected correctly; both PyInstaller builds shipped without icons and translations | correct-on-Windows is not evidence that a bundle is correct; verify per platform | HIGH |
| Rolling `continuous` tag used as a checksum pin | TBO | SOLUCIONES §9.5 | the asset was republished 2026-10-04, so the pinned SHA-256 stopped matching and the build failed | pin a **versioned** release; the checksum failing is the desired outcome, the pin choice was wrong | HIGH |
| Icon filename must match `Icon=` in the `.desktop` entry | TBO | SOLUCIONES §9.5 | appimagetool 1.9.1 refuses to build with `Icon=org.tbo.TBO` while the AppDir contains `tbo.png` | name the icon after the application ID; older rolling builds tolerated it | HIGH |
| Green CI is not a working artifact | TBO | SOLUCIONES §9 | five jobs green while the published AppImage had been missing 14 UI icons since August | smoke test the built artifact in CI; nothing else catches a silently incomplete bundle | HIGH |
| Freezer comparison on the real application | TBO | SOLUCIONES §10 | Windows had only ever been built with Nuitka; the PyInstaller false-positive claim was never measured on TBO | a PyInstaller Windows build now exists with identical metadata and no UPX, to be scanned alongside it | HIGH (for the setup) |
| PyInstaller toolchain missing from the comparison job | TBO | SOLUCIONES §10 | CI failed with `No module named PyInstaller`: the job installed `requirements-windows.txt`, the Nuitka toolchain | give each freezer its own requirements file; the job's own exit-code check turned it into a one-line message | HIGH |
| **Measured freezer comparison** | TBO | SOLUCIONES §11; matrix B.1; `experiments/pyinstaller-vs-nuitka/evidence/` | Nuitka **0/71**; PyInstaller onedir **3/73** and onefile **3/73**, flagged by generic or behavioural detections with all major engines clean | for this application the freezer is the differentiator, **not** the onedir/onefile layout; the shape of the detections reads as false positives; n = 1, so treat as a lead, not a rule | MEDIUM (observation HIGH, generalisation LOW) |
| A bare onedir executable published as an artifact | TBO | SOLUCIONES §11.3 | the CI artifact uploads both the complete zip and the loose `.exe`; extracted alone the `.exe` cannot start and was reported as "no funciona" | the loose `.exe` is wanted for scanning, so label it as scan-only rather than shipping it as a runnable app | HIGH |

### Note: re-citation of the `.gitignore` / submodule-dirt row

This row was originally cited to `Añadir_un_git_sub-modulo.md`, which has since
been deleted from this repository (commit `1a356de`, "delete file"). Rather than
restore a deliberately removed file, the behaviour was re-verified directly and
is now documented in two places that exist:

- `AGENTS.md` §5, "Submodule and ignore hygiene";
- the comment block at the head of `.gitignore`.

What was confirmed:

- A submodule is recorded as a gitlink (mode `160000`), and `.gitignore` has no
  effect on a tracked path. The `dikte/` and `napari/` patterns that used to sit
  in `.gitignore` did nothing at all.
- What actually keeps `git status` clean is `ignore = dirty` in `.gitmodules`.
  With `git status --ignore-submodules=none`, the only untracked submodule
  content reported was the research agents' leftover `opencode.json` files.
- Related, and worse in practice: unanchored patterns are actively harmful in
  this repository. A bare `napari/` also matched
  `napari-resultados/_evidence/napari/` and silently excluded **12 real evidence
  files** from git.

Confidence remains **HIGH**: the behaviour was reproduced directly rather than
read from a note.
