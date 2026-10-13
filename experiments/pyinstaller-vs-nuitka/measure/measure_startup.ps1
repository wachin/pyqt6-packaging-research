#Requires -Version 5.1
<#
.SYNOPSIS
    Measure process-start -> first-window-visible for one built artifact.

.DESCRIPTION
    Runs the artifact N times, measuring from process creation to the moment the
    probe reports its window as visible. This is deliberately measured *outside*
    the process: interpreter start-up and the PyInstaller/Nuitka bootstrap happen
    before any Python code runs, so a value computed inside the app would hide
    exactly the difference we are trying to measure.

    Honest limitations, which belong in any published result:

      * This is NOT a true cold start. Truly clearing the OS file cache requires
        administrator tooling and is not attempted. Run 1 is the coldest
        available sample and is reported separately; runs 2..N are warm.
      * First-run cost also includes Windows Defender scanning the new binary,
        which is real end-user behaviour but is not the build tool's cost.
      * A single sample is noise. Report the median of >= 5 runs and repeat
        across several builds before drawing a conclusion.

.PARAMETER Exe
    Path to the built executable.

.PARAMETER Runs
    Number of runs. The default of 6 gives 1 coldest sample + 5 warm samples.

.PARAMETER TimeoutSeconds
    Give up waiting for the ready file after this long.

.PARAMETER OutFile
    Where to write the JSON result.

.EXAMPLE
    ./measure/measure_startup.ps1 -Exe dist/arm-b-onefile/PackagingProbe.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Exe,
    [int]$Runs = 6,
    [int]$TimeoutSeconds = 120,
    [string]$OutFile = 'startup.json'
)

$ErrorActionPreference = 'Stop'

$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("probe-{0}" -f ([guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $Tmp | Out-Null

Write-Host "Measuring $Exe ($Runs runs)" -ForegroundColor Cyan

$samples = @()
try {
    for ($i = 1; $i -le $Runs; $i++) {
        $ready = Join-Path $Tmp "ready-$i.json"
        if (Test-Path $ready) { Remove-Item $ready -Force }

        # Stop the environment interfering: the artifact must be self-contained.
        $env:QT_DEBUG_PLUGINS = $null
        $env:PYTHONPATH = $null
        $env:PYTHONHOME = $null

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $proc = Start-Process -FilePath $Exe `
            -ArgumentList @('--ready-file', $ready, '--exit-after-ms', '1500') `
            -PassThru

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while (-not (Test-Path $ready)) {
            if ((Get-Date) -gt $deadline) {
                $sw.Stop()
                try { $proc.Kill() } catch { }
                throw "run $i timed out after $TimeoutSeconds s without writing $ready"
            }
            if ($proc.HasExited -and -not (Test-Path $ready)) {
                throw "run $i exited with code $($proc.ExitCode) before signalling readiness"
            }
            Start-Sleep -Milliseconds 10
        }
        $sw.Stop()

        try { $proc.WaitForExit(15000) | Out-Null } catch { }
        if (-not $proc.HasExited) { try { $proc.Kill() } catch { } }

        $inner = Get-Content $ready -Raw | ConvertFrom-Json
        $samples += [pscustomobject]@{
            run                                    = $i
            seconds_process_start_to_window_visible = [math]::Round($sw.Elapsed.TotalSeconds, 3)
            inner_seconds_to_qt_import              = $inner.seconds_module_start_to_qt_import
            inner_seconds_to_window_visible         = $inner.seconds_module_start_to_window_visible
        }
        Write-Host ("  run {0}: {1:N3} s" -f $i, $sw.Elapsed.TotalSeconds)
    }
}
finally {
    Remove-Item $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$warm = $samples | Select-Object -Skip 1
$result = [pscustomobject]@{
    executable               = $Exe
    sha256                   = (Get-FileHash -LiteralPath $Exe -Algorithm SHA256).Hash.ToLower()
    size_bytes               = (Get-Item -LiteralPath $Exe).Length
    runs                     = $Runs
    coldest_sample_seconds   = $samples[0].seconds_process_start_to_window_visible
    warm_median_seconds      = if ($warm.Count -gt 0) {
        [math]::Round((($warm | Sort-Object seconds_process_start_to_window_visible)[[int][math]::Floor($warm.Count / 2)]).seconds_process_start_to_window_visible, 3)
    } else { $null }
    measured_utc             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    samples                  = $samples
}

$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8
Write-Host "Wrote $OutFile" -ForegroundColor Green
Write-Host ("coldest={0:N3}s  warm_median={1}s" -f $result.coldest_sample_seconds, $result.warm_median_seconds)
