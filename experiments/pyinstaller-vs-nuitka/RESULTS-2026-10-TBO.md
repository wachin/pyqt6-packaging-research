# Run record: freezer comparison on a real application (TBO, 2026-10)

This is the first run recorded for this experiment. It used the **real
application** rather than the minimal probe in `app/`, so the numbers are not
comparable with a probe run — but the method is the one this kit exists to make
repeatable.

Detailed write-ups: `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md`
§10-11 and `03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` §B.1.

## Run metadata

| Field | Value |
|---|---|
| Date | 2026-10 |
| Application | TBO 2.0.0.dev0 (github.com/wachin/TBO) |
| Python | 3.12 (GitHub `windows-2025` runner) |
| PyQt6 | pinned via `packaging/requirements-windows*.txt` |
| PyInstaller | 6.x |
| Nuitka | 2.x, `--msvc=latest` |
| Signed? | **no** — all three arms unsigned |
| UPX | **disabled in all three arms** |
| Build workflow | `github.com/wachin/TBO` → *Build executables* |

## Arms

| Arm | Freezer | Layout | SHA-256 | Size | VirusTotal |
|---|---|---|---|---|---|
| `TBO.exe` | Nuitka | standalone | `9f8a79c1c6cf55cf6700334f585a2e9a61f04ce15eb723bacc0a1c7c20a1818b` | 7,117,824 B | **not flagged** |
| `tbo-pyinstaller-onedir.exe` | PyInstaller | onedir | `e4fd50350ca15e6f456dd746f04332849db31714375174122275e970e96d840a` | 2,019,109 B | **flagged** |
| `tbo-pyinstaller-onefile.exe` | PyInstaller | onefile | `94ba578707ebc5c90591520c8f6c3ce392aa3d1c76bc2100b53413f887acd5f1` | 38,802,576 B | **flagged** |

The SHA-256 values were **recomputed from the build artifacts on disk** and match
the hashes in the VirusTotal links, so these are exactly the files TBO's CI
produced.

## VirusTotal

| Arm | SHA-256 submitted | Total detections | Engines | Categories | Report URL |
|---|---|---|---|---|---|
| Nuitka | `9f8a79c1…8181b` | **not captured** | not captured | not captured | `virustotal.com/gui/file/9f8a79c1…8181b` |
| PyInstaller onedir | `e4fd5035…d840a` | **not captured** | not captured | not captured | `virustotal.com/gui/file/e4fd5035…d840a` |
| PyInstaller onefile | `94ba5787…cd5f1` | **not captured** | not captured | not captured | `virustotal.com/gui/file/94ba5787…cd5f1` |

**This is the main weakness of the run.** "Flagged" and "not flagged" is all that
was recorded. Whether the onefile arm was flagged by one heuristic engine or by a
majority changes the interpretation completely, and the difference between a
generic heuristic name and a named malware family is the difference between a
known false-positive pattern and something worth investigating properly.

## Other measurements

Not captured: start-up time, installed tree size, `QT_DEBUG_PLUGINS=1` output,
SmartScreen behaviour.

## Observations

- **The bundle layout was not the differentiator.** Both PyInstaller arms were
  flagged, onedir included. The common factor is PyInstaller's bootloader, not
  the self-extracting wrapper — which is the opposite of the assumption the
  research previously carried as "plausible but unmeasured".
- **Sizes are not comparable as download sizes.** The onedir arm's executable is
  only 1.9 MB because the payload sits in the sibling `_internal/` tree; the
  onefile arm is 37 MB because it embeds everything. Compare the *portable zip*
  sizes, not the bare executables.
- **A published bare `.exe` from the onedir arm confuses users.** The CI artifact
  contains both the complete zip and the loose executable (the latter is what you
  submit for scanning). Extracted alone, without `_internal/`, the loose
  executable cannot start and was reported as "does not work". It is scan-only and
  should be labelled as such.

## Conclusion for this run

For this application, on this day, the PyInstaller builds were flagged and the
Nuitka build was not.

It is **n = 1**, unsigned, on a GPL application with no download history, with no
detection counts. It is a lead worth pursuing, not a rule, and it must not be
restated as "PyInstaller causes detections" or "Nuitka avoids them".

## Follow-ups

- [ ] Capture the detection count, engine names and categories for each artifact.
- [ ] Repeat across several releases.
- [ ] Repeat with Authenticode signing — a signature changes heuristics and none
      of these arms was signed.
- [ ] Isolate the cause: is it the PyInstaller bootloader specifically? Compare
      against a PyInstaller build with a locally rebuilt bootloader.
- [ ] If a false positive appears: capture engine, malware name, SHA-256 and
      source URL, then submit through that vendor's official false-positive
      portal. Track the response. Do not obfuscate, pack or mutate the binary.
