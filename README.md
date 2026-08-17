# 🎙️ Voice Input 语音输入

> 一款 Windows 桌面语音输入工具：按住快捷键说话，松开自动识别成文字并粘贴到任意输入框。完全离线运行，无需联网，无需 API Key。

![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue)
![Language](https://img.shields.io/badge/Language-PowerShell%20%2B%20Python-green)
![Model](https://img.shields.io/badge/ASR-Whisper%20(faster--whisper)-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## 📖 项目简介

**打字太慢？张嘴就行。**

这个项目解决一个很朴素的需求：**在电脑上任何地方（Codex、微信、记事本、浏览器……），不想打字的时候，按住一个快捷键说话，文字就自动出现在输入框里。**

它像普通软件一样提供了完整的使用体验：
- 🖥️ 桌面图标打开**主窗口**（类似 App）
- 📌 右下角**托盘图标**随时快捷操作
- ⚙️ 图形化**设置界面**，不用改代码

最关键的是：**完全本地离线识别**，你的语音不会上传到任何服务器，隐私安全，也不需要付费 API。

---

## ✨ 功能特性

- 🎤 **按住说话，松开自动粘贴**：快捷键（默认 F8）按住录音，松开即识别并粘贴到当前光标位置，中间停顿不会断句
- 🧠 **本地 AI 识别（Whisper）**：基于 faster-whisper，完全离线，隐私安全
- 🚀 **极速 / 高质量双模式**：默认极速模型（快约 4 倍），可在设置中切换高质量模型
- 🌐 **中英混合自动识别**：自动检测语言，中英混说也能识别
- 🔢 **数字/标点智能转换**：说“三点半”自动变成 `3点半`，说“五百二十”自动变成 `520`
- 📚 **自定义词库**：人名、专业术语等可优先识别正确
- 🔇 **静音模式**：一键关闭所有提示音，开会不打扰
- 📋 **听写历史记录**：每次识别自动保存，可查看、可清空
- ⚙️ **图形化设置窗口**：改快捷键、选麦克风、切语言/速度、开关自启，全部可视化
- 🚀 **开机自启 + 就绪通知**：开机自动运行，就绪后弹窗提示

---

## 🖥️ 界面一览

| 组件 | 说明 |
|------|------|
| **桌面快捷方式** | 双击打开主窗口，像 App 一样 |
| **主窗口** | 显示运行状态，一键开关 / 设置 / 历史 / 自启 / 退出 |
| **托盘图标** | 蓝色=运行中，灰色=已停止；左键双击打开主窗口，右键快捷操作 |
| **设置窗口** | 图形化配置所有选项 |

---

## 🧩 技术栈

- **语言**：PowerShell（界面/控制）+ Python（识别引擎）
- **语音识别**：[faster-whisper](https://github.com/SYSTRAN/faster-whisper)（CPU int8 量化）
- **录音**：sounddevice
- **简繁转换**：OpenCC
- **数字转换**：cn2an
- **模型**：Whisper `small`（极速）/ `large-v3-turbo`（高质量）

---

## 🚀 一键安装（不会编程也没关系）

> 只需要做 3 件事：**下载 → 解压 → 双击 `install.bat`**，剩下的全自动完成。

1. 点击右侧 **Releases** → 下载最新的 `voice-input-安装包.zip`
2. 解压到任意文件夹（例如桌面）
3. 双击里面的 **`install.bat`**

安装程序会自动帮你：
- ✅ 检查 / 自动安装 Python
- ✅ 安装识别依赖
- ✅ 下载语音模型（可选手速快的极速版或更准的高质量版）
- ✅ 把程序装到电脑上，创建桌面图标 + 开机自启
- ✅ 自动启动，弹窗提示"已就绪"

全程中文提示，跟着走就行。

---

## 📦 手动安装（进阶）

### 1. 环境要求
- Windows 10 / 11
- [Python 3.10+](https://www.python.org/downloads/)
- PowerShell（Windows 自带）

### 2. 安装依赖
```powershell
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple faster-whisper sounddevice opencc cn2an
```

### 3. 下载语音模型
模型放在 `%LOCALAPPDATA%\WhisperModels\` 下，目录名对应配置中的 `model` 值：
```
WhisperModels/
├── small/            # 极速模型（约 480MB）
└── large-v3-turbo/   # 高质量模型（约 1.6GB）
```
每个模型目录需要包含 `model.bin`、`config.json`、`tokenizer.json`、`vocabulary.txt`（或 `vocabulary.json`）。
国内用户可从 HuggingFace 镜像站下载：`https://hf-mirror.com`。

> 提示：模型路径可在 `settings.json` 的 `modelsDir` 字段中自定义，或用环境变量 `VOICEINPUT_MODELS_DIR` 指定。

### 4. 启动
```powershell
# 启动托盘版（推荐，开机自启）
wscript VoiceInputTray.vbs

# 或直接启动语音服务（无托盘）
wscript voice-input.vbs
```

---

## 📖 使用方法

1. 启动后（托盘图标变蓝 / 收到“已就绪”通知）
2. 把光标点进要输入文字的地方（Codex、微信、记事本、浏览器……）
3. **按住 F8** 开始说话（中间停顿不会断）
4. **松开 F8**，等 1~3 秒，文字自动粘贴进输入框

**提示音说明：**
- 一声“叮” = 引擎就绪 / 开始录音
- 两声“叮叮” = 识别完成，已粘贴
- 一声低音 = 没听清，请重试
- 静音模式可关闭全部提示音

---

## ⚙️ 配置说明

配置文件为程序目录下的 `settings.json`（首次运行自动生成，可参考 `settings.example.json`）：

| 字段 | 说明 | 默认值 |
|------|------|--------|
| `hotkey` | 快捷键虚拟键码（119 = F8） | `119` |
| `micDevice` | 麦克风设备索引（`null` = 默认） | `null` |
| `language` | 识别语言：`auto` / `zh` / `en` | `auto` |
| `model` | 识别模型：`small` / `large-v3-turbo` | `small` |
| `mute` | 静音模式 | `false` |
| `smartPunct` | 数字/标点智能转换 | `true` |
| `vocab` | 自定义词库（每行一个词） | 空 |
| `modelsDir` | 模型根目录 | `%LOCALAPPDATA%\WhisperModels` |

> 日常使用推荐直接在**托盘右键 → 设置…** 里修改，无需手改文件。

---

## 📁 项目结构

```
voice-input/
├── voice-input.ps1           # 语音服务主控（按住说话、控制录音、粘贴结果）
├── VoiceInputTray.ps1        # 托盘控制程序
├── VoiceInputMain.ps1        # 主窗口（App 首页）
├── VoiceInputSettings.ps1    # 设置窗口
├── common.ps1                # 公共模块（服务管理、开机自启）
├── asr-daemon.py             # 识别引擎（常驻，模型加载一次）
├── record.py                 # 录音程序（按住录制，松开停止）
├── VoiceInputTray.vbs        # 托盘启动器
├── VoiceInputMain.vbs        # 主窗口启动器
├── voice-input.vbs           # 语音服务启动器
├── mic.ico                   # 应用图标
├── settings.example.json     # 配置示例
└── README.md
```

---

## 🗺️ Roadmap

- [x] 托盘 + 主窗口 + 设置界面
- [x] 离线本地识别
- [x] 极速/高质量双模型
- [x] 中英混合识别
- [x] 数字/标点智能转换
- [x] 自定义词库
- [x] 静音模式
- [x] 听写历史
- [x] 开机自启 + 就绪通知
- [ ] 识别结果预览编辑
- [ ] 连续听写模式（一句一句上屏）
- [ ] 更多语言支持

---

## 📄 许可证

[MIT](LICENSE)