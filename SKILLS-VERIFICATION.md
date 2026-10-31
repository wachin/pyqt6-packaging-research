# Skill verification: can these Skills actually produce the five artifacts?

Audited on 2026-10-30, after the Lucio IVA Calculator study was added and TBO's
evidence was regenerated. It answers one question:

> Following only `.dsh/skills/`, can an agent produce, for a PyQt6 application:
> an AppImage, a `.deb`, a portable macOS `.zip`, a portable Windows `.zip` and a
> Windows installer — and does that generalise beyond the five projects studied?

## 1. Method

1. Read all six Skills end to end.
2. Mapped every section against the five requested artifacts and against the
   *freezer* each one needs (Nuitka on Windows, PyInstaller elsewhere).
3. Checked every factual claim against the pinned evidence pack it cites —
   `my-PyQt6-Apps/*-resultados/_evidence/` and `<project>-resultados/_evidence/`.
4. Re-measured, where possible, on real artifacts (the Lucio installer) and on
   this machine (the Debian package names).
5. Fixed what did not hold up. **Ten defects were found**, three of them material:
   a Skill that contradicted its own evidence, a pin that could not run, and a
   missing procedure for one of the five artifacts.

What this audit did **not** do: execute the Skills end to end on a brand-new
application. There is no such application in this repository, and inventing one
would not have made the result more trustworthy — see section 5.

## 2. Coverage matrix

| Requested artifact | Freezer needed | Skill and section | Status |
|---|---|---|---|
| **AppImage** (Ubuntu, Debian) | PyInstaller onedir (Nuitka works too) | `pyqt6-appimage-packaging` §1-§7 | **Covered** — AppDir layout, `AppRun`, pinned and checksum-verified `appimagetool`, GLIBC floor, external-binary repair, desktop entry, pre-publish verification |
| **`.deb`** (Ubuntu, Debian) | none — native `python3-pyqt6` | `pyqt6-deb-packaging` §1-§6 | **Covered and validated on a real package** (TBO's) — layout, `control`, `rules` with the `dh_auto_test` trap, `changelog`, the CI failures that actually happened, post-build audit |
| **macOS portable `.zip`** | PyInstaller `-D` + `BUNDLE` | `pyqt6-macos-signing-notarization` §1 | **Covered after this audit** — `BUNDLE` recipe, `ditto -c -k --sequesterRsrc`, arch naming, and the unsigned/Gatekeeper path. Signing and notarization are documented but not exercised (no certificate) |
| **Windows portable `.zip`** | **Nuitka `--standalone`** | `pyqt6-windows-installer-signing` §1 | **Covered after this audit** — Nuitka invocation with the traps that break builds, plus the archive rules: one top-level folder, forward slashes, shape post-conditions |
| **Windows `setup.exe`** (NSIS) | **Nuitka `--standalone`** + `makensis` | `pyqt6-windows-installer-signing` §1, §4 | **Covered and measured** — the published Lucio installer's metadata was parsed from the binary; per-user scope, MUI, bilingual UI, `/D` version injection, silent-install test in CI; and since 2026-10-31 the layout that measured clean (6 pages, 4 sections, bitmaps, `XPStyle`) with a pinned compiler version |
| Checksums, pinning, provenance, artifact tests | — | `pyqt6-release-integrity` | **Covered** |
| Which tool for which platform | — | `pyqt6-packaging-decisions` | **Covered after this audit** — a route table for exactly these five artifacts |

Deliberately **not** covered, and stated as such in the Skills: Flatpak, Snap,
MSI/MSIX, and code signing as an *executed* procedure.

## 3. Defects found and fixed

| # | Skill | What was wrong | Fix |
|---|---|---|---|
| 1 | decisions §2 | *"No case study uses Nuitka at all"* and *"NOT VERIFIED"*, contradicting §4 of the same file, which shows the 0/71 vs 3/73 measurement | Rewritten: Nuitka is the Windows default on the strength of two data points, PyInstaller keeps Linux and macOS, with the costs stated |
| 2 | decisions §4 | *"the differentiator looks like PyInstaller's bootloader"* — **contradicted by the evidence**: the rebuilt-bootloader arm scored 2/70, which refutes exactly that | Corrected: `onedir` is not the cause and the bootloader is not the cause; what remains is the embedded CPython runtime and PyInstaller's archive format |
| 3 | decisions §4 | "One controlled measurement… **n = 1**", three arms | Four arms, and Lucio's separately reported pair (`0/68`, `0/65`) added; now n = 2 applications, one self-reported |
| 4 | decisions §3 | "none of the **five** upstream case studies ships a `.deb`" | six |
| 5 | appimage §3 | `APPIMAGETOOL_VERSION=13` and `APPIMAGETOOL_SHA256=<digest>` — an unpinnable placeholder that cannot run | Real pinned release `1.9.1` with the digest verified in the evidence pack, plus the story of why `continuous` broke CI |
| 6 | windows §1 | Only a PyInstaller spec, although both Windows deliverables require **Nuitka** | Nuitka invocation added, with `--enable-plugin=pyqt6`, `--include-data-dir=SRC=DEST`, four-part versions, `ordered-set`/`zstandard`, and "do not hardcode the `.dist` name" |
| 7 | windows | **No portable-ZIP procedure in any Skill.** The knowledge that a Windows ZIP needs forward slashes, one top-level folder and a licence *inside* it lived only in a case-study tutorial | New subsection: the bad and good layouts, why `Compress-Archive` is not enough, a Python builder with post-conditions, and the PowerShell `Copy-Item` contents-vs-folder trap |
| 8 | macos §1 | No step that produces the `.zip`, and no guidance for shipping unsigned — the actual situation for anyone without a paid Apple account | `ditto` recipe, "do not wrap a zip in a zip", arch naming, and an unsigned-release subsection with the Gatekeeper consequence and the right-click → Open workaround |
| 9 | deb §2 | The `Depends` example gave only `python3-pyqt6` | The PyQt6 Debian module split, measured on Debian 13 — see section 4 |
| 10 | decisions | The "where to go next" table was a list of questions, not a route to the five artifacts; the evidence path predated `my-PyQt6-Apps/` | A five-row route table with freezer, skill and section per artifact |
| 11 | windows §3, §4 | Inno Setup was presented as *the* demonstrated installer path and the compressor as a cosmetic trade. Neither reflects what decides a verdict: the installer's shape | §4 now leads with the measured layout (6 pages, 4 sections, header and welcome bitmaps, `XPStyle`) and a pinned `makensis`; §3 marks Inno as working but unmeasured; the compressor section says plainly that size and compression are not levers |
| 12 | windows, decisions | Neither Skill mentioned the installer as a variable separate from the freezer, although a controlled measurement of exactly that existed | The 2026-10-31 wrapper measurement is now in decisions §4 and windows §4, with the record in `PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/lucio-iva-calculator-results/INSTALLER_WRAPPER_EXPERIMENT.md` |

### Two corrections this audit made against itself

Both are worth recording, because they are the reason the method is "check, then
write down what happened" rather than "write down what seems true".

**`QtPrintSupport`.** The first draft of fix #9 claimed that an app importing it
needs its own Debian package. Checking on a real system disproved that, and the
Skill now carries the measured table instead:

| Package | Ships |
|---|---|
| `python3-pyqt6` | QtCore, QtGui, QtWidgets, QtNetwork, **QtPrintSupport** |
| `python3-pyqt6.qtsvg` | QtSvg, QtSvgWidgets |
| `python3-pyqt6.qtpdf` | QtPdf, QtPdfWidgets |

Verified with `dpkg -L` on Debian 13 (trixie), where all ten package names used
by the `.deb` Skill resolve: `debhelper`, `dh-python`,
`pybuild-plugin-pyproject`, `python3-all`, `python3-setuptools`, `python3-build`,
`python3-wheel`, `python3-pyqt6`, `python3-pyqt6.qtsvg`, `python3-pyqt6.qtpdf`.

**The path check in section 6.** Its first version matched only
`<name>-resultados/_evidence/…` and silently dropped the `my-PyQt6-Apps/` prefix,
so it reported five evidence paths as missing when they were present. The regex
now includes the optional prefix, and the snippet below is the corrected one that
was actually run.

### Measurements behind the Windows sections

Parsed from the published `LucioIVACalculator-0.1.1-nuitka-setup.exe`
(30,666,770 bytes, SHA-256 `4d8cda49…f55c12`), not quoted from prose:

- `RT_VERSION`: `VS_FIXEDFILEINFO` gives `FileVersion=0.1.1.0` and
  `ProductVersion=0.1.1.0`; all eight `VIAddVersionKey` strings are present, with
  `OriginalFilename = LucioIVACalculator-0.1.1-nuitka-setup.exe`.
- Authenticode security directory: offset 0, size 0 — **unsigned**, in the
  installer *and* in the portable executable inside the ZIP.

And from the 2026-10-31 wrapper experiment
(`PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/lucio-iva-calculator-results/INSTALLER_WRAPPER_EXPERIMENT.md`):
four installers built from one Nuitka payload, only the wrapper changed, and the
only clean one was built with the reference layout and `makensis` 3.12.0. Its
compile statistics match the Lucio installer exactly — 6 pages, 4 sections, an
8,288-byte section table, 280 uninstall instructions and a 39,936-byte compressed
header — which is what "the same layout" means in practice, beyond copying the
directives.

## 4. Does it generalise beyond these five projects?

The Skills are written against placeholders (`MyApp`, `myapp`, `org.example.myapp`)
and contain no application-specific assumption. What is project-specific is only
the *evidence citation*: each Skill points at the pinned files it was derived
from, and a reader is expected to follow the procedure, not the project.

To apply them to a different PyQt6 application, an agent has to change this much:

| Placeholder | Where | Note |
|---|---|---|
| `MyApp` / `myapp` | every recipe | must match the executable name; PyInstaller derives it from `--name`, Nuitka from `--output-filename` |
| `org.example.myapp` / `org.lucio.iva-calculator` | macOS `bundle_identifier` | reverse-DNS, stable forever; changing it resets permissions |
| Inno `AppId` GUID | `[Setup]` | stable forever, or upgrades install side by side |
| `.desktop` `Icon=` and `StartupWMClass` | AppImage and `.deb` | the icon name must equal the shipped file name without extension |
| `--add-data` / `--include-data-dir` destinations | all three freezers | must equal what the code resolves at runtime — the single most common freezing bug in this research |
| Pinned versions | requirements files | `==`, not `>=` |
| PyQt6 module list | `.deb` `Depends` | see section 3 |
| Architecture matrix | CI | build per-arch rather than trusting an untested universal build |

**What does not generalise, and the Skills say so:** the antivirus measurement.
Two applications, Windows only, one self-reported. An agent must not turn it into
"PyInstaller causes detections" or "Nuitka avoids them", and it must never propose
obfuscation, packing or binary mutation — the response to a false positive is a
report to the vendor.

## 5. What is still not verified

Stated plainly, because a Skill is followed confidently:

- **No Skill has been executed end to end on a new application.** The coverage
  above is procedural and grounded in projects that shipped these exact artifacts;
  that is strong evidence, not proof. The first real test is the next application.
- **The signing paths are documented, not exercised.** Nobody in this research has
  a Developer ID or an Authenticode certificate, so `notarytool`, `stapler` and
  `signtool` sequences are transcribed from pyzo, CARA and napari rather than run.
- **The NSIS uninstaller is read, not run.** No CI job uninstalls and checks.
- **`--include-data-dir` remains a template.** It has not been compiled here.
  `makensis /D` has since been compiled and run in a port of Lucio's script to
  another application, but not in the exact form printed in the Skill.
- **Which element of the installer layout did the work.** The compiler version
  and the script shape changed together in the round that came back clean. The
  two builds that would separate them are listed in the experiment record and
  have not been run.
- **The pinned `appimagetool` digest is a fact about version 1.9.1.** It will age,
  and the Skill says to check it rather than trust it.
- **`linuxdeploy` + `linuxdeploy-plugin-qt`** is mentioned as an alternative and
  is not validated by any project in this research.

## 6. Re-running this audit

```bash
# 1. every Skill still parses and has its frontmatter
python3 - <<'PY'
import yaml, pathlib
for p in sorted(pathlib.Path(".dsh/skills").glob("*/SKILL.md")):
    print(yaml.safe_load(p.read_text().split("---\n", 2)[1])["name"])
PY

# 2. every evidence path a Skill cites resolves
grep -rhoE '(my-PyQt6-Apps/)?[A-Za-z0-9_.-]+-resultados/_evidence/[A-Za-z0-9_./-]+' \
  .dsh/skills | sed 's|[.,;)]*$||' | sort -u |
  while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done

# 3. the Debian package names still exist
for p in debhelper dh-python pybuild-plugin-pyproject python3-all \
         python3-setuptools python3-build python3-wheel \
         python3-pyqt6 python3-pyqt6.qtsvg python3-pyqt6.qtpdf; do
  LC_ALL=C apt-cache policy "$p" | grep -q 'Candidate: [(0-9]' || echo "MISSING: $p"
done

# 4. the Lucio installer still carries the metadata the Skill claims
#    (download LucioIVACalculator-0.1.1-nuitka-setup.exe from the v0.1.1 release
#     and parse its RT_VERSION resource; expectations are in section 3)

# 5. the wrapper record exists and is cited by the Skills that rely on it
test -f PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/lucio-iva-calculator-results/INSTALLER_WRAPPER_EXPERIMENT.md \
  || echo "MISSING: INSTALLER_WRAPPER_EXPERIMENT.md"
grep -rl "INSTALLER_WRAPPER_EXPERIMENT" .dsh/skills SKILLS.md | sort
```

Re-run this whenever a measurement is repeated, a template is executed, or an
evidence pack is regenerated at a new commit — a Skill pinned to a citation that
no longer exists is a Skill that fails silently.
