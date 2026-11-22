<#
.SYNOPSIS
  ADSCivil MCP installer (menu). Started by CaiDat.cmd.

.DESCRIPTION
  Finds the ADSCivil install folders, then sets up ChatGPT (Codex), Gemini CLI and/or
  the AI auto-load for ADSCivil 2026, tests the connection or removes everything.
  Without switches it shows a menu. Switches allow unattended use:
    -All -Codex -Gemini -Adscivil2026 -Test -Uninstall
    -Dir2027 "<folder>" -Dir2026 "<folder>"   (override auto-detection)
#>
param(
  [switch]$All, [switch]$Codex, [switch]$Gemini, [switch]$Adscivil2026, [switch]$Test, [switch]$Uninstall,
  [string]$Dir2027, [string]$Dir2026
)
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$Root = Split-Path $Here
$Version = (Get-Content (Join-Path $Root 'VERSION') -ErrorAction SilentlyContinue | Select-Object -First 1)

# Files downloaded from the internet carry "Mark of the Web"; unblock so PowerShell runs them quietly.
Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

function Write-Title($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }
function Write-Ok($t)    { Write-Host "  [OK] $t" -ForegroundColor Green }
function Write-Warn2($t) { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Write-Err($t)   { Write-Host "  [LOI] $t" -ForegroundColor Red }
function Confirm-YesNo($q) { $a = Read-Host "$q (Y/N)"; return ($a -match '^(y|yes|c|co)$') }
function Update-PathEnv {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}

# ---------- find ADSCivil folders ----------
function Find-AdsDir([string]$ver, [string]$mustHave) {
  $cands = @()
  foreach ($b in @("$env:ProgramFiles\BZS", "${env:ProgramFiles(x86)}\BZS")) {
    if ($b -and (Test-Path $b)) {
      $cands += Get-ChildItem $b -Directory | Where-Object { $_.Name -match "ADSCivil.* $ver .*ZWCAD" } | ForEach-Object { $_.FullName }
    }
  }
  $reg = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
  $cands += Get-ItemProperty $reg -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'ADSCivil' -and $_.DisplayName -match " $ver" -and $_.InstallLocation } |
    ForEach-Object { $_.InstallLocation }
  foreach ($d in $cands) { if ($d -and (Test-Path (Join-Path $d $mustHave))) { return $d.TrimEnd('\') } }
  return $null
}

if (-not $Dir2027) { $Dir2027 = Find-AdsDir '2027' 'AdsMcpServer.exe' }
if (-not $Dir2026) { $Dir2026 = Find-AdsDir '2026' 'ZWCAD.lsp' }
$Server = if ($Dir2027) { Join-Path $Dir2027 'AdsMcpServer.exe' } else { $null }

function Show-Status {
  Write-Host ""
  Write-Host "ADSCivil MCP - ket noi ADSCivil voi ChatGPT (Codex), Gemini va Claude   $Version" -ForegroundColor Cyan
  Write-Host "------------------------------------------------------------------------"
  if ($Dir2027) { Write-Ok "ADSCivil 2027: $Dir2027" } else { Write-Err "Khong tim thay ADSCivil NW 2027 (co AdsMcpServer.exe). Can cai ADSCivil 2027 truoc." }
  if ($Dir2026) { Write-Ok "ADSCivil 2026: $Dir2026" } else { Write-Host "  [-]  Khong co ADSCivil 2026 (bo qua muc 3)" }
}
function Assert-Server { if (-not $Server) { throw "Can ADSCivil NW 2027 (AdsMcpServer.exe). Cai ADSCivil 2027 roi chay lai, hoac dung -Dir2027." } }

# ---------- steps ----------
function Step-Codex([switch]$Remove) {
  Write-Title "ChatGPT (Codex)"
  if (-not $Remove) { Assert-Server }
  Update-PathEnv
  $has = (Get-Command codex -ErrorAction SilentlyContinue) -or (Get-AppxPackage OpenAI.Codex -ErrorAction SilentlyContinue)
  if (-not $has) {
    if ($Remove) { Write-Host "  Khong co Codex, bo qua."; return }
    Write-Warn2 "Chua co Codex. Cach de nhat: cai app 'Codex' cua OpenAI tu Microsoft Store, dang nhap tai khoan ChatGPT, roi chay lai muc nay."
    if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Confirm-YesNo "  Hoac cai Codex CLI bang npm ngay bay gio?")) {
      npm install -g @openai/codex
      Update-PathEnv
    } else { return }
  }
  if ($Remove) { & (Join-Path $Here 'setup-codex.ps1') -Uninstall; return }
  & (Join-Path $Here 'setup-codex.ps1') -Server $Server
  Write-Ok "Xong. THOAT HAN app Codex roi mo lai, mo thu muc %USERPROFILE%\ADSCivil-Codex, tao chat moi."
}

function Step-Gemini([switch]$Remove) {
  Write-Title "Gemini CLI"
  if ($Remove) { & (Join-Path $Here 'setup-gemini.ps1') -Uninstall; return }
  Assert-Server
  Update-PathEnv
  if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
    Write-Warn2 "Chua co Gemini CLI."
    if (-not (Confirm-YesNo "  Cai Gemini CLI (va Node.js neu thieu) ngay bay gio?")) { return }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
      if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "Khong co winget. Cai Node.js LTS tu https://nodejs.org roi chay lai." }
      winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
      Update-PathEnv
    }
    npm install -g @google/gemini-cli
    Update-PathEnv
    if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) { throw "Cai Gemini CLI chua thanh cong. Mo cua so moi va chay lai CaiDat.cmd." }
  }
  & (Join-Path $Here 'setup-gemini.ps1') -Server $Server
  $ws = Join-Path $env:USERPROFILE 'ADSCivil-Gemini'
  $envFile = Join-Path $ws '.env'
  if (-not (Test-Path $envFile) -and -not $env:GEMINI_API_KEY) {
    Write-Host ""
    Write-Host "  Gemini CLI can API key (dang nhap Google khong con dung duoc)."
    Write-Host "  Lay key mien phi tai: https://aistudio.google.com/apikey"
    $k = Read-Host "  Dan API key vao day (Enter de bo qua, them sau)"
    if ($k -and $k.Trim()) {
      [IO.File]::WriteAllText($envFile, "GEMINI_API_KEY=$($k.Trim())`r`n", (New-Object Text.UTF8Encoding($false)))
      Write-Ok "Da luu key vao $envFile"
    } else { Write-Warn2 "Chua co key. Sau nay tao file $envFile voi dong: GEMINI_API_KEY=<key>" }
  }
  Write-Ok "Xong. Bam dup 'Gemini ADSCivil' tren Desktop, go /mcp de xem cac tool."
}

function Step-2026([switch]$Remove) {
  Write-Title "ADSCivil 2026 - tu nap tro ly AI"
  if (-not $Dir2026) { Write-Warn2 "Khong co ADSCivil 2026, bo qua."; return }
  if (-not $Remove) { Assert-Server }
  $running = Get-Process ZWCAD -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match '2026' -and $_.MainWindowTitle -notmatch '2027' }
  if ($running) { Write-Warn2 "ADSCivil 2026 dang mo. Nen luu ban ve va dong lai truoc." ; if (-not (Confirm-YesNo "  Van tiep tuc?")) { return } }
  $script = Join-Path $Here 'install-2026-autoload.ps1'
  $src = if ($Dir2027) { $Dir2027 } else { $Dir2026 }
  $writable = $true
  try { $t = Join-Path $Dir2026 "__w$PID.tmp"; [IO.File]::WriteAllText($t, 'x'); Remove-Item $t } catch { $writable = $false }
  if ($writable) {
    if ($Remove) { & $script -Source $src -Target $Dir2026 -Uninstall } else { & $script -Source $src -Target $Dir2026 }
  } else {
    Write-Host "  Can quyen admin de ghi vao $Dir2026 - Windows se hoi xac nhan..."
    $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$script`"",'-Source',"`"$src`"",'-Target',"`"$Dir2026`"",'-PauseAtEnd')
    if ($Remove) { $a += '-Uninstall' }
    $p = Start-Process powershell -Verb RunAs -ArgumentList $a -Wait -PassThru
    if ($p.ExitCode -eq 0) { Write-Ok "Xong (cua so admin)." } else { Write-Err "Cua so admin bao loi (ma $($p.ExitCode))." }
  }
}

function Step-Test {
  Write-Title "Kiem tra ket noi MCP"
  Assert-Server
  if (-not (Get-Process ZWCAD -ErrorAction SilentlyContinue)) { Write-Warn2 "ZWCAD chua mo: chi kiem tra duoc cac tool khong can CAD." }
  & (Join-Path $Here 'test-mcp.ps1') -Exe $Server -Calls get_drawing_info | ForEach-Object {
    if ($_ -match '^  - ') { } else { $_ }
  }
}

function Invoke-Step($block) {
  try { & $block } catch { Write-Err $_.Exception.Message }
}

# ---------- run ----------
Show-Status
$any = $All -or $Codex -or $Gemini -or $Adscivil2026 -or $Test
if ($any -or $Uninstall) {
  if ($Uninstall -and -not ($Codex -or $Gemini -or $Adscivil2026)) { $All = $true }
  if ($All -or $Codex)        { Invoke-Step { Step-Codex  -Remove:$Uninstall } }
  if ($All -or $Gemini)       { Invoke-Step { Step-Gemini -Remove:$Uninstall } }
  if ($All -or $Adscivil2026) { Invoke-Step { Step-2026   -Remove:$Uninstall } }
  if ($Test)                  { Invoke-Step { Step-Test } }
  return
}

while ($true) {
  Write-Host ""
  Write-Host "  1. Ket noi ChatGPT (app Codex)"
  Write-Host "  2. Ket noi Gemini CLI"
  Write-Host "  3. ADSCivil 2026: tu nap tro ly AI (lenh ADSAI)"
  Write-Host "  4. Cai tat ca (1 + 2 + 3)"
  Write-Host "  5. Kiem tra ket noi (mo ADSCivil truoc)"
  Write-Host "  6. Go bo tat ca"
  Write-Host "  0. Thoat"
  $c = Read-Host "Chon"
  switch ($c) {
    '1' { Invoke-Step { Step-Codex } }
    '2' { Invoke-Step { Step-Gemini } }
    '3' { Invoke-Step { Step-2026 } }
    '4' { Invoke-Step { Step-Codex }; Invoke-Step { Step-Gemini }; Invoke-Step { Step-2026 } }
    '5' { Invoke-Step { Step-Test } }
    '6' { if (Confirm-YesNo "Go adscivil khoi Codex, Gemini va ADSCivil 2026?") { Invoke-Step { Step-Codex -Remove }; Invoke-Step { Step-Gemini -Remove }; Invoke-Step { Step-2026 -Remove } } }
    '0' { return }
    default { Write-Host "  Chon 0-6." }
  }
}
