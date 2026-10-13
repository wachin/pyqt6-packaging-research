#!/usr/bin/env python3
"""Build a traceable *evidence pack* for the PyQt6 packaging research repository.

Why this exists
---------------
The case studies describe and cite the real packaging files (for example
``packaging/build-appimage.sh`` lines 41-49) but do not embed them. Most of those
files live inside Git submodules pinned to a commit, so a citation breaks as soon
as a submodule is updated. (TBO is the exception: it is an ordinary independent
clone ignored by this repository.) This script copies the files that actually
participate in producing (or installing) a distributable into::

    <results-dir>/_evidence/<original/relative/path>

Mirroring the original repository-relative layout is deliberate: a citation such
as ``packaging/build-appimage.sh#L41-L49`` resolves directly against the
extracted tree.

Provenance is the point
-----------------------
Each extraction records the upstream URL, the exact commit, the licence, and a
SHA-256 per file, in ``_evidence/PROVENANCE.md`` plus ``_evidence/SHA256SUMS``. A
file copied without its commit is worthless as evidence.

Nothing here is relicensed. The extracted files remain under their upstream
licence -- note that CARA, CustomKnight-Creator, dikte and TBO are GPL, while
napari and pyzo are BSD, and napari/packaging carries no licence file. Reusing
GPL code in your own application has licensing consequences.

Usage
-----
    python3 tools/extract_evidence.py [--dry-run]

Run from the repository root (or anywhere; paths are resolved from the script
location).
"""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# --------------------------------------------------------------------------- #
# Whitelist
#
# Two admission rules:
#   (a) the file participates in producing or installing a distributable
#       (spec / iss / nsi / build scripts / debian / CI release workflows /
#       entitlements / .desktop / metadata / dependency manifests); or
#   (b) the studies cite it while discussing packaging-relevant runtime
#       behaviour (resource resolution, freeze entry point, external-binary
#       environment repair, Qt translations, plugin/asset collection).
#
# Application source, tests and UI files are deliberately out of scope unless
# they fall under rule (b).
# --------------------------------------------------------------------------- #

PROJECTS: list[dict] = [
    {
        "key": "dikte",
        "submodule": "dikte",
        "results": "dikte-resultados",
        "label": "dikte - voice-dictation tray app",
        "note": "Only implemented AppImage in the case set; onedir payload wrapped in Inno/DMG/AppImage.",
        "files": [
            ("packaging/dikte.spec", "PyInstaller spec: onedir (EXE(exclude_binaries=True) + COLLECT) with targeted Qt module excludes."),
            ("packaging/dikte.iss", "Inno Setup installer: per-user, PrivilegesRequired=lowest, bundles FFmpeg."),
            ("packaging/build-appimage.sh", "Hand-built AppDir + AppRun + appimagetool; the only observed AppImage implementation."),
            ("packaging/build-dmg.sh", "macOS DMG via hdiutil UDZO per architecture; ad-hoc signing only."),
            ("packaging/build-windows.ps1", "Windows build driver; pins and SHA-256-verifies the downloaded FFmpeg build."),
            ("packaging/entry.py", "Frozen entry point used by the PyInstaller spec."),
            ("install.sh", "Source/system install script; documents distro PyQt6 package names (native-dependency model)."),
            ("install.ps1", "Windows source install script."),
            ("scripts/install-mac.sh", "macOS source install script."),
            ("scripts/release.sh", "Local release automation."),
            ("scripts/update.sh", "Update script shipped to users."),
            ("scripts/uninstall.sh", "Uninstall script shipped to users."),
            (".github/workflows/build.yml", "Build matrix on ubuntu-22.04 (GLIBC floor) producing the AppImage and platform archives."),
            (".github/workflows/release.yml", "Tag-gated release automation (rolling + v* tags, gh release create)."),
            (".github/workflows/tests.yml", "CI tests."),
            ("dikte/integrate.py", "Cite (b): restores LD_LIBRARY_PATH and the CA store before launching bundled host binaries."),
            ("dikte/i18n.py", "Cite (b): Qt translation loading via QTranslator/QLibraryInfo."),
            ("dikte/paths.py", "Cite (b): development vs frozen path resolution."),
            ("dikte/__main__.py", "Cite (b): entry-point/guarded start."),
        ],
    },
    {
        "key": "CARA",
        "submodule": "CARA",
        "results": "CARA-resultados",
        "label": "CARA - chess analysis app",
        "note": "Full macOS Developer ID signing + notarization from a local script; three separate platform specs.",
        "files": [
            ("CARA_windows.spec", "PyInstaller spec; requests upx=True (actual Windows compression unverified)."),
            ("CARA_linux.spec", "PyInstaller spec for the Linux onedir bundle."),
            ("CARA_macos.spec", "PyInstaller spec producing the macOS BUNDLE .app."),
            ("packaging/macos/entitlements.plist", "Entitlements used for hardened-runtime signing."),
            ("scripts/build_macos_signed.sh", "codesign Developer ID + hardened runtime + notarytool submit --wait + stapler."),
            (".github/workflows/build-appbundles.yml", "macOS/Windows bundle builds."),
            (".github/workflows/build-linux-appbundles.yml", "Linux builds on Ubuntu 22.04; comments record the GLIBC 2.38/24.04 failure."),
            (".github/workflows/tests.yml", "CI tests."),
            (".github/ci/linux-pip-constraints.txt", "Pinned Linux CI constraints (the closest thing to dependency pinning in this project)."),
            ("requirements.txt", "Runtime dependency list."),
            ("cara.py", "Cite (b): multiprocessing.freeze_support() guard for PyInstaller workers."),
            ("app/utils/path_resolver.py", "Cite (b): central dev / Resources / _internal resolver; avoids sys._MEIPASS."),
            ("app/services/uci_communication_service.py", "Cite (b): strips loader variables before launching the external engine."),
        ],
    },
    {
        "key": "pyzo",
        "submodule": "pyzo",
        "results": "pyzo-resultados",
        "label": "pyzo - scientific Python IDE",
        "note": "Mature onedir + Inno/DMG/ZIP wrappers; full macOS signing and notarization in CI; the only project that curates Qt modules explicitly.",
        "files": [
            ("freeze/installerBuilderScript.iss", "Inno Setup script (Win64 only, per-user default)."),
            ("freeze/pyzo_freeze.py", "Freeze driver; explicitly selects Core/Gui/Widgets/PrintSupport and excludes the rest."),
            ("freeze/pyzo_package.py", "Freeze packaging helper."),
            ("freeze/boot.py", "Cite (b): frozen bootstrap; uses sys._MEIPASS to locate shipped source."),
            ("freeze/frozen_libs.txt", "Libraries kept in the frozen bundle."),
            ("freeze/pyzo_test_frozen.py", "Frozen-artifact test."),
            ("freeze/_settings/README.txt", "Notes shipped beside the frozen settings."),
            ("pyzo/resources/org.pyzo.Pyzo.desktop", "Linux desktop entry."),
            ("pyzo.appdata.xml", "AppStream metadata."),
            ("pyproject.toml", "Build/packaging metadata."),
            (".github/workflows/cd.yml", "Release pipeline: P12 to temp keychain, codesign --deep --options runtime --timestamp, notarytool, staple, gh release create --verify-tag."),
            (".github/workflows/ci.yml", "CI tests."),
            ("pyzo/util/_locale.py", "Cite (b): QTranslator + QLibraryInfo, ships pyzo_*.qm and tries Qt's."),
            ("pyzo/qt/__init__.py", "Cite (b): Qt binding selection layer."),
            ("pyzo/_start.py", "Cite (b): application start path."),
            ("pyzolauncher.py", "Cite (b): launcher entry point."),
            ("tests/check_log.py", "Cite (b): log check used by the frozen-artifact smoke test in CI."),
        ],
    },
    {
        "key": "CustomKnight-Creator",
        "submodule": "CustomKnight-Creator",
        "results": "CustomKnight-Creator-resultados",
        "label": "CustomKnight-Creator - Hollow Knight mod tool",
        "note": "The negative example: onefile on all platforms, ubuntu-latest GLIBC, no signing, no release automation.",
        "files": [
            (".github/workflows/package.yml", "The entire packaging story: pyinstaller -F -w per OS, upload-artifact; no spec file, no signing, no release."),
            ("requirements.txt", "Exact top-level pins (PyQt6==6.3.1, pyinstaller==5.1) - partial pinning only."),
            ("main.py", "Cite (b): resource resolution via os.path.dirname(__file__) plus a broken qrc reference."),
        ],
    },
    {
        "key": "napari",
        "submodule": "napari",
        "results": "napari-resultados",
        "label": "napari - scientific image viewer",
        "note": "Freezing rejected in favour of conda constructor; delegates all packaging to napari/packaging.",
        "files": [
            (".github/workflows/make_bundle_conda.yml", "Thin caller: delegates to napari/packaging/.github/workflows/make_bundle_conda.yml@main with secrets: inherit."),
            (".github/workflows/make_release.yml", "Wheel release; attest-build-provenance for wheels."),
            (".github/workflows/reusable_build_wheel.yml", "Reusable wheel build."),
            (".github/dependabot.yml", "Dependency update automation."),
            ("MANIFEST.in", "Source-distribution file manifest."),
            ("pyproject.toml", "Project metadata and dependency bounds (PySide6 < 6.11 etc)."),
            ("resources/conda_menu_config.json", "Menu entry installed by menuinst when the conda package is installed."),
            ("resources/bundle_license.txt", "Licence text shipped in the bundle."),
            ("resources/bundle_readme.md", "Readme shipped in the bundle."),
            ("binder/Desktop/napari.desktop", "Desktop entry."),
            ("src/napari/utils/logo.py", "Cite (b): importlib.resources used to locate bundled logos (recommended modern pattern)."),
            ("src/napari/_qt/__init__.py", "Cite (b): QtPy binding abstraction."),
            ("src/napari/_qt/qt_event_loop.py", "Cite (b): Qt event-loop handling relevant to frozen/packaged execution."),
            ("src/napari/resources/_icons.py", "Cite (b): icon/resource collection."),
        ],
    },
    {
        "key": "napari-packaging",
        "submodule": "napari-packaging",
        "results": "napari-packaging-resultados",
        "label": "napari/packaging - dedicated packaging + installer infrastructure",
        "note": "The most auditable installer pipeline in the set: conda constructor + NSIS/pkg, SHA-pinned actions, artifact smoke test. NO LICENCE FILE - evidence only, do not reuse.",
        "files": [
            (".github/workflows/make_bundle_conda.yml", "727-line installer pipeline: signing, notarization with an API key, staple, spctl, and an install-and-launch artifact smoke test."),
            (".github/workflows/upstream_checks.yml", "Upstream compatibility checks."),
            (".github/workflows/zimor.yml", "zizmor workflow security linting (note the filename typo upstream)."),
            (".github/dependabot.yml", "Dependency update automation."),
            ("build_installers.py", "Driver that turns conda packages into NSIS/pkg/shell installers."),
            ("conda-recipe/recipe.yaml", "Conda recipe used to build the packages that feed the installers."),
            ("conda-recipe/yum_requirements.txt", "System libraries needed during the conda build."),
            ("conda-recipe/README.md", "Recipe documentation."),
            ("environments/ci_installers_environment.yml", "Conda environment for the installer build."),
            ("environments/ci_packages_environment.yml", "Conda environment for the package build."),
            (".pre-commit-config.yaml", "Pre-commit hooks."),
            (".github/PYPROJECT_TOML_UPDATED_TEMPLATE.md", "Template used to keep napari's pyproject in sync."),
        ],
    },
    {
        "key": "TBO",
        "submodule": "PyQt6-Apps/TBO",
        "results": "03-Promt-MAESTRO-resultado/TBO-SOLUCIONES",
        "label": "TBO - own PyQt6 app (Nuitka on Windows, PyInstaller on macOS/Linux)",
        "note": "Not a case study: this is the owner's own application, kept as an independent clone rather than a sub-module, and the only source of validated .deb evidence, plus a Flatpak manifest. Findings recorded in SOLUCIONES-TBO.md and DEBIAN-PACKAGE-AUDIT.md in this same folder.",
        "files": [
            ("packaging/build_appimage.sh", "AppImage build script."),
            ("packaging/build_windows_nuitka.ps1", "Windows build (Nuitka) driver - the shipping Windows build."),
            ("packaging/build_windows_pyinstaller.ps1", "Windows build (PyInstaller) driver, added to make the two freezers comparable on the same application."),
            ("packaging/build_macos.sh", "macOS build (PyInstaller) driver."),
            ("packaging/build.sh", "Top-level local packaging driver (includes the Flatpak step)."),
            ("packaging/generate_icon.py", "Icon generator; the explicit output-dir bug is recorded in SOLUCIONES-TBO.md."),
            ("packaging/update_translations.sh", "Translation (.qm) generation."),
            ("packaging/tbo.desktop", "Linux desktop entry."),
            ("packaging/org.tbo.TBO.appdata.xml", "AppStream metadata."),
            ("packaging/org.tbo.TBO.json", "Flatpak manifest (org.kde.Platform 6.8 runtime)."),
            ("packaging/org.tbo.TBO.svg", "Scalable application icon."),
            ("packaging/requirements-windows.txt", "Pinned Windows build dependencies (Nuitka toolchain)."),
            ("packaging/requirements-windows-pyinstaller.txt", "Pinned Windows dependencies for the PyInstaller comparison build."),
            ("packaging/requirements-linux.txt", "Pinned Linux build dependencies."),
            ("packaging/requirements-macos.txt", "Pinned macOS build dependencies."),
            ("debian/control", "Debian metadata: Depends/Recommends - the native-dependency model, validated in CI."),
            ("debian/rules", "debhelper rules, including override_dh_auto_test to skip Qt GUI tests."),
            ("debian/changelog", "Debian changelog driving the package version."),
            ("debian/copyright", "Debian copyright/attribution file."),
            ("debian/source/format", "Source package format (3.0 quilt)."),
            (".github/workflows/build.yml", "Release pipeline producing the wheel/sdist, .deb, Flatpak, Windows and macOS artifacts."),
            (".github/workflows/ci.yml", "CI tests."),
            ("docs/GitHub-Actions-Solutions/PACKAGING-RESOURCE-COLLECTION-BUG.md", "The resource-collection defect: bundles that built green and shipped without their icons and translations."),
            ("pyproject.toml", "Build metadata (version source for the .deb and Nuitka --file-version)."),
        ],
    },
]

LICENCE_CANDIDATES = (
    "LICENSE",
    "LICENSE.md",
    "LICENSE.txt",
    "LICENCE",
    "LICENCE.md",
    "COPYING",
    "COPYING.md",
)

LICENCE_PATTERNS = (
    (r"GNU LESSER GENERAL PUBLIC LICENSE", "LGPL"),
    (r"GNU GENERAL PUBLIC LICENSE", "GPL"),
    (r"MIT License", "MIT"),
    (r"Apache License", "Apache-2.0"),
    (r"Mozilla Public License", "MPL-2.0"),
    (r"Redistribution and use in source and binary forms", "BSD"),
)


def run_git(args: list[str], cwd: Path) -> str:
    """Return stripped stdout, or '' when the git command fails."""
    try:
        proc = subprocess.run(
            ["git", *args],
            cwd=cwd,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return ""
    return proc.stdout.strip() if proc.returncode == 0 else ""


def is_submodule(path: str) -> bool:
    """Whether `path` is still registered as a submodule in .gitmodules."""
    return bool(run_git(["config", "-f", ".gitmodules", "--get", f"submodule.{path}.url"], ROOT))


def source_url(path: str) -> str:
    """Upstream URL of a studied source tree.

    Most trees are sub-modules, so their URL comes from .gitmodules. TBO is the
    exception: it used to be a sub-module and is now an ordinary independent
    clone checked out under this repository and ignored by it, so its URL has to
    come from its own Git configuration.
    """
    url = run_git(["config", "-f", ".gitmodules", "--get", f"submodule.{path}.url"], ROOT)
    if url:
        return url
    url = run_git(["config", "--get", "remote.origin.url"], ROOT / path)
    return url or "(no remote recorded)"


def detect_licence(submodule: str) -> tuple[str, str]:
    """Return (spdx_guess, licence_file_relative_path)."""
    base = ROOT / submodule
    for name in LICENCE_CANDIDATES:
        candidate = base / name
        if not candidate.is_file():
            continue
        try:
            head = candidate.read_text(encoding="utf-8", errors="replace")[:4000]
        except OSError:
            continue
        for pattern, label in LICENCE_PATTERNS:
            if re.search(pattern, head, re.IGNORECASE):
                return label, name
        return "UNKNOWN (licence file present but not recognised)", name
    return "NO LICENCE FILE FOUND", ""


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="report what would be copied without writing anything")
    args = parser.parse_args()

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    index_rows: list[tuple[str, str, str, str, str, int, str]] = []
    failures: list[str] = []
    grand_total_bytes = 0
    grand_total_files = 0

    for project in PROJECTS:
        key = project["key"]
        submodule = project["submodule"]
        results = project["results"]
        sub_path = ROOT / submodule

        if not sub_path.is_dir():
            failures.append(f"{key}: submodule directory '{submodule}' not found (run 'git submodule update --init --recursive')")
            continue

        commit = run_git(["rev-parse", "HEAD"], sub_path) or "(unknown)"
        described = run_git(["describe", "--tags", "--always"], sub_path)
        url = source_url(submodule)
        tracked = "submodule" if is_submodule(submodule) else "independent clone (ignored by this repository)"
        licence, licence_file = detect_licence(submodule)
        dest_root = ROOT / results / "_evidence"

        print(f"\n=== {key} ===")
        print(f"  source    : {submodule} [{tracked}]")
        print(f"  commit    : {commit[:12]}{' (' + described + ')' if described else ''}")
        print(f"  licence   : {licence}{' [' + licence_file + ']' if licence_file else ''}")
        print(f"  target    : {dest_root.relative_to(ROOT)}")

        copied: list[tuple[str, int, str]] = []
        missing: list[str] = []

        for rel, why in project["files"]:
            src = sub_path / rel
            if not src.is_file():
                missing.append(rel)
                continue
            copied.append((rel, src.stat().st_size, why))

        if missing:
            failures.extend(f"{key}: missing {rel}" for rel in missing)

        if args.dry_run:
            for rel, size, _ in copied:
                print(f"    would copy {size:>8,} B  {rel}")
        else:
            if dest_root.exists():
                shutil.rmtree(dest_root)
            for rel, size, _ in copied:
                target = dest_root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(sub_path / rel, target)
                print(f"    copied {size:>8,} B  {rel}")

            sums = dest_root / "SHA256SUMS"
            with sums.open("w", encoding="utf-8") as handle:
                for rel, _, _ in copied:
                    handle.write(f"{sha256_of(dest_root / rel)}  {rel}\n")

            provenance = dest_root / "PROVENANCE.md"
            with provenance.open("w", encoding="utf-8") as handle:
                handle.write(f"# Provenance - {project['label']}\n\n")
                handle.write(
                    "Extracted by `tools/extract_evidence.py`. These files are **not** relicensed; "
                    "they remain under the upstream licence below. Read the licence before reusing "
                    "any of this in another project.\n\n"
                )
                handle.write("| Field | Value |\n|---|---|\n")
                handle.write(f"| Source tree | `{submodule}` |\n")
                handle.write(f"| Tracked as | {tracked} |\n")
                handle.write(f"| Upstream | {url} |\n")
                handle.write(f"| Pinned commit | `{commit}` |\n")
                if described:
                    handle.write(f"| Described as | `{described}` |\n")
                handle.write(f"| Licence | {licence}{f' (`{licence_file}`)' if licence_file else ''} |\n")
                handle.write(f"| Extracted (UTC) | {stamp} |\n")
                handle.write(f"| Files | {len(copied)} |\n")
                handle.write(f"| Total size | {sum(s for _, s, _ in copied):,} bytes |\n\n")
                handle.write(f"> {project['note']}\n\n")
                handle.write("## Files and why each one is here\n\n")
                handle.write("| Original path | Bytes | Why it is included |\n|---|---|---|\n")
                for rel, size, why in copied:
                    handle.write(f"| `{rel}` | {size:,} | {why} |\n")
                handle.write(
                    "\n## Integrity\n\nVerify the extracted tree against `SHA256SUMS`:\n\n"
                    "```bash\ncd \"$(dirname \"$0\")\" && sha256sum -c SHA256SUMS\n```\n"
                )

        project_bytes = sum(s for _, s, _ in copied)
        grand_total_files += len(copied)
        grand_total_bytes += project_bytes
        print(f"  files: {len(copied)}  bytes: {project_bytes:,}")

        index_rows.append(
            (
                project["label"],
                f"`{submodule}`" + ("" if is_submodule(submodule) else " *(independent clone)*"),
                commit,
                licence,
                str((Path(results) / "_evidence").as_posix()),
                len(copied),
                project["note"],
            )
        )

    if args.dry_run:
        print(f"\nDRY RUN: {grand_total_files} files would be copied.")
        return 1 if failures else 0

    # ------------------------------------------------------------------ index
    index = ROOT / "EVIDENCE_INDEX.md"
    with index.open("w", encoding="utf-8") as handle:
        handle.write("# EVIDENCE INDEX\n\n")
        handle.write(
            "Snapshot of the real packaging files behind each case study, copied next to the "
            "studies that cite them so that a reference such as "
            "`packaging/build-appimage.sh#L41-L49` can be resolved immediately.\n\n"
        )
        handle.write(
            "**Do not edit the extracted files.** They are read-only evidence pinned to the "
            "commits below. Regenerate the whole pack with:\n\n"
            "```bash\npython3 tools/extract_evidence.py\n```\n\n"
        )
        handle.write("## Projects\n\n")
        handle.write("| Project | Source tree | Commit | Licence | Evidence | Files | Purpose |\n|---|---|---|---|---|---|---|\n")
        for label, submodule, commit, licence, dest, count, note in index_rows:
            short = commit[:12] if commit != "(unknown)" else commit
            handle.write(f"| {label} | {submodule} | `{short}` | {licence} | `{dest}/` | {count} | {note} |\n")

        handle.write("\n## How to read an evidence pack\n\n")
        handle.write(
            "Each `<results>/_evidence/` directory mirrors the original repository layout and contains:\n\n"
            "```text\n_evidence/\n"
            "├── PROVENANCE.md   upstream URL, exact commit, licence, per-file rationale\n"
            "├── SHA256SUMS      integrity check for every extracted file\n"
            "└── <original/relative/paths...>\n```\n"
        )
        handle.write(
            "\nLine numbers quoted in the studies refer to the file at the pinned commit recorded "
            "in `PROVENANCE.md`, not to the current upstream `main`.\n"
        )

        handle.write("\n## Licence warning\n\n")
        handle.write(
            "The extracted files keep their upstream licence. **CARA, CustomKnight-Creator, dikte "
            "and TBO are GPL**; napari and pyzo are BSD; `napari/packaging` has **no licence file**. "
            "Studying and quoting is one thing; copying GPL packaging code into your own "
            "application is another. Check before reuse.\n"
        )

        handle.write("\n## Totals\n\n")
        handle.write(f"- Projects: {len(index_rows)}\n")
        handle.write(f"- Files: {grand_total_files}\n")
        handle.write(f"- Total size: {grand_total_bytes:,} bytes\n")
        handle.write(f"- Generated: {stamp}\n")

    print(f"\nWrote {index.relative_to(ROOT)}")
    print(f"Total: {grand_total_files} files, {grand_total_bytes:,} bytes across {len(index_rows)} projects.")

    if failures:
        print("\nPROBLEMS:", file=sys.stderr)
        for item in failures:
            print(f"  - {item}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
