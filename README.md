# CapsLock-Extension 🚀

A lightweight, high-performance system enhancement tool written in **AutoHotkey v2**. This script redefines the `CapsLock` key as a powerful modifier (Mod-key), significantly boosting productivity for coding, writing, and window management without losing original functionality.



## ✨ Key Features

- **Intelligent CapsLock Logic**: 
  - Single tap toggles the native CapsLock state (via smart delay logic).
  - Holding down activates the extension layer.
- **Efficient Text Navigation**: 
  - Vim-like movement (Home/End/Ctrl+Arrows) at your fingertips.
  - Quick word selection and whole-line deletion.
- **Window Management Mastery**: 
  - Instant Maximize/Restore/Minimize commands.
  - **Dynamic Transparency**: Smoothly adjust current window transparency using mouse clicks or long-press.
- **Tray Integration**: 
  - Manage "Load on Start-up" directly via the tray icon context menu.
  - Native performance with minimal memory footprint.

## ⌨️ Hotkey Reference

| Key Combo (CapsLock +) | Action |
| :--- | :--- |
| `↑` / `↓` | Go to Home / End |
| `←` / `→` | Jump Prev Word / Next Word (Ctrl+Left/Right) |
| `Space` | Select current word |
| `,` / `.` | Backspace / Delete |
| `m` / `/` | Delete word left / Delete word right |
| `Backspace` | Delete entire line |
| `Q` / `E` | Switch Browser Tabs (Ctrl+PgUp/PgDn) |
| `8` / `2` | Toggle Maximize / Minimize Window |

### 🖱️ Mouse Enhancements (Hold CapsLock)
- **Left/Right Click**: Click or hold to increase/decrease window transparency.
- **Middle Click**: Toggle between "Stealth Mode" (10% opacity) and 100% opacity.



## 🚀 Installation & Usage

1. **Prerequisites**: Ensure you have [AutoHotkey v2.0+](https://www.autohotkey.com/) installed.
2. **Download**: Clone this repository or download the `CapsLock_Extension.ahk` file.
3. **Run**: Double-click the script to start.
4. **Auto-Start**: Right-click the tray icon and select **"Load on start up"** to enable persistence.

## 🛠️ Optimization Tips

- **Antivirus**: Add the compiled `.exe` to your antivirus whitelist to prevent input lag.
- **Admin Rights**: To manage high-privilege applications (like Task Manager), run the script as **Administrator**.
- **Compilation**: For the best performance, compile using the `Ahk2Exe` 64-bit base without compression.

## 📄 License
This project is licensed under the [MIT License](LICENSE).