# Windowed run of the Gate 0 frame's five screen shots
# (scripts/frame_shots_route.gd) -- must NOT run under --headless, see
# that script's own doc comment for why. Copies the resulting PNGs out of
# user:// into build/frame_shots/ so they land somewhere findable in the
# repo tree (build/ itself is gitignored, same as shots.ps1's own
# build/shots/).
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    $godotArgs = @("--path", ".", "--script", "res://scripts/frame_shots_route.gd", "--resolution", "1280x720")

    & "$PSScriptRoot\godot.ps1" @godotArgs | Tee-Object -Variable outLines
    $status = $LASTEXITCODE

    $shotsLine = $outLines | Where-Object { $_ -match '^SHOTS_DIR: ' } | Select-Object -Last 1
    if (-not $shotsLine) {
        Write-Error "frame_shots.ps1: could not find a SHOTS_DIR line in frame_shots_route.gd's output -- nothing to copy."
        exit 1
    }
    $shotsSrc = $shotsLine -replace '^SHOTS_DIR: ', ''

    $dest = "build\frame_shots"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $pngs = Get-ChildItem -Path $shotsSrc -Filter "*.png" -ErrorAction SilentlyContinue
    if (-not $pngs) {
        Write-Error "frame_shots.ps1: no PNGs found in $shotsSrc to copy."
        exit 1
    }
    Copy-Item -Path $pngs.FullName -Destination $dest -Force

    Write-Host "frame_shots.ps1: copied shots to $(Resolve-Path $dest)"
    Get-ChildItem $dest

    if ($status -ne 0) {
        Write-Warning "frame_shots.ps1: frame_shots_route.gd exited $status -- see output above before trusting these frames."
    }
    exit $status
} finally {
    Pop-Location
}
