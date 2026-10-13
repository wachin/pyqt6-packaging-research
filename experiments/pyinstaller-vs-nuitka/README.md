# Controlled experiment: PyInstaller vs Nuitka

This directory turns §31 of
[`MASTER_PYQT6_PACKAGING_GUIDE.md`](../../03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md)
into something that can actually be run.

It exists because of the largest single gap in the research. Reading five real
projects established a great deal about *packaging practice*, but the evidence
matrix records that:

> **No project records any antivirus / VirusTotal / SmartScreen measurement.**

So the repository's headline question — does PyInstaller or Nuitka change
false-positive behaviour? — is **not answered by the case studies**, and cannot
be. No amount of reading replaces building the four artifacts and measuring
them.

## What this experiment can and cannot establish

**Can establish**, for one exact application, one exact toolchain and one point
in time:

- artifact size and installed-tree size per arm;
- start-up time (coldest sample and warm median) per arm;
- build time and build-log differences;
- whether each artifact runs on a machine without Python or Qt installed;
- the VirusTotal result for each exact set of bytes, with engine names and
  categories;
- whether Windows shows a SmartScreen prompt for each downloaded artifact.

**Cannot establish:**

- that a detection is *true*. A single heuristic hit on an unsigned bootloader
  is not evidence of malware.
- what any engine will report tomorrow.
- that a result transfers to a **different** application. Bundle contents drive
  heuristics; a minimal probe is a baseline, not a verdict about your app.
- anything at all from a single build. One sample is noise.

Treat a VirusTotal number as a **release-quality signal to investigate**, never
as a score to optimise or as proof of safety. That framing is deliberate: this
is reputation and distribution research, not evasion research. Nothing here —
and nothing that should be added here — obfuscates, packs, mutates or otherwise
tries to defeat a scanner.

## The four arms

| Arm | Tool | Layout | Expected profile |
|---|---|---|---|
| **A** | PyInstaller | `onedir` | The demonstrated default in CARA, dikte and pyzo. |
| **B** | PyInstaller | `onefile` | Self-extracting single executable; the CustomKnight negative example. |
| **C** | Nuitka | `standalone` | Compiled; **no case study in this repository uses Nuitka at all.** |
| **D** | Nuitka | `onefile` | Compiled + self-extracting. |

## Variables held constant

Getting this wrong makes the whole exercise worthless, so each item is enforced
somewhere in the kit:

| Variable | How it is held constant |
|---|---|
| Application source | One probe app, `app/main.py`, used by all four arms. |
| Bundled data | The same `app/resources/` directory, collected by every arm. |
| Python version | A single workflow input applied to all arms. |
| PyQt6 version | `app/requirements.txt` plus an explicit pin in the workflow. |
| PE identity metadata | `app/version_info.txt` for PyInstaller; identical values as flags for Nuitka. |
| UPX | Disabled in every arm, including Nuitka, where it is not involved at all. |
| OS image | The same `windows-latest` runner for all arms. |
| C toolchain | `--msvc=latest` for Nuitka, so the compiler is not a hidden variable. |
| Signing | Off by default; when enabled, applied identically to every arm. |

Run the whole experiment **twice**: unsigned first, then signed with the same
real certificate. A signature changes heuristics and SmartScreen reputation, so
an unsigned-only conclusion does not transfer to signed releases. Never mix
signed and unsigned arms in one comparison.

## Running it

### In CI (the intended path)

The workflow needs to sit at the repository root, because GitHub only reads
`.github/workflows/` there:

```bash
cp experiments/pyinstaller-vs-nuitka/workflow-experiment.yml \
   .github/workflows/experiment.yml
```

Then trigger **Actions → Packaging experiment - PyInstaller vs Nuitka → Run
workflow**. It produces four artifacts, a per-arm manifest with SHA-256 and size,
a start-up measurement, a frozen toolchain list, and a combined summary.

### Locally on Windows

```powershell
cd experiments/pyinstaller-vs-nuitka
python -m pip install -r app/requirements.txt
python -m pip install "pyinstaller==6.13.0" "nuitka==2.7.12"

python -m PyInstaller --noconfirm --clean --distpath dist/arm-a-onedir `
  --workpath build/arm-a-onedir build/pyinstaller_onedir.spec
python -m PyInstaller --noconfirm --clean --distpath dist/arm-b-onefile `
  --workpath build/arm-b-onefile build/pyinstaller_onefile.spec
./build/build_nuitka.ps1 -Arm standalone
./build/build_nuitka.ps1 -Arm onefile

./measure/measure_startup.ps1 -Exe dist/arm-b-onefile/PackagingProbe.exe
```

### Locally on Linux or macOS

Only the PyInstaller arms apply. All four files in `build/pyinstaller_*` and the
probe app are cross-platform; the Nuitka script is Windows-only because that is
where the comparison matters.

```bash
cd experiments/pyinstaller-vs-nuitka
python3 -m PyInstaller --noconfirm --clean \
  --distpath dist/arm-a-onedir --workpath build/arm-a-onedir \
  build/pyinstaller_onedir.spec
```

## Recording a run

Copy `RESULTS-TEMPLATE.md` and fill it in. Record the artifact SHA-256 next to
every measurement: without the hash, the numbers describe nothing in particular,
because builds are not reproducible. That is itself one of the findings in the
evidence matrix.

## Validation status of this kit

Be sceptical of tooling that has never been executed:

| Component | Status |
|---|---|
| Probe app (`app/main.py`) | **Verified** — runs from source and from both PyInstaller arms. |
| `build/pyinstaller_onedir.spec` | **Verified** — built and launched on Linux. |
| `build/pyinstaller_onefile.spec` | **Verified** — built and launched on Linux. |
| `workflow-experiment.yml` | **Not executed.** YAML is valid and the job graph is checked; it has never run on a GitHub runner. |
| `build/build_nuitka.ps1` | **Not executed.** No Nuitka available on the machine where this kit was written. Flags follow Nuitka's documented interface and the TBO lessons, but treat the first run as a test. |
| `measure/measure_startup.ps1` | **Not executed.** Untested on a Windows runner; the start-up step in the workflow is `continue-on-error` for that reason. |

The honest summary: the PyInstaller half is exercised, the Nuitka half and the
CI workflow are written but unproven. The first CI run should be treated as
debugging, not as data.

## First local run (Linux, smoke test only)

The two PyInstaller arms were built and launched on Linux to prove the kit
works. **These numbers are not experiment results**: they are Linux, unsigned,
single-sample, and carry no antivirus data. They are recorded only because one
of them is counter-intuitive enough to be worth knowing before designing the
Windows run.

| | A — onedir | B — onefile |
|---|---|---|
| Executable | 1.49 MB | 79.3 MB |
| Full bundle on disk | **206.9 MB** | 79.3 MB |
| `_internal/` | 197 MB | n/a (temporary `_MEIPASS` extraction) |
| `_internal/PyQt6` | 24 MB | n/a |
| Resolved data directory | `_internal/resources` | `/tmp/_MEI…/resources` |
| Start-up, module start to window visible | 0.234 s | 0.151 s |

Two things to carry into the Windows run:

1. **onedir is not automatically the smaller option.** Uncompressed, it is
   *larger* on disk than the compressed onefile: 207 MB against 79 MB. onefile
   pays its cost at every launch (extraction to a temporary directory) rather
   than in download size.
2. **This spec excludes nothing.** A 197 MB `_internal/` is what happens when
   every Qt module is collected. It is precisely the problem that dikte and
   pyzo solve with targeted Qt excludes — see the evidence packs at
   `dikte-resultados/_evidence/packaging/dikte.spec` and
   `pyzo-resultados/_evidence/freeze/pyzo_freeze.py`. The experiment holds
   collection strategy constant on purpose; a follow-up run should add a third
   PyInstaller arm with curated excludes to quantify what curation is worth.
