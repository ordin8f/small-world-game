# Windowed screenshot capture for the four new Gate 1 mechanics (imagination
# transforms, pocket treasures, NPC talk, swing/sandbox) -- must NOT run
# under --headless, same reason as shots.ps1/verb_shots.ps1: headless never
# renders a frame to capture. Copies the resulting PNGs out of user:// into
# build/mechanics_shots/ so they land somewhere findable in the repo tree.
# Usage: tools/mechanics_shots.ps1
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    $godotArgs = @("--path", ".", "--script", "res://scripts/mechanics_shots.gd", "--resolution", "1280x720")

    & "$PSScriptRoot\godot.ps1" @godotArgs | Tee-Object -Variable outLines
    $status = $LASTEXITCODE

    $shotsLine = $outLines | Where-Object { $_ -match '^SHOTS_DIR: ' } | Select-Object -Last 1
    if (-not $shotsLine) {
        Write-Error "mechanics_shots.ps1: could not find a SHOTS_DIR line in mechanics_shots.gd's output -- nothing to copy."
        exit 1
    }
    $shotsSrc = $shotsLine -replace '^SHOTS_DIR: ', ''

    $dest = "build\mechanics_shots"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $pngs = Get-ChildItem -Path $shotsSrc -Filter "*.png" -ErrorAction SilentlyContinue
    if (-not $pngs) {
        Write-Error "mechanics_shots.ps1: no PNGs found in $shotsSrc to copy."
        exit 1
    }
    Copy-Item -Path $pngs.FullName -Destination $dest -Force

    Write-Host "mechanics_shots.ps1: copied shots to $(Resolve-Path $dest)"
    Get-ChildItem $dest

    if ($status -ne 0) {
        Write-Warning "mechanics_shots.ps1: mechanics_shots.gd exited $status -- see output above before trusting these frames."
    }
    exit $status
} finally {
    Pop-Location
}
