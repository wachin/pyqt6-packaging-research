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
# Do NOT use Compress-Archive, and do not use ZipFile::CreateFromDirectory
# either. Both write BACKSLASH entry separators, and the ZIP specification
# (APPNOTE.TXT section 4.4.17.1) requires a forward slash. The consequence is
# that the tree collapses on extraction anywhere except Windows: on Linux or
# macOS, unzip treats "\" as an ordinary character in the filename, so the
# archive unpacks into 277 files literally named "TBO\python312.dll".
#
#   * Compress-Archive (Windows PowerShell 5.1) writes backslashes.
#   * ZipFile::CreateFromDirectory writes backslashes too, unless the *host*
#     application targets .NET Framework 4.6.1 or later. Windows PowerShell 5.1
#     targets an older framework, so it keeps the old behaviour. Microsoft
#     documents this at:
#     https://learn.microsoft.com/en-us/dotnet/framework/migration-guide/mitigation-ziparchiveentry-fullname-path-separator
#
# So the archive is built by packaging/make_portable_zip.py instead. CPython's
# zipfile normalises the separator in ZipInfo.__init__ ("ensure paths always use
# forward slashes ... as required by the ZIP format specification"), and that
# script builds the entry names from Path.parts and then re-reads the archive it
# wrote, failing if any entry still carries a backslash.
#
# The same script does the verification, deliberately: reading
# ZipArchiveEntry.FullName is subject to the very switch described above, so a
# PowerShell-side check could report a conformant archive as broken.
$stagingDir = Join-Path $outputDir "TBO-$version-Windows-x64-portable"
Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

Copy-Item $appDistDir $stagingDir -Recurse -Force
Copy-Item "$workspaceRoot\COPYING" $stagingDir -Force

$stagingRoot = (Get-Item $stagingDir).FullName
python "$workspaceRoot\packaging\make_portable_zip.py" $stagingRoot $portableZipPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "make_portable_zip.py failed with exit code $LASTEXITCODE; no archive was published."
}

Write-Output "Windows build complete: $portableZipPath"
