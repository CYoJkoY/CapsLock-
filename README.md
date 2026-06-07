# CapsLock Extension

A high-performance system enhancement utility developed in AutoHotkey v2. This script transforms the underutilized `CapsLock` key into a versatile Super-Modifier, streamlining text navigation, window management, clipboard history, and advanced workflows such as Clipboard-to-File and Image-to-PDF conversion. It features persistent, encrypted storage for clipboard history while preserving the native CapsLock toggle functionality.

# 📋 Table of Contents

- [✨ Core Features](#core-features)
  - [📋 Advanced Clipboard Management](#advanced-clipboard-management)
  - [🔄 Quick Case Conversion](#quick-case-conversion)
  - [🖼️ Integrated Image Processing & PDF Creation](#integrated-image-processing-pdf-creation)
  - [🗑️ Temporary File Cleanup System](#temporary-file-cleanup-system)
  - [⌨️ Efficient Text Navigation & Editing](#efficient-text-navigation-editing)
  - [🪟 Window & Transparency Control](#window-transparency-control)
  - [⚙️ System Integration](#system-integration)
- [⌨️ Keyboard Shortcuts Reference](#keyboard-shortcuts-reference)
- [🚀 Installation & Usage](#installation-usage)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
- [🛠️ Technical Details & Configuration](#technical-details-configuration)
  - [Architecture Notes](#architecture-notes)
- [📄 License](#license)

## ✨ Core Features

### 📋 Advanced Clipboard Management
*   **Plain Text Copy (`CapsLock + C`)**: Copies selected content as pure text, stripping all rich formatting (HTML/RTF/styles). It internally backs up the clipboard, executes the copy command, and overwrites the clipboard with the plain text version. File path lists are automatically detected and skipped to preserve the original clipboard state.
*   **Smart Paste (`CapsLock + V`)**: Converts the last manually copied text (or current clipboard) into a `.txt` file and pastes it, ideal for sharing code snippets in messaging applications or File Explorer. 
    *   *Context-Aware Headers*: Generated files include a header comment detailing the source window title and timestamp.
    *   *Configurable Paste Mode*: Users can toggle between pasting as a temporary file (Mode 1) or pasting as text with appended source metadata (Mode 2).
*   **Clipboard History with Encrypted Storage (`CapsLock + Shift + V`)**: 
    *   **Quick Menu**: A lightweight, non-blocking menu displaying the most recent entries (configurable limit).
    *   **Full History GUI**: A resizable interface supporting multi-selection, batch operations (paste as individual files or batch delete), and content preview.
    *   **Persistent & Encrypted**: History is saved to `ClipHistory.bin` using XOR-based encryption (configurable key) to obfuscate text content, persisting across script reloads and system restarts.
    *   **Intelligent Source Tracking**: Captures the active window title and timestamp at the exact moment of copying, ensuring accurate provenance.

### 🔄 Quick Case Conversion
*   **Instant Case Inversion (`CapsLock + F`)**: Detects the first English letter in the clipboard content. If uppercase, the entire text is converted to lowercase, and vice versa. The converted text is pasted immediately, and the original clipboard content is automatically restored.

### 🖼️ Integrated Image Processing & PDF Creation
*   **Image to PDF Conversion (`CapsLock + V`)**: When the clipboard contains a list of valid image file paths (one per line), the script automatically invokes ImageMagick to merge them into a single PDF file and pastes the resulting file.
*   **Supported Formats**: PNG, JPG, JPEG, BMP, GIF, TIFF, TIF, WEBP, ICO, HEIC.

### 🗑️ Temporary File Cleanup System
All temporary files generated during paste operations are managed by a robust cleanup system. Three strategies are available via the system tray menu:
1.  **Delete after delay (Default)**: Each temporary file is deleted individually after a configurable delay (default: 10 seconds).
2.  **Batch cleanup**: Temporary files are queued and deleted collectively at a configurable interval (default: 30 seconds).
3.  **Never delete**: Temporary files are retained indefinitely.

### ⌨️ Efficient Text Navigation & Editing
Vim-inspired home row movement allows for efficient text navigation and editing without leaving the home row:
*   **Navigation**: Jump to line Home/End, or jump left/right by word.
*   **Selection**: Select text to line Home/End, select by word, or instantly select the entire current word.
*   **Deletion**: Delete single characters, delete by word, or delete the entire current line.
*   **Tab Switching**: Quickly switch browser or application tabs.

### 🪟 Window & Transparency Control
*   **Real-time Opacity Adjustment**: 
    *   Hold `CapsLock` + **Left Mouse Button**: Gradually increase opacity (quick click: +20).
    *   Hold `CapsLock` + **Right Mouse Button**: Gradually decrease opacity (quick click: -20).
    *   *Note*: Opacity is clamped between 20 and 255.
*   **One-Click Stealth Toggle (`CapsLock` + **Middle Mouse Button**)**: Toggles the active window’s opacity between 10% (nearly transparent) and 100% (fully opaque).
*   **Quick Window State Control**:
    *   `CapsLock + w` / `8` / `Numpad8`: Toggle window Maximize / Restore.
    *   `CapsLock + s` / `2` / `Numpad2`: Minimize active window.

### ⚙️ System Integration
*   **Comprehensive Tray Menu**: Right-click the system tray icon to access:
    *   ImageMagick path configuration.
    *   Temporary folder access.
    *   Cleanup mode and timing configuration.
    *   Paste mode selection (File vs. Text with source).
    *   Maximum history limit adjustment.
    *   Auto-start on system login toggle.
    *   Script reload and exit commands.
*   **Native CapsLock Toggle**: Double-tap `CapsLock` (within 50–300ms) to toggle the native CapsLock state (On/Off), maintaining its dual functionality as both a toggle and a modifier key.

---

## ⌨️ Keyboard Shortcuts Reference

| Action | Shortcut | Description |
| :--- | :--- | :--- |
| **Native Toggle** | `CapsLock` (Double-tap) | Toggles native CapsLock state (50-300ms window). |
| **Clipboard** | `CapsLock + C` | Copy selection as plain text. |
| | `CapsLock + V` | Smart paste (as file or text with source, based on Paste Mode). |
| | `CapsLock + Shift + V` | Open clipboard history quick menu. |
| | `CapsLock + F` | Invert case of clipboard text (Upper ↔ Lower). |
| **Navigation** | `CapsLock + ← / →` | Jump left/right by word. |
| | `CapsLock + ↑ / ↓` | Jump to line Home / End. |
| **Selection** | `CapsLock + Shift + ← / →` | Select text left/right by word. |
| | `CapsLock + Shift + ↑ / ↓` | Select text to line Home / End. |
| | `CapsLock + Space` | Select the entire current word. |
| **Editing** | `CapsLock + a / d` | Backspace / Delete (single character). |
| | `CapsLock + Shift + a / d` | Delete word to the left / right. |
| | `CapsLock + Backspace / Delete`| Delete the entire current line. |
| **Window** | `CapsLock + LButton` | Increase window opacity (Hold: +5/50ms, Click: +20). |
| | `CapsLock + RButton` | Decrease window opacity (Hold: -5/50ms, Click: -20). |
| | `CapsLock + MButton` | Toggle opacity between 10% and 100%. |
| | `CapsLock + w / 8 / Numpad8` | Toggle Maximize / Restore active window. |
| | `CapsLock + s / 2 / Numpad2` | Minimize active window. |
| **Misc** | `CapsLock + q / e` | Switch to previous / next tab (`Ctrl + PgUp / PgDn`). |

---

## 🚀 Installation & Usage

### Prerequisites
1. Install [AutoHotkey v2](https://www.autohotkey.com/). This script is strictly incompatible with AutoHotkey v1.1.
2. (Optional) Download and install [ImageMagick](https://imagemagick.org/) to enable the Image-to-PDF conversion feature.

### Setup
1. **Download**: Place the `CapsLock-.ahk` script and the `modules` directory in your preferred location.
2. **Run**: Double-click the script file to launch it. A system tray icon will appear.
3. **Auto-Start (Optional)**: Right-click the tray icon and select **"Load on start up"**. A checkmark indicates it is enabled (this modifies the `HKCU\...\Run` registry key).
4. **Configure ImageMagick (Optional)**:
   * Right-click the tray icon → Select **"ImageMagick: Not Set"** (or similar status).
   * Navigate to your ImageMagick installation directory and select `magick.exe` (typically `C:\Program Files\ImageMagick-<version>\magick.exe`).
   * The path will be saved to the `[ImageMagick]` section of `Config.ini`.

---

## 🛠️ Technical Details & Configuration

The script’s behavior can be fine-tuned by modifying the global variables at the top of the respective module files or via the system tray menu. Settings are persisted in `Config.ini`.

| Variable / Config Key | Default | Description |
| :--- | :--- | :--- |
| `MaxHistory` | `10000` | Maximum number of clipboard history entries to retain (FIFO). Configurable via Tray Menu. |
| `MAX_VISIBLE_MENU` | `15` | Maximum items displayed in the quick history menu (`CapsLock + Shift + V`). |
| `ENCRYPT_KEY` | `0x5A` | Hexadecimal key used for XOR encryption of the history file. Set to `0` to disable encryption (plain text storage). |
| `HistoryFile` | `A_ScriptDir "\ClipHistory.bin"` | File path for persistent history storage. |
| `ImageMagickExe` | `""` | Full path to `magick.exe`, read from the `[ImageMagick]` section of `Config.ini`. |
| `ImageFormats` | `[ "png", "jpg", ... ]` | Array of supported image extensions for path detection in the clipboard. |
| `DeleteMode` | `1` | Temporary file cleanup strategy: `1` = Delete after delay, `2` = Batch cleanup, `3` = Never delete. |
| `DeleteDelay` | `10` | Delay in seconds before deleting temp files (applies when `DeleteMode = 1`). |
| `CleanupInterval` | `30` | Interval in seconds between batch cleanup runs (applies when `DeleteMode = 2`). |
| `PasteMode` | `1` | Paste behavior: `1` = Paste as temporary `.txt` file, `2` = Paste as text with appended source metadata. |
| `ConfigFile` | `A_ScriptDir "\Config.ini"` | Unified INI file storing all persistent settings. |

### Architecture Notes
*   **Modular Design**: The codebase is separated into logical modules (`Constants`, `Encryption`, `Config`, `Cleanup`, `ClipboardUtils`, `History`, `Hotkeys`, `Tray`, `Main`) for maintainability.
*   **Clipboard Monitoring**: Utilizes `OnClipboardChange` to detect new copies. It intelligently ignores its own generated temporary files (`ClipTemp_*.txt`) to prevent infinite loops.
*   **Multiple File Paste**: The `SetClipboardFiles` function constructs a `DROPFILES` structure in memory, enabling the script to place multiple file paths onto the clipboard simultaneously for batch paste operations from the Full History GUI.
*   **Encryption Limitation**: The provided XOR encryption (`CryptBuffer` function) is a simple obfuscation mechanism and is not cryptographically secure. For highly sensitive data, consider setting `ENCRYPT_KEY` to `0` and relying on OS-level file permissions.

---

## 📄 License

This project is licensed under the [GPL-3.0 License](LICENSE).
