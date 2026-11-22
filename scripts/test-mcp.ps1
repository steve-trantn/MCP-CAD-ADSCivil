<#
.SYNOPSIS
  Talks to AdsMcpServer.exe over stdio: MCP handshake, tool list, then optional tool calls.
  ADSCivil (ZWCAD) must be running for CAD tools; knowledge tools work without CAD.

.EXAMPLE
  .\test-mcp.ps1
  .\test-mcp.ps1 -Calls get_drawing_info, list_layers
  .\test-mcp.ps1 -Calls 'standards_search|{"query":"ban kinh duong cong nam"}'
  .\test-mcp.ps1 -Pipe '\\.\pipe\adscivil-mcp-12345'   # pick one ZWCAD when several run
#>
param(
  [string]$Exe = "C:\Program Files\BZS\ADSCivil NW 2027 For ZWCAD 2026\AdsMcpServer.exe",
  [string]$Pipe = "",
  [string[]]$Calls = @('get_drawing_info')
)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $Exe
$psi.WorkingDirectory = Split-Path $Exe
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
if ($Pipe) { $psi.EnvironmentVariables["ADSCIVIL_MCP_PIPE"] = $Pipe }
$p = [System.Diagnostics.Process]::Start($psi)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$w = New-Object System.IO.StreamWriter($p.StandardInput.BaseStream, $utf8)
$r = New-Object System.IO.StreamReader($p.StandardOutput.BaseStream, $utf8)
function Send($obj) { $w.WriteLine(($obj | ConvertTo-Json -Depth 20 -Compress)); $w.Flush() }
function Recv() { $t = $r.ReadLineAsync(); if ($t.Wait(60000)) { return $t.Result } else { return "<timeout>" } }

Send @{jsonrpc="2.0"; id=1; method="initialize"; params=@{protocolVersion="2025-06-18"; capabilities=@{}; clientInfo=@{name="adscivil-test"; version="1"}}}
$init = Recv | ConvertFrom-Json
"Server: {0} {1}" -f $init.result.serverInfo.name, $init.result.serverInfo.version
Send @{jsonrpc="2.0"; method="notifications/initialized"}
Send @{jsonrpc="2.0"; id=2; method="tools/list"}
$tools = (Recv | ConvertFrom-Json).result.tools
"Tools: {0}" -f $tools.Count
$tools | ForEach-Object { "  - " + $_.name }

$id = 3
foreach ($c in $Calls) {
  $name, $json = $c -split '\|', 2
  if (-not $json) { $json = '{}' }
  Send @{jsonrpc="2.0"; id=$id; method="tools/call"; params=@{name=$name; arguments=($json | ConvertFrom-Json)}}
  $resp = Recv
  ""
  "=== $name"
  try {
    $o = $resp | ConvertFrom-Json
    if ($o.error) { "ERROR: " + $o.error.message } else { $o.result.content | ForEach-Object { $_.text } }
  } catch { $resp }
  $id++
}
$w.Close(); $p.WaitForExit(3000) | Out-Null; if (-not $p.HasExited) { $p.Kill() }
