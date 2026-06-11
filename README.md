<p align="center">
  <img src="assets/CapsLock-.ico" alt="CapsLock Extended Logo" width="120">
</p>

<h1 align="center">CapsLock Extended</h1>

<p align="center">
  <strong>Turn the most underrated key on your keyboard into your productivity command center</strong><br>
  A high-performance, Vim-style system enhancement tool based on AutoHotkey v2.
</p>

<p align="center">
  <a href="https://www.autohotkey.com/"><img src="https://img.shields.io/badge/AutoHotkey-v2.0-blue?logo=autohotkey" alt="AutoHotkey v2"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-green.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-Windows-lightgrey" alt="Platform">
  <a href="https://cyojkoy.github.io/Payment/"><img src="https://img.shields.io/badge/Support-Me-orange?logo=buy-me-a-coffee" alt="Support Me"></a>
</p>

<p align="center">
  <a href="#-shortcut-quick-reference">Shortcut Quick Reference</a> •
  <a href="#-installation--setup">Installation & Setup</a> •
  <a href="#️-configuration--parameters">Configuration & Parameters</a> •
  <a href="#-support-the-author">Support the Author</a>
</p>

---

## 📖 Overview

**CapsLock Extended** redefines the purpose of the `CapsLock` key, turning it into a "super modifier key".  
By holding `CapsLock` and combining it with other keys, you can perform Vim-style home row cursor movement, advanced clipboard management (including encrypted history), window transparency adjustment, tab switching, and other workflow automations—all without leaving the keyboard's home row.

> **Note**: This script only supports **AutoHotkey v2** and is not compatible with v1.

---

## ✨ Core Features

### ⌨️ Vim-Style Navigation & Editing
- **Home row arrow keys**: `←` / `→` move cursor by word, `↑` / `↓` jump to beginning/end of line  
- **Smart selection**: Hold `Shift` to select by word/line; `Space` selects the entire word under the cursor  
- **Quick deletion**: `A` / `D` delete single character, `Shift+A` / `D` delete whole word, `Backspace` / `Delete` delete entire line

### 📋 Advanced Clipboard & Smart Paste
- **Plain text copy (`C`)**: Automatically strips all rich text formats (HTML/RTF) when copying  
- **Context-aware smart paste (`V`)**  
  - *Multi-file to text*: If clipboard contains multiple file paths (one per line), reads file contents and merges into plain text with source markers  
  - *Image set to PDF*: If multiple image paths are detected, automatically invokes ImageMagick to merge them into a single PDF  
  - *Single file paste*: Pastes the file as a temporary `.txt` file (suitable for instant messengers like WeChat/DingTalk)  
- **Encrypted history (`Shift+V`)**  
  - XOR-encrypted persistent clipboard history (default 10,000 entries)  
  - Quick menu + full GUI window, supporting batch paste, multi-select delete, and entry preview  
- **Instant case swap (`F`)**: Automatically detects the first letter of clipboard text and toggles between ALL CAPS and all lowercase

### 🪟 Window Management & "Stealth Mode"
- **Real-time transparency adjustment**: Hold `CapsLock` and click/drag left/right mouse button to smoothly increase/decrease window transparency  
- **One-click ghost mode (`Middle Mouse Button`)**: Toggle between 10% (semi-transparent) and 100% (fully opaque) for the current window  
- **Always on top (`T`)**: Pin any window to the foreground, accompanied by a sound effect and OSD notification  
- **Quick resize**: `W` / `8` / `Num8` maximize/restore window, `S` / `2` / `Num2` minimize window

### 🔖 Browser / IDE Tab Switching
- `Q` / `E` → Switch to previous / next tab (simulates `Ctrl+PgUp` / `Ctrl+PgDn`)

---

## 🎹 Shortcut Quick Reference

*All shortcuts below require **holding `CapsLock`** while pressing the corresponding key (except for double-click `CapsLock`).*

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

---

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

---

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
```ini
[Cleanup]
deleteMode=1          ; 1=delayed 2=batch 3=never
deleteDelay=10        ; delay in seconds
cleanupInterval=30    ; batch cleanup interval in seconds

[History]
maxHistory=10000      ; maximum history entries

[General]
pasteMode=1           ; 1=paste as file 2=paste as text with source

[ImageMagick]
Path=C:\Program Files\ImageMagick-7.1.1-Q16\magick.exe
```

### Advanced Global Variables (modifiable in `Config/Globals.ahk`)
| Variable | Default | Description |
|:---|:---|:---|
| `ENCRYPT_KEY` | `0x5A` | XOR encryption key (0 means plaintext history) |
| `MAX_VISIBLE_MENU` | `15` | Maximum entries shown in the history quick menu |
| `TextFormats` | 50+ common extensions | List of extensions treated as "text files" |
| `ImageFormats` | png, jpg, bmp… | Image formats supported for PDF conversion |

---

## 🧱 Project Structure

```ini
CapsLock-.ahk          # Main entry point, integrates all modules
Config/
├─ Globals.ahk         # Global variable definitions
├─ Encryption.ahk      # XOR encryption/decryption
└─ ConfigManager.ahk   # Ini configuration read/write
Core/
├─ Clipboard.ahk       # Clipboard file operations (CF_HDROP)
├─ ClipboardPaste.ahk  # Smart paste core logic
├─ FileValidation.ahk  # Path/image/multi-file validation
├─ FileOperations.ahk  # Multi-file content merge, header generation
├─ ImageToPdf.ahk      # ImageMagick invocation, image list to PDF
├─ Cleanup.ahk         # Temporary file delayed/batch deletion
└─ WindowUtils.ahk     # Transparency adjustment helpers
History/
├─ HistoryStorage.ahk  # Encrypted history save/load, add entries
├─ HistoryMenu.ahk     # Quick menu (Shift+V)
├─ HistoryFullGui.ahk  # Full history GUI window
└─ HistoryActions.ahk  # History entry paste/delete/multi-select operations
Hotkeys/
├─ HotkeyBindings.ahk  # All CapsLock combo key definitions
└─ HotkeyActions.ahk   # Concrete implementation of each hotkey action
Tray/
├─ TrayMenu.ahk        # Tray menu construction and refresh
└─ TraySettings.ahk    # Menu item interaction logic (set delete delay, clear history, etc.)
UI/
├─ OSD.ahk             # On-screen display for topmost toggle (fade in/out)
└─ PreviewGui.ahk      # History content preview window
Utils/
├─ ResourceSound.ahk   # Built-in WAV resource playback (topmost toggle sound)
└─ MathUtils.ahk       # File size formatting, value clamping
```

---

## 🧠 Implementation Highlights

- **In-memory file paste**  
  Constructs a `DROPFILES` structure to write multiple file paths directly to the clipboard, enabling batch file pasting.

- **Smart loop prevention**  
  Uses the `ignoreNextClipChange` flag to prevent temporary files generated by the script (`ClipTemp_*.txt`) from triggering an infinite `OnClipboardChange` loop.

- **Encrypted history storage**  
  Employs simple XOR stream encryption to obfuscate the history file, deterring casual snooping (for high-security needs, set `ENCRYPT_KEY` to 0 and rely on Windows EFS/BitLocker).

- **Delayed / batch cleanup mechanism**  
  Supports two temporary file cleanup strategies: delayed deletion (each file has its own timer) and batch scanning (reduces I/O pressure).

- **Modular design**  
  Each functional domain is separated into its own `.ahk` file for easy maintenance and further development.

---

## 🔐 Security Notes

- The history file `configs/ClipHistory.bin` is encrypted using a **fixed XOR key** (default `0x5A`). This is **only intended to prevent casual viewing and offers no cryptographic strength**.  
- If you handle highly sensitive data, it is recommended to:  
  1. Set `ENCRYPT_KEY` to `0` (disable encryption)  
  2. Use Windows built-in **EFS** or **BitLocker** to encrypt the entire configuration folder

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

<p align="center">
  <a href="https://cyojkoy.github.io/Payment/">
    <img src="https://img.shields.io/badge/👉_Click_Here_to_Support_Me-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Support Me Button" height="40">
  </a>
</p>

<p align="center">
  <i>Made with ❤️ and AutoHotkey v2</i>
</p>
