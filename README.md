# CapsLock Extension 🚀
A high-performance system enhancement tool built with **AutoHotkey v2**. This script transforms the underutilized `CapsLock` key into a versatile **Super-Modifier (Mod-key)**, streamlining text navigation, window management, clipboard history, and introducing a unique **Clipboard-to-File** workflow. It features **persistent storage** for clipboard history, with support for **encryption** to protect your privacy, all without losing the native CapsLock toggle functionality.

## ✨ Key Features
### 📋 Advanced Clipboard Management
*   **Smart Paste as File (`CapsLock + V`)**:
    *   Instantly converts the last manually copied text (or current clipboard if no manual history) into a `.txt` file and pastes it. Ideal for sending code/text as files in IM apps or File Explorer.
    *   **Context-Aware Headers**: Each generated `.txt` file includes a header (e.g., `; Copied from: Document.txt - Notepad (at 2026-04-20 06:46:11)`) that records the **source window title and timestamp**. When pasting from the history menu, it uses the original copy source stored in history. For direct `CapsLock+V` pasting, it attempts to match the current clipboard content with the history to retrieve the source; otherwise, it uses a generic descriptor.
    *   **Auto Cleanup**: The temporary `.txt` file in `%TEMP%` is automatically deleted 10 seconds after pasting.
    *   **Clipboard Restoration**: The original manual clipboard content (if any) is restored 10 seconds after the paste operation.
*   **Clipboard History with Encrypted Storage**:
    *   **History Menu (`CapsLock + Shift + V`)**: A lightweight, non-blocking menu showing the 15 most recent entries (configurable via `MAX_VISIBLE_MENU`). Click **"📋 View full history (X items)..."** to open the full management GUI.
    *   **Full History GUI**: A resizable window with a multi-select ListView, supporting:
        *   **Batch Operations**: Select multiple items to paste as individual `.txt` files sequentially, or delete them in batch.
        *   **Content Preview**: Double-click an item or use the context menu to preview its full content in a separate read-only, resizable window.
        *   **"Select All" Toggle**: A checkbox to quickly select/deselect all history entries.
    *   **Persistent & Encrypted Storage**: Clipboard history is automatically saved to `ClipHistory.bin` in the script directory. The storage uses a simple XOR-based encryption (controllable via the `ENCRYPT_KEY` global variable) to obfuscate the text content. The history survives script reloads and system restarts.
*   **Intelligent Source Tracking**: The script captures the active window title and timestamp at the moment of *copying* (`Ctrl+C`), not at pasting. This "copy-time context" is stored with each history entry, ensuring accurate provenance.

### ⌨️ Productivity Text Navigation
*   **Vim-like Home Row Movement**: Navigate through text with Home/End jumps and word-wise movement, all from the home row.
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

### 🖼️ Window & Transparency Control
*   **Real-time Window Opacity Adjustment**:
    *   **Hold `CapsLock` + Left Mouse Button**: Gradually increase the active window's opacity (becomes more opaque). Click quickly for a +20 step.
    *   **Hold `CapsLock` + Right Mouse Button**: Gradually decrease the active window's opacity (becomes more transparent). Click quickly for a -20 step.
    *   Opacity is clamped between 20 and 255.
*   **One-Click Stealth Toggle**: `CapsLock + Middle Mouse Button`: Toggle the active window's opacity between 10% (nearly transparent) and 100% (fully opaque).
*   **Quick Window State Control**:
    *   `CapsLock + 8` / `Numpad8`: Toggle window **Maximize / Restore**.
    *   `CapsLock + 2` / `Numpad2`: **Minimize** active window.

### ⚙️ System Integration
*   **Tray Menu**: Right-click the system tray icon for:
    *   **Load on start up**: Toggle auto-start with the system (modifies `HKCU\...\Run` registry).
    *   **Reload**: Reload the script.
    *   **Exit**: Exit the application.
*   **Native CapsLock Toggle**: Double-tap `CapsLock` (within 50-300ms) to toggle the native CapsLock state (On/Off), while still allowing it to function as a modifier key when held.

---
## 🚀 Installation & Usage
1.  **Prerequisite**: Install [AutoHotkey v2.0+](https://www.autohotkey.com/). **This script requires v2 and is not compatible with v1.1**.
2.  **Download**: Place the `CapsLock-.ahk` script in your preferred directory.
3.  **Run**: Double-click the script file to launch it. A tray icon (![Tray Icon](https://img.shields.io/badge/-CapsLock--blue)) will appear.
4.  **Auto-Start (Optional)**: Right-click the tray icon → Select **"Load on start up"**. A checkmark indicates it's enabled. This adds a registry entry for automatic launch on user login.

---
## 🛠️ Technical Details & Configuration
The script's behavior can be adjusted by modifying the global variables at the top of the file:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `MaxHistory` | `10000` | Maximum number of clipboard history entries to keep (FIFO). |
| `MAX_VISIBLE_MENU` | `15` | Maximum items shown in the quick history menu (`CapsLock+Shift+V`). |
| `ENCRYPT_KEY` | `0x5A` | Key used for XOR encryption of the history file. Change this to alter the encryption. Set to `0` to disable encryption (plain text storage). |
| `HistoryFile` | `A_ScriptDir "\ClipHistory.bin"` | Path for the persistent history file. |

**History File Format**: Entries are stored sequentially. Each entry is prefixed by its data length (4 bytes), followed by the XOR-encrypted data. The data format for each entry is: `Timestamp | Window Title | Text Content`.

**Key Mechanisms**:
*   **Clipboard Monitoring**: Uses `OnClipboardChange` to detect new copies. It ignores its own generated temp files (`ClipTemp_*.txt`).
*   **Multiple File Paste**: The `SetClipboardFiles` function constructs a `DROPFILES` structure in memory, allowing the script to set multiple file paths to the clipboard at once, enabling batch paste operations from the Full History GUI.
*   **Data Structure**: History is stored in an array of Map objects: `{text: "", source: "", time: "", process: ""}`.
*   **Error Handling & Compatibility**: The `LoadHistory()` function includes logic to handle and migrate from older, unencrypted, or malformed history file formats gracefully.

**Note on Encryption**: The provided XOR encryption (`CryptBuffer` function) is a simple obfuscation and not cryptographically secure. For sensitive data, consider using a stronger encryption library or setting `ENCRYPT_KEY` to `0` and relying on system file permissions.

---
## 📄 License
This project is licensed under the [GPL-3.0 License](LICENSE).
