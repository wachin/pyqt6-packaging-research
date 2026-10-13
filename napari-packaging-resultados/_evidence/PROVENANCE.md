# Provenance - napari/packaging - dedicated packaging + installer infrastructure

Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; they remain under the upstream licence below. Read the licence before reusing any of this in another project.

| Field | Value |
|---|---|
| Submodule | `napari-packaging` |
| Upstream | https://github.com/napari/packaging |
| Pinned commit | `5befa97fdd90fa20f1709cf72f379bccf9a403f6` |
| Described as | `5befa97` |
| Licence | NO LICENCE FILE FOUND |
| Extracted (UTC) | 2026-10-13 |
| Files | 12 |
| Total size | 68,404 bytes |

> The most auditable installer pipeline in the set: conda constructor + NSIS/pkg, SHA-pinned actions, artifact smoke test. NO LICENCE FILE - evidence only, do not reuse.

## Files and why each one is here

| Original path | Bytes | Why it is included |
|---|---|---|
| `.github/workflows/make_bundle_conda.yml` | 34,348 | 727-line installer pipeline: signing, notarization with an API key, staple, spctl, and an install-and-launch artifact smoke test. |
| `.github/workflows/upstream_checks.yml` | 2,068 | Upstream compatibility checks. |
| `.github/workflows/zimor.yml` | 662 | zizmor workflow security linting (note the filename typo upstream). |
| `.github/dependabot.yml` | 204 | Dependency update automation. |
| `build_installers.py` | 20,234 | Driver that turns conda packages into NSIS/pkg/shell installers. |
| `conda-recipe/recipe.yaml` | 7,268 | Conda recipe used to build the packages that feed the installers. |
| `conda-recipe/yum_requirements.txt` | 93 | System libraries needed during the conda build. |
| `conda-recipe/README.md` | 1,082 | Recipe documentation. |
| `environments/ci_installers_environment.yml` | 517 | Conda environment for the installer build. |
| `environments/ci_packages_environment.yml` | 553 | Conda environment for the package build. |
| `.pre-commit-config.yaml` | 854 | Pre-commit hooks. |
| `.github/PYPROJECT_TOML_UPDATED_TEMPLATE.md` | 521 | Template used to keep napari's pyproject in sync. |

## Integrity

Verify the extracted tree against `SHA256SUMS`:

```bash
cd "$(dirname "$0")" && sha256sum -c SHA256SUMS
```
