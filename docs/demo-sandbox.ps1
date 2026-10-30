# Reproducible capture sandbox for docs/demo.gif.
#
# Builds a throwaway "new user" home under C:\Users\demo, runs the REAL
# install.ps1 + doctor.ps1 there, and stores their output for
# make-demo-gif.py. Nothing here touches your own %USERPROFILE%; delete
# C:\Users\demo when done. The GIF substitutes C:\Users\demo -> C:\Users\you.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\demo-sandbox.ps1 [-Repo <path to repo checkout>]
[CmdletBinding()]
param([string]$Repo)

$ErrorActionPreference = "Stop"
# PowerShell 5.1 leaves $PSScriptRoot empty inside a param default; resolve here.
if (-not $Repo) {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $Repo = Split-Path -Parent $here
}
$DEMO = "C:\Users\demo"
$env:USERPROFILE = $DEMO

Remove-Item $DEMO -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $DEMO | Out-Null

# --- 1. "clone" the repo into the demo home --------------------------------
$clone = Join-Path $DEMO "clone"
Copy-Item $Repo $clone -Recurse -Force

# --- 2. real install -------------------------------------------------------
$installOut = & (Join-Path $clone "install.ps1") 2>&1
$installOut | Out-File (Join-Path $DEMO "install.out.txt") -Encoding UTF8
$installOut | Write-Output

# --- 3. a fresh user has no plugins yet (keeps `dsh plugin list` honest) ---
$profileDir = Join-Path $DEMO ".dsh\profiles\desktop"
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
[IO.File]::WriteAllText(
    (Join-Path $profileDir "package.json"),
    '{"name":"dsh-profile-desktop","private":true,"dependencies":{}}',
    (New-Object System.Text.UTF8Encoding $false))

# --- 4. stub tool files + skill junctions, then seed config ----------------
$hub = Join-Path $DEMO ".dsh-hub\dsh-plugin-hub"
$sk  = Join-Path $DEMO ".dsh-hub\skills"
$skv = Join-Path $DEMO ".dsh\skills"

foreach ($n in 'agent-browser','local-whisper','skill-scanner','find-skills') {
    New-Item -ItemType Directory -Force -Path (Join-Path $sk $n) | Out-Null
}
Set-Content -Path (Join-Path $sk 'agent-browser\ab.cmd') -Value '@echo off' -Encoding ASCII
Set-Content -Path (Join-Path $sk 'local-whisper\whisper-cli.exe') -Value 'stub' -Encoding ASCII
Set-Content -Path (Join-Path $sk 'skill-scanner\scan-skill.cmd') -Value '@echo off' -Encoding ASCII
Set-Content -Path (Join-Path $sk 'find-skills\SKILL.md') -Value '# find-skills' -Encoding ASCII

New-Item -ItemType Directory -Force -Path $skv | Out-Null
foreach ($n in 'agent-browser','local-whisper','skill-scanner','find-skills') {
    $p = Join-Path $skv $n
    if (-not (Test-Path $p)) { New-Item -ItemType Junction -Path $p -Target (Join-Path $sk $n) | Out-Null }
}

$cfg = @"
# dsh-plugin-hub configuration (demo)
`$DshCli = `$null
`$SkillsRoot = "`$env:USERPROFILE\.dsh-hub\skills"
`$DshProfile = "desktop"
`$AgentBrowserCmd = "$sk\agent-browser\ab.cmd"
`$WhisperCli      = "$sk\local-whisper\whisper-cli.exe"
`$SkillScannerCmd = "$sk\skill-scanner\scan-skill.cmd"
`$HindsightUrl  = "http://127.0.0.1:8888"
`$HindsightBank = "default"
"@
[IO.File]::WriteAllText((Join-Path $hub 'config.ps1'), $cfg, (New-Object System.Text.UTF8Encoding $true))

# --- 5. real doctor run ----------------------------------------------------
$doctorOut = & (Join-Path $hub 'doctor.ps1') 2>&1
$doctorOut | Out-File (Join-Path $DEMO "doctor.out.txt") -Encoding UTF8
$doctorOut | Write-Output
Write-Output "EXIT=$LASTEXITCODE"
Write-Output ""
Write-Output "Captured to $DEMO\install.out.txt and $DEMO\doctor.out.txt -"
Write-Output "now run:  python docs/make-demo-gif.py"
