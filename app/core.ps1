# Steve CAD-AI Connect - core logic shared by the GUI and the command line.
# Dot-source this file. Set $script:LogSink / $script:ConfirmSink to redirect messages and questions.

$ErrorActionPreference = 'Stop'
$script:AppName   = 'Steve CAD-AI Connect'
$script:AppId     = 'SteveCADConnect'
$script:Root      = Split-Path $PSScriptRoot
$script:Version   = (Get-Content (Join-Path $script:Root 'VERSION') -ErrorAction SilentlyContinue | Select-Object -First 1)
$script:AppHome   = Join-Path $env:LOCALAPPDATA $script:AppId
$script:ToolDir   = Join-Path $script:AppHome 'tool'
$script:VenvPy    = Join-Path $script:AppHome 'venv\Scripts\python.exe'
$script:Workspace = Join-Path $env:USERPROFILE 'Steve-CAD-AI'
$script:Utf8      = New-Object Text.UTF8Encoding($false)
$script:IsGui     = $false
$script:Author    = 'Steve Tran'
$script:Phone     = '0987 779 228'
$script:Contact   = "$($script:Author) | $($script:Phone)"

# our own MCP server for ZWCAD / AutoCAD (folder server\ of this tool), installed to %LOCALAPPDATA%
$script:ServerDir = Join-Path $script:AppHome 'server'
$script:Settings  = Join-Path $script:AppHome 'settings.json'

$script:CadList    = @('zwcad', 'autocad', 'adscivil')
$script:CadLabel   = @{ zwcad = 'ZWCAD'; autocad = 'AutoCAD'; adscivil = 'ADSCivil' }
$script:ClientList = @('claude', 'claudecode', 'codex', 'gemini')
$script:ClientLabel = @{ claude = 'Claude Desktop'; claudecode = 'Claude Code'; codex = 'ChatGPT (Codex)'; gemini = 'Gemini CLI' }

$script:LogSink     = { param($m, $lvl) Write-Host $m }
$script:ConfirmSink = { param($q) (Read-Host "$q (Y/N)") -match '^(y|yes|c|co)$' }
function Write-Log([string]$m, [string]$lvl = 'info') { & $script:LogSink $m $lvl }
function Confirm-User([string]$q) { return [bool](& $script:ConfirmSink $q) }
function Invoke-UiPump { if ($script:IsGui) { [System.Windows.Forms.Application]::DoEvents() } }

function Update-PathEnv {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Backup-File($f) { if (Test-Path $f) { Copy-Item $f "$f.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" } }
function Read-Json($f) {
  if (Test-Path $f) { $t = [IO.File]::ReadAllText($f); if ($t.Trim()) { return ($t | ConvertFrom-Json) } }
  return (New-Object PSObject)
}
function Get-Setting([string]$name, $default = $null) {
  $s = Read-Json $script:Settings
  if ($s.PSObject.Properties[$name]) { return $s.$name } else { return $default }
}
function Set-Setting([string]$name, $value) {
  New-Item -ItemType Directory -Force $script:AppHome | Out-Null
  $s = Read-Json $script:Settings; Set-Prop $s $name $value; Write-Json $script:Settings $s
}
function Write-Json($f, $obj) { [IO.File]::WriteAllText($f, ($obj | ConvertTo-Json -Depth 30), $script:Utf8) }
function Set-Prop($obj, [string]$name, $value) {
  if ($obj.PSObject.Properties[$name]) { $obj.$name = $value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

# Runs an executable, streams its output to the log, keeps the GUI responsive. Returns the exit code.
function Invoke-Exe([string]$File, [string[]]$ArgList = @(), [switch]$Quiet) {
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $File
  $psi.Arguments = ($ArgList | ForEach-Object { if ($_ -match '[\s"]' -or $_ -eq '') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = $script:Utf8; $psi.StandardErrorEncoding = $script:Utf8
  $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
  $psi.CreateNoWindow = $true
  $p = [Diagnostics.Process]::Start($psi)
  $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync()
  while (-not $p.HasExited) { Start-Sleep -Milliseconds 100; Invoke-UiPump }
  $p.WaitForExit()
  if (-not $Quiet) {
    (($o.Result + "`n" + $e.Result) -split "`r?`n") | Where-Object { $_.Trim() } | ForEach-Object { Write-Log "      $_" 'detail' }
  }
  return $p.ExitCode
}
function Find-Exe([string]$name) {
  Update-PathEnv
  $c = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  return $null
}

# ======================= detection =======================
function Get-ZwcadProgId {
  $ids = Get-ChildItem Registry::HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^ZWCAD\.Application\.\d+$' } | ForEach-Object { $_.PSChildName }
  if ($ids) { return ($ids | Sort-Object { [int]($_ -replace '^ZWCAD\.Application\.', '') } -Descending | Select-Object -First 1) }
  if (Test-Path 'Registry::HKEY_CLASSES_ROOT\ZWCAD.Application') { return 'ZWCAD.Application' }
  return $null
}
function Get-UninstallEntries {
  Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                   'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                   'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
}
function Get-AutocadVersions {
  $v = Get-UninstallEntries | Where-Object { $_.DisplayName -match '^AutoCAD (20\d\d)( -|$)' } | ForEach-Object { $Matches[1] }
  return @($v | Sort-Object -Unique)
}
function Find-AdsDir([string]$ver, [string]$mustHave) {
  $cands = @()
  foreach ($b in @("$env:ProgramFiles\BZS", "${env:ProgramFiles(x86)}\BZS")) {
    if ($b -and (Test-Path $b)) {
      $cands += Get-ChildItem $b -Directory | Where-Object { $_.Name -match "ADSCivil.* $ver .*ZWCAD" } | ForEach-Object { $_.FullName }
    }
  }
  $cands += Get-UninstallEntries | Where-Object { $_.DisplayName -match 'ADSCivil' -and $_.DisplayName -match " $ver" -and $_.InstallLocation } |
    ForEach-Object { $_.InstallLocation }
  foreach ($d in $cands) { if ($d -and (Test-Path (Join-Path $d $mustHave))) { return $d.TrimEnd('\') } }
  return $null
}

# Returns @{ zwcad=@{ok;info}; autocad=...; adscivil=@{ok;info;dir2027;dir2026} }
function Get-CadStatus {
  $s = @{}
  $zw = Get-ZwcadProgId
  $s.zwcad = @{ ok = [bool]$zw; info = $(if ($zw) { $zw -replace '^ZWCAD\.Application\.?', 'ZWCAD ' } else { 'chưa cài ZWCAD' }) }
  $ac = Get-AutocadVersions
  $hasAc = Test-Path 'Registry::HKEY_CLASSES_ROOT\AutoCAD.Application'
  $s.autocad = @{ ok = $hasAc; info = $(if ($ac) { 'AutoCAD ' + ($ac -join ', ') } elseif ($hasAc) { 'AutoCAD' } else { 'chưa cài AutoCAD' }) }
  $d27 = Find-AdsDir '2027' 'AdsMcpServer.exe'
  $d26 = Find-AdsDir '2026' 'ZWCAD.lsp'
  $s.adscivil = @{ ok = [bool]$d27; dir2027 = $d27; dir2026 = $d26
                   info = $(if ($d27) { 'ADSCivil NW 2027' + $(if ($d26) { ' + 2026' } else { '' }) } elseif ($d26) { 'chỉ có 2026 - cần bản 2027' } else { 'chưa cài ADSCivil' }) }
  return $s
}

function Find-Codex {
  $cx = Find-Exe 'codex'
  if (-not $cx) {
    $pkg = Get-AppxPackage OpenAI.Codex -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg) { $cx = Join-Path $pkg.InstallLocation 'app\resources\codex.exe' }
  }
  if ($cx -and (Test-Path $cx)) { return $cx }
  return $null
}
function Get-ClaudeDesktopConfigs {
  $list = @()
  Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue |
    ForEach-Object { $list += Join-Path $_.FullName 'LocalCache\Roaming\Claude\claude_desktop_config.json' }
  if ((Test-Path (Join-Path $env:LOCALAPPDATA 'AnthropicClaude')) -or (Test-Path (Join-Path $env:APPDATA 'Claude'))) {
    $list += Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
  }
  return $list
}
function Get-ClientStatus {
  $s = @{}
  $s.claude     = @{ ok = (@(Get-ClaudeDesktopConfigs).Count -gt 0); hint = 'Cài Claude Desktop: claude.ai/download' }
  $s.claudecode = @{ ok = [bool](Find-Exe 'claude'); hint = 'Cài Claude Code: claude.com/claude-code' }
  $s.codex      = @{ ok = [bool](Find-Codex); hint = 'Cài app Codex (Microsoft Store), đăng nhập ChatGPT' }
  $s.gemini     = @{ ok = [bool](Find-Exe 'gemini'); hint = 'Chưa có - sẽ tự cài Gemini CLI khi Connect' }
  return $s
}

# Which of our servers each client has now: @{ codex=@('zwcad',...); ... }
function Get-Connections {
  $r = @{}
  foreach ($c in $script:ClientList) { $r[$c] = @() }
  $cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
  if (Test-Path $cfg) {
    $t = [IO.File]::ReadAllText($cfg)
    $r.codex = @($script:CadList | Where-Object { $t -match "(?m)^\[mcp_servers\.$_\]" })
  }
  $g = Read-Json (Join-Path $env:USERPROFILE '.gemini\settings.json')
  if ($g.PSObject.Properties['mcpServers']) { $r.gemini = @($script:CadList | Where-Object { $g.mcpServers.PSObject.Properties[$_] }) }
  foreach ($f in Get-ClaudeDesktopConfigs) {
    $j = Read-Json $f
    if ($j.PSObject.Properties['mcpServers']) { $r.claude = @($r.claude + @($script:CadList | Where-Object { $j.mcpServers.PSObject.Properties[$_] }) | Select-Object -Unique) }
  }
  try {
    $j = Read-Json (Join-Path $env:USERPROFILE '.claude.json')
    if ($j.PSObject.Properties['mcpServers']) { $r.claudecode = @($script:CadList | Where-Object { $j.mcpServers.PSObject.Properties[$_] }) }
  } catch {}
  return $r
}

# ======================= servers =======================
function Find-Python {
  Update-PathEnv
  $cands = @()
  $py = Find-Exe 'py'; if ($py) { $cands += , @($py, '-3') }
  $p = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch 'WindowsApps' } | Select-Object -First 1
  if ($p) { $cands += , @($p.Source) }
  Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe", "$env:ProgramFiles\Python3*\python.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | ForEach-Object { $cands += , @($_.FullName) }
  foreach ($c in $cands) {
    try {
      $pre = @($c | Select-Object -Skip 1)
      $v = & $c[0] @pre -c "import sys;print('%d.%d' % sys.version_info[:2])" 2>$null
      if ($LASTEXITCODE -eq 0 -and "$v" -match '^3\.(\d+)$' -and [int]$Matches[1] -ge 10) { return , $c }
    } catch {}
  }
  return $null
}

function Install-PythonEnv {
  $mark = Join-Path $script:AppHome 'venv\.ok'
  $req = Join-Path $script:Root 'server\requirements.txt'
  $want = [IO.File]::ReadAllText($req).Trim()
  if ((Test-Path $script:VenvPy) -and (Test-Path $mark) -and ([IO.File]::ReadAllText($mark).Trim() -eq $want)) { return }
  if (Test-Path $script:VenvPy) {
    Write-Log "  Cập nhật thư viện Python..."
    if ((Invoke-Exe $script:VenvPy @('-m', 'pip', 'install', '-q', '--disable-pip-version-check', '-r', $req)) -ne 0) { throw "Cài thư viện Python thất bại (kiểm tra Internet)." }
    [IO.File]::WriteAllText($mark, $want, $script:Utf8); return
  }
  $py = Find-Python
  if (-not $py) {
    Write-Log "  Máy chưa có Python 3.10+ (cần cho ZWCAD/AutoCAD)." 'warn'
    if (-not (Find-Exe 'winget')) { throw "Không có winget. Cài Python 3.12 từ python.org rồi bấm Connect lại." }
    if (-not (Confirm-User "Cài Python 3.12 (miễn phí, từ Microsoft winget) ngay bây giờ?")) { throw "Cần Python để chạy MCP cho ZWCAD/AutoCAD." }
    Write-Log "  Đang cài Python 3.12..."
    Invoke-Exe (Find-Exe 'winget') @('install', '--id', 'Python.Python.3.12', '-e', '--scope', 'user', '--accept-source-agreements', '--accept-package-agreements') | Out-Null
    $py = Find-Python
    if (-not $py) { throw "Cài Python chưa xong. Đóng công cụ, mở lại rồi bấm Connect." }
  }
  Write-Log "  Python: $($py -join ' ')"
  Write-Log "  Tạo môi trường Python riêng và cài thư viện (1-2 phút)..."
  $pre = @($py | Select-Object -Skip 1)
  if ((Invoke-Exe $py[0] ($pre + @('-m', 'venv', (Join-Path $script:AppHome 'venv'))) -Quiet) -ne 0) { throw "Tạo môi trường Python thất bại." }
  if ((Invoke-Exe $script:VenvPy @('-m', 'pip', 'install', '-q', '--disable-pip-version-check', '-r', $req)) -ne 0) { throw "Cài thư viện Python thất bại (kiểm tra Internet)." }
  [IO.File]::WriteAllText($mark, $want, $script:Utf8)
}

# Copies the Steve CAD MCP server (server\ of this tool) to %LOCALAPPDATA%\SteveCADConnect\server.
function Install-Server {
  Install-PythonEnv
  $src = Join-Path $script:Root 'server'
  if ((Resolve-Path $src).Path.TrimEnd('\') -ne $script:ServerDir) {
    if (Test-Path $script:ServerDir) { Remove-Item $script:ServerDir -Recurse -Force }
    New-Item -ItemType Directory -Force $script:ServerDir | Out-Null
    Get-ChildItem $src -Force | Where-Object { $_.Name -ne '__pycache__' } | Copy-Item -Destination $script:ServerDir -Recurse -Force
    Get-ChildItem $script:ServerDir -Recurse -Directory -Filter '__pycache__' | Remove-Item -Recurse -Force
  }
  Write-Log "  Steve CAD MCP server sẵn sàng."
}

# @{ command; args; cwd } for one of our MCP servers
function Get-ServerSpec([string]$cad) {
  if ($cad -eq 'adscivil') {
    $d = Find-AdsDir '2027' 'AdsMcpServer.exe'
    if (-not $d) { throw "Không thấy ADSCivil NW 2027 (AdsMcpServer.exe)." }
    return @{ command = (Join-Path $d 'AdsMcpServer.exe'); args = @(); cwd = $d }
  }
  $a = @((Join-Path $script:ServerDir 'run.py'), '--cad', $cad)
  if ($cad -eq 'zwcad') { $pid0 = Get-ZwcadProgId; if ($pid0) { $a += @('--progid', $pid0) } }
  if (Get-Setting 'AllowScript' $false) { $a += '--allow-script' }
  return @{ command = $script:VenvPy; args = $a; cwd = $script:ServerDir }
}

# ======================= clients =======================
function Add-ToCodex([string]$name, $spec) {
  $cx = Find-Codex; if (-not $cx) { throw "Không thấy Codex." }
  $cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
  Backup-File $cfg
  Invoke-Exe $cx @('mcp', 'remove', $name) -Quiet | Out-Null
  if ((Invoke-Exe $cx (@('mcp', 'add', $name, '--', $spec.command) + $spec.args) -Quiet) -ne 0) { throw "codex mcp add $name thất bại." }
  # the Codex desktop app needs cwd, otherwise: "The directory name is invalid (os error 267)"
  $text = [IO.File]::ReadAllText($cfg)
  $rx = "(?m)^(\[mcp_servers\.$name\]\r?\n(?:(?!\[)[^\r\n]*\r?\n)*?command\s*=\s*[^\r\n]*\r?\n)"
  if ($text -notmatch "(?ms)^\[mcp_servers\.$name\][^\[]*?^cwd\s*=") {
    $text = [regex]::Replace($text, $rx, { param($m) $m.Value + "cwd = '$($spec.cwd)'`nstartup_timeout_sec = 60`n" }, 1)
    [IO.File]::WriteAllText($cfg, $text, $script:Utf8)
  }
}
function Remove-FromCodex([string]$name) {
  $cx = Find-Codex; if (-not $cx) { return }
  Backup-File (Join-Path $env:USERPROFILE '.codex\config.toml')
  Invoke-Exe $cx @('mcp', 'remove', $name) -Quiet | Out-Null
}

function Add-ToGemini([string]$name, $spec) {
  $gdir = Join-Path $env:USERPROFILE '.gemini'
  New-Item -ItemType Directory -Force $gdir | Out-Null
  $sf = Join-Path $gdir 'settings.json'
  Backup-File $sf
  $s = Read-Json $sf
  if (-not $s.PSObject.Properties['mcpServers']) { Set-Prop $s 'mcpServers' (New-Object PSObject) }
  Set-Prop $s.mcpServers $name ([pscustomobject]@{ command = $spec.command; args = @($spec.args); cwd = $spec.cwd; timeout = 600000; trust = $false })
  if (-not $s.PSObject.Properties['security']) { Set-Prop $s 'security' (New-Object PSObject) }
  if (-not $s.security.PSObject.Properties['auth']) { Set-Prop $s.security 'auth' (New-Object PSObject) }
  Set-Prop $s.security.auth 'selectedType' 'gemini-api-key'
  Write-Json $sf $s
  # Gemini disables MCP servers in untrusted folders
  $tf = Join-Path $gdir 'trustedFolders.json'
  $t = Read-Json $tf
  Set-Prop $t $script:Workspace 'TRUST_FOLDER'
  Write-Json $tf $t
}
function Remove-FromGemini([string]$name) {
  $sf = Join-Path $env:USERPROFILE '.gemini\settings.json'
  $s = Read-Json $sf
  if ($s.PSObject.Properties['mcpServers'] -and $s.mcpServers.PSObject.Properties[$name]) {
    Backup-File $sf; $s.mcpServers.PSObject.Properties.Remove($name); Write-Json $sf $s
  }
}

function Add-ToClaudeDesktop([string]$name, $spec) {
  foreach ($cf in Get-ClaudeDesktopConfigs) {
    New-Item -ItemType Directory -Force (Split-Path $cf) | Out-Null
    Backup-File $cf
    $s = Read-Json $cf
    if (-not $s.PSObject.Properties['mcpServers']) { Set-Prop $s 'mcpServers' (New-Object PSObject) }
    Set-Prop $s.mcpServers $name ([pscustomobject]@{ command = $spec.command; args = @($spec.args) })
    Write-Json $cf $s
  }
}
function Remove-FromClaudeDesktop([string]$name) {
  foreach ($cf in Get-ClaudeDesktopConfigs) {
    $s = Read-Json $cf
    if ($s.PSObject.Properties['mcpServers'] -and $s.mcpServers.PSObject.Properties[$name]) {
      Backup-File $cf; $s.mcpServers.PSObject.Properties.Remove($name); Write-Json $cf $s
    }
  }
}

function Add-ToClaudeCode([string]$name, $spec) {
  $cl = Find-Exe 'claude'; if (-not $cl) { throw "Không thấy Claude Code." }
  Invoke-Exe $cl @('mcp', 'remove', '-s', 'user', $name) -Quiet | Out-Null
  if ((Invoke-Exe $cl (@('mcp', 'add', '-s', 'user', $name, '--', $spec.command) + $spec.args) -Quiet) -ne 0) { throw "claude mcp add $name thất bại." }
}
function Remove-FromClaudeCode([string]$name) {
  $cl = Find-Exe 'claude'; if (-not $cl) { return }
  Invoke-Exe $cl @('mcp', 'remove', '-s', 'user', $name) -Quiet | Out-Null
}

function Install-GeminiCli {
  if (Find-Exe 'gemini') { return }
  if (-not (Confirm-User "Máy chưa có Gemini CLI. Cài Gemini CLI (và Node.js nếu thiếu) ngay bây giờ?")) { throw "Bỏ qua Gemini." }
  if (-not (Find-Exe 'npm.cmd')) {
    $wg = Find-Exe 'winget'; if (-not $wg) { throw "Không có winget. Cài Node.js LTS từ nodejs.org rồi thử lại." }
    Write-Log "  Đang cài Node.js..."
    Invoke-Exe $wg @('install', '--id', 'OpenJS.NodeJS.LTS', '-e', '--accept-source-agreements', '--accept-package-agreements') | Out-Null
  }
  $npm = Find-Exe 'npm.cmd'; if (-not $npm) { throw "Cài Node.js chưa xong. Đóng công cụ, mở lại rồi thử." }
  Write-Log "  Đang cài Gemini CLI..."
  Invoke-Exe $npm @('install', '-g', '@google/gemini-cli') | Out-Null
  if (-not (Find-Exe 'gemini')) { throw "Cài Gemini CLI chưa xong. Đóng công cụ, mở lại rồi thử." }
}

function Save-GeminiKey([string]$key) {
  if (-not $key -or -not $key.Trim()) { return }
  New-Item -ItemType Directory -Force $script:Workspace | Out-Null
  [IO.File]::WriteAllText((Join-Path $script:Workspace '.env'), "GEMINI_API_KEY=$($key.Trim())`r`n", $script:Utf8)
  Write-Log "  Đã lưu Gemini API key vào $script:Workspace\.env"
}
function Test-GeminiKey { return ((Test-Path (Join-Path $script:Workspace '.env')) -or [bool]$env:GEMINI_API_KEY) }

# ======================= workspace (instructions for the AI) =======================
function Update-Workspace {
  New-Item -ItemType Directory -Force $script:Workspace | Out-Null
  $conn = Get-Connections
  $cads = @($script:ClientList | ForEach-Object { $conn[$_] } | Select-Object -Unique)
  $txt = [IO.File]::ReadAllText((Join-Path $script:Root 'templates\AGENTS.base.md'))
  foreach ($c in $script:CadList) {
    if ($cads -contains $c) { $txt += "`r`n" + [IO.File]::ReadAllText((Join-Path $script:Root "CAD\$($script:CadLabel[$c])\AGENTS.part.md")) }
  }
  foreach ($n in 'AGENTS.md', 'GEMINI.md', 'CLAUDE.md') { [IO.File]::WriteAllText((Join-Path $script:Workspace $n), $txt, $script:Utf8) }
  # skills (server\skills\<name>\SKILL.md): native Claude Code skills in the workspace; other AIs read them via get_skill
  $sk = Join-Path $script:Root 'server\skills'
  if (Test-Path $sk) {
    $dst = Join-Path $script:Workspace '.claude\skills'
    New-Item -ItemType Directory -Force $dst | Out-Null
    Get-ChildItem $sk -Directory | ForEach-Object { Copy-Item $_.FullName $dst -Recurse -Force }
  }
  Copy-Item (Join-Path $script:Root 'templates\Mo Gemini.cmd') $script:Workspace -Force
}

# ======================= ADSCivil 2026 auto-load =======================
function Set-Ads2026Autoload([switch]$Remove) {
  $st = (Get-CadStatus).adscivil
  if (-not $st.dir2026) { Write-Log "  Không có ADSCivil 2026, bỏ qua." ; return }
  if (-not $Remove -and -not $st.dir2027) { throw "Cần ADSCivil 2027 để chép trợ lý AI sang 2026." }
  $script2026 = Join-Path $script:Root 'CAD\ADSCivil\install-2026-autoload.ps1'
  $src = if ($st.dir2027) { $st.dir2027 } else { $st.dir2026 }
  $writable = $true
  try { $t = Join-Path $st.dir2026 "__w$PID.tmp"; [IO.File]::WriteAllText($t, 'x'); Remove-Item $t } catch { $writable = $false }
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script2026, '-Source', $src, '-Target', $st.dir2026)
  if ($Remove) { $a += '-Uninstall' }
  if ($writable) {
    $code = Invoke-Exe (Join-Path $PSHOME 'powershell.exe') $a
  } else {
    Write-Log "  Cần quyền admin để ghi vào $($st.dir2026) - Windows sẽ hỏi xác nhận..."
    $q = $a | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }
    $p = Start-Process powershell -Verb RunAs -ArgumentList ($q + '-PauseAtEnd') -Wait -PassThru
    $code = $p.ExitCode
  }
  if ($code -ne 0) { throw "Cài/gỡ tự nạp ADSCivil 2026 báo lỗi (mã $code)." }
}
function Test-Ads2026Autoload {
  $d = (Get-CadStatus).adscivil.dir2026
  if (-not $d) { return $false }
  $lsp = Join-Path $d 'ZWCAD.lsp'
  return ((Test-Path $lsp) -and ([IO.File]::ReadAllText($lsp).Contains('(defun ads-ai-autoload')))
}

# ======================= the tool itself =======================
function New-AppIcon {
  Add-Type -AssemblyName System.Drawing
  $bmp = New-Object Drawing.Bitmap 64, 64
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.Clear([Drawing.Color]::Transparent)
  $path = New-Object Drawing.Drawing2D.GraphicsPath
  $r = 14; $path.AddArc(0, 0, $r, $r, 180, 90); $path.AddArc(63 - $r, 0, $r, $r, 270, 90); $path.AddArc(63 - $r, 63 - $r, $r, $r, 0, 90); $path.AddArc(0, 63 - $r, $r, $r, 90, 90); $path.CloseFigure()
  $g.FillPath((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 16, 94, 168))), $path)
  $f = New-Object Drawing.Font 'Segoe UI', 25, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $g.DrawString('S', $f, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF 0, 2, 40, 40), $sf)
  $f2 = New-Object Drawing.Font 'Segoe UI', 17, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
  $g.DrawString('AI', $f2, (New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 255, 196, 0))), (New-Object Drawing.RectangleF 22, 26, 42, 36), $sf)
  $g.Dispose()
  return [Drawing.Icon]::FromHandle($bmp.GetHicon())
}

function Install-Self {
  New-Item -ItemType Directory -Force $script:AppHome | Out-Null
  $same = ((Resolve-Path $script:Root).Path.TrimEnd('\') -eq $script:ToolDir)
  if (-not $same) {
    if (Test-Path $script:ToolDir) { Remove-Item $script:ToolDir -Recurse -Force }
    New-Item -ItemType Directory -Force $script:ToolDir | Out-Null
    foreach ($i in 'app', 'CAD', 'server', 'templates', 'VERSION', 'README.md', 'Uninstall.cmd', 'Steve CAD-AI Connect.cmd') {
      $p = Join-Path $script:Root $i
      if (Test-Path $p) { Copy-Item $p $script:ToolDir -Recurse -Force }
    }
  }
  $ico = Join-Path $script:AppHome 'app.ico'
  try { $icon = New-AppIcon; $fs = [IO.File]::Create($ico); $icon.Save($fs); $fs.Close() } catch {}
  $ps1 = Join-Path $script:ToolDir 'app\SteveCADConnect.ps1'
  $sh = New-Object -ComObject WScript.Shell
  $lnks = @((Join-Path ([Environment]::GetFolderPath('Desktop')) "$($script:AppName).lnk"),
            (Join-Path ([Environment]::GetFolderPath('Programs')) "$($script:AppName).lnk"))
  foreach ($l in $lnks) {
    $s = $sh.CreateShortcut($l)
    $s.TargetPath = Join-Path $PSHOME 'powershell.exe'
    $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$ps1`""
    $s.WorkingDirectory = $script:ToolDir
    $s.Description = 'Kết nối ZWCAD, AutoCAD, ADSCivil với Claude, ChatGPT, Gemini'
    if (Test-Path $ico) { $s.IconLocation = $ico }
    $s.Save()
  }
  if (Test-GeminiKey) {
    $gl = $sh.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Gemini CAD AI.lnk'))
    $gl.TargetPath = Join-Path $script:Workspace 'Mo Gemini.cmd'; $gl.WorkingDirectory = $script:Workspace; $gl.Save()
  }
  # Settings > Apps entry, so it can be removed like any program
  $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($script:AppId)"
  New-Item $k -Force | Out-Null
  $vals = @{ DisplayName = $script:AppName; DisplayVersion = ($script:Version -replace '^v', ''); Publisher = $script:Author;
             Contact = $script:Author; HelpTelephone = $script:Phone; HelpLink = 'https://github.com/steve-trantn/MCP-CAD-ADSCivil';
             UninstallString = "`"$(Join-Path $script:ToolDir 'Uninstall.cmd')`""; InstallLocation = $script:AppHome;
             DisplayIcon = $ico; URLInfoAbout = 'https://github.com/steve-trantn/MCP-CAD-ADSCivil' }
  foreach ($n in $vals.Keys) { Set-ItemProperty $k $n $vals[$n] }
  Set-ItemProperty $k NoModify 1 -Type DWord; Set-ItemProperty $k NoRepair 1 -Type DWord
}

# Clean up the earlier separate ZWCAD-MCP package once nothing points to it any more.
function Remove-OldInstalls {
  # v1 packages: reuse their Gemini key, drop their desktop shortcuts
  foreach ($w in 'ADSCivil-Gemini', 'ZWCAD-AI') {
    $envOld = Join-Path $env:USERPROFILE "$w\.env"
    if ((Test-Path $envOld) -and -not (Test-Path (Join-Path $script:Workspace '.env'))) {
      New-Item -ItemType Directory -Force $script:Workspace | Out-Null
      Copy-Item $envOld $script:Workspace
    }
  }
  foreach ($l in 'Gemini ADSCivil.lnk', 'Gemini ZWCAD.lnk') { Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) $l) -Force -ErrorAction SilentlyContinue }
  # v2 used the third-party CAD-MCP server; v3 has its own
  $cadmcp = Join-Path $script:AppHome 'cadmcp'
  if (Test-Path $cadmcp) {
    $files0 = @((Join-Path $env:USERPROFILE '.codex\config.toml'), (Join-Path $env:USERPROFILE '.gemini\settings.json'), (Join-Path $env:USERPROFILE '.claude.json')) + @(Get-ClaudeDesktopConfigs)
    $used = $false
    foreach ($f in $files0) { if ((Test-Path $f) -and ([IO.File]::ReadAllText($f) -match 'SteveCADConnect\\{1,2}cadmcp')) { $used = $true } }
    if (-not $used) { Remove-Item $cadmcp -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "  Đã dọn server CAD-MCP cũ (v2)." }
  }
  $old = Join-Path $env:LOCALAPPDATA 'ZWCAD-MCP'
  if (-not (Test-Path $old)) { return }
  $files = @((Join-Path $env:USERPROFILE '.codex\config.toml'), (Join-Path $env:USERPROFILE '.gemini\settings.json'), (Join-Path $env:USERPROFILE '.claude.json')) + @(Get-ClaudeDesktopConfigs)
  foreach ($f in $files) { if ((Test-Path $f) -and ([IO.File]::ReadAllText($f) -match 'AppData\\{1,2}Local\\{1,2}ZWCAD-MCP')) { return } }
  Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Gemini ZWCAD.lnk') -Force -ErrorAction SilentlyContinue
  Write-Log "  Đã dọn bản ZWCAD-MCP cũ."
}

# v2 -> v3: AI assistants that still point at the old CAD-MCP copy are switched to the new server.
function Update-OldServerRefs {
  $files = @{ codex = @(Join-Path $env:USERPROFILE '.codex\config.toml'); gemini = @(Join-Path $env:USERPROFILE '.gemini\settings.json');
              claudecode = @(Join-Path $env:USERPROFILE '.claude.json'); claude = @(Get-ClaudeDesktopConfigs) }
  $conn = Get-Connections
  foreach ($cl in $script:ClientList) {
    $old = $false
    foreach ($f in $files[$cl]) { if ($f -and (Test-Path $f) -and ([IO.File]::ReadAllText($f) -match 'SteveCADConnect\\{1,2}cadmcp')) { $old = $true } }
    if (-not $old) { continue }
    foreach ($c in @('zwcad', 'autocad')) {
      if ($conn[$cl] -notcontains $c) { continue }
      try {
        Install-Server
        $spec = Get-ServerSpec $c
        switch ($cl) {
          'codex'      { Add-ToCodex $c $spec }
          'gemini'     { Add-ToGemini $c $spec }
          'claude'     { Add-ToClaudeDesktop $c $spec }
          'claudecode' { Add-ToClaudeCode $c $spec }
        }
        Write-Log "  Nâng cấp $($script:ClientLabel[$cl])/$c lên server mới." 'ok'
      } catch { Write-Log "  Lỗi nâng cấp $($script:ClientLabel[$cl])/$c : $($_.Exception.Message)" 'error' }
    }
  }
}

# ======================= main actions =======================
function Invoke-Connect([string[]]$Cads, [string[]]$Clients, [bool]$Ads2026 = $false, [string]$GeminiKey = '') {
  if (-not $Cads) { throw "Chưa chọn phần mềm CAD nào." }
  if (-not $Clients) { throw "Chưa chọn trợ lý AI nào." }
  Write-Log "== CONNECT: $(($Cads | ForEach-Object { $script:CadLabel[$_] }) -join ', ')  ->  $(($Clients | ForEach-Object { $script:ClientLabel[$_] }) -join ', ')" 'title'
  $specs = @{}
  foreach ($c in $Cads) {
    Write-Log "[$($script:CadLabel[$c])] chuẩn bị MCP server..."
    if ($c -ne 'adscivil') { Install-Server }
    $specs[$c] = Get-ServerSpec $c
  }
  $ok = 0; $fail = 0
  foreach ($cl in $Clients) {
    Write-Log "[$($script:ClientLabel[$cl])]"
    try {
      if ($cl -eq 'gemini') { Install-GeminiCli; Save-GeminiKey $GeminiKey }
      foreach ($c in $Cads) {
        switch ($cl) {
          'codex'      { Add-ToCodex $c $specs[$c] }
          'gemini'     { Add-ToGemini $c $specs[$c] }
          'claude'     { Add-ToClaudeDesktop $c $specs[$c] }
          'claudecode' { Add-ToClaudeCode $c $specs[$c] }
        }
        Write-Log "  + $c" 'ok'
      }
      if ($cl -eq 'gemini' -and -not (Test-GeminiKey)) { Write-Log "  Chưa có Gemini API key: dán key vào ô Gemini rồi bấm Connect lại." 'warn' }
      $ok++
    } catch { Write-Log "  Lỗi: $($_.Exception.Message)" 'error'; $fail++ }
  }
  if ($Cads -contains 'adscivil' -and $Ads2026) {
    Write-Log "[ADSCivil 2026] tự nạp trợ lý ADSAI..."
    try { Set-Ads2026Autoload; Write-Log "  Đã bật tự nạp." 'ok' } catch { Write-Log "  Lỗi: $($_.Exception.Message)" 'error'; $fail++ }
  }
  Update-OldServerRefs
  Update-Workspace
  Install-Self
  Remove-OldInstalls
  Write-Log ""
  if ($fail -eq 0) { Write-Log "XONG. Khởi động lại trợ lý AI (thoát hẳn rồi mở lại) để nhận kết nối mới. Có thể đóng công cụ này." 'ok' }
  else { Write-Log "Xong, có $fail lỗi - xem các dòng đỏ ở trên. Cần hỗ trợ: $($script:Contact)" 'warn' }
  return ($fail -eq 0)
}

function Invoke-Disconnect([string[]]$Cads, [string[]]$Clients, [bool]$Ads2026 = $false) {
  Write-Log "== DISCONNECT: $(($Cads | ForEach-Object { $script:CadLabel[$_] }) -join ', ')  khỏi  $(($Clients | ForEach-Object { $script:ClientLabel[$_] }) -join ', ')" 'title'
  foreach ($cl in $Clients) {
    foreach ($c in $Cads) {
      try {
        switch ($cl) {
          'codex'      { Remove-FromCodex $c }
          'gemini'     { Remove-FromGemini $c }
          'claude'     { Remove-FromClaudeDesktop $c }
          'claudecode' { Remove-FromClaudeCode $c }
        }
      } catch { Write-Log "  Lỗi $($script:ClientLabel[$cl])/$c : $($_.Exception.Message)" 'error' }
    }
    Write-Log "  - $($script:ClientLabel[$cl])" 'ok'
  }
  if ($Cads -contains 'adscivil' -and $Ads2026 -and (Test-Ads2026Autoload)) {
    try { Set-Ads2026Autoload -Remove; Write-Log "  Đã tắt tự nạp ADSCivil 2026." 'ok' } catch { Write-Log "  Lỗi: $($_.Exception.Message)" 'error' }
  }
  if (Test-Path $script:Workspace) { Update-Workspace }
  Write-Log "XONG. Khởi động lại trợ lý AI để áp dụng." 'ok'
}

function Invoke-Uninstall {
  Write-Log "== UNINSTALL: gỡ toàn bộ $($script:AppName)" 'title'
  Invoke-Disconnect $script:CadList $script:ClientList $true
  $desk = [Environment]::GetFolderPath('Desktop'); $progs = [Environment]::GetFolderPath('Programs')
  foreach ($l in "$desk\$($script:AppName).lnk", "$progs\$($script:AppName).lnk", "$desk\Gemini CAD AI.lnk") { Remove-Item $l -Force -ErrorAction SilentlyContinue }
  Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($script:AppId)" -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path $script:AppHome) { Remove-Item $script:AppHome -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "  Đã xóa $script:AppHome" }
  Remove-OldInstalls
  Write-Log "  Thư mục $script:Workspace (có .env chứa API key) được giữ lại, xóa tay nếu muốn."
  Write-Log "ĐÃ GỠ XONG." 'ok'
}

# Talks MCP over stdio to one server: handshake, list tools, optionally call one tool.
function Test-McpServer($spec, [string]$call = '', [int]$timeoutSec = 60) {
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $spec.command
  $psi.Arguments = ($spec.args | ForEach-Object { "`"$_`"" }) -join ' '
  $psi.WorkingDirectory = $spec.cwd
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
  # .NET Framework writes Console.InputEncoding's preamble to the child's stdin at start; with the
  # system UTF-8 code page that is a BOM, which breaks the first JSON-RPC message. Use UTF-8 without BOM.
  $oldIn = $null
  try { $oldIn = [Console]::InputEncoding; [Console]::InputEncoding = $script:Utf8 } catch {}
  try { $p = [Diagnostics.Process]::Start($psi) } finally { if ($oldIn) { try { [Console]::InputEncoding = $oldIn } catch {} } }
  $null = $p.StandardError.ReadToEndAsync()
  $w = New-Object IO.StreamWriter($p.StandardInput.BaseStream, $script:Utf8)
  $rd = New-Object IO.StreamReader($p.StandardOutput.BaseStream, $script:Utf8)
  $send = { param($o) $w.WriteLine(($o | ConvertTo-Json -Depth 20 -Compress)); $w.Flush() }
  # wait for the response with this id; skip notifications and log messages
  $recv = {
    param($id)
    $end = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $end) {
      $t = $rd.ReadLineAsync()
      while (-not $t.IsCompleted -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 100; Invoke-UiPump }
      if (-not $t.IsCompleted -or $null -eq $t.Result) { break }
      try { $o = $t.Result | ConvertFrom-Json } catch { continue }
      if ($o.PSObject.Properties['id'] -and $o.id -eq $id) { return $o }
    }
    throw "server không trả lời"
  }
  try {
    & $send @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{ protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'steve-cad-ai-test'; version = '1' } } }
    $null = & $recv 1
    & $send @{ jsonrpc = '2.0'; method = 'notifications/initialized' }
    & $send @{ jsonrpc = '2.0'; id = 2; method = 'tools/list' }
    $tools = @((& $recv 2).result.tools)
    $res = @{ tools = $tools.Count; text = '' }
    if ($call) {
      & $send @{ jsonrpc = '2.0'; id = 3; method = 'tools/call'; params = @{ name = $call; arguments = @{} } }
      $o = & $recv 3
      $res.text = if ($o.error) { 'LỖI: ' + $o.error.message } else { (@($o.result.content) | ForEach-Object { $_.text }) -join ' ' }
    }
    return $res
  } finally {
    try { $w.Close() } catch {}
    $p.WaitForExit(2000) | Out-Null; if (-not $p.HasExited) { $p.Kill() }
  }
}

function Invoke-Test([string[]]$Cads) {
  Write-Log "== KIỂM TRA" 'title'
  foreach ($c in $Cads) {
    try {
      $spec = Get-ServerSpec $c
      if (-not (Test-Path $spec.command) -or ($spec.args -and -not (Test-Path $spec.args[0]))) { Write-Log "[$($script:CadLabel[$c])] chưa cài - bấm Connect trước." 'warn'; continue }
      $proc = @{ zwcad = 'ZWCAD'; adscivil = 'ZWCAD'; autocad = 'acad' }[$c]
      $running = [bool](Get-Process $proc -ErrorAction SilentlyContinue)
      $call = if (-not $running) { '' } elseif ($c -eq 'adscivil') { 'get_drawing_info' } else { 'info' }
      $r = Test-McpServer $spec $call
      Write-Log "[$($script:CadLabel[$c])] server chạy, $($r.tools) tool." 'ok'
      if (-not $running) { Write-Log "  $($script:CadLabel[$c]) chưa mở - mở phần mềm và một bản vẽ để thử đọc bản vẽ." 'warn' }
      elseif ($c -eq 'adscivil') { Write-Log ("  " + ($r.text -replace '\s+', ' ').Substring(0, [Math]::Min(220, ($r.text -replace '\s+', ' ').Length))) }
      else {
        try { $j = $r.text | ConvertFrom-Json } catch { $j = $null }
        if ($j -and $j.drawing) { Write-Log "  Đọc được bản vẽ $(Split-Path $j.drawing -Leaf): $($j.modelspace_objects) đối tượng, layer hiện hành '$($j.current_layer)', đơn vị $($j.units)." 'ok' }
        else { Write-Log "  Chưa đọc được bản vẽ: $($r.text)" 'warn' }
      }
    } catch { Write-Log "[$($script:CadLabel[$c])] lỗi: $($_.Exception.Message)" 'error' }
  }
}
