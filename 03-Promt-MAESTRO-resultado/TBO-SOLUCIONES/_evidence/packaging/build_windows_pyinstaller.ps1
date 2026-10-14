#Requires -Version 5.1
<#
.SYNOPSIS
    Build the TBO Windows executable with PyInstaller, in onedir and onefile form.

.DESCRIPTION
    This is the PyInstaller counterpart of build_windows_nuitka.ps1, which
    remains the shipping Windows build. It exists for one reason: to produce
    comparable artifacts so that the two freezers can be evaluated on the same
    application - in particular by uploading each .exe to VirusTotal.

    The Windows build historically used Nuitka because a PyInstaller build of an
    earlier application produced antivirus false positives. That claim has never
    been measured on TBO. This script makes it measurable; it does not assume the
    outcome either way.

    Everything that could confound the comparison is held constant with the
    Nuitka build:

      * same application source, same __version__;
      * same PE identity metadata (company, product, description, versions);
      * same bundled data (doodle assets, package resources, translations);
      * UPX disabled (--noupx) in both - never a hidden variable.

    Two artifacts are produced, because bundle layout is a second variable worth
    separating from the freezer itself:

      onedir   - a directory containing the executable, no self-extraction at
                 launch;
      onefile  - a single self-extracting executable, the shape the case studies
                 flag as the classic false-positive profile.

.PARAMETER Mode
    onedir, onefile, or both (default).

.EXAMPLE
    ./packaging/build_windows_pyinstaller.ps1
    ./packaging/build_windows_pyinstaller.ps1 -Mode onefile

    # Same build, distinct artifact names, for comparing configurations:
    ./packaging/build_windows_pyinstaller.ps1 -Flavour pyinstaller-rebuilt

.NOTES
    Like the shipping script, --file-version / --product-version must be plain
    four-part numeric values. A version such as "2.0.0.dev0" makes the version
    resource invalid, which is the failure recorded for Nuitka in
    03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/SOLUCIONES-TBO.md section 4.

    This script does not build the bootloader; that happens when PyInstaller is
    *installed*. To produce the rebuilt-bootloader arm, install PyInstaller with
    PYINSTALLER_COMPILE_BOOTLOADER=1 from the sdist and then run this script with
    -Flavour pyinstaller-rebuilt. PyInstaller documents rebuilding the bootloader
    as a way to avoid antivirus false positives caused by the widely shared
    pre-compiled one:
    https://pyinstaller.org/en/stable/bootloader-building.html
#>
[CmdletBinding()]
param(
    [ValidateSet('onedir', 'onefile', 'both')]
    [string]$Mode = 'both',

    # Distinguishes artifacts when more than one PyInstaller configuration is
    # built, so the standard build and the rebuilt-bootloader build can be
    # scanned side by side without overwriting each other. The default
    # reproduces the original artifact names exactly.
    [string]$Flavour = 'pyinstaller'
)

$ErrorActionPreference = 'Stop'
Set-Item Env:PYTHONIOENCODING UTF-8

# For ZipFile / CreateFromDirectory, used instead of Compress-Archive so the
# produced archives use conformant forward-slash separators.
Add-Type -AssemblyName System.IO.Compression.FileSystem

$workspaceRoot = Split-Path -Parent "$PSScriptRoot"
$distDir = Join-Path $workspaceRoot "build\dist"
$tmpDir = Join-Path $workspaceRoot "build\tmp\pyinstaller"
$workDir = Join-Path $tmpDir "work"
$specDir = Join-Path $tmpDir "spec"
$outputDir = Join-Path $workspaceRoot "build\output"

# ---------------------------------------------------------------- version ----
$initFile = Join-Path $workspaceRoot "src\tbo\__init__.py"
$versionLine = Get-Content $initFile | Where-Object { $_ -match "__version__" } | Select-Object -First 1
if ($versionLine -match '"([^"]+)"') { $version = $Matches[1] } else { $version = "2.0.0" }

# Four-part numeric version for the PE resource. "2.0.0.dev0" -> "2.0.0" -> "2.0.0.0".
$numericVersion = if ($version -match '^(\d+(?:\.\d+)*)') { $Matches[1] } else { $version }
$windowsVersion = if (($numericVersion -split '\.').Count -ge 4) { $numericVersion } else { "$numericVersion.0" }

New-Item -ItemType Directory -Force -Path $distDir, $workDir, $specDir, $outputDir | Out-Null

Write-Host "=== TBO PyInstaller build ($Mode) ===" -ForegroundColor Cyan
Write-Host "version $version -> PE version $windowsVersion"

# ------------------------------------------------------------------- icon ----
python "$workspaceRoot\packaging\generate_icon.py" "$workspaceRoot\src\tbo\resources\icon.png" ico
$icoPath = Join-Path $workspaceRoot "src\tbo\resources\icon.ico"
if (-not (Test-Path $icoPath)) { throw "icon.ico was not generated at $icoPath" }

# ------------------------------------------- PE identity metadata (VS_VERSION) ---
# Kept identical to the Nuitka flags in build_windows_nuitka.ps1. If you change
# one, change the other, or the comparison stops being apples to apples.
$versionInfoPath = Join-Path $tmpDir "version_info.txt"
$versionInfo = @"
VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=($($windowsVersion -replace '\.', ', ')),
    prodvers=($($windowsVersion -replace '\.', ', ')),
    mask=0x3F, flags=0x0, OS=0x40004, fileType=0x1, subtype=0x0, date=(0, 0)
  ),
  kids=[
    StringFileInfo([
      StringTable("040904B0", [
        StringStruct("CompanyName", "TBO"),
        StringStruct("FileDescription", "TBO comic editor"),
        StringStruct("FileVersion", "$windowsVersion"),
        StringStruct("InternalName", "TBO"),
        StringStruct("LegalCopyright", "Copyright (c) 2026 Washington Indacochea Delgado"),
        StringStruct("OriginalFilename", "TBO.exe"),
        StringStruct("ProductName", "TBO"),
        StringStruct("ProductVersion", "$windowsVersion")
      ])
    ]),
    VarFileInfo([VarStruct("Translation", [0x0409, 1200])])
  ]
)
"@
# WriteAllText emits UTF-8 WITHOUT a byte-order mark. `Set-Content -Encoding UTF8`
# on Windows PowerShell 5.1 prepends a BOM, and PyInstaller then fails to parse
# the version resource instead of reporting a clear error.
[IO.File]::WriteAllText($versionInfoPath, $versionInfo)

# ---------------------------------------------------------------- helpers ----
# On Windows the --add-data separator is ";" (os.pathsep), not ":".
$sep = [IO.Path]::PathSeparator

function Build-TboPyInstaller {
    param([Parameter(Mandatory)][ValidateSet('onedir', 'onefile')][string]$Kind)

    $name = "tbo-$Flavour-$Kind"
    $layout = if ($Kind -eq 'onedir') { '--onedir' } else { '--onefile' }

    Write-Host "=== PyInstaller $Kind -> $name ===" -ForegroundColor Cyan

    $pyiArgs = @(
        '-m', 'PyInstaller'
        '--noconfirm', '--clean', '--log-level=INFO'
        '--name', $name
        $layout
        '--windowed'                      # no console window, like the Nuitka build
        '--noupx'                         # UPX is never a hidden variable
        '--icon', $icoPath
        '--version-file', $versionInfoPath

        '--hidden-import=PyQt6'
        '--hidden-import=PyQt6.QtCore'
        '--hidden-import=PyQt6.QtGui'
        '--hidden-import=PyQt6.QtWidgets'
        '--hidden-import=PyQt6.QtSvg'
        '--hidden-import=PyQt6.QtSvgWidgets'
        '--hidden-import=PyQt6.QtPrintSupport'

        # Destinations must match how the application resolves its own data at
        # runtime; see the comment block in build_appimage.sh. Getting these
        # wrong produces a bundle that builds "successfully" and ships without
        # its icons and translations.
        '--add-data', "$workspaceRoot\data\doodle${sep}data\doodle"
        '--add-data', "$workspaceRoot\src\tbo\resources${sep}tbo\resources"
        '--add-data', "$workspaceRoot\src\tbo\translations${sep}tbo\translations"

        '--distpath', $distDir
        '--workpath', (Join-Path $workDir $Kind)
        '--specpath', $specDir
        (Join-Path $workspaceRoot "src\tbo\__main__.py")
    )

    # The build log goes to the host, not to the success stream: anything a
    # native command writes to stdout would otherwise be captured into this
    # function's return value and end up inside the JSON manifest.
    & python @pyiArgs | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "PyInstaller ($Kind) failed with exit code $LASTEXITCODE" }

    # --------------------------------------------------------------- package --
    if ($Kind -eq 'onedir') {
        $appDir = Join-Path $distDir $name
        if (-not (Test-Path $appDir)) { throw "expected onedir output not found: $appDir" }

        # The .exe on its own cannot run; it needs the sibling _internal tree.
        # Both are zipped so the artifact is complete for a human, while the
        # bare .exe remains available for a VirusTotal submission.
        Copy-Item "$workspaceRoot\COPYING" $appDir -Force
        $zipPath = Join-Path $outputDir "TBO-$version-Windows-x64-$Flavour-onedir-portable.zip"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        # ZipFile, not Compress-Archive: see the packaging comment in
        # build_windows_nuitka.ps1. Compress-Archive writes backslash
        # separators, which break extraction everywhere except Windows.
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $appDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        # PyInstaller names the executable after --name, so the onedir payload
        # is <name>\<name>.exe, not <name>\tbo.exe.
        $exePath = Join-Path $appDir "$name.exe"
        if (-not (Test-Path $exePath)) { throw "expected onedir executable not found: $exePath" }
    }
    else {
        $exePath = Join-Path $distDir "$name.exe"
        if (-not (Test-Path $exePath)) { throw "expected onefile output not found: $exePath" }
        $zipPath = Join-Path $outputDir "TBO-$version-Windows-x64-$Flavour-onefile.zip"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        $archive = [System.IO.Compression.ZipFile]::Open(
            $zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $exePath, (Split-Path $exePath -Leaf)) | Out-Null
        } finally {
            $archive.Dispose()
        }
    }

    # ----------------------------------------------------------------- report --
    $exe = Get-Item $exePath
    $hash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLower()
    Write-Host ""
    Write-Host "  artifact : $zipPath"
    Write-Host "  exe      : $exePath"
    Write-Host ("  size     : {0:N0} bytes" -f $exe.Length)
    Write-Host "  sha256   : $hash"
    Write-Host "  -> upload the .exe above to VirusTotal" -ForegroundColor Yellow
    Write-Host ""

    # One machine-readable line per artifact, for the CI summary and for
    # comparing runs without retyping hashes by hand.
    [pscustomobject]@{
        kind   = $Kind
        exe    = $exePath
        zip    = $zipPath
        bytes  = $exe.Length
        sha256 = $hash
    }
}

$results = @()
switch ($Mode) {
    'onedir' { $results += Build-TboPyInstaller -Kind onedir }
    'onefile' { $results += Build-TboPyInstaller -Kind onefile }
    'both' {
        $results += Build-TboPyInstaller -Kind onedir
        $results += Build-TboPyInstaller -Kind onefile
    }
}

$manifestPath = Join-Path $outputDir "TBO-$version-$Flavour-windows.json"
[IO.File]::WriteAllText($manifestPath, ($results | ConvertTo-Json -Depth 4))

Write-Host "PyInstaller Windows build complete." -ForegroundColor Green
$results | Format-Table kind, bytes, sha256 -AutoSize
