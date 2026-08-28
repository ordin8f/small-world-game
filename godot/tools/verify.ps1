# The one command that must be green before any commit: import -> test -> export.
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    Write-Host "== import =="
    & "$PSScriptRoot\import.ps1"
    Write-Host "== test =="
    & "$PSScriptRoot\test.ps1"
    Write-Host "== export =="
    & "$PSScriptRoot\export.ps1"
    Write-Host "verify.ps1: all green."
} finally {
    Pop-Location
}
