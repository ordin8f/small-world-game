# Serves the exported web build locally so it can be played in a real browser.
# Usage: tools/serve.ps1 [-Port 8081]
param([int]$Port = 8081)
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    if (-not (Test-Path "build\web\index.html")) {
        throw "serve.ps1: build/web/index.html not found — run tools/export.ps1 first."
    }
    Write-Host "Serving godot/build/web on http://localhost:$Port/ (Ctrl+C to stop)"
    python -m http.server $Port --directory build/web
} finally {
    Pop-Location
}
