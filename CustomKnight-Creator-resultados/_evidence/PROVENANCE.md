# Provenance - CustomKnight-Creator - Hollow Knight mod tool

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Source tree | `CustomKnight-Creator` |
| Tracked as | submodule |
| Upstream | https://github.com/cmot17/CustomKnight-Creator.git |
| Pinned commit | `158ec2f259cb220b6d81fe409fb64c367c2fc893` |
| Described as | `v1.0.2` |
| Licence | GPL (`LICENSE.md`) |
| Extracted (UTC) | 2026-10-13 |
| Files | 3 |
| Total size | 20,821 bytes |

> The negative example: onefile on all platforms, ubuntu-latest GLIBC, no signing, no release automation.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `.github/workflows/package.yml` | 1,530 | The entire packaging story: pyinstaller -F -w per OS, upload-artifact; no spec file, no signing, no release. |
| `requirements.txt` | 43 | Exact top-level pins (PyQt6==6.3.1, pyinstaller==5.1) - partial pinning only. |
| `main.py` | 19,248 | Cite (b): resource resolution via os.path.dirname(__file__) plus a broken qrc reference. |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
