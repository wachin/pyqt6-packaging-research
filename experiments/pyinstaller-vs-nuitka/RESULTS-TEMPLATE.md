# Experiment run record

Copy this file to `RESULTS-<YYYY-MM-DD>.md` for each run. One record per run; a
single run is noise, and the comparison only becomes meaningful across several
builds and several releases.

## Run metadata

| Field | Value |
|---|---|
| Date (UTC) | |
| Operator | |
| Probe app version | `1.0.0.0` |
| Python | |
| PyQt6 | |
| PyInstaller | |
| Nuitka | |
| Runner / OS image | |
| Nuitka C toolchain | `msvc` |
| Signed? | no / yes — certificate subject: |
| Workflow run URL | |
| Toolchain freeze file | `dist-toolchain-<arm>.txt` |

> Record the **frozen** toolchain list, not the intended pins. If the two
> differ, the intended pins are fiction.

## Per-arm results

| | A — PyInstaller onedir | B — PyInstaller onefile | C — Nuitka standalone | D — Nuitka onefile |
|---|---|---|---|---|
| Primary artifact | | | | |
| SHA-256 | | | | |
| Download size (bytes) | | | | |
| Installed tree size (bytes) | | | | |
| Build time (s) | | | | |
| Coldest start-up (s) | | | | |
| Warm median start-up (s) | | | | |
| Start-up runs (N) | | | | |
| Launches with no Python/Qt installed | | | | |
| `QT_DEBUG_PLUGINS=1`: missing plugins | | | | |
| PE version metadata present | | | | |
| Signature status | | | | |
| SmartScreen prompt on download | | | | |

### VirusTotal

One row per artifact. Use the **final** bytes — rescan after signing, and after
any other mutation.

| Arm | SHA-256 submitted | Total detections | Engines | Categories (malware / PUA / heuristic) | Report URL | Date |
|---|---|---|---|---|---|---|
| A | | | | | | |
| B | | | | | | |
| C | | | | | | |
| D | | | | | | |

> A detection count is a point-in-time, engine-specific signal. It is not a
> security verdict, and it is not a score to optimise. Record the engine names
> and claimed categories, because "1/70" and "1/70 by a single heuristic engine
> with a generic name" are different facts.

## Observations

What differed between the arms beyond the numbers above? Build warnings, missing
Qt plugins, antivirus interference during the build, unexpected files in the
bundle, differences in the installed tree.

-

## Failed checks and workarounds

Record anything that did not work on the first attempt. These are the most
reusable output of the whole experiment — more useful than the numbers, which
age quickly.

-

## Conclusion for this run

State what the data supports **and what it does not**. If nothing separated
cleanly, say so; "no measurable difference on this application" is a valid and
useful result.

-

## Follow-ups

- [ ] Repeat unsigned/signed.
- [ ] Repeat with the real application as a second phase.
- [ ] If a false positive appeared: capture engine, malware name, SHA-256 and
      source URL, then submit through the vendor's official false-positive
      portal. Track the response in the release notes. Do not obfuscate.
