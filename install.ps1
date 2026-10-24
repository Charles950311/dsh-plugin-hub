#Requires -Version 5.1
<#
.SYNOPSIS
    Install dsh-plugin-hub: copy the hub skill to a local directory, create a
    junction from %USERPROFILE%\.dsh\skills so DSH hot-loads it, and seed
    config.ps1 from the example.
#>
[CmdletBinding()]
param(
    # Where the hub itself should live (defaults under your user profile)
    [string]$HubRoot = "$env:USERPROFILE\.dsh-hub"
)

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot

$target = Join-Path $HubRoot "dsh-plugin-hub"
$skillsDir = Join-Path $env:USERPROFILE ".dsh\skills"
$junction = Join-Path $skillsDir "dsh-plugin-hub"

Write-Host "== dsh-plugin-hub install =="

# 1. Copy hub skill + scripts
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item (Join-Path $repo "skill\*") $target -Recurse -Force
Copy-Item (Join-Path $repo "status.ps1") $target -Force
Copy-Item (Join-Path $repo "hindsight.ps1") $target -Force
Copy-Item (Join-Path $repo "doctor.ps1") $target -Force
Copy-Item (Join-Path $repo "gen-provenance.ps1") $target -Force
Write-Host ("hub files -> {0}" -f $target)

# 2. Seed config
$configTarget = Join-Path $target "config.ps1"
if (-not (Test-Path $configTarget)) {
    Copy-Item (Join-Path $repo "config.example.ps1") $configTarget
    Write-Host "config.ps1 created from example — edit paths to fit your machine"
} else {
    Write-Host "config.ps1 already exists — left untouched"
}

# Windows PowerShell 5.1 parses non-ASCII .ps1 correctly only when the file
# is UTF-8 *with* BOM. Normalize everything we just wrote/copied.
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8Plain = New-Object System.Text.UTF8Encoding($false)
$hubScripts = @("status.ps1", "hindsight.ps1") + (Get-ChildItem $target -Filter "*.ps1" | Select-Object -ExpandProperty Name)
$hubScripts = $hubScripts | Select-Object -Unique
foreach ($name in $hubScripts) {
    $p = Join-Path $target $name
    if (Test-Path $p) {
        $text = [System.IO.File]::ReadAllText($p, $utf8Plain)
        [System.IO.File]::WriteAllText($p, $text, $utf8Bom)
    }
}
Write-Host "ps1 files normalized to UTF-8 BOM"

# 3. Junction into the DSH hot-load directory
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
if (Test-Path $junction) {
    Write-Host ("junction already exists: {0}" -f $junction)
} else {
    New-Item -ItemType Junction -Path $junction -Target $target | Out-Null
    Write-Host ("junction created: {0} -> {1}" -f $junction, $target)
}

# 4. Next steps
Write-Host ""
Write-Host "Done. Next steps:"
Write-Host ("  1. Edit {0}" -f $configTarget)
Write-Host "  2. Restart DSH (or reload its Web UI) so the skill hot-loads"
Write-Host "  3. In a DSH session, ask: which plugins are installed / how do I use memory?"
Write-Host "  4. Track what you install in PROVENANCE.md (see templates/)"
