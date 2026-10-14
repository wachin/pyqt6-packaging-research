# Build a standalone Windows .exe with Nuitka.
# Mirrors the proven configuration of lucio-iva-calculator (clean VirusTotal).
$ErrorActionPreference = "Stop"
Set-Item Env:PYTHONIOENCODING UTF-8

$workspaceRoot = Split-Path -Parent "$PSScriptRoot"
$distDir = Join-Path $workspaceRoot "build\dist"
$tmpDir = Join-Path $workspaceRoot "build\tmp\nuitka"
$outputDir = Join-Path $workspaceRoot "build\output"
$appDistDir = Join-Path $distDir "TBO"

$initFile = Join-Path $workspaceRoot "src\tbo\__init__.py"
$versionLine = Get-Content $initFile | Where-Object { $_ -match "__version__" } | Select-Object -First 1
if ($versionLine -match '"([^"]+)"') {
    $version = $Matches[1]
} else {
    $version = "2.0.0"
}
# Nuitka requires a 4-part numeric version (major.minor.build.revision) for
# --file-version / --product-version.  Strip any non-numeric suffix (e.g.
# "2.0.0.dev0" -> "2.0.0") and append ".0" -> "2.0.0.0".
$numericVersion = if ($version -match '^(\d+(?:\.\d+)*)') { $Matches[1] } else { $version }
$windowsVersion = "$numericVersion.0"

New-Item -ItemType Directory -Force -Path $distDir, $tmpDir, $outputDir | Out-Null
Remove-Item "$distDir\*" -Recurse -Force -ErrorAction SilentlyContinue

# Generate the .ico from the SVG application icon
python "$workspaceRoot\packaging\generate_icon.py" "$workspaceRoot\src\tbo\resources\icon.png" ico

# Make the src layout importable by Nuitka
$env:PYTHONPATH = "$workspaceRoot\src"

& python -m nuitka `
  --standalone `
  --assume-yes-for-downloads `
  --remove-output `
  --verbose `
  --msvc=latest `
  --enable-plugin=pyqt6 `
  --follow-import-to=tbo `
  --windows-console-mode=disable `
  --windows-icon-from-ico="$workspaceRoot\src\tbo\resources\icon.ico" `
  --company-name="TBO" `
  --product-name="TBO" `
  --file-description="TBO comic editor" `
  --file-version="$windowsVersion" `
  --product-version="$windowsVersion" `
  --copyright="Copyright (c) 2026 Washington Indacochea Delgado" `
  --include-package=tbo `
  --include-package-data=tbo `
  --include-data-dir="$workspaceRoot\data\doodle=tbo\data\doodle" `
  --include-data-dir="$workspaceRoot\translations=tbo\translations" `
  --output-filename="TBO.exe" `
  --output-dir="$tmpDir" `
  "$workspaceRoot\src\tbo\__main__.py"

$builtExe = Get-ChildItem -Path $tmpDir -Recurse -Filter "TBO.exe" |
    Where-Object { $_.FullName -like "*.dist\TBO.exe" } |
    Select-Object -First 1

if (-not $builtExe) {
    Write-Error "Nuitka output executable was not found."
}

Copy-Item $builtExe.Directory.FullName $appDistDir -Recurse -Force

$portableZipPath = Join-Path $outputDir "TBO-$version-Windows-x64-portable.zip"
if (Test-Path $portableZipPath) {
    Remove-Item $portableZipPath -Force
}

# ---------------------------------------------------------------- packaging ---
# Do NOT use Compress-Archive here.
#
# Windows PowerShell 5.1's Compress-Archive writes the entry separator as a
# BACKSLASH. The ZIP specification (APPNOTE.TXT) requires a forward slash, and
# archives that break this rule extract wrongly everywhere except Windows: on
# Linux or macOS, `unzip` treats "\" as an ordinary character in the filename,
# so the whole tree collapses into one directory of files literally named
# "TBO\python312.dll". The previous build produced exactly that: a zip with 277
# of 278 entries using backslashes.
#
# [System.IO.Compression.ZipFile] writes conformant forward slashes, and the
# check afterwards fails the build rather than shipping another broken archive.
$stagingDir = Join-Path $outputDir "TBO-$version-Windows-x64-portable"
Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

Copy-Item $appDistDir $stagingDir -Recurse -Force
Copy-Item "$workspaceRoot\COPYING" $stagingDir -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stagingDir,
    $portableZipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false)   # $false = do not nest everything under an extra base directory

# ------------------------------------------------------------------- verify ---
$archive = [System.IO.Compression.ZipFile]::OpenRead($portableZipPath)
try {
    $malformed = @($archive.Entries | Where-Object { $_.FullName.Contains('\') })
    $entries = $archive.Entries.Count
} finally {
    $archive.Dispose()
}

if ($malformed.Count -gt 0) {
    Write-Error ("The archive is not ZIP-conformant: {0} of {1} entries use a backslash separator. " +
                 "Everything except Windows will extract it incorrectly." -f $malformed.Count, $entries)
}

$hasExe = $false
$archive = [System.IO.Compression.ZipFile]::OpenRead($portableZipPath)
try {
    $hasExe = @($archive.Entries | Where-Object { $_.FullName -eq 'TBO/TBO.exe' }).Count -gt 0
} finally {
    $archive.Dispose()
}
if (-not $hasExe) {
    Write-Error "The archive does not contain TBO/TBO.exe at the expected path."
}

Write-Output "Windows build complete: $portableZipPath"
Write-Output ("  {0} entries, all with forward-slash separators; TBO/TBO.exe present" -f $entries)
