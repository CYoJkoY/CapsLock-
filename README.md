# CapsLock Extension 🚀

A high‑performance system enhancement tool built with **AutoHotkey v2**. This script transforms the underutilized `CapsLock` key into a versatile **Super‑Modifier (Mod‑key)**, streamlining text navigation, window management, clipboard history, and introducing unique workflows like **Clipboard‑to‑File** and **Image‑to‑PDF conversion**. It features **persistent, encrypted storage** for clipboard history without losing the native CapsLock toggle functionality.

## ✨ Core Features

### 📋 Advanced Clipboard Management
*   **Smart Paste as File (`CapsLock + V`)**:
    *   Instantly converts the last manually copied text (or the current clipboard if no manual history exists) into a `.txt` file and pastes it. Perfect for sending code snippets or text as files in IM apps or File Explorer.
    *   **Context‑Aware Headers**: Each generated `.txt` file includes a header comment (e.g., `; Copied from: CapsLock‑.ahk - Visual Studio Code [Administrator] (at 2026‑04‑23 00:46:39)`) recording the **source window title and timestamp**. When pasting from the history menu, it uses the original source stored in history. For direct `CapsLock+V` pasting, it attempts to match the clipboard content with history to retrieve the source; otherwise, it uses a generic descriptor.
    *   **Clipboard Restoration**: The original manual clipboard content (if any) is restored 10 seconds after the paste operation.
*   **Clipboard History with Encrypted Storage**:
    *   **History Menu (`CapsLock + Shift + V`)**: A lightweight, non‑blocking menu showing the 15 most recent entries (configurable via `MAX_VISIBLE_MENU`). Click **"📋 View full history (X items)..."** to open the full management GUI.
    *   **Full History GUI**: A resizable window with a multi‑select ListView, supporting:
        *   **Batch Operations**: Select multiple items to paste as individual `.txt` files sequentially, or delete them in batch.
        *   **Content Preview**: Double‑click an item or use the context menu to preview its full content in a separate read‑only, resizable window.
        *   **"Select All" Toggle**: A checkbox to quickly select/deselect all history entries.
    *   **Persistent & Encrypted Storage**: Clipboard history is automatically saved to `ClipHistory.bin` in the script directory. Storage uses simple XOR‑based encryption (controllable via the `ENCRYPT_KEY` global variable) to obfuscate text content. History persists across script reloads and system restarts.
*   **Intelligent Source Tracking**: The script captures the active window title and timestamp at the moment of *copying* (`Ctrl+C`), not at pasting. This "copy‑time context" is stored with each history entry for accurate provenance. The source process name is also captured in memory for potential future use.

### 🔄 Quick Case Conversion
*   **Instant Case Inversion (`CapsLock + F`)**:
    *   Detects the first English letter in the last copied text (or current clipboard). If the letter is uppercase, the entire text is converted to lowercase; if lowercase, converted to uppercase.
    *   The converted text is pasted immediately. After pasting, the original clipboard content is automatically restored, leaving your copy history unchanged.

### 🖼️ Integrated Image Processing & PDF Creation
*   **Image to PDF Conversion (`CapsLock + V`)**: When the clipboard contains a list of valid image file paths (one per line), the script automatically calls ImageMagick to merge them into a single PDF file and paste it.
*   **Supported Image Formats**: PNG, JPG, JPEG, BMP, GIF, TIFF, TIF, WEBP, ICO, HEIC (configurable via the `ImageFormats` list).
*   **ImageMagick Configuration**: Before first use, you must specify the full path to `magick.exe` via the system tray icon menu → **"Set ImageMagick Path..."**. The path is saved to the `[ImageMagick]` section of `Config.ini`.

### 🗑️ Temporary File Cleanup System
All temporary files generated during paste operations are automatically cleaned up. You can choose from three cleanup strategies via the tray menu:
*   **Mode 1 – Delete after delay** (default): Each temp file is deleted individually after a configurable delay (default: 10 seconds).
*   **Mode 2 – Batch cleanup**: Temp files are collected and deleted together at a configurable interval (default: every 30 seconds).
*   **Mode 3 – Never delete**: Temporary files are never automatically removed.
Cleanup settings are persisted in the `[Cleanup]` section of `Config.ini` and can be adjusted at any time through the tray menu.

### ⌨️ Efficient Text Navigation & Editing
*   **Vim‑like Home Row Movement**: Navigate text efficiently without moving your hands off the home row.
    *   `CapsLock + ↑/↓`: Jump to line **Home** / **End**.
    *   `CapsLock + ←/→`: Jump **left/right by word** (equivalent to `Ctrl + ←/→`).
*   **Enhanced Selection**:
    *   `CapsLock + Shift + ↑/↓`: Select text from cursor to line Home/End.
    *   `CapsLock + Shift + ←/→`: Select text left/right by word.
    *   `CapsLock + Space`: Instantly select the entire current word.
*   **Powerful Deletion**:
    *   `CapsLock + a/d`: **Backspace** / **Delete** (single character).
    *   `CapsLock + Shift + a/d`: Delete word to the left / Delete word to the right.
    *   `CapsLock + Backspace/Delete`: Delete the entire current line (Home + Shift + End + Delete).
*   **Quick Tab Switching**: `CapsLock + Q/E`: Switch browser tabs (`Ctrl + PgUp` / `PgDn`).

### 🪟 Window & Transparency Control
*   **Real‑time Window Opacity Adjustment**:
    *   **Hold `CapsLock` + Left Mouse Button**: Gradually increase the active window’s opacity (becomes more opaque). Click quickly for a +20 step.
    *   **Hold `CapsLock` + Right Mouse Button**: Gradually decrease the active window’s opacity (becomes more transparent). Click quickly for a -20 step.
    *   Opacity is clamped between 20 and 255.
*   **One‑Click Stealth Toggle**: `CapsLock + Middle Mouse Button`: Toggle the active window’s opacity between 10% (nearly transparent) and 100% (fully opaque).
*   **Quick Window State Control**:
    *   `CapsLock + 8` / `Numpad8`: Toggle window **Maximize / Restore**.
    *   `CapsLock + 2` / `Numpad2`: **Minimize** active window.

### ⚙️ System Integration
*   **Tray Menu**: Right‑click the system tray icon for:
    *   **Set ImageMagick Path...**: Set the path to `magick.exe` for the image‑to‑PDF feature.
    *   **Open Temp Folder**: Open the system temporary folder where generated `.txt` files are stored.
    *   **Delete Mode** (submenu):
        *   `1 - Delete after delay`: Each temp file is deleted after a set delay.
        *   `2 - Batch cleanup`: Temp files are deleted in batches at a set interval.
        *   `3 - Never delete`: Temp files are kept indefinitely.
    *   **Mode1: Set Delete Delay...**: Configure the delay (in seconds) for Mode 1.
    *   **Mode2: Set Cleanup Interval...**: Configure the interval (in seconds) for Mode 2.
    *   **Load on start up**: Toggle auto‑start with the system (modifies `HKCU\...\Run` registry).
    *   **Reload**: Reload the script.
    *   **Exit**: Exit the application.
*   **Native CapsLock Toggle**: Double‑tap `CapsLock` (within 50‑300ms) to toggle the native CapsLock state (On/Off), while still allowing it to function as a modifier key when held.

---

## 🚀 Installation & Usage
1.  **Prerequisite**: Install [AutoHotkey v2](https://www.autohotkey.com/). **This script requires v2 and is not compatible with v1.1**.
2.  **Download**: Place the `CapsLock‑.ahk` script in your preferred directory.
3.  **Run**: Double‑click the script file to launch it. A tray icon will appear.
4.  **Auto‑Start (Optional)**: Right‑click the tray icon → Select **"Load on start up"**. A checkmark indicates it’s enabled. This adds a registry entry for automatic launch on user login.
5.  **Configure Image‑to‑PDF (Optional)**:
    *   Download and install ImageMagick from the [official site](https://imagemagick.org/).
    *   Right‑click the tray icon → Select **"Set ImageMagick Path..."**.
    *   In the file selector, navigate to your ImageMagick installation directory and select the `magick.exe` file (typically under `C:\Program Files\ImageMagick‑<version>\`).
    *   Click "Open" to save the path to `Config.ini`. If a legacy `ImageMagickPath.txt` exists in the script directory, it will be automatically migrated on next launch.

---

## 🛠️ Technical Details & Configuration
The script’s behavior can be adjusted by modifying the global variables at the top of the file:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `MaxHistory` | `10000` | Maximum number of clipboard history entries to keep (FIFO). |
| `MAX_VISIBLE_MENU` | `15` | Maximum items shown in the quick history menu (`CapsLock+Shift+V`). |
| `ENCRYPT_KEY` | `0x5A` | Key used for XOR encryption of the history file. Change this to alter the encryption. Set to `0` to disable encryption (plain text storage). |
| `HistoryFile` | `A_ScriptDir "\ClipHistory.bin"` | Path for the persistent history file. |
| `ImageMagickExe` | (empty string) | Full path to ImageMagick `magick.exe`, read from the `[ImageMagick]` section of `Config.ini` at startup. |
| `ImageFormats` | `["png", "jpg", "jpeg", "bmp", "gif", "tiff", "tif", "webp", "ico", "heic"]` | List of supported image formats for identifying image paths in the clipboard. |
| `DeleteMode` | `1` | Temporary file cleanup strategy: `1` = delete after delay, `2` = batch cleanup, `3` = never delete. |
| `DeleteDelay` | `10` | Delay in seconds before deleting temp files (used when `DeleteMode = 1`). |
| `CleanupInterval` | `30` | Interval in seconds between batch cleanup runs (used when `DeleteMode = 2`). |
| `ConfigFile` | `A_ScriptDir "\\Config.ini"` | Unified INI file storing cleanup settings (`[Cleanup]` section) and ImageMagick path (`[ImageMagick]` section). |

**History File Format**: Entries are stored sequentially. Each entry is prefixed by its data length (4 bytes), followed by the XOR‑encrypted data. The data format for each entry is: `Timestamp | Window Title | Text Content`.  
In memory, each history item is a Map object containing the keys `text`, `source` (window title), `process` (executable name), and `time` (timestamp). The `process` name is captured for potential future use but is **not** persisted to disk.

**Key Mechanisms**:
*   **Clipboard Monitoring**: Uses `OnClipboardChange` to detect new copies. It ignores its own generated temp files (`ClipTemp_*.txt`).
*   **Multiple File Paste**: The `SetClipboardFiles` function constructs a `DROPFILES` structure in memory, allowing the script to set multiple file paths to the clipboard at once, enabling batch paste operations from the Full History GUI.
*   **Temporary File Cleanup**: The `ScheduleFileDeletion` function routes cleanup based on `DeleteMode`. Mode 1 uses `SetTimer` with a negative delay for one‑shot deletion. Mode 2 queues files and uses a periodic `SetTimer` to delete them in batches. Mode 3 keeps all files.
*   **Error Handling & Compatibility**: The `LoadHistory()` function includes logic to handle and migrate from older, unencrypted, or malformed history file formats gracefully.

**Note on Encryption**: The provided XOR encryption (`CryptBuffer` function) is a simple obfuscation and is **not cryptographically secure**. For sensitive data, consider using a stronger encryption library or setting `ENCRYPT_KEY` to `0` and relying on system file permissions.

**Note on Image Processing**: The script relies on the external ImageMagick command‑line tool for image merging and PDF creation. The path to `magick.exe` is configured via the tray menu and stored in `Config.ini`. On first launch, any legacy `ImageMagickPath.txt` is automatically migrated to the unified `Config.ini`. If the path is not set or the executable is not found, a prompt will appear.

---

## 📄 License
This project is licensed under the [GPL‑3.0 License](LICENSE).
