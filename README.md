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
    <a href="#%EF%B8%8F-configuration--parameters" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Configuration & Parameters</a> &nbsp;•&nbsp;
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
    <li><code>Backspace</code>/<code>Delete</code> delete entire line</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">📋 Advanced Clipboard</h3>
  <ul style="color: #BEB8AE;">
    <li><code>C</code> copy as plain text (auto strip formatting)</li>
    <li><code>V</code> smart paste — multi‑file merging, image→PDF conversion, mixed path handling, recursive folder collection</li>
    <li><code>Shift+V</code> encrypted history quick menu with preview, single/batch paste, delete</li>
    <li><code>F</code> instant case swap of clipboard text (preserves original in clipboard)</li>
    <li>Custom ignore rules (gitignore syntax) to exclude sensitive or temporary files during paste</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">🪟 Window & Tabs</h3>
  <ul style="color: #BEB8AE;">
    <li>Hold CapsLock + Left/Right mouse button to adjust window opacity (click +/−20, hold +/−100 per second)</li>
    <li>Middle mouse button toggles "ghost mode" (10% ↔ 100%)</li>
    <li><code>T</code> toggle always on top (with sound and OSD feedback)</li>
    <li><code>W</code>/<code>8</code>/<code>Num8</code> maximize/restore, <code>S</code>/<code>2</code>/<code>Num2</code> minimize</li>
    <li><code>Q</code>/<code>E</code> previous / next tab (<code>Ctrl+PgUp</code> / <code>Ctrl+PgDn</code>)</li>
    <li><code>Shift+Q</code>/<code>Shift+E</code> window cycling (<code>Alt+Esc</code> / <code>Alt+Shift+Esc</code>)</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">📂 Full History Browser</h3>
  <ul style="color: #BEB8AE;">
    <li>Open full clipboard history window via bottom entry of the history menu</li>
    <li>Supports search, multi‑select, batch paste as file or text</li>
    <li>Delete entries directly from the window with real‑time updates</li>
    <li>"Load More" button for paginated browsing (50 items per page)</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">🖱️ Custom Dark‑Themed Tray Menu</h3>
  <ul style="color: #BEB8AE;">
    <li>Right‑click tray icon opens a fully custom dark‑themed popup menu with sub‑menu support</li>
    <li>Settings organized into collapsible sub‑menus: Cleanup, History & Paste, Language</li>
    <li>Menu auto‑flips upward to avoid overflowing into the taskbar</li>
    <li>DPI‑aware anchor offset for accurate tray icon alignment</li>
    <li>Language can be switched on the fly from the tray sub‑menu (13 languages supported)</li>
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
| **Selection**  | `Shift+←` / `Shift+→`       | Extend selection left/right **by word**                                    |
|                | `Shift+↑` / `Shift+↓`       | Extend selection from cursor to start/end of line                          |
| **Editing**    | `A` / `D`                   | `Backspace` / `Delete` (delete single character)                           |
|                | `Shift+A` / `Shift+D`       | Delete left/right **entire word**                                          |
|                | `Backspace` / `Delete`      | Delete **entire line** (Home+Shift+End+Delete)                             |
| **Window**     | `T`                         | Toggle current window **always on top** (with sound & OSD)                 |
|                | `W` / `8` / `Num8`          | **Maximize / Restore** current window                                      |
|                | `S` / `2` / `Num2`          | **Minimize** current window                                                |
| **Mouse**      | `Left Button` (click/hold)  | **Increase** window transparency (click +20, hold +100 per second)         |
|                | `Right Button` (click/hold) | **Decrease** window transparency (click -20, hold -100 per second)         |
|                | `Middle Button`             | **Toggle** transparency: 10% (ghost mode) ↔ 100% (normal)                  |
| **Tabs**       | `Q` / `E`                   | Switch to **previous** / **next** tab (`Ctrl+PgUp` / `Ctrl+PgDn`)          |
|                | `Shift+Q` / `Shift+E`       | **Cycle windows** (`Alt+Esc` / `Alt+Shift+Esc`)                            |

---

## 🚀 Installation & Setup

### Prerequisites

1. **AutoHotkey v2** – Download and install from [autohotkey.com](https://www.autohotkey.com/)
2. **ImageMagick** (optional) – Required for image‑to‑PDF feature; install from [imagemagick.org](https://imagemagick.org/) (check "Install legacy utilities" during setup)
3. **Pandoc** (optional) – Required for document conversion feature; install from [pandoc.org](https://pandoc.org/)

### Quick Start

1. **Download the project** and place `CapsLock-.ahk` along with all subdirectories (`Config/`, `Core/`, `History/`, etc.) in the same folder.
2. **Run the script**: double‑click `CapsLock-.ahk`; an icon will appear in the system tray.
3. **(Optional) Auto‑start with Windows**: right‑click the tray icon → check **"Load on start up"** (writes to `HKCU\Run`).

### Configure ImageMagick (only needed for image‑to‑PDF)

1. Right‑click the tray icon → click **"ImageMagick: Not Set"**.
2. Browse to your ImageMagick installation directory and select `magick.exe` (e.g., `C:\Program Files\ImageMagick-7.x.x-Q16\magick.exe`).
3. The path is saved automatically to `configs/Config.ini` and the menu entry changes to **"ImageMagick: Valid"**.

### Configure Pandoc (only needed for document conversion)

1. Right‑click the tray icon → hover **"Pandoc: Not Set / Valid"** → click **"Set Pandoc Path"**.
2. Browse to your Pandoc installation directory and select `pandoc.exe`.
3. To change the output format, use the same sub‑menu → **"Set Pandoc Output"**.

---

## ⚙️ Configuration & Parameters

### Tray Menu Settings

| Menu Item                      | Description                                                                            |
| :----------------------------- | :------------------------------------------------------------------------------------- |
| `ImageMagick: Not Set / Valid` | Set or change the ImageMagick executable path                                          |
| `Pandoc: Not Set / Valid`      | Set Pandoc executable path and output format (sub‑menu)                                |
| `Open Temp Folder`             | Open the temporary folder (`%TEMP%`, where temporary paste files are stored)           |
| `Delete Mode`                  | Temp file cleanup strategy: 1=delayed delete, 2=batch cleanup, 3=never delete          |
| `Set Delay...`                 | Delay in seconds for Mode 1 (default 10 seconds)                                       |
| `Set Cleanup Interval...`      | Cleanup interval in seconds for Mode 2 (default 30 seconds)                            |
| `Set Max History...`           | Maximum clipboard history entries (0 disables history, default 10000)                  |
| `Paste Mode`                   | Paste mode: 1=paste as temp file, 2=paste as plain text with source markers            |
| `Ignore Rules`                 | Edit a list of gitignore‑style patterns; matched files/paths are skipped during paste  |
| `Language`                     | Switch UI language (based on `lang.csv`; 13 languages supported, default: `zh`)        |
| `Rebuild Language Cache`       | Rebuild language cache files from `lang.csv` into `langs/` directory                   |
| `Load on start up`             | Toggle auto‑start with Windows (registry `HKCU\Run`)                                   |
| `Reload`                       | Reload the script                                                                      |
| `Exit`                         | Exit the script                                                                        |

### Configuration File `configs/Config.ini`

```ini
[Cleanup]
deleteMode=1          ; 1=delayed 2=batch 3=never
deleteDelay=10        ; delay in seconds
cleanupInterval=30    ; batch cleanup interval in seconds

[History]
maxHistory=10000      ; max history entries

[General]
pasteMode=1           ; 1=paste as file 2=paste as text with source
autoClean=0           ; 1=enable periodic auto‑trim of history (runs every 60s)
maxHistoryItems=500   ; when autoClean is on, history is trimmed to this size
language=zh           ; UI language code (en, zh, ja, etc.)

[ImageMagick]
Path=C:\Program Files\ImageMagick-7.1.1-Q16\magick.exe

[Pandoc]
Path=C:\Program Files\Pandoc\pandoc.exe
OutputFormat=docx     ; docx, html, markdown, pdf, rst, rtf, odt, epub, etc.

[Ignore]
Rules=                ; multiple patterns separated by |
; Examples (in the UI editor each pattern is on its own line):
; ^C:\\Windows\\.*    # ignore all files under Windows folder
; \\.tmp$             # ignore .tmp files
; *.log               # ignore all .log files
```

### Advanced Global Variables (modifiable in `Config/Globals.ahk`)

| Variable               | Default               | Description                                      |
| :--------------------- | :-------------------- | :----------------------------------------------- |
| `ENCRYPT_KEY`          | `0x5A`                | XOR encryption key (0 = plaintext history)       |
| `MAX_VISIBLE_MENU`     | `12`                  | Maximum entries shown in the history quick menu  |
| `MAX_FULL_HISTORY_DISPLAY` | `50`              | Initial rows shown in the full history window    |
| `TextFormats`          | 50+ common extensions | List of extensions treated as "text files"       |
| `ImageFormats`         | png, jpg, bmp, heic…  | Image formats supported for PDF conversion       |
| `IgnorePatterns`       | (empty)               | Default ignore rules (overridable via Tray menu) |
| `AutoCleanEnabled`     | `false`               | Enable periodic history trimming                 |
| `MaxHistoryItems`      | `500`                 | Trim target when autoClean is enabled            |
| `CurrentLanguage`      | `"zh"`                | Current UI language code                         |
| `PandocInputFormats`   | 50+ formats           | Supported input formats for Pandoc conversion    |
| `PandocOutputFormats`  | 70+ formats           | Supported output formats for Pandoc conversion   |

### Theme Colors (modifiable in `Globals.ahk`)

The script uses a built‑in dark theme with configurable color values:

```autohotkey
; Background & Surface
THEME_BG            := "0x14141D"  ; Main window background
THEME_SURFACE       := "0x1B1B27"  ; Card / surface background
THEME_ELEVATED      := "0x232332"  ; Elevated surface (hover states)
THEME_CONTROL_BG    := "0x282838"  ; Input control background
THEME_CONTROL_HOVER := "0x33334A"  ; Control hover background
THEME_BORDER        := "0x3A3A52"  ; Border / separator color

; Foreground
THEME_FG            := "0xB0B4CC"  ; Primary foreground text
THEME_FG_DIM        := "0x8088A0"  ; Dimmed secondary text
THEME_FG_MUTED      := "0x5E6478"  ; Muted / disabled text

; Accent
THEME_ACCENT        := "0x5B86C9"  ; Primary accent color
THEME_ACCENT_DARK   := "0x3A5A8C"  ; Darker accent (button backgrounds)
THEME_ACCENT_GLOW   := "0x82A8E0"  ; Accent glow (hover highlight)

; State
THEME_SUCCESS       := "0x6FA572"  ; Success state color
THEME_WARNING       := "0xC4A95E"  ; Warning state color
THEME_DANGER        := "0xC06070"  ; Danger / delete state color

; Fonts
THEME_FONT          := "Segoe UI"
THEME_FONT_MONO     := "Cascadia Code"
THEME_RADIUS        := 8            ; Corner radius (px)
```

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
│   ├── 📄 Pandoc.ahk
│   └── 📄 WindowUtils.ahk
├── 📁 History
│   ├── 📄 CustomMenu.ahk
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
│   ├── 📄 PreviewGui.ahk
│   └── 📄 ThemeHelper.ahk
├── 📁 Utils
│   ├── 📄 DarkInputDialog.ahk
│   ├── 📄 Language.ahk
│   ├── 📄 MethodsUtils.ahk
│   └── 📄 ResourceSound.ahk
├── 📁 langs                (language cache files, auto-generated from lang.csv)
├── 📄 CapsLock-.ahk
├── ⚖️ LICENSE
├── 📖 README.md
└── 🌐 lang.csv
```

---

## 🧠 Implementation Highlights

- **In‑memory file paste** – Constructs a `DROPFILES` structure directly in memory to write multiple file paths to the clipboard.
- **Smart loop prevention** – Uses the `IgnoreNextClipChange` flag to prevent temporary files (`ClipTemp_*.txt`) from triggering infinite `OnClipboardChange` loops.
- **Encrypted history storage** – Employs simple XOR stream encryption to obfuscate the history file; for high‑security needs, combine with Windows EFS or BitLocker.
- **Delayed / batch / off cleanup** – Three strategies (`DeleteMode` 1–3) for temporary file cleanup to control I/O pressure and disk usage.
- **Modular design** – Each functional domain is separated into its own `.ahk` file for easy maintenance and extension.
- **Multi‑language support** – CSV‑based translation system with compiled cache files in `langs/` directory; 13 languages switchable on the fly from the tray menu. Language cache can be rebuilt from `lang.csv` via the tray menu.
- **Ignore rules** – Gitignore‑style pattern matching with hybrid engine: fast `PathMatchSpecW` API for simple patterns, regex fallback for complex patterns (e.g., `**` and `?`).
- **Custom dark‑themed menu** – `CustomMenu` builds a lightweight, hover‑aware popup GUI with sub‑menu support, replacing the native `Menu` control for both the history quick menu and the tray icon context menu.
- **GDI resource caching** – `ThemeHelper` caches `CreateSolidBrush` objects, border pens, and focus pens to avoid repeated GDI object creation/destruction during custom button drawing.
- **Debounced history save** – `HistoryManager` uses a 3000ms debounce timer to batch writes to `ClipHistory.bin`, reducing disk I/O during rapid clipboard operations. `ForceSave()` ensures no data loss on exit.
- **OSD notification system** – `OSD` class provides a single‑line, auto‑dismissing notification banner with icon, accent color bar, and timestamp, used throughout the app for status feedback.
- **Immersive dark mode** – Uses `DwmSetWindowAttribute` APIs to enable native dark title bars and window borders on Windows.
- **Resource‑embedded sound** – Always‑on‑top toggle sounds (`AlwaysOnTopOn.wav` / `AlwaysOnTopOff.wav`) are embedded as binary resources and played via `PlaySoundW` without external files.
- **Fast plain‑text copy** – `CopyAsPlainText()` backs up only `A_Clipboard` (text) instead of `ClipboardAll()` (all formats), significantly reducing backup time for rich clipboard content.
- **Recursive file enumeration** – `CollectFilesFromFolder()` uses native `Loop Files, "FR"` for deep directory trees, avoiding slow manual recursion.
- **Pandoc integration** – `ConvertWithPandoc()` converts files between 50+ input formats and 70+ output formats, with progress GUI and batch processing support.
- **Smart paste routing** – `PasteWithCurrentMode()` intelligently detects clipboard content type (single file, multiple files, folders, mixed paths, images) and routes to the appropriate paste handler.

---

## 🔐 Security Notes

> ⚠️ The history file `configs/ClipHistory.bin` is encrypted using a **fixed XOR key** (default `0x5A`). This is **only intended to prevent casual viewing and offers no cryptographic strength**.

If you handle highly sensitive data, it is recommended to:

1. Set `ENCRYPT_KEY` to `0` (disable encryption) in `Config/Globals.ahk`
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
