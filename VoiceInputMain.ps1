# ============================================================
#  语音输入 - 主窗口 (App 首页)
# ============================================================
param([switch]$Test)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'common.ps1')

$settingsPs1 = Join-Path $script:ToolDir 'VoiceInputSettings.ps1'
$historyPath = Join-Path $script:ToolDir 'history.txt'

# ---- 窗体 ----
$form = New-Object System.Windows.Forms.Form
$form.Text = '语音输入'
$form.Size = New-Object System.Drawing.Size(360, 420)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$iconPath = Join-Path $script:ToolDir 'mic.ico'
if (Test-Path -LiteralPath $iconPath) {
    try { $form.Icon = New-Object System.Drawing.Icon($iconPath) } catch {}
}

# 标题
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = '🎙  语音输入'
$lblTitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 18)
$lblTitle.Size = New-Object System.Drawing.Size(310, 30)
$form.Controls.Add($lblTitle)

# 状态
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(22, 58)
$lblStatus.Size = New-Object System.Drawing.Size(310, 22)
$lblStatus.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$form.Controls.Add($lblStatus)

# 开启/关闭
$btnToggle = New-Object System.Windows.Forms.Button
$btnToggle.Location = New-Object System.Drawing.Point(22, 92)
$btnToggle.Size = New-Object System.Drawing.Size(316, 40)
$btnToggle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11)
$btnToggle.Add_Click({
    Toggle-VoiceService | Out-Null
    Refresh-State
})
$form.Controls.Add($btnToggle)

# 设置
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = '⚙ 设置…'
$btnSettings.Location = New-Object System.Drawing.Point(22, 140)
$btnSettings.Size = New-Object System.Drawing.Size(316, 38)
$btnSettings.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$btnSettings.Add_Click({
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$settingsPs1`"" | Out-Null } catch {}
})
$form.Controls.Add($btnSettings)

# 历史
$btnHistory = New-Object System.Windows.Forms.Button
$btnHistory.Text = '📋 听写历史'
$btnHistory.Location = New-Object System.Drawing.Point(22, 185)
$btnHistory.Size = New-Object System.Drawing.Size(316, 38)
$btnHistory.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$btnHistory.Add_Click({
    if (Test-Path -LiteralPath $historyPath) { Start-Process notepad.exe -ArgumentList "`"$historyPath`"" }
})
$form.Controls.Add($btnHistory)

# 开机自启
$chkAuto = New-Object System.Windows.Forms.CheckBox
$chkAuto.Text = '开机自动启动'
$chkAuto.Location = New-Object System.Drawing.Point(24, 238)
$chkAuto.Size = New-Object System.Drawing.Size(200, 22)
$chkAuto.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$chkAuto.Checked = Get-AutostartEnabled
$chkAuto.Add_Click({ Set-AutostartEnabled $chkAuto.Checked })
$form.Controls.Add($chkAuto)

# 退出
$btnQuit = New-Object System.Windows.Forms.Button
$btnQuit.Text = '退出（同时关闭语音服务）'
$btnQuit.Location = New-Object System.Drawing.Point(22, 272)
$btnQuit.Size = New-Object System.Drawing.Size(316, 40)
$btnQuit.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$btnQuit.Add_Click({
    Stop-VoiceService
    $form.Close()
})
$form.Controls.Add($btnQuit)

# 底部提示
$lblTip = New-Object System.Windows.Forms.Label
$lblTip.Text = '提示：托盘图标可随时开关；按住快捷键说话即可输入'
$lblTip.Location = New-Object System.Drawing.Point(22, 325)
$lblTip.Size = New-Object System.Drawing.Size(316, 40)
$lblTip.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$lblTip.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblTip)

# 状态刷新
function Refresh-State {
    $st = Get-VoiceStatus
    if ($st -eq 'running') {
        $lblStatus.Text = '● 运行中  （按住快捷键说话）'
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
        $btnToggle.Text = '关闭语音输入'
    } else {
        $lblStatus.Text = '○ 已停止'
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
        $btnToggle.Text = '开启语音输入'
    }
}
Refresh-State

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Refresh-State })
$timer.Start()

if ($Test) {
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 2000
    $t.Add_Tick({ $form.Close() })
    $t.Start()
}
$null = $form.ShowDialog()
$form.Dispose()
exit 0