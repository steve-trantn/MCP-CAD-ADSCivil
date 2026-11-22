<#
.SYNOPSIS
  Connects Gemini CLI to ADSCivil through the adscivil MCP server.

.DESCRIPTION
  - Adds "adscivil" to mcpServers in %USERPROFILE%\.gemini\settings.json (other settings are kept).
  - Sets auth to gemini-api-key (Google account login for Gemini CLI individuals is no longer
    supported: IneligibleTierError).
  - Creates the workspace folder with GEMINI.md and a launcher, and marks it trusted
    (Gemini CLI disables MCP servers in untrusted folders).
  Needs Node.js 20+ and Gemini CLI:  npm install -g @google/gemini-cli

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\setup-gemini.ps1
#>
param(
  [string]$Server    = "C:\Program Files\BZS\ADSCivil NW 2027 For ZWCAD 2026\AdsMcpServer.exe",
  [string]$Workspace = (Join-Path $env:USERPROFILE 'ADSCivil-Gemini')
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
if (-not (Test-Path $Server)) { throw "AdsMcpServer.exe not found: $Server" }

$gdir = Join-Path $env:USERPROFILE '.gemini'
New-Item -ItemType Directory -Force $gdir | Out-Null

# settings.json: merge, keep what is already there
$sf = Join-Path $gdir 'settings.json'
if (Test-Path $sf) {
  Copy-Item $sf "$sf.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
  $s = Get-Content $sf -Raw | ConvertFrom-Json
} else { $s = New-Object PSObject }
if (-not $s.PSObject.Properties['mcpServers']) { $s | Add-Member mcpServers (New-Object PSObject) }
$srv = [pscustomobject]@{ command = $Server; args = @(); cwd = (Split-Path $Server); timeout = 600000; trust = $false }
if ($s.mcpServers.PSObject.Properties['adscivil']) { $s.mcpServers.adscivil = $srv } else { $s.mcpServers | Add-Member adscivil $srv }
if (-not $s.PSObject.Properties['security']) { $s | Add-Member security (New-Object PSObject) }
if (-not $s.security.PSObject.Properties['auth']) { $s.security | Add-Member auth (New-Object PSObject) }
if ($s.security.auth.PSObject.Properties['selectedType']) { $s.security.auth.selectedType = 'gemini-api-key' } else { $s.security.auth | Add-Member selectedType 'gemini-api-key' }
[IO.File]::WriteAllText($sf, ($s | ConvertTo-Json -Depth 20), $utf8)
Write-Host "settings.json updated: $sf"

# workspace
New-Item -ItemType Directory -Force $Workspace | Out-Null
$tpl = Join-Path $PSScriptRoot '..\gemini'
Copy-Item (Join-Path $tpl 'GEMINI.md') $Workspace -Force
Copy-Item (Join-Path $tpl 'Mo Gemini ADSCivil.cmd') $Workspace -Force
Write-Host "Workspace: $Workspace"

# trusted folders
$tf = Join-Path $gdir 'trustedFolders.json'
if (Test-Path $tf) { $t = Get-Content $tf -Raw | ConvertFrom-Json } else { $t = New-Object PSObject }
if ($t.PSObject.Properties[$Workspace]) { $t.$Workspace = 'TRUST_FOLDER' } else { $t | Add-Member $Workspace 'TRUST_FOLDER' }
[IO.File]::WriteAllText($tf, ($t | ConvertTo-Json -Depth 5), $utf8)
Write-Host "Trusted: $Workspace"

Write-Host ""
Write-Host "Next: get an API key at https://aistudio.google.com/apikey and create"
Write-Host "  $Workspace\.env   with the line   GEMINI_API_KEY=<your key>"
Write-Host "then double-click 'Mo Gemini ADSCivil.cmd' and type /mcp to see the adscivil tools."
