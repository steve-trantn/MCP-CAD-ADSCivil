<#
.SYNOPSIS
  Steve CAD-AI Connect - kết nối ZWCAD, AutoCAD, ADSCivil với Claude, ChatGPT (Codex), Gemini qua MCP.

.DESCRIPTION
  Không tham số: mở giao diện (tích chọn CAD + trợ lý AI, bấm Connect / Disconnect / Kiểm tra / Uninstall).
  Dòng lệnh (cho IT):
    -Connect | -Disconnect | -Test | -Uninstall
    -Cad zwcad,autocad,adscivil        (mặc định: những phần mềm có trên máy)
    -Client claude,claudecode,codex,gemini   (mặc định: những trợ lý có trên máy)
    -Ads2026                            (ADSCivil 2026 tự nạp trợ lý ADSAI)
    -GeminiKey <key>
#>
param(
  [switch]$Connect, [switch]$Disconnect, [switch]$Test, [switch]$Uninstall,
  [string[]]$Cad, [string[]]$Client, [switch]$Ads2026, [string]$GeminiKey = ''
)
. (Join-Path $PSScriptRoot 'core.ps1')
Get-ChildItem $script:Root -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

# ======================= command line =======================
if ($Connect -or $Disconnect -or $Test -or $Uninstall) {
  try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
  $script:LogSink = {
    param($m, $lvl)
    $col = @{ ok = 'Green'; warn = 'Yellow'; error = 'Red'; title = 'Cyan'; detail = 'DarkGray' }[$lvl]
    if ($col) { Write-Host $m -ForegroundColor $col } else { Write-Host $m }
  }
  $cs = Get-CadStatus; $ks = Get-ClientStatus
  if (-not $Cad)    { $Cad    = @($script:CadList | Where-Object { $cs[$_].ok }) }
  if (-not $Client) { $Client = @($script:ClientList | Where-Object { $ks[$_].ok }) }
  $Cad = @($Cad -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
  $Client = @($Client -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
  $code = 0
  try {
    if ($Uninstall)  { Invoke-Uninstall }
    elseif ($Disconnect) { Invoke-Disconnect $Cad $Client ([bool]$Ads2026) }
    elseif ($Connect) { if (-not (Invoke-Connect $Cad $Client ([bool]$Ads2026) $GeminiKey)) { $code = 1 } }
    if ($Test) { Invoke-Test $Cad }
  } catch { Write-Log "LỖI: $($_.Exception.Message)" 'error'; $code = 1 }
  exit $code
}

# ======================= GUI =======================
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:IsGui = $true

$blue  = [Drawing.Color]::FromArgb(16, 94, 168)
$gold  = [Drawing.Color]::FromArgb(255, 196, 0)
$fontN = New-Object Drawing.Font 'Segoe UI', 9.5
$fontB = New-Object Drawing.Font 'Segoe UI', 9.5, ([Drawing.FontStyle]::Bold)

$form = New-Object Windows.Forms.Form
$form.Text = "$($script:AppName) $($script:Version)"
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'; $form.MaximizeBox = $false
$form.ClientSize = New-Object Drawing.Size 640, 700
$form.Font = $fontN
$form.BackColor = [Drawing.Color]::White
try { $form.Icon = New-AppIcon } catch {}

# header
$head = New-Object Windows.Forms.Panel
$head.SetBounds(0, 0, 640, 74); $head.BackColor = $blue
$t1 = New-Object Windows.Forms.Label
$t1.Text = $script:AppName; $t1.ForeColor = [Drawing.Color]::White
$t1.Font = New-Object Drawing.Font 'Segoe UI', 17, ([Drawing.FontStyle]::Bold)
$t1.SetBounds(18, 8, 520, 34)
$t2 = New-Object Windows.Forms.Label
$t2.Text = 'Kết nối ZWCAD · AutoCAD · ADSCivil với Claude · ChatGPT · Gemini - một cú bấm'
$t2.ForeColor = $gold; $t2.SetBounds(20, 44, 600, 22)
$t3 = New-Object Windows.Forms.Label
$t3.Text = "Hỗ trợ: $($script:Contact)"; $t3.ForeColor = [Drawing.Color]::White; $t3.TextAlign = 'TopRight'
$t3.SetBounds(400, 16, 226, 20)
$head.Controls.AddRange(@($t1, $t2, $t3))
$form.Controls.Add($head)

function New-Check([string]$text, [int]$x, [int]$y, [int]$w = 170) {
  $c = New-Object Windows.Forms.CheckBox
  $c.Text = $text; $c.Font = $fontB; $c.SetBounds($x, $y, $w, 24)
  return $c
}
function New-Note([int]$x, [int]$y, [int]$w) {
  $l = New-Object Windows.Forms.Label
  $l.SetBounds($x, $y + 3, $w, 20); $l.ForeColor = [Drawing.Color]::DimGray
  return $l
}

# 1. CAD
$g1 = New-Object Windows.Forms.GroupBox
$g1.Text = '1. Phần mềm CAD'; $g1.Font = $fontB; $g1.SetBounds(14, 84, 612, 140)
$cadChk = @{}; $cadNote = @{}
$y = 24
foreach ($c in $script:CadList) {
  $cadChk[$c] = New-Check $script:CadLabel[$c] 16 $y
  $cadNote[$c] = New-Note 190 $y 410
  $cadNote[$c].Font = $fontN
  $g1.Controls.AddRange(@($cadChk[$c], $cadNote[$c])); $y += 28
}
$chk26 = New-Object Windows.Forms.CheckBox
$chk26.Text = 'ADSCivil 2026: tự nạp trợ lý ADSAI khi khởi động'; $chk26.Font = $fontN
$chk26.SetBounds(36, $y, 420, 24)
$g1.Controls.Add($chk26)
$form.Controls.Add($g1)

# 2. AI
$g2 = New-Object Windows.Forms.GroupBox
$g2.Text = '2. Trợ lý AI'; $g2.Font = $fontB; $g2.SetBounds(14, 230, 612, 172)
$cliChk = @{}; $cliNote = @{}
$y = 24
foreach ($c in $script:ClientList) {
  $cliChk[$c] = New-Check $script:ClientLabel[$c] 16 $y
  $cliNote[$c] = New-Note 190 $y 410
  $cliNote[$c].Font = $fontN
  $g2.Controls.AddRange(@($cliChk[$c], $cliNote[$c])); $y += 28
}
$lk = New-Object Windows.Forms.Label
$lk.Text = 'Gemini API key:'; $lk.Font = $fontN; $lk.SetBounds(16, ($y + 6), 110, 20)
$txtKey = New-Object Windows.Forms.TextBox
$txtKey.UseSystemPasswordChar = $true; $txtKey.Font = $fontN; $txtKey.SetBounds(128, ($y + 3), 300, 24)
$getKey = New-Object Windows.Forms.LinkLabel
$getKey.Text = 'Lấy key miễn phí'; $getKey.Font = $fontN; $getKey.SetBounds(438, ($y + 6), 160, 20)
$getKey.add_LinkClicked({ Start-Process 'https://aistudio.google.com/apikey' })
$g2.Controls.AddRange(@($lk, $txtKey, $getKey))
$form.Controls.Add($g2)

# buttons
function New-Btn([string]$text, [int]$x, [Drawing.Color]$back, [Drawing.Color]$fore) {
  $b = New-Object Windows.Forms.Button
  $b.Text = $text; $b.SetBounds($x, 412, 142, 40); $b.Font = $fontB
  $b.FlatStyle = 'Flat'; $b.BackColor = $back; $b.ForeColor = $fore
  $b.FlatAppearance.BorderColor = $blue
  return $b
}
$bConnect    = New-Btn 'Connect' 14 $blue ([Drawing.Color]::White)
$bDisconnect = New-Btn 'Disconnect' 170 ([Drawing.Color]::White) $blue
$bTest       = New-Btn 'Kiểm tra' 326 ([Drawing.Color]::White) $blue
$bUninstall  = New-Btn 'Uninstall' 484 ([Drawing.Color]::White) ([Drawing.Color]::Firebrick)
$bUninstall.FlatAppearance.BorderColor = [Drawing.Color]::Firebrick
$form.Controls.AddRange(@($bConnect, $bDisconnect, $bTest, $bUninstall))

# log
$log = New-Object Windows.Forms.RichTextBox
$log.SetBounds(14, 462, 612, 206); $log.ReadOnly = $true; $log.BackColor = [Drawing.Color]::FromArgb(248, 249, 251)
$log.Font = New-Object Drawing.Font 'Consolas', 9; $log.BorderStyle = 'FixedSingle'
$form.Controls.Add($log)

$foot = New-Object Windows.Forms.LinkLabel
$foot.Text = 'github.com/steve-trantn/MCP-CAD-ADSCivil'; $foot.SetBounds(14, 674, 400, 20)
$foot.add_LinkClicked({ Start-Process 'https://github.com/steve-trantn/MCP-CAD-ADSCivil' })
$ws = New-Object Windows.Forms.LinkLabel
$ws.Text = 'Mở thư mục làm việc AI'; $ws.TextAlign = 'TopRight'; $ws.SetBounds(426, 674, 200, 20)
$ws.add_LinkClicked({ New-Item -ItemType Directory -Force $script:Workspace | Out-Null; Start-Process explorer.exe $script:Workspace })
$form.Controls.AddRange(@($foot, $ws))

$script:LogSink = {
  param($m, $lvl)
  $col = @{ ok = [Drawing.Color]::ForestGreen; warn = [Drawing.Color]::DarkOrange; error = [Drawing.Color]::Firebrick
            title = $blue; detail = [Drawing.Color]::Gray }[$lvl]
  if (-not $col) { $col = [Drawing.Color]::Black }
  $log.SelectionStart = $log.TextLength; $log.SelectionLength = 0
  $log.SelectionColor = $col
  $log.AppendText($m + "`n")
  $log.ScrollToCaret()
  [System.Windows.Forms.Application]::DoEvents()
}
$script:ConfirmSink = {
  param($q)
  [Windows.Forms.MessageBox]::Show($form, $q, $script:AppName, 'YesNo', 'Question') -eq 'Yes'
}

function Update-View([switch]$First) {
  $cs = Get-CadStatus; $ks = Get-ClientStatus; $conn = Get-Connections
  foreach ($c in $script:CadList) {
    $cadChk[$c].Enabled = $cs[$c].ok
    $users = @($script:ClientList | Where-Object { $conn[$_] -contains $c } | ForEach-Object { $script:ClientLabel[$_] })
    $cadNote[$c].Text = $cs[$c].info + $(if ($users) { "   ·  đang nối $($users.Count) trợ lý AI" } else { '' })
    $cadNote[$c].ForeColor = $(if ($users) { [Drawing.Color]::ForestGreen } elseif ($cs[$c].ok) { [Drawing.Color]::DimGray } else { [Drawing.Color]::Silver })
    if ($First) { $cadChk[$c].Checked = $cs[$c].ok }
    if (-not $cs[$c].ok) { $cadChk[$c].Checked = $false }
  }
  $a = $cs.adscivil
  $chk26.Enabled = [bool]($a.dir2026 -and $a.dir2027) -and $cadChk.adscivil.Checked
  $on26 = Test-Ads2026Autoload
  $chk26.Text = 'ADSCivil 2026: tự nạp trợ lý ADSAI khi khởi động' + $(if ($on26) { '   (đang bật)' } elseif (-not $a.dir2026) { '   (không có bản 2026)' } else { '' })
  if ($First) { $chk26.Checked = $on26 -or [bool]($a.dir2026 -and $a.dir2027) }
  foreach ($c in $script:ClientList) {
    $mine = @($conn[$c])
    $cliChk[$c].Enabled = $ks[$c].ok -or $c -eq 'gemini'
    $cliNote[$c].Text = $(if (-not $ks[$c].ok) { $ks[$c].hint } elseif ($mine) { 'đang nối: ' + (($mine | ForEach-Object { $script:CadLabel[$_] }) -join ', ') } else { 'đã cài, chưa nối' })
    $cliNote[$c].ForeColor = $(if ($mine) { [Drawing.Color]::ForestGreen } elseif ($ks[$c].ok) { [Drawing.Color]::DimGray } else { [Drawing.Color]::DarkOrange })
    if ($First) { $cliChk[$c].Checked = $ks[$c].ok }
  }
  $txtKey.Enabled = $cliChk.gemini.Checked
  if (Test-GeminiKey) { $getKey.Text = 'đã có key (dán để thay)' }
}
$cadChk.adscivil.add_CheckedChanged({ $chk26.Enabled = $cadChk.adscivil.Checked -and $chk26.Text -notmatch 'không có' })
$cliChk.gemini.add_CheckedChanged({ $txtKey.Enabled = $cliChk.gemini.Checked })

function Get-Picked($map) { @($map.Keys | Where-Object { $map[$_].Checked -and $map[$_].Enabled } | Sort-Object { [array]::IndexOf(($script:CadList + $script:ClientList), $_) }) }
function Invoke-Busy([scriptblock]$job) {
  $all = @($bConnect, $bDisconnect, $bTest, $bUninstall)
  $all | ForEach-Object { $_.Enabled = $false }
  $form.Cursor = 'WaitCursor'
  try { & $job } catch { Write-Log "LỖI: $($_.Exception.Message)" 'error' }
  finally {
    $form.Cursor = 'Default'; $all | ForEach-Object { $_.Enabled = $true }
    try { Update-View } catch {}
  }
}

$bConnect.add_Click({
  Invoke-Busy {
    $k = $txtKey.Text; $txtKey.Text = ''
    Invoke-Connect (Get-Picked $cadChk) (Get-Picked $cliChk) ($chk26.Checked -and $chk26.Enabled) $k | Out-Null
  }
})
$bDisconnect.add_Click({
  $cads = Get-Picked $cadChk; $clis = Get-Picked $cliChk
  if (-not $cads -or -not $clis) { Write-Log "Chọn CAD và trợ lý AI muốn ngắt kết nối." 'warn'; return }
  Invoke-Busy { Invoke-Disconnect $cads $clis ($chk26.Checked -and $chk26.Enabled) }
})
$bTest.add_Click({
  $cads = Get-Picked $cadChk
  if (-not $cads) { Write-Log "Chọn ít nhất một phần mềm CAD." 'warn'; return }
  Invoke-Busy { Invoke-Test $cads }
})
$bUninstall.add_Click({
  $q = "Gỡ toàn bộ $($script:AppName)?`n`n- Ngắt ZWCAD, AutoCAD, ADSCivil khỏi mọi trợ lý AI`n- Tắt tự nạp ADSCivil 2026`n- Xóa server, shortcut và mục trong Settings > Apps`n`nThư mục làm việc (có API key) được giữ lại."
  if (-not (Confirm-User $q)) { return }
  Invoke-Busy { Invoke-Uninstall }
})

$form.add_Shown({
  Write-Log "Chào mừng! Tích chọn phần mềm CAD và trợ lý AI, rồi bấm Connect." 'title'
  Write-Log "Sau khi Connect có thể đóng công cụ; mở lại từ shortcut '$($script:AppName)' trên Desktop để Disconnect hoặc Uninstall."
  Write-Log ""
  try { Update-View -First } catch { Write-Log "Lỗi đọc trạng thái: $($_.Exception.Message)" 'error' }
  if ($env:STEVECAD_SNAPSHOT) {   # used to make README screenshots
    $bmp = New-Object Drawing.Bitmap $form.Width, $form.Height
    $form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle 0, 0, $form.Width, $form.Height))
    $bmp.Save($env:STEVECAD_SNAPSHOT, [Drawing.Imaging.ImageFormat]::Png); $form.Close()
  }
})
[void]$form.ShowDialog()
