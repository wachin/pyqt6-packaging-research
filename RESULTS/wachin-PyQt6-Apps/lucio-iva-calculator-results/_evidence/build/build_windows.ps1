$ErrorActionPreference = "Stop"
Set-Item Env:PYTHONIOENCODING UTF-8

$workspaceRoot = Split-Path -Parent "$PSScriptRoot"
$distDir = Join-Path $workspaceRoot "build\dist"
$tmpDir = Join-Path $workspaceRoot "build\tmp\nuitka"
$outputDir = Join-Path $workspaceRoot "build\output"
$nuitkaOutputDir = Join-Path $tmpDir "output"
$appDistDir = Join-Path $distDir "LucioIVACalculator"
$version = Get-Content "$workspaceRoot\VERSION" -Raw
$version = $version.Trim()
$windowsVersion = "$version.0"

New-Item -ItemType Directory -Force -Path $distDir, $tmpDir, $outputDir, $nuitkaOutputDir | Out-Null
Remove-Item "$distDir\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$nuitkaOutputDir\*" -Recurse -Force -ErrorAction SilentlyContinue

& powershell -NoProfile -ExecutionPolicy Bypass -File "$workspaceRoot\scripts\compile_translations.ps1"

& python -m nuitka `
  --standalone `
  --assume-yes-for-downloads `
  --remove-output `
  --msvc=latest `
  --enable-plugin=pyqt6 `
  --windows-console-mode=disable `
  --windows-icon-from-ico="$workspaceRoot\assets\app-icon.ico" `
  --company-name="Lucio" `
  --product-name="Lucio IVA Calculator" `
  --file-description="Lucio IVA Calculator" `
  --file-version="$windowsVersion" `
  --product-version="$windowsVersion" `
  --copyright="Copyright (c) 2026 Washington Indacochea Delgado and Joseph Lucio Guerrero" `
  --include-data-dir="$workspaceRoot\assets=assets" `
  --include-data-dir="$workspaceRoot\translations=translations" `
  --include-data-dir="$workspaceRoot\docs=docs" `
  --output-filename="LucioIVACalculator.exe" `
  --output-dir="$nuitkaOutputDir" `
  "$workspaceRoot\main.py"

$builtExe = Get-ChildItem -Path $nuitkaOutputDir -Recurse -Filter "LucioIVACalculator.exe" |
    Where-Object { $_.FullName -like "*.dist\LucioIVACalculator.exe" } |
    Select-Object -First 1

if (-not $builtExe) {
    Write-Error "Nuitka output executable was not found."
}

Copy-Item $builtExe.Directory.FullName $appDistDir -Recurse -Force
Copy-Item "$workspaceRoot\LICENSE" "$distDir\" -Force
Copy-Item "$workspaceRoot\assets\app-icon.ico" "$distDir\" -Force
Copy-Item "$workspaceRoot\assets\nsis-welcome.bmp" "$distDir\" -Force
Copy-Item "$workspaceRoot\assets\nsis-header.bmp" "$distDir\" -Force

$portableZipPath = Join-Path $outputDir "LucioIVACalculator-$version-Windows-x64-portable.zip"
if (Test-Path $portableZipPath) {
    Remove-Item $portableZipPath -Force
}
Compress-Archive -Path "$distDir\LucioIVACalculator", "$distDir\LICENSE" -DestinationPath $portableZipPath

$nsiContent = Get-Content "$workspaceRoot\build\LucioIVACalculator.nsi" -Raw
$nsiContent = $nsiContent.Replace('!define VERSION "0.1.0.0"', "!define VERSION `"$windowsVersion`"")
$nsiContent = $nsiContent.Replace('!define INSTALLER_NAME "LucioIVACalculator-0.1.0-setup.exe"', "!define INSTALLER_NAME `"LucioIVACalculator-$version-setup.exe`"")
$nsiContent = $nsiContent.Replace('WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayVersion" "0.1.0"', "WriteRegStr HKCU `"Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APP_NAME}`" `"DisplayVersion`" `"$version`"")
Set-Content -Path "$distDir\LucioIVACalculator.nsi" -Value $nsiContent -Encoding UTF8

$makensis = "C:\Program Files (x86)\NSIS\makensis.exe"
if (Test-Path $makensis) {
    Push-Location $distDir
    & $makensis "$distDir\LucioIVACalculator.nsi"
    Move-Item "LucioIVACalculator-*-setup.exe" "$outputDir" -Force
    Pop-Location
} else {
    Write-Warning "NSIS was not found. Portable ZIP was created, but the installer was not built."
}
