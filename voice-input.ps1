# ============================================================
#  语音输入服务 — 按住说话，松开自动识别并粘贴
#  配置来自 settings.json（托盘"设置"窗口可改）
# ============================================================
param([switch]$Test)

Add-Type -AssemblyName System.Windows.Forms

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class VoiceInputNative {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsPath = Join-Path $toolDir 'settings.json'
$workDir = Join-Path $env:TEMP 'voice-input'
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$python = (Get-Command python).Source
if (-not $python) { Write-Host "未找到 python" -ForegroundColor Red; exit 1 }

$settings = @{ hotkey = 119; micDevice = $null; mute = $false }
if (Test-Path -LiteralPath $settingsPath) {
    try { $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
$VK = if ($settings.hotkey) { [int]$settings.hotkey } else { 119 }
$micArg = ''
if ($settings.micDevice -ne $null -and $settings.micDevice -ne '') { $micArg = " --device $($settings.micDevice)" }

function Play-Sound([string]$kind) {
    if (Test-Path -LiteralPath $settingsPath) {
        try { $s = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($s.mute) { return } } catch {}
    }
    switch ($kind) {
        'ready' { [System.Media.SystemSounds]::Asterisk.Play() }
        'start' { [System.Media.SystemSounds]::Exclamation.Play() }
        'done'  { [System.Media.SystemSounds]::Asterisk.Play() }
        'fail'  { [System.Media.SystemSounds]::Hand.Play() }
    }
}

function Clear-ToolFile([string]$name) {
    $p = Join-Path $workDir $name
    if (Test-Path -LiteralPath $p) { try { [System.IO.File]::Delete($p) } catch {} }
}

'request.txt','result.txt','ready.txt','stop.flag','service_ready.txt','start.flag','quit.flag' | ForEach-Object { Clear-ToolFile $_ }

# ---- 启动识别引擎（常驻）----
$daemon = $null
try {
    $daemon = Start-Process -FilePath $python -ArgumentList "`"$toolDir\asr-daemon.py`" `"$workDir`"" -WindowStyle Hidden -PassThru
    $ready = Join-Path $workDir 'ready.txt'
    $deadline = (Get-Date).AddSeconds(90)
    while (-not (Test-Path -LiteralPath $ready) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    if (Test-Path -LiteralPath $ready) {
        try { [System.IO.File]::WriteAllText((Join-Path $workDir 'service_ready.txt'), 'ready', (New-Object System.Text.UTF8Encoding($false))) } catch {}
        Play-Sound 'ready'
        Write-Host "语音引擎就绪，按住说话（松开自动识别并粘贴）" -ForegroundColor Green
        Clear-ToolFile 'ready.txt'
    } else {
        Write-Host "引擎启动超时" -ForegroundColor Red
        exit 1
    }

    # ---- 主循环：按住录音，松开停止并识别 ----
    $prevDown = $false
    $rec = $null
    $recActive = $false
    $wav = ''
    $flag = Join-Path $workDir 'stop.flag'

    while ($true) {
        $down = (([VoiceInputNative]::GetAsyncKeyState($VK)) -band 0x8000) -ne 0

        if ($down -and -not $prevDown -and -not $recActive) {
            $wav = Join-Path $workDir ("utt_" + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + ".wav")
            $rec = Start-Process -FilePath $python -ArgumentList "`"$toolDir\record.py`" `"$wav`" --flag `"$flag`"$micArg" -WindowStyle Hidden -PassThru
            $recActive = $true
            Play-Sound 'start'
            Write-Host "[录音中] 说话...松开结束" -ForegroundColor Cyan
        }
        elseif (-not $down -and $prevDown -and $recActive) {
            [System.IO.File]::WriteAllText($flag, 'stop', (New-Object System.Text.UTF8Encoding($false)))
        }

        $prevDown = $down

        if ($recActive -and $rec.HasExited) {
            $recActive = $false
            Clear-ToolFile 'stop.flag'
            Start-Sleep -Milliseconds 50
            if (Test-Path -LiteralPath $wav) {
                [System.IO.File]::WriteAllText((Join-Path $workDir 'request.txt'), $wav, (New-Object System.Text.UTF8Encoding($false)))
                $res = Join-Path $workDir 'result.txt'
                $dl = (Get-Date).AddSeconds(120)
                while (-not (Test-Path -LiteralPath $res) -and (Get-Date) -lt $dl) { Start-Sleep -Milliseconds 50 }
                if (Test-Path -LiteralPath $res) {
                    $text = [System.IO.File]::ReadAllText($res, [System.Text.Encoding]::UTF8)
                    try { [System.IO.File]::Delete($res) } catch {}
                    if ($text -and -not $text.StartsWith('ERR:')) {
                        [System.Windows.Forms.Clipboard]::SetText($text)
                        Start-Sleep -Milliseconds 50
                        [System.Windows.Forms.SendKeys]::SendWait('^v')
                        Write-Host "已粘贴: $text" -ForegroundColor Green
                        Play-Sound 'done'
                    } else {
                        Write-Host "未识别到内容" -ForegroundColor Yellow
                        Play-Sound 'fail'
                    }
                }
                try { [System.IO.File]::Delete($wav) } catch {}
            }
        }

        Start-Sleep -Milliseconds 30
    }
} finally {
    if ($daemon -and -not $daemon.HasExited) { try { Stop-Process -Id $daemon.Id -Force } catch {} }
}