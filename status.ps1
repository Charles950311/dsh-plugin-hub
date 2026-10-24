#Requires -Version 5.1
<#
.SYNOPSIS
    One-shot health check for your DSH plugin setup: profile plugins, tool
    files, optional services, and the skill junctions DSH will hot-load.
#>
param([switch]$Full)

$ErrorActionPreference = "Continue"
$hub = $PSScriptRoot
$configPath = Join-Path $hub "config.ps1"

$DshCli = $null; $DshProfile = "desktop"; $SkillsRoot = "$env:USERPROFILE\.dsh-hub\skills"
$AgentBrowserCmd = $null; $WhisperCli = $null; $SkillScannerCmd = $null
$HindsightUrl = $null

if (Test-Path $configPath) { . $configPath }

function Test-Port([int]$Port) {
    return (Test-NetConnection 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)
}

# --- resolve dsh CLI ---
if (-not $DshCli) {
    $cmd = Get-Command dsh -ErrorAction SilentlyContinue
    if ($cmd) { $DshCli = $cmd.Source }
}
if (-not $DshCli) {
    foreach ($p in @(
        "$env:LOCALAPPDATA\Programs\deepseek harness\resources\runtime\cli\bin\dsh.cmd",
        "D:\Program Files (x86)\deepseek harness\resources\runtime\cli\bin\dsh.cmd",
        "C:\Program Files\deepseek harness\resources\runtime\cli\bin\dsh.cmd"
    )) { if (Test-Path $p) { $DshCli = $p; break } }
}

Write-Output "== DSH profile plugins =="
if ($DshCli -and (Test-Path $DshCli)) {
    & $DshCli plugin --profile $DshProfile list --depth=0 2>$null | Select-Object -First 20
} else {
    Write-Output "dsh CLI not found — set `$DshCli in config.ps1"
}

Write-Output ""
Write-Output "== Tool files =="
$paths = [ordered]@{}
if ($AgentBrowserCmd) { $paths["agent-browser"] = $AgentBrowserCmd }
if ($WhisperCli)      { $paths["whisper-cli"]   = $WhisperCli }
if ($SkillScannerCmd) { $paths["skill-scanner"] = $SkillScannerCmd }
$paths["plugin-hub"] = Join-Path $hub "SKILL.md"
foreach ($k in $paths.Keys) {
    $p = $paths[$k]
    if (Test-Path $p) { Write-Output ("{0,-16} OK   {1}" -f $k, $p) }
    else { Write-Output ("{0,-16} MISS {1}" -f $k, $p) }
}

Write-Output ""
Write-Output "== Services =="
if ($HindsightUrl) {
    $u = [Uri]$HindsightUrl
    $h = Test-Port $u.Port
    Write-Output ("hindsight:{0,-5}  {1}" -f $u.Port, $(if ($h) { "UP" } else { "DOWN" }))
} else {
    Write-Output "hindsight: not configured (set `$HindsightUrl in config.ps1)"
}

Write-Output ""
Write-Output "== DSH skill roots =="
$dshSkills = Join-Path $env:USERPROFILE ".dsh\skills"
Get-ChildItem $dshSkills -Force -ErrorAction SilentlyContinue |
    ForEach-Object { "{0} -> {1}" -f $_.Name, ($_.Target -join ',') }

if ($Full) {
    Write-Output ""
    Write-Output "== Versions =="
    if ($AgentBrowserCmd -and (Test-Path $AgentBrowserCmd)) {
        & $AgentBrowserCmd --version 2>&1 | Select-Object -First 1
    }
    if ($SkillScannerCmd -and (Test-Path $SkillScannerCmd)) {
        & $SkillScannerCmd scan --help 2>&1 | Select-Object -First 3
    }
}
