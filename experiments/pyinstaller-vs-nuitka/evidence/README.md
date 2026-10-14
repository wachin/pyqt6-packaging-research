# Primary evidence: VirusTotal screenshots (2026-10-14)

Screenshots of the VirusTotal report pages for the three Windows artifacts built
by TBO's CI from a single commit. They are the primary source for the
measurement recorded in `../RESULTS-2026-10-TBO.md`, section B.1 of
`PACKAGING_EVIDENCE_MATRIX.md`, and section 11 of `SOLUCIONES-TBO.md`.

| File | Artifact | Result |
|---|---|---|
| `vt-nuitka-TBO.exe-0of71.png` | Nuitka standalone `TBO.exe` | **0 / 71** |
| `vt-pyinstaller-onedir-3of73.png` | PyInstaller onedir | **3 / 73** |
| `vt-pyinstaller-onefile-3of73.png` | PyInstaller onefile | **3 / 73** |
| `vt-pyinstaller-rebuilt-bootloader-onefile-2of70.png` | PyInstaller onefile, bootloader compiled from source | **2 / 70** |

Each screenshot shows the VirusTotal file page: community score, detection
summary, and the full per-engine list.

## Provenance

Captured by the repository owner on 2026-10-14 from
`virustotal.com/gui/file/<sha256>`. The three SHA-256 values were recomputed from
the build artifacts on disk and match both the hashes in the screenshot
filenames and the "Analysis date / size" shown on each page, so these pages
describe exactly the binaries TBO's CI produced.

Screenshot file hashes, for integrity:

```text
475e58f0da5b35b860e63d1050a9b010fe6eb6afad0b1616edaf48a102d17398  vt-nuitka-TBO.exe-0of71.png
b326557d8ed65297b9031cb9a2a805408a0702d0f13717b00968ec887fd3f53f  vt-pyinstaller-onedir-3of73.png
6e6621832a7e38a80e18c61597a7f0bdf8619897d05b49091b50df8fca11e33e  vt-pyinstaller-onefile-3of73.png
f451b20cf4c01d4461f3a54950e8fdab8249d0de5f81ebd048202ee99359c758  vt-pyinstaller-rebuilt-bootloader-onefile-2of70.png
```

## How to read them

VirusTotal scores drift: engines update, and a result is a point-in-time,
engine-specific signal, not a verdict. These images are a record of one moment
and should be reproduced, not quoted as current.

The detections recorded are generic and behavioural rather than signature
matches on a named family, and most of the industry's major engines report clean.
See the analysis in `../RESULTS-2026-10-TBO.md` before drawing conclusions from
the counts alone.

## Replacing these

These are screenshots because VirusTotal's web interface cannot be read without
an API key. If a VirusTotal API key is ever available, replace them with the
`/api/v3/files/<hash>` JSON responses, which are machine-checkable and carry the
engine list in a diffable form.
