<style>
  table {
    border-collapse: separate;
    border-spacing: 0;
    width: 100%;
    margin: 1.2em 0;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    background-color: #2A2A2A;
  }
  th {
    background-color: #3A3A3A;
    color: #E6DED6;
    font-weight: 500;
    padding: 12px 16px;
    border-bottom: 1px solid #5A6B6B;
    text-align: left;
  }
  td {
    background-color: #2A2A2A;
    color: #CEC6B8;
    padding: 10px 16px;
    border-bottom: 1px solid #3A3A3A;
  }
  tr:last-child td {
    border-bottom: none;
  }
  tr:hover td {
    background-color: #3A3A3A;
    color: #E6DED6;
  }
  code {
    background-color: #1E1E1E;
    padding: 2px 6px;
    border-radius: 8px;
    font-family: 'Fira Code', monospace;
    font-size: 0.85em;
    color: #CEC6B8;
  }
  pre code {
    background: transparent;
    padding: 0;
  }
  blockquote {
    margin: 1.2em 0;
    padding: 0.5em 1em;
    border-left: 4px solid #7A8E8E;
    background-color: #2A2A2A;
    border-radius: 12px;
    color: #BEB8AE;
  }
</style>

<div align="center" style="background-color: #1E1E1E; padding: 8px 0;">
  <div style="background: linear-gradient(135deg, #2E2E2E 0%, #3A3A3A 100%); border-radius: 32px; padding: 48px 24px; margin-bottom: 32px; box-shadow: 0 8px 20px rgba(0,0,0,0.3);">
    <img src="assets/CapsLock-.ico" alt="CapsLock Extended Logo" width="88" style="filter: drop-shadow(2px 4px 8px rgba(0,0,0,0.4));">
    <h1 style="color: #E6DED6; font-weight: 380; letter-spacing: 2px; margin-top: 20px; margin-bottom: 10px;">CapsLock Extended</h1>
    <p style="color: #BEB8AE; font-size: 1.22em; max-width: 720px; margin: 0 auto;">Turn the most underrated key on your keyboard into your productivity command center</p>
    <p style="color: #8A9E8B; font-size: 0.96em; margin-top: 14px;">A high-performance, Vim-style system enhancement tool based on AutoHotkey v2</p>
  </div>

  <div>
    <a href="https://www.autohotkey.com/"><img src="https://img.shields.io/badge/AutoHotkey-v2.0-8A9E8B?logo=autohotkey&logoColor=BEB8AE&style=flat-square" alt="AutoHotkey v2"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-7A8E8E?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/Platform-Windows-9E8F7E?style=flat-square" alt="Platform">
    <a href="https://cyojkoy.github.io/Payment/"><img src="https://img.shields.io/badge/Support_Me-9E8F7E?logo=buy-me-a-coffee&logoColor=BEB8AE&style=flat-square" alt="Support Me"></a>
  </div>

  <p style="margin-top: 24px; word-spacing: 4px;">
    <a href="#-shortcut-quick-reference" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Shortcut Quick Reference</a>   •  
    <a href="#-installation--setup" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Installation & Setup</a>   •  
    <a href="#%EF%B8%8F-configuration--parameters" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Configuration & Parameters</a>   •  
    <a href="#-support-the-author" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Support the Author</a>
  </p>
</div>

<div align="center">
  <svg width="140" height="10" viewBox="0 0 140 10" fill="none" xmlns="http://www.w3.org/2000/svg">
    <circle cx="10" cy="5" r="2.2" fill="#7A8E8E"/>
    <circle cx="35" cy="5" r="2.2" fill="#9E8F7E"/>
    <circle cx="60" cy="5" r="2.2" fill="#8A9E8B"/>
    <circle cx="85" cy="5" r="2.2" fill="#6B7B7B"/>
    <circle cx="110" cy="5" r="2.2" fill="#7A8E8E"/>
    <circle cx="130" cy="5" r="1.8" fill="#9E8F7E"/>
  </svg>
</div>

## 📖 Overview

**CapsLock Extended** redefines the purpose of the `CapsLock` key, turning it into a "super modifier key".  
By holding `CapsLock` and combining it with other keys, you can perform Vim-style home row cursor movement, advanced clipboard management (including encrypted history), window transparency adjustment, tab switching, and other workflow automations—all without leaving the keyboard's home row.

> **Note**  
> This script supports **AutoHotkey v2 only** and is not backward compatible with v1.

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## ✨ Core Features

<div style="display: flex; flex-wrap: wrap; gap: 16px; margin: 20px 0;">
  <div style="flex: 1; min-width: 200px; background: #2A2A2A; border-radius: 20px; padding: 16px; box-shadow: 0 2px 6px rgba(0,0,0,0.3);">
    <h3 style="margin-top: 0; color: #D6D2CC;">⌨️ Vim‑Style Navigation</h3>
    <ul style="margin-bottom: 0; color: #BEB8AE;">
      <li><code>←</code>/<code>→</code> move by word</li>
      <li><code>↑</code>/<code>↓</code> jump to start/end of line</li>
      <li><code>Shift</code> + arrows for smart selection</li>
      <li><code>Space</code> selects whole word under cursor</li>
      <li><code>A</code>/<code>D</code> delete char, <code>Shift+A/D</code> delete word</li>
    </ul>
  </div>
  <div style="flex: 1; min-width: 200px; background: #2A2A2A; border-radius: 20px; padding: 16px; box-shadow: 0 2px 6px rgba(0,0,0,0.3);">
    <h3 style="margin-top: 0; color: #D6D2CC;">📋 Advanced Clipboard</h3>
    <ul style="margin-bottom: 0; color: #BEB8AE;">
      <li><code>C</code> copy as plain text</li>
      <li><code>V</code> smart paste (multi‑file → text / images → PDF)</li>
      <li><code>Shift+V</code> encrypted history menu</li>
      <li><code>F</code> instant case swap</li>
    </ul>
  </div>
  <div style="flex: 1; min-width: 200px; background: #2A2A2A; border-radius: 20px; padding: 16px; box-shadow: 0 2px 6px rgba(0,0,0,0.3);">
    <h3 style="margin-top: 0; color: #D6D2CC;">🪟 Window &amp; Tabs</h3>
    <ul style="margin-bottom: 0; color: #BEB8AE;">
      <li>Hold CapsLock + mouse → transparency</li>
      <li>Middle‑click → ghost mode (10% ↔ 100%)</li>
      <li><code>T</code> always on top, <code>W</code>/<code>S</code> resize</li>
      <li><code>Q</code>/<code>E</code> previous/next tab</li>
    </ul>
  </div>
</div>

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## 🎹 Shortcut Quick Reference

*All shortcuts below require **holding `CapsLock`** while pressing the corresponding key (except double-click `CapsLock`).*

| Category | Shortcut | Description |
|:---|:---|:---|
| **System** | `CapsLock` (double-click) | Toggle native CapsLock state (50~300ms double-click window) |
| **Clipboard** | `C` | Copy selection as **plain text** (auto strip formatting) |
| | `V` | **Smart paste** (multi-file/image-to-PDF/text with source) |
| | `Shift+V` | Open **clipboard history** quick menu |
| | `F` | **Swap case** of clipboard text |
| **Navigation** | `←` / `→` | Move cursor left/right **by one word** |
| | `↑` / `↓` | Jump to **beginning** / **end of line** |
| | `Space` | Select the **entire word** under the cursor |
| **Selection** | `Shift+←` / `→` | Select left/right **by word** |
| | `Shift+↑` / `↓` | Select left/right **by line** (to start/end of line) |
| **Editing** | `A` / `D` | `Backspace` / `Delete` (delete single character) |
| | `Shift+A` / `D` | Delete left/right **entire word** |
| | `Backspace` / `Delete` | Delete **entire line** (from start to end) |
| **Window** | `T` | Toggle current window **always on top** |
| | `W` / `8` / `Num8` | **Maximize / Restore** current window |
| | `S` / `2` / `Num2` | **Minimize** current window |
| **Mouse** | `Left Button` (click/hold) | **Increase** window transparency (click +20, hold +100 per second) |
| | `Right Button` (click/hold) | **Decrease** window transparency (click -20, hold -100 per second) |
| | `Middle Button` | **Toggle** transparency: 10% (ghost mode) ↔ 100% (normal) |
| **Tabs** | `Q` / `E` | Switch to **previous** / **next** tab (`Ctrl+PgUp/PgDn`) |

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## 🚀 Installation & Setup

### Prerequisites
1. **AutoHotkey v2** – Download and install from [autohotkey.com](https://www.autohotkey.com/)  
2. **ImageMagick** (optional) – Required for "Image set to PDF" feature; install from [imagemagick.org](https://imagemagick.org/) (check "Install legacy utilities" during setup)

### Quick Start
1. **Download the project** and extract `CapsLock-.ahk` along with the `modules/` folder to any directory  
2. **Run the script**: Double-click `CapsLock-.ahk`, a new icon will appear in the system tray  
3. **(Optional) Auto-start with Windows**: Right-click the tray icon → check **"Load on start up"**

### Configure ImageMagick (only for image-to-PDF)
1. Right-click the tray icon → click **"ImageMagick: Not Set"**  
2. Browse to the ImageMagick installation directory and select `magick.exe` (e.g., `C:\Program Files\ImageMagick-7.x.x-Q16\magick.exe`)  
3. The path will be saved automatically to `configs/Config.ini`, and the status will change to **"ImageMagick: Valid"**

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## ⚙️ Configuration & Parameters

### Tray Menu Settings

| Menu Item | Description |
|:---|:---|
| `ImageMagick: Not Set / Valid` | Set the path to the ImageMagick executable |
| `Open Temp Folder` | Open the temporary folder (`%TEMP%`, where temporary paste files are stored) |
| `Delete Mode` | Temporary file cleanup mode: 1=delayed delete, 2=batch cleanup, 3=never delete |
| `Mode1: Set Delete Delay...` | Delay in seconds for Mode 1 (default 10 seconds) |
| `Mode2: Set Cleanup Interval...` | Cleanup interval in seconds for Mode 2 (default 30 seconds) |
| `Set Max History Limit...` | Maximum number of clipboard history entries (0 disables history, default 10000) |
| `Paste Mode` | Paste mode: 1=paste as temporary txt file, 2=paste as plain text with source markers |
| `Load on start up` | Toggle auto-start with Windows (writes to registry `HKCU\Run`) |
| `Reload` | Reload the script |
| `Exit` | Exit the script |

### Configuration File `configs/Config.ini` (auto-generated)

<div style="background: #2A2A2A; border-radius: 20px; padding: 20px; margin: 16px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.3);">
  <div style="border-bottom: 1px solid #5A6B6B; padding-bottom: 8px; margin-bottom: 16px;">
    <span style="color: #8A9E8B; font-family: monospace;">📁 configs/Config.ini</span>
  </div>
  <pre style="background: #1E1E1E; color: #D6D2CC; border-radius: 12px; padding: 16px; overflow-x: auto; margin: 0;"><code style="font-family: 'Fira Code', monospace; font-size: 0.9em;">[Cleanup]
deleteMode=1          ; 1=delayed 2=batch 3=never
deleteDelay=10        ; delay in seconds
cleanupInterval=30    ; batch cleanup interval in seconds

[History]
maxHistory=10000      ; maximum history entries

[General]
pasteMode=1           ; 1=paste as file 2=paste as text with source

[ImageMagick]
Path=C:\Program Files\ImageMagick-7.1.1-Q16\magick.exe
</code></pre>
</div>

### Advanced Global Variables (modifiable in `Config/Globals.ahk`)

| Variable | Default | Description |
|:---|:---|:---|
| `ENCRYPT_KEY` | `0x5A` | XOR encryption key (0 means plaintext history) |
| `MAX_VISIBLE_MENU` | `15` | Maximum entries shown in the history quick menu |
| `TextFormats` | 50+ common extensions | List of extensions treated as "text files" |
| `ImageFormats` | png, jpg, bmp… | Image formats supported for PDF conversion |

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## 🧱 Project Structure

<div style="background: #2A2A2A; border-radius: 20px; padding: 20px; margin: 16px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.3);">
  <div style="border-bottom: 1px solid #5A6B6B; padding-bottom: 8px; margin-bottom: 16px;">
    <span style="color: #8A9E8B; font-family: monospace;">📂 CapsLock-</span>
  </div>
  <pre style="background: #1E1E1E; color: #D6D2CC; border-radius: 12px; padding: 16px; overflow-x: auto; margin: 0;"><code style="font-family: 'Fira Code', monospace; font-size: 0.9em;">CapsLock-.ahk                # Main entry point
configs/
├─ ClipIgnore.txt            # Ignore list for clipboard history
└─ Config.ini                # Runtime configuration (auto-generated)
Config/
├─ Globals.ahk               # Global variable definitions
├─ Encryption.ahk            # XOR encryption/decryption
└─ ConfigManager.ahk         # INI configuration read/write
Core/
├─ Clipboard.ahk             # CF_HDROP clipboard operations
├─ ClipboardPaste.ahk        # Smart paste core logic
├─ FileValidation.ahk        # Path/image/multi-file validation
├─ FileOperations.ahk        # Multi-file content merge, header generation
├─ ImageToPdf.ahk            # ImageMagick invocation, image list → PDF
├─ Cleanup.ahk               # Temporary file delayed/batch deletion
└─ WindowUtils.ahk           # Transparency adjustment helpers
History/
├─ HistoryStorage.ahk        # Encrypted history save/load, add entries
├─ HistoryMenu.ahk           # Quick menu (Shift+V)
├─ HistoryFullGui.ahk        # Full history GUI window
└─ HistoryActions.ahk        # Paste/delete/multi-select operations
Hotkeys/
├─ HotkeyBindings.ahk        # All CapsLock combo key definitions
└─ HotkeyActions.ahk         # Concrete implementation of each hotkey action
Tray/
├─ TrayMenu.ahk              # Tray menu construction and refresh
└─ TraySettings.ahk          # Menu interaction logic (delete delay, clear history, etc.)
UI/
├─ OSD.ahk                   # On-screen display for topmost toggle (fade in/out)
└─ PreviewGui.ahk            # History content preview window
Utils/
├─ ResourceSound.ahk         # Built-in WAV resource playback (topmost toggle sound)
└─ MathUtils.ahk             # File size formatting, value clamping
</code></pre>
</div>

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## 🧠 Implementation Highlights

- **In-memory file paste** – Constructs a `DROPFILES` structure to write multiple file paths directly to the clipboard, enabling batch file pasting.
- **Smart loop prevention** – Uses the `ignoreNextClipChange` flag to prevent temporary files generated by the script (`ClipTemp_*.txt`) from triggering an infinite `OnClipboardChange` loop.
- **Encrypted history storage** – Employs simple XOR stream encryption to obfuscate the history file, deterring casual snooping (for high‑security needs, set `ENCRYPT_KEY` to 0 and rely on Windows EFS/BitLocker).
- **Delayed / batch cleanup mechanism** – Supports two temporary file cleanup strategies: delayed deletion (each file has its own timer) and batch scanning (reduces I/O pressure).
- **Modular design** – Each functional domain is separated into its own `.ahk` file for easy maintenance and further development.

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## 🔐 Security Notes

<div style="background-color: #2A2A2A; border-radius: 16px; padding: 12px 20px; margin: 16px 0;">
  <span style="color: #B6C9D0;">⚠️</span> <span style="color: #BEB8AE;">The history file <code>configs/ClipHistory.bin</code> is encrypted using a <strong>fixed XOR key</strong> (default <code>0x5A</code>). This is <strong>only intended to prevent casual viewing and offers no cryptographic strength</strong>.</span>
</div>

If you handle highly sensitive data, it is recommended to:  
1. Set `ENCRYPT_KEY` to `0` (disable encryption)  
2. Use Windows built-in **EFS** or **BitLocker** to encrypt the entire configuration folder

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## 🤝 Contributing & Feedback

Issues and Pull Requests are welcome.  
Please ensure your code conforms to AHK v2 syntax and follows the existing modular style.

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.  
See the [LICENSE](LICENSE) file for details.

<svg width="100%" height="1" viewBox="0 0 100% 1" style="margin: 24px 0;"><line x1="0" y1="0.5" x2="100%" y2="0.5" stroke="#5A6B6B" stroke-width="0.8" stroke-dasharray="4 4"/></svg>

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
  <svg width="220" height="8" viewBox="0 0 220 8" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect x="0" y="2" width="44" height="3" fill="#7A8E8E" rx="1.5"/>
    <rect x="52" y="2" width="44" height="3" fill="#9E8F7E" rx="1.5"/>
    <rect x="104" y="2" width="44" height="3" fill="#8A9E8B" rx="1.5"/>
    <rect x="156" y="2" width="44" height="3" fill="#6B7B7B" rx="1.5"/>
  </svg>
</div>
