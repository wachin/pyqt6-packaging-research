# Run record: freezer comparison on a real application (TBO, 2026-10)

This is the first run recorded for this experiment. It used the **real
application** rather than the minimal probe in `app/`, so the numbers are not
comparable with a probe run — but the method is the one this kit exists to make
repeatable.

Primary evidence: the VirusTotal screenshots in `evidence/`.
Detailed write-ups: `03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md`
§10-11 and `03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md` §B.1.

## Run metadata

| Field | Value |
|---|---|
| Date | 2026-10-14 |
| Application | TBO 2.0.0.dev0 (github.com/wachin/TBO) |
| Python | 3.12 (GitHub `windows-2025` runner) |
| PyQt6 | pinned via `packaging/requirements-windows*.txt` |
| PyInstaller | 6.x |
| Nuitka | 2.x, `--msvc=latest` |
| Signed? | **no** — all three arms unsigned |
| UPX | **disabled in all three arms** |
| Build workflow | `github.com/wachin/TBO` → *Build executables* |

## Result

| Arm | Freezer | Layout | SHA-256 | Size (bytes) | VirusTotal |
|---|---|---|---|---|---|
| `TBO.exe` | Nuitka | standalone | `9f8a79c1c6cf55cf6700334f585a2e9a61f04ce15eb723bacc0a1c7c20a1818b` | 7,117,824 | **0 / 71** |
| `tbo-pyinstaller-onedir.exe` | PyInstaller | onedir | `e4fd50350ca15e6f456dd746f04332849db31714375174122275e970e96d840a` | 2,019,109 | **3 / 73** |
| `tbo-pyinstaller-onefile.exe` | PyInstaller | onefile | `94ba578707ebc5c90591520c8f6c3ce392aa3d1c76bc2100b53413f887acd5f1` | 38,802,576 | **3 / 73** |
| `tbo-pyinstaller-rebuilt-onefile.exe` | PyInstaller, **bootloader compiled from source** | onefile | `107d539b5f26d2c652919b6ce6fc8fd954b99bc992b204117611c81ca94c16a2` | 38,803,385 | **2 / 70** |

The SHA-256 values were **recomputed from the build artifacts on disk** and match
the hashes in the VirusTotal links, so these are exactly the files TBO's CI
produced.

## Which engines flagged, and with what

| Arm | Engine | Detection |
|---|---|---|
| onedir | SecureAge | `Malicious` |
| onedir | Zillya | `Trojan.Script.2226` |
| onedir | Skyhigh (SWG) | `BehavesLike.Win32.Backdoor.rc` |
| onefile | Bkav Pro | `W32.Malware.7730AFD` |
| onefile | Zillya | `Trojan.Script.2226` |
| onefile | SecureAge | `Malicious` |
| onefile, rebuilt bootloader | Bkav Pro | `W32.Malware.7730AFD` |
| onefile, rebuilt bootloader | SecureAge | `Malicious` |

The rebuilt-bootloader build lost Zillya and kept the other two. Both
PyInstaller pages aggregate to the popular threat label `trojan.script/wacatac`,
with `trojan` as the category and family label.

## The other platforms, same release

The Windows detections turn out to be specific to the Windows binary. Two further
scans of the same release, screenshots in `evidence/`:

| Artifact | Format submitted | Result |
|---|---|---|
| `TBO-2.0.0.dev0-x86_64.AppImage` | the ELF executable itself (`c065c1c3…`) | **0 / 64** |
| `tbo-macos.zip` | a ZIP containing another ZIP (`22d5d093…`) | **0 / 73**, but ~22 engines reported **Timeout** |

**The AppImage result is the informative one.** Three of the four engines that
flag the Windows `.exe` — **Bkav Pro**, **Skyhigh (SWG)** and **Zillya** — scanned
this AppImage and reported it **clean**. Only SecureAge could not process it
("Unable to process this file type", which several Windows-only engines also
reported for an ELF).

The AppImage's payload is itself a PyInstaller `onedir` build, so the same
toolchain, the same bootloader family and the same embedded CPython are all
present in a file those engines find harmless. That sharpens the conclusion from
observation 5: **the detections are specific to the Windows PE binary**, not to
PyInstaller's contents in general. It also reads better than the first
interpretation of the bootloader test — the bootloader *is* a Windows PE stub, and
rebuilding it changed the bytes without changing the structure the heuristic
reacts to.

**The macOS result is weak evidence and should not be quoted as a clean scan.**
The submitted file was a ZIP containing a second ZIP, and the engines listed
against it mostly report Timeout rather than Undetected — including two of the
engines relevant here (Zillya, Skyhigh SWG). To make it meaningful, submit the
Mach-O binary itself, from `TBO.app/Contents/MacOS/TBO` inside the `.app`.

## Observations

**1. The magnitude is small, and the pattern is heuristic.** Three engines out of
73 — about 4% — and every one of the industry's major engines reports clean:
Microsoft, Kaspersky, BitDefender, ESET, Sophos, Avast, AVG, Google, Fortinet,
CrowdStrike, Palo Alto, Symantec, Trend Micro, McAfee, SentinelOne, Ikarus,
Elastic, Vipre, Webroot, Xcitium and the rest of the 73.

**2. The detections are generic or behavioural, not signature matches.** Two of
the six are `SecureAge → Malicious` (no family named at all) and
`Skyhigh (SWG) → BehavesLike.Win32.Backdoor.rc`, which is explicitly a behavioural
rule. `Trojan.Script.2226` names no real family either. Nothing here names a
specific malware that anyone could act on.

**3. Two of the three flagging engines are shared, the third differs.** SecureAge
and Zillya flag **both** PyInstaller arms identically; the third engine is Bkav
Pro on onefile and Skyhigh on onedir. Two closely related builds of the same code
disagreeing about the third detection is the signature of an unstable heuristic,
not of a signature matching a real threat — a genuine detection would tend to
follow the bytes.

**4. The bundle layout is not the differentiator.** Both PyInstaller layouts
scored 3/73, with the same two engines. This refutes the common assumption that
`onedir` avoids the self-extraction heuristics that make `onefile` suspicious.

**5. Rebuilding the bootloader did not fix it, and that is the most useful
result here.** PyInstaller documents building the bootloader from source as a way
to avoid false positives caused by the widely shared pre-compiled stub, so a
fourth arm was built with the bootloader compiled locally:

| Arm | Result |
|---|---|
| onefile, stock bootloader | 3 / 73 — Bkav Pro, Zillya, SecureAge |
| onefile, **rebuilt** bootloader | 2 / 70 — Bkav Pro, SecureAge |

Zillya disappeared, so the bootloader is not irrelevant. **But Bkav Pro and
SecureAge flagged it anyway**, which refutes the hypothesis: if the shared stub
were the cause, new bytes would have cleared it.

Combined with observation 4, this narrows the cause. The **onedir** arm was
flagged too and onedir does not self-extract, so it is not the extraction step
either. The common factor across all four PyInstaller builds is the **embedded
CPython runtime and PyInstaller's archive format**. Changing the bootloader cannot
touch that, which is why the Windows PyInstaller arms were removed from TBO's CI.

**6. `wacatac` is a family name with a false-positive reputation.** VirusTotal's
popular threat label is an aggregate, and it is worth knowing that it is widely
associated with generic false positives on installers.

The reading that fits all six observations is **generic false positives from
heuristic engines**, not evidence of malware.

**7. Sizes are not comparable as download sizes.** The onedir arm's executable is
2.0 MB because the payload sits in the sibling `_internal/` tree; the onefile arm
is 38.8 MB because it embeds everything. Compare the *portable zip* sizes, not the
bare executables.

**8. A published bare `.exe` from the onedir arm confuses users.** The CI
artifact contains both the complete zip and the loose executable (the latter is
what you submit for scanning). Extracted alone, without `_internal/`, the loose
executable cannot start and was reported as "does not work". It is scan-only and
should be labelled as such.

## Conclusion for this run

For this application, on this day: **Nuitka 0/71, PyInstaller 3/73 in both
layouts, and 2/70 with a rebuilt bootloader**, with the detections coming from a
small number of engines whose verdicts are generic and mutually inconsistent.

That confirms the *direction* of the long-standing claim — PyInstaller was
flagged and Nuitka was not — while showing that the *severity* is far lower than
"flagged as a virus" suggests.

It also closes the one build-side hypothesis worth testing: **rebuilding
PyInstaller's bootloader does not clear it.** One detection went away and two
stayed, and because the non-self-extracting `onedir` arm was flagged as well, the
remaining cause is the embedded CPython runtime and PyInstaller's archive format
— neither of which the developer controls.

And it locates the problem precisely: **it is specific to the Windows PE
binary.** The same release's AppImage, whose payload is also a PyInstaller build,
was scanned by three of the four flagging engines and came back clean. So this is
not a reason to abandon PyInstaller on Linux or macOS — the AppImage and the
`.app` are judged on different terms.

It still does not establish that PyInstaller causes detections in general: **n = 1**,
unsigned, on a GPL application with no download history.

## Recommended response

These look like false positives, and the correct handling is procedural, not
technical:

- Do **not** rebuild, obfuscate, pack or mutate the binary to make a scanner
  quieter. That is evasion, and it is both wrong and counterproductive. The
  rebuilt-bootloader arm above is the legitimate version of "rebuild" — compiling
  the tool from its own source — and it still was not enough.
- Submit a false-positive report to the engines involved, through each vendor's
  official channel. For Bkav Pro, SecureAge and Zillya (the stock builds) and
  **Skyhigh (SWG)** (onedir). Include: the SHA-256, the detection name, the
  project's source URL, and a one-line explanation that it is an unsigned
  PyInstaller build of an open-source PyQt6 application. This is the only measured
  route to a clean report page.
- Consider **signing**: it is the one lever not yet tried here, and the research
  supports it for reputation.
- Or use a freezer that is not flagged. For TBO the answer was Nuitka, which
  scored 0/71 on the same application, and its Windows PyInstaller arms have since
  been removed from CI.

## Follow-ups

- [x] Capture the detection count and engine names — done, see above.
- [x] Test the bootloader hypothesis — done, and **refuted**: 3/73 → 2/70.
- [ ] Scan the rebuilt **onedir** arm too. It was built (`ab2c30ff…`, 2,019,621 B)
      but only the rebuilt onefile was submitted, so one data point is missing.
- [ ] Repeat across several releases. One build set does not separate a property
      of the tool from a coincidence of that build.
- [ ] Repeat with Authenticode signing. A signature changes heuristics and none of
      these arms was signed — this is now the most valuable arm to add.
- [ ] If a vendor clears a detection, record when, so the trend is visible.
