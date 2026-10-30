# Provenance - TBO - own PyQt6 app (Nuitka on Windows, PyInstaller on macOS/Linux)

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Source tree | `my-PyQt6-Apps/TBO` |
| Tracked as | submodule |
| Upstream | https://github.com/wachin/TBO |
| Pinned commit | `797011a584ff58a5b078df4cb9b9bc78a73e881c` |
| Described as | `v2.0.0.dev0-2-g797011a` |
| Licence | GPL (`LICENSE`) |
| Extracted (UTC) | 2026-10-30 |
| Files | 25 |
| Total size | 188,899 bytes |

> Not a case study in the same sense: this is the owner's own application, pinned as a sub-module like the rest. It is the only source of validated .deb evidence and the only project here with a Flatpak manifest and a controlled freezer measurement. The fix log lives in 03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md; the packaging study is the one in this folder.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `packaging/build_appimage.sh` | 5,479 | AppImage build script. |
| `packaging/build_windows_nuitka.ps1` | 5,993 | Windows build (Nuitka) driver - the shipping Windows build. |
| `packaging/build_windows_pyinstaller.ps1` | 12,215 | Windows build (PyInstaller) driver, added to make the two freezers comparable on the same application. |
| `packaging/build_macos.sh` | 2,585 | macOS build (PyInstaller) driver. |
| `packaging/build.sh` | 2,032 | Top-level local packaging driver (includes the Flatpak step). |
| `packaging/generate_icon.py` | 2,634 | Icon generator; the explicit output-dir bug is recorded in SOLUCIONES-TBO.md. |
| `packaging/make_portable_zip.py` | 7,204 | Creates the Windows portable ZIP with conformant forward-slash entry names, because PowerShell 5.1 cannot be trusted to; see SOLUCIONES-TBO.md section 12. |
| `packaging/update_translations.sh` | 1,851 | Translation (.qm) generation. |
| `packaging/tbo.desktop` | 340 | Linux desktop entry. |
| `packaging/org.tbo.TBO.appdata.xml` | 1,460 | AppStream metadata. |
| `packaging/org.tbo.TBO.json` | 1,382 | Flatpak manifest (org.kde.Platform 6.8 runtime). |
| `packaging/org.tbo.TBO.svg` | 126,895 | Scalable application icon. |
| `packaging/requirements-windows.txt` | 75 | Pinned Windows build dependencies (Nuitka toolchain). |
| `packaging/requirements-windows-pyinstaller.txt` | 648 | Pinned Windows dependencies for the PyInstaller comparison build. |
| `packaging/requirements-linux.txt` | 43 | Pinned Linux build dependencies. |
| `packaging/requirements-macos.txt` | 42 | Pinned macOS build dependencies. |
| `debian/control` | 1,100 | Debian metadata: Depends/Recommends - the native-dependency model, validated in CI. |
| `debian/rules` | 1,382 | debhelper rules, including override_dh_auto_test to skip Qt GUI tests. |
| `debian/changelog` | 410 | Debian changelog driving the package version. |
| `debian/copyright` | 1,730 | Debian copyright/attribution file. |
| `debian/source/format` | 12 | Source package format (3.0 quilt). |
| `.github/workflows/build.yml` | 6,317 | Release pipeline producing the wheel/sdist, .deb, Flatpak, Windows and macOS artifacts. |
| `.github/workflows/ci.yml` | 1,572 | CI tests. |
| `docs/GitHub-Actions-Solutions/PACKAGING-RESOURCE-COLLECTION-BUG.md` | 3,726 | The resource-collection defect: bundles that built green and shipped without their icons and translations. |
| `pyproject.toml` | 1,772 | Build metadata (version source for the .deb and Nuitka --file-version). |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
