# Install BlenderMCP addon into every Blender version under AppData.
# Usage: powershell -ExecutionPolicy Bypass -File install-addon.ps1

$ErrorActionPreference = "Stop"
$addonSrc = Join-Path $PSScriptRoot "addon.py"
$blenderRoot = Join-Path $env:APPDATA "Blender Foundation\Blender"

if (-not (Test-Path $addonSrc)) {
    Write-Error "Missing addon.py at $addonSrc"
}

if (-not (Test-Path $blenderRoot)) {
    Write-Error @"
Blender app data not found at:
  $blenderRoot
Open Blender once, then run this script again.
"@
}

$installed = $false
Get-ChildItem $blenderRoot -Directory | ForEach-Object {
    $addonsDir = Join-Path $_.FullName "scripts\addons"
    New-Item -ItemType Directory -Force -Path $addonsDir | Out-Null

    # Single-file install is the most reliable module name on Windows.
    $destFile = Join-Path $addonsDir "blender_mcp.py"
    Copy-Item $addonSrc $destFile -Force

    # Remove old folder-based install if present (can leave broken module entries).
    $oldFolder = Join-Path $addonsDir "blender_mcp"
    if (Test-Path $oldFolder) {
        Remove-Item $oldFolder -Recurse -Force
    }

    Write-Host "Installed addon for Blender $($_.Name) -> $destFile"
    $installed = $true
}

if (-not $installed) {
    Write-Error "No Blender version folders under $blenderRoot"
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart Blender completely"
Write-Host "  2. Edit > Preferences > Add-ons > Refresh"
Write-Host "  3. Search 'Blender MCP' and enable it"
Write-Host "  4. N panel > BlenderMCP > Connect"
