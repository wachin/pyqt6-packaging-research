# Provenance - Lucio IVA Calculator - own PyQt6 app (Nuitka on Windows, PyInstaller elsewhere)

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Source tree | `PyQt6-Apps/lucio-iva-calculator` |
| Tracked as | independent clone (ignored by this repository) |
| Upstream | https://github.com/wachin/lucio-iva-calculator |
| Pinned commit | `4db15fa9962241dbdac9967a670872331fa7d692` |
| Described as | `v0.1.1-22-g4db15fa` |
| Licence | GPL (`LICENSE`) |
| Extracted (UTC) | 2026-10-30 |
| Files | 17 |
| Total size | 123,398 bytes |

> Independent clone of the owner's own application. The only project in the set whose Windows freezer was changed from PyInstaller to Nuitka on the strength of antivirus results, and the only one that verifies its Linux onefile archive's contents before publishing. Recorded VirusTotal figures are 0/68 for the installer and 0/65 for the portable ZIP at 0.1.1; PACKAGING_STUDY.md section 2 states exactly what that record does and does not establish.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `.github/workflows/build.yml` | 9,883 | Six-stage pipeline: build, then download the artifact and run it (--smoke-test) on every platform. The Windows leg also installs the NSIS installer silently and runs both the installed and the portable executable. Release is gated on v* tags and generates SHA256SUMS.txt. |
| `build/build_windows.ps1` | 3,578 | Nuitka standalone driver plus the NSIS invocation. The version is injected into the .nsi by three exact-literal String.Replace calls. |
| `build/LucioIVACalculator.nsi` | 5,628 | Per-user NSIS installer: RequestExecutionLevel user, $LOCALAPPDATA install root, HKCU uninstall keys, bilingual UI, and MUI branding bitmaps. |
| `build/build_linux.sh` | 3,261 | PyInstaller -F -w onefile. The only build in the set that greps `pyi-archive_viewer -l` for required resources and fails the build if one is missing. |
| `build/build_macos.sh` | 2,169 | PyInstaller -D .app bundle, icon built from SVG through iconutil, packaged with `ditto -c -k --sequesterRsrc`. No signing, no notarization. |
| `build/LucioIVACalculator.desktop` | 258 | Linux desktop entry whose Icon= key names a theme icon that the shipped archive does not contain under that name. |
| `build/requirements-windows.txt` | 60 | Windows build dependencies: Nuitka and its helpers, all with >= ranges rather than pins. |
| `build/requirements-linux.txt` | 28 | Linux build dependencies: PyInstaller, unpinned. |
| `build/requirements-macos.txt` | 47 | macOS build dependencies: PyQt6 pinned to 6.5.3, behind the >=6.7 used on the other two platforms, with no reason recorded anywhere in the tree. |
| `requirements.txt` | 11 | Runtime dependency for running from source. |
| `scripts/compile_translations.ps1` | 1,593 | lrelease driver called by the Windows build. |
| `scripts/create_macos_icon.py` | 1,323 | Rasterises the SVG into the .iconset that iconutil turns into the .icns. |
| `docs/nuitka-windows-build.md` | 12,654 | The project's own Nuitka reference. Its VirusTotal section is the origin of the 0/68 and 0/65 figures cited above. |
| `docs/github_release_checklist.md` | 1,653 | Manual release checklist, written in Spanish. Its expected asset list no longer matches what the release job uploads. |
| `windows-exe-fixes.md` | 1,994 | Short statement of the PyInstaller to Nuitka move and of the practices kept alongside it. |
| `VERSION` | 6 | Single source of the version string for every artifact and for the installer substitution. |
| `main.py` | 79,252 | Cite (b): --smoke-test returns before QApplication is constructed, which bounds what the CI smoke tests actually prove. |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
