# Reducing antivirus false positives legitimately

This document answers a question the rest of the research had left implicit:
when a legitimate application is flagged, what can a developer actually *do*?

It exists because the practical problem is rarely technical. A flagged download
page becomes a public accusation, and being right is not enough to win that
argument. The only thing that ends it is a clean scan result.

## The line this document stays on

**Reducing false positives is not evasion.** The distinction is concrete:

| Legitimate | Evasion |
|---|---|
| Making the software identifiable and verifiable | Making it hard to identify |
| Code signing, complete version metadata | Obfuscation, packing, crypters |
| Publishing source, checksums, provenance | Renaming or mutating binaries per build to dodge signatures |
| Reporting a false positive to the vendor | Trying to defeat the scanner yourself |
| Building from your own source, reproducibly | Tampering with the toolchain to change bytes at random |

Everything below is in the left column. The research treats the right column as
out of scope regardless of the provocation, because it does not survive contact
with a determined reviewer and it damages the developer who does it.

## Why PyInstaller gets flagged at all

The measured facts from this repository (`PACKAGING_EVIDENCE_MATRIX.md` §B.1):

- the same application, unsigned, with UPX disabled, built with Nuitka, PyInstaller
  `onedir` and PyInstaller `onefile`;
- **Nuitka 0/71; both PyInstaller arms 3/73**;
- the detections were generic (`SecureAge → Malicious`, `BehavesLike.…`,
  `Trojan.Script.2226`, `W32.Malware.…`), the two arms shared two of the three
  engines, and every major engine was clean.

The mechanism that fits: **PyInstaller ships a single pre-compiled bootloader
that is redistributed inside thousands of unrelated executables.** An engine that
decides to flag that stub flags every application built with it, regardless of
what the application does. Nuitka has no equivalent widely-shared self-extracting
stub, which is why it comes out clean.

That explains the two things this document is about: why the detections cluster
on a handful of generic engines, and why changing the bootloader is the
structural fix.

## The measures, in order of value

### 1. Sign the binary (Authenticode)

The largest legitimate reputation lever, and the one the whole research points
at: napari signs precisely for this, and the guide's §13 covers the sequence
(inner binaries first, then the installer; SHA-256 digest; RFC 3161 timestamp).

Costs money (an OV or EV certificate). Note the honest caveat from the evidence
matrix: signing does **not** guarantee a clean VirusTotal result, and an
untrusted certificate does not even remove SmartScreen warnings — napari
documented that about its own stopgap.

### 2. Rebuild the PyInstaller bootloader

This is the direct answer to "how do other developers stop PyInstaller being
flagged", and it is **not folklore — PyInstaller's own documentation recommends
it for exactly this reason.** The bootloader-building page lists among the
reasons to build it yourself:

> "you want to avoid anti-virus false positives that result from the wide-spread
> use of pre-compiled bootloaders"
> — <https://pyinstaller.org/en/stable/bootloader-building.html>

and documents doing it at install time, which is what a CI job needs:

```powershell
# Windows PowerShell
$env:PYINSTALLER_COMPILE_BOOTLOADER = 1
python -m pip uninstall -y PyInstaller
python -m pip cache remove PyInstaller
python -m pip install --verbose --no-binary=PyInstaller PyInstaller
```

The three steps matter: uninstall any existing copy, clear the cached wheel so
`pip` cannot reuse a pre-built one, and force an sdist install. Requires a C
toolchain — MSVC on the Windows runner, which is already there for Nuitka.

#### Measured: which of the two flags actually does the work

This was tested rather than assumed, on Linux with PyInstaller 6.22.3 held
constant, and the result contains a trap worth knowing.

Installing from the sdist does produce a locally compiled bootloader, with
different bytes from the wheel's — that is the whole point:

| Install method | `Linux-64bit-intel/run` |
|---|---|
| wheel (default `pip install pyinstaller`) | `220bf3c7…`, 72,464 B |
| sdist (`--no-binary=PyInstaller`) | `b8771ca4…`, 68,472 B |

**But the sdist ships pre-compiled bootloaders for some platforms, and for
Windows the one it ships is byte-identical to the wheel's:**

```text
sdist  PyInstaller/bootloader/Windows-64bit-intel/run.exe  581ea23e…  311,808 B
wheel  PyInstaller/bootloader/Windows-64bit-intel/run.exe  581ea23e…  311,808 B
```

So on Windows, `--no-binary=PyInstaller` **on its own changes nothing**: pip
reuses the same pre-built stub that every other application uses. It is
`PYINSTALLER_COMPILE_BOOTLOADER=1` that forces the compile.

On Linux the sdist happens to carry no pre-built bootloader for the platform, so
it compiles regardless — which is exactly why the flag looks redundant if you
only ever test on Linux. **Both flags are required for the Windows arm**, and
this detail is missing from most write-ups that recommend "rebuilding the
bootloader".

#### Result: it was tested, and it did not work

Measured on 2026-10-14, same commit, version and metadata, unsigned, UPX
disabled. Screenshot in `experiments/pyinstaller-vs-nuitka/evidence/`:

| Arm | VirusTotal |
|---|---|
| Nuitka standalone | **0 / 71** |
| PyInstaller onedir | **3 / 73** — Bkav Pro, Zillya, SecureAge |
| PyInstaller onefile | **3 / 73** — Bkav Pro, Zillya, SecureAge |
| PyInstaller onefile, **rebuilt bootloader** | **2 / 70** — Bkav Pro, SecureAge |

**Rebuilding the bootloader removed one detection** (Zillya disappeared), so the
shared pre-compiled stub is not irrelevant. **But two engines flagged the rebuilt
build anyway.**

That refutes the hypothesis. If the widely shared bootloader were the cause, new
bytes would have cleared it; they did not. The rebuilt bootloader is a real but
partial effect, and it is **not a fix** — so this section is a description of a
technique that was tried, not a recommendation.

The evidence also points somewhere more specific. The **onedir** arm was flagged
too, and onedir does not self-extract at all. The common factor across all four
PyInstaller builds is the **embedded CPython runtime and PyInstaller's archive
format**, not the extraction step and not the stub. Changing the bootloader cannot
touch that.

With the build-side options exhausted, what remains is: **sign** (untested here),
**report the false positives to Bkav and SecureAge**, or use a different freezer
— which is what happened.

**Why it was plausible:** the rebuilt bootloader has different bytes from the
stock one that every other PyInstaller application shares, so a signature written
against the stock stub would no longer match. It is still a legitimate engineering
act — you are compiling the tool from its own public source — it simply turned
out not to be sufficient.

**What is not verified:** this research has **not measured** whether rebuilding
the bootloader drops the count to zero. It is documented as a mitigation by the
tool's own maintainers, and it is worth testing, but it must not be presented as
a guaranteed cure. See "Testing it" below.

### 3. Report the false positive to the vendors

This is what actually changes the VirusTotal page. Vendors do remove generic
detections when shown a legitimate application, and once they do, the scan goes
clean and the public accusation loses its evidence.

VirusTotal itself cannot help: it aggregates other companies' verdicts and
produces none of its own, which is why a file report has no "report a false
positive" button. **Who to contact, and a ready-to-send message, is in
`FALSE-POSITIVE-REPORTING.md`** — including the official VirusTotal contacts page
that exists but is not linked from the reports.

### 4. The things that cost nothing

- **No UPX.** Disabled everywhere, consistently. Cheap and conservative.
- **Complete, consistent PE metadata** from the first release: company, product,
  description, four-part numeric version. A file with no identity looks like
  something assembled in a hurry.
- **Prefer `onedir` over `onefile`.** Not because it avoids detection — the
  measurement shows it does not — but because it is easier to inspect and debug,
  and every mature project in the case studies chose it.
- **Publish the source and the SHA-256** next to every download. It gives the
  accusation somewhere to go: anyone can check.

### 5. What does not work, and why not to try it

Obfuscation, packers, crypters, mutating the binary between builds, or hunting
for a build that happens to score zero. These are the techniques that make an
application look like malware, and they are the reason the detection exists in
the first place. They also produce a result that changes the next time the
engines update, so the reprieve is temporary and the practice is indefensible.

## Testing it

The repository ships a repeatable kit: `experiments/pyinstaller-vs-nuitka/`.
The honest next step for anyone facing this is to add an arm — PyInstaller with a
**rebuilt bootloader** — and scan all of them together. That converts "documented
as a mitigation" into either a measured result or a measured non-result, and this
research only states the latter kind.

That arm now exists in TBO as the
`build-windows-pyinstaller-rebuilt-bootloader` CI job, which installs PyInstaller
from its sdist with `PYINSTALLER_COMPILE_BOOTLOADER=1` and builds with
`-Flavour pyinstaller-rebuilt` so the artifacts are named distinctly. The job also
prints the bootloader directory contents, because a silent fall-back to the
pre-built wheel would turn the arm into a duplicate of the standard build —
a worse outcome than a failed job, since it would look like evidence.

Run recorded for the three original arms:
`experiments/pyinstaller-vs-nuitka/RESULTS-2026-10-TBO.md`.

## A separate problem that gets confused with this one

Being flagged by VirusTotal and being penalised by a hosting platform are **two
different systems**, and conflating them leads to fixing the wrong thing.

VirusTotal aggregates third-party engines. Google's platform warnings come from
**Google's own scanners and Safe Browsing**, not from VirusTotal. A blog can be
locked for reasons that have nothing to do with the software it distributes.

There is a documented precedent. On **4 August 2026** Google Blogger mass-locked
thousands of legitimate blogs with a "Malware and Similar Malicious Content"
policy notice. Google's own Product Experts confirmed it was a widespread
misfire by automated scanning, apparently triggered by copyright-protection
scripts in popular free templates, and Google fixed it. The official thread is
marked `[FIXED]`:
<https://support.google.com/blogger/thread/457259506>

Two practical consequences:

- If a blog shows such a notice, there is a **Request Review** route in the
  Blogger dashboard (Info tab). Reporting coverage notes a **90-day countdown**
  on locked blogs before permanent deletion becomes a risk, so it is worth doing
  promptly rather than waiting.
- Public accusations citing VirusTotal are answered by a clean VirusTotal page —
  which is what sections 2 and 3 above are for.

## Summary

| Measure | Effect on detections | Cost |
|---|---|---|
| Authenticode signing | The main reputation lever; not a guarantee | A certificate |
| Rebuild the PyInstaller bootloader | Documented by PyInstaller as a mitigation; **unmeasured here** | A few minutes of CI |
| Vendor false-positive reports | The thing that actually clears the report page | Time and follow-up |
| No UPX, full metadata, publish hashes | Small, cumulative, free | None |
| Obfuscation / packing / mutation | Do not do this | Your credibility |
