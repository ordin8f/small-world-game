# Windowed run of the Gate 0 verb screenshot capture (scripts/verb_shots.gd)
# -- must NOT run under --headless, same reason as shots.ps1: headless never
# renders a frame to capture. Copies the resulting PNGs out of user:// into
# build/verb_shots/ so they land somewhere findable in the repo tree.
# Usage: tools/verb_shots.ps1
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    $godotArgs = @("--path", ".", "--script", "res://scripts/verb_shots.gd", "--resolution", "1280x720")

    & "$PSScriptRoot\godot.ps1" @godotArgs | Tee-Object -Variable outLines
    $status = $LASTEXITCODE

    $shotsLine = $outLines | Where-Object { $_ -match '^SHOTS_DIR: ' } | Select-Object -Last 1
    if (-not $shotsLine) {
        Write-Error "verb_shots.ps1: could not find a SHOTS_DIR line in verb_shots.gd's output -- nothing to copy."
        exit 1
    }
    $shotsSrc = $shotsLine -replace '^SHOTS_DIR: ', ''

    $dest = "build\verb_shots"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $pngs = Get-ChildItem -Path $shotsSrc -Filter "*.png" -ErrorAction SilentlyContinue
    if (-not $pngs) {
        Write-Error "verb_shots.ps1: no PNGs found in $shotsSrc to copy."
        exit 1
    }
    Copy-Item -Path $pngs.FullName -Destination $dest -Force

    Write-Host "verb_shots.ps1: copied shots to $(Resolve-Path $dest)"
    Get-ChildItem $dest

    if ($status -ne 0) {
        Write-Warning "verb_shots.ps1: verb_shots.gd exited $status -- see output above before trusting these frames."
    }
    exit $status
} finally {
    Pop-Location
}
