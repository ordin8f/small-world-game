# Resolves the Godot 4.7 binary: $env:GODOT_BIN if set, else `godot4`/`godot` on PATH.
$ErrorActionPreference = "Stop"

if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) {
    & $env:GODOT_BIN @args
    exit $LASTEXITCODE
}

foreach ($candidate in @("godot4", "godot")) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        & $candidate @args
        exit $LASTEXITCODE
    }
}

Write-Error "godot.ps1: no Godot 4.7 binary found. Set `$env:GODOT_BIN` or add godot/godot4 to PATH."
exit 1
