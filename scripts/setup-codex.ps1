<#
.SYNOPSIS
  Connects ChatGPT (Codex desktop app / Codex CLI) to ADSCivil through the adscivil MCP server.

.DESCRIPTION
  - Finds codex.exe (PATH, or inside the Microsoft Store "OpenAI.Codex" app).
  - Runs "codex mcp add adscivil -- <AdsMcpServer.exe>".
  - Adds cwd and startup_timeout_sec to [mcp_servers.adscivil] in %USERPROFILE%\.codex\config.toml.
    Without cwd the desktop app fails with "The directory name is invalid (os error 267)"
    and ChatGPT falls back to screenshots.
  - Creates the workspace folder with AGENTS.md.
  Restart the Codex app afterwards (it reads MCP config only at start).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\setup-codex.ps1
#>
param(
  [string]$Server    = "C:\Program Files\BZS\ADSCivil NW 2027 For ZWCAD 2026\AdsMcpServer.exe",
  [string]$Workspace = (Join-Path $env:USERPROFILE 'ADSCivil-Codex'),
  [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'

$cx = (Get-Command codex -ErrorAction SilentlyContinue).Source
if (-not $cx) {
  $pkg = Get-AppxPackage OpenAI.Codex -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pkg) { $cx = Join-Path $pkg.InstallLocation 'app\resources\codex.exe' }
}
if (-not $cx -or -not (Test-Path $cx)) { throw "Khong thay Codex. Cai app Codex (Microsoft Store) hoac: npm install -g @openai/codex" }
Write-Host "codex: $cx"

$cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
if (Test-Path $cfg) { Copy-Item $cfg "$cfg.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" }

if ($Uninstall) {
  & $cx mcp remove adscivil
  Write-Host "Da go adscivil khoi Codex. Thu muc $Workspace duoc giu lai (xoa tay neu muon)."
  return
}
if (-not (Test-Path $Server)) { throw "Khong thay AdsMcpServer.exe: $Server" }

& $cx mcp remove adscivil 2>$null | Out-Null
& $cx mcp add adscivil -- $Server
if ($LASTEXITCODE -ne 0) { throw "codex mcp add failed" }

# add cwd + startup timeout right after the command line of [mcp_servers.adscivil]
$text = [IO.File]::ReadAllText($cfg)
$dir  = Split-Path $Server
$rx   = '(?m)^(\[mcp_servers\.adscivil\]\r?\n(?:(?!\[)[^\r\n]*\r?\n)*?command\s*=\s*[^\r\n]*\r?\n)'
if ($text -notmatch '(?ms)^\[mcp_servers\.adscivil\][^\[]*?^cwd\s*=') {
  $text = [regex]::Replace($text, $rx, { param($m) $m.Value + "cwd = '$dir'`nstartup_timeout_sec = 60`n" }, 1)
  [IO.File]::WriteAllText($cfg, $text, (New-Object Text.UTF8Encoding($false)))
}
& $cx mcp get adscivil

New-Item -ItemType Directory -Force $Workspace | Out-Null
Copy-Item (Join-Path $PSScriptRoot '..\codex\AGENTS.md') $Workspace -Force
Write-Host ""
Write-Host "Workspace: $Workspace"
Write-Host "Next: quit the Codex app completely, open it again, open the workspace folder,"
Write-Host "start a NEW chat and ask: 'Dung tool adscivil liet ke cac layer cua ban ve dang mo.'"
