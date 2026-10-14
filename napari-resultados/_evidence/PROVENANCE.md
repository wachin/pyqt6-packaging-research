# Provenance - napari - scientific image viewer

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Source tree | `napari` |
| Tracked as | submodule |
| Upstream | https://github.com/napari/napari.git |
| Pinned commit | `908b3ed80ccbe73a3393f0207aafc6d7a45e116a` |
| Described as | `v0.9.0` |
| Licence | BSD (`LICENSE`) |
| Extracted (UTC) | 2026-10-14 |
| Files | 14 |
| Total size | 185,537 bytes |

> Freezing rejected in favour of conda constructor; delegates all packaging to napari/packaging.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `.github/workflows/make_bundle_conda.yml` | 464 | Thin caller: delegates to napari/packaging/.github/workflows/make_bundle_conda.yml@main with secrets: inherit. |
| `.github/workflows/make_release.yml` | 4,745 | Wheel release; attest-build-provenance for wheels. |
| `.github/workflows/reusable_build_wheel.yml` | 408 | Reusable wheel build. |
| `.github/dependabot.yml` | 408 | Dependency update automation. |
| `MANIFEST.in` | 813 | Source-distribution file manifest. |
| `pyproject.toml` | 31,568 | Project metadata and dependency bounds (PySide6 < 6.11 etc). |
| `resources/conda_menu_config.json` | 114,844 | Menu entry installed by menuinst when the conda package is installed. |
| `resources/bundle_license.txt` | 1,678 | Licence text shipped in the bundle. |
| `resources/bundle_readme.md` | 2,366 | Readme shipped in the bundle. |
| `binder/Desktop/napari.desktop` | 139 | Desktop entry. |
| `src/napari/utils/logo.py` | 2,259 | Cite (b): importlib.resources used to locate bundled logos (recommended modern pattern). |
| `src/napari/_qt/__init__.py` | 4,570 | Cite (b): QtPy binding abstraction. |
| `src/napari/_qt/qt_event_loop.py` | 15,455 | Cite (b): Qt event-loop handling relevant to frozen/packaged execution. |
| `src/napari/resources/_icons.py` | 5,820 | Cite (b): icon/resource collection. |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
