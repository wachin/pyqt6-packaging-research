# Provenance - pyzo - scientific Python IDE

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Submodule | `pyzo` |
| Upstream | https://github.com/pyzo/pyzo.git |
| Pinned commit | `7f9679625c8bf028a3f796e6cba6f6d6c18dd063` |
| Described as | `v4.22.0-10-g7f96796` |
| Licence | BSD (`LICENSE.md`) |
| Extracted (UTC) | 2026-10-13 |
| Files | 17 |
| Total size | 66,210 bytes |

> Mature onedir + Inno/DMG/ZIP wrappers; full macOS signing and notarization in CI; the only project that curates Qt modules explicitly.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `freeze/installerBuilderScript.iss` | 2,146 | Inno Setup script (Win64 only, per-user default). |
| `freeze/pyzo_freeze.py` | 8,971 | Freeze driver; explicitly selects Core/Gui/Widgets/PrintSupport and excludes the rest. |
| `freeze/pyzo_package.py` | 3,863 | Freeze packaging helper. |
| `freeze/boot.py` | 3,290 | Cite (b): frozen bootstrap; uses sys._MEIPASS to locate shipped source. |
| `freeze/frozen_libs.txt` | 8 | Libraries kept in the frozen bundle. |
| `freeze/pyzo_test_frozen.py` | 667 | Frozen-artifact test. |
| `freeze/_settings/README.txt` | 734 | Notes shipped beside the frozen settings. |
| `pyzo/resources/org.pyzo.Pyzo.desktop` | 1,430 | Linux desktop entry. |
| `pyzo.appdata.xml` | 1,755 | AppStream metadata. |
| `pyproject.toml` | 2,978 | Build/packaging metadata. |
| `.github/workflows/cd.yml` | 11,384 | Release pipeline: P12 to temp keychain, codesign --deep --options runtime --timestamp, notarytool, staple, gh release create --verify-tag. |
| `.github/workflows/ci.yml` | 4,195 | CI tests. |
| `pyzo/util/_locale.py` | 5,639 | Cite (b): QTranslator + QLibraryInfo, ships pyzo_*.qm and tries Qt's. |
| `pyzo/qt/__init__.py` | 4,318 | Cite (b): Qt binding selection layer. |
| `pyzo/_start.py` | 12,770 | Cite (b): application start path. |
| `pyzolauncher.py` | 1,299 | Cite (b): launcher entry point. |
| `tests/check_log.py` | 763 | Cite (b): log check used by the frozen-artifact smoke test in CI. |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
