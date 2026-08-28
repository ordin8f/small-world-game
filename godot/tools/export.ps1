# Headless web export. Output lands in godot/build/web/.
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    New-Item -ItemType Directory -Force -Path "build\web" | Out-Null
    & "$PSScriptRoot\godot.ps1" --headless --path . --export-release "Web" "build/web/index.html"
    if ($LASTEXITCODE -ne 0) { throw "export failed ($LASTEXITCODE)" }

    foreach ($f in @("index.html", "index.js", "index.wasm", "index.pck", "index.png")) {
        $p = "build\web\$f"
        if (-not (Test-Path $p) -or (Get-Item $p).Length -eq 0) {
            throw "export.ps1: expected output $p is missing or empty"
        }
    }
    Write-Host "export.ps1: all expected output files present."
} finally {
    Pop-Location
}
