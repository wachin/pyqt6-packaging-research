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
Copy-Item "$workspaceRoot\COPYING" "$distDir\" -Force

$portableZipPath = Join-Path $outputDir "TBO-$version-Windows-x64-portable.zip"
if (Test-Path $portableZipPath) {
    Remove-Item $portableZipPath -Force
}
Compress-Archive -Path "$appDistDir", "$distDir\COPYING" -DestinationPath $portableZipPath

Write-Output "Windows build complete: $portableZipPath"
