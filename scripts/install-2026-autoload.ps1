<#
.SYNOPSIS
  Bring the ADSCivil 2027 AI assistant (MCP) to ADSCivil 2026 and load it at every ZWCAD start.

.DESCRIPTION
  1. Copies Ads.System.AI.Assistant.zrx, AdsMcpServer.exe and the AdsAI\ folder
     from the ADSCivil 2027 install folder into the ADSCivil 2026 install folder.
  2. Backs up ZWCAD.lsp in the 2026 folder and appends zwcad\ads-ai-autoload.lsp
     to it (only once: it checks for the marker line).
  Run in an elevated PowerShell if the install folder is under C:\Program Files
  and is not writable for your user. Close ADSCivil 2026 first.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\install-2026-autoload.ps1
#>
param(
  [string]$Source = "C:\Program Files\BZS\ADSCivil NW 2027 For ZWCAD 2026",
  [string]$Target = "C:\Program Files\BZS\ADSCivil NW 2026 For ZWCAD 2026"
)
$ErrorActionPreference = 'Stop'
$marker  = '(defun ads-ai-autoload'
$snippet = Join-Path $PSScriptRoot '..\zwcad\ads-ai-autoload.lsp'

foreach ($p in @($Source, $Target)) {
  if (-not (Test-Path $p)) { throw "Folder not found: $p" }
}
foreach ($f in @('Ads.System.AI.Assistant.zrx', 'AdsMcpServer.exe', 'AdsAI')) {
  if (-not (Test-Path (Join-Path $Source $f))) { throw "Missing in source (ADSCivil 2027): $f" }
}

Write-Host "[1/2] Copying AI module from 2027 to 2026..."
Copy-Item (Join-Path $Source 'Ads.System.AI.Assistant.zrx') $Target -Force
Copy-Item (Join-Path $Source 'AdsMcpServer.exe') $Target -Force
Copy-Item (Join-Path $Source 'AdsAI') $Target -Recurse -Force

Write-Host "[2/2] Adding auto-load to ZWCAD.lsp..."
$lsp = Join-Path $Target 'ZWCAD.lsp'
if (-not (Test-Path $lsp)) { throw "ZWCAD.lsp not found in $Target" }
$text = [IO.File]::ReadAllText($lsp)
if ($text.Contains($marker)) {
  Write-Host "      ZWCAD.lsp already has the auto-load block, nothing to do."
} else {
  $bak = "$lsp.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
  Copy-Item $lsp $bak
  $add = [IO.File]::ReadAllText((Resolve-Path $snippet))
  $nl  = if ($text.EndsWith("`n")) { '' } else { "`r`n" }
  [IO.File]::WriteAllText($lsp, $text + $nl + "`r`n" + $add, (New-Object Text.UTF8Encoding($false)))
  Write-Host "      Done. Backup: $bak"
}

Write-Host ""
Write-Host "OK. Start ADSCivil 2026: the command line shows 'ADSCivil AI: da nap...'. Type ADSAI."
Write-Host "Note: reinstalling ADSCivil 2026 overwrites ZWCAD.lsp - run this script again."
