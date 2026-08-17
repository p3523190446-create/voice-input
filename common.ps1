# ============================================================
#  语音输入 - 公共模块 (服务管理 + 开机自启)
#  由托盘程序与主窗口共用
# ============================================================

$script:ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ServicePs1 = Join-Path $script:ToolDir 'voice-input.ps1'
$script:PidFile = Join-Path $script:ToolDir 'service.pid'
$script:AutoLnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\语音输入.lnk'

function Get-VoiceStatus {
    # running / stopped
    if (Test-Path -LiteralPath $script:PidFile) {
        try {
            $id = [int](Get-Content -LiteralPath $script:PidFile -Raw -ErrorAction Stop)
            $p = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($p) { return 'running' }
        } catch {}
    }
    return 'stopped'
}

function Start-VoiceService {
    if ((Get-VoiceStatus) -eq 'running') { return }
    $sp = Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script:ServicePs1`"" -WindowStyle Hidden -PassThru
    try {
        [System.IO.File]::WriteAllText($script:PidFile, [string]$sp.Id, (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
}

function Stop-VoiceService {
    if (Test-Path -LiteralPath $script:PidFile) {
        try {
            $id = [int](Get-Content -LiteralPath $script:PidFile -Raw -ErrorAction Stop)
            $p = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($p) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
        } catch {}
        try { [System.IO.File]::Delete($script:PidFile) } catch {}
    }
}

function Toggle-VoiceService {
    if ((Get-VoiceStatus) -eq 'running') { Stop-VoiceService; return 'stopped' }
    else { Start-VoiceService; return 'running' }
}

function Get-AutostartEnabled {
    return (Test-Path -LiteralPath $script:AutoLnk)
}

function Set-AutostartEnabled([bool]$on) {
    if ($on) {
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($script:AutoLnk)
        $lnk.TargetPath = Join-Path $script:ToolDir 'VoiceInputTray.vbs'
        $lnk.WorkingDirectory = $script:ToolDir
        $lnk.Description = '语音输入（开机自启）'
        $lnk.Save()
    } else {
        if (Test-Path -LiteralPath $script:AutoLnk) { try { [System.IO.File]::Delete($script:AutoLnk) } catch {} }
    }
}