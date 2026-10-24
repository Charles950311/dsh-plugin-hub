#Requires -Version 5.1
<#
.SYNOPSIS
    Health diagnosis for a dsh-plugin-hub install: config, DSH CLI, skill
    junction, services, and optional tools - each check prints PASS/WARN/FAIL
    with the fix command when something is wrong.

.PARAMETER Fix
    Apply the safe fixes automatically (UTF-8 BOM normalization, missing
    junction creation). Everything else stays report-only.
#>
[CmdletBinding()]
param([switch]$Fix)

$ErrorActionPreference = "Continue"
$hub = $PSScriptRoot
$script:failures = 0

function Result([string]$Level, [string]$Check, [string]$Detail, [string]$FixHint) {
    Write-Output ("[{0,-4}] {1}" -f $Level, $Check)
    if ($Detail)   { Write-Output ("       {0}" -f $Detail) }
    if ($FixHint)  { Write-Output ("       fix: {0}" -f $FixHint) }
    if ($Level -eq "FAIL") { $script:failures++ }
}

# ---------- 1. config ----------
$configPath = Join-Path $hub "config.ps1"
if (Test-Path $configPath) {
    $bytes = [System.IO.File]::ReadAllBytes($configPath)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) {
        Result "PASS" "config.ps1 present, UTF-8 BOM ok"
    } elseif ($Fix) {
        $text = [System.IO.File]::ReadAllText($configPath, (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText($configPath, $text, (New-Object System.Text.UTF8Encoding($true)))
        Result "PASS" "config.ps1 BOM added by -Fix (was missing - breaks non-ASCII paths on PS 5.1)"
    } else {
        Result "WARN" "config.ps1 has no UTF-8 BOM" `
            "Windows PowerShell 5.1 mis-parses non-ASCII paths without it." `
            "re-run with -Fix, or: $hub\install.ps1"
    }
    . $configPath
} else {
    Result "WARN" "config.ps1 missing (defaults in use)" `
        "copy config.example.ps1 to config.ps1 and set your paths."
}

# ---------- 2. DSH CLI ----------
$DshCli = $null
if (Test-Path $configPath) { . $configPath }
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
if ($DshCli -and (Test-Path $DshCli)) {
    Result "PASS" "dsh CLI found" $DshCli
    & $DshCli plugin --profile $(if ($DshProfile) { $DshProfile } else { "desktop" }) list --depth=0 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Result "PASS" "dsh plugin list exits 0 (no peer-dependency breakage)"
    } else {
        Result "FAIL" "dsh plugin list failed (exit $LASTEXITCODE)" `
            "usually a peer-dependency conflict after a harness upgrade." `
            "check plugin versions against your harness version; see PROVENANCE.md"
    }
} else {
    Result "FAIL" "dsh CLI not found" `
        "set `$DshCli in config.ps1 to your dsh.cmd path."
}

# ---------- 3. junction ----------
$skillsDir = Join-Path $env:USERPROFILE ".dsh\skills"
$junction = Join-Path $skillsDir "dsh-plugin-hub"
$here = (Get-Item $hub).FullName
if (Test-Path $junction) {
    $target = (Get-Item $junction -Force).Target
    if ($target -and ($target -join "") -eq $here) {
        Result "PASS" "junction points here" "$junction -> $here"
    } else {
        Result "WARN" "junction exists but points elsewhere" `
            ("{0} -> {1}" -f $junction, ($target -join ",")) `
            "if this is an old install: remove the junction and re-run install.ps1"
    }
} elseif ($Fix) {
    New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
    New-Item -ItemType Junction -Path $junction -Target $here | Out-Null
    Result "PASS" "junction created by -Fix" "$junction -> $here"
} else {
    Result "FAIL" "no junction in $skillsDir" `
        "DSH will not hot-load the hub." "re-run with -Fix, or: $hub\install.ps1"
}

# ---------- 4. hub skill reachable ----------
if (Test-Path (Join-Path $hub "SKILL.md")) {
    Result "PASS" "SKILL.md present (installed layout)"
} elseif (Test-Path (Join-Path $hub "skill\SKILL.md")) {
    Result "PASS" "repo checkout layout detected" `
        "run install.ps1 -HubRoot <dir> to get the installed layout DSH hot-loads."
} else {
    Result "FAIL" "SKILL.md missing in hub directory" `
        "run install.ps1 -HubRoot <dir> and install there."
}

# ---------- 5. hindsight ----------
if ($HindsightUrl) {
    $u = [Uri]$HindsightUrl
    $up = Test-NetConnection 127.0.0.1 -Port $u.Port -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($up) {
        try {
            $h = Invoke-RestMethod -Uri "$HindsightUrl/health" -TimeoutSec 8
            Result "PASS" "hindsight healthy" ("{0} (status: {1})" -f $HindsightUrl, $h.status)
        } catch {
            Result "WARN" "hindsight port open but /health failed" $_.Exception.Message
        }
    } else {
        Result "WARN" "hindsight DOWN on port $($u.Port)" `
            "memory tools will fake-fail; start the service, then re-check."
    }
} else {
    Result "INFO" "hindsight not configured (no memory checks)"
}

# ---------- 6. optional tools ----------
foreach ($pair in @(@("agent-browser", $AgentBrowserCmd), @("whisper", $WhisperCli), @("skill-scanner", $SkillScannerCmd))) {
    $name = $pair[0]; $path = $pair[1]
    if ($path) {
        if (Test-Path $path) { Result "PASS" ("tool {0}: {1}" -f $name, $path) }
        else { Result "WARN" ("tool {0} configured but missing: {1}" -f $name, $path) `
            "update config.ps1 or install the tool." }
    }
}

Write-Output ""
if ($script:failures -eq 0) { Write-Output "doctor: no FAIL items." }
else { Write-Output ("doctor: {0} FAIL item(s) - fix them, then re-run." -f $script:failures) }
exit $(if ($script:failures -eq 0) { 0 } else { 1 })
