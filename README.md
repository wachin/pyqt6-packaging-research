# PyQt6 Packaging Research

Research repository for studying how real-world Python/Qt desktop applications are packaged and distributed on **Windows, Linux, and macOS**.

The goal is not to develop a new application in this repository. Instead, it collects selected open-source projects as **Git submodules** so their build, packaging, release, signing, and CI/CD infrastructure can be studied side by side.

## Goals

The main objective is to create a practical, evidence-based guide for packaging my own **PyQt6 desktop applications**.

The research focuses on:

### Windows

- PyInstaller
- Nuitka
- `onefile` vs `onedir` / standalone builds
- Windows executables
- Portable distributions
- Installers
- Inno Setup, NSIS, MSI/MSIX, or other installer systems
- Application metadata and manifests
- Code signing / Authenticode
- SmartScreen reputation
- VirusTotal and antivirus false positives
- Legitimate techniques for reducing false-positive detections
- Release checksums and provenance

A particularly important research question is whether PyInstaller can be configured and used in ways that reduce antivirus false positives. I have previously experienced false positives with PyInstaller-built executables while having better results with Nuitka, so both approaches are studied rather than assuming one is universally better.

There is **no assumption that zero VirusTotal detections can be guaranteed**. The goal is to identify legitimate professional distribution practices, not antivirus evasion techniques.

### Linux

The research focuses on two different distribution formats:

#### AppImage

- Standalone application bundling
- AppDir structure
- AppRun
- `.desktop` integration
- Icons
- Qt plugins
- PyQt6 libraries
- Python runtime
- AppImage creation tools
- GLIBC compatibility
- Portability between Linux distributions

#### Debian packages

- `.deb` package structure
- Debian metadata
- Dependency management
- System Python/PyQt6 vs bundled runtimes
- Installation paths
- Desktop integration
- Icons and application metadata
- Package validation and testing

### macOS

- `.app` bundles
- PyInstaller and Nuitka on macOS
- `Info.plist`
- `.icns` icons
- Qt frameworks and plugins
- Python runtime
- Code signing
- Hardened Runtime
- Apple notarization
- Stapling
- `.dmg` creation
- GitHub Actions macOS runners

### Automation

Another major objective is to understand how mature projects automate releases with **GitHub Actions**, ideally reaching a workflow conceptually similar to:

```text
                         Git tag
                            |
                +-----------+-----------+
                |           |           |
             Windows      Linux       macOS
                |           |           |
             Build       AppImage      Build
                |           |           |
             Sign          DEB          Sign
                |                       |
            Installer                 Notarize
                |                       |
                +-----------+-----------+
                            |
                     GitHub Release
```

## Projects under study

The following upstream projects are included as Git submodules:

| Submodule | Purpose in this research |
| --- | --- |
| `dikte` | Study a relatively small PyQt6 application with multiplatform distribution. |
| `CustomKnight-Creator` | Study a smaller project and its executable/packaging approach. |
| `pyzo` | Study packaging practices from a mature Python/Qt desktop application. |
| `CARA` | Study another real-world PyQt6 desktop application and its multiplatform builds. |
| `napari` | Study a large, mature scientific Python/Qt application and its release architecture. |
| `napari-packaging` | Study napari's dedicated packaging and installer infrastructure. |

The projects remain independent upstream repositories. This repository records specific commits of those projects through Git submodules.

## Repository structure

```text
pyqt6-packaging-research/
├── CARA/
├── CustomKnight-Creator/
├── dikte/
├── napari/
├── napari-packaging/
├── pyzo/
├── .gitmodules
└── README.md
```

Additional research documents may be added as the investigation progresses.

## Why Git submodules?

Git submodules make it possible to:

- preserve the original upstream repositories;
- keep their Git history separate;
- record the exact upstream commit used during an investigation;
- update individual projects independently;
- avoid copying third-party source code directly into this repository;
- compare packaging implementations from several projects in one workspace.

## Clone this repository

Because the projects are submodules, the recommended way to clone this repository is:

```bash
git clone --recurse-submodules https://github.com/wachin/pyqt6-packaging-research.git
cd pyqt6-packaging-research
```

If the repository was cloned without its submodules:

```bash
git submodule update --init --recursive
```

Check their current state with:

```bash
git submodule status
```

## Update the submodules

To fetch newer upstream commits:

```bash
git submodule update --remote
```

Then inspect the changes:

```bash
git status
git diff --submodule
```

If the updates are intentional, record the new submodule commits in this repository:

```bash
git add .
git commit -m "Update research submodules"
git push
```

Updating a submodule can change the code being studied, so research results should ideally record the exact commit or version analyzed.

## Research methodology

Each project should be analyzed independently using the same investigation criteria.

The analysis should inspect, when available:

```text
README.md
CONTRIBUTING.md
pyproject.toml
setup.py
setup.cfg
requirements*.txt

.github/workflows/

*.spec

scripts/
build/
packaging/
installer/

Debian packaging files
AppImage configuration
Windows installer configuration
macOS packaging scripts
```

Important technologies and terms to search for include:

```text
PyQt6
PySide6
QtPy

PyInstaller
Nuitka
cx_Freeze
py2app

AppImage
AppDir
appimagetool
linuxdeploy

dpkg
debhelper

Inno Setup
NSIS
WiX
MSI
MSIX

codesign
signtool
Authenticode
notarytool
notarization

GitHub Actions
GitHub Releases
```

The investigation should trace the complete path from source code to the final downloadable artifact rather than merely identifying which packaging tool is installed.

## Expected research documents

For each case study, the research can produce documents such as:

```text
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md
```

### `PACKAGING_STUDY.md`

This document should describe what the specific upstream project actually does.

It should distinguish between:

- verified implementation;
- project-specific techniques;
- legacy infrastructure;
- reusable ideas;
- assumptions;
- things that could not be verified.

Important conclusions should reference the actual source files, build scripts, configuration, and GitHub Actions workflows that support them.

### `PYQT6_PACKAGING_TUTORIAL.md`

This document should transform useful findings from the project into practical lessons for packaging other PyQt6 applications.

It should cover, where evidence is available:

```text
Windows
├── PyInstaller
├── Nuitka
├── portable builds
├── installers
├── code signing
└── antivirus / VirusTotal considerations

Linux
├── AppImage
└── DEB

macOS
├── .app
├── signing
├── notarization
└── DMG

Automation
└── GitHub Actions
```

## Final objective

After all projects have been studied, their findings can be compared to produce a consolidated guide, for example:

```text
MASTER_PYQT6_PACKAGING_GUIDE.md
```

The final guide should not simply copy one project's build system.

Instead, it should compare multiple real-world implementations and identify practices that are:

- highly recommended;
- useful;
- project-specific;
- legacy;
- not recommended;
- or in need of further research.

The desired end result is a reusable packaging strategy for open-source PyQt6 desktop applications:

```text
                         PyQt6 project
                               |
             +-----------------+-----------------+
             |                 |                 |
          Windows            Linux             macOS
             |                 |                 |
     PyInstaller/Nuitka   standalone build  PyInstaller/Nuitka
             |                 |                 |
        executable       +-----+-----+          .app
             |           |           |            |
          signing     AppImage      DEB        signing
             |                                  |
         installer                            notarization
             |                                  |
     installer signing                          DMG
             |                 |                 |
             +-----------------+-----------------+
                               |
                         GitHub Actions
                               |
                         GitHub Release
```

## Research principles

This repository is intended for legitimate open-source software packaging research.

The investigation should:

- prefer primary sources and actual repository evidence;
- distinguish verified facts from assumptions;
- avoid blindly copying project-specific build systems;
- compare PyInstaller and Nuitka objectively;
- treat antivirus false positives as a software distribution and reputation problem, not as something to bypass through evasion;
- never expose credentials, signing certificates, private keys, or CI secrets;
- document secret variable names only when necessary to understand a workflow;
- prefer reproducible and transparent release processes;
- consider code signing, checksums, provenance, and public source code as part of professional software distribution.

## License and third-party projects

The source code contained in each submodule belongs to its respective upstream project and remains subject to that project's own license.

This repository does not relicense the submodules.

Before reusing code, scripts, configuration, icons, or other assets from an upstream project, check its license and attribution requirements.

## Status

**Work in progress.**

The repository currently establishes the collection of reference projects. Detailed packaging studies and the consolidated PyQt6 packaging guide will be added as the research progresses.
