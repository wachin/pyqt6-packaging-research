# Provenance - dikte - voice-dictation tray app

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Submodule | `dikte` |
| Upstream | https://github.com/yusufipk/dikte.git |
| Pinned commit | `3663c7fd57569d1914424f4f9656a9941ae2d636` |
| Described as | `v1.0.2` |
| Licence | GPL (`LICENSE`) |
| Extracted (UTC) | 2026-10-13 |
| Files | 19 |
| Total size | 154,857 bytes |

> Only implemented AppImage in the case set; onedir payload wrapped in Inno/DMG/AppImage.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `packaging/dikte.spec` | 6,019 | PyInstaller spec: onedir (EXE(exclude_binaries=True) + COLLECT) with targeted Qt module excludes. |
| `packaging/dikte.iss` | 4,260 | Inno Setup installer: per-user, PrivilegesRequired=lowest, bundles FFmpeg. |
| `packaging/build-appimage.sh` | 3,107 | Hand-built AppDir + AppRun + appimagetool; the only observed AppImage implementation. |
| `packaging/build-dmg.sh` | 4,245 | macOS DMG via hdiutil UDZO per architecture; ad-hoc signing only. |
| `packaging/build-windows.ps1` | 5,549 | Windows build driver; pins and SHA-256-verifies the downloaded FFmpeg build. |
| `packaging/entry.py` | 1,101 | Frozen entry point used by the PyInstaller spec. |
| `install.sh` | 9,281 | Source/system install script; documents distro PyQt6 package names (native-dependency model). |
| `install.ps1` | 3,649 | Windows source install script. |
| `scripts/install-mac.sh` | 15,825 | macOS source install script. |
| `scripts/release.sh` | 2,411 | Local release automation. |
| `scripts/update.sh` | 4,317 | Update script shipped to users. |
| `scripts/uninstall.sh` | 8,875 | Uninstall script shipped to users. |
| `.github/workflows/build.yml` | 3,890 | Build matrix on ubuntu-22.04 (GLIBC floor) producing the AppImage and platform archives. |
| `.github/workflows/release.yml` | 7,602 | Tag-gated release automation (rolling + v* tags, gh release create). |
| `.github/workflows/tests.yml` | 4,845 | CI tests. |
| `dikte/integrate.py` | 23,616 | Cite (b): restores LD_LIBRARY_PATH and the CA store before launching bundled host binaries. |
| `dikte/i18n.py` | 43,410 | Cite (b): Qt translation loading via QTranslator/QLibraryInfo. |
| `dikte/paths.py` | 1,845 | Cite (b): development vs frozen path resolution. |
| `dikte/__main__.py` | 1,010 | Cite (b): entry-point/guarded start. |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
