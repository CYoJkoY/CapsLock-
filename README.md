Understood! Here is the revised, professional **README.md** in pure English, including all your latest features like the Clipboard History and the Resizable Preview GUI. You can copy and paste this directly into your GitHub repository.

---

# CapsLock-Extension 🚀

A high-performance system enhancement tool built with **AutoHotkey v2**. This script transforms the underutilized `CapsLock` key into a versatile **Super-Modifier (Mod-key)**, streamlining text navigation, window management, and introducing a unique **Clipboard-to-File** workflow—all without losing the native CapsLock functionality.

## ✨ Key Features

### 📋 Advanced Clipboard Management (New!)

* **Paste as File (`CapsLock + V`)**: Instantly convert the last manually copied text into a `.txt` file and paste it (ideal for sending code/text as files in IM or File Explorer).
* **Custom History Menu (`CapsLock + Shift + V`)**: A dedicated clipboard manager that supports:
* **Persistent Coordinates**: The menu stays locked at the initial mouse position when navigating back from sub-menus for a seamless feel.
* **Responsive Preview GUI**: A built-in viewer with vertical scrolling and word wrap. The preview content and buttons **dynamically resize** with the window.
* **Quick Management**: Preview full content, delete specific entries, or paste as file directly from the history.


* **Intelligent Locking**: The script remembers your last manual `Ctrl+C` action, ensuring `CapsLock + V` always pastes what you expect, even after using the history menu.

### ⌨️ Productivity Navigation

* **Vim-like Movement**: Navigate through text using Home/End and word-jumps without moving your hands from the home row.
* **Enhanced Deletion**: Quick word-left/right deletion and a single-stroke command to wipe an entire line.

### 🖼️ Window Control & Transparency

* **Dynamic Opacity**: Adjust the transparency of any window in real-time using `CapsLock` + Mouse Clicks.
* **Stealth Mode**: A middle-click shortcut to instantly toggle between 10% and 100% opacity.
* **State Toggle**: Quickly maximize, restore, or minimize windows with numeric shortcuts.

---

## ⌨️ Hotkey Reference

### Function & Clipboard

| Combo (CapsLock +) | Action |
| --- | --- |
| `Double Tap` | Toggle native CapsLock (Large/Small letters) |
| `V` | Paste last manual copy as **.txt file** |
| `Shift + V` | Open **Clipboard History Menu** |

### Text Editing

| Combo (CapsLock +) | Mapping |
| --- | --- |
| `↑` / `↓` | Home / End |
| `←` / `→` | Ctrl + Left / Right (Jump by word) |
| `Space` | Select current word |
| `,` / `.` | Backspace / Delete |
| `m` / `/` | Delete word left / Delete word right |
| `Backspace` | **Delete entire line** |

### Window & System

| Combo (CapsLock +) | Mapping |
| --- | --- |
| `8` / `2` | Toggle Maximize / Minimize Window |
| `Q` / `E` | Switch Browser Tabs (Ctrl+PgUp/PgDn) |
| `LButton` (Hold) | Increase Window Opacity |
| `RButton` (Hold) | Decrease Window Opacity |
| `MButton` | Toggle 10% / 100% Opacity |

---

## 🚀 Installation

1. **Requirement**: Install [AutoHotkey v2.0+](https://www.autohotkey.com/).
2. **Download**: Clone this repo or download `CapsLock_Extension.ahk`.
3. **Run**: Double-click the script to execute.
4. **Auto-Start**: Right-click the tray icon and select **"Load on start up"** to enable persistence.

## 🛠️ Technical Details

* **Self-Cleaning**: Temporary `.txt` files created for pasting are automatically deleted after 10 seconds to keep your `Temp` folder clean.
* **Non-Blocking Menu**: The history menu uses function-based calls instead of key-simulations to avoid input conflicts and IME (input method) interference.
* **Adaptive GUI**: The preview window utilizes an `OnEvent("Size")` listener to ensure the text area and buttons stay perfectly aligned during resizing.

## 📄 License

This project is licensed under the [MIT License](https://www.google.com/search?q=LICENSE).
