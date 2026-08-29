# The one command that must be green before any commit:
# import -> assets -> test -> export.
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    Write-Host "== import =="
    & "$PSScriptRoot\import.ps1"

    # Before the tests, because this failure mode is invisible to them: a model
    # whose external texture was never vendored still loads, still generates,
    # and still passes all 95 -- it just renders pure white. See
    # _check_asset_textures.gd's own doc comment for the round it shipped in.
    Write-Host "== assets =="
    & "$PSScriptRoot\godot.ps1" --headless --path . --script res://tools/_check_asset_textures.gd
    if ($LASTEXITCODE -ne 0) {
        Write-Error "verify.ps1: asset texture check failed -- see the unresolved references above."
        exit 1
    }

    Write-Host "== test =="
    & "$PSScriptRoot\test.ps1"
    Write-Host "== export =="
    & "$PSScriptRoot\export.ps1"
    Write-Host "verify.ps1: all green."
} finally {
    Pop-Location
}
