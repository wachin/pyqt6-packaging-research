# Provenance - TBO - own PyQt6 app (Nuitka on Windows, PyInstaller on macOS/Linux)

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Submodule | `PyQt6-Apps/TBO` |
| Upstream | https://github.com/wachin/TBO |
| Pinned commit | `d92fabbedc63878d2e0e5a4aa565b13c4545338e` |
| Described as | `d92fabb` |
| Licence | GPL (`LICENSE`) |
| Extracted (UTC) | 2026-10-13 |
| Files | 21 |
| Total size | 158,226 bytes |

> Not a case study: this is the owner's own application and the only source of validated .deb evidence, plus a Flatpak manifest. Findings recorded in SOLUCIONES-TBO.md and DEBIAN-PACKAGE-AUDIT.md in this same folder.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `packaging/build_appimage.sh` | 3,857 | AppImage build script. |
| `packaging/build_windows.ps1` | 2,908 | Windows build (Nuitka) driver. |
| `packaging/build_macos.sh` | 2,027 | macOS build (PyInstaller) driver. |
| `packaging/build.sh` | 2,030 | Top-level local packaging driver (includes the Flatpak step). |
| `packaging/generate_icon.py` | 2,632 | Icon generator; the explicit output-dir bug is recorded in SOLUCIONES-TBO.md. |
| `packaging/update_translations.sh` | 1,849 | Translation (.qm) generation. |
| `packaging/tbo.desktop` | 338 | Linux desktop entry. |
| `packaging/org.tbo.TBO.appdata.xml` | 1,458 | AppStream metadata. |
| `packaging/org.tbo.TBO.json` | 1,380 | Flatpak manifest (org.kde.Platform 6.8 runtime). |
| `packaging/org.tbo.TBO.svg` | 126,893 | Scalable application icon. |
| `packaging/requirements-windows.txt` | 73 | Pinned Windows build dependencies. |
| `packaging/requirements-linux.txt` | 41 | Pinned Linux build dependencies. |
| `packaging/requirements-macos.txt` | 40 | Pinned macOS build dependencies. |
| `debian/control` | 1,100 | Debian metadata: Depends/Recommends - the native-dependency model, validated in CI. |
| `debian/rules` | 1,382 | debhelper rules, including override_dh_auto_test to skip Qt GUI tests. |
| `debian/changelog` | 410 | Debian changelog driving the package version. |
| `debian/copyright` | 1,730 | Debian copyright/attribution file. |
| `debian/source/format` | 12 | Source package format (3.0 quilt). |
| `.github/workflows/build.yml` | 4,724 | Release pipeline producing the wheel/sdist, .deb, Flatpak, Windows and macOS artifacts. |
| `.github/workflows/ci.yml` | 1,572 | CI tests. |
| `pyproject.toml` | 1,770 | Build metadata (version source for the .deb and Nuitka --file-version). |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
