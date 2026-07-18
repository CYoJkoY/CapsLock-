<div align="center" style="background-color: #1E1E1E; padding: 40px 20px; border-radius: 28px;">

  <div style="background: #2A2A2A; border-radius: 36px; padding: 42px 18px; margin-bottom: 28px;">
    <img src="assets/CapsLock-.ico" alt="CapsLock Extended Logo" width="80">
    <h1 style="color: #E6DED6; font-weight: 350; letter-spacing: 2px; margin: 18px 0 8px;">CapsLock Extended</h1>
    <p style="color: #BEB8AE; font-size: 1.2em; max-width: 600px; margin: 0 auto;">Turn the most underrated key on your keyboard into your productivity command center</p>
    <p style="color: #8A9E8B; font-size: 0.95em; margin-top: 12px;">A high-performance, Vim-style system enhancement tool based on AutoHotkey v2</p>
  </div>

  <p>
    <a href="https://www.autohotkey.com/"><img src="https://img.shields.io/badge/AutoHotkey-v2.0-8A9E8B?logo=autohotkey&logoColor=BEB8AE&style=flat-square" alt="AutoHotkey v2"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-7A8E8E?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/Platform-Windows-9E8F7E?style=flat-square" alt="Platform">
    <a href="https://cyojkoy.github.io/Payment/"><img src="https://img.shields.io/badge/Support_Me-9E8F7E?logo=buy-me-a-coffee&logoColor=BEB8AE&style=flat-square" alt="Support Me"></a>
  </p>

  <p style="word-spacing: 6px; margin-top: 20px;">
    <a href="#-shortcut-quick-reference" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Shortcut Quick Reference</a> &nbsp;•&nbsp;
    <a href="#-installation--setup" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Installation & Setup</a> &nbsp;•&nbsp;
    <a href="#️-configuration--parameters" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Configuration & Parameters</a> &nbsp;•&nbsp;
    <a href="#-support-the-author" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Support the Author</a>
  </p>
</div>

<div align="center">
  <img src="assets/dots.svg" alt="separator" width="160" height="12">
</div>

## 📖 Overview

**CapsLock Extended** redefines the purpose of the `CapsLock` key, turning it into a "super modifier key".  
By holding `CapsLock` and combining it with other keys, you can perform Vim-style home row cursor movement, advanced clipboard management (including encrypted history), window transparency adjustment, tab switching, and other workflow automations—all without leaving the keyboard's home row.

> **Note**  
> This script supports **AutoHotkey v2 only** and is not backward compatible with v1.

---

## ✨ Core Features

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">⌨️ Vim‑Style Navigation</h3>
  <ul style="color: #BEB8AE;">
    <li><code>←</code>/<code>→</code> move cursor by word</li>
    <li><code>↑</code>/<code>↓</code> jump to beginning / end of line</li>
    <li><code>Shift</code> + arrows for smart text selection</li>
    <li><code>Space</code> selects whole word under cursor</li>
    <li><code>A</code>/<code>D</code> delete char, <code>Shift+A/D</code> delete word</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">📋 Advanced Clipboard</h3>
  <ul style="color: #BEB8AE;">
    <li><code>C</code> copy as plain text</li>
    <li><code>V</code> smart paste (multi‑file merging, image→PDF, path content merge, etc.)</li>
    <li><code>Shift+V</code> encrypted history quick menu with preview, single/batch paste, delete</li>
    <li><code>F</code> instant case swap of clipboard text</li>
    <li>Custom ignore rules to exclude sensitive or temporary files during paste</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">🪟 Window & Tabs</h3>
  <ul style="color: #BEB8AE;">
    <li>Hold CapsLock + Left/Right mouse button to adjust window opacity</li>
    <li>Middle mouse button toggles "ghost mode" (10% ↔ 100%)</li>
    <li><code>T</code> toggle always on top (with sound and OSD feedback)</li>
    <li><code>W</code>/<code>8</code>/<code>Num8</code> maximize/restore, <code>S</code>/<code>2</code>/<code>Num2</code> minimize</li>
    <li><code>Q</code>/<code>E</code> previous / next tab</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">📂 Full History Browser</h3>
  <ul style="color: #BEB8AE;">
    <li>Open full clipboard history window via bottom entry of the history menu</li>
    <li>Supports search, multi‑select, batch paste as file or text</li>
    <li>Delete entries directly from the window with real‑time updates</li>
  </ul>
</div>

---

## 🎹 Shortcut Quick Reference

_All shortcuts below require **holding `CapsLock`** while pressing the corresponding key (except double‑click `CapsLock`)._

| Category       | Shortcut                    | Description                                                                |
| :------------- | :-------------------------- | :------------------------------------------------------------------------- |
| **System**     | `CapsLock` (double‑click)   | Toggle native CapsLock state (50~300ms double‑click window)                |
| **Clipboard**  | `C`                         | Copy selection as **plain text** (auto strip formatting)                   |
|                | `V`                         | **Smart paste** (image paths→PDF / multi‑file content merge / mixed paths) |
|                | `Shift+V`                   | Open **clipboard history** quick menu                                      |
|                | `F`                         | **Swap case** of clipboard text and paste (original retained)              |
| **Navigation** | `←` / `→`                   | Move cursor left/right **by one word**                                     |
|                | `↑` / `↓`                   | Jump to **beginning** / **end of line**                                    |
|                | `Space`                     | Select the **entire word** under the cursor                                |
| **Selection**  | `Shift+←` / `→`             | Extend selection left/right **by word**                                    |
|                | `Shift+↑` / `↓`             | Extend selection from cursor to start/end of line                          |
| **Editing**    | `A` / `D`                   | `Backspace` / `Delete` (delete single character)                           |
|                | `Shift+A` / `D`             | Delete left/right **entire word**                                          |
|                | `Backspace` / `Delete`      | Delete **entire line**                                                     |
| **Window**     | `T`                         | Toggle current window **always on top**                                    |
|                | `W` / `8` / `Num8`          | **Maximize / Restore** current window                                      |
|                | `S` / `2` / `Num2`          | **Minimize** current window                                                |
| **Mouse**      | `Left Button` (click/hold)  | **Increase** window transparency (click +20, hold +100 per second)         |
|                | `Right Button` (click/hold) | **Decrease** window transparency (click -20, hold -100 per second)         |
|                | `Middle Button`             | **Toggle** transparency: 10% (ghost mode) ↔ 100% (normal)                  |
| **Tabs**       | `Q` / `E`                   | Switch to **previous** / **next** tab (`Ctrl+PgUp` / `Ctrl+PgDn`)          |

---

## 🚀 Installation & Setup

### Prerequisites

1. **AutoHotkey v2** – Download and install from [autohotkey.com](https://www.autohotkey.com/)
2. **ImageMagick** (optional) – Required for image‑to‑PDF feature; install from [imagemagick.org](https://imagemagick.org/) (check "Install legacy utilities" during setup)

### Quick Start

1. **Download the project** and place `CapsLock-.ahk` along with all subdirectories (`Config/`, `Core/`, `History/`, etc.) in the same folder.
2. **Run the script**: double‑click `CapsLock-.ahk`; an icon will appear in the system tray.
3. **(Optional) Auto‑start with Windows**: right‑click the tray icon → check **"Load on start up"** (writes to `HKCU\Run`).

### Configure ImageMagick (only needed for image‑to‑PDF)

1. Right‑click the tray icon → click **"ImageMagick: Not Set"**.
2. Browse to your ImageMagick installation directory and select `magick.exe` (e.g., `C:\Program Files\ImageMagick-7.x.x-Q16\magick.exe`).
3. The path is saved automatically to `configs/Config.ini` and the menu entry changes to **"ImageMagick: Valid"**.

---

## ⚙️ Configuration & Parameters

### Tray Menu Settings

| Menu Item                      | Description                                                                            |
| :----------------------------- | :------------------------------------------------------------------------------------- |
| `ImageMagick: Not Set / Valid` | Set or change the ImageMagick executable path                                          |
| `Open Temp Folder`             | Open the temporary folder (`%TEMP%`, where temporary paste files are stored)           |
| `Delete Mode`                  | Temp file cleanup strategy: 1=delayed delete, 2=batch cleanup, 3=never delete          |
| `Set Delay...`                 | Delay in seconds for Mode 1 (default 10 seconds)                                       |
| `Set Cleanup Interval...`      | Cleanup interval in seconds for Mode 2 (default 30 seconds)                            |
| `Set Max History...`           | Maximum clipboard history entries (0 disables history, default 10000)                  |
| `Paste Mode`                   | Paste mode: 1=paste as temp file, 2=paste as plain text with source markers            |
| `Ignore Rules`                 | Edit a list of regex patterns; matched files/paths are skipped during paste operations |
| `Language`                     | Switch UI language (based on `lang.csv`; 13 languages supported)                       |
| `Load on start up`             | Toggle auto‑start with Windows (registry `HKCU\Run`)                                   |
| `Reload`                       | Reload the script                                                                      |
| `Exit`                         | Exit the script                                                                        |

### Configuration File `configs/Config.ini`

📁 configs/Config.ini

```ini
[Cleanup]
deleteMode=1          ; 1=delayed 2=batch 3=never
deleteDelay=10        ; delay in seconds
cleanupInterval=30    ; batch cleanup interval in seconds

[History]
maxHistory=10000      ; max history entries

[General]
pasteMode=1           ; 1=paste as file 2=paste as text with source

[ImageMagick]
Path=C:\Program Files\ImageMagick-7.1.1-Q16\magick.exe

[Ignore]
Rules=                ; multiple regexes separated by |
; Examples (in the UI editor each pattern is on its own line):
; ^C:\\Windows\\.*    # ignore all files under Windows folder
; \\.tmp$             # ignore .tmp files
```

### Advanced Global Variables (modifiable in `Config/Globals.ahk`)

| Variable           | Default               | Description                                      |
| :----------------- | :-------------------- | :----------------------------------------------- |
| `ENCRYPT_KEY`      | `0x5A`                | XOR encryption key (0 = plaintext history)       |
| `MAX_VISIBLE_MENU` | `15`                  | Maximum entries shown in the history quick menu  |
| `TextFormats`      | 50+ common extensions | List of extensions treated as "text files"       |
| `ImageFormats`     | png, jpg, bmp…        | Image formats supported for PDF conversion       |
| `IgnorePatterns`   | (empty)               | Default ignore rules (overridable via Tray menu) |

---

## 🧱 Project Structure

```tree
CapsLock-
├── 📁 assets
│   ├── 🎵 AlwaysOnTopOn.wav
│   ├── 🎵 AlwaysOnTopOff.wav
│   ├── 🖼️ bar.svg
│   ├── 🖼️ CapsLock-.ico
│   ├── 🖼️ Config.ico
│   ├── 🖼️ Core.ico
│   ├── 🖼️ dots.svg
│   ├── 🖼️ History.ico
│   ├── 🖼️ Hotkeys.ico
│   ├── 🖼️ Tray.ico
│   ├── 🖼️ UI.ico
│   └── 🖼️ Utils.ico
├── 📁 Config
│   ├── 📄 ConfigManager.ahk
│   ├── 📄 Encryption.ahk
│   └── 📄 Globals.ahk
├── 📁 Core
│   ├── 📄 Cleanup.ahk
│   ├── 📄 Clipboard.ahk
│   ├── 📄 ClipboardPaste.ahk
│   ├── 📄 FileOperations.ahk
│   ├── 📄 FileValidation.ahk
│   ├── 📄 ImageToPdf.ahk
│   └── 📄 WindowUtils.ahk
├── 📁 History
│   ├── 📄 FullHistoryGui.ahk
│   ├── 📄 FullHistoryHandlers.ahk
│   ├── 📄 HistoryDelete.ahk
│   ├── 📄 HistoryMenu.ahk
│   ├── 📄 HistoryPaste.ahk
│   └── 📄 HistoryStorage.ahk
├── 📁 Hotkeys
│   ├── 📄 HotkeyActions.ahk
│   ├── 📄 HotkeyBindings.ahk
│   └── 📄 PasteHandler.ahk
├── 📁 Tray
│   ├── 📄 TrayMenu.ahk
│   └── 📄 TraySettings.ahk
├── 📁 UI
│   ├── 📄 OSD.ahk
│   └── 📄 PreviewGui.ahk
├── 📁 Utils
│   ├── 📄 Language.ahk
│   ├── 📄 MethodsUtils.ahk
│   └── 📄 ResourceSound.ahk
├── 📄 CapsLock-.ahk
├── ⚖️ LICENSE
├── 📖 README.md
└── 🌐 lang.csv
```

---

## 🧠 Implementation Highlights

- **In‑memory file paste** – Constructs a `DROPFILES` structure directly in memory to write multiple file paths to the clipboard.
- **Smart loop prevention** – Uses the `ignoreNextClipChange` flag to prevent temporary files (`ClipTemp_*.txt`) from triggering infinite `OnClipboardChange` loops.
- **Encrypted history storage** – Employs simple XOR stream encryption to obfuscate the history file; for high‑security needs, combine with Windows EFS or BitLocker.
- **Delayed / batch cleanup** – Two strategies for temporary file cleanup to control I/O pressure and disk usage.
- **Modular design** – Each functional domain is separated into its own `.ahk` file for easy maintenance and extension.
- **Multi‑language support** – CSV‑based translation system; 13 languages switchable on the fly from the tray menu.
- **Ignore rules** – Regex‑based filtering to safely exclude unwanted files or paths from paste operations.

---

## 🔐 Security Notes

> ⚠️ The history file `configs/ClipHistory.bin` is encrypted using a **fixed XOR key** (default `0x5A`). This is **only intended to prevent casual viewing and offers no cryptographic strength**.

If you handle highly sensitive data, it is recommended to:

1. Set `ENCRYPT_KEY` to `0` (disable encryption)
2. Use Windows built‑in **EFS** or **BitLocker** to encrypt the entire configuration folder

---

## 🤝 Contributing & Feedback

Issues and Pull Requests are welcome.  
Please ensure your code conforms to AHK v2 syntax and follows the existing modular style.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.  
See the [LICENSE](LICENSE) file for details.

---

## 💰 Support the Author

If this project has boosted your productivity, consider buying me a coffee! ☕

<div align="center">
  <a href="https://cyojkoy.github.io/Payment/">
    <img src="https://img.shields.io/badge/👉_Click_Here_to_Support_Me-9E8F7E?style=for-the-badge&logo=buy-me-a-coffee&logoColor=BEB8AE" alt="Support Me Button">
  </a>
</div>

<div align="center">
  <br>
  <i style="color: #8A9E8B;">Made with ❤️ and AutoHotkey v2</i>
</div>

<div align="center">
  <img src="assets/bar.svg" alt="footer bar" width="240" height="8">
</div>
