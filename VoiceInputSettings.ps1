# ============================================================
#  语音输入 - 设置窗口
# ============================================================
param([switch]$Test)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsPath = Join-Path $toolDir 'settings.json'
$historyPath = Join-Path $toolDir 'history.txt'
$workDir = Join-Path $env:TEMP 'voice-input'

$settings = @{ hotkey = 119; micDevice = $null; language = 'auto'; mute = $false; smartPunct = $true; vocab = ''; model = 'small' }
if (Test-Path -LiteralPath $settingsPath) {
    try { $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
$oldHotkey = [int]$settings.hotkey
$oldMic = $settings.micDevice
$oldModel = if ($settings.model) { [string]$settings.model } else { 'small' }

$devFile = Join-Path $env:TEMP 'voice-input-devices.json'
$python = (Get-Command python).Source
if (Test-Path -LiteralPath $devFile) { try { [System.IO.File]::Delete($devFile) } catch {} }
& $python -c "import sounddevice,json;d=[];[d.append({'i':i,'n':x['name']}) for i,x in enumerate(sounddevice.query_devices()) if x['max_input_channels']>0];open(r'$devFile','w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False))" 2>$null
$devices = @()
if (Test-Path -LiteralPath $devFile) { try { $devices = Get-Content -LiteralPath $devFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }

$form = New-Object System.Windows.Forms.Form
$form.Text = '语音输入 - 设置'
$form.Size = New-Object System.Drawing.Size(470, 690)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$iconPath = Join-Path $toolDir 'mic.ico'
if (Test-Path -LiteralPath $iconPath) { try { $form.Icon = New-Object System.Drawing.Icon($iconPath) } catch {} }

$y = 15
$grpBasic = New-Object System.Windows.Forms.GroupBox
$grpBasic.Text = '基本设置'
$grpBasic.Location = New-Object System.Drawing.Point(15, $y)
$grpBasic.Size = New-Object System.Drawing.Size(425, 185)
$form.Controls.Add($grpBasic)

$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = '快捷键（按住说话）:'
$lblKey.Location = New-Object System.Drawing.Point(15, 28)
$lblKey.Size = New-Object System.Drawing.Size(150, 20)
$grpBasic.Controls.Add($lblKey)
$cmbKey = New-Object System.Windows.Forms.ComboBox
$cmbKey.DropDownStyle = 'DropDownList'
$cmbKey.Location = New-Object System.Drawing.Point(170, 25)
$cmbKey.Size = New-Object System.Drawing.Size(100, 22)
$keyMap = @{ 'F5' = 116; 'F6' = 117; 'F7' = 118; 'F8' = 119; 'F9' = 120; 'F10' = 121; 'F11' = 122; 'F12' = 123 }
foreach ($k in $keyMap.Keys) { [void]$cmbKey.Items.Add($k) }
$cmbKey.SelectedItem = ($keyMap.GetEnumerator() | Where-Object { $_.Value -eq $oldHotkey } | Select-Object -First 1).Key
if (-not $cmbKey.SelectedItem) { $cmbKey.SelectedItem = 'F8' }
$grpBasic.Controls.Add($cmbKey)

$lblMic = New-Object System.Windows.Forms.Label
$lblMic.Text = '麦克风:'
$lblMic.Location = New-Object System.Drawing.Point(15, 60)
$lblMic.Size = New-Object System.Drawing.Size(150, 20)
$grpBasic.Controls.Add($lblMic)
$cmbMic = New-Object System.Windows.Forms.ComboBox
$cmbMic.DropDownStyle = 'DropDownList'
$cmbMic.Location = New-Object System.Drawing.Point(170, 57)
$cmbMic.Size = New-Object System.Drawing.Size(240, 22)
[void]$cmbMic.Items.Add('默认麦克风（自动）')
$micIndex = @{}
foreach ($d in $devices) { [void]$cmbMic.Items.Add("$($d.n)  [$($d.i)]"); $micIndex[$cmbMic.Items.Count - 1] = [int]$d.i }
$selMic = -1
if ($oldMic -ne $null -and $oldMic -ne '') {
    foreach ($kv in $micIndex.GetEnumerator()) { if ($kv.Value -eq [int]$oldMic) { $selMic = $kv.Key } }
}
$cmbMic.SelectedIndex = if ($selMic -ge 0) { $selMic } else { 0 }
$grpBasic.Controls.Add($cmbMic)

$lblLang = New-Object System.Windows.Forms.Label
$lblLang.Text = '识别语言:'
$lblLang.Location = New-Object System.Drawing.Point(15, 92)
$lblLang.Size = New-Object System.Drawing.Size(150, 20)
$grpBasic.Controls.Add($lblLang)
$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.DropDownStyle = 'DropDownList'
$cmbLang.Location = New-Object System.Drawing.Point(170, 89)
$cmbLang.Size = New-Object System.Drawing.Size(100, 22)
[void]$cmbLang.Items.Add('自动识别')
[void]$cmbLang.Items.Add('中文')
[void]$cmbLang.Items.Add('英文')
$cmbLang.SelectedIndex = switch ($settings.language) { 'zh' { 1 } 'en' { 2 } default { 0 } }
$grpBasic.Controls.Add($cmbLang)

$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text = '识别速度:'
$lblModel.Location = New-Object System.Drawing.Point(15, 124)
$lblModel.Size = New-Object System.Drawing.Size(150, 20)
$grpBasic.Controls.Add($lblModel)
$cmbModel = New-Object System.Windows.Forms.ComboBox
$cmbModel.DropDownStyle = 'DropDownList'
$cmbModel.Location = New-Object System.Drawing.Point(170, 121)
$cmbModel.Size = New-Object System.Drawing.Size(180, 22)
[void]$cmbModel.Items.Add('极速（快4倍，推荐）')
[void]$cmbModel.Items.Add('高质量（慢一些）')
$cmbModel.SelectedIndex = if ($oldModel -eq 'large-v3-turbo') { 1 } else { 0 }
$grpBasic.Controls.Add($cmbModel)

$chkMute = New-Object System.Windows.Forms.CheckBox
$chkMute.Text = '静音模式（关闭提示音）'
$chkMute.Location = New-Object System.Drawing.Point(15, 152)
$chkMute.Size = New-Object System.Drawing.Size(200, 22)
$chkMute.Checked = [bool]$settings.mute
$grpBasic.Controls.Add($chkMute)

$y += 200
$grpVocab = New-Object System.Windows.Forms.GroupBox
$grpVocab.Text = '自定义词库（每行一个词，识别优先）'
$grpVocab.Location = New-Object System.Drawing.Point(15, $y)
$grpVocab.Size = New-Object System.Drawing.Size(425, 130)
$form.Controls.Add($grpVocab)
$txtVocab = New-Object System.Windows.Forms.TextBox
$txtVocab.Multiline = $true
$txtVocab.ScrollBars = 'Vertical'
$txtVocab.Location = New-Object System.Drawing.Point(12, 24)
$txtVocab.Size = New-Object System.Drawing.Size(400, 95)
$txtVocab.Text = [string]$settings.vocab
$grpVocab.Controls.Add($txtVocab)

$y += 145
$grpSmart = New-Object System.Windows.Forms.GroupBox
$grpSmart.Text = '智能处理'
$grpSmart.Location = New-Object System.Drawing.Point(15, $y)
$grpSmart.Size = New-Object System.Drawing.Size(425, 80)
$form.Controls.Add($grpSmart)
$chkSmart = New-Object System.Windows.Forms.CheckBox
$chkSmart.Text = '数字/标点智能转换（“三点半”→3点半、“五百二十”→520）'
$chkSmart.Location = New-Object System.Drawing.Point(15, 25)
$chkSmart.Size = New-Object System.Drawing.Size(400, 22)
$chkSmart.Checked = [bool]$settings.smartPunct
$grpSmart.Controls.Add($chkSmart)
$chkAuto = New-Object System.Windows.Forms.CheckBox
$chkAuto.Text = '开机自动启动'
$chkAuto.Location = New-Object System.Drawing.Point(15, 50)
$chkAuto.Size = New-Object System.Drawing.Size(200, 22)
$chkAuto.Checked = Test-Path -LiteralPath (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\语音输入.lnk')
$grpSmart.Controls.Add($chkAuto)

$y += 95
$grpHist = New-Object System.Windows.Forms.GroupBox
$grpHist.Text = '听写历史（最近 50 条）'
$grpHist.Location = New-Object System.Drawing.Point(15, $y)
$grpHist.Size = New-Object System.Drawing.Size(425, 170)
$form.Controls.Add($grpHist)
$lstHist = New-Object System.Windows.Forms.ListBox
$lstHist.Location = New-Object System.Drawing.Point(12, 24)
$lstHist.Size = New-Object System.Drawing.Size(400, 110)
$histLines = @()
if (Test-Path -LiteralPath $historyPath) { $histLines = Get-Content -LiteralPath $historyPath -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Last 50 }
foreach ($h in $histLines) { [void]$lstHist.Items.Add($h) }
$grpHist.Controls.Add($lstHist)
$btnOpenHist = New-Object System.Windows.Forms.Button
$btnOpenHist.Text = '打开历史文件'
$btnOpenHist.Location = New-Object System.Drawing.Point(12, 138)
$btnOpenHist.Size = New-Object System.Drawing.Size(120, 24)
$btnOpenHist.Add_Click({ if (Test-Path -LiteralPath $historyPath) { Start-Process notepad.exe -ArgumentList "`"$historyPath`"" } })
$grpHist.Controls.Add($btnOpenHist)
$btnClearHist = New-Object System.Windows.Forms.Button
$btnClearHist.Text = '清空历史'
$btnClearHist.Location = New-Object System.Drawing.Point(140, 138)
$btnClearHist.Size = New-Object System.Drawing.Size(90, 24)
$btnClearHist.Add_Click({
    if (Test-Path -LiteralPath $historyPath) { try { [System.IO.File]::WriteAllText($historyPath, '', (New-Object System.Text.UTF8Encoding($false))) } catch {} }
    $lstHist.Items.Clear()
})
$grpHist.Controls.Add($btnClearHist)

$y += 185
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = '保存'
$btnSave.Location = New-Object System.Drawing.Point(220, $y)
$btnSave.Size = New-Object System.Drawing.Size(100, 30)
$btnSave.Add_Click({
    $newHotkey = $keyMap[$cmbKey.SelectedItem]
    $newMic = $null
    if ($cmbMic.SelectedIndex -gt 0) { $newMic = $micIndex[$cmbMic.SelectedIndex] }
    $langVal = switch ($cmbLang.SelectedIndex) { 1 { 'zh' } 2 { 'en' } default { 'auto' } }
    $modelVal = if ($cmbModel.SelectedIndex -eq 1) { 'large-v3-turbo' } else { 'small' }
    $out = @{
        hotkey = $newHotkey
        micDevice = $newMic
        language = $langVal
        mute = [bool]$chkMute.Checked
        smartPunct = [bool]$chkSmart.Checked
        vocab = $txtVocab.Text
        model = $modelVal
    } | ConvertTo-Json
    [System.IO.File]::WriteAllText($settingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))

    $autoLnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\语音输入.lnk'
    if ($chkAuto.Checked) {
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($autoLnk)
        $lnk.TargetPath = Join-Path $toolDir 'VoiceInputTray.vbs'
        $lnk.WorkingDirectory = $toolDir
        $lnk.Description = '语音输入（开机自启）'
        $lnk.Save()
    } else {
        if (Test-Path -LiteralPath $autoLnk) { try { [System.IO.File]::Delete($autoLnk) } catch {} }
    }

    if ($newHotkey -ne $oldHotkey -or "$newMic" -ne "$oldMic" -or $modelVal -ne $oldModel) {
        $restartFlag = Join-Path $workDir 'restart.flag'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        [System.IO.File]::WriteAllText($restartFlag, 'restart', (New-Object System.Text.UTF8Encoding($false)))
    }
    $form.DialogResult = 'OK'
    $form.Close()
})
$form.Controls.Add($btnSave)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = '取消'
$btnCancel.Location = New-Object System.Drawing.Point(330, $y)
$btnCancel.Size = New-Object System.Drawing.Size(100, 30)
$btnCancel.Add_Click({ $form.DialogResult = 'Cancel'; $form.Close() })
$form.Controls.Add($btnCancel)

if ($Test) {
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 2000
    $t.Add_Tick({ $form.Close() })
    $t.Start()
}
$null = $form.ShowDialog()
$form.Dispose()
exit 0