# Provenance - CARA - chess analysis app

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Submodule | `CARA` |
| Upstream | https://github.com/pguntermann/CARA.git |
| Pinned commit | `6c9164c6616cea5a3cf5ab125e82362ebf87822f` |
| Described as | `2.8.7` |
| Licence | GPL (`LICENSE`) |
| Extracted (UTC) | 2026-10-13 |
| Files | 13 |
| Total size | 68,659 bytes |

> Full macOS Developer ID signing + notarization from a local script; three separate platform specs.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `CARA_windows.spec` | 1,324 | PyInstaller spec; requests upx=True (actual Windows compression unverified). |
| `CARA_linux.spec` | 2,088 | PyInstaller spec for the Linux onedir bundle. |
| `CARA_macos.spec` | 3,263 | PyInstaller spec producing the macOS BUNDLE .app. |
| `packaging/macos/entitlements.plist` | 334 | Entitlements used for hardened-runtime signing. |
| `scripts/build_macos_signed.sh` | 3,915 | codesign Developer ID + hardened runtime + notarytool submit --wait + stapler. |
| `.github/workflows/build-appbundles.yml` | 3,492 | macOS/Windows bundle builds. |
| `.github/workflows/build-linux-appbundles.yml` | 3,663 | Linux builds on Ubuntu 22.04; comments record the GLIBC 2.38/24.04 failure. |
| `.github/workflows/tests.yml` | 1,101 | CI tests. |
| `.github/ci/linux-pip-constraints.txt` | 106 | Pinned Linux CI constraints (the closest thing to dependency pinning in this project). |
| `requirements.txt` | 93 | Runtime dependency list. |
| `cara.py` | 8,005 | Cite (b): multiprocessing.freeze_support() guard for PyInstaller workers. |
| `app/utils/path_resolver.py` | 8,164 | Cite (b): central dev / Resources / _internal resolver; avoids sys._MEIPASS. |
| `app/services/uci_communication_service.py` | 33,111 | Cite (b): strips loader variables before launching the external engine. |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
