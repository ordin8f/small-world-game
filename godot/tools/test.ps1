# Runs the gdUnit4 test suite headlessly (unit + play tests under godot/tests/).
$ErrorActionPreference = "Stop"
Push-Location "$PSScriptRoot\.."
try {
    & "$PSScriptRoot\godot.ps1" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
    if ($LASTEXITCODE -ne 0) { throw "tests failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}
