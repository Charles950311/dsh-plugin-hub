#Requires -Version 5.1
<#
.SYNOPSIS
    Thin CLI over the Hindsight long-term-memory REST service, for when the
    dsh-hindsight tool isn't loaded in the current session yet.
#>
param(
    [ValidateSet("status", "remember", "recall", "list")]
    [string]$Action = "status",
    [string]$Text,
    [string]$Query,
    [int]$Limit = 10,
    # Overrides; defaults come from config.ps1 next to this script
    [string]$BaseUrl,
    [string]$Bank
)

$ErrorActionPreference = "Stop"
$hub = $PSScriptRoot
$configPath = Join-Path $hub "config.ps1"
$cfgUrl = "http://127.0.0.1:8888"; $cfgBank = "default"
if (Test-Path $configPath) { . $configPath }
if (-not $BaseUrl) { $BaseUrl = $HindsightUrl; if (-not $BaseUrl) { $BaseUrl = $cfgUrl } }
if (-not $Bank)    { $Bank = $HindsightBank;   if (-not $Bank)    { $Bank = $cfgBank } }
$bank = "$BaseUrl/v1/default/banks/$Bank"

function Invoke-Json {
    param([string]$Uri, [string]$Method = "GET", $Body = $null)
    $params = @{
        Uri             = $Uri
        Method          = $Method
        UseBasicParsing = $true
        TimeoutSec      = 90
        ContentType     = "application/json; charset=utf-8"
    }
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Compress -Depth 8
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    }
    $resp = Invoke-WebRequest @params
    if (-not $resp.RawContentStream) { return ($resp.Content | ConvertFrom-Json) }
    $text = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    return ($text | ConvertFrom-Json)
}

switch ($Action) {
    "status" {
        try {
            $health = Invoke-Json "$BaseUrl/health"
            Write-Output ("health: " + $health.status + " / db: " + $health.database)
        } catch {
            Write-Output ("health: DOWN (cannot reach {0} — is the Hindsight service running?)" -f $BaseUrl)
            return
        }
        try {
            $stats = Invoke-Json "$bank/stats"
            Write-Output ("bank: $Bank / stats: " + ($stats | ConvertTo-Json -Compress -Depth 4))
        } catch {
            Write-Output "bank: $Bank / stats unavailable"
        }
    }
    "remember" {
        if (-not $Text) { throw "-Text is required for remember" }
        $body = @{
            items        = @(@{
                    content  = $Text
                    context  = "dsh"
                    metadata = @{ source = "dsh" }
                })
            async        = $true
            operation_id = [guid]::NewGuid().ToString()
        }
        $r = Invoke-Json "$bank/memories" "POST" $body
        Write-Output ("stored: " + ($r | ConvertTo-Json -Compress -Depth 4))
    }
    "recall" {
        if (-not $Query) { throw "-Query is required for recall" }
        $body = @{ query = $Query; budget = "mid"; max_tokens = 4000 }
        $r = Invoke-Json "$bank/memories/recall" "POST" $body
        $items = @($r.results)
        Write-Output ("hits: " + $items.Count)
        $items | Select-Object -First $Limit | ForEach-Object {
            Write-Output ("- [" + $_.id + "] " + $_.text)
        }
    }
    "list" {
        $r = Invoke-Json ("$bank/memories/list?limit=" + $Limit)
        $items = @($r.items)
        Write-Output ("items: " + $items.Count)
        $items | ForEach-Object { Write-Output ("- [" + $_.id + "] " + $_.text) }
    }
}
