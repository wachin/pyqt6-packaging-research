# Packaging Study: napari/packaging (conda-based napari installers)

> This document is a personal technical study of the `napari/packaging` repository.
> It was created by inspecting the repository itself, its git history, the official
> napari documentation, and the public GitHub releases of `napari/napari`.
> No source code was modified. Nothing was executed.
>
> **Headline finding:** this repository does **NOT** use PyInstaller, Nuitka,
> cx_Freeze, py2app, or Briefcase. It uses **conda `constructor`** to build native
> installers (`.exe`, `.pkg`, `.sh`) from **conda packages**. It bundles **PySide6**
> (not PyQt6) as the Qt binding, through the **QtPy** abstraction layer.

---

## 1. Executive Summary

`napari/packaging` is a dedicated, standalone repository owned by the napari
project that holds all logic for producing **conda-based end-user installers**
of the napari image viewer for Linux, macOS, and Windows.

The core ideas:

1. **Everything is a conda package.** The napari application is packaged for
   conda-forge (`napari-base`, `napari`, `napari-menu` outputs). The installers
   are built from those conda packages, never from raw source or wheels.
2. **`constructor` (conda) builds the installers.** The script
   `build_installers.py` generates a `construct.yaml` configuration and invokes
   `constructor`. The resulting installers are:
   - Windows → NSIS-based `.exe` graphical installer
   - Linux → text-based `.sh` shell installer
   - macOS → native graphical `.pkg` installer
3. **The installed product is a self-contained conda installation.** It ships
   its own Python runtime, conda/mamba, PySide6, and the entire napari dependency
   tree inside a per-user prefix (e.g. `~/.local/napari-0.9.0` on Linux). It does
   not rely on system packages for Qt or Python.
4. **Signing/notarization:**
   - macOS: full chain — `Developer ID Application` cert (codesign internal
     binaries) + `Developer ID Installer` cert (productsign the PKG) +
     notarization via `xcrun notarytool` (App Store Connect API key) + stapling +
     `spctl` verification.
   - Windows: **two** mechanisms. (a) A stopgap signature using the *Apple*
     certificate (deliberately not trusted by Windows) applied on all signed
     runs; (b) a proper **Azure Code Signing** signature with a NumFOCUS-managed
     certificate, applied **only to final tagged releases**, plus SHA256 checksum
     generation and signature verification.
   - Linux: no signing (`.sh` installers are not signed).
5. **No AppImage, no .deb, no DMG.** Those formats were used by the *previous*
   Briefcase-based pipeline and were deliberately dropped (documented in
   NAP-2 and the official packaging docs).

### Why this matters for a PyQt6 developer

This repository is a **counter-example** to the "freeze with PyInstaller/Nuitka"
approach. It shows a mature, large-scale project choosing a *package-manager-based
installer* strategy instead of binary freezing. That choice is mostly driven by the
plugin ecosystem requirement (installers must allow installing plugins at runtime),
which frozen single-file binaries make hard. For a simple PyQt6 app without a plugin
ecosystem, PyInstaller/Nuitka remain the mainstream choice; the genuinely reusable
parts here are the **signing/notarization pipelines**, the **CI architecture**, the
**release hygiene** (lockfiles, checksums, license collection), and the **testing of
installers inside CI**.

---

## 2. Project Architecture

| Item | Value | Evidence |
|---|---|---|
| Repository | `napari/packaging` (mirrored locally as `napari-packaging`) | README.md |
| Main purpose | Build conda-based installers for napari (Linux/macOS/Windows) | README.md:1-12 |
| Language(s) | Python (build orchestration), YAML (workflows, recipes, environments), Shell/PowerShell (CI steps) | repo tree |
| Python versions | Build Python pinned to **3.13**; bundled Python also **3.13** (`INSTALLER_PYTHON_VERSION: "3.13"`); recipe `python_min: "3.11"` | make_bundle_conda.yml:65-66, recipe.yaml:4 |
| Qt binding | **PySide6** (bundled in installers) via **QtPy** abstraction in napari core | build_installers.py:239 (`QT_API: pyside6`), build_installers.py:275 (`pyside6={PYSIDE_VER}`), recipe.yaml:75 (`qtpy`) |
| Qt version | `pyside6 >=6.7.1,<6.11` (run_constraint); `6.11` explicitly blocked due to napari dock/layout issues | recipe.yaml:86, commit 9e093ce |
| OS supported | Linux x86_64, macOS x86_64 + arm64, Windows x86_64 | make_bundle_conda.yml:258-279 matrix |
| App entry point | `napari = napari._main:main` (in napari/napari, referenced here via `python` entry_point in recipe) | recipe.yaml:32 |
| Dependency mgmt | conda (`conda-forge` channel), plus `pip`/`uv` installed *inside* the bundle; setuptools_scm for versioning | recipe.yaml, build_installers.py:107-113 |
| Build system | `rattler-build` (conda-recipe/recipe.yaml, README.md:80-82); conda-smithy rerender for feedstock | conda-recipe/README.md |
| Packaging system | conda `constructor` | build_installers.py:423-466 |
| Release system | GitHub Actions (workflow in this repo called by `napari/napari`), GitHub Releases (assets uploaded by CI) | make_bundle_conda.yml, napari/napari make_release.yml |

### Project structure

```text
napari-packaging/
├── build_installers.py                 # THE build orchestration script (621 lines)
├── README.md                           # usage documentation
├── conda-recipe/
│   ├── recipe.yaml                     # patched copy of conda-forge napari feedstock recipe
│   ├── README.md                       # explains sync policy with conda-forge
│   └── yum_requirements.txt            # system deps for the conda-forge docker build
├── environments/
│   ├── ci_packages_environment.yml     # env to build conda packages (conda-smithy, etc.)
│   └── ci_installers_environment.yml   # env to run constructor
└── .github/
    ├── dependabot.yml
    ├── PYPROJECT_TOML_UPDATED_TEMPLATE.md
    └── workflows/
        ├── make_bundle_conda.yml       # MAIN workflow (727 lines)
        ├── upstream_checks.yml         # watches napari/napari pyproject.toml changes
        └── zimor.yml                   # zizmor security analysis of workflows
```

Notable absences (important to record): no `pyproject.toml`, no `setup.py`, no
`requirements.txt` for this repo itself (environments are conda YAML), no `Makefile`,
no `.spec` files, no Dockerfile, no AppImage/linuxdeploy config, no Debian packaging,
no py2app/Briefcase config. A `.gitignore` still contains a leftover
`# PyInstaller` section and `*.spec` ignore rule — that is vestigial.

---

## 3. Packaging Overview

The full pipeline, reconstructed from the workflow and `build_installers.py`:

```text
napari/napari source (tag vX.Y.Z or nightly)
        │  GitHub Actions trigger: push tag v*, schedule (nightly), workflow_dispatch
        ▼
workflow_call → napari/packaging make_bundle_conda.yml  (secrets: inherit)
        │
        ├── job "packages"  (ubuntu-latest)
        │     ├─ clone napari/packaging + napari/napari + conda-forge/napari-feedstock
        │     ├─ replace feedstock recipe/ with our conda-recipe/
        │     ├─ patch version + sdist path into recipe.yaml
        │     ├─ conda-smithy rerender
        │     ├─ run conda-forge's docker build scripts → napari conda packages
        │     ├─ upload packages to anaconda.org/napari (nightlies/RCs/finals only)
        │     └─ pass packages as GitHub Actions artifact
        │
        ├── job "prepare_matrix"  (ubuntu-latest, computes 4-platform matrix)
        │
        └── job "installers"  (matrix: linux-64, osx-64, osx-arm64, win-64)
              ├─ install micromamba env (constructor, conda-standalone, conda, …)
              ├─ download local napari package artifact, index as local channel
              ├─ python build_installers.py → writes construct.yaml → runs constructor
              │     ├─ Linux  → napari-X-OSx86_64.sh
              │     ├─ macOS  → napari-X-OSarm64.pkg  / -OSx86_64.pkg
              │     └─ Windows→ napari-X-Windowsx86_64.exe
              ├─ collect licenses.zip + lockfile.txt artifacts
              ├─ macOS: notarize + staple PKG
              ├─ Windows: Apple-cert PFX signing (all signed runs) +
              │           Azure Code Signing (final releases) + SHA256 + verify
              ├─ upload installer + lockfile to the GitHub Release (tag only)
              └─ install & smoke-test the installer on the runner (per OS)
```

### Stage → file map

| Stage | File(s) |
|---|---|
| Trigger / CI orchestration | `.github/workflows/make_bundle_conda.yml` |
| Package building (conda packages) | `conda-recipe/recipe.yaml` (+ `conda-recipe/README.md`) |
| Installer configuration generation | `build_installers.py` (`_definitions`, `_constructor`) |
| Windows installer | `constructor` (NSIS) via `build_installers.py:364-389, 440` |
| Linux installer | `constructor` (shell) via `build_installers.py:325-332` |
| macOS installer | `constructor` (pkgbuild) via `build_installers.py:334-362` |
| macOS signing/notarization | `make_bundle_conda.yml:416-455, 534-585` |
| Windows signing | `make_bundle_conda.yml:457-478` (stopgap), `588-631` (Azure) |
| Release asset upload | `make_bundle_conda.yml:651-672` |
| Installer smoke tests | `make_bundle_conda.yml:674-727` |

---

## 4. Windows

**Packaging mechanism: conda `constructor` (NSIS-based `.exe` installer).**

- Installer type is set in `build_installers.py:364-389`:
  ```python
  if WINDOWS:
      definitions.update({
          'welcome_image': ..., 'header_image': ..., 'icon_image': ...,
          'register_python': False,
          'register_python_default': False,
          'default_prefix': os.path.join('%LOCALAPPDATA%', INSTALLER_DEFAULT_PATH_STEM),
          'default_prefix_domain_user': ...,
          'default_prefix_all_users': os.path.join('%ALLUSERSPROFILE%', ...),
          'check_path_length': False,
          'installer_type': 'exe',
      })
  ```
- Default install location: `%LOCALAPPDATA%\napari-<version>` (per-user),
  `%ALLUSERSPROFILE%\napari-<version>` (all-users). Path-length checking disabled.
- Python registry not touched (`register_python: False`).
- The `.exe` bundles a full conda installation; the napari environment is
  `%PREFIX%\envs\napari-<version>`.
- Installer is tested in CI by running it silently and starting napari
  (`make_bundle_conda.yml:711-727`):
  ```
  cmd.exe /c start /wait napari-...exe /S /D=...
  CALL ...\Scripts\activate ...
  napari --info
  ```
  Plus a check that a Start-Menu `.lnk` shortcut exists:
  `%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\napari*`.

**There is no portable/frozen single .exe.** The "executable" is an installer,
not a bundled app binary.

### Antivirus note (no data here)

This repository contains **no** antivirus / VirusTotal / Defender evidence at all
(grep for `VirusTotal`, `antivirus`, `SmartScreen`, `Defender`, `false positive`
returns nothing in source). The only indirect signal is the workflow comment about
the Apple-cert stopgap signature still producing Windows SmartScreen warnings
(`make_bundle_conda.yml:470-472`). Any claim about false-positive rates for this
pipeline is therefore **not verifiable from this repository**.

---

## 5. PyInstaller

This repository does **not** use PyInstaller. The only mentions are:

- `environments/ci_installers_environment.yml` — no.
- `.gitignore` — a leftover generic `# PyInstaller` comment and `*.spec` ignore
  (a copy-paste from a generic gitignore; the project never ships spec files).
- napari's official docs mention that **`conda-standalone` (used inside the
  installers) is itself a PyInstaller-frozen version of conda** — but that is a
  conda-infrastructure detail, not this project's own packaging method.

So: no `.spec` files, no hidden imports, no `sys._MEIPASS`, no bootloader work,
no UPX handling. **Not applicable to this repository.**

The only deep-learning value is *indirect*: the napari team explicitly evaluated
and rejected freezing tools for their use case. See section 6 and the tutorial's
PyInstaller-vs-Nuitka discussion.

---

## 6. Nuitka

This repository does **not** use Nuitka. However, NAP-2 (the design document that
created this repository) documents that **Nuitka and PyOxidizer were tried and
rejected**:

> "Freezing `napari` directly with PyOxidizer and Nuitka. These experiments were
> not successful either and didn't allow for a good plugin installation story
> (the frozen executables are immutable)."
> — https://napari.org/stable/naps/2-conda-based-packaging.html, Related Work

That is a valuable data point: for an app whose entire value proposition is a
**runtime-installable plugin ecosystem**, freezing (PyInstaller/Nuitka/…)
fundamentally conflicts, because the frozen binary cannot extend itself with new
Python packages at runtime. napari's answer was to ship a package-managed
environment (conda) instead.

For a **simple PyQt6 application without a plugin system**, that constraint does
not apply; see the tutorial for the PyInstaller-vs-Nuitka decision guide.

---

## 7. Antivirus / VirusTotal Considerations

**No evidence exists in this repository.** Specifically:

- No `UPX`, `upx`, `signtool`, `certificate`, `Authenticode`, `SmartScreen`,
  `VirusTotal`, `antivirus`, `Defender`, `false positive` handling *in the build
  code* other than the signing steps.
- The only relevant, verifiable statement is the workflow comment at
  `make_bundle_conda.yml:470-472`:
  > "We are signing with Apple's certificate to provide _something_. This is not
  > trusted by Windows so the warnings are still there, but curious users will be
  > able to check it's actually us if necessary."

  And the Azure Code Signing comment at `make_bundle_conda.yml:599-602`:
  > "Azure Code Signing has a monthly quota... These certificates are shared with
  > other NumFOCUS projects, so we only sign final releases."

**What this repository genuinely demonstrates about AV reputation:**

1. **Code signing is treated as the reputation mechanism.** Both the stopgap and
   the proper Azure signature exist to improve trust in the executable.
2. **Signing the installer, not the frozen app** — there is no inner frozen
   executable to sign; the thing users download is the signed installer.
3. **Transparency** (public source, public releases, lockfiles, license bundles)
   is the non-signature layer of trust.

**What it does NOT demonstrate:** any relationship between installer technology
(constructor/NSIS), compression, or onefile-vs-onedir and AV detection rates.
Those topics are covered (honestly, with no guarantees) in the tutorial.

---

## 8. Windows Installer

- Technology: **NSIS**, produced by `constructor` (conda's installer builder).
  Constructor delegates EXE generation to its NSIS templates.
- This is the same installer technology used by Anaconda/Miniconda distributions.
- The installer is a graphical, wizard-style NSIS executable with:
  - welcome/header/icon images (generated by `_generate_background_images` in
    `build_installers.py:178-211` from the napari logo),
  - default paths per install scope (user/domain/all-users),
  - shortcut creation via `menuinst` (the `napari-menu` package provides the
    menu JSON and icons),
  - optional code signing (PFX or Azure).
- Constructor supports `.exe` on Windows, `.pkg` + `.sh` on macOS, `.sh` on Linux.
  It does **not** produce MSI/MSIX.

### Reusability assessment for a PyQt6 project

NSIS-based installers produced by `constructor` are a **conda-first** approach:
they install a conda environment, not a frozen app. That is only relevant if you
want a conda-managed, plugin-installable runtime. For a classic PyQt6 app, tools
like Inno Setup / NSIS directly around a PyInstaller/Nuitka onedir are simpler and
more common. Section 8 of the tutorial covers both.

---

## 9. Windows Code Signing

The complete Windows signing sequence in this repository:

```text
constructor build
      ↓  (all signed runs: schedule/push on main/PRs from main repo)
Apple Developer cert as .pfx  (make_bundle_conda.yml:464-478)
      ↓  constructor embeds it via CONSTRUCTOR_SIGNING_CERTIFICATE
Napari .exe installer (signed with Apple cert — NOT Windows-trusted)
      ↓  (final releases only: push of refs/tags/v*)
Azure login (make_bundle_conda.yml:588-597)
      ↓
azure/artifact-signing-action (make_bundle_conda.yml:604-614)
  endpoint, signing-account-name, certificate-profile-name,
  files-folder=_work/, files-folder-filter=exe,
  file-digest=SHA256, timestamp-rfc3161 (Microsoft timestamp server),
  timestamp-digest=SHA256
      ↓
Get-AuthenticodeSignature verification — FAILS the build if Status != 'Valid'
      (make_bundle_conda.yml:616-631)
      ↓
SHA256 checksum files generated per .exe  (make_bundle_conda.yml:633-640)
      ↓
upload to GitHub Release
```

Notes:

- The **stopgap Apple-cert signature** is applied by `constructor` itself during
  the build (through `definitions['signing_certificate']`, read from
  `CONSTRUCTOR_SIGNING_CERTIFICATE` at `build_installers.py:387-389`).
- The **proper Azure Code Signing** signature is applied *after* the build, as a
  post-processing step on the finished `.exe` (which therefore ends up with both
  signatures or a re-sign, since Azure signing signs the existing file).
- Certificate material is **not stored in the repo**. Only secret *names* are
  referenced:
  `WINDOWS_SIGNING_AZURE_CLIENT_ID`,
  `WINDOWS_SIGNING_AZURE_CLIENT_SECRET_VALUE`,
  `WINDOWS_SIGNING_AZURE_SUBSCRIPTION_ID`,
  `WINDOWS_SIGNING_AZURE_TENANT_ID`,
  `WINDOWS_SIGNING_ENDPOINT`,
  `WINDOWS_SIGNING_ACCOUNT_NAME`,
  `WINDOWS_SIGNING_PROFILE_NAME`,
  plus `CONSTRUCTOR_SIGNING_CERTIFICATE` and `CONSTRUCTOR_PFX_CERTIFICATE_PASSWORD`
  (fed from `APPLE_APPLICATION_CERTIFICATE_BASE64`/`_PASSWORD`).
- Timestamping uses the Microsoft RFC 3161 timestamp server.
- SHA256 checksums are produced but the `.sha256` files are **not** uploaded to
  the release (only the installer and lockfile are; see section 16). The hashes
  are also recorded by GitHub Releases automatically (the release assets API
  returns a `digest` field).

---

## 10. Linux

**Packaging mechanism: conda `constructor` text-based `.sh` installer.**

- `build_installers.py:325-332`:
  ```python
  if LINUX:
      definitions['default_prefix'] = os.path.join(
          '$HOME', '.local', INSTALLER_DEFAULT_PATH_STEM)
      definitions['license_file'] = os.path.join(resources, 'bundle_license.txt')
      definitions['installer_type'] = 'sh'
  ```
- The `.sh` is a self-extracting shell script that installs a full conda
  installation under `~/.local/napari-<version>`. It is **not** an AppImage and
  **not** a `.deb`.
- Desktop integration: `napari-menu` package + `menuinst` create a
  `~/.local/share/applications/napari*.desktop` entry. This is verified in CI
  (`make_bundle_conda.yml:690`).
- CI tests the Linux installer (`make_bundle_conda.yml:674-690`) by running it
  headless with `-bfp <prefix>`, activating the installed conda env, and launching
  `napari --info` under `xvfb-run`.
- The build machine is `ubuntu-24.04`. Because the installer ships **all** of its
  own libraries (Python, Qt, everything) as conda packages, glibc is the only
  real system dependency — matching the *oldest* glibc of the conda-forge
  "sysroot" used to build the packages, not the Ubuntu version itself. This is the
  standard conda-portability approach: conda packages are built against a
  `__glibc` pseudo-package minimum and the solver refuses to install on systems
  with an older glibc.

---

## 11. AppImage

**Not produced.** No AppImage, AppDir, `linuxdeploy`, `appimagetool`,
`appimage-builder`, or `.desktop`-in-AppDir logic exists. NAP-2 documents that
AppImage and DMG were formats of the *previous Briefcase-based* pipeline and were
deliberately dropped when the project migrated to `constructor`:

> "constructor does not support the AppImage format for Linux or DMG for macOS,
> which were the ones previously used with Briefcase. We don't see this as a
> problem though, given the small number of downloads each format enjoyed in
> previous releases."

For AppImage packaging of a PyQt6 app, see the tutorial (general best practice,
not from this repo).

---

## 12. Debian Package

**Not produced.** No `debian/`, no `DEBIAN/control`, no `dpkg-deb`, no `fpm`.
The Linux artifact is exclusively the conda `.sh` installer.

Conceptually, this project's dependency philosophy is closest to Debian option (A)
"bundle the runtime": the installer ships Python + Qt + all libraries. But it does
so through conda, not through a `.deb` that embeds binaries.

Relevant general knowledge for `.deb` packaging is covered in the tutorial.

---

## 13. macOS

**Packaging mechanism: conda `constructor` native `.pkg` installer.**

- `build_installers.py:334-362`:
  ```python
  if MACOS:
      definitions['pkg_name'] = INSTALLER_DEFAULT_PATH_STEM
      definitions['default_location_pkg'] = 'Library'
      definitions['installer_type'] = 'pkg'
      definitions['progress_notifications'] = True
      definitions['welcome_image'] = .../napari_1227x600.png
      definitions['welcome_file'] = .../osx_pkg_welcome.rtf  (version-injected)
      definitions['conclusion_text'] = ''
      definitions['readme_text'] = ''
      signing_identity_name  ← CONSTRUCTOR_SIGNING_IDENTITY (Developer ID Installer)
      notarization_identity_name ← CONSTRUCTOR_NOTARIZATION_IDENTITY (Developer ID Application)
  ```
- Default install location: `~/Library/napari-<version>` (PKG installers give
  little control; `default_location_pkg: Library` + `pkg_name: napari-<version>`).
- There is **no `.app` bundle and no DMG**. This is a *package installer*, not an
  application bundle. The "app" users launch is the conda-installed `napari`
  executable; the `napari-menu` package + `menuinst` create a
  `~/Applications/napari*.app` alias/shortcut (verified in CI at
  `make_bundle_conda.yml:709`).
- Two arch artifacts: `osx-64` (built on `macos-15-intel`) and `osx-arm64`
  (built on `macos-15`).

### macOS pipeline reconstruction

```text
constructor build (on macOS runner)
   → PKG containing base conda env + napari-<version> env
   → constructor codesigns bundled _conda binary with Developer ID Application cert
   → constructor productsigns the PKG with Developer ID Installer cert
        ↓
xcrun notarytool submit --key(.p8) --key-id --issuer --wait --timeout 30m
        ↓ (on failure: notarytool log + exit)
xcrun stapler staple <pkg>
        ↓
spctl --assess -vv --type install <pkg>  (must grep 'accepted')
        ↓
upload to GitHub Release
```

### macOS CI tests (make_bundle_conda.yml:692-709)

```bash
installer -pkg napari-....pkg -target CurrentUserHomeDirectory -dumplog
source ~/Library/napari-<ver>/etc/profile.d/conda.sh
conda activate ~/Library/napari-<ver>/envs/napari-<ver>
napari --info
python -c "import pathlib; assert list(pathlib.Path('~/Applications').expanduser().glob('napari*.app'))"
```

---

## 14. macOS Code Signing

Implemented, on macOS only, gated on secret availability and event type
(`make_bundle_conda.yml:416-455, 534-539`):

- Two certificates are used:
  - `Developer ID Installer` → product signing of the PKG
    (fed to constructor as `CONSTRUCTOR_SIGNING_IDENTITY`).
  - `Developer ID Application` → code signing of bundled binaries inside the PKG
    (required for notarization; fed as `CONSTRUCTOR_NOTARIZATION_IDENTITY`).
- The certs are stored **outside the repo** as base64-encoded `.p12` files in
  GitHub secrets (`APPLE_INSTALLER_CERTIFICATE_BASE64`,
  `APPLE_APPLICATION_CERTIFICATE_BASE64`, plus their passwords). They are imported
  into a temporary keychain (`security create-keychain`,
  `security import`, 6h lock timeout).
- **Important details** observed in the workflow:
  - `codesign` resolution: the conda environment may contain a different
    `codesign` which would clobber Apple's; the workflow moves it aside if it
    comes from the conda prefix (`make_bundle_conda.yml:450-455`).
  - Signing is limited to: scheduled nightly runs, pushes to main, and PRs from
    the main repo (not forks), to avoid burning through the shared NumFOCUS
    certificate quota.
- The "Hardened Runtime" entitlement is **not** configured here (that setting
  belongs to `.app`-style bundles; this is a PKG installer of a conda env).

---

## 15. macOS Notarization

Implemented (`make_bundle_conda.yml:534-585`), using **App Store Connect API
keys** (the modern `notarytool` method), with these secrets:

| Secret | Purpose |
|---|---|
| `APPLE_NOTARIZATION_ISSUER_ID` | Issuer ID of the ASC API key |
| `APPLE_NOTARIZATION_KEY_ID` | Key ID of the ASC API key |
| `APPLE_NOTARIZATION_AUTHKEY_BASE64` | The `.p8` key file, base64-encoded |

Sequence: decode `.p8` → `pkgutil --check-signature` (abort early if unsigned) →
`xcrun notarytool submit --key --key-id --issuer --output-format json --wait
--timeout 30m` → on failure fetch `notarytool log` and fail → `xcrun stapler
staple` → `spctl --assess -vv --type install` must match `accepted`.

Notarization requires an Apple Developer account ($99/year) with the Developer ID
program. There is no free alternative for *trusted* macOS distribution.

---

## 16. GitHub Actions

### Workflow: `make_bundle_conda.yml` (in this repo, reusable via `workflow_call`)

**Triggers** (this file):
- `pull_request` to `main` touching packaging-relevant paths (build script,
  recipe, environments, the workflow itself).
- `workflow_call` — invoked by `napari/napari` with an `event_name` input and
  `secrets: inherit`.
- `workflow_dispatch` (manual) with an optional `ref`.

**Caller** (`napari/napari .github/workflows/make_bundle_conda.yml`):
```yaml
on:
  push: { tags: ["v*"] }
  schedule: [{ cron: "0 0 * * *" }]
jobs:
  packaging:
    uses: napari/packaging/.github/workflows/make_bundle_conda.yml@main
    secrets: inherit
    with:
      event_name: ${{ github.event_name }}
```
So the pipeline runs: **on every tag `v*`** (final release), **every night**
(nightly), and **manually**. The `event_name` (schedule/push) controls *whether*
signing/upload happens.

**Job 1 — `packages`** (ubuntu-latest): builds napari conda packages by cloning
conda-forge's `napari-feedstock`, replacing its recipe with this repo's
`conda-recipe/`, patching version + sdist path, `conda-smithy rerender`, then
running conda-forge's own Docker build scripts. Outputs are `.conda`/`.tar.bz2`
`noarch` packages, uploaded to `anaconda.org/napari` (only on nightly schedule or
tag events; RCs/devs → `nightly` label) and also passed as a workflow artifact.

**Job 2 — `prepare_matrix`** (ubuntu-latest): builds a 4-element matrix by
parsing the `installer_platforms` input (default all four).

| runner | target-platform |
|---|---|
| `ubuntu-24.04` | `linux-64` |
| `macos-15-intel` | `osx-64` |
| `macos-15` | `osx-arm64` |
| `windows-2025` | `win-64` |

**Job 3 — `installers`** (matrix, 4 runs in parallel, `fail-fast: false`):
as detailed in section 3. Secrets are checked for availability first
(`SIGNING_SECRETS_AVAILABLE` env flag) and steps are gated with `if:` conditions.

**Secrets referenced** (names only, never values):

| Secret | Where used | Purpose |
|---|---|---|
| `ANACONDA_TOKEN` | packages job | upload conda packages to anaconda.org/napari |
| `APPLE_APPLICATION_CERTIFICATE_BASE64` | macOS keychain + Windows PFX | .p12 app cert |
| `APPLE_APPLICATION_CERTIFICATE_PASSWORD` | both | password for app cert |
| `APPLE_INSTALLER_CERTIFICATE_BASE64` | macOS keychain | .p12 installer cert |
| `APPLE_INSTALLER_CERTIFICATE_PASSWORD` | macOS keychain | password for installer cert |
| `APPLE_NOTARIZATION_ISSUER_ID` | notarize step | ASC API issuer |
| `APPLE_NOTARIZATION_KEY_ID` | notarize step | ASC API key id |
| `APPLE_NOTARIZATION_AUTHKEY_BASE64` | notarize step | ASC API .p8 key |
| `TEMP_KEYCHAIN_PASSWORD` | macOS keychain | throwaway keychain password |
| `WINDOWS_SIGNING_AZURE_CLIENT_ID` | Azure login | Azure service principal |
| `WINDOWS_SIGNING_AZURE_CLIENT_SECRET_VALUE` | Azure login | Azure client secret |
| `WINDOWS_SIGNING_AZURE_SUBSCRIPTION_ID` | Azure login | Azure subscription |
| `WINDOWS_SIGNING_AZURE_TENANT_ID` | Azure login | Azure tenant |
| `WINDOWS_SIGNING_ENDPOINT` | artifact-signing | Azure Code Signing endpoint |
| `WINDOWS_SIGNING_ACCOUNT_NAME` | artifact-signing | ACS account |
| `WINDOWS_SIGNING_PROFILE_NAME` | artifact-signing | ACS cert profile |

**Release asset upload**: On `push` of tag `v*`, the workflow fetches the
existing GitHub Release (created by napari/napari's `make_release.yml` via
`gh release create`) using `bruceadams/get-release`, then uploads the installer
and lockfile via `actions/upload-release-asset`.

### Other workflows

- `upstream_checks.yml` — nightly + PR: diffs `napari/napari:pyproject.toml` since
  yesterday and opens an issue reminding maintainers to sync the conda recipe.
- `zimor.yml` — runs **zizmor** (a security linter for GitHub Actions) on push/PR;
  the workflow sets `permissions: {}` at top level (least privilege) and grants
  scoped permissions per-job. The repo pins **every action to a full commit SHA**
  (e.g. `actions/checkout@3d3c42e5... # v7.0.1`), and `dependabot.yml` keeps them
  updated (monthly, grouped).

---

## 17. Resource Handling

Resources in this project's *installer* pipeline:

- **Icons** for installers and shortcuts are downloaded at build time from the
  `napari/resources` GitHub release
  (`build_installers.py:77-79, 124-134`; `conda-recipe/recipe.yaml:181-186`):
  `gradient-plain-light.ico`, `gradient-padded-light.icns`, `.png` variants.
- **Installer graphics** (welcome/header/background images) are generated with
  **Pillow** at build time from the logo
  (`build_installers.py:178-211`), sized per platform
  (`napari_164x314.png` for Windows sidebar/banner, `napari_1227x600.png` for
  macOS welcome, none for text-based `.sh`).
- **License/readme text**: `bundle_license.rtf`/`bundle_license.txt` and
  `bundle_readme.md` are read from the *napari source repo* `resources/` directory
  (passed via `--location ../napari`), not from this repo.
- **License collection**: `constructor`'s `build_outputs > licenses` key makes the
  installer generate `_work/licenses.json`, which the script zips into
  `licenses.<OS>-<ARCH>.zip` (`build_installers.py:471-485`).
- **Lockfiles**: `build_outputs > lockfile` emits `lockfile.napari-*.txt`, which is
  post-processed to rewrite local `file://` channel paths to the remote
  anaconda.org channel (`build_installers.py:488-513`).

### Implications

Because this is a conda installer, resources live inside conda packages and the
conda prefix at runtime — there is no freeze-time resource-location problem
(`sys._MEIPASS` etc.). For a PyInstaller/Nuitka-based PyQt6 app, resource handling
is entirely different; see tutorial section on resources.

---

## 18. PyQt6 / Qt Plugins

- **Qt binding bundled: PySide6**, pinned `>=6.7.1,<6.11`; Qt `6.11` explicitly
  excluded because it caused napari dock widget and layout regressions
  (recipe.yaml:86; pyproject comment in napari/napari).
- **PyQt6 is supported as an alternative** via `run_constraints`:
  `pyqt6 >=6.5,!=6.6.1,<6.11` (recipe.yaml:88). But the *installer* always ships
  PySide6 (`build_installers.py:275`), and the bundled environment is forced to it
  with a `conda-meta/state` file setting `QT_API: pyside6`
  (`build_installers.py:236-245`).
- napari core uses **QtPy** to abstract over bindings (`qtpy>=2.4.0`,
  recipe.yaml:75), and even has an import-linter contract forbidding direct
  `PyQt5/PyQt6/PySide6` imports (napari/napari `pyproject.toml`).
- **Qt plugins** (platform plugins, image formats, styles, etc.) are handled
  implicitly by the conda `pyside6` package — conda-forge packages ship the Qt
  plugin directories inside the prefix, and Qt finds them relative to the
  `Qt6` libraries. There is **no manual plugin bundling** anywhere in this repo.
  This is the *opposite* of the PyInstaller/Nuitka situation where you must
  explicitly bundle `platforms/`, `imageformats/`, etc.

---

## 19. Translations

**No translation machinery in this repo.** No `QTranslator`, `.qm`, `.ts`,
`TranslationsPath`, `locale`/`i18n` handling. Search results are empty.

Inference (not from repo evidence): napari's own Qt translations would be handled
by the conda `pyside6`/`pyqt6` packages, which ship Qt's `translations/` directory
in the conda prefix — so Qt's standard dialogs can find `.qm` files. This is a
conda advantage: translations come along automatically with the package.

For frozen apps (PyInstaller/Nuitka) Qt translations are a known gotcha: you must
explicitly bundle Qt's `translations/qtbase_*.qm` (and your own `.qm`), and on some
setups set the library path. Covered in the tutorial.

---

## 20. Security and Release Integrity

| Practice | Present? | Evidence |
|---|---|---|
| Pin GitHub Actions to SHA | Yes | every action pinned with `@<sha> # vX.Y.Z` |
| Dependabot for actions | Yes | `.github/dependabot.yml` (monthly, grouped) |
| Workflow security linting (zizmor) | Yes | `.github/workflows/zimor.yml` |
| Least-privilege workflow permissions | Yes | `permissions: {}` top-level in zimor.yml; `contents: write` only on the installer job that needs it |
| Secret isolation (no values in repo) | Yes | secrets referenced by name only |
| GitHub artifact attestations (SLSA-ish) | For sdist/wheel in napari/napari (`attest-build-provenance-github`) | napari/napari make_release.yml; **not** in this repo's installer workflow |
| Release lockfiles (reproducible env) | Yes | `build_outputs: lockfile`, uploaded per platform |
| SHA256 checksums | Partial | generated for Windows `.exe` on tag runs only; uploaded release assets also get hashes via GitHub Release `digest` |
| License bundling/collection | Yes | `build_outputs: licenses`, `licenses.zip` artifact |
| Dependency pinning | Partial | conda specs with version bounds; no committed conda lock for the *installer* (lockfiles are generated, not used to rebuild) |
| Code signing | Yes (macOS full, Windows releases) | see sections 9, 14, 15 |
| Git tag signing | Not visible in this repo (release creation lives in napari/napari) | — |
| SBOM | No | — |

Note: the lockfiles are uploaded as *release artifacts* for end-users to
reproduce the environment, but the CI does **not** use them to build the
installer (they are produced *after* building).

---

## 21. Techniques Worth Reusing

1. **`workflow_call` separation**: keep packaging logic in a dedicated repo/action
   that the app repo calls with `secrets: inherit` and an `event_name` input.
   Clean, reusable, testable. `[HIGHLY RECOMMENDED]`
2. **Matrix computed by a prepare job** (instead of hardcoded in `strategy`)
   so platforms can be filtered via an input. `[USEFUL]`
3. **Gate signing by event type + secret availability**, and document *why*
   (shared certificate quota). Avoids burning expensive signatures on every PR.
   `[HIGHLY RECOMMENDED]`
4. **Test the installer, not just build it**: each OS job installs its own
   artifact headlessly and smoke-tests it (`--info`, shortcut existence).
   `[HIGHLY RECOMMENDED]`
5. **Post-build integrity steps**: signature verification that fails the build
   (`Get-AuthenticodeSignature -ne 'Valid'` → exit 1), checksum generation.
   `[HIGHLY RECOMMENDED]`
6. **Pre-build integrity**: `pkgutil --check-signature` before notarization.
   `[USEFUL]`
7. **Notarytool auth via App Store Connect API key** instead of app passwords.
   `[HIGHLY RECOMMENDED]`
8. **Temporary keychain pattern** for importing certificates on CI runners.
   `[USEFUL]`
9. **Version & artifact naming centralized in one script** (CLI flags
   `--version/--arch/--ext/--artifact-name`) so both the workflow and release
   naming agree. `[USEFUL]`
10. **License + lockfile collection as first-class build outputs**.
    `[USEFUL]`
11. **Action pinning to SHA + dependabot + zizmor**. `[HIGHLY RECOMMENDED]`
12. **Version-pinned conda environments** (`environments/*.yml`) instead of
    ad-hoc install steps. `[USEFUL]`

---

## 22. Techniques Specific to This Project (do not copy blindly)

1. **Conda/constructor installers as the packaging format.** Only makes sense
   if you want a conda-managed runtime, plugin installation at runtime, or a
   scientific ecosystem. Huge installers (~500-600 MB) and high complexity.
   `[PROJECT-SPECIFIC]`
2. **Signing Windows installers with an Apple certificate** as a stopgap — it is
   explicitly *not* trusted by Windows; only provides provenance metadata.
   `[NOT RECOMMENDED for a new project]` (do real Windows signing instead).
3. **Azure Code Signing with shared NumFOCUS certificates** — an organizational
   arrangement; requires Azure infrastructure and a quota budget.
   `[PROJECT-SPECIFIC]`
4. **Cloning & patching the conda-forge feedstock** to build packages with the
   same scripts conda-forge uses. `[PROJECT-SPECIFIC / REQUIRES FURTHER RESEARCH]`
5. **Two-environment layout** (base conda + `napari-<version>` env) for
   update-in-place. `[PROJECT-SPECIFIC, valuable only with plugin/update needs]`
6. **The `QT_API: pyside6` force** via `conda-meta/state`. `[PROJECT-SPECIFIC]`
7. **`.gitignore` PyInstaller leftovers** — vestigial, ignore. `[LEGACY]`

---

## 23. Problems or Weaknesses Found

1. **Huge installers**: 505-637 MB per platform (v0.9.0 release data). Every
   bundle ships a full conda + mamba + pip + uv + Python + PySide6 + full napari
   dependency tree. This is the price of the conda approach.
2. **Windows "signing" is incomplete for non-release builds** — Apple cert only;
   the team openly acknowledges SmartScreen warnings remain. End users of nightlies
   get no trusted signature.
3. **`construct.yaml` is written to the working directory** and cleanup relies on
   `atexit` handlers and a `NamedTemporaryFile` (empty file trick for a marker) —
   fragile if interrupted.
4. **The PFX password "strip" workaround** (`build_installers.py:427-434`) signals
   a secret hygiene problem upstream (password containing a newline).
5. **Two separate signing mechanisms on Windows** (constructor-embedded PFX vs
   post-build Azure) — more moving parts than a single signtool pass.
6. **Lockfiles are generated post-hoc and not used for reproducible builds** — a
   reproducibility gap.
7. **`.sha256` files generated but never uploaded to the release** — users can get
   hashes via the GitHub API but not from a checksum file attached to the release.
8. **No per-installer SBOM** (licenses are collected, but no machine-readable
   SBOM format).
9. **Release creation depends on `napari/napari`'s workflow** — the packaging repo
   cannot create a release on its own; asset upload requires the release to already
   exist (potential race documented in the workflow).
10. **Documentation drift**: the packaging docs say the recipe file is
    `conda-recipe/meta.yaml` ("Check the file `conda-recipe/meta.yaml`"), but the
    actual file is `conda-recipe/recipe.yaml` (converted to `rattler-build` in
    commit `1c8d871`). Minor, but real.

---

## 24. Recommended Approach for My PyQt6 Projects

See the companion `PYQT6_PACKAGING_TUTORIAL.md` for the full playbook. The
short version, informed by this repo:

- For a **classic PyQt6 desktop app** (no runtime plugin ecosystem), do **not**
  adopt conda/constructor. Use PyInstaller onedir or Nuitka standalone, an Inno
  Setup/NSIS installer for Windows, AppImage for Linux, and a signed+notarized
  `.app`/DMG for macOS.
- **Reuse from napari**: the CI *shape* (workflow_call, prepare-matrix, gated
  signing, install-and-smoke-test the artifact), the macOS notarization sequence
  (notarytool + API key, stapler, spctl), Windows post-build signing + SHA256 +
  verification, SHA-pinned actions, zizmor, least-privilege permissions.
- **Do not copy**: conda/constructor installers (unless you adopt the conda
  ecosystem), the Apple-cert-for-Windows stopgap, feedstock cloning, the shared
  Azure signing arrangement.

---

## 25. Important Files to Study

| File | What to read |
|---|---|
| `build_installers.py` | The entire packaging logic: platform dispatch, construct.yaml generation, signing hooks, artifact naming. Start with `_definitions` (lines 283-403) and `cli` (531-585). |
| `.github/workflows/make_bundle_conda.yml` | Full CI: package build, matrix, installer build, signing, notarization, tests, release upload. |
| `conda-recipe/recipe.yaml` | The napari conda recipe (3 outputs), dependency bounds, Qt constraints. |
| `environments/ci_installers_environment.yml` | Exact tool versions needed to run constructor locally. |
| `conda-recipe/README.md` | Sync policy with conda-forge feedstock. |
| `README.md` | Local build instructions (quickstart + local packages). |
| napari/napari `make_release.yml` | Where the GitHub Release itself is created (asset upload target). |
| napari docs "Packaging" + NAP-2 | Design rationale and known history (Briefcase→constructor, Nuitka/PyOxidizer rejected). |

---

## 26. Commands Used by the Project

Local build (from README.md):

```bash
conda env create -n napari-packaging-installers --file environments/ci_installers_environment.yml
conda activate napari-packaging-installers
pip install -e ../napari --no-deps
CONSTRUCTOR_PYTHON_VERSION="3.13" python build_installers.py --location ../napari
# installers under _work/
```

Local package build (README.md):

```bash
conda create -n rattler-build rattler-build
conda activate rattler-build
CONDA_BLD_PATH=_work/packages/ rattler-build build --recipe conda-recipe/
```

Version/artifact introspection (workflow uses these):

```bash
CONSTRUCTOR_USE_LOCAL=1 python build_installers.py --version
python build_installers.py --installer-version
python build_installers.py --arch
python build_installers.py --ext
python build_installers.py --artifact-name
python build_installers.py --licenses   # post-build
python build_installers.py --lockfile   # post-build
```

CI smoke tests:

```bash
# Linux
bash napari-<v>-Linux-x86_64.sh -bfp "$PREFIX"
source "$PREFIX/etc/profile.d/conda.sh" && conda activate "$PREFIX/envs/napari-<v>"
xvfb-run --auto-servernum napari --info

# macOS
installer -pkg napari-<v>.pkg -target CurrentUserHomeDirectory -dumplog

# Windows
cmd.exe /c start /wait napari-<v>.exe /S /D=...
```

---

## 27. Final Conclusions

1. **This is not a PyInstaller/Nuitka project.** It is a **conda `constructor`**
   packaging repository. Any expectation of frozen-binary techniques here is
   unfounded.
2. The repository's value to an outside developer is concentrated in three areas:
   **CI orchestration** (workflow_call + matrix + gated signing + installer smoke
   tests), **macOS signing/notarization** (complete, modern, working), and
   **release hygiene** (lockfiles, licenses, checksums, provenance).
3. Its Windows signing story is a **work in progress** — a stopgap Apple signature
   for non-release builds, and proper Azure Code Signing only for final releases.
   This honestly documents the difficulty of Windows trust for open source.
4. **Nothing in this repository supports claims about antivirus false-positive
   reduction** for PyInstaller/Nuitka binaries. Do not generalize from it.
5. For a new PyQt6 application, reuse napari's *process*, not its *technology*:
   install-and-test-your-artifact, sign consistently, verify signatures in CI,
   publish lockfiles + checksums, and keep the packaging pipeline in its own
   reusable workflow.

---

## Questions answered (quick reference)

1. How does this project package Windows? → conda `constructor` NSIS `.exe` installer.
2. PyInstaller/Nuitka? → Neither. `constructor` (conda).
3. Why? → Plugin ecosystem needs runtime-installable Python packages; NAP-2 rejects freezing (immutable binaries); Briefcase was deprecated.
4. onefile or onedir? → N/A (installer + conda prefix layout).
5. UPX? → No.
6. Sign Windows executables? → There is no inner frozen exe; the installer is signed (Apple-cert stopgap on all signed runs; Azure Code Signing on final releases).
7. Sign Windows installers? → Yes, both mechanisms above.
8. Installer technology? → NSIS (via constructor).
9. Measures to reduce false AV detections? → Only signing (proper trust chain) + transparency. No evidence beyond that.
10. Which supported by evidence? → Signing is evidenced; AV-rate correlation is not.
11. Would Nuitka be a reasonable alternative? → For *napari's* use case, no (plugin ecosystem). For a plain PyQt6 app, yes — see tutorial.
12. How does it distribute Linux? → `.sh` conda installer.
13. AppImage? → No (dropped after Briefcase migration).
14. How was the AppImage created? → Previously by Briefcase; now gone. Not in this repo.
15. `.deb`? → No.
16. Debian packaging? → None.
17. Qt/PyQt6 deps on Linux? → Bundled via conda packages (PySide6 shipped; PyQt6 supported as alternative binding).
18. macOS `.app`? → No `.app` bundle; PKG installer + `~/Applications/napari.app` shortcut via menuinst.
19. `.dmg`? → No (dropped after Briefcase migration).
20. Apple code signing? → Yes (Developer ID Installer + Application certs).
21. Notarization? → Yes (`notarytool`, ASC API key, stapling, `spctl`).
22. Qt plugins? → Implicitly via conda `pyside6` package.
23. Translations? → No explicit handling in this repo; conda packages carry Qt translations.
24. Icons/resources? → Downloaded from `napari/resources` releases; installer graphics generated with Pillow.
25. GitHub Actions? → 3 jobs: packages (ubuntu), prepare_matrix, installers (4-platform matrix).
26. Secrets? → `ANACONDA_TOKEN`, `APPLE_*` (5), `TEMP_KEYCHAIN_PASSWORD`, `WINDOWS_SIGNING_*` (7). Names only.
27. Reuse? → CI shape, macOS notarization, signature verification, checksums, action pinning/zizmor, testing installers.
28. Avoid? → conda/constructor for plain apps, Apple-cert Windows stopgap, feedstock cloning, shared Azure quota model.
29. What would I change today? → Use Nuitka/PyInstaller onedir + Inno Setup; proper EV/OV code signing; publish checksums + SBOM; verify signatures in CI.
30. Recommended end-to-end architecture? → See tutorial section 10.
