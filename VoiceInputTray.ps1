# ============================================================
#  语音输入 - 托盘控制 (v4)
# ============================================================
param([switch]$Test)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$mutex = New-Object System.Threading.Mutex($false, 'VoiceInputTrayMutex')
if (-not $mutex.WaitOne(0)) { exit 0 }

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'common.ps1')

$settingsPs1 = Join-Path $script:ToolDir 'VoiceInputSettings.ps1'
$mainVbs = Join-Path $script:ToolDir 'VoiceInputMain.vbs'
$historyPath = Join-Path $script:ToolDir 'history.txt'
$workDir = Join-Path $env:TEMP 'voice-input'
$logPath = Join-Path $script:ToolDir 'tray.log'

function Log($msg) {
    try { [System.IO.File]::AppendAllText($logPath, (Get-Date -Format 'HH:mm:ss.fff') + ' ' + $msg + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false))) } catch {}
}

function New-MicIcon([bool]$active = $true) {
    $size = 16
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $s = $size / 16.0
    $col = if ($active) { [System.Drawing.Color]::FromArgb(0, 120, 215) } else { [System.Drawing.Color]::FromArgb(150, 150, 150) }
    $brush = New-Object System.Drawing.SolidBrush($col)
    $pen = New-Object System.Drawing.Pen($col, [Math]::Max(1, 2 * $s))
    $g.FillEllipse($brush, 5 * $s, 1.5 * $s, 6 * $s, 8 * $s)
    $g.DrawArc($pen, 2.5 * $s, 4.5 * $s, 11 * $s, 9 * $s, 200, 140)
    $g.FillRectangle($brush, 7.3 * $s, 12 * $s, 1.4 * $s, 3 * $s)
    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    $pen.Dispose(); $brush.Dispose(); $g.Dispose()
    return $icon
}

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = New-MicIcon $true
$notify.Text = '语音输入'
$notify.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miToggle = New-Object System.Windows.Forms.ToolStripMenuItem('开启语音输入')
$miOpen = New-Object System.Windows.Forms.ToolStripMenuItem('打开主窗口')
$miSettings = New-Object System.Windows.Forms.ToolStripMenuItem('设置…')
$miHistory = New-Object System.Windows.Forms.ToolStripMenuItem('听写历史')
$miAuto = New-Object System.Windows.Forms.ToolStripMenuItem('开机自启')
$miAuto.CheckOnClick = $true
$sep1 = New-Object System.Windows.Forms.ToolStripSeparator
$miQuit = New-Object System.Windows.Forms.ToolStripMenuItem('退出')
$null = $menu.Items.AddRange([System.Windows.Forms.ToolStripItem[]]@($miToggle, $miOpen, $miSettings, $miHistory, $miAuto, $sep1, $miQuit))
$notify.ContextMenuStrip = $menu

$script:readyNotified = $false

function Refresh-Tray {
    $st = Get-VoiceStatus
    if ($st -eq 'running') {
        $miToggle.Text = '关闭语音输入'
        $notify.Text = '语音输入：运行中（按住说话）'
        $notify.Icon = New-MicIcon $true
    } else {
        $miToggle.Text = '开启语音输入'
        $notify.Text = '语音输入：已停止'
        $notify.Icon = New-MicIcon $false
    }
}
Refresh-Tray

$miToggle.Add_Click({
    Toggle-VoiceService | Out-Null
    Refresh-Tray
    $msg = if ((Get-VoiceStatus) -eq 'running') { '已开启' } else { '已关闭' }
    $notify.ShowBalloonTip(1200, '语音输入', $msg, [System.Windows.Forms.ToolTipIcon]::Info)
})
$miOpen.Add_Click({
    try { Start-Process wscript.exe -ArgumentList "`"$mainVbs`"" } catch {}
})
$notify.Add_MouseDoubleClick({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        try { Start-Process wscript.exe -ArgumentList "`"$mainVbs`"" } catch {}
    }
})
$miSettings.Add_Click({
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$settingsPs1`"" | Out-Null } catch {}
})
$miHistory.Add_Click({
    if (Test-Path -LiteralPath $historyPath) { Start-Process notepad.exe -ArgumentList "`"$historyPath`"" }
    else { $notify.ShowBalloonTip(1200, '语音输入', '暂无听写历史', [System.Windows.Forms.ToolTipIcon]::Info) }
})

$miAuto.Checked = Get-AutostartEnabled
$miAuto.Add_Click({
    Set-AutostartEnabled $miAuto.Checked
    $msg = if ($miAuto.Checked) { '已设为开机自启' } else { '已取消开机自启' }
    $notify.ShowBalloonTip(1200, '语音输入', $msg, [System.Windows.Forms.ToolTipIcon]::Info)
})

$miQuit.Add_Click({
    Stop-VoiceService
    $notify.Visible = $false
    $notify.Dispose()
    $mutex.ReleaseMutex()
    [System.Windows.Forms.Application]::Exit()
})

$watch = New-Object System.Windows.Forms.Timer
$watch.Interval = 2000
$watch.Add_Tick({
    $restartFlag = Join-Path $workDir 'restart.flag'
    $readyFlag = Join-Path $workDir 'service_ready.txt'

    if (Test-Path -LiteralPath $restartFlag) {
        try { [System.IO.File]::Delete($restartFlag) } catch {}
        Log '检测到设置变更，重启服务'
        $wasRunning = ((Get-VoiceStatus) -eq 'running')
        Stop-VoiceService
        Start-Sleep -Milliseconds 500
        if ($wasRunning) { Start-VoiceService }
    }

    if ((Get-VoiceStatus) -eq 'running' -and -not $script:readyNotified -and (Test-Path -LiteralPath $readyFlag)) {
        try { [System.IO.File]::Delete($readyFlag) } catch {}
        $script:readyNotified = $true
        $notify.ShowBalloonTip(2000, '语音输入', '已就绪：按住说话，松开自动粘贴', [System.Windows.Forms.ToolTipIcon]::Info)
        Log '就绪通知已弹出'
    }

    Refresh-Tray
})
$watch.Start()

Log '托盘启动'
Start-VoiceService

if ($Test) {
    Start-Sleep -Seconds 3
    Log 'Test 结束'
    Stop-VoiceService
    $notify.Visible = $false
    $notify.Dispose()
    $mutex.ReleaseMutex()
    exit 0
}

[System.Windows.Forms.Application]::Run()