<p align="center">
  <img src="assets/CapsLock-.ico" alt="CapsLock Extended Logo" width="120">
</p>

<h1 align="center">CapsLock Extended</h1>

<p align="center">
  <strong>Transform your most underutilized key into a productivity powerhouse.</strong><br>
  A high-performance, Vim-inspired system enhancement utility built with AutoHotkey v2.
</p>

<p align="center">
  <a href="https://www.autohotkey.com/"><img src="https://img.shields.io/badge/AutoHotkey-v2.0-blue?logo=autohotkey" alt="AutoHotkey v2"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-green.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-Windows-lightgrey" alt="Platform">
  <a href="https://cyojkoy.github.io/Payment/"><img src="https://img.shields.io/badge/Support-Me-orange?logo=buy-me-a-coffee" alt="Support Me"></a>
</p>

<p align="center">
  <a href="#-hotkey-reference">View Hotkeys</a> •
  <a href="#-installation--setup">Installation</a> •
  <a href="#-configuration--technical-details">Configuration</a> •
  <a href="#-support-me">Support</a>
</p>

---

## 📑 Table of Contents

- [📖 Overview](#-overview)
- [✨ Core Features](#-core-features)
- [🎹 Hotkey Reference](#-hotkey-reference)
- [🚀 Installation & Setup](#-installation--setup)
- [⚙️ Configuration & Technical Details](#️-configuration--technical-details)
- [🤝 Contributing & Feedback](#-contributing--feedback)
- [📄 License](#-license)
- [💰 Support Me](#-support-me)

---

## 📖 Overview

**CapsLock Extended** reimagines the `CapsLock` key, turning it into a versatile "Super-Modifier". It brings Vim-like home-row navigation, advanced clipboard management with encrypted history, window opacity control, and seamless workflow automation directly to your fingertips—all without leaving your keyboard's home row.

> **Note:** This script is strictly designed for **AutoHotkey v2**.

---

## ✨ Core Features

### ⌨️ Vim-Inspired Navigation & Editing
Navigate and edit text at the speed of thought without reaching for the mouse or arrow keys.
*   **Home-Row Navigation:** Move by word or jump to line start/end instantly.
*   **Smart Selection:** Select by word, line, or instantly grab the current word under the cursor.
*   **Rapid Deletion:** Delete characters, words, or entire lines using intuitive `A/D` and `Backspace/Delete` mappings.

### 📋 Advanced Clipboard & Smart Paste
*   **Plain Text Copy (`C`):** Strips all rich formatting (HTML/RTF) and copies pure text.
*   **Context-Aware Smart Paste (`V`):** 
    *   *Image-to-PDF:* Automatically detects image paths in the clipboard and merges them into a single PDF via ImageMagick.
    *   *Source-Tracked Text:* Pastes text with an auto-generated header containing the source window title and timestamp.
    *   *File Pasting:* Can paste content as a temporary `.txt` file (ideal for messaging apps like WeChat/Slack/Discord).
*   **Encrypted History (`Shift+V`):** Persistent, XOR-encrypted clipboard history with a quick-access menu and a full GUI for batch operations.
*   **Instant Case Toggle (`F`):** Automatically detects the first letter's case and flips the entire clipboard text (Upper ↔ Lower).

### 🪟 Window Management & "Ninja" Mode
*   **Real-time Opacity Control:** Hold `CapsLock` and click/drag with mouse buttons to smoothly adjust window transparency.
*   **One-Click Stealth (`Middle Click`):** Instantly toggle active window opacity between 10% (ghost mode) and 100%.
*   **Always on Top (`T`):** Pin any window to the foreground with audio/visual feedback.
*   **Quick Resizing:** Maximize, restore, or minimize windows using `W/S` or the Numpad.

---

## 🎹 Hotkey Reference

*All hotkeys below require holding **`CapsLock`** (except the native toggle).*

| Category | Hotkey | Action Description |
| :--- | :--- | :--- |
| **System** | `CapsLock` *(Double Tap)* | Toggle native CapsLock state (50-300ms window). |
| **Clipboard** | `C` | Copy selection as **plain text** (strips formatting). |
| | `V` | **Smart Paste** (File / Source-text / Image-to-PDF). |
| | `Shift + V` | Open **Clipboard History** Quick Menu. |
| | `F` | **Toggle Case** of clipboard text (Upper ↔ Lower). |
| **Navigation** | `←` / `→` | Move cursor left / right by **word**. |
| | `↑` / `↓` | Jump to **start / end** of the current line. |
| | `Space` | Select the **entire current word**. |
| **Selection** | `Shift + ←` / `→` | Select left / right by word. |
| | `Shift + ↑` / `↓` | Select to start / end of line. |
| **Editing** | `A` / `D` | `Backspace` / `Delete` (single character). |
| | `Shift + A` / `D` | Delete left / right by **word**. |
| | `Backspace` / `Delete`| Delete the **entire current line**. |
| **Window** | `T` | Toggle **Always on Top** for the active window. |
| | `W` / `8` / `Num8` | **Maximize / Restore** active window. |
| | `S` / `2` / `Num2` | **Minimize** active window. |
| **Mouse** | `Left Button` | **Increase** window opacity (Click: +20, Hold: +5). |
| | `Right Button` | **Decrease** window opacity (Click: -20, Hold: -5). |
| | `Middle Button` | **Toggle** opacity between 10% (Stealth) and 100%. |
| **Tabs** | `Q` / `E` | Switch to **previous / next** tab (`Ctrl+PgUp/PgDn`). |

---

## 🚀 Installation & Setup

### Prerequisites
1. **AutoHotkey v2**: Download and install from [autohotkey.com](https://www.autohotkey.com/).
2. **ImageMagick** *(Optional)*: Required only if you want to use the *Image-to-PDF* clipboard feature. Download from [imagemagick.org](https://imagemagick.org/).

### Quick Start
1. **Download** the repository and place `CapsLock-.ahk` along with the `modules/` folder in your desired directory.
2. **Run** the script by double-clicking `CapsLock-.ahk`. You will see a new icon in your system tray.
3. *(Optional)* **Auto-Start**: Right-click the tray icon → Select **"Load on Startup"**.

### Configuring ImageMagick (Optional)
1. Right-click the system tray icon → Select **"ImageMagick: Not Set"**.
2. Navigate to your ImageMagick installation folder and select `magick.exe` (e.g., `C:\Program Files\ImageMagick-7.x.x-Q16\magick.exe`).
3. The path is automatically saved to `Config.ini`.

---

## ⚙️ Configuration & Technical Details

Behavior can be fine-tuned via the **System Tray Menu** or by editing `Config.ini` / global variables in the module files.

| Setting / Variable | Default | Description |
| :--- | :--- | :--- |
| `PasteMode` | `1` | `1`: Paste as temporary `.txt` file.<br>`2`: Paste as text with source metadata header. |
| `MaxHistory` | `10000` | Maximum clipboard history entries (FIFO). |
| `ENCRYPT_KEY` | `0x5A` | Hex key for XOR encryption of history. Set to `0` for plaintext. |
| `DeleteMode` | `1` | Temp file cleanup: `1`=Delayed, `2`=Batch, `3`=Never. |
| `DeleteDelay` | `10` | Seconds before deleting temp files (Mode 1). |
| `CleanupInterval`| `30` | Seconds between batch cleanup runs (Mode 2). |

### 🏗️ Architecture Highlights
* **Modular Codebase:** Cleanly separated into `Constants`, `Encryption`, `Config`, `Cleanup`, `ClipboardUtils`, `History`, `Hotkeys`, `Tray`, and `Main`.
* **Memory-Level File Pasting:** Uses `DROPFILES` structure manipulation to place multiple file paths directly onto the clipboard for seamless batch pasting.
* **Smart Loop Prevention:** Intelligent `OnClipboardChange` monitoring that ignores script-generated temp files (`ClipTemp_*.txt`) to prevent infinite clipboard loops.

> **⚠️ Security Note:** The built-in XOR encryption (`CryptBuffer`) is designed for basic obfuscation to prevent casual snooping. It is **not** cryptographically secure. For highly sensitive environments, set `ENCRYPT_KEY=0` and rely on Windows OS-level file permissions (EFS/BitLocker).

---

## 🤝 Contributing & Feedback

Found a bug or have a feature request? 
* Please open an **Issue** or submit a **Pull Request**.
* Ensure your code follows the existing modular structure and AHK v2 syntax.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for details.

---

## 💰 Support Me

If you've found this project helpful or it has boosted your productivity, feel free to buy me a coffee. Your support is my biggest motivation to keep updating and maintaining it! ☕

<p align="center">
  <a href="https://cyojkoy.github.io/Payment/">
    <img src="https://img.shields.io/badge/👉_Click_Here_to_Support_Me-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Support Me Button" height="40">
  </a>
</p>

<p align="center">
  <i>Made with ❤️ and AutoHotkey v2</i>
</p>
