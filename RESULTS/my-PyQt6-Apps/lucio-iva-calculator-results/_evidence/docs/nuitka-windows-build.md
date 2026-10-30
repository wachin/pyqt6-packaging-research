# Windows Nuitka Build

This document explains how the Windows build works in this repository.

Lucio IVA Calculator is a Python and PyQt6 desktop application. The official Windows package is built with Nuitka and then packaged in two forms:

- an NSIS installer;
- a portable ZIP.

The older PyInstaller-based Windows build is preserved only for reference in the `pyinstaller-old` branch.

## Why Nuitka Is Used

The first Windows builds used PyInstaller. They worked, but some antivirus engines reported heuristic false positives on VirusTotal. This is common with unsigned Python applications packaged as Windows executables, especially when the binary shape looks similar to many one-file or bundled Python applications.

Nuitka compiles Python modules through a C/C++ compiler and creates a different binary layout. In this project, the Nuitka build reduced the Windows false positives to clean VirusTotal results for the first tested Windows Nuitka release.

Nuitka does not replace code signing. A code signing certificate is still the strongest long-term solution for Windows SmartScreen and reputation, but Nuitka gave this project a cleaner unsigned build.

## Important Files

The Windows build is controlled by these files:

```text
.github/workflows/build.yml
build/build_windows.ps1
build/requirements-windows.txt
build/LucioIVACalculator.nsi
scripts/compile_translations.ps1
VERSION
assets/app-icon.ico
assets/nsis-welcome.bmp
assets/nsis-header.bmp
```

The output files are written to:

```text
build/output/
```

## Generated Artifacts

For version `0.1.1`, the Windows build produces:

```text
build/output/LucioIVACalculator-0.1.1-setup.exe
build/output/LucioIVACalculator-0.1.1-Windows-x64-portable.zip
```

The names are generated from the `VERSION` file.

In general:

```text
LucioIVACalculator-<version>-setup.exe
LucioIVACalculator-<version>-Windows-x64-portable.zip
```

## GitHub Actions Workflow

The official CI/CD workflow is:

```text
.github/workflows/build.yml
```

The Windows jobs run on:

```text
windows-2025
```

The workflow has two Windows stages:

1. `build_windows`
2. `test_windows`

The release job depends on the Windows, Linux, and macOS smoke tests.

## Windows Build Job

The `build_windows` job performs these steps:

1. Checks out the repository.
2. Reads the version from `VERSION`.
3. Installs Python 3.11 x64.
4. Installs NSIS with Chocolatey.
5. Installs Qt translation tools with `jurplel/install-qt-action`.
6. Installs Python dependencies from `build/requirements-windows.txt`.
7. Runs `build/build_windows.ps1`.
8. Uploads the installer and portable ZIP as the `lucio-iva-windows` artifact.

The Qt installation is important because translation files must be compiled with `lrelease.exe`.

## Windows Smoke Test Job

The `test_windows` job downloads the `lucio-iva-windows` artifact and verifies both packages:

1. Silent-installs the NSIS installer into a temporary directory.
2. Runs the installed application with `--smoke-test`.
3. Extracts the portable ZIP.
4. Runs the portable executable with `--smoke-test`.

This confirms that both Windows distribution formats start correctly in GitHub Actions.

## Build Script Overview

The main Windows script is:

```text
build/build_windows.ps1
```

It performs these tasks:

1. Sets strict PowerShell error handling.
2. Resolves repository paths.
3. Reads the application version from `VERSION`.
4. Cleans previous Windows build directories.
5. Compiles Qt translation files.
6. Runs Nuitka.
7. Copies the Nuitka output into `build/dist/LucioIVACalculator`.
8. Copies license and installer assets.
9. Creates the portable ZIP.
10. Generates a versioned NSIS script.
11. Runs NSIS to create the installer.
12. Moves the installer into `build/output`.

## Directory Layout During Build

The script uses these directories:

```text
build/tmp/nuitka/
build/dist/
build/output/
```

Their roles are:

```text
build/tmp/nuitka/
```

Temporary Nuitka output.

```text
build/dist/LucioIVACalculator/
```

The final application folder copied from Nuitka output. This folder is used for both the installer and the portable ZIP.

```text
build/output/
```

Final publishable files.

## Translation Compilation

Before running Nuitka, the script calls:

```powershell
scripts/compile_translations.ps1
```

This compiles Qt `.ts` translation files into `.qm` files.

The generated translation files are included in the packaged application through Nuitka's data directory support:

```powershell
--include-data-dir="$workspaceRoot\translations=translations"
```

If translations are not compiled before packaging, the application may start but some languages will not be available.

## Nuitka Command

The build script runs Nuitka with:

```powershell
python -m nuitka
```

The important options are:

```text
--standalone
--enable-plugin=pyqt6
--windows-console-mode=disable
--windows-icon-from-ico=assets/app-icon.ico
--msvc=latest
```

### `--standalone`

Creates a distributable application folder with the executable and its required runtime files.

### `--enable-plugin=pyqt6`

Enables Nuitka support for PyQt6, so Qt dependencies are discovered and packaged correctly.

### `--windows-console-mode=disable`

Builds the application as a GUI program without a console window.

### `--windows-icon-from-ico`

Embeds the Windows icon into the executable.

### `--msvc=latest`

Requests the latest available Microsoft Visual C++ compiler on the runner.

## Windows Version Metadata

The script also passes product metadata to Nuitka:

```powershell
--company-name="Lucio"
--product-name="Lucio IVA Calculator"
--file-description="Lucio IVA Calculator"
--file-version="$windowsVersion"
--product-version="$windowsVersion"
--copyright="Copyright (c) 2026 Washington Indacochea Delgado and Joseph Lucio Guerrero"
```

This metadata appears in the Windows file properties dialog.

It is useful because:

- the executable looks more professional;
- users can identify the program from Windows Explorer;
- antivirus engines receive more normal product metadata;
- it avoids anonymous-looking binaries.

## Included Data Directories

The application needs more than Python code. The build includes:

```powershell
--include-data-dir="$workspaceRoot\assets=assets"
--include-data-dir="$workspaceRoot\translations=translations"
--include-data-dir="$workspaceRoot\docs=docs"
```

These directories are needed for:

- the application icon and visual assets;
- translation files;
- offline help files;
- about dialog images;
- documentation shown by the app.

If the application starts but icons, help, photos, or translations are missing, check these include options first.

## Portable ZIP

After Nuitka finishes, the script copies the generated `.dist` folder to:

```text
build/dist/LucioIVACalculator/
```

Then it creates:

```text
build/output/LucioIVACalculator-<version>-Windows-x64-portable.zip
```

The portable package contains:

```text
LucioIVACalculator/
LICENSE
```

Users can extract the ZIP and run:

```text
LucioIVACalculator/LucioIVACalculator.exe
```

The portable ZIP does not write installer registry keys and does not create shortcuts.

## NSIS Installer

The installer template is:

```text
build/LucioIVACalculator.nsi
```

The PowerShell build script reads this file and patches version-specific values before running NSIS:

```powershell
!define VERSION
!define INSTALLER_NAME
DisplayVersion
```

The patched `.nsi` file is written into:

```text
build/dist/LucioIVACalculator.nsi
```

Then NSIS creates the final installer.

The installer uses:

```text
assets/nsis-welcome.bmp
assets/nsis-header.bmp
assets/app-icon.ico
```

These resources give the installer its custom welcome image, header image, and icon.

## Silent Install Mode

The GitHub Actions smoke test installs the program silently:

```powershell
LucioIVACalculator-<version>-setup.exe /S /D=<install-dir>
```

This is important because GitHub Actions cannot manually click through installer windows.

The test then runs:

```powershell
LucioIVACalculator.exe --smoke-test
```

The `--smoke-test` argument lets the application start enough to verify packaging without opening a normal user session.

## Dependencies

Windows-specific Python build dependencies live in:

```text
build/requirements-windows.txt
```

Current dependencies:

```text
PyQt6>=6.7
nuitka>=2.6
ordered-set>=4.1.0
zstandard>=0.23.0
```

### PyQt6

The GUI framework used by the application.

### Nuitka

The compiler and packager used for the Windows executable.

### ordered-set

Recommended by Nuitka for faster and cleaner compilation.

### zstandard

Used by Nuitka for dependency/cache handling and compression support.

NSIS and Qt tools are installed separately in GitHub Actions because they are system tools, not Python packages.

## Local Windows Build

To build locally on Windows, install:

- Python 3.11 or newer;
- Visual Studio Build Tools with MSVC;
- NSIS;
- Qt tools, especially `lrelease.exe`;
- Python dependencies from `build/requirements-windows.txt`.

Then run:

```powershell
pip install -r build\requirements-windows.txt
.\build\build_windows.ps1
```

Expected output:

```text
build/output/LucioIVACalculator-<version>-setup.exe
build/output/LucioIVACalculator-<version>-Windows-x64-portable.zip
```

## Local Smoke Test

After building locally, test the portable executable:

```powershell
Expand-Archive build\output\LucioIVACalculator-<version>-Windows-x64-portable.zip -DestinationPath build\portable-test
.\build\portable-test\LucioIVACalculator\LucioIVACalculator.exe --smoke-test
```

To test the installer silently:

```powershell
$installDir = "$PWD\build\installed-test"
.\build\output\LucioIVACalculator-<version>-setup.exe /S /D=$installDir
.\build\installed-test\LucioIVACalculator\LucioIVACalculator.exe --smoke-test
```

Replace `<version>` with the current value from `VERSION`.

## Release Flow

When a tag starting with `v` is pushed, the release job:

1. Downloads the Windows, Linux, and macOS artifacts.
2. Generates `SHA256SUMS.txt`.
3. Creates a GitHub Release.
4. Uploads:
   - Windows installer;
   - Windows portable ZIP;
   - Linux archive;
   - macOS ZIP;
   - SHA256 checksums.

Example tag:

```bash
git tag v0.1.2
git push origin v0.1.2
```

## VirusTotal Notes

For version `0.1.1`, the first tested Windows Nuitka build produced clean VirusTotal results:

```text
installer:    0/68
portable ZIP: 0/65
```

The tested files were:

```text
LucioIVACalculator-0.1.1-nuitka-setup.exe
LucioIVACalculator-0.1.1-Windows-x64-nuitka-portable.zip
```

The official `main` branch later adopted the same Nuitka approach while keeping the normal public artifact names:

```text
LucioIVACalculator-<version>-setup.exe
LucioIVACalculator-<version>-Windows-x64-portable.zip
```

## Common Problems

### `lrelease.exe` Not Found

Qt translation compilation requires `lrelease.exe`.

On GitHub Actions this is provided by:

```yaml
jurplel/install-qt-action@v4
```

Locally, install Qt with Qt Creator or the Qt online installer and make sure the Qt `bin` directory is available in `PATH`.

### Missing Icons, Help, or Translations

Check that these Nuitka options still exist:

```powershell
--include-data-dir="$workspaceRoot\assets=assets"
--include-data-dir="$workspaceRoot\translations=translations"
--include-data-dir="$workspaceRoot\docs=docs"
```

### Installer Builds but Portable ZIP Fails

The portable ZIP is created from:

```text
build/dist/LucioIVACalculator/
```

Check that Nuitka generated `LucioIVACalculator.exe` and that the script copied the `.dist` folder correctly.

### Installer Does Not Build

Check that NSIS exists at:

```text
C:\Program Files (x86)\NSIS\makensis.exe
```

If NSIS is missing, the script creates only the portable ZIP and prints a warning.

### Antivirus False Positives

False positives can still happen with unsigned Windows executables.

Helpful practices used in this project:

- no UPX compression;
- complete Windows product metadata;
- visible application icon;
- clean installer behavior;
- reproducible GitHub Actions builds;
- portable ZIP in addition to installer;
- SHA256 checksums for releases;
- public source code.

Code signing is still recommended for long-term public distribution.

## When Editing the Build

If you change the Windows build, verify:

1. `python -m unittest discover -s tests`
2. `build/build_windows.ps1`
3. installer smoke test
4. portable ZIP smoke test
5. GitHub Actions Windows job
6. GitHub Actions release artifact names
7. `SHA256SUMS.txt` generation

Be careful with artifact names. The release workflow expects the exact names generated by `build/build_windows.ps1`.
