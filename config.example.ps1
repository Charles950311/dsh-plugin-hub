# dsh-plugin-hub configuration
# Copy this file to config.ps1 and adjust the paths for your machine.
# config.ps1 is git-ignored — never commit personal paths.

# --- DSH CLI -------------------------------------------------------------
# Leave $null to auto-detect (PATH, then common install locations).
$DshCli = $null
# $DshCli = "D:\Program Files (x86)\deepseek harness\resources\runtime\cli\bin\dsh.cmd"

# --- Unified skills directory --------------------------------------------
# All your skills live here; dsh-plugin-hub is junctioned into
# %USERPROFILE%\.dsh\skills so DSH hot-loads it.
$SkillsRoot = "$env:USERPROFILE\.dsh-hub\skills"

# --- DSH profile used for `plugin list` ----------------------------------
$DshProfile = "desktop"

# --- Optional tool checks (leave $null to skip) ---------------------------
$AgentBrowserCmd = $null   # e.g. "$env:USERPROFILE\.dsh-hub\skills\agent-browser\ab.cmd"
$WhisperCli      = $null   # e.g. "C:\dsh-tools\whisper\bin\Release\whisper-cli.exe"
$SkillScannerCmd = $null   # e.g. "$env:USERPROFILE\.dsh-hub\skills\skill-scanner\scan-skill.cmd"

# --- Hindsight (long-term memory) -----------------------------------------
$HindsightUrl  = "http://127.0.0.1:8888"
$HindsightBank = "default"
