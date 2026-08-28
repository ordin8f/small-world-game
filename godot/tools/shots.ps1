# Windowed run of the six-beat screenshot route (scripts/screenshot_route.gd)
# -- must NOT run under --headless, see that script's own doc comment for
# why (headless never renders a frame to capture). Copies the resulting
# PNGs out of user:// into build/shots/ so they land somewhere findable in
# the repo tree (build/ itself is gitignored, same as export.ps1's
# build/web/ -- this just gives every run a stable, known local path).
# Usage: tools/shots.ps1 [-Ui]   (-Ui keeps the HUD/dialogue on screen;
# default hides it for clean world frames)
param(
    [switch]$Ui
)
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    $godotArgs = @("--path", ".", "--script", "res://scripts/screenshot_route.gd", "--resolution", "1280x720")
    if ($Ui) {
        $godotArgs += @("--", "--ui")
    }

    # Tee-Object rather than a plain capture so the run's own progress
    # (one line per beat) still streams to the console live, not just
    # dumped after the fact -- $LASTEXITCODE still reflects godot.ps1's
    # own `exit $LASTEXITCODE` since Tee-Object never runs a native
    # command or exits itself.
    & "$PSScriptRoot\godot.ps1" @godotArgs | Tee-Object -Variable outLines
    $status = $LASTEXITCODE

    # screenshot_route.gd prints "SHOTS_DIR: <globalized user:// path>" as
    # its last line on both success and failure -- parsed out here rather
    # than hardcoding user://'s real OS path, which differs by platform
    # and depends on project.godot's application/config/name.
    $shotsLine = $outLines | Where-Object { $_ -match '^SHOTS_DIR: ' } | Select-Object -Last 1
    if (-not $shotsLine) {
        Write-Error "shots.ps1: could not find a SHOTS_DIR line in screenshot_route.gd's output -- nothing to copy."
        exit 1
    }
    $shotsSrc = $shotsLine -replace '^SHOTS_DIR: ', ''

    $dest = "build\shots"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem -Path $dest -File -ErrorAction SilentlyContinue | Remove-Item -Force

    $pngs = Get-ChildItem -Path $shotsSrc -Filter "*.png" -ErrorAction SilentlyContinue
    if (-not $pngs) {
        Write-Error "shots.ps1: no PNGs found in $shotsSrc to copy."
        exit 1
    }
    Copy-Item -Path $pngs.FullName -Destination $dest -Force

    Write-Host "shots.ps1: copied shots to $(Resolve-Path $dest)"
    Get-ChildItem $dest

    if ($status -ne 0) {
        Write-Error "shots.ps1: screenshot_route.gd exited $status -- see output above before trusting these frames."
        exit $status
    }
    exit $status
} finally {
    Pop-Location
}
