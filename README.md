<div align="center" style="background-color: #1E1E1E; padding: 40px 20px; border-radius: 28px;">
  <div style="background: #2A2A2A; border-radius: 36px; padding: 42px 18px; margin-bottom: 28px;">
    <img src="assets/CapsLock-.ico" alt="CapsLock Extended" width="80">
    <h1 style="color: #E6DED6; font-weight: 350; letter-spacing: 2px; margin: 18px 0 8px;">CapsLock Extended</h1>
    <p style="color: #BEB8AE; font-size: 1.2em; max-width: 700px; margin: 0 auto;">Turn CapsLock into a powerful productivity layer for navigation, clipboard workflows, windows, tabs, and document conversion.</p>
    <p style="color: #8A9E8B; font-size: 0.95em; margin-top: 12px;">AutoHotkey v2 · Windows · Vim-style shortcuts · Clipboard automation · Pandoc integration</p>
  </div>

  <p>
    <a href="https://www.autohotkey.com/"><img src="https://img.shields.io/badge/AutoHotkey-v2.0-8A9E8B?logo=autohotkey&logoColor=BEB8AE&style=flat-square" alt="AutoHotkey v2"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-7A8E8E?style=flat-square" alt="GPL-3.0"></a>
    <img src="https://img.shields.io/badge/Platform-Windows-9E8F7E?style=flat-square" alt="Windows">
    <a href="https://github.com/CYoJkoY/CapsLock-/actions"><img src="https://img.shields.io/badge/CI-GitHub_Actions-8A9E8B?style=flat-square&logo=github" alt="GitHub Actions"></a>
    <a href="https://cyojkoy.github.io/Payment/"><img src="https://img.shields.io/badge/Support_Me-9E8F7E?logo=buy-me-a-coffee&logoColor=BEB8AE&style=flat-square" alt="Support Me"></a>
  </p>

  <p style="word-spacing: 6px; margin-top: 20px;">
    <a href="#-overview" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Overview</a> &nbsp;•&nbsp;
    <a href="#-core-features" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Core Features</a> &nbsp;•&nbsp;
    <a href="#-shortcut-quick-reference" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Shortcuts</a> &nbsp;•&nbsp;
    <a href="#-installation--setup" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Installation</a> &nbsp;•&nbsp;
    <a href="#%EF%B8%8F-configuration--parameters" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Configuration</a> &nbsp;•&nbsp;
    <a href="#-project-structure" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Structure</a> &nbsp;•&nbsp;
    <a href="#-security-notes" style="color: #8A9E8B; text-decoration: none; border-bottom: 1px dotted #5A6B6B;">Security</a>
  </p>
</div>

<div align="center">
  <img src="assets/dots.svg" alt="separator" width="160" height="12">
</div>

## 📖 Overview

**CapsLock Extended** turns the CapsLock key into a dedicated productivity modifier. Hold `CapsLock` and combine it with familiar keys to control text navigation, selection, clipboard operations, windows, tabs, and document conversion without constantly reaching for the mouse or leaving the home row.

The project is written for **AutoHotkey v2** and targets Windows desktop workflows. It combines Vim-inspired keyboard behavior with practical automation features such as clipboard history, smart file pasting, window transparency control, tab switching, Pandoc conversion, and a customizable tray menu.

> **Note**  
> This project targets **AutoHotkey v2 only**. AutoHotkey v1 is not supported.

## ✨ Core Features

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">⌨️ Vim-style Text Navigation</h3>
  <ul style="color: #BEB8AE;">
    <li>Move by word with <code>CapsLock + Left/Right</code>.</li>
    <li>Jump to the beginning or end of a line with <code>CapsLock + Up/Down</code>.</li>
    <li>Extend selections by word or line with the corresponding <code>Shift</code> combinations.</li>
    <li>Select the complete word under the cursor with <code>CapsLock + Space</code>.</li>
    <li>Delete characters, words, or entire lines without leaving the home row.</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">📋 Advanced Clipboard Workflows</h3>
  <ul style="color: #BEB8AE;">
    <li>Copy selected text as plain text with automatic formatting removal.</li>
    <li>Smart paste supports mixed file paths, recursive folder collection, and image-to-PDF conversion.</li>
    <li>Clipboard history provides preview, single-item paste, batch paste, and deletion.</li>
    <li>Swap the case of clipboard text while preserving the original clipboard content.</li>
    <li>Gitignore-style ignore rules can exclude temporary or sensitive files from file-based paste workflows.</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">📄 Document Conversion with Pandoc</h3>
  <ul style="color: #BEB8AE;">
    <li>Convert clipboard file paths with <code>CapsLock + P</code>.</li>
    <li>Support a broad range of Pandoc input and output formats.</li>
    <li>Expand folders recursively and process multiple documents as a batch.</li>
    <li>Show progress feedback and place converted files into a workflow-ready multi-file drop.</li>
    <li>Choose the output format from the tray menu, with <code>docx</code> available as the default configuration.</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">🪟 Window & Tab Control</h3>
  <ul style="color: #BEB8AE;">
    <li>Adjust window opacity with CapsLock plus the left or right mouse button.</li>
    <li>Toggle a lightweight ghost mode between 10% and 100% opacity.</li>
    <li>Toggle always-on-top behavior with sound and OSD feedback.</li>
    <li>Maximize, restore, and minimize the active window from the keyboard.</li>
    <li>Switch browser tabs or cycle windows without leaving the keyboard.</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">🕘 Full Clipboard History Browser</h3>
  <ul style="color: #BEB8AE;">
    <li>Open a dedicated history window from the clipboard history menu.</li>
    <li>Search and multi-select historical entries.</li>
    <li>Paste multiple entries as files or text.</li>
    <li>Delete entries with real-time list updates.</li>
    <li>Browse large histories with paginated loading.</li>
  </ul>
</div>

<div style="background: #2A2A2A; border-radius: 20px; padding: 16px; margin: 16px 0;">
  <h3 style="margin-top: 0; color: #D6D2CC;">🖱️ Custom Tray Interface</h3>
  <ul style="color: #BEB8AE;">
    <li>Use a custom dark-themed tray menu with nested settings.</li>
    <li>Group cleanup, history, paste, and language controls into dedicated submenus.</li>
    <li>Automatically reposition the menu to avoid taskbar overflow.</li>
    <li>Use DPI-aware tray positioning for accurate alignment.</li>
    <li>Switch the interface language directly from the tray menu; the project supports 13 languages.</li>
  </ul>
</div>

## 🎹 Shortcut Quick Reference

All shortcuts below require **holding `CapsLock`** while pressing the corresponding key unless explicitly stated otherwise.

| Category | Shortcut | Action |
|---|---|---|
| **System** | `CapsLock` double-click | Toggle the native CapsLock state |
| **Clipboard** | `C` | Copy as plain text |
| | `V` | Smart paste |
| | `Shift+V` | Open clipboard history |
| | `F` | Swap clipboard text case and paste |
| | `P` | Convert clipboard file paths with Pandoc |
| **Navigation** | `Left / Right` | Move one word |
| | `Up / Down` | Jump to line start / end |
| | `Space` | Select the current word |
| **Selection** | `Shift+Left / Shift+Right` | Extend selection by word |
| | `Shift+Up / Shift+Down` | Extend selection to line start / end |
| **Editing** | `A / D` | Delete one character |
| | `Shift+A / Shift+D` | Delete one word |
| | `Backspace / Delete` | Delete the current line |
| **Window** | `T` | Toggle always on top |
| | `W / 8 / Num8` | Maximize / restore |
| | `S / 2 / Num2` | Minimize |
| **Mouse** | `Left Button` | Increase opacity |
| | `Right Button` | Decrease opacity |
| | `Middle Button` | Toggle ghost mode |
| **Tabs** | `Q / E` | Previous / next tab |
| | `Shift+Q / Shift+E` | Cycle windows |

## 🚀 Installation & Setup

### Prerequisites

1. **AutoHotkey v2** — install it from [autohotkey.com](https://www.autohotkey.com/).
2. **ImageMagick** — optional, required for image-to-PDF workflows. Download from [imagemagick.org](https://imagemagick.org/).
3. **Pandoc** — optional, required for document conversion. Download from [pandoc.org](https://pandoc.org/).

### Quick Start

1. Download or clone this repository.
2. Keep `CapsLock-.ahk` together with its supporting directories such as `Config/`, `Core/`, and `History/`.
3. Run `CapsLock-.ahk` with AutoHotkey v2.
4. Confirm that the CapsLock Extended icon appears in the Windows system tray.

### Optional: Start with Windows

Open the tray menu and enable **Load on start up**. The option uses the current user's Windows startup registry entry under `HKCU\Run`.

### Configure ImageMagick

1. Open the tray menu and choose **ImageMagick: Not Set**.
2. Select `magick.exe` from your ImageMagick installation.
3. The selected path is stored in the project's configuration file and the tray status changes to a valid state.

### Configure Pandoc

1. Open the tray menu and choose the Pandoc settings.
2. Select `pandoc.exe`.
3. Select the desired output format.
4. Use `CapsLock + P` to convert clipboard file paths.

## ⚙️ Configuration & Parameters

### Tray Settings

| Setting | Purpose |
|---|---|
| `ImageMagick: Not Set / Valid` | Set or change the ImageMagick executable path. |
| `Pandoc: Not Set / Valid` | Configure the Pandoc executable and output format. |
| `Open Temp Folder` | Open the working directory used for temporary paste files. |
| `Delete Mode` | Choose delayed, batch, or disabled temporary-file cleanup. |
| `Set Delay...` | Set the delay for delayed cleanup. |
| `Set Cleanup Interval...` | Set the interval for batch cleanup. |
| `Set Max History...` | Set the maximum clipboard history size. |
| `Paste Mode` | Choose file-based paste or plain-text paste with source markers. |
| `Ignore Rules` | Edit gitignore-style file and path exclusions. |
| `Language` | Switch the interface language. |
| `Rebuild Language Cache` | Rebuild localized cache files from `lang.csv`. |
| `Load on start up` | Enable or disable Windows startup integration. |
| `Reload` | Reload the script. |
| `Exit` | Exit the application. |

### Configuration File

The main configuration is stored in `configs/Config.ini`.

```ini
[Cleanup]
deleteMode=1
deleteDelay=10
cleanupInterval=30

[History]
maxHistory=10000

[General]
pasteMode=1
autoClean=0
```

Values may vary by release and local configuration. The tray menu is the preferred interface for changing supported settings.

## 🧠 Implementation Highlights

### CapsLock as a Modifier Layer

The script intercepts CapsLock combinations and maps them to focused productivity actions. This creates a compact keyboard layer without replacing the native CapsLock function permanently.

### Clipboard-Centric Workflows

Clipboard operations are designed around real file-system workflows rather than text alone. Paths can be normalized, folders can be expanded recursively, files can be merged or converted, and history entries can be revisited without leaving the application context.

### Temporary File Management

File-based paste operations use a dedicated temporary workflow and provide configurable cleanup behavior. Users can choose delayed cleanup, periodic batch cleanup, or no automatic deletion.

### External Tool Integration

Optional ImageMagick and Pandoc integrations keep external dependencies isolated to the workflows that require them. The main keyboard layer remains usable without either dependency.

## 🔐 Security Notes

### Clipboard History

Clipboard history may contain sensitive text, files, paths, or other user data. Review the configured history retention and cleanup behavior before using the tool with confidential information.

### Ignore Rules

Use ignore rules to prevent sensitive or temporary paths from being included in file-oriented clipboard operations.

### External Tools

ImageMagick and Pandoc are optional external executables. Only point CapsLock Extended to installations you trust.

### Credentials

This project does not require a cloud account or external authentication service for its core functionality.

## 📁 Project Structure

```tree
CapsLock-/
├── 📁 .github
│   └── 📁 workflows
│       └── ⚙️ ...
├── 📁 Config
│   └── 📄 ...
├── 📁 Core
│   └── 📄 ...
├── 📁 History
│   └── 📄 ...
├── 📁 langs
│   └── 📄 ...
├── 📁 assets
│   ├── 🖼️ CapsLock-.ico
│   └── 🖼️ dots.svg
├── 📄 CapsLock-.ahk
├── 📄 lang.csv
├── ⚖️ LICENSE
└── 📖 README.md
```

## 🤝 Contributing & Feedback

Issues and pull requests are welcome.

For bug reports, include the Windows version, AutoHotkey version, the affected shortcut or feature, and the exact error message when available. Do not include private clipboard contents, sensitive file paths, or other confidential information.

For feature requests, describe the workflow you want to improve and the keyboard or mouse interaction you would prefer.

## 📄 License

CapsLock Extended is licensed under the **GNU General Public License v3.0 only (GPL-3.0-only)**.

See [`LICENSE`](LICENSE) for the complete license text.

## 💰 Support the Author

If CapsLock Extended improves your workflow, consider supporting the project.

<div align="center">
  <a href="https://cyojkoy.github.io/Payment/">
    <img src="https://img.shields.io/badge/Support_the_Author-9E8F7E?style=for-the-badge&logo=buy-me-a-coffee&logoColor=BEB8AE" alt="Support the Author">
  </a>
</div>

<div align="center">
  <sub>Built for Windows users who want a fast, keyboard-centered productivity layer.</sub>
</div>
