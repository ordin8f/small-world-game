# Headless (re)import of the Godot project. Exits non-zero on failure.
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    & "$PSScriptRoot\godot.ps1" --headless --path . --import
    if ($LASTEXITCODE -ne 0) { throw "import failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}
