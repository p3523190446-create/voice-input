# ============================================================
#  语音输入 - 一键安装脚本（面向不懂编程的用户）
#  自动：检查/安装 Python → 安装依赖 → 下载模型 → 复制程序
#        → 创建桌面/开机自启快捷方式 → 启动
# ============================================================
param(
  [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'VoiceInput'),
  [switch]$NoShortcuts, [switch]$NoLaunch, [switch]$NoPip, [switch]$Check
)
$ErrorActionPreference = 'Stop'
$srcDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modelsRoot = Join-Path $env:LOCALAPPDATA 'WhisperModels'

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

function Find-Python {
    $c = Get-Command python -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $c2 = Get-Command py -ErrorAction SilentlyContinue
    if ($c2) { return $c2.Source }
    $p = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python" -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'Python3' } | Select-Object -First 1
    if ($p) { return $p.FullName }
    return $null
}

function Get-ModelFile([string]$modelName, [string]$file, [string]$baseUrl) {
    $dir = Join-Path $modelsRoot $modelName
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $out = Join-Path $dir $file
    if ((Test-Path -LiteralPath $out) -and (Get-Item -LiteralPath $out).Length -gt 0) {
        Write-Host "  OK 已存在 $file"
        return
    }
    Write-Host "  下载 $file ..."
    curl.exe -sS --progress-bar --connect-timeout 20 -L -o $out "$baseUrl/$file"
    if (-not (Test-Path -LiteralPath $out) -or (Get-Item -LiteralPath $out).Length -eq 0) {
        throw "下载失败: $file"
    }
    try {
        $head = Get-Content -LiteralPath $out -TotalCount 1 -ErrorAction Stop
        if ($head -match 'Entry not found|Not Found') { throw "文件不存在: $file" }
    } catch {
        if ($_.Exception.Message -like '*不存在*') { throw }
    }
}
if ($Check) {
    Write-Host "=== 环境检查 ===" -ForegroundColor Green
    $py = Find-Python
    Write-Host "Python : $(if ($py) { $py } else { '未找到' })"
    if ($py) { & $py --version 2>&1 | ForEach-Object { Write-Host "   $_" } }
    Write-Host "模型目录: $modelsRoot  存在=$(Test-Path -LiteralPath $modelsRoot)"
    foreach ($m in @('small','large-v3-turbo')) {
        $b = Join-Path $modelsRoot "$m\model.bin"
        Write-Host "  模型 $m : $(if (Test-Path -LiteralPath $b) { '已下载' } else { '未下载' })"
    }
    Write-Host "源目录: $srcDir"
    exit 0
}

Write-Host "==============================================" -ForegroundColor Green
Write-Host "   VOICE INPUT  语音输入 - 一键安装" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

# ---- 1. 检查 / 安装 Python ----
Write-Step "第1步/共5步：检查 Python"
$py = Find-Python
if (-not $py) {
    Write-Host "未检测到 Python，正在自动安装（几分钟）..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            & $winget.Source install -e --id Python.Python.3.12 --scope user --accept-source-agreements --accept-package-agreements --silent --disable-interactivity | Out-Null
        } catch { }
        Start-Sleep -Seconds 3
        $py = Find-Python
    }
    if (-not $py) {
        Write-Host "Python 自动安装失败，请手动安装：https://www.python.org/downloads/ （安装时勾选 Add to PATH）" -ForegroundColor Red
        Read-Host "按回车键退出"
        exit 1
    }
}
Write-Host "OK Python: $py"
& $py --version

# ---- 2. 安装依赖 ----
if (-not $NoPip) {
    Write-Step "第2步/共5步：安装识别依赖（faster-whisper 等，首次约2-3分钟）"
    & $py -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple faster-whisper sounddevice opencc cn2an
    if ($LASTEXITCODE -ne 0) { Write-Host "依赖安装失败" -ForegroundColor Red; Read-Host "按回车退出"; exit 1 }
    Write-Host "OK 依赖安装完成"
}

# ---- 3. 下载模型 ----
Write-Step "第3步/共5步：下载语音模型"
Write-Host "  选择模型（识别质量 vs 速度）："
Write-Host "    [1] 极速模型（约480MB，快，推荐）"
Write-Host "    [2] 高质量模型（约1.6GB，更准但慢）"
Write-Host "    [3] 两个都要"
$choice = Read-Host "  请输入 1 / 2 / 3（回车默认 1）"
$needSmall = $true
$needTurbo = $false
if ($choice -eq '2') { $needSmall = $false; $needTurbo = $true }
elseif ($choice -eq '3') { $needSmall = $true; $needTurbo = $true }
if ($needSmall) {
    Write-Host "`n[极速模型 small]"
    try {
        Get-ModelFile 'small' 'model.bin'      'https://hf-mirror.com/Systran/faster-whisper-small/resolve/main'
        Get-ModelFile 'small' 'config.json'    'https://hf-mirror.com/Systran/faster-whisper-small/resolve/main'
        Get-ModelFile 'small' 'tokenizer.json' 'https://hf-mirror.com/Systran/faster-whisper-small/resolve/main'
        Get-ModelFile 'small' 'vocabulary.txt' 'https://hf-mirror.com/Systran/faster-whisper-small/resolve/main'
    } catch { Write-Host "  极速模型下载失败: $_" -ForegroundColor Red }
}
if ($needTurbo) {
    Write-Host "`n[高质量模型 large-v3-turbo]"
    try {
        Get-ModelFile 'large-v3-turbo' 'model.bin'      'https://hf-mirror.com/mobiuslabsgmbh/faster-whisper-large-v3-turbo/resolve/main'
        Get-ModelFile 'large-v3-turbo' 'config.json'    'https://hf-mirror.com/mobiuslabsgmbh/faster-whisper-large-v3-turbo/resolve/main'
        Get-ModelFile 'large-v3-turbo' 'tokenizer.json' 'https://hf-mirror.com/mobiuslabsgmbh/faster-whisper-large-v3-turbo/resolve/main'
        Get-ModelFile 'large-v3-turbo' 'vocabulary.json' 'https://hf-mirror.com/mobiuslabsgmbh/faster-whisper-large-v3-turbo/resolve/main'
    } catch { Write-Host "  高质量模型下载失败: $_" -ForegroundColor Red }
}

# ---- 4. 复制程序 ----
Write-Step "第4步/共5步：安装程序到 $InstallDir"
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
foreach ($f in @('voice-input.ps1','VoiceInputTray.ps1','VoiceInputMain.ps1','VoiceInputSettings.ps1','common.ps1','asr-daemon.py','record.py','VoiceInputTray.vbs','VoiceInputMain.vbs','voice-input.vbs','mic.ico')) {
    $s = Join-Path $srcDir $f
    if (Test-Path -LiteralPath $s) { Copy-Item -LiteralPath $s -Destination (Join-Path $InstallDir $f) -Force }
}
$settingsPath = Join-Path $InstallDir 'settings.json'
if (-not (Test-Path -LiteralPath $settingsPath)) {
    $modelVal = if ($needSmall) { 'small' } else { 'large-v3-turbo' }
    $defaultSettings = @{
        hotkey = 119; micDevice = $null; language = 'auto'; mute = $false
        smartPunct = $true; vocab = ''; model = $modelVal; modelsDir = $modelsRoot
    } | ConvertTo-Json
    [System.IO.File]::WriteAllText($settingsPath, $defaultSettings, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "OK 已生成默认配置"
} else {
    Write-Host "OK 已保留你的现有配置"
}
# ---- 5. 快捷方式 + 启动 ----
if (-not $NoShortcuts) {
    Write-Step "第5步/共5步：创建快捷方式"
    $ws = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = $ws.CreateShortcut((Join-Path $desktop '语音输入.lnk'))
    $lnk.TargetPath = Join-Path $InstallDir 'VoiceInputTray.vbs'
    $lnk.WorkingDirectory = $InstallDir
    $lnk.IconLocation = "$InstallDir\mic.ico,0"
    $lnk.Description = '语音输入：按住 F8 说话，松开自动粘贴'
    $lnk.Save()
    $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    $lnk2 = $ws.CreateShortcut((Join-Path $startup '语音输入.lnk'))
    $lnk2.TargetPath = Join-Path $InstallDir 'VoiceInputTray.vbs'
    $lnk2.WorkingDirectory = $InstallDir
    $lnk2.Description = '语音输入（开机自启）'
    $lnk2.Save()
    Write-Host "OK 桌面快捷方式 + 开机自启已创建"
}

if (-not $NoLaunch) {
    try { Start-Process wscript.exe -ArgumentList "`"$InstallDir\VoiceInputTray.vbs`"" } catch { }
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "  使用方法：光标点进输入框 → 按住 F8 说话 → 松开自动粘贴" -ForegroundColor Green
Write-Host "  托盘图标可随时开关 / 设置 / 退出（已设开机自启）" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Read-Host "按回车键退出"